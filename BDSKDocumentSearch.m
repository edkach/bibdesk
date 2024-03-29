//
//  BDSKDocumentSearch.m
//  Bibdesk
//
//  Created by Adam Maxwell on 1/19/08.
/*
 This software is Copyright (c) 2008-2012
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
#import "NSInvocation_BDSKExtensions.h"
#import <libkern/OSAtomic.h>

#define IDENTIFIERS_KEY @"identifiers"
#define SCORES_KEY @"scores"

@implementation BDSKDocumentSearch

static NSOperationQueue *searchQueue = nil;

+ (void)initialize
{
    if (nil == searchQueue) {
        searchQueue = [NSOperationQueue new];
        [searchQueue setMaxConcurrentOperationCount:1];
    }
}

- (id)initWithDelegate:(id)aDelegate {
    self = [super init];
    if (self) {
        delegate = aDelegate;
        search = NULL;
        isSearching = 0;
        shouldStop = NO;
        currentSearchString = nil;
        previouslySelectedPublications = nil;
        previousScrollPositionAsPercentage = NSZeroPoint;
        
    }
    return self;
}

- (id)init {
    return [self initWithDelegate:nil];
}

// owner should have already sent -terminate; sending it from -dealloc causes resurrection
- (void)dealloc
{
    delegate = nil;
    BDSKDESTROY(currentSearchString);
    BDSKDESTROY(previouslySelectedPublications);
    [super dealloc];
}

- (void)_cancelSearch;
{
    if (NULL != search) {
        // set first in case this is called while we're working
        OSAtomicCompareAndSwap32Barrier(1, 0, &isSearching);
        SKSearchCancel(search);
        CFRelease(search);
        search = NULL;
    }    
}

- (void)cancelSearch;
{
    // make sure this is performed on the queue thread
    NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_cancelSearch) object:nil];
    [searchQueue addOperation:op];
    [op release];
}

- (void)terminate;
{
    [self cancelSearch];
    @synchronized(self) {
        shouldStop = YES;
    }
    delegate = nil;
}

- (BOOL)isSearching;
{
    OSMemoryBarrier();
    return 1 == isSearching;
}

- (void)invokeFoundCallback:(NSDictionary *)info
{
    [delegate search:self foundIdentifiers:[info objectForKey:IDENTIFIERS_KEY] normalizedScores:[info objectForKey:SCORES_KEY]];
}

- (void)invokeFinishedCallback
{
    [delegate searchDidStop:self];
} 

- (void)invokeStartedCallback
{
    [delegate searchDidStart:self];
} 

#define SEARCH_BUFFER_MAX 1024

static inline NSDictionary *normalizedScores(NSDictionary *originalScores, CGFloat maxScore)
{
    NSMutableDictionary *scores = [NSMutableDictionary dictionary];
    for (id aKey in originalScores) {
        NSNumber *nsScore = [originalScores objectForKey:aKey];
        CGFloat score = [nsScore doubleValue];
        [scores setObject:[NSNumber numberWithDouble:(score/maxScore)] forKey:aKey];
    }
    return scores;
}

- (void)backgroundSearchForString:(NSString *)searchString index:(SKIndexRef)skIndex
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    OSAtomicCompareAndSwap32Barrier(0, 1, &isSearching);
    [self performSelectorOnMainThread:@selector(invokeStartedCallback) withObject:nil waitUntilDone:YES];

    // note that the add/remove methods flush the index, so we don't have to do it again
    NSParameterAssert(NULL == search);
    search = SKSearchCreate(skIndex, (CFStringRef)searchString, kSKSearchOptionDefault);
    
    SKDocumentID documents[SEARCH_BUFFER_MAX] = { 0 };
    float scores[SEARCH_BUFFER_MAX] = { 0.0 };
    CFIndex i, foundCount;
    
    Boolean more, keepGoing;
    CGFloat maxScore = 0.0f;
    NSMutableDictionary *originalScores  = [NSMutableDictionary dictionary];
    
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
                    [originalScores setObject:[NSNumber numberWithDouble:scores[i]] forKey:documentURLs[i]];
                    [foundURLSet addObject:documentURLs[i]];
                    [documentURLs[i] release];
                    maxScore = MAX(maxScore, scores[i]);
                }
            }
        }
        
        // check currentSearchString to see if a new search is queued; if so, exit this loop
        // check shouldStop in case the doc is closing while a search is in progress

        @synchronized(self) {
            keepGoing = (shouldStop == NO && [searchString isEqualToString:currentSearchString]);
        }

        if (keepGoing) {
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:foundURLSet, IDENTIFIERS_KEY, normalizedScores(originalScores, maxScore), SCORES_KEY, nil];
            [self performSelectorOnMainThread:@selector(invokeFoundCallback:) withObject:info waitUntilDone:YES];
        }
                
        @synchronized(self) {
            keepGoing = (shouldStop == NO && [searchString isEqualToString:currentSearchString]);
        }
        
    } while (keepGoing && NULL != search && more);
    
    [self performSelectorOnMainThread:@selector(invokeFinishedCallback) withObject:nil waitUntilDone:YES];
    [self _cancelSearch];
    
    [pool release];
}

- (NSArray *)previouslySelectedPublications { return previouslySelectedPublications; }

- (NSPoint)previousScrollPositionAsPercentage { return previousScrollPositionAsPercentage; }

- (void)searchForString:(NSString *)searchString index:(SKIndexRef)skIndex selectedPublications:(NSArray *)selPubs scrollPositionAsPercentage:(NSPoint)scrollPoint;
{
    [previouslySelectedPublications autorelease];
    previouslySelectedPublications = [[NSArray alloc] initWithArray:selPubs copyItems:NO];
    previousScrollPositionAsPercentage = scrollPoint;
    
    @synchronized(self) {
        [currentSearchString autorelease];
        currentSearchString = [searchString copy];
    }

    if ([self isSearching])
        [self cancelSearch];
    
    // always queue a search, since the index content may be changing (in case of a search group)
    NSInvocation *invocation = [NSInvocation invocationWithTarget:self selector:@selector(backgroundSearchForString:index:)];
    [invocation setArgument:&searchString atIndex:2];
    [invocation setArgument:&skIndex atIndex:3];
    NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithInvocation:invocation];
    [searchQueue addOperation:op];
    [op release];
}

@end
