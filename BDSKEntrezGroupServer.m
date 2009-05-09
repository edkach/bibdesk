//
//  BDSKEntrezGroupServer.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/28/06.
/*
 This software is Copyright (c) 2006-2009
 Christiaan Hofman. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Christiaan Hofman nor the names of any
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

// max number of results from NCBI is 100, except on evenings and weekends
#define MAX_RESULTS 50

/* Based on public domain sample code written by Oleg Khovayko, available at
 http://www.ncbi.nlm.nih.gov/entrez/query/static/eutils_example.pl
 
 - We limit requests to 100 in the editor interface, per NCBI's request.  
 - We also pass tool=bibdesk for their tracking purposes.  
 - We use lower case characters in the URL /except/ for WebEnv
 - See http://www.ncbi.nlm.nih.gov/entrez/query/static/eutils_help.html for details.
 
 */

#import "BDSKEntrezGroupServer.h"
#import "BDSKSearchGroup.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringParser.h"
#import "BDSKAppController.h"
#import <WebKit/WebKit.h>
#import "BDSKServerInfo.h"
#import "NSError_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKPubMedXMLParser.h"

@implementation BDSKEntrezGroupServer

enum { BDSKIdleState, BDSKEsearchState, BDSKEfetchState };

+ (NSString *)baseURLString { return @"http://eutils.ncbi.nlm.nih.gov/entrez/eutils"; }

