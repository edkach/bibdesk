//
//  BDSKErrorObject.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/26/06.
/*
 This software is Copyright (c) 2005-2012
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
//

#import "BDSKErrorObject.h"
#import "BDSKErrorObjectController.h"
#import "BDSKErrorEditor.h"
#import "BibItem.h"


@implementation BDSKErrorObject

- (id)initWithClassName:(NSString *)className message:(NSString *)msg forFile:(NSString *)filePath line:(NSInteger)line isWarning:(BOOL)flag{
    self = [super init];
    if (self) {
        errorClassName = [className copy];
        errorMessage = [msg copy];
        fileName = [filePath copy];
        lineNumber = line;
        isIgnorableWarning = flag;
    }
    return self;
}

- (id)init {
    return [self initWithClassName:nil message:nil forFile:nil line:-1 isWarning:NO];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] alloc] initWithClassName:errorClassName message:errorMessage forFile:fileName line:lineNumber isWarning:isIgnorableWarning];
}

- (void)dealloc {
    BDSKDESTROY(fileName);
    BDSKDESTROY(errorClassName);
    BDSKDESTROY(errorMessage);
    BDSKDESTROY(editor);
    BDSKDESTROY(publication);
    [super dealloc];
}

+ (void)reportError:(NSString *)className message:(NSString *)msg forFile:(NSString *)filePath line:(NSInteger)line isWarning:(BOOL)flag{
    id error = [[self alloc] initWithClassName:className message:msg forFile:filePath line:line isWarning:flag];
    [[BDSKErrorObjectController sharedErrorObjectController] reportError:error];
    [error release];
}

+ (void)reportErrorMessage:(NSString *)msg forFile:(NSString *)filePath line:(NSInteger)line{
    [self reportError:NSLocalizedString(@"error", @"error name") message:msg forFile:filePath line:line isWarning:NO];
}

- (NSString *)description{
    return [NSString stringWithFormat:@"<%@ file: %@, line: %ld\n\terror class: %@, error message: %@\n\teditor: %@>", [self class], fileName, lineNumber, errorClassName, errorMessage, editor];
}

- (NSString *)fileName {
    return fileName;
}

- (NSInteger)lineNumber {
    return lineNumber;
}

- (NSString *)errorClassName {
    return errorClassName;
}

- (NSString *)errorMessage {
    return errorMessage;
}

- (BOOL)isIgnorableWarning {
    return isIgnorableWarning;
}

- (BDSKErrorEditor *)editor {
    return editor;
}

- (void)setEditor:(BDSKErrorEditor *)newEditor {
    if (editor != newEditor) {
        [editor release];
        editor = [newEditor retain];
    }
}

- (BibItem *)publication {
    return publication;
}

- (void)setPublication:(BibItem *)newPublication{
    if (publication != newPublication) {
        [publication release];
        publication = [newPublication retain];
    }
}

@end
