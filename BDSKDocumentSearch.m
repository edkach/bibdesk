//
//  BDSKDocumentSearch.m
//  Bibdesk
//
//  Created by Adam Maxwell on 1/19/08.
/*
 This software is Copyright (c) 2008-2009
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKDocumentSearch.h"
#import "BibDocument.h"
#import "BibItem.h"
#import <libkern/OSAtomic.h>
#import "NSInvocation_BDSKExtensions.h"
#import "RALatchTrigger.h"


@interface BDSKDocumentSearch (BDSKPrivate)
- (void)runSearchThread;

@end

@implementation BDSKDocumentSearch

- (id)initWithDocument:(id)doc;
{
    self = [super init];
    if (self) {
        SEL cb = @selector(search:foundIdentifiers:normalizedScores:);
        NSMethodSignature *sig = [doc methodSignatureForSelector:cb];
        NSParameterAssert(nil != sig);
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        [invocation setTarget:doc];
        [invocation setSelector:cb];
        [invocation setArgument:&self atIndex:2];
        searchLock = [[NSLock alloc] init];
        queueLock = [[NSLock alloc] init];
		trigger = [[RALatchTrigger alloc] init];
        queue = [[NSMutableArray alloc] init];
        
        callback = [invocation retain];
        originalScores = [NSMutableDictionary new];
        isSearching = 0;
        shouldKeepRunning = 1;
        
        [NSThread detachNewThreadSelector:@selector(runSearchThread) toTarget:self withObject:nil];
    }
    return self;
}

// owner should have already sent -terminate; sending it from -dealloc causes resurrection
- (void)dealloc
{
	[trigger release];
	[queue release];
    [currentSearchString release];
    [originalScores release];
    [callback release];
    [previouslySelectedPublications release];
    [searchLock release];
    [super dealloc];
}

- (void)queueInvocation:(NSInvocation *)invocation {
    [queueLock lock];
    [queue addObject:invocation];
    [queueLock unlock];
    [trigger signal];
}

- (void)_cancelSearch;
{
    if (NULL != search) {
        // set first in case this is called while we're working
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&isSearching);
        SKSearchCancel(search);
        CFRelease(search);
        search = NULL;
    }    
}

- (void)cancelSearch;
{
    NSInvocation *invocation = [NSInvocation invocationWithTarget:self selector:@selector(_cancelSearch)];
    [self queueInvocation:invocation];
}

- (void)terminate;
{
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&shouldKeepRunning);
    [trigger signal];
    [searchLock lock];
    NSInvocation *cb = callback;
    callback = nil;
    [cb release];
    [searchLock unlock];
}

- (BOOL)isSearching;
{
    OSMemoryBarrier();
    return 1 == isSearching;
}

- (NSDictionary *)normalizedScores
{
    NSMutableDictionary *scores = [NSMutableDictionary dictionary];
    NSEnumerator *keyEnum = [originalScores keyEnumerator];
    id aKey;
    while (aKey = [keyEnum nextObject]) {
        NSNumber *nsScore = [originalScores objectForKey:aKey];
        NSParameterAssert(nil != nsScore);
        float score = [nsScore floatValue];
        [scores setObject:[NSNumber numberWithFloat:(score/maxScore)] forKey:aKey];
    }
    return scores;
}

- (void)invokeFinishedCallback
{
    [[callback target] searchDidStop:self];
}

- (void)invokeStartedCallback
{
    [[callback target] searchDidStart:self];
} 

#define SEARCH_BUFFER_MAX 1024

- (void)_searchForString:(NSString *)searchString index:(SKIndexRef)skIndex
{
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&isSearching);
    [self performSelectorOnMainThread:@selector(invokeStartedCallback) withObject:nil waitUntilDone:YES];

    // note that the add/remove methods flush the index, so we don't have to do it again
    NSParameterAssert(NULL == search);
    search = SKSearchCreate(skIndex, (CFStringRef)searchString, kSKSearchOptionDefault);
    
    SKDocumentID documents[SEARCH_BUFFER_MAX] = { 0 };
    float scores[SEARCH_BUFFER_MAX] = { 0.0 };
    CFIndex i, foundCount;
    
    Boolean more, keepGoing;
    maxScore = 0.0f;
    
    [originalScores removeAllObjects];
    
    do {
        
        more = SKSearchFindMatches(search, SEARCH_BUFFER_MAX, documents, scores, 1.0, &foundCount);
        
        NSMutableSet *foundURLSet = nil;

        if (foundCount > 0) {
            
            NSParameterAssert(foundCount <= SEARCH_BUFFER_MAX);
            id documentURLs[SEARCH_BUFFER_MAX] = { nil };
            SKIndexCopyDocumentURLsForDocumentIDs(skIndex, foundCount, documents, (CFURLRef *)documentURLs);
            foundURLSet = [NSMutableSet setWithCapacity:foundCount];
            
            for (i = 0; i < foundCount; i++) {
                
                // Array may contain NULL values from initialization; before adding the initialization step, it was possible to pass garbage pointers as documentURL (bug #2124370) and non-finite values for the score (bug #1932040).  This is actually a gap in the returned values, so appears to be a Search Kit bug.
                if (documentURLs[i] != nil) {
                    [originalScores setObject:[NSNumber numberWithFloat:scores[i]] forKey:documentURLs[i]];
                    [foundURLSet addObject:documentURLs[i]];
                    [documentURLs[i] release];
                    maxScore = MAX(maxScore, scores[i]);
                }
            }
        }
        
        // check currentSearchString to see if a new search is queued; if so, exit this loop
        // check callback in case the doc is closing while a search is in progress

        [searchLock lock];
        keepGoing = (nil != callback && [searchString isEqualToString:currentSearchString]);
        [searchLock unlock];

        if (keepGoing) {
            NSDictionary *normalizedScores = [self normalizedScores];
            [callback setArgument:&foundURLSet atIndex:3];
            [callback setArgument:&normalizedScores atIndex:4];
            [callback performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
        }
                
        [searchLock lock];
        keepGoing = (nil != callback && [searchString isEqualToString:currentSearchString]);
        [searchLock unlock];
        
    } while (keepGoing && NULL != search && more);
    [self performSelectorOnMainThread:@selector(invokeFinishedCallback) withObject:nil waitUntilDone:YES];
    [self _cancelSearch];  
}

- (NSArray *)previouslySelectedPublications { return previouslySelectedPublications; }

- (void)setPreviouslySelectedPublications:(NSArray *)selPubs
{
    [previouslySelectedPublications autorelease];
    previouslySelectedPublications = [[NSArray alloc] initWithArray:selPubs copyItems:NO];
}

- (NSPoint)previousScrollPositionAsPercentage {
    return previousScrollPositionAsPercentage;
}

- (void)setPreviousScrollPositionAsPercentage:(NSPoint)scrollPoint {
    previousScrollPositionAsPercentage = scrollPoint;
}

- (void)searchForString:(NSString *)searchString index:(SKIndexRef)skIndex selectedPublications:(NSArray *)selPubs scrollPositionAsPercentage:(NSPoint)scrollPoint;
{
    [self setPreviouslySelectedPublications:selPubs];
    [self setPreviousScrollPositionAsPercentage:scrollPoint];
    
    [searchLock lock];
    [currentSearchString autorelease];
    currentSearchString = [searchString copy];
    [searchLock unlock];

    if ([self isSearching])
        [self cancelSearch];
    
    // always queue a search, since the index content may be changing (in case of a search group)
    NSInvocation *invocation = [NSInvocation invocationWithTarget:self selector:@selector(_searchForString:index:)];
    [invocation setArgument:&searchString atIndex:2];
    [invocation setArgument:&skIndex atIndex:3];
    [self queueInvocation:invocation];
}

- (BOOL)shouldKeepRunning {
    OSMemoryBarrier();
    return shouldKeepRunning;
}

- (void)runSearchThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	while ([self shouldKeepRunning]) {
        // get the next invocation from the queue
        NSInvocation *invocation = nil;
        [queueLock lock];
        if ([queue count]) {
            invocation = [[queue objectAtIndex:0] retain];
            [queue removeObjectAtIndex:0];
        }
        [queueLock unlock];
        
        if (invocation) {
            [invocation invoke];
            [invocation release];
		} else if ([self shouldKeepRunning]) {
            // if there's no more invocation wait until we're woken up again, either for a new invocation or to stop
            [trigger wait];
        }
        
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
    }
	
    // make sure the last search was canceled
    [self _cancelSearch];
    
    [queueLock lock];
    [queue removeAllObjects];
    [queueLock unlock];
	
	[pool release];
}

@end
