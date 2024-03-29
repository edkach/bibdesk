//
//  BDSKBibDeskProtocol.m
//  Bibdesk
//
//  Created by Sven-S. Porst on 12.04.09.
/*
 This software is Copyright (c) 2009-2012
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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

/* 
	Mostly nicked from Apple's PictureBrowser example project.
*/

#import "BDSKBibDeskProtocol.h"
#import "BDSKWebParser.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import <WebKit/WebView.h>
#import "BDSKTemplateParser.h"
#import "BDSKDownloadManager.h"

#define WEBGROUP_SPECIFIER  @"webgroup"
#define DOWNLOADS_SPECIFIER @"downloads"
#define FILEICON_SPECIFIER  @"fileicon:"
#define HELP_SPECIFIER      @"help"
#define HELP_DIRECTORY      @"BibDeskHelp"
#define HELP_START_FILE     @"BibDeskHelp.html"

NSString *BDSKBibDeskScheme = @"bibdesk";

@interface BDSKBibDeskProtocol (Private)
- (NSData *)HTMLDataUsingTemplateFile:(NSString *)template usingObject:(id)object;
@end

@implementation BDSKBibDeskProtocol

/*
 Only accept the bibdesk:webgroup URL.
*/
+ (BOOL)canInitWithRequest:(NSURLRequest *)theRequest {
	return [[[theRequest URL] scheme] isCaseInsensitiveEqual:BDSKBibDeskScheme];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

/*
 Immediately provide the requested data.
*/ 
- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType {
    id<NSURLProtocolClient> client = [self client];
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[[self request] URL] MIMEType:MIMEType expectedContentLength:[data length] textEncodingName:[MIMEType isEqualToString:@"text/html"] ? @"utf-8" : nil];
    [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [client URLProtocol:self didLoadData:data];
    [client URLProtocolDidFinishLoading:self];
    [response release];
}

- (void)startLoading {
    id<NSURLProtocolClient> client = [self client];
    NSURLRequest *request = [self request];
    NSURL *theURL = [request URL];
    NSString *resourceSpecifier = [theURL resourceSpecifier];
	
    if ([WEBGROUP_SPECIFIER isCaseInsensitiveEqual:resourceSpecifier]) {
        static NSData *welcomeHTMLData = nil;
        if (welcomeHTMLData == nil)
            welcomeHTMLData = [[self HTMLDataUsingTemplateFile:@"WebGroupStartPage" usingObject:[BDSKWebParser class]] copy];
        [self loadData:welcomeHTMLData MIMEType:@"text/html"];
    } else if ([DOWNLOADS_SPECIFIER isCaseInsensitiveEqual:resourceSpecifier]) {
        NSData *data = [self HTMLDataUsingTemplateFile:@"WebGroupDownloads" usingObject:[BDSKDownloadManager sharedManager]];
        [self loadData:data MIMEType:@"text/html"];
    } else if ([resourceSpecifier hasCaseInsensitivePrefix:FILEICON_SPECIFIER]) {
        NSString *extension = [resourceSpecifier substringFromIndex:[FILEICON_SPECIFIER length]];
        NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
        [self loadData:[icon TIFFRepresentation] MIMEType:@"image/tiff"];
    } else if ([HELP_SPECIFIER isCaseInsensitiveEqual:[[resourceSpecifier pathComponents] firstObject]]) {
        // when there's no "//" the URL we get has percent escapes including in particular the # character, which would we don't want
        NSString *URLString = [NSString stringWithFormat:@"%@://%@", BDSKBibDeskScheme, [resourceSpecifier stringByReplacingPercentEscapes]];
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:theURL MIMEType:@"text/html" expectedContentLength:-1 textEncodingName:nil];
        NSURLRequest *redirectRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithStringByNormalizingPercentEscapes:URLString]];
        [client URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
        [client URLProtocolDidFinishLoading:self];
        [response release];
        [redirectRequest release];
    } else if ([HELP_SPECIFIER isCaseInsensitiveEqual:[theURL host]]) {
        NSString *path = [theURL path];
        if ([path hasPrefix:@"/"])
            path = [path substringFromIndex:1];
        if ([path length] == 0)
            path = HELP_START_FILE;
        path = [[NSBundle mainBundle] pathForResource:[[path lastPathComponent] stringByDeletingPathExtension] ofType:[path pathExtension] inDirectory:[HELP_DIRECTORY stringByAppendingPathComponent:[path stringByDeletingLastPathComponent]]];
        if (path) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            NSString *theUTI = [[NSWorkspace sharedWorkspace] typeOfFile:path error:NULL];
            NSString *MIMEType = (NSString *)UTTypeCopyPreferredTagWithClass((CFStringRef)theUTI, kUTTagClassMIMEType);
            [self loadData:data MIMEType:MIMEType];
            [MIMEType release];
        } else {
            [client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil]];
        }
    } else {
        [client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:nil]];
    }
}

- (void)stopLoading {}

#pragma mark Create web pages from template

- (NSData *)HTMLDataUsingTemplateFile:(NSString *)template usingObject:(id)object {
    NSString *templateStringPath = [[NSBundle mainBundle] pathForResource:template ofType:@"html"];
    NSString *templateString = [NSString stringWithContentsOfFile:templateStringPath encoding:NSUTF8StringEncoding error:NULL];
    NSString *string = [BDSKTemplateParser stringByParsingTemplateString:templateString usingObject:object];
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

@end
