//
//  NSWorkspace_BDSKExtensions.h
//  Bibdesk
//
//  Created by Adam Maxwell on 10/27/05.
/*
 This software is Copyright (c) 2005-2012
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

#import <Cocoa/Cocoa.h>


@interface NSWorkspace (BDSKExtensions)

/*!
@method     openURL:withSearchString:
 @abstract   When opening a file from Spotlight search results, an application receives the search text in the open documents Apple event.  This goes the other way, and allows an application to send an open documents Apple event with the search text.
 @discussion (comprehensive description)
 @param      fileURL This must be a valid file URL pointing to the file you want to open.
 @param      searchString This is the text that is to be searched for in the receiving application.
 @result     (description)
 */
- (BOOL)openURL:(NSURL *)fileURL withSearchString:(NSString *)searchString;

- (BOOL)openLinkedFile:(NSString *)fullPath;
- (BOOL)openLinkedURL:(NSURL *)aURL;
- (BOOL)openURL:(NSURL *)aURL withApplicationURL:(NSURL *)applicationURL;

- (NSArray *)editorAndViewerURLsForURL:(NSURL *)aURL;
- (NSURL *)defaultEditorOrViewerURLForURL:(NSURL *)aURL;
- (NSArray *)editorAndViewerNamesAndBundleIDsForPathExtension:(NSString *)extension;

- (BOOL)isAppleScriptFileAtPath:(NSString *)path;
- (BOOL)isApplicationAtPath:(NSString *)path;
- (BOOL)isAutomatorWorkflowAtPath:(NSString *)path;
- (BOOL)isFolderAtPath:(NSString *)path;

- (BOOL)emailTo:(NSString *)receiver subject:(NSString *)subject body:(NSString *)body attachments:(NSArray *)files;

@end

@interface NSString (UTIExtensions)

- (BOOL)isEqualToUTI:(NSString *)UTIString;

@end
