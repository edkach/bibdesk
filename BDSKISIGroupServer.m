//
//  BDSKISIGroupServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/10/07.
/*
 This software is Copyright (c) 2007-2012
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

#import "BDSKISIGroupServer.h"
#import "BDSKISIWebServices.h"
#import "BDSKLinkedFile.h"
#import "BDSKServerInfo.h"
#import "BibItem.h"
#import "NSArray_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"

#define SERVER_URL @"http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve"

#define WOS_DB_ID @"WOS"

#define RECORDSFOUND_KEY @"recordsFound"
#define RECORDS_KEY @"records"

#define BDSKAddISIXMLStringToAnnoteKey @"BDSKAddISIXMLStringToAnnote"
#define BDSKDisableISITitleCasingKey @"BDSKDisableISITitleCasing"
#define BDSKISISourceXMLTagPriorityKey @"BDSKISISourceXMLTagPriority"
#define BDSKISIURLFieldNameKey @"BDSKISIURLFieldName"

#define DefaultISIURLFieldName @"ISI URL"

#define MAX_RESULTS 100
#ifdef DEBUG
static BOOL addXMLStringToAnnote = YES;
#else
static BOOL addXMLStringToAnnote = NO;
#endif

static BOOL useTitlecase = YES;
static NSArray *sourceXMLTagPriority = nil;
static NSString *ISIURLFieldName = nil;

static NSArray *publicationInfosWithISIXMLString(NSString *xmlString);
static NSArray *publicationInfosWithISIRefXMLString(NSString *xmlString, NSMutableArray *hotRecids);
static NSArray *replacePubInfosByField(NSArray *targetPubs, NSArray *sourcePubs, NSString *fieldName);
static NSArray *publicationsFromData(NSData *data);

// private protocols for inter-thread messaging
@protocol BDSKISIGroupServerMainThread <BDSKAsyncDOServerMainThread>
- (void)addPublicationsToGroup:(bycopy NSData *)data;
@end

@protocol BDSKISIGroupServerLocalThread <BDSKAsyncDOServerThread>
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm database:(NSString *)database;
@end

@implementation BDSKISIGroupServer

+ (BOOL)canConnect;
{
    CFURLRef theURL = (CFURLRef)[NSURL URLWithString:SERVER_URL];
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

+ (void)initialize
{
    BDSKINITIALIZE;
    // this is messy, but may be useful for debugging
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKAddISIXMLStringToAnnoteKey])
        addXMLStringToAnnote = YES;
    // try to allow for common titlecasing in Web of Science (which gives us uppercase titles)
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKDisableISITitleCasingKey])
        useTitlecase = NO;
    // prioritized list of XML tag names for getting the source field value
    sourceXMLTagPriority = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKISISourceXMLTagPriorityKey] retain];

    // set the ISI URL in a specified field name
    ISIURLFieldName = [([[NSUserDefaults standardUserDefaults] stringForKey:BDSKISIURLFieldNameKey] ?: DefaultISIURLFieldName) retain];
}

- (Protocol *)protocolForMainThread { return @protocol(BDSKISIGroupServerMainThread); }
- (Protocol *)protocolForServerThread { return @protocol(BDSKISIGroupServerLocalThread); }

- (id)initWithGroup:(id<BDSKSearchGroup>)aGroup serverInfo:(BDSKServerInfo *)info;
{
    self = [super init];
    if (self) {
        group = aGroup;
        serverInfo = [info copy];
        flags.failedDownload = 0;
        flags.isRetrieving = 0;
        availableResults = 0;
        fetchedResults = 0;
    
        [self startDOServerSync];
    }
    return self;
}

- (void)dealloc {
    group = nil;
    BDSKDESTROY(serverInfo);
    [super dealloc];
}

#pragma mark BDSKSearchGroupServer protocol

// these are called on the main thread

- (NSString *)type { return BDSKSearchGroupISI; }

- (void)reset
{
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
    OSAtomicCompareAndSwap32Barrier(availableResults, 0, &availableResults);
    OSAtomicCompareAndSwap32Barrier(fetchedResults, 0, &fetchedResults);
}

- (void)terminate
{
    [self stopDOServer];
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
}

- (void)retrieveWithSearchTerm:(NSString *)aSearchTerm
{
    if ([[self class] canConnect]) {
        OSAtomicCompareAndSwap32Barrier(1, 0, &flags.failedDownload);
        
        OSAtomicCompareAndSwap32Barrier(0, 1, &flags.isRetrieving);
        [[self serverOnServerThread] downloadWithSearchTerm:aSearchTerm database:[[self serverInfo] database]];
        
    } else {
        OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
        [self setErrorMessage:NSLocalizedString(@"Unable to connect to server", @"")];
    }
}

- (void)setServerInfo:(BDSKServerInfo *)info;
{
    if (serverInfo != info) {
        [serverInfo release];
        serverInfo = [info copy];
    }
}

- (BDSKServerInfo *)serverInfo;
{
    return serverInfo;
}

- (NSInteger)numberOfAvailableResults;
{
    OSMemoryBarrier();
    return availableResults;
}

- (NSInteger)numberOfFetchedResults;
{
    OSMemoryBarrier();
    return fetchedResults;
}

- (BOOL)failedDownload { OSMemoryBarrier(); return 1 == flags.failedDownload; }

- (BOOL)isRetrieving { OSMemoryBarrier(); return 1 == flags.isRetrieving; }

- (NSString *)errorMessage {
    NSString *msg;
    @synchronized(self) {
        msg = [[errorMessage copy] autorelease];
    }
    return msg;
}

- (void)setErrorMessage:(NSString *)newErrorMessage {
    @synchronized(self) {
        if (errorMessage != newErrorMessage) {
            [errorMessage release];
            errorMessage = [newErrorMessage copy];
        }
    }
}

- (NSFormatter *)searchStringFormatter { return nil; }

#pragma mark Main thread

- (void)addPublicationsToGroup:(bycopy NSData *)data;
{
    BDSKASSERT([NSThread isMainThread]);
    [group addPublications:publicationsFromData(data)];
}

#pragma mark Server thread

// @@ currently limited to topic search; need to figure out UI for other search types (mixing search types will require either NSTokenField or raw text string entry)
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm database:(NSString *)database;
{    
    NSArray *pubs = nil;
    NSMutableArray *identifiers = nil;
    enum operationTypes { search, retrieve, retrieveRecid, citedReferences, citingArticles, citingArticlesByRecids } operation = search;
    NSInteger availableResultsLocal = [self numberOfAvailableResults];
    NSInteger fetchedResultsLocal = [self numberOfFetchedResults];
    
    if (NO == [NSString isEmptyString:searchTerm]){
        
        /*
         TODO: document this syntax and the results thereof in the code, and in the help book.
         */
        
        NSRange prefixRange;
        if ((prefixRange = [searchTerm rangeOfString:@"RetrieveRecid:" options:NSAnchoredSearch]).location == 0) {
            searchTerm = [searchTerm substringFromIndex:NSMaxRange(prefixRange)];
            operation = retrieveRecid;
        } else if ((prefixRange = [searchTerm rangeOfString:@"CitedReferences:" options:NSAnchoredSearch]).location == 0) {
            searchTerm = [searchTerm substringFromIndex:NSMaxRange(prefixRange)];
            operation = citedReferences;
        } else if ((prefixRange = [searchTerm rangeOfString:@"CitingArticles:" options:NSAnchoredSearch]).location == 0) {
            searchTerm = [searchTerm substringFromIndex:NSMaxRange(prefixRange)];
            operation = citingArticles;
        } else if ((prefixRange = [searchTerm rangeOfString:@"CitingArticlesRecid:" options:NSAnchoredSearch]).location == 0) {
            searchTerm = [searchTerm substringFromIndex:NSMaxRange(prefixRange)];
            operation = citingArticlesByRecids;
        } else if ([searchTerm rangeOfString:@"="].location == NSNotFound)
            searchTerm = [NSString stringWithFormat:@"TS=\"%@\"", searchTerm];
        
        // Strip whitespace from the search term to make WOS happy
        searchTerm = [searchTerm stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // perform WS query to get count of results; don't pass zero for record numbers, although it's not clear what the values mean in this context
        NSDictionary *resultInfo = nil;
        NSString *resultString = nil;
        
        NSString *fields = @"doctype authors bib_vol pub_url source_title source_abbrev item_title bib_issue bib_pages keywords abstract source_series article_nos bib_date publisher pub_address issue_ed times_cited get_parent ut refs ";
        if (sourceXMLTagPriority)
            fields = [fields stringByAppendingString:[sourceXMLTagPriority componentsJoinedByString:@" "]];
        
        // @@ Currently limited to WOS database; extension to other WOS databases might require different WebService stubs?  Note that the value we're passing as database is referred to as  "edition" in the WoS docs.
        NSScanner *scanner;
        switch (operation) {
            
            case search:
                resultInfo = [BDSKISISearchRetrieveService search:WOS_DB_ID
                                                         in_query:searchTerm
                                                         in_depth:@""
                                                      in_editions:database
                                                      in_firstRec:1
                                                       in_numRecs:1];
                availableResultsLocal = [[resultInfo objectForKey:RECORDSFOUND_KEY] integerValue];
                break;
            
            case retrieve:
                resultString = [BDSKISISearchRetrieveService retrieve:WOS_DB_ID
                                                       in_primaryKeys:searchTerm
                                                              in_sort:@""
                                                            in_fields:fields];
                pubs = publicationInfosWithISIXMLString(resultString);
                availableResultsLocal = [pubs count];
                fetchedResultsLocal = [pubs count];
                break;
            
            case retrieveRecid:
                scanner = [[[NSScanner alloc] initWithString:searchTerm] autorelease];
                identifiers = [[[NSMutableArray alloc] init] autorelease];
                while ([scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:NULL]) {
                    NSString *token;
                    if ([scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&token])
                        [identifiers addObject:token];
                }
                availableResultsLocal = [identifiers count];
                break;
            
            case citedReferences:
                resultString = [BDSKISISearchRetrieveService citedReferences:WOS_DB_ID
                                                               in_primaryKey:searchTerm];
                if (resultString) {
                    NSMutableArray *hotRecids = [[[NSMutableArray alloc] init] autorelease];
                    pubs = publicationInfosWithISIRefXMLString(resultString, hotRecids);
                    NSRange retrieveRange = {0, 0};
                    while ([hotRecids count] > retrieveRange.location) {
                        retrieveRange.length = MIN((NSUInteger)MAX_RESULTS, [hotRecids count] - retrieveRange.location);
                        NSArray *subHotRecids = [hotRecids subarrayWithRange:retrieveRange];
                        NSString *fullString;
                        fullString = [BDSKISISearchRetrieveService retrieveRecid:WOS_DB_ID
                                                                        in_recid:[subHotRecids componentsJoinedByString:@" "]
                                                                         in_sort:@""
                                                                       in_fields:fields];
                        if (fullString) {
                            NSArray *fullPubs = publicationInfosWithISIXMLString(fullString);
                            if (fullPubs)
                                pubs = replacePubInfosByField(pubs, fullPubs, @"Isi-Recid");
                        }
                        retrieveRange.location += MAX_RESULTS;
                    }
                }
                availableResultsLocal = [pubs count];
                fetchedResultsLocal = [pubs count];
                break;
            
            case citingArticles:
                resultInfo = [BDSKISISearchRetrieveService citingArticles:WOS_DB_ID
                                                            in_primaryKey:searchTerm
                                                                 in_depth:@""
                                                              in_editions:database
                                                                  in_sort:@""
                                                              in_firstRec:1
                                                               in_numRecs:1
                                                                in_fields:@""];
                availableResultsLocal = [[resultInfo objectForKey:RECORDSFOUND_KEY] integerValue];
                break;
            
            case citingArticlesByRecids:
                resultInfo = [BDSKISISearchRetrieveService citingArticlesByRecids:WOS_DB_ID
                                                                        in_recids:searchTerm
                                                                         in_depth:@""
                                                                      in_editions:database
                                                                          in_sort:@""
                                                                      in_firstRec:1
                                                                       in_numRecs:1
                                                                        in_fields:@""];
                availableResultsLocal = [[resultInfo objectForKey:RECORDSFOUND_KEY] integerValue];
                break;
        }
        
        if (nil == resultString && nil == resultInfo && operation != retrieveRecid) {
            OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
            // we already know that a connection can be made, so we likely don't have permission to read this edition or database
            [self setErrorMessage:NSLocalizedString(@"Unable to retrieve results.  You may not have permission to use this database, or your query syntax may be incorrect.", @"Error message when connection to Web of Science fails.")];
        }
        
        NSInteger numResults = MIN(availableResultsLocal - fetchedResultsLocal, MAX_RESULTS);
        //NSAssert(numResults >= 0, @"number of results to get must be non-negative");
        
        if(numResults > 0) {
            // retrieve the actual XML results up to the maximum number per fetch
            switch (operation) {
                
                case search:
                    resultInfo = [BDSKISISearchRetrieveService searchRetrieve:WOS_DB_ID
                                                                     in_query:searchTerm
                                                                     in_depth:@""
                                                                  in_editions:database
                                                                      in_sort:@""
                                                                  in_firstRec:fetchedResultsLocal
                                                                   in_numRecs:numResults
                                                                    in_fields:fields];
                    resultString = [resultInfo objectForKey:RECORDS_KEY];
                    break;
                
                case retrieveRecid:
                    searchTerm = [[identifiers subarrayWithRange:NSMakeRange(fetchedResultsLocal, numResults)] componentsJoinedByString:@" "];
                    resultString = [BDSKISISearchRetrieveService retrieveRecid:WOS_DB_ID
                                                                      in_recid:searchTerm
                                                                       in_sort:@""
                                                                     in_fields:fields];
                    break;

                case citingArticles:
                    resultInfo = [BDSKISISearchRetrieveService citingArticles:WOS_DB_ID
                                                                in_primaryKey:searchTerm
                                                                     in_depth:@""
                                                                  in_editions:database
                                                                      in_sort:@""
                                                                  in_firstRec:fetchedResultsLocal
                                                                   in_numRecs:numResults
                                                                    in_fields:fields];
                    resultString = [resultInfo objectForKey:RECORDS_KEY];
                    break;
                
                case citingArticlesByRecids:
                    resultInfo = [BDSKISISearchRetrieveService citingArticlesByRecids:WOS_DB_ID
                                                                            in_recids:searchTerm
                                                                             in_depth:@""
                                                                          in_editions:database
                                                                              in_sort:@""
                                                                          in_firstRec:fetchedResultsLocal
                                                                           in_numRecs:numResults
                                                                            in_fields:fields];
                    resultString = [resultInfo objectForKey:RECORDS_KEY];
                    break;
                
                // get rid of warnings
                case retrieve:
                case citedReferences:
                    break;
            }
        
            pubs = publicationInfosWithISIXMLString(resultString);
            
            // now increment this so we don't get the same set next time; BDSKSearchGroup resets it when the searcn term changes
            fetchedResultsLocal += [pubs count];
        }
    }
    
    OSAtomicCompareAndSwap32Barrier(availableResults, availableResultsLocal, &availableResults);
    OSAtomicCompareAndSwap32Barrier(fetchedResults, fetchedResultsLocal, &fetchedResults);
    
    // set this flag before adding pubs, or the client will think we're still retrieving (and spinners don't stop)
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:pubs];
    
    // this will create the array if it doesn't exist
    [[self serverOnMainThread] addPublicationsToGroup:data];
}