// may be useful for UI validation
+ (BOOL)canConnect;
{
    CFURLRef theURL = (CFURLRef)[NSURL URLWithString:[self baseURLString]];
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

- (id)initWithGroup:(BDSKSearchGroup *)aGroup serverInfo:(BDSKServerInfo *)info;
{
    self = [super init];
    if (self) {
        group = aGroup;
        serverInfo = [info copy];
        searchTerm = nil;
        failedDownload = NO;
        needsReset = NO;
        availableResults = 0;
        filePath = nil;
        URLDownload = nil;
        downloadState = BDSKIdleState;
    }
    return self;
}

- (void)dealloc
{
    [filePath release];
    [serverInfo release];
    [webEnv release];
    [queryKey release];
    [super dealloc];
}

#pragma mark BDSKSearchGroupServer protocol

- (void)terminate;
{
    [self stop];
}

- (void)stop;
{
    [URLDownload cancel];
    [URLDownload release];
    URLDownload = nil;
    downloadState = BDSKIdleState;
    if (filePath) {
        [[NSFileManager defaultManager] removeFileAtPath:filePath handler:nil];
        [filePath release];
        filePath = nil;
    }
}

- (void)retrievePublications {
    if ([[self class] canConnect]) {
        isRetrieving = YES;
        if ([[self searchTerm] isEqualToString:[group searchTerm]] == NO || needsReset)
            [self resetSearch];
        else if ([self isRetrieving] == NO)
            [self fetch];
    } else {
        failedDownload = YES;
        
        NSError *presentableError = [NSError mutableLocalErrorWithCode:kBDSKNetworkConnectionFailed localizedDescription:NSLocalizedString(@"Unable to connect to server", @"error when pubmed connection fails")];
        [NSApp presentError:presentableError];
    }
}

- (BDSKServerInfo *)serverInfo { return serverInfo; }

- (void)setServerInfo:(BDSKServerInfo *)info;
{
    if(serverInfo != info){
        [serverInfo release];
        serverInfo = [info copy];
        needsReset = YES;
    }
}

- (void)setNumberOfAvailableResults:(NSInteger)value;
{
    availableResults = value;
}

- (NSInteger)numberOfFetchedResults { return fetchedResults; }

- (void)setNumberOfFetchedResults:(NSInteger)value;
{
    fetchedResults = value;
}

- (NSInteger)numberOfAvailableResults { return availableResults; }

- (BOOL)failedDownload { return failedDownload; }

- (BOOL)isRetrieving { return BDSKIdleState != downloadState; }

- (NSFormatter *)searchStringFormatter { return nil; }

#pragma mark Other accessors

- (void)setSearchTerm:(NSString *)string;
{
    if(searchTerm != string){
        [searchTerm release];
        searchTerm = [string copy];
    }
}

- (NSString *)searchTerm { return searchTerm; }

- (void)setWebEnv:(NSString *)env;
{
    if(webEnv != env){
        [webEnv release];
        webEnv = [env copy];
    }
}

- (NSString *)webEnv { return webEnv; }

- (void)setQueryKey:(NSString *)aKey;
{
    if(queryKey != aKey){
        [queryKey release];
        queryKey = [aKey copy];
    }
}

- (NSString *)queryKey { return queryKey; }

#pragma mark Search methods

- (void)resetSearch;
{
    [self setSearchTerm:[group searchTerm]];
    [self setWebEnv:nil];
    [self setQueryKey:nil];
    [self setNumberOfAvailableResults:0];
    [self setNumberOfFetchedResults:0];
    
    NSXMLDocument *document = nil;
    
    if(NO == [NSString isEmptyString:[self searchTerm]]){
        // get the initial XML document with our search parameters in it
        NSString *esearch = [[[self class] baseURLString] stringByAppendingFormat:@"/esearch.fcgi?db=%@&retmax=1&usehistory=y&term=%@&tool=bibdesk", [[self serverInfo] database], [[self searchTerm] stringByAddingPercentEscapesIncludingReserved]];
        NSURL *initialURL = [NSURL URLWithString:esearch]; 
        BDSKPRECONDITION(initialURL);
        
        downloadState = BDSKEsearchState;
        [self startDownloadFromURL:initialURL];
        needsReset = NO;
    }
}

- (void)fetch;
{
    if ([self webEnv] == nil || [self queryKey] == nil || [self numberOfAvailableResults] <= [self numberOfFetchedResults]) {
        [group addPublications:[NSArray array]];
        return;
    }
    
    BDSKPRECONDITION(downloadState == BDSKIdleState);
    NSInteger numResults = MIN([self numberOfAvailableResults] - [self numberOfFetchedResults], MAX_RESULTS);
    
    // need to escape queryKey, but the rest should be valid for a URL
    NSString *efetch = [[[self class] baseURLString] stringByAppendingFormat:@"/efetch.fcgi?rettype=abstract&retmode=xml&retstart=%ld&retmax=%ld&db=%@&query_key=%@&WebEnv=%@&tool=bibdesk", (long)[self numberOfFetchedResults], (long)numResults, [[self serverInfo] database], [[self queryKey] stringByAddingPercentEscapesIncludingReserved], [self webEnv]];
    NSURL *theURL = [NSURL URLWithString:efetch];
    BDSKPOSTCONDITION(theURL);
    
    [self setNumberOfFetchedResults:[self numberOfFetchedResults] + numResults];
    
    downloadState = BDSKEfetchState;
    [self startDownloadFromURL:theURL];
}

#pragma mark URL download

- (void)startDownloadFromURL:(NSURL *)theURL;
{
    NSURLRequest *request = [NSURLRequest requestWithURL:theURL];
    // we use a WebDownload since it's supposed to add authentication dialog capability
    if (URLDownload)
        [URLDownload cancel];
    [URLDownload release];
    URLDownload = [[WebDownload alloc] initWithRequest:request delegate:self];
    [URLDownload setDestination:[[NSFileManager defaultManager] temporaryFileWithBasename:nil] allowOverwrite:NO];
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
    [filePath autorelease];
    filePath = [path copy];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
    failedDownload = NO;
    NSError *presentableError;
    
    if (URLDownload) {
        [URLDownload release];
        URLDownload = nil;
    }
    
    NSURL *downloadURL = filePath ? [NSURL fileURLWithPath:filePath] : nil;
    [filePath release];
    filePath = nil;
    
    switch (downloadState) {
        case BDSKEsearchState:
        {
            // okay to reset state before calling -fetch
            downloadState = BDSKIdleState;

            NSError *error;
            NSXMLDocument *document = nil;
            if (downloadURL)
                document = [[NSXMLDocument alloc] initWithContentsOfURL:downloadURL options:NSXMLNodeOptionsNone error:&error];

            if (nil != document) {
                NSXMLElement *root = [document rootElement];
                
                // we need to extract WebEnv, Count, and QueryKey to construct our final URL
                [self setWebEnv:[[[root nodesForXPath:@"/eSearchResult[1]/WebEnv[1]" error:NULL] lastObject] stringValue]];
                [self setQueryKey:[[[root nodesForXPath:@"/eSearchResult[1]/QueryKey[1]" error:NULL] lastObject] stringValue]];
                NSString *countString = [[[root nodesForXPath:@"/eSearchResult[1]/Count[1]" error:NULL] lastObject] stringValue];
                [self setNumberOfAvailableResults:[countString intValue]];
                
                [document release];
                [self fetch];
                
            } else {
                
                // no document, or zero length data from the server
                failedDownload = YES;

                presentableError = [NSError mutableLocalErrorWithCode:kBDSKNetworkConnectionFailed localizedDescription:NSLocalizedString(@"Unable to connect to server", @"error when pubmed connection fails")];
                
                [presentableError embedError:error];
                [NSApp presentError:presentableError];
            }
            
            break;
        }
        case BDSKEfetchState:
        {
            // specifically requested the XML type, so go straight to the correct parser
            NSArray *pubs = [BDSKPubMedXMLParser itemsFromData:[NSData dataWithContentsOfMappedFile:[downloadURL path]] error:&presentableError];
            
            if (nil == pubs) {
                failedDownload = YES;
                [NSApp presentError:presentableError];
            }
            else {
                [group addPublications:pubs];
            }
            downloadState = BDSKIdleState;
            break;
        }
        case BDSKIdleState:
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Unhandled case %d", downloadState];
            break;
    }
    
    // don't reset downloadState here, or we clobber the value that -fetch sets
    
    // it's always okay to delete the original download, but filePath will be reset at some point as a side effect of -fetch
    if (downloadURL)
        [[NSFileManager defaultManager] removeFileAtPath:[downloadURL path] handler:nil];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
    downloadState = BDSKIdleState;
    failedDownload = YES;
    
    if (URLDownload) {
        [URLDownload release];
        URLDownload = nil;
    }
    
    if (filePath) {
        [[NSFileManager defaultManager] removeFileAtPath:filePath handler:nil];
        [filePath release];
        filePath = nil;
    }
    
    // redraw 
    [group addPublications:nil];
    [NSApp presentError:error];
}

@end
