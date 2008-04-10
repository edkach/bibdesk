//
//  BDSKDBLPGroupServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 4/2/08.
/*
 This software is Copyright (c) 2008
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
#import "BDSKDBLPGroupServer.h"
#import "BDSKDBLPWebServices.h"
#import "BDSKServerInfo.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BDSKBibTeXParser.h"
#import "NSArray_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"

// private protocols for inter-thread messaging
@protocol BDSKDBLPGroupServerMainThread <BDSKAsyncDOServerMainThread>
- (void)addPublicationsToGroup:(bycopy NSArray *)pubs;
@end

@protocol BDSKDBLPGroupServerLocalThread <BDSKAsyncDOServerThread>
- (int)availableResults;
- (void)setAvailableResults:(int)value;
- (int)fetchedResults;
- (void)setFetchedResults:(int)value;
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm;
@end


@implementation BDSKDBLPGroupServer

+ (BOOL)canConnect;
{
    CFURLRef theURL = (CFURLRef)[NSURL URLWithString:@"http://dblp.uni-trier.de"];
    CFNetDiagnosticRef diagnostic = CFNetDiagnosticCreateWithURL(CFGetAllocator(theURL), theURL);
    
    NSString *details;
    CFNetDiagnosticStatus status = CFNetDiagnosticCopyNetworkStatusPassively(diagnostic, (CFStringRef *)&details);
    CFRelease(diagnostic);
    [details autorelease];
    
    BOOL canConnect = kCFNetDiagnosticConnectionUp == status;
    if (NO == canConnect)
        NSLog(@"%@", details);
    
    return canConnect;
}

- (Protocol *)protocolForMainThread { return @protocol(BDSKDBLPGroupServerMainThread); }
- (Protocol *)protocolForServerThread { return @protocol(BDSKDBLPGroupServerLocalThread); }

- (id)initWithGroup:(BDSKSearchGroup *)aGroup serverInfo:(BDSKServerInfo *)info;
{
    self = [super init];
    if (self) {
        group = aGroup;
        serverInfo = [info copy];
        flags.failedDownload = 0;
        flags.isRetrieving = 0;
        availableResults = 0;
        fetchedResults = 0;
        pthread_rwlock_init(&infolock, NULL);
        
        [self startDOServerSync];
    }
    return self;
}

- (void)dealloc {
    pthread_rwlock_destroy(&infolock);
    [serverInfo release];
    serverInfo = nil;
    [super dealloc];
}

#pragma mark BDSKSearchGroupServer protocol

// these are called on the main thread

- (void)terminate
{
    [self stopDOServer];
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
}

- (void)stop
{
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
}

- (void)retrievePublications
{
    if ([[self class] canConnect]) {
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.failedDownload);
        
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.isRetrieving);
        [[self serverOnServerThread] downloadWithSearchTerm:[group searchTerm]];
        
    } else {
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.failedDownload);
        NSError *presentableError = [NSError mutableLocalErrorWithCode:kBDSKNetworkConnectionFailed localizedDescription:NSLocalizedString(@"Unable to connect to server", @"")];
        [NSApp presentError:presentableError];
    }
}

- (void)setServerInfo:(BDSKServerInfo *)info;
{
    pthread_rwlock_wrlock(&infolock);
    if (serverInfo != info) {
        [serverInfo release];
        serverInfo = [info copy];
    }
    pthread_rwlock_unlock(&infolock);
}

- (BDSKServerInfo *)serverInfo;
{
    pthread_rwlock_rdlock(&infolock);
    BDSKServerInfo *info = [[serverInfo copy] autorelease];
    pthread_rwlock_unlock(&infolock);
    return info;
}

- (void)setNumberOfAvailableResults:(int)value;
{
    [[self serverOnServerThread] setAvailableResults:value];
}

- (int)numberOfAvailableResults;
{
    return [[self serverOnServerThread] availableResults];
}

- (void)setNumberOfFetchedResults:(int)value;
{
    [[self serverOnServerThread] setFetchedResults:value];
}

- (int)numberOfFetchedResults;
{
    return [[self serverOnServerThread] fetchedResults];
}

- (BOOL)failedDownload { OSMemoryBarrier(); return 1 == flags.failedDownload; }

- (BOOL)isRetrieving { OSMemoryBarrier(); return 1 == flags.isRetrieving; }
- (NSFormatter *)searchStringFormatter { return nil; }

#pragma mark Main thread

- (void)addPublicationsToGroup:(bycopy NSArray *)pubs;
{
    OBASSERT([NSThread inMainThread]);
    [group addPublications:pubs];
}

#pragma mark Server thread

- (void)setAvailableResults:(int)value;
{
    availableResults = value;
}

- (int)availableResults;
{
    return availableResults;
}

- (void)setFetchedResults:(int)value;
{
    fetchedResults = value;
}

- (int)fetchedResults;
{
    return fetchedResults;
}

- (NSArray *)resultsWithSearchTerm:(NSString *)searchTerm
{
    BDSKServerInfo *info = [self serverInfo];
    
    // no UI for providing years, so use 1900--present
    NSNumber *startYear = [NSNumber numberWithInt:1900];
    NSNumber *endYear = [NSNumber numberWithInt:[[NSCalendarDate date] yearOfCommonEra]];
    
    NSArray *searchResults = nil;
    if ([[info database] caseInsensitiveCompare:@"authors"] == NSOrderedSame) {
        BibAuthor *author = [BibAuthor authorWithName:searchTerm andPub:nil];
        searchResults = [DBLPPlusPlusService all_publications_author_year:([author firstName] ? [author firstName] : @"")
                                                            in_familyName:([author lastName] ? [author lastName] : @"")
                                                             in_startYear:startYear
                                                               in_endYear:endYear];
    }
    else {
        searchResults = [DBLPPlusPlusService all_publications_keywords_year:searchTerm
                                                               in_startYear:startYear 
                                                                 in_endYear:endYear
                                                                   in_limit:[NSNumber numberWithInt:100]];
    }
    return searchResults;
}

static void fixEEURL(BibItem *pub)
{
    NSMutableString *URLString = [NSMutableString stringWithString:[pub valueOfField:[@"ee" fieldName] inherit:NO]];
    // some URLs have been converted for compatibility with TeX
    [URLString replaceOccurrencesOfString:@"{\\&}" withString:@"&" options:0 range:NSMakeRange(0, [URLString length])];
    NSURL *aURL;
    if ([NSString isEmptyString:URLString] == NO && (aURL = [NSURL URLWithString:URLString]) != nil) {
        
        // some refs have a partial URL in the ee field that uses this as a base
        if (nil == [aURL scheme]) {
            [URLString insertString:@"http://dblp.uni-trier.de/" atIndex:0];
            aURL = [NSURL URLWithString:URLString];
        }
        
        if ([pub addFileForURL:aURL autoFile:NO runScriptHook:NO])
            [pub setField:[@"ee" fieldName] toValue:nil];
    }
}

// Note:  WSGeneratedObj doesn't supply a way to cancel a request, so calling downloadWithSearchTerm: again with a non-empty string before the first request completes will cause a beachball.  This is mainly a problem on slow network connections.
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm;
{    
    NSArray *pubs = nil;
    if (NO == [NSString isEmptyString:searchTerm]){
        
        NSArray *dblpKeys = [[self resultsWithSearchTerm:searchTerm] valueForKeyPath:@"dblp_key"];
        [self setAvailableResults:[dblpKeys count]];

        NSMutableSet *btEntries = [NSMutableSet set];
        NSMutableDictionary *abstracts = [NSMutableDictionary dictionary];
        NSEnumerator *objEnum = [dblpKeys objectEnumerator];
        NSString *aKey;
        while ((aKey = [objEnum nextObject]) && flags.isRetrieving) {
            
            NSURL *theURL = [NSURL URLWithString:[@"http://dblp.uni-trier.de/rec/bibtex/" stringByAppendingString:aKey]];
            NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:theURL options:NSXMLDocumentTidyHTML error:NULL];
            
            NSArray *btNodes = [doc nodesForXPath:@"//pre" error:NULL];
            NSEnumerator *nodeEnum = [btNodes objectEnumerator];
            NSXMLNode *aNode;
            while (aNode = [nodeEnum nextObject])
                [btEntries addObject:[aNode stringValue]];
            
            [doc release];
            
            NSDictionary *pubData = [[DBLPPlusPlusService publication_data:aKey] lastObject];
            if ([pubData objectForKey:@"abstract"])
                [abstracts setObject:[pubData objectForKey:@"abstract"] forKey:aKey];
        }
        
        NSString *btString = [[btEntries allObjects] componentsJoinedByString:@"\n"];
        pubs = [BDSKBibTeXParser itemsFromString:btString document:group isPartialData:NULL error:NULL];
        objEnum = [pubs objectEnumerator];
        BibItem *pub;
        while ((pub = [objEnum nextObject]) && flags.isRetrieving) {
            
            aKey = [[pub citeKey] stringByRemovingPrefix:@"DBLP:"];
            id value = [abstracts objectForKey:aKey];
            if (value && [value isEqual:[NSNull null]] == NO)
                [pub setValue:value forKey:BDSKAbstractString];
            
            fixEEURL(pub);
        }
        
        [self setAvailableResults:[pubs count]];
        [self setFetchedResults:[pubs count]];
        
    }
    
    // set this flag before adding pubs, or the client will think we're still retrieving (and spinners don't stop)
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
    
    // this will create the array if it doesn't exist
    [[self serverOnMainThread] addPublicationsToGroup:pubs];
}

@end