#pragma mark XML Parsing

// convenience to avoid creating a local variable and checking it each time
static inline void addStringToDictionaryIfNotNil(NSString *value, NSString *key, NSMutableDictionary *dict)
{
    if (value) [dict setObject:[value stringByBackslashEscapingTeXSpecials] forKey:key];
}

// convenience to add the string value of a node; only adds if non-nil
static inline void addStringValueOfNodeForField(NSXMLNode *child, NSString *field, NSMutableDictionary *pubFields)
{
    addStringToDictionaryIfNotNil([child stringValue], field, pubFields);
}

// this returns nil if the XPath query fails, and addAuthorsFromXMLNode() relies on that behavior
static NSString *nodeStringsForXPathJoinedByString(NSXMLNode *child, NSString *XPath, NSString *join)
{
    NSArray *nodes = [child nodesForXPath:XPath error:NULL];
    NSString *toReturn = nil;
    if ([nodes count]) {
        nodes = [nodes valueForKey:@"stringValue"];
        toReturn = [nodes componentsJoinedByString:join];
    }
    return toReturn;
}

// adds authors using the most complete representation available
static void addAuthorsFromXMLNode(NSXMLNode *child, NSMutableDictionary *pubFields)
{
    // this seems to be the most complete name representation, although we could build authors from components as well
    NSString *authorString = nodeStringsForXPathJoinedByString(child, @".//AuCollectiveName", @" and ");
    if (authorString)
        [pubFields setObject:authorString forKey:BDSKAuthorString];
    else { 
        // join the subnodes by their stringValue, since that's all that's available at this point
        authorString = [[[child children] valueForKey:@"stringValue"] componentsJoinedByString:@" and "];
        if (authorString) [pubFields setObject:authorString forKey:BDSKAuthorString];
    }
}

