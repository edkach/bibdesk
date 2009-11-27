//
//  BDSKURLGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/17/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKURLGroup.h"
#import "BDSKOwnerProtocol.h"
#import <WebKit/WebKit.h>
#import "BDSKBibTeXParser.h"
#import "BDSKWebOfScienceParser.h"
#import "BDSKSharedGroup.h"
#import "BDSKAppController.h"
#import "NSURL_BDSKExtensions.h"
#import "BDSKStringParser.h"
#import "NSError_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacroResolver.h"
#import "BDSKItemSearchIndexes.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibItem.h"

@implementation BDSKURLGroup

// old designated initializer
- (id)initWithName:(NSString *)aName count:(NSInteger)aCount;
{
    [self release];
    self = nil;
    return self;
}

- (id)initWithURL:(NSURL *)aURL;
{
    self = [self initWithName:nil URL:aURL];
    return self;
}

// designated initializer
- (id)initWithName:(NSString *)aName URL:(NSURL *)aURL;
{
    NSParameterAssert(aURL != nil);
    if (aName == nil)
        aName = [aURL lastPathComponent];
    if(self = [super initWithName:aName count:0]){
        
        publications = nil;
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
        URL = [aURL copy];
        isRetrieving = NO;
        failedDownload = NO;
        URLDownload = nil;
        searchIndexes = [BDSKItemSearchIndexes new];
    }
    
    return self;
}

- (id)initWithDictionary:(NSDictionary *)groupDict {
    NSString *aName = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
    NSURL *anURL = [NSURL URLWithString:[groupDict objectForKey:@"URL"]];
    self = [self initWithName:aName URL:anURL];
    return self;
}

- (NSDictionary *)dictionaryValue {
    NSString *aName = [[self stringValue] stringByEscapingGroupPlistEntities];
    NSString *anURL = [[self URL] absoluteString];
    return [NSDictionary dictionaryWithObjectsAndKeys:aName, @"group name", anURL, @"URL", nil];
}

- (id)initWithCoder:(NSCoder *)aCoder
{
    [NSException raise:BDSKUnimplementedException format:@"Instances of %@ do not conform to NSCoding", [self class]];
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [NSException raise:BDSKUnimplementedException format:@"Instances of %@ do not conform to NSCoding", [self class]];
}

- (id)copyWithZone:(NSZone *)aZone {
	return [[[self class] allocWithZone:aZone] initWithName:name URL:URL];
}

- (void)dealloc;
{
    [self terminate];
    [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
    [URL release];
    [filePath release];
    [publications release];
    [macroResolver release];
    [searchIndexes release];
    [super dealloc];
}

- (void)terminate;
{
    [URLDownload cancel];
    [URLDownload release];
    URLDownload = nil;
    isRetrieving = NO;
}

- (BOOL)isEqual:(id)other { return self == other; }

- (NSUInteger)hash {
    return BDSKHash(self);
}

// Logging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tis downloading: %@\n\tname: %@\n\tURL: %@\n }", [self class], self, (isRetrieving ? @"yes" : @"no"), name, [self URL]];
}

- (BDSKItemSearchIndexes *)searchIndexes {
    return searchIndexes;
}

#pragma mark Downloading

