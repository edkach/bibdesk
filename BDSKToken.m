//
//  BDSKToken.m
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

#import "BDSKToken.h"
#import "BDSKTemplateDocument.h"
#import "BDSKStringConstants.h"
#import "BDSKTypeManager.h"

#define EQUAL_OR_NIL_STRINGS(string1, string2) ( (string1 == nil && string2 == nil) || [string1 isEqualToString:string2] )

NSString *BDSKTokenDidChangeNotification = @"BDSKTokenDidChangeNotification";

@implementation BDSKToken

+ (id)tokenWithField:(NSString *)field {
    id tag = nil;
    if ([field isPersonField]) {
        tag = [[BDSKPersonTagToken alloc] initWithTitle:field];
    } else if ([field isLocalFileField]) {
        tag = [[BDSKFileTagToken alloc] initWithTitle:field];
    } else if ([field isRemoteURLField]) {
        tag = [[BDSKURLTagToken alloc] initWithTitle:field];
    } else if ([field isEqualToString:@"Rich Text"]) {
        tag = [[BDSKTextToken alloc] initWithTitle:field];
    } else {
        tag = [[BDSKFieldTagToken alloc] initWithTitle:field];
        if ([field isEqualToString:BDSKPubTypeString])
            [tag setKey:@"pubType"];
        else  if ([field isEqualToString:BDSKCiteKeyString])
            [tag setKey:@"citeKey"];
        else  if ([field isEqualToString:@"Item Index"])
            [tag setKey:@"itemIndex"];
    }
    
    return [tag autorelease];
}

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super init]) {
        title = [aTitle copy];
        fontName = nil;
        fontSize = 0.0;
        bold = NSMixedState;
        italic = NSMixedState;
        document = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if ([decoder allowsKeyedCoding]) {
        if (self = [self initWithTitle:[decoder decodeObjectForKey:@"title"]]) {
            fontName = [[decoder decodeObjectForKey:@"fontName"] retain];
            fontSize = [decoder decodeFloatForKey:@"fontSize"];
            bold = [decoder decodeIntForKey:@"bold"];
            italic = [decoder decodeIntForKey:@"italic"];
        }
    } else {
        if (self = [self initWithTitle:[decoder decodeObject]]) {
            fontName = [[decoder decodeObject] retain];
            [decoder decodeValueOfObjCType:@encode(float) at:&fontSize];
            [decoder decodeValueOfObjCType:@encode(int) at:&bold];
            [decoder decodeValueOfObjCType:@encode(int) at:&italic];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:title forKey:@"title"];
        [encoder encodeObject:fontName forKey:@"fontName"];
        [encoder encodeFloat:fontSize forKey:@"fontSize"];
        [encoder encodeInt:bold forKey:@"bold"];
        [encoder encodeInt:italic forKey:@"italic"];
    } else {
        [encoder encodeObject:title];
        [encoder encodeObject:fontName];
        [encoder encodeValueOfObjCType:@encode(float) at:&fontSize];
        [encoder encodeValueOfObjCType:@encode(int) at:&bold];
        [encoder encodeValueOfObjCType:@encode(int) at:&italic];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKToken *copy = [[[self class] allocWithZone:aZone] initWithTitle:title];
    copy->fontName = [fontName retain];
    copy->fontSize = fontSize;
    copy->bold = bold;
    copy->italic = italic;
    return copy;
}

- (void)dealloc {
    [title release];
    [fontName release];
    [super dealloc];
}
/*
- (BOOL)isEqual:(id)other {
    return [self isMemberOfClass:[other class]] &&
           EQUAL_OR_NIL_STRINGS(title, [other title]) &&
           EQUAL_OR_NIL_STRINGS(fontName, [other fontName]) &&
           fontSize == [other fontSize] &&
           bold == [other nbold] &&
           italic == [other italic];
}
*/
- (int)type {
    return -1;
}

- (NSString *)title {
    return title;
}

- (NSString *)fontName {
    return fontName;
}

- (void)setFontName:(NSString *)newFontName {
    if (fontName != newFontName) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFontName:fontName];
        [fontName release];
        fontName = [newFontName retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (float)fontSize {
    return fontSize;
}

- (void)setFontSize:(float)newFontSize {
    if (fabs(fontSize - newFontSize) > 0.0) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFontSize:fontSize];
        fontSize = newFontSize;
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (int)bold {
    return bold;
}

- (void)setBold:(int)newBold {
    if (bold != newBold) {
        [(BDSKToken *)[[self undoManager] prepareWithInvocationTarget:self] setBold:bold];
        bold = newBold;
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (int)italic {
    return italic;
}

- (void)setItalic:(int)newItalic {
    if (italic != newItalic) {
        [(BDSKToken *)[[self undoManager] prepareWithInvocationTarget:self] setItalic:italic];
        italic = newItalic;
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (BDSKTemplateDocument *)document {
    return document;
}

- (void)setDocument:(BDSKTemplateDocument *)newDocument {
    document = newDocument;
}

- (NSUndoManager *)undoManager {
    return [document undoManager];
}

- (NSString *)string {
    return nil;
}

- (NSAttributedString *)attributedStringWithDefaultAttributes:(NSDictionary *)attributes {
    NSFontManager *fm = [NSFontManager sharedFontManager];
    NSAttributedString *attrString = nil;
    NSMutableDictionary *attrs = [attributes mutableCopy];
    NSFont *font = [attrs objectForKey:NSFontAttributeName];
    int traits = [fm traitsOfFont:font];
    BOOL wasBold = (traits & NSBoldFontMask) != 0;
    BOOL wasItalic = (traits & NSItalicFontMask) != 0;
    BOOL useBold = bold == NSMixedState ? wasBold : bold;
    BOOL useItalic = italic == NSMixedState ? wasItalic : italic;
    
    if (fontName)
        font = [NSFont fontWithName:fontName size:fontSize > 0.0 ? fontSize : [font pointSize]];
    else if (fontSize > 0.0)
        font = [fm convertFont:font toSize:fontSize];
    if (fontName || useBold != wasBold)
        font = [fm convertFont:font toHaveTrait:useBold ? NSBoldFontMask : NSUnboldFontMask];
    if (fontName || useItalic != wasItalic)
        font = [fm convertFont:font toHaveTrait:useItalic ? NSItalicFontMask : NSUnitalicFontMask];
    
    [attrs setObject:font forKey:NSFontAttributeName];
    attrString = [[[NSAttributedString alloc] initWithString:[self string] attributes:attrs] autorelease];
    [attrs release];
    
    return attrString;
}

// Needed as any option control binds to any type of token
- (id)valueForUndefinedKey:(NSString *)key { return nil; }

#pragma mark NSEditorRegistration

- (void)objectDidBeginEditing:(id)editor {
    [document objectDidBeginEditing:editor];
}

- (void)objectDidEndEditing:(id)editor {
    [document objectDidEndEditing:editor];
}

@end

#pragma mark -

@implementation BDSKTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        key = nil;
        appendingKey = nil;
        prefix = nil;
        suffix = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        if ([decoder allowsKeyedCoding]) {
            key = [[decoder decodeObjectForKey:@"key"] retain];
            appendingKey = [[decoder decodeObjectForKey:@"appendingKey"] retain];
            prefix = [[decoder decodeObjectForKey:@"prefix"] retain];
            suffix = [[decoder decodeObjectForKey:@"suffix"] retain];
        } else {
            key = [[decoder decodeObject] retain];
            appendingKey = [[decoder decodeObject] retain];
            prefix = [[decoder decodeObject] retain];
            suffix = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:key forKey:@"key"];
        [encoder encodeObject:appendingKey forKey:@"appendingKey"];
        [encoder encodeObject:prefix forKey:@"prefix"];
        [encoder encodeObject:suffix forKey:@"suffix"];
    } else {
        [encoder encodeObject:key];
        [encoder encodeObject:appendingKey];
        [encoder encodeObject:prefix];
        [encoder encodeObject:suffix];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKTagToken *copy = [super copyWithZone:aZone];
    copy->key = [key retain];
    copy->appendingKey = [appendingKey retain];
    copy->prefix = [prefix retain];
    copy->suffix = [suffix retain];
    return copy;
}

- (void)dealloc {
    [key release];
    [appendingKey release];
    [prefix release];
    [suffix release];
    [super dealloc];
}
/*
- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(key, [other key]) &&
           EQUAL_OR_NIL_STRINGS(appendingKey, [other appendingKey]) &&
           EQUAL_OR_NIL_STRINGS(prefix, [other prefix]) &&
           EQUAL_OR_NIL_STRINGS(suffix, [other suffix]);
}
*/
- (NSString *)key {
    return key;
}

- (void)setKey:(NSString *)newKey {
    if (key != newKey) {
        [[[self undoManager] prepareWithInvocationTarget:self] setKey:key];
        [key release];
        key = [newKey retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSString *)appendingKey {
    return appendingKey;
}

- (void)setAppendingKey:(NSString *)newAppendingKey {
    if (appendingKey != newAppendingKey) {
        [[[self undoManager] prepareWithInvocationTarget:self] setAppendingKey:appendingKey];
        [appendingKey release];
        appendingKey = [newAppendingKey retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSString *)prefix {
    return prefix;
}

- (void)setPrefix:(NSString *)newPrefix {
    if (prefix != newPrefix) {
        [[[self undoManager] prepareWithInvocationTarget:self] setPrefix:prefix];
        [prefix release];
        prefix = [newPrefix retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSString *)suffix {
    return suffix;
}

- (void)setSuffix:(NSString *)newSuffix {
    if (suffix != newSuffix) {
        [[[self undoManager] prepareWithInvocationTarget:self] setSuffix:suffix];
        [suffix release];
        suffix = [newSuffix retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSArray *)keys {
    return nil;
}

- (NSString *)string {
    if ([prefix length] || [suffix length]) {
        NSMutableString *string = [NSMutableString stringWithFormat:@"<$%@?>", title];
        if ([prefix length])
            [string appendString:prefix];
        [string appendFormat:@"<$%@/>", [[self keys] componentsJoinedByString:@"."]];
        if ([suffix length])
            [string appendString:suffix];
        [string appendFormat:@"</$%@?>", title];
        return string;
    } else {
        return [NSString stringWithFormat:@"<$%@/>", [[self keys] componentsJoinedByString:@"."]];
    }
}

@end

#pragma mark -

@implementation BDSKFieldTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        capitalizationKey = nil;
        cleaningKey = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        if ([decoder allowsKeyedCoding]) {
            capitalizationKey = [[decoder decodeObjectForKey:@"capitalizationKey"] retain];
            cleaningKey = [[decoder decodeObjectForKey:@"cleaningKey"] retain];
        } else {
            capitalizationKey = [[decoder decodeObject] retain];
            cleaningKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:capitalizationKey forKey:@"capitalizationKey"];
        [encoder encodeObject:cleaningKey forKey:@"cleaningKey"];
    } else {
        [encoder encodeObject:capitalizationKey];
        [encoder encodeObject:cleaningKey];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKFieldTagToken *copy = [super copyWithZone:aZone];
    copy->capitalizationKey = [capitalizationKey retain];
    copy->cleaningKey = [cleaningKey retain];
    return copy;
}

- (void)dealloc {
    [capitalizationKey release];
    [cleaningKey release];
    [super dealloc];
}
/*
- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(capitalizationKey, [other capitalizationKey]) &&
           EQUAL_OR_NIL_STRINGS(cleaningKey, [other cleaningKey]);
}
*/
- (int)type {
    return BDSKFieldTokenType;
}

- (NSString *)capitalizationKey {
    return capitalizationKey;
}

- (void)setCapitalizationKey:(NSString *)newCapitalizationKey {
    if (capitalizationKey != newCapitalizationKey) {
        [[[self undoManager] prepareWithInvocationTarget:self] setCapitalizationKey:capitalizationKey];
        [capitalizationKey release];
        capitalizationKey = [newCapitalizationKey retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSString *)cleaningKey {
    return cleaningKey;
}

- (void)setCleaningKey:(NSString *)newCleaningKey {
    if (cleaningKey != newCleaningKey) {
        [[[self undoManager] prepareWithInvocationTarget:self] setCleaningKey:cleaningKey];
        [cleaningKey release];
        cleaningKey = [newCleaningKey retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}


- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if (key) {
        [keys addObject:key];
    } else {
        [keys addObject:@"fields"];
        [keys addObject:title];
    }
    if ([capitalizationKey length])
        [keys addObject:capitalizationKey];
    if ([cleaningKey length])
        [keys addObject:cleaningKey];
    if ([appendingKey length])
        [keys addObject:appendingKey];
    return keys;
}

- (NSAttributedString *)attributedString {
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
    return [[[NSAttributedString alloc] initWithString:[self string] attributes:attrs] autorelease];
}

@end

#pragma mark -

@implementation BDSKURLTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        urlFormatKey = nil;
        if ([title isEqualToString:BDSKUrlString])
            key = @"remoteURL";
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        if ([decoder allowsKeyedCoding]) {
            urlFormatKey = [[decoder decodeObjectForKey:@"urlFormatKey"] retain];
        } else {
            urlFormatKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:urlFormatKey forKey:@"urlFormatKey"];
    } else {
        [encoder encodeObject:urlFormatKey];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKURLTagToken *copy = [super copyWithZone:aZone];
    copy->urlFormatKey = [urlFormatKey retain];
    return copy;
}

- (void)dealloc {
    [urlFormatKey release];
    [super dealloc];
}
/*
- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(urlFormatKey, [other urlFormatKey]);
}
*/
- (int)type {
    return BDSKURLTokenType;
}

- (NSString *)urlFormatKey {
    return urlFormatKey;
}

- (void)setUrlFormatKey:(NSString *)newUrlFormatKey {
    if (urlFormatKey != newUrlFormatKey) {
        [[[self undoManager] prepareWithInvocationTarget:self] setKey:urlFormatKey];
        [urlFormatKey release];
        urlFormatKey = [newUrlFormatKey retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if (key) {
        [keys addObject:key];
    } else {
        [keys addObject:@"urls"];
        [keys addObject:title];
    }
    if ([urlFormatKey length])
        [keys addObject:urlFormatKey];
    if ([appendingKey length])
        [keys addObject:appendingKey];
    return keys;
}

@end

#pragma mark -

@implementation BDSKFileTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        if ([title isEqualToString:BDSKLocalUrlString])
            key = @"localURL";
    }
    return self;
}

- (int)type {
    return BDSKFileTokenType;
}

@end

#pragma mark -

@implementation BDSKPersonTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        nameStyleKey = [@"name" retain];
        joinStyleKey = [@"@componentsJoinedByCommaAndAnd" retain];
        if ([title isEqualToString:BDSKAuthorString])
            key = [@"authors" retain];
        else if ([title isEqualToString:BDSKEditorString])
            key = [@"editors" retain];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        if ([decoder allowsKeyedCoding]) {
            nameStyleKey = [[decoder decodeObjectForKey:@"nameStyleKey"] retain];
            joinStyleKey = [[decoder decodeObjectForKey:@"joinStyleKey"] retain];
        } else {
            nameStyleKey = [[decoder decodeObject] retain];
            joinStyleKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:nameStyleKey forKey:@"nameStyleKey"];
        [encoder encodeObject:joinStyleKey forKey:@"joinStyleKey"];
    } else {
        [encoder encodeObject:nameStyleKey];
        [encoder encodeObject:joinStyleKey];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKPersonTagToken *copy = [super copyWithZone:aZone];
    copy->nameStyleKey = [nameStyleKey retain];
    copy->joinStyleKey = [joinStyleKey retain];
    return copy;
}

- (void)dealloc {
    [nameStyleKey release];
    [joinStyleKey release];
    [super dealloc];
}
/*
- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(nameStyleKey, [other nameStyleKey]) &&
           EQUAL_OR_NIL_STRINGS(joinStyleKey, [other joinStyleKey]);
}
*/
- (int)type {
    return BDSKPersonTokenType;
}

- (NSString *)nameStyleKey {
    return [[nameStyleKey retain] autorelease];
}

- (void)setNameStyleKey:(NSString *)newNameStyleKey {
    if (nameStyleKey != newNameStyleKey) {
        [[[self undoManager] prepareWithInvocationTarget:self] setNameStyleKey:nameStyleKey];
        [nameStyleKey release];
        nameStyleKey = [newNameStyleKey retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSString *)joinStyleKey {
    return [[joinStyleKey retain] autorelease];
}

- (void)setJoinStyleKey:(NSString *)newJoinStyleKey {
    if (joinStyleKey != newJoinStyleKey) {
        [[[self undoManager] prepareWithInvocationTarget:self] setJoinStyleKey:joinStyleKey];
        [joinStyleKey release];
        joinStyleKey = [newJoinStyleKey retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if ([key length]) {
        [keys addObject:key];
    } else {
        [keys addObject:@"persons"];
        [keys addObject:title];
    }
    if ([nameStyleKey length])
        [keys addObject:nameStyleKey];
    [keys addObject:joinStyleKey];
    if ([appendingKey length])
        [keys addObject:appendingKey];
    return keys;
}

@end

#pragma mark -

@implementation BDSKTextToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        field = nil;
        altText = [@"" retain];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        if ([decoder allowsKeyedCoding]) {
            field = [[decoder decodeObjectForKey:@"field"] retain];
            altText = [[decoder decodeObjectForKey:@"altText"] retain];
        } else {
            field = [[decoder decodeObject] retain];
            altText = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:field forKey:@"field"];
        [encoder encodeObject:altText forKey:@"altText"];
    } else {
        [encoder encodeObject:field];
        [encoder encodeObject:altText];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKTextToken *copy = [super copyWithZone:aZone];
    copy->field = [field retain];
    copy->altText = [altText retain];
    return copy;
}

- (void)dealloc {
    [field release];
    [altText release];
    [super dealloc];
}
/*
- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(field, [other field]) &&
           EQUAL_OR_NIL_STRINGS(altText, [other altText]);
}
*/
- (int)type {
    return BDSKTextTokenType;
}

- (void)setTitle:(NSString *)newTitle {
    if (newTitle == nil)
        newTitle = @"";
    if (title != newTitle) {
        [[[self undoManager] prepareWithInvocationTarget:self] setTitle:title];
        [title release];
        title = [newTitle retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSString *)field {
    return field;
}

- (void)setField:(NSString *)newField {
    if (field != newField) {
        [[[self undoManager] prepareWithInvocationTarget:self] setField:field];
        [field release];
        field = [newField retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSString *)altText {
    return altText;
}

- (void)setAltText:(NSString *)newAltText {
    if (altText != newAltText) {
        [[[self undoManager] prepareWithInvocationTarget:self] setAltText:altText];
        [altText release];
        altText = [newAltText retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTokenDidChangeNotification object:self];
    }
}

- (NSString *)string {
    if ([field length]) {
        NSMutableString *string = [NSMutableString stringWithFormat:@"<$%@?>%@", field, title];
        if ([altText length])
            [string appendFormat:@"<?$%@?>%@", field, altText];
        [string appendFormat:@"</$%@?>", field];
        return string;
    } else {
        return title;
    }
}

@end