static NSDictionary *createPublicationInfoWithRecord(NSXMLNode *record)
{
    // this is now a field/value set for a particular publication record
    NSXMLNode *child = [record childCount] ? [record childAtIndex:0] : nil;
    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    NSString *keywordSeparator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
    NSMutableDictionary *sourceTagValues = [NSMutableDictionary dictionary];
    NSString *isiURL = nil;
    
    // default values
    NSString *pubType = BDSKArticleString;
    NSString *sourceField = BDSKJournalString;
    
    /*
     I've seen "Meeting Abstract" and "Article" as common types.  However, "Geomorphology" and 
     "Estuarine Coastal and Shelf Science" articles are sometimes listed as "Proceedings Paper"
     which is clearly wrong.  Likewise, any journal with "Review" in the name is listed as a 
     "Review" type, when it should probably be a journal (e.g., "Earth Science Reviews").
     */
    NSString *docType =[[[record nodesForXPath:@"doctype" error:NULL] lastObject] stringValue];
    if ([docType isEqualToString:@"Meeting Abstract"]) {
        pubType = BDSKInproceedingsString;
        sourceField = BDSKBooktitleString;
    } else if ([docType isEqualToString:@"Article"] == NO && [docType isEqualToString:@"Review"] == NO) {
        // preserve the type if it's unclear
        addStringToDictionaryIfNotNil(docType, BDSKTypeString, pubFields);
    }
    
    [pubFields setObject:pubType forKey:BDSKPubTypeString];
    
    addStringToDictionaryIfNotNil([[(NSXMLElement *)record attributeForName:@"timescited"] stringValue], @"Times-Cited", pubFields);
    addStringToDictionaryIfNotNil([[(NSXMLElement *)record attributeForName:@"recid"] stringValue], @"Isi-Recid", pubFields);
        
    while (nil != child) {
        
        NSString *name = [child name];
        
        if ([name isEqualToString:@"item_title"])
            addStringValueOfNodeForField(child, BDSKTitleString, pubFields);
        else if ([name isEqualToString:@"source_title"])
            addStringToDictionaryIfNotNil((useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue]), sourceField, pubFields);
        else if ([name isEqualToString:@"source_abbrev"])
            addStringToDictionaryIfNotNil((useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue]), @"Iso-Source-Abbreviation", pubFields);
        else if ([name isEqualToString:@"authors"])
            addAuthorsFromXMLNode(child, pubFields);
        else if ([name isEqualToString:@"abstract"])
            // abstract is broken into paragraphs; we'll use a double newline as separator
            addStringToDictionaryIfNotNil( nodeStringsForXPathJoinedByString(child, @"p", @"\n\n"), BDSKAbstractString, pubFields);
        else if ([name isEqualToString:@"keywords"])
            addStringToDictionaryIfNotNil( nodeStringsForXPathJoinedByString(child, @".//keyword", keywordSeparator), BDSKKeywordsString, pubFields);
        else if ([name isEqualToString:@"bib_pages"]) {
            NSString *begin = [[(NSXMLElement *)child attributeForName:@"begin"] stringValue];
            NSString *end = [[(NSXMLElement *)child attributeForName:@"end"] stringValue];
            if (NO == [NSString isEmptyString:begin] && NO == [NSString isEmptyString:end])
                addStringToDictionaryIfNotNil([NSString stringWithFormat:@"%@--%@", begin, end], BDSKPagesString, pubFields);
            else if (NO == [NSString isEmptyString:begin])
                addStringToDictionaryIfNotNil(begin, BDSKPagesString, pubFields);
            else if (NO == [[child stringValue] isEqualToString:@"-"])
                addStringValueOfNodeForField(child, BDSKPagesString, pubFields);
        }
        else if ([name isEqualToString:@"bib_issue"] && [child kind] == NSXMLElementKind) {
            addStringValueOfNodeForField([(NSXMLElement *)child attributeForName:@"year"], BDSKYearString, pubFields);
            addStringValueOfNodeForField([(NSXMLElement *)child attributeForName:@"vol"], BDSKVolumeString, pubFields);
        }
        else if ([name isEqualToString:@"article_nos"]) {
            // for current journals, these are DOI strings, which doesn't follow from the name or the description
            addStringValueOfNodeForField([[child nodesForXPath:@"./article_no[starts-with(., 'DOI')]" error:NULL] lastObject], BDSKDoiString, pubFields);
            if ([pubFields objectForKey:BDSKPagesString] == nil) {
                NSString *artnum = [[[child nodesForXPath:@"./article_no[starts-with(., 'ARTN ')]" error:NULL] lastObject] stringValue];
                addStringToDictionaryIfNotNil([artnum stringByRemovingPrefix:@"ARTN "], BDSKPagesString, pubFields);
            }
        }
        else if ([name isEqualToString:@"source_series"])
            addStringValueOfNodeForField(child, BDSKSeriesString, pubFields);
        else if ([name isEqualToString:@"bib_date"] && [child kind] == NSXMLElementKind) {
            /* 
             There are at least 3 variants of this, so it's not always possible to get something
             truly useful from it.
             
             <bib_date date="AUG" year="2008">AUG 2008</bib_date>
             <bib_date date="JUN 19" year="2008">JUN 19 2008</bib_date>
             <bib_date date="MAR-APR" year="2007">MAR-APR 2007</bib_date>
             */
            NSString *possibleMonthString = [[(NSXMLElement *)child attributeForName:@"date"] stringValue];
            NSString *monthString;
            NSScanner *scanner = nil;
            if (possibleMonthString)
                scanner = [[NSScanner alloc] initWithString:possibleMonthString];
            static NSCharacterSet *monthSet = nil;
            if (nil == monthSet) {
                NSMutableCharacterSet *cset = [[NSCharacterSet letterCharacterSet] mutableCopy];
                [cset addCharactersInString:@"-"];
                monthSet = [cset copy];
                [cset release];
            }
            if ([scanner scanCharactersFromSet:monthSet intoString:&monthString]) {
                if ([monthString rangeOfString:@"-"].length == 0)
                    monthString = [NSString stringWithBibTeXString:[monthString lowercaseString] macroResolver:nil error:NULL];
                else
                    monthString = [monthString titlecaseString];
                addStringToDictionaryIfNotNil(monthString, BDSKMonthString, pubFields);
            }
            else
                addStringToDictionaryIfNotNil(possibleMonthString, BDSKDateString, pubFields);
            [scanner release];
        }
        
        // @@ remainder are untested (they're empty in all of my search results) so may be NSXMLElements
        else if ([name isEqualToString:@"pub_url"])
            addStringValueOfNodeForField(child, BDSKUrlString, pubFields);
        else if ([name isEqualToString:@"bib_vol"])
            addStringToDictionaryIfNotNil([[(NSXMLElement *)child attributeForName:@"issue"] stringValue], BDSKNumberString, pubFields);
        else if ([name isEqualToString:@"publisher"])
            addStringValueOfNodeForField(child, BDSKPublisherString, pubFields);
        else if ([name isEqualToString:@"pub_address"])
            addStringValueOfNodeForField(child, BDSKAddressString, pubFields);
        else if ([name isEqualToString:@"ut"]) {
            addStringValueOfNodeForField(child, @"Isi", pubFields);
            isiURL = [@"http://gateway.isiknowledge.com/gateway/Gateway.cgi?GWVersion=2&SrcAuth=Alerting&SrcApp=Alerting&DestApp=WOS&DestLinkType=FullRecord;KeyUT=" stringByAppendingString:[pubFields objectForKey:@"Isi"]];
            [pubFields setObject:isiURL forKey:ISIURLFieldName];
        } else if ([name isEqualToString:@"refs"])
            addStringToDictionaryIfNotNil( nodeStringsForXPathJoinedByString(child, @".//ref", @" "), @"Isi-Ref-Recids", pubFields);
        
        // check to see if the current tag name matches an item in the source XML tag priority list
        NSString *sourceTagValue;
        for (NSString *sourceTagName in sourceXMLTagPriority) {
            if ([name isEqualToString:sourceTagName]) {
                sourceTagValue = (useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue]);
                if (sourceTagValue && [sourceTagValue length])
                    [sourceTagValues setObject:sourceTagValue forKey:sourceTagName];
            }
        }
        
        child = [child nextSibling];
    }
    
    // if source field value(s) are in the priority list, subtitute the first one
    if ([sourceTagValues count]) {
        NSString *sourceTagValue;
        for (NSString *sourceTagName in sourceXMLTagPriority) {
            if ((sourceTagValue = [sourceTagValues objectForKey:sourceTagName])) {
                [pubFields setObject:sourceTagValue forKey:sourceField];
                break;
            }
        }
    }
    
    // mainly useful for debugging
    if (addXMLStringToAnnote)
        addStringToDictionaryIfNotNil([record XMLString], BDSKAnnoteString, pubFields);
    
    return pubFields;
}

