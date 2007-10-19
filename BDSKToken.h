//
//  BDSKToken.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/8/07.
/*
 This software is Copyright (c) 2007
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

enum {
    BDSKFieldTokenType,
    BDSKURLTokenType,
    BDSKPersonTokenType,
    BDSKDateTokenType,
    BDSKNumberTokenType,
    BDSKTextTokenType
};

extern NSString *BDSKTokenDidChangeNotification;

@class BDSKTemplateDocument;

@interface BDSKToken : NSObject <NSCopying, NSCoding> {
    NSString *title;
    NSString *fontName;
    float fontSize;
    int bold;
    int italic;
    BDSKTemplateDocument *document;
}

+ (id)tokenWithField:(NSString *)field;

- (id)initWithTitle:(NSString *)aTitle;

- (int)type;

- (NSString *)title;

- (NSString *)fontName;
- (void)setFontName:(NSString *)newFontName;

- (float)fontSize;
- (void)setFontSize:(float)newFontSize;

- (int)bold;
- (void)setBold:(int)newBold;

- (int)italic;
- (void)setItalic:(int)newItalic;

- (BDSKTemplateDocument *)document;
- (void)setDocument:(BDSKTemplateDocument *)newDocument;

- (NSString *)string;
- (NSAttributedString *)attributedStringWithDefaultAttributes:(NSDictionary *)attributes;

- (NSUndoManager *)undoManager;

@end

#pragma mark -

@interface BDSKTagToken : BDSKToken {
    NSString *key;
}

- (NSString *)key;
- (void)setKey:(NSString *)newKey;

- (NSArray *)keys;

@end

#pragma mark -

@interface BDSKFieldTagToken : BDSKTagToken {
    NSString *casingKey;
    NSString *cleaningKey;
    NSString *appendingKey;
    NSString *prefix;
    NSString *suffix;
}

- (NSString *)casingKey;
- (void)setCasingKey:(NSString *)newCasingKey;

- (NSString *)cleaningKey;
- (void)setCleaningKey:(NSString *)newCleaningKey;

- (NSString *)appendingKey;
- (void)setAppendingKey:(NSString *)newAppendingKey;

- (NSString *)prefix;
- (void)setPrefix:(NSString *)newPrefix;

- (NSString *)suffix;
- (void)setSuffix:(NSString *)newSuffix;

@end

#pragma mark -

@interface BDSKURLTagToken : BDSKFieldTagToken {
    NSString *urlFormatKey;
}

- (NSString *)urlFormatKey;
- (void)setUrlFormatKey:(NSString *)newUrlFormatKey;

@end

#pragma mark -

@interface BDSKPersonTagToken : BDSKFieldTagToken {
    NSString *nameStyleKey;
    NSString *joinStyleKey;
}

- (NSString *)nameStyleKey;
- (void)setNameStyleKey:(NSString *)newNameStyleKey;

- (NSString *)joinStyleKey;
- (void)setJoinStyleKey:(NSString *)newJoinStyleKey;

@end

#pragma mark -

@interface BDSKDateTagToken : BDSKFieldTagToken {
    NSString *dateFormatKey;
}

- (NSString *)dateFormatKey;
- (void)setDateFormatKey:(NSString *)newDateFormatKey;

@end

#pragma mark -

@interface BDSKNumberTagToken : BDSKTagToken {
}
@end

#pragma mark -

@interface BDSKTextToken : BDSKToken {
    NSString *field;
    NSString *altText;
}

- (void)setTitle:(NSString *)newTitle;

- (NSString *)field;
- (void)setField:(NSString *)newField;

- (NSString *)altText;
- (void)setAltText:(NSString *)newAltText;

@end