- (void)startDownload;
{
    NSURL *theURL = [self URL];
    if ([theURL isFileURL]) {
        NSString *path = [[theURL fileURLByResolvingAliases] path];
        BOOL isDir = NO;
        if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && NO == isDir){
            [self download:nil didCreateDestination:path];
            [self downloadDidFinish:nil];
        } else {
            NSError *error = [NSError mutableLocalErrorWithCode:kBDSKFileNotFound localizedDescription:nil];
            if (isDir)
                [error setValue:NSLocalizedString(@"URL points to a directory instead of a file", @"Error description") forKey:NSLocalizedDescriptionKey];
            else
                [error setValue:NSLocalizedString(@"The URL points to a file that does not exist", @"Error description") forKey:NSLocalizedDescriptionKey];
            [error setValue:[theURL path] forKey:NSFilePathErrorKey];
            [self download:nil didFailWithError:error];
        }
    } else {
        NSURLRequest *request = [NSURLRequest requestWithURL:theURL];
        // we use a WebDownload since it's supposed to add authentication dialog capability
        if ([self isRetrieving])
            [URLDownload cancel];
        [URLDownload release];
        URLDownload = [[WebDownload alloc] initWithRequest:request delegate:self];
        [URLDownload setDestination:[[NSFileManager defaultManager] temporaryFileWithBasename:nil] allowOverwrite:NO];
        isRetrieving = YES;
    }
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
    [filePath autorelease];
    filePath = [path copy];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
    isRetrieving = NO;
    failedDownload = NO;
    
    NSError *error = nil;
    
    if (URLDownload) {
        [URLDownload release];
        URLDownload = nil;
    }

    // tried using -[NSString stringWithContentsOfFile:usedEncoding:error:] but it fails too often
    NSString *contentString = [NSString stringWithContentsOfFile:filePath encoding:0 guessEncoding:YES];
    NSArray *pubs = nil;
    if (nil == contentString) {
        failedDownload = YES;
        [self setErrorMessage:NSLocalizedString(@"Unable to find content", @"Error description")];
    } else {
        NSInteger type = [contentString contentStringType];
        BOOL isPartialData = NO;
        if (type == BDSKBibTeXStringType) {
            NSMutableString *frontMatter = [NSMutableString string];
            pubs = [BDSKBibTeXParser itemsFromData:[contentString dataUsingEncoding:NSUTF8StringEncoding] frontMatter:frontMatter filePath:filePath document:self encoding:NSUTF8StringEncoding isPartialData:&isPartialData error:&error];
        } else if (type != BDSKUnknownStringType && type != BDSKNoKeyBibTeXStringType){
            pubs = [BDSKStringParser itemsFromString:contentString ofType:type error:&error];
        }
        if (pubs == nil || isPartialData) {
            failedDownload = YES;
            [self setErrorMessage:[error localizedDescription]];
        }
    }
    [self setPublications:pubs];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
    isRetrieving = NO;
    failedDownload = YES;
    [self setErrorMessage:[error localizedDescription]];
    
    if (URLDownload) {
        [URLDownload release];
        URLDownload = nil;
    }
    
    // redraw 
    [self setPublications:nil];
}

#pragma mark Accessors

- (NSURL *)URL;
{
    return URL;
}

- (void)setURL:(NSURL *)newURL;
{
    if (URL != newURL) {
		[[[self undoManager] prepareWithInvocationTarget:self] setURL:URL];
        
        if (name == nil || [name isEqualToString:[URL lastPathComponent]])
            [self setName:[newURL lastPathComponent]];
        
        [URL release];
        URL = [newURL copy];
        
        // get rid of any current pubs and notify the tableview to start progress indicators
        [self setPublications:nil];
    }
}

- (BDSKPublicationsArray *)publicationsWithoutUpdating { return publications; }
 
- (BDSKPublicationsArray *)publications;
{
    if([self isRetrieving] == NO && publications == nil){
        // get the publications asynchronously if remote, synchronously if local
        [self startDownload]; 
        
        // use this to notify the tableview to start the progress indicators
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKURLGroupUpdatedNotification object:self userInfo:userInfo];
    }
    // this posts a notification that the publications of the group changed, forcing a redisplay of the table cell
    return publications;
}

- (void)setPublications:(NSArray *)newPublications;
{
    if ([self isRetrieving])
        [self terminate];
    
    if(newPublications != publications){
        [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
        [publications release];
        publications = newPublications == nil ? nil : [[BDSKPublicationsArray alloc] initWithArray:newPublications];
        [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
        [searchIndexes resetWithPublications:publications];
        
        if (publications == nil)
            [macroResolver removeAllMacros];
    }
    
    [self setCount:[publications count]];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(publications != nil)] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKURLGroupUpdatedNotification object:self userInfo:userInfo];
}

- (BDSKMacroResolver *)macroResolver;
{
    return macroResolver;
}

- (NSUndoManager *)undoManager { return [super undoManager]; }

- (NSURL *)fileURL { return [NSURL fileURLWithPath:filePath]; }

- (NSString *)documentInfoForKey:(NSString *)key { return nil; }

- (BOOL)isDocument { return NO; }

- (BOOL)isRetrieving { return isRetrieving; }

- (BOOL)failedDownload { return failedDownload; }

// BDSKGroup overrides

- (NSImage *)icon {
    return [NSImage imageNamed:NSImageNameNetwork];
}

- (BOOL)isURL { return YES; }

- (BOOL)isExternal { return YES; }

- (BOOL)isEditable { return YES; }


- (NSString *)errorMessage {
    return errorMessage;
}

- (void)setErrorMessage:(NSString *)newErrorMessage {
    if (errorMessage != newErrorMessage) {
        [errorMessage release];
        errorMessage = [newErrorMessage retain];
    }
}

- (BOOL)containsItem:(BibItem *)item {
    // calling [self publications] will repeatedly reschedule a retrieval, which may be undesirable if it failed
    return [publications containsObject:item];
}

@end