static NSArray *publicationInfosWithISIXMLString(NSString *xmlString)
{
    NSCParameterAssert(nil != xmlString);
    NSError *error;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:xmlString options:0 error:&error] autorelease];
    if (nil == xmlDoc) {
        NSLog(@"failed to create XML document from ISI string.  %@", error);
        return nil;
    }
    
    NSArray *records = [xmlDoc nodesForXPath:@"/RECORDS/REC" error:&error];
    if (nil == records)
        NSLog(@"%@", error);
    
    NSXMLNode *record = [records firstObject];
    NSMutableArray *pubs = [NSMutableArray array];
    
    while (nil != record) {
        
        NSDictionary *pub = createPublicationInfoWithRecord(record);
        [pubs addObject:pub];
        [pub release];
        
        record = [record nextSibling];
    }
    return pubs;
}

static NSDictionary *createPublicationInfoWithRefRecord(NSXMLNode *record)
{
    // this is now a field/value set for a particular publication record
    NSXMLNode *child = [record childCount] ? [record childAtIndex:0] : nil;
    NSMutableDictionary *pubFields = [NSMutableDictionary new];

    // fallback values
    NSString *sourceField = BDSKJournalString;
    
    [pubFields setObject:BDSKArticleString forKey:BDSKPubTypeString];
    
    addStringToDictionaryIfNotNil([[(NSXMLElement *)record attributeForName:@"timescited"] stringValue], @"Timescited", pubFields);
    addStringToDictionaryIfNotNil([[(NSXMLElement *)record attributeForName:@"recid"] stringValue], @"Isi-Recid", pubFields);
    
    // if there is no ISI data for the publication (hot==no), then set the title to Unknown
    //if ([(NSXMLElement *)record attributeForName:@"hot"] && 
    //    [[[(NSXMLElement *)record attributeForName:@"hot"] stringValue] isEqualToString:@"no"])
    //    addStringToDictionaryIfNotNil(@"Unknown", BDSKTitleString, pubFields);
        
    while (nil != child) {

        NSString *name = [child name];
        
        if ([name isEqualToString:@"AU"]) {
            NSArray *authorTokens = [[child stringValue] componentsSeparatedByString:@" "];
            if ([authorTokens count] == 2) {
                NSString *lastName = [authorTokens objectAtIndex:0];
                NSString *firstInitials = [authorTokens objectAtIndex:1];
                NSString *authorName = [[lastName capitalizedString] stringByAppendingFormat:@", %@", firstInitials];
                addStringToDictionaryIfNotNil(authorName, BDSKAuthorString, pubFields);
            } else
                addStringValueOfNodeForField(child, BDSKAuthorString, pubFields);
        } else if ([name isEqualToString:@"J2"])
            addStringToDictionaryIfNotNil((useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue]), sourceField, pubFields);
        else if ([name isEqualToString:@"PY"])
            addStringValueOfNodeForField(child, BDSKYearString, pubFields);
        else if ([name isEqualToString:@"VL"])
            addStringValueOfNodeForField(child, BDSKVolumeString, pubFields);
        else if ([name isEqualToString:@"BP"])
            addStringValueOfNodeForField(child, BDSKPagesString, pubFields);
        else if ([name isEqualToString:@"AR"])
            addStringValueOfNodeForField(child, BDSKPagesString, pubFields);

        child = [child nextSibling];
    }
    
    // mainly useful for debugging
    if (addXMLStringToAnnote)
        addStringToDictionaryIfNotNil([record XMLString], BDSKAnnoteString, pubFields);
    
    return pubFields;
}

