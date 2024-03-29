//
//  NSURL_BDSKExtensions.h
//  Bibdesk
//
//  Created by Adam Maxwell on 12/19/05.
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


@interface NSURL (BDSKExtensions)

+ (NSURL *)fileURLWithAEDesc:(NSAppleEventDescriptor *)desc;
- (NSAppleEventDescriptor *)aeDescriptorValue;

- (NSURL *)fileURLByResolvingAliases;
- (NSURL *)fileURLByResolvingAliasesBeforeLastPathComponent;

+ (NSURL *)URLWithStringByNormalizingPercentEscapes:(NSString *)string;
+ (NSURL *)URLWithStringByNormalizingPercentEscapes:(NSString *)string baseURL:(NSURL *)baseURL;
+ (NSCharacterSet *)illegalURLCharacterSet;
- (NSString *)precomposedPath;

- (NSComparisonResult)UTICompare:(NSURL *)other;

+ (NSURL *)URLFromPasteboardAnyType:(NSPasteboard *)pasteboard;

- (NSArray *)SkimNotes;
- (NSString *)textSkimNotes;
- (NSAttributedString *)richTextSkimNotes;
- (NSArray *)scriptingSkimNotes;

- (NSInteger)finderLabel;
- (void)setFinderLabel:(NSInteger)label;
- (NSArray *)openMetaTags;
- (double)openMetaRating;

- (NSAttributedString *)linkedText;
- (NSAttributedString *)icon;
- (NSAttributedString *)smallIcon;
- (NSAttributedString *)linkedIcon;
- (NSAttributedString *)linkedSmallIcon;

@end

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@interface NSURL (BDSKSnowLeopardExtensions)
- (NSString *)lastPathComponent;
- (NSString *)pathExtension;
- (NSURL *)URLByDeletingLastPathComponent;
- (NSURL *)URLByDeletingPathExtension;
- (NSURL *)filePathURL;
@end
#endif

CFURLRef BDCopyFileURLResolvingAliases(CFURLRef fileURL);
