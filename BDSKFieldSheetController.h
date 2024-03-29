//
//  BDSKFieldSheetController.h
//  BibDesk
//
//  Created by Christiaan Hofman on 3/18/06.
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

#import <Cocoa/Cocoa.h>

@interface BDSKFieldSheetController : NSWindowController
{
    IBOutlet NSObjectController *objectController;
    IBOutlet NSControl *fieldsControl;
    IBOutlet NSButton *okButton;
    IBOutlet NSButton *cancelButton;
    IBOutlet NSTextField *promptField;
    NSString *prompt;
    NSArray *fieldsArray;
    NSString *field;
}

- (id)initWithPrompt:(NSString *)prompt fieldsArray:(NSArray *)fields;

- (NSString *)field;
- (void)setField:(NSString *)newField;
- (NSArray *)fieldsArray;
- (void)setFieldsArray:(NSArray *)array;
- (NSString *)prompt;
- (void)setPrompt:(NSString *)promptString;

@end

@interface BDSKAddFieldSheetController : BDSKFieldSheetController
@end

@interface BDSKRemoveFieldSheetController : BDSKFieldSheetController
@end

@interface BDSKChangeFieldSheetController : BDSKRemoveFieldSheetController {
    IBOutlet NSComboBox *replaceFieldsComboBox;
    IBOutlet NSTextField *replacePromptField;
    NSString *replacePrompt;
    NSArray *replaceFieldsArray;
    NSString *replaceField;
}

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields replacePrompt:(NSString *)newPromptString replaceFieldsArray:(NSArray *)newFields;

- (NSString *)replaceField;
- (void)setReplaceField:(NSString *)newField;
- (NSArray *)replaceFieldsArray;
- (void)setReplaceFieldsArray:(NSArray *)array;
- (NSString *)replacePrompt;
- (void)setReplacePrompt:(NSString *)promptString;

@end