static NSArray *publicationInfosWithISIRefXMLString(NSString *xmlString, NSMutableArray *hotRecids)
{
    NSCParameterAssert(nil != xmlString);
    NSError *error;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:xmlString options:0 error:&error] autorelease];
    if (nil == xmlDoc) {
        NSLog(@"failed to create XML document from ISI referece string.  %@", error);
        return nil;
    }
    
    NSArray *records = [xmlDoc nodesForXPath:@"/RECORDS/REC" error:&error];
    if (nil == records)
        NSLog(@"%@", error);
    
    NSXMLNode *record = [records firstObject];
    NSMutableArray *pubs = [NSMutableArray array];
    
    while (nil != record) {
        
        NSDictionary *pub = createPublicationInfoWithRefRecord(record);
        [pubs addObject:pub];
        [pub release];
        
        if ([(NSXMLElement *)record attributeForName:@"hot"] && 
            [[[(NSXMLElement *)record attributeForName:@"hot"] stringValue] isEqualToString:@"yes"] &&
            [(NSXMLElement *)record attributeForName:@"recid"])
            [hotRecids addObject:[[(NSXMLElement *)record attributeForName:@"recid"] stringValue]];
        
        record = [record nextSibling];
    }
    return pubs;
}

static NSArray *replacePubInfosByField(NSArray *targetPubs, NSArray *sourcePubs, NSString *fieldName)
{
    NSMutableArray *outPubs = [NSMutableArray arrayWithCapacity:[targetPubs count]];
    NSMutableDictionary *sourcePubIndex = [NSMutableDictionary dictionaryWithCapacity:[sourcePubs count]];
    NSDictionary *pub;
    NSString *value;
    NSDictionary *replacedPub;
    
    for (pub in sourcePubs) {
        if ((value = [pub objectForKey:fieldName]))
            [sourcePubIndex setValue:pub forKey:value];
    }
    
    for (pub in targetPubs) {
        if ((value = [pub objectForKey:fieldName]) &&
            (replacedPub = [sourcePubIndex objectForKey:value]))
            pub = replacedPub;
        [outPubs addObject:pub]; 
    }
    
    return outPubs;
}

static NSArray *publicationsFromData(NSData *data) {
    NSArray *pubInfos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSMutableArray *pubs = [NSMutableArray arrayWithCapacity:[pubInfos count]];
    for (NSDictionary *pubInfo in pubInfos) {
        NSMutableDictionary *pubFields = [pubInfo mutableCopy];
        NSArray *files = nil;
        
        NSString *pubType = [pubFields objectForKey:BDSKPubTypeString];
        [pubFields removeObjectForKey:BDSKPubTypeString];
        
        // insert the ISI URL into the normal file array if hasn't been put elsewhere
        NSString *isiURL = [pubFields objectForKey:DefaultISIURLFieldName];
        if (isiURL) {
            files = [[NSMutableArray alloc] initWithObjects:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithStringByNormalizingPercentEscapes:isiURL] delegate:nil], nil];
            [pubFields removeObjectForKey:DefaultISIURLFieldName];
        }
        
        BibItem *pub = [[BibItem alloc] initWithType:pubType citeKey:nil pubFields:pubFields files:files isNew:YES];
        
        [pubs addObject:pub];
        [pub release];
        [pubFields release];
        [files release];
    }
    return pubs;
}

@end
