//
//  BDSKTemplateDocument.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/8/07.
/*
 This software is Copyright (c) 2007-2012
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

#import "BDSKTemplateDocument.h"
#import "BDSKToken.h"
#import "BDSKTypeTemplate.h"
#import "BDSKTypeManager.h"
#import "BDSKStringConstants.h"
#import "BDSKFieldNameFormatter.h"
#import "BDSKFieldSheetController.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKTemplateParser.h"
#import "BDSKTemplateTag.h"
#import "NSString_BDSKExtensions.h"
#import "NSCharacterSet_BDSKExtensions.h"
#import "BDSKRuntime.h"
#import "NSInvocation_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSPrintOperation_BDSKExtensions.h"
#import "BDSKTableView.h"
#import "BDSKUndoManager.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"

static CGFloat BDSKDefaultFontSizes[] = {8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 48.0, 64.0};

NSString *BDSKTextTemplateDocumentType = @"Text Template";
NSString *BDSKRichTextTemplateDocumentType = @"Rich Text Template";

#define BDSKTemplateDocumentErrorDomain @"BDSKTemplateDocumentErrorDomain"

#define BDSKTemplateDocumentFrameAutosaveName @"BDSKTemplateDocument"

#define BDSKTokenFieldDidChangeSelectionNotification @"BDSKTokenFieldDidChangeSelectionNotification"

#define BDSKTemplateTokensPboardType @"BDSKTemplateTokensPboardType"
#define BDSKTypeTemplateRowsPboardType @"BDSKTypeTemplateRowsPboardType"
#define BDSKValueOrNoneTransformerName @"BDSKValueOrNone"

static char BDSKTypeTemplateObservationContext;
static char BDSKTokenPropertiesObservationContext;

static inline BOOL getTemplateRanges(NSString *str, NSRange *prefixRangePtr, NSRange *suffixRangePtr, NSRange *separatorRangePtr, NSRange *itemRangePtr);

@interface BDSKValueOrNoneTransformer : NSValueTransformer @end

@interface BDSKFlippedClipView : NSClipView @end

@interface BDSKTemplateDocument (BDSKPrivate)
- (NSArray *)tokensForFields:(NSArray *)array;
- (BDSKTypeTemplate *)addTypeTemplateForType:(NSString *)type;
- (void)updateTextViews;
- (void)updateTokenFields;
- (void)updateStrings;
- (void)updateOptionView;
- (void)handleDidChangeSelectionNotification:(NSNotification *)notification;
- (void)handleTokenDidChangeNotification:(NSNotification *)notification;
- (void)handleTemplateDidChangeNotification:(NSNotification *)notification;
- (NSDictionary *)convertPubTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont;
@end

@implementation BDSKTemplateDocument

+ (NSSet *)keyPathsForValuesAffectingPreviewAttributedString {
    return [NSSet setWithObjects:@"attributedString", nil];
}

+ (void)initialize {
    BDSKINITIALIZE;
	[NSValueTransformer setValueTransformer:[[[BDSKValueOrNoneTransformer alloc] init] autorelease]
									forName:BDSKValueOrNoneTransformerName];
}

+ (NSArray *)writableTypes {
    return [NSArray arrayWithObjects:BDSKTextTemplateDocumentType, BDSKRichTextTemplateDocumentType, nil];
}

+ (NSArray *)readableTypes {
    return [NSArray arrayWithObjects:BDSKTextTemplateDocumentType, BDSKRichTextTemplateDocumentType, nil];
}

+ (BOOL)isNativeType:(NSString *)aType {
    return [aType isEqualToString:BDSKTextTemplateDocumentType] || [aType isEqualToString:BDSKRichTextTemplateDocumentType];
}

- (id)init {
    self = [super init];
    if (self) {
        NSFont *font = [NSFont userFontOfSize:0.0];
        
        specialTokens = [[NSMutableArray alloc] init];
        defaultTokens = [[NSMutableArray alloc] init];
        fieldTokens = [[NSMutableDictionary alloc] init];
        typeTemplates = [[NSMutableArray alloc] init];
        prefixTemplate = [[NSMutableAttributedString alloc] init];
        suffixTemplate = [[NSMutableAttributedString alloc] init];
        separatorTemplate = [[NSMutableAttributedString alloc] init];
        richText = NO;
        fontName = [[font familyName] retain];
        fontSize = [font pointSize];
        bold = NO;
        italic = NO;
        selectedToken = nil;
        defaultTypeIndex = 0;
        
        [self setFileType:BDSKTextTemplateDocumentType];
        
        BDSKUndoManager *undoManager = [[[BDSKUndoManager alloc] init] autorelease];
        [undoManager setDelegate:self];
        [self setUndoManager:undoManager];
        
        NSBundle *bundle = [NSBundle mainBundle];
        NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] initWithContentsOfFile:[bundle pathForResource:@"TemplateOptions" ofType:@"plist"]];
        
        for (NSString *key in [tmpDict allKeys]) {
            NSMutableArray *array = [NSMutableArray array];
            for (NSDictionary *dict in [tmpDict objectForKey:key]) {
                NSMutableDictionary *mutableDict = [dict mutableCopy];
                [mutableDict setObject:[bundle localizedStringForKey:[dict objectForKey:@"displayName"] value:@"" table:@"TemplateOptions"] forKey:@"displayName"];
                [array addObject:mutableDict];
                [mutableDict release];
            }
            [tmpDict setObject:array forKey:key];
        }
        templateOptions = [tmpDict copy];
        [tmpDict release];
        
        for (NSString *type in [[BDSKTypeManager sharedManager] types]) {
            if ([type isEqualToString:BDSKArticleString])
                defaultTypeIndex = [typeTemplates count];
            [self addTypeTemplateForType:type];
        }
        [[typeTemplates objectAtIndex:defaultTypeIndex] setDefault:YES];
        
        NSMutableArray *tmpFonts = [NSMutableArray array];
        NSMutableArray *fontNames = [[[[NSFontManager sharedFontManager] availableFontFamilies] mutableCopy] autorelease];
        
        [fontNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
        for (NSString *name in fontNames) {
            font = [NSFont fontWithName:name size:0.0];
            [tmpFonts addObject:[NSDictionary dictionaryWithObjectsAndKeys:[font fontName], @"fontName", [font displayName], @"displayName", nil]];
        }
        fonts = [tmpFonts copy];
        [tmpFonts insertObject:[NSDictionary dictionaryWithObjectsAndKeys:@"<None>", @"fontName", NSLocalizedString(@"Same as body", @"Inerited font message in popup"), @"displayName", nil] atIndex:0];
        tokenFonts = [tmpFonts copy];
        
        [defaultTokens setArray:[self tokensForFields:[[BDSKTypeManager sharedManager] userDefaultFieldsForType:nil]]];
        [specialTokens setArray:[self tokensForFields:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCiteKeyString, BDSKLocalFileString, BDSKRemoteURLString, BDSKItemNumberString, BDSKRichTextString, BDSKDateAddedString, BDSKDateModifiedString, BDSKPubDateString, nil]]];
    }
    return self;
}

- (void)dealloc {
    for (BDSKTypeTemplate *template in typeTemplates)
        [self stopObservingTypeTemplate:template];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(fieldOptionsMenu);
    BDSKDESTROY(urlOptionsMenu);
    BDSKDESTROY(personOptionsMenu);
    BDSKDESTROY(linkedFileOptionsMenu);
    BDSKDESTROY(dateOptionsMenu);
    BDSKDESTROY(numberOptionsMenu);
    BDSKDESTROY(specialTokens);
    BDSKDESTROY(defaultTokens);
    BDSKDESTROY(fieldTokens);
    BDSKDESTROY(typeTemplates);
    BDSKDESTROY(prefixTemplate);
    BDSKDESTROY(suffixTemplate);
    BDSKDESTROY(separatorTemplate);
    BDSKDESTROY(fontName);
    BDSKDESTROY(selectedToken);
    BDSKDESTROY(templateOptions);
    BDSKDESTROY(fonts);
    BDSKDESTROY(tokenFonts);
    BDSKDESTROY(string);
    BDSKDESTROY(attributedString);
    [super dealloc];
}

- (NSString *)windowNibName {
    return @"TemplateDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    
    [aController setWindowFrameAutosaveNameOrCascade:BDSKTemplateDocumentFrameAutosaveName];
    
    NSRect frame = [itemTemplateTokenField frame];
    frame.size.height = 39.0;
    [itemTemplateTokenField setFrame:frame];
    
    [requiredTokenField setEditable:NO];
    [requiredTokenField setBezeled:NO];
    [requiredTokenField setDrawsBackground:NO];
    [requiredTokenField setObjectValue:[[typeTemplates objectAtIndex:defaultTypeIndex] requiredTokens]];
    [optionalTokenField setEditable:NO];
    [optionalTokenField setBezeled:NO];
    [optionalTokenField setDrawsBackground:NO];
    [optionalTokenField setObjectValue:[[typeTemplates objectAtIndex:defaultTypeIndex] optionalTokens]];
    [defaultTokenField setEditable:NO];
    [defaultTokenField setBezeled:NO];
    [defaultTokenField setDrawsBackground:NO];
    [defaultTokenField setObjectValue:defaultTokens];
    [specialTokenField setEditable:NO];
    [specialTokenField setBezeled:NO];
    [specialTokenField setDrawsBackground:NO];
    [specialTokenField setObjectValue:specialTokens];
    [itemTemplateTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@""]];
    
    NSScrollView *scrollView = [specialTokenField enclosingScrollView];
    NSView *documentView = [[scrollView documentView] retain];
    NSClipView *clipView = [[BDSKFlippedClipView alloc] initWithFrame:[[scrollView contentView] frame]];
    [clipView setDrawsBackground:NO];
    [scrollView setContentView:clipView];
    [scrollView setDocumentView:documentView];
    [clipView release];
    [documentView release];
    
    [self updateTokenFields];
    [self updateTextViews];
    
    [tableView setTypeSelectHelper:[[[BDSKTypeSelectHelper alloc] init] autorelease]];
    
    [tableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
	[fieldField setFormatter:[[[BDSKFieldNameFormatter alloc] init] autorelease]];
    
    [ownerController bind:@"contentObject" toObject:self withKeyPath:@"self" options:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:itemTemplateTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:specialTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:requiredTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:optionalTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:defaultTokenField];
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation {
    return [NSArray arrayWithObjects:richText ? BDSKRichTextTemplateDocumentType : BDSKTextTemplateDocumentType, nil];
}

- (void)document:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void *)contextInfo {
    NSDictionary *info = [(id)contextInfo autorelease];
    NSString *path = [info objectForKey:@"path"];
    NSInvocation *invocation = [info objectForKey:@"callback"];
    
    if (didSave)
        [[NSFileManager defaultManager] setAppleStringEncoding:NSUTF8StringEncoding atPath:path error:NULL];
    
    if (invocation) {
        [invocation setArgument:&doc atIndex:2];
        [invocation setArgument:&didSave atIndex:3];
        [invocation invoke];
    }
}

- (void)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    if (richText) {
        [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
    } else {
        NSInvocation *invocation = nil;
        if (delegate && didSaveSelector) {
            invocation = [[NSInvocation invocationWithTarget:delegate selector:didSaveSelector] retain];
            [invocation setArgument:&contextInfo atIndex:4];
        }
        NSDictionary *info = [[NSDictionary alloc] initWithObjectsAndKeys:[absoluteURL path], @"path", invocation, @"callback", nil];
        [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation delegate:self didSaveSelector:@selector(document:didSave:contextInfo:) contextInfo:info];
    }
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSData *data = nil;
    if (richText) {
        NSAttributedString *attrString = [self attributedString];
        data = [attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil];
    } else {
        data = [[self string] dataUsingEncoding:NSUTF8StringEncoding];
    }
    return data;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSAttributedString *attrString = nil;
    NSString *str = nil;
    NSRange prefixRange, suffixRange, separatorRange, itemRange;
    BOOL success = NO;
    
    richText = [typeName isEqualToString:BDSKRichTextTemplateDocumentType];
    
    if ([self isRichText]) {
        attrString = [[[NSAttributedString alloc] initWithData:data options:nil documentAttributes:NULL error:NULL] autorelease];
        str = [attrString string];
    } else {
        str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    }
    
    if (getTemplateRanges(str, &prefixRange, &suffixRange, &separatorRange, &itemRange)) {
        NSArray *parsedTemplate = nil;
        NSDictionary *templateDict = nil;
        NSAttributedString *prefix = nil;
        NSAttributedString *suffix = nil;
        NSAttributedString *separator = nil;
        NSFont *font = nil;
        
        if ([self isRichText]) {
            font = [attrString attribute:NSFontAttributeName atIndex:NSMaxRange(prefixRange) effectiveRange:NULL] ?: [NSFont userFontOfSize:0.0];
            if (prefixRange.length > 0)
               prefix = [attrString attributedSubstringFromRange:prefixRange];
            if (suffixRange.length > 0)
                suffix = [attrString attributedSubstringFromRange:suffixRange];
            if (separatorRange.length > 0)
                separator = [attrString attributedSubstringFromRange:separatorRange];
            parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateAttributedString:[attrString attributedSubstringFromRange:itemRange]];
        } else {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont userFontOfSize:0.0], NSFontAttributeName, nil];
            if (prefixRange.length > 0)
                prefix = [[[NSAttributedString alloc] initWithString:[str substringWithRange:prefixRange] attributes:attrs] autorelease];
            if (suffixRange.length > 0)
                suffix = [[[NSAttributedString alloc] initWithString:[str substringWithRange:suffixRange] attributes:attrs] autorelease];
            if (separatorRange.length > 0)
                separator = [[[NSAttributedString alloc] initWithString:[str substringWithRange:separatorRange] attributes:attrs] autorelease];
            parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateString:[str substringWithRange:itemRange]];
        }
        
        if ((templateDict = [self convertPubTemplate:parsedTemplate defaultFont:font])) {
            NSArray *defaultItemTemplate = [templateDict objectForKey:@""];
            NSArray *itemTemplate;
            BDSKTypeTemplate *template;
            NSString *type;
            NSArray *currentTypes = [typeTemplates valueForKey:@"pubType"];
            NSArray *types = [templateDict allKeys];
            NSString *defaultType = nil;
            
            if (defaultItemTemplate) {
                NSArray *defaultTypes = [[templateDict allKeysForObject:defaultItemTemplate] arrayByRemovingObject:@""];
                types = [[types mutableCopy] autorelease];
                [(NSMutableArray *)types removeObject:@""];
                if ([defaultTypes count] == 0) {
                    if ([templateDict objectForKey:BDSKArticleString] == nil)
                        defaultType = BDSKArticleString;
                    else if ([templateDict objectForKey:BDSKMiscString] == nil)
                        defaultType = BDSKMiscString;
                    else
                        defaultType = @"(default)";
                    [(NSMutableArray *)types addObject:defaultType];
                } else if ([defaultTypes containsObject:BDSKArticleString])
                    defaultType = BDSKArticleString;
                else if ([defaultTypes containsObject:BDSKMiscString])
                    defaultType = BDSKMiscString;
                else
                    defaultType = [defaultTypes objectAtIndex:0];
            }
            
            [typeTemplates setValue:nil forKey:@"itemTemplate"];
            [typeTemplates setValue:[NSNumber numberWithBool:NO] forKey:@"included"];
            
            for (type in types) {
                NSUInteger currentIndex = [currentTypes indexOfObject:type];
                if (currentIndex == NSNotFound) {
                    currentIndex = [typeTemplates count];
                    template = [self addTypeTemplateForType:type];
                } else {
                    template = [typeTemplates objectAtIndex:currentIndex];
                }
                if ((itemTemplate = [templateDict objectForKey:type])) {
                    [template setIncluded:YES];
                    [template setItemTemplate:itemTemplate];
                } else {
                    BDSKASSERT([type isEqualToString:defaultType]);
                    [template setItemTemplate:defaultItemTemplate];
                }
                if ([type isEqualToString:defaultType])
                    [self setDefaultTypeIndex:currentIndex];
            }
            
            [self setPrefixTemplate:prefix];
            [self setSuffixTemplate:suffix];
            [self setSeparatorTemplate:separator];
            if ([self isRichText]) {
                NSInteger traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
                [self setFontName:[font familyName]];
                [self setFontSize:[font pointSize]];
                [self setBold:(traits & NSBoldFontMask) != 0];
                [self setItalic:(traits & NSItalicFontMask) != 0];
            }
            
            [[self undoManager] removeAllActions];
            [self updateChangeCount:NSChangeCleared];
            
            success = YES;
        }
    }
    
    if (success == NO && outError)
        *outError = [NSError errorWithDomain:BDSKTemplateDocumentErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to open file.", @"Error description"), NSLocalizedDescriptionKey, NSLocalizedString(@"This template cannot be opened by BibDesk. You should edit it manually.", @"Error description"), NSLocalizedRecoverySuggestionErrorKey, nil]];
    
    return success;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    return [NSPrintOperation printOperationWithAttributedString:[self attributedString] printInfo:[self printInfo] settings:printSettings];
}

- (BOOL)undoManagerShouldUndoChange:(id)sender{
	if (![self isDocumentEdited]) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog") 
                                         defaultButton:NSLocalizedString(@"Yes", @"Button title") 
                                       alternateButton:NSLocalizedString(@"No", @"Button title") 
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"You are about to undo past the last point this file was saved. Do you want to do this?", @"Informative text in alert dialog") ];

		NSInteger rv = [alert runModal];
		if (rv == NSAlertAlternateReturn)
			return NO;
	}
	return YES;
}

- (NSArray *)tokensForFields:(NSArray *)array {
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSString *field in array) {
        id token = [fieldTokens objectForKey:field];
        if (token == nil) {
            token = [BDSKToken tokenWithField:field];
            [fieldTokens setObject:token forKey:field];
        }
        [tokens addObject:token];
    }
    return tokens;
}

- (BDSKTypeTemplate *)addTypeTemplateForType:(NSString *)type {
    BDSKTypeManager *tm = [BDSKTypeManager sharedManager];
    NSArray *requiredTokens = [self tokensForFields:[tm requiredFieldsForType:type]];
    NSArray *optionalTokens = [self tokensForFields:[tm optionalFieldsForType:type]];
    BDSKTypeTemplate *template = [[[BDSKTypeTemplate alloc] initWithPubType:type requiredTokens:requiredTokens optionalTokens:optionalTokens] autorelease];
    [self willChangeValueForKey:@"typeTemplates"];
    [typeTemplates addObject:template];
    [self didChangeValueForKey:@"typeTemplates"];
    [self startObservingTypeTemplate:template];
    return template;
}

#pragma mark Accessors

- (NSArray *)typeTemplates {
    return typeTemplates;
}

- (NSUInteger)countOfSizes {
    return sizeof(BDSKDefaultFontSizes) / sizeof(CGFloat);
}

- (id)objectInSizesAtIndex:(NSUInteger)idx {
    return [NSNumber numberWithDouble:BDSKDefaultFontSizes[idx]];
}

- (NSUInteger)countOfTokenSizes {
    return 1 + sizeof(BDSKDefaultFontSizes) / sizeof(CGFloat);
}

- (id)objectInTokenSizesAtIndex:(NSUInteger)idx {
    return [NSNumber numberWithDouble:idx == 0 ? 0.0 : BDSKDefaultFontSizes[idx - 1]];
}

- (NSArray *)specialTokens {
    return specialTokens;
}

- (void)setSpecialTokens:(NSArray *)newSpecialTokens {
    [specialTokens setArray:newSpecialTokens];
}

- (NSArray *)defaultTokens {
    return defaultTokens;
}

- (void)setDefaultTokens:(NSArray *)newDefaultTokens {
    [defaultTokens setArray:newDefaultTokens];
}

- (NSAttributedString *)prefixTemplate {
    return prefixTemplate;
}

- (void)setPrefixTemplate:(NSAttributedString *)newPrefixTemplate {
    [[[self undoManager] prepareWithInvocationTarget:self] setPrefixTemplate:[[prefixTemplate copy] autorelease]];
    [prefixTemplate setAttributedString:newPrefixTemplate ?: [[[NSAttributedString alloc] init] autorelease]];
}

- (NSAttributedString *)suffixTemplate {
    return suffixTemplate;
}

- (void)setSuffixTemplate:(NSAttributedString *)newSuffixTemplate {
    [[[self undoManager] prepareWithInvocationTarget:self] setSuffixTemplate:[[suffixTemplate copy] autorelease]];
    [suffixTemplate setAttributedString:newSuffixTemplate ?: [[[NSAttributedString alloc] init] autorelease]];
}

- (NSAttributedString *)separatorTemplate {
    return separatorTemplate;
}

- (void)setSeparatorTemplate:(NSAttributedString *)newSeparatorTemplate {
    [[[self undoManager] prepareWithInvocationTarget:self] setSeparatorTemplate:[[separatorTemplate copy] autorelease]];
    [separatorTemplate setAttributedString:newSeparatorTemplate ?: [[[NSAttributedString alloc] init] autorelease]];
}

- (BOOL)isRichText {
    return richText;
}

- (void)setRichText:(BOOL)newRichText {
    if (richText != newRichText) {
        [[[self undoManager] prepareWithInvocationTarget:self] setRichText:richText];
        richText = newRichText;
        
        [self updateStrings];
        [self updateOptionView];
        [self updateTextViews];
        [self setFileURL:nil];
        [self setFileType:richText ? BDSKRichTextTemplateDocumentType : BDSKTextTemplateDocumentType];
    }
}

- (NSString *)fontName {
    return fontName;
}

- (void)setFontName:(NSString *)newFontName {
    if (fontName != newFontName) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFontName:fontName];
        [fontName release];
        fontName = [newFontName retain];
        [self updateStrings];
        [self updateTextViews];
    }
}

- (CGFloat)fontSize {
    return fontSize;
}

- (void)setFontSize:(CGFloat)newFontSize {
    if (fabs(fontSize - newFontSize) > 0.0) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFontSize:fontSize];
        fontSize = newFontSize;
        [self updateStrings];
        [self updateTextViews];
    }
}

- (BOOL)isBold {
    return bold;
}

- (void)setBold:(BOOL)newBold {
    if (bold != newBold) {
        [(BDSKTemplateDocument *)[[self undoManager] prepareWithInvocationTarget:self] setBold:bold];
        bold = newBold;
        [self updateStrings];
        [self updateTextViews];
    }
}

- (BOOL)isItalic {
    return italic;
}

- (void)setItalic:(BOOL)newItalic {
    if (italic != newItalic) {
        [(BDSKTemplateDocument *)[[self undoManager] prepareWithInvocationTarget:self] setItalic:italic];
        italic = newItalic;
        [self updateStrings];
        [self updateTextViews];
    }
}

- (BDSKToken *)selectedToken {
    return selectedToken;
}

- (void)setSelectedToken:(BDSKToken *)newSelectedToken {
    if (selectedToken != newSelectedToken) {
        [selectedToken release];
        selectedToken = [newSelectedToken retain];
        [self updateOptionView];
    }
}

- (NSUInteger)defaultTypeIndex {
    return defaultTypeIndex;
}

- (void)setDefaultTypeIndex:(NSUInteger)newDefaultTypeIndex {
    if (defaultTypeIndex != newDefaultTypeIndex) {
        [[[self undoManager] prepareWithInvocationTarget:self] setDefaultTypeIndex:defaultTypeIndex];
        [[typeTemplates objectAtIndex:defaultTypeIndex] setDefault:NO];
        defaultTypeIndex = newDefaultTypeIndex;
        [[typeTemplates objectAtIndex:defaultTypeIndex] setDefault:YES];
        [self updateStrings];
    }
}

- (NSString *)string {
    if (string == nil) {
        NSMutableString *mutString = [NSMutableString string];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"included = 1"];
        NSArray *includedTemplates = [typeTemplates filteredArrayUsingPredicate:predicate];
        BDSKTypeTemplate *template;
        NSString *altPrefix = @"";
        BOOL isSimple = [includedTemplates count] == 0 ||
            ([includedTemplates count] == 1 && [typeTemplates objectAtIndex:defaultTypeIndex] == [includedTemplates lastObject]);
        
        if ([prefixTemplate length]) {
            [mutString appendString:[prefixTemplate string]];
        }
        [mutString appendString:@"<$publications>\n"];
        if (isSimple) {
            [mutString appendString:[[typeTemplates objectAtIndex:defaultTypeIndex] string]];
        } else {
            for (template in includedTemplates) {
                [mutString appendFormat:@"<%@$pubType=%@?>\n", altPrefix, [template pubType]];
                [mutString appendString:[template string]];
                altPrefix = @"?";
            }
            [mutString appendString:@"<?$pubType?>\n"];
            [mutString appendString:[[typeTemplates objectAtIndex:defaultTypeIndex] string]];
            [mutString appendString:@"</$pubType?>\n"];
        }
        if ([separatorTemplate length]) {
            [mutString appendString:@"<?$publications>\n"];
            [mutString appendString:[separatorTemplate string]];
        }
        [mutString appendString:@"</$publications>\n"];
        if ([suffixTemplate length]) {
            [mutString appendString:[suffixTemplate string]];
        }
        string = [mutString copy];
    }
    return string;
}

- (NSAttributedString *)attributedString {
    if (attributedString == nil) {
        NSMutableAttributedString *attrString = nil;
        
        if (richText) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"included = 1"];
            NSArray *includedTemplates = [typeTemplates filteredArrayUsingPredicate:predicate];
            BDSKTypeTemplate *template;
            NSString *altPrefix = @"";
            BOOL isSimple = [includedTemplates count] == 0 ||
                ([includedTemplates count] == 1 && [typeTemplates objectAtIndex:defaultTypeIndex] == [includedTemplates lastObject]);
            NSFont *font = [NSFont fontWithName:fontName size:fontSize];
            NSDictionary *attrs;
            
            attrString = [[[NSMutableAttributedString alloc] init] autorelease];
            
            if (bold)
                font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
            if (italic)
                font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
            attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
            
            if ([prefixTemplate length]) {
                [attrString appendAttributedString:prefixTemplate];
            }
            [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"<$publications>\n" attributes:attrs] autorelease]];
            if (isSimple) {
                [attrString appendAttributedString:[[typeTemplates objectAtIndex:defaultTypeIndex] attributedStringWithDefaultAttributes:attrs]];
            } else {
                for (template in includedTemplates) {
                    NSString *s = [NSString stringWithFormat:@"<%@$pubType=%@?>\n", altPrefix, [template pubType]];
                    [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:s attributes:attrs] autorelease]];
                    [attrString appendAttributedString:[template attributedStringWithDefaultAttributes:attrs]];
                    altPrefix = @"?";
                }
                [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"<?$pubType?>\n" attributes:attrs] autorelease]];
                [attrString appendAttributedString:[[typeTemplates objectAtIndex:defaultTypeIndex] attributedStringWithDefaultAttributes:attrs]];
                [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"</$pubType?>\n" attributes:attrs] autorelease]];
            }
            if ([separatorTemplate length]) {
                [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"<?$publications>\n" attributes:attrs] autorelease]];
                [attrString appendAttributedString:separatorTemplate];
            }
            [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"</$publications>\n" attributes:attrs] autorelease]];
            if ([suffixTemplate length]) {
                [attrString appendAttributedString:suffixTemplate];
            }
            [attrString fixAttributesInRange:NSMakeRange(0, [attrString length])];
        } else {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont userFontOfSize:0.0], NSFontAttributeName, nil];
            attrString = [[[NSMutableAttributedString alloc] initWithString:[self string] attributes:attrs] autorelease];
        }
        
        attributedString = [attrString copy];
    }
    return attributedString;
}

- (NSAttributedString *)previewAttributedString {
    // this should probably parse the template with a preview item
    return [self attributedString];
}

#pragma mark Actions

- (void)addFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        NSArray *tokens = [self tokensForFields:[NSArray arrayWithObjects:[addFieldController field], nil]];
        [self setDefaultTokens:[[self defaultTokens] arrayByAddingObjectsFromArray:tokens]];
        [defaultTokenField setObjectValue:[self defaultTokens]];
        [self updateTokenFields];
    }
}

- (IBAction)addField:(id)sender {
    NSArray *allFields = [[BDSKTypeManager sharedManager] allFieldNamesIncluding:nil excluding:nil];
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Field:", @"Label for adding a field for a template")
                                                                                              fieldsArray:allFields];
	[addFieldController beginSheetModalForWindow:[self windowForSheet]
                                   modalDelegate:self
                                  didEndSelector:@selector(addFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (void)changeValueFromMenu:(id)sender {
    [menuToken setValue:[sender representedObject] forKey:[[sender menu] title]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(changeValueFromMenu:)) {
        NSString *value = [menuItem representedObject];
        NSString *currentValue = [menuToken valueForKey:[[menuItem menu] title]];
        [menuItem setState:currentValue == value || [currentValue isEqualToString:value]];
        return YES;
    } else if ([[BDSKTemplateDocument superclass] instancesRespondToSelector:_cmd]) {
        return [super validateMenuItem:menuItem];
    } else {
        return YES;
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    if ([anItem action] == @selector(saveDocument:)) {
        return YES;
    } else if ([[BDSKTemplateDocument superclass] instancesRespondToSelector:_cmd]) {
        return [super validateUserInterfaceItem:anItem];
    } else {
        return YES;
    }
}

#pragma mark Setup and Update

- (NSArray *)propertiesForTokenType:(BDSKTokenType)type {
    static NSArray *fieldProperties = nil;
    static NSArray *urlProperties = nil;
    static NSArray *personProperties = nil;
    static NSArray *linkedFileProperties = nil;
    static NSArray *dateProperties = nil;
    static NSArray *numberProperties = nil;
    if (fieldProperties == nil) {
        fieldProperties = [[NSArray alloc] initWithObjects:@"casing", @"cleaning", @"appending", nil];
        urlProperties = [[NSArray alloc] initWithObjects:@"urlFormat", @"casing", @"cleaning", @"appending", nil];
        personProperties = [[NSArray alloc] initWithObjects:@"nameStyle", @"joinStyle", @"casing", @"cleaning", @"appending", nil];
        linkedFileProperties = [[NSArray alloc] initWithObjects:@"linkedFileFormat", @"linkedFileJoinStyle", @"appending", nil];
        dateProperties = [[NSArray alloc] initWithObjects:@"dateFormat", @"casing", @"cleaning", @"appending", nil];
        numberProperties = [[NSArray alloc] initWithObjects:@"counterStyle", @"counterCasing", nil];
    }
    switch (type) {
        case BDSKFieldTokenType:        return fieldProperties;
        case BDSKURLTokenType:          return urlProperties;
        case BDSKPersonTokenType:       return personProperties;
        case BDSKLinkedFileTokenType:   return linkedFileProperties;
        case BDSKDateTokenType:         return dateProperties;
        case BDSKNumberTokenType:       return numberProperties;
        default:                        return nil;
    }
}

- (NSMenu *)newOptionsMenuForTokenType:(BDSKTokenType)type {
    NSMenu *menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
    NSBundle *bundle = [NSBundle mainBundle];
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    for (NSString *key in [self propertiesForTokenType:type]) {
        NSMenu *submenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:[key stringByAppendingString:@"Key"]];
        [submenu setTitle:[key stringByAppendingString:@"Key"]];
        for (NSDictionary *dict in [templateOptions valueForKey:key]) {
            NSMenuItem *item = [submenu addItemWithTitle:[dict objectForKey:@"displayName"]
                                                  action:@selector(changeValueFromMenu:) keyEquivalent:@""];
            [item setTarget:self];
            [item setRepresentedObject:[transformer reverseTransformedValue:[dict objectForKey:@"key"]]];
        }
        [menu addItemWithTitle:[bundle localizedStringForKey:key value:@"" table:@"TemplateOptions"] submenu:submenu];
        [submenu release];
    }
    return menu;
}

- (void)updateTextViews {
    [prefixTemplateTextView setRichText:[self isRichText]];
    [separatorTemplateTextView setRichText:[self isRichText]];
    [suffixTemplateTextView setRichText:[self isRichText]];
    if ([self isRichText]) {
        NSFont *font = [NSFont fontWithName:[self fontName] size:[self fontSize]];
        if ([self isBold])
            font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
        if ([self isItalic])
            font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
        if ([[prefixTemplateTextView string] length] == 0)
            [prefixTemplateTextView setFont:font];
        if ([[separatorTemplateTextView string] length] == 0)
            [separatorTemplateTextView setFont:font];
        if ([[suffixTemplateTextView string] length] == 0)
            [suffixTemplateTextView setFont:font];
    } else {
        [prefixTemplateTextView setFont:[NSFont userFontOfSize:0.0]];
        [separatorTemplateTextView setFont:[NSFont userFontOfSize:0.0]];
        [suffixTemplateTextView setFont:[NSFont userFontOfSize:0.0]];
    }
}

- (void)updateTokenFields {
    NSRect frame;
    CGFloat width = 0.0;
    
    for (NSTokenField *tokenField in [NSArray arrayWithObjects:specialTokenField, requiredTokenField, optionalTokenField, defaultTokenField, nil]) {
        [tokenField sizeToFit];
        frame = [tokenField frame];
        width = fmax(width, NSWidth(frame));
        // NSTokenField bug: add 10px to the width, because otherwise the tracking rect for the last token is broken
        frame.size.width += 10.0;
        [tokenField setFrame:frame];
    }
    
    NSScrollView *scrollView = [specialTokenField enclosingScrollView];
    frame = [[scrollView documentView] frame];
    frame.size.width = width;
    [[scrollView documentView] setFrame:frame];
    [scrollView setNeedsDisplay:YES];
}

- (void)updateStrings {
    [self willChangeValueForKey:@"string"];
    [string release];
    string = nil;
    [self didChangeValueForKey:@"string"];
    [self willChangeValueForKey:@"attributedString"];
    [attributedString release];
    attributedString = nil;
    [self didChangeValueForKey:@"attributedString"];
}

- (void)updateOptionView {
    NSArray *currentOptionViews = [[tokenOptionsBox contentView] subviews];
    NSMutableArray *optionViews = nil;
    
    if (selectedToken && [selectedToken isKindOfClass:[BDSKToken class]]) {
        switch ([selectedToken type]) {
            case BDSKFieldTokenType:
                optionViews = [NSMutableArray arrayWithObjects:fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKURLTokenType:
                optionViews = [NSMutableArray arrayWithObjects:urlOptionsView, fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKPersonTokenType:
                optionViews = [NSMutableArray arrayWithObjects:personOptionsView, fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKLinkedFileTokenType:
                optionViews = [NSMutableArray arrayWithObjects:linkedFileOptionsView, appendingOptionsView, nil];
                break;
            case BDSKDateTokenType:
                optionViews = [NSMutableArray arrayWithObjects:dateOptionsView, fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKNumberTokenType:
                optionViews = [NSMutableArray arrayWithObjects:numberOptionsView, nil];
                break;
            case BDSKTextTokenType:
                optionViews = [NSMutableArray arrayWithObjects:textOptionsView, nil];
                break;
            default:
                optionViews = [NSMutableArray array];
        }
        if (richText)
            [optionViews addObject:fontOptionsView];
    }
    
    if ([optionViews isEqualToArray:currentOptionViews] == NO) {
        NSRect frame = [[tokenOptionsBox contentView] bounds];
        NSPoint point = NSMakePoint(NSMinX(frame) + 7.0, NSMaxY(frame) - 7.0);
        
        [currentOptionViews retain];
        [currentOptionViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [currentOptionViews release];
        
        for (NSView *view in optionViews) {
            frame = [view frame];
            point.y -= NSHeight(frame);
            frame.origin = point;
            [view setFrame:frame];
            [[tokenOptionsBox contentView] addSubview:view];
        }
    }
}

#pragma mark KVO and Undo

- (void)startObservingTypeTemplate:(BDSKTypeTemplate *)template {
    [template addObserver:self forKeyPath:@"itemTemplate" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&BDSKTypeTemplateObservationContext];
    [template addObserver:self forKeyPath:@"included" options:NSKeyValueObservingOptionOld context:&BDSKTypeTemplateObservationContext];
    [self startObservingTokens:[template itemTemplate]];
}

- (void)stopObservingTypeTemplate:(BDSKTypeTemplate *)template {
    [template removeObserver:self forKeyPath:@"itemTemplate"];
    [template removeObserver:self forKeyPath:@"included"];
    [self stopObservingTokens:[template itemTemplate]];
}

- (void)startObservingTokens:(NSArray *)tokens {
    for (id token in tokens) {
        if ([token isKindOfClass:[BDSKToken class]]) {
            for (NSString *key in [token keysForValuesToObserveForUndo])
                [token addObserver:self forKeyPath:key options:NSKeyValueObservingOptionOld context:&BDSKTokenPropertiesObservationContext];
        }
    }
}

- (void)stopObservingTokens:(NSArray *)tokens {
    for (id token in tokens) {
        if ([token isKindOfClass:[BDSKToken class]]) {
            for (NSString *key in [token keysForValuesToObserveForUndo])
                [token removeObserver:self forKeyPath:key];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKTypeTemplateObservationContext) {
        
        BDSKTypeTemplate *template = (BDSKTypeTemplate *)object;
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        if ([oldValue isEqual:[NSNull null]]) oldValue = nil;
        
        if ([keyPath isEqualToString:@"itemTemplate"]) {
            id newValue = [change objectForKey:NSKeyValueChangeNewKey];
            if ([newValue isEqual:[NSNull null]]) newValue = nil;
            
            [self stopObservingTokens:oldValue];
            [self startObservingTokens:newValue];
            
            // KVO in NSTokenField binding does not work
            if (template == [typeTemplates objectAtIndex:[tableView selectedRow]])
                [itemTemplateTokenField setObjectValue:[template itemTemplate]];
            [[[self undoManager] prepareWithInvocationTarget:template] setItemTemplate:oldValue];
        } else if ([keyPath isEqualToString:@"included"]) {
            [[[self undoManager] prepareWithInvocationTarget:template] setIncluded:[oldValue boolValue]];
        }

        [self updateStrings];
        
    } else if (context == &BDSKTokenPropertiesObservationContext) {
        
        BDSKToken *token = (BDSKToken *)object;
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        if ([oldValue isEqual:[NSNull null]]) oldValue = nil;
        
        [[[self undoManager] prepareWithInvocationTarget:token] setKey:keyPath toValue:oldValue];
        
        [self updateStrings];
        if ([token type] == BDSKTextTokenType) {
            NSArray *currentItemTemplate = [itemTemplateTokenField objectValue];
            if ([currentItemTemplate indexOfObjectIdenticalTo:token] != NSNotFound)
                [itemTemplateTokenField setObjectValue:[[currentItemTemplate copy] autorelease]];
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Notification handlers

- (void)handleDidChangeSelectionNotification:(NSNotification *)notification {
    NSTextView *textView = [[notification userInfo] objectForKey:@"NSFieldEditor"];
    
    // we shouldn't remove the selectedToken when the focus turns to a text field
    if ([textView delegate]) {
        BDSKToken *token = nil;
        NSArray *selRanges = [textView selectedRanges];
        
        if ([selRanges count] == 1) {
            NSRange range = [[selRanges lastObject] rangeValue];
            
            if (range.length == 1) {
                NSDictionary *attrs = [[textView textStorage] attributesAtIndex:range.location effectiveRange:NULL];
                id attachment = [attrs objectForKey:NSAttachmentAttributeName];
                
                if (attachment) {
                    if ([attachment respondsToSelector:@selector(representedObject)])
                        token = [attachment representedObject];
                    else if ([[attachment attachmentCell] respondsToSelector:@selector(representedObject)])
                        token = [(id)[attachment attachmentCell] representedObject];
                    if (token && [token isKindOfClass:[BDSKToken class]] == NO)
                        token = nil;
                }
            } else if (NSEqualRanges(range, NSMakeRange(0,0))) // this happens when you hover over a token on Leopard, very stupid
                return;
        }
        [self setSelectedToken:token];
    }
}

- (void)textDidEndEditing:(NSNotification *)notification {
    NSText *textView = [notification object];
    if (textView == separatorTemplateTextView || textView == prefixTemplateTextView || textView == suffixTemplateTextView)
        [self updateStrings];
}

- (BOOL)windowShouldClose:(id)window {
    return [ownerController commitEditing];
}

- (void)windowWillClose:(NSNotification *)notification {
    [ownerController unbind:@"contentObject"];
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo {
    if ([ownerController commitEditing]) {
        if ([[self undoManager] groupingLevel] > 0) {
            [self updateChangeCount:NSChangeDone];
            [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
            [self updateChangeCount:NSChangeUndone];
        } else {
            [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
        }
    } else if (delegate && shouldCloseSelector) {
        NSInvocation *invocation = [NSInvocation invocationWithTarget:delegate selector:shouldCloseSelector];
        BOOL no = NO;
        [invocation setArgument:&self atIndex:2];
        [invocation setArgument:&no atIndex:3];
        [invocation setArgument:&contextInfo atIndex:4];
        [invocation invoke]; 
    }
}

#pragma mark NSTokenField delegate

// implement pasteboard delegate methods as a workaround for not doing the string->token transformation of tokenField:representedObjectForEditingString: (apparently needed for drag-and-drop on post-10.4 systems)
- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard {
    NSMutableString *str = [NSMutableString string];
    
    for (id object in objects)
        [str appendString:[self tokenField:tokenField displayStringForRepresentedObject:object]];
    
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKTemplateTokensPboardType, NSStringPboardType, nil] owner:nil];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:objects];
    [pboard setData:data forType:BDSKTemplateTokensPboardType];
    [pboard setString:str forType:NSStringPboardType];
    return nil != data;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField readFromPasteboard:(NSPasteboard *)pboard {
    if (tokenField == itemTemplateTokenField) {
        NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTemplateTokensPboardType, NSStringPboardType, nil]];
        if ([type isEqualToString:BDSKTemplateTokensPboardType]) {
            NSData *data = [pboard dataForType:BDSKTemplateTokensPboardType];
            return [NSKeyedUnarchiver unarchiveObjectWithData:data];
        } else if ([type isEqualToString:NSStringPboardType]) {
            return [NSArray arrayWithObjects:[pboard stringForType:NSStringPboardType], nil];
        }
    }
    return nil;
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
    if ([representedObject isKindOfClass:[BDSKToken class]])
        return [representedObject title];
    else if ([representedObject isKindOfClass:[NSString class]])
        return representedObject;
    return @"";
}

- (NSString *)tokenField:(NSTokenField *)tokenField editingStringForRepresentedObject:(id)representedObject {
    return nil;
}

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
    if ([representedObject isKindOfClass:[BDSKToken class]])
        return NSRoundedTokenStyle;
    else if ([representedObject isKindOfClass:[NSString class]])
        return NSPlainTextTokenStyle;
    return NSRoundedTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
    return [representedObject isKindOfClass:[BDSKToken class]] && [(BDSKToken *)representedObject type] != BDSKTextTokenType;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
    if ([representedObject isKindOfClass:[BDSKToken class]]) {
        menuToken = representedObject;
        switch ([(BDSKToken *)representedObject type]) {
            case BDSKFieldTokenType:
                if (fieldOptionsMenu == nil)
                    fieldOptionsMenu = [self newOptionsMenuForTokenType:BDSKFieldTokenType];
                return fieldOptionsMenu;
            case BDSKURLTokenType:
                if (urlOptionsMenu == nil)
                    urlOptionsMenu = [self newOptionsMenuForTokenType:BDSKURLTokenType];
                return urlOptionsMenu;
            case BDSKPersonTokenType:
                if (personOptionsMenu == nil)
                    personOptionsMenu = [self newOptionsMenuForTokenType:BDSKPersonTokenType];
                return personOptionsMenu;
            case BDSKLinkedFileTokenType:
                if (linkedFileOptionsMenu == nil)
                    linkedFileOptionsMenu = [self newOptionsMenuForTokenType:BDSKLinkedFileTokenType];
                return linkedFileOptionsMenu;
            case BDSKDateTokenType:
                if (dateOptionsMenu == nil)
                    dateOptionsMenu = [self newOptionsMenuForTokenType:BDSKDateTokenType];
                return dateOptionsMenu;
            case BDSKNumberTokenType:
                if (numberOptionsMenu == nil)
                    numberOptionsMenu = [self newOptionsMenuForTokenType:BDSKNumberTokenType];
                return numberOptionsMenu;
            default: 
                return nil;
        }
    }
    return nil;
}

- (void)tokenField:(NSTokenField *)tokenField textViewDidChangeSelection:(NSTextView *)textView {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:textView, @"NSFieldEditor", nil];
    NSNotification *note = [NSNotification notificationWithName:BDSKTokenFieldDidChangeSelectionNotification object:tokenField userInfo:userInfo];
    [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName forModes:nil];
}

#pragma mark NSTableView delegate and dataSource

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self setSelectedToken:nil];
    [self updateTokenFields];
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation {
    if ([[tableColumn identifier] isEqualToString:@"included"])
        return NSLocalizedString(@"Check to include an item template for this type", @"Tool tip message");
    return nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv{ return 0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row { return nil; }

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil] owner:nil];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:BDSKTypeTemplateRowsPboardType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
    if (op == NSTableViewDropAbove)
        [tv setDropRow:row == -1 ? 0 : row dropOperation:NSTableViewDropOn];
    
    return type ? NSDragOperationCopy : NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
    if (type) {
        NSInteger idx = [[NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:BDSKTypeTemplateRowsPboardType]] lastIndex];
        BDSKTypeTemplate *sourceTemplate = [typeTemplates objectAtIndex:idx];
        BDSKTypeTemplate *targetTemplate = [typeTemplates objectAtIndex:row];
        [targetTemplate setItemTemplate:[[[NSArray alloc] initWithArray:[sourceTemplate itemTemplate] copyItems:YES] autorelease]];
        return YES;
    }
    return NO;
}

- (NSArray *)tableView:(NSTableView *)tv typeSelectHelperSelectionStrings:(BDSKTypeSelectHelper *)aTypeSelectHelper {
    return [[self typeTemplates] valueForKey:@"pubType"];
}

- (void)tableViewInsertNewline:(NSTableView *)tv {
    BDSKTypeTemplate *selTemplate = [typeTemplates objectAtIndex:[tableView selectedRow]];
    [selTemplate setIncluded:[selTemplate isIncluded] == NO];
}

#pragma mark NSSplitView delegate

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
    if (sender == tableViewSplitView) {
        return proposedMax - 600.0;
    } else {
        return proposedMax;
    }
}

#pragma mark Reading

- (NSString *)propertyForKey:(NSString *)key tokenType:(BDSKTokenType)type {
    for (NSString *prop in [self propertiesForTokenType:type]) {
        if ([[templateOptions valueForKeyPath:[prop stringByAppendingString:@".key"]] containsObject:key])
            return [prop stringByAppendingString:@"Key"];
    }
    return nil;
}

- (void)setFont:(NSFont *)font ofToken:(BDSKToken *)token defaultFont:(NSFont *)defaultFont{
    if ([font isEqual:defaultFont] == NO) {
        NSInteger defaultTraits = [[NSFontManager sharedFontManager] traitsOfFont:defaultFont];
        NSInteger traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
        BOOL defaultBold = (defaultTraits & NSBoldFontMask) != 0;
        BOOL defaultItalic = (defaultTraits & NSItalicFontMask) != 0;
        BOOL isBold = (traits & NSBoldFontMask) != 0;
        BOOL isItalic = (traits & NSItalicFontMask) != 0;
        
        if ([[font familyName] isEqualToString:[defaultFont familyName]] == NO)
            [token setFontName:[font familyName]];
        if (fabs([font pointSize] - [defaultFont pointSize]) > 0.0)
            [token setFontSize:[font pointSize]];
        if (isBold != defaultBold)
            [token setBold:isBold];
        if (isItalic != defaultItalic)
            [token setItalic:isItalic];
    }
}

- (NSArray *)tokensForTextTag:(BDSKTemplateTag *)tag allowText:(BOOL)allowText defaultFont:(NSFont *)defaultFont {
    NSMutableArray *tokens = [NSMutableArray array];
    if (defaultFont) {
        NSAttributedString *text = [(BDSKRichTextTemplateTag *)tag attributedText];
        NSUInteger length = [text length];
        NSRange range = NSMakeRange(0, 0);
        
        while (NSMaxRange(range) < length) {
            id token;
            NSFont *font = [text attribute:NSFontAttributeName atIndex:range.location longestEffectiveRange:&range inRange:NSMakeRange(range.location, length - range.location)];
            if (allowText && [font isEqual:defaultFont]) {
                token = [[(BDSKRichTextTemplateTag *)tag attributedText] string];
            } else {
                token = [[[BDSKTextToken alloc] initWithTitle:[text string]] autorelease];
                [self setFont:font ofToken:token defaultFont:defaultFont];
            }
            [tokens addObject:token];
        }
    } else if (allowText) {
        [tokens addObject:[(BDSKTextTemplateTag *)tag text]];
    } else {
        [tokens addObject:[[[BDSKTextToken alloc] initWithTitle:[(BDSKTextTemplateTag *)tag text]] autorelease]];
    }
    return tokens;
}

- (id)tokenForValueTag:(BDSKValueTemplateTag *)tag defaultFont:(NSFont *)defaultFont {
    NSArray *keys = [[tag keyPath] componentsSeparatedByString:@"."];
    NSString *key = [keys count] ? [keys objectAtIndex:0] : nil;
    BDSKToken *token = nil;
    BDSKTokenType type;
    NSString *field = nil;
    NSInteger i = 0, j;
    
    if (([key isEqualToString:@"fields"] || [key isEqualToString:@"urls"] || [key isEqualToString:@"persons"]) && [keys count] > 1)
        field = [keys objectAtIndex:++i];
    else if ([key isEqualToString:@"citeKey"])
        field = BDSKCiteKeyString;
    else if ([key isEqualToString:@"pubType"])
        field = BDSKPubTypeString;
    else if ([key isEqualToString:@"itemIndex"])
        field = BDSKItemNumberString;
    else if ([key isEqualToString:@"authors"])
        field = BDSKAuthorString;
    else if ([key isEqualToString:@"editors"])
        field = BDSKEditorString;
    else
        return nil;
    
    token = [BDSKToken tokenWithField:field];
    type = [(BDSKToken *)token type];
    keys = [keys subarrayWithRange:NSMakeRange(i + 1, [keys count] - i - 1)];
    NSInteger count = [keys count];
    NSString *property;
    
    if (type == BDSKPersonTokenType && [keys firstObjectCommonWithArray:[templateOptions valueForKeyPath:@"joinStyle.key"]] == nil)
        return nil;
    
    for (i = 0; i < count; i++) {
        for (j = count; j > i; j--) {
            key = [[keys subarrayWithRange:NSMakeRange(i, j - i)] componentsJoinedByString:@"."];
            if ((property = [self propertyForKey:key tokenType:type]))
                break;
        }
        if (j > i)
            [token setValue:key forKey:property];
        else return nil;
        i = j - 1;
    }
    
    if (defaultFont) {
        NSFont *font = [[(BDSKRichValueTemplateTag *)tag attributes] objectForKey:NSFontAttributeName];
        [self setFont:font ofToken:token defaultFont:defaultFont];
    }
    
    return token;
}

- (id)tokenForConditionTag:(BDSKConditionTemplateTag *)tag defaultFont:(NSFont *)defaultFont {
    NSInteger count = [tag countOfSubtemplates];
    if ([(BDSKConditionTemplateTag *)tag matchType] != BDSKTemplateTagMatchOther || count > 2)
        return nil;
    
    NSArray *nonemptyTemplate = [tag objectInSubtemplatesAtIndex:0];
    NSArray *emptyTemplate = count > 1 ? [tag objectInSubtemplatesAtIndex:1] : nil;
    id token = nil;
    
    if ([nonemptyTemplate count] == 1 && [(BDSKTemplateTag *)[nonemptyTemplate lastObject] type] == BDSKTextTemplateTagType) {
        NSArray *keys = [[tag keyPath] componentsSeparatedByString:@"."];
        NSArray *tokens;
        if ([keys count] != 2 || [[keys objectAtIndex:0] isEqualToString:@"fields"] == NO)
            return nil;
        if ((tokens = [self tokensForTextTag:tag allowText:NO defaultFont:defaultFont])) {
            if ([tokens count] == 1) {
                token = [tokens lastObject];
                [token setField:[keys lastObject]];
                if ([emptyTemplate count]) {
                    id textTag = [emptyTemplate lastObject];
                    if ([(BDSKTemplateTag *)textTag type] != BDSKTextTemplateTagType)
                        return nil;
                    [token setAltText:defaultFont ? [[(BDSKRichTextTemplateTag *)textTag attributedText] string] : [(BDSKTextTemplateTag *)textTag text]];
                }
            } else return nil;
        } else return nil;
    } else if ([emptyTemplate count] == 0 && [nonemptyTemplate count] < 4) {
        NSInteger i = 0;
        BDSKTemplateTag *subtag = [nonemptyTemplate objectAtIndex:i];
        NSString *prefix = nil, *suffix = nil;
        count = [nonemptyTemplate count];
        
        if ([subtag type] == BDSKTextTemplateTagType) {
            prefix = defaultFont ? [[(BDSKRichTextTemplateTag *)subtag attributedText] string] : [(BDSKTextTemplateTag *)subtag text];
            subtag = ++i < count ? [nonemptyTemplate objectAtIndex:i] : nil;
        }
        if ([subtag type] == BDSKValueTemplateTagType && [[(BDSKValueTemplateTag *)subtag keyPath] isEqualToString:[tag keyPath]]) {
            token = [self tokenForValueTag:(BDSKValueTemplateTag *)subtag defaultFont:defaultFont];
            subtag = ++i < count ? [nonemptyTemplate objectAtIndex:i] : nil;
        } else return nil;
        if (subtag) {
            if ([subtag type] == BDSKTextTemplateTagType) {
                suffix = defaultFont ? [[(BDSKRichTextTemplateTag *)subtag attributedText] string] : [(BDSKTextTemplateTag *)subtag text];
            } else return nil;
        }
        if (prefix)
            [token setPrefix:prefix];
        if (suffix)
            [token setSuffix:suffix];
    } else return nil;
    
    return token;
}

- (NSArray *)convertItemTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont {
    NSMutableArray *result = [NSMutableArray array];
    id token;
    
    for (BDSKTemplateTag *tag in templateArray) {
        switch ([(BDSKTemplateTag *)tag type]) {
            case BDSKTextTemplateTagType:
                if ((token = [self tokensForTextTag:tag allowText:YES defaultFont:defaultFont]))
                    [result addObjectsFromArray:token];
                else return nil;
                break;
            case BDSKValueTemplateTagType:
                if ((token = [self tokenForValueTag:(BDSKValueTemplateTag *)tag defaultFont:defaultFont]))
                    [result addObject:token];
                else return nil;
                break;
            case BDSKConditionTemplateTagType:
                if ((token = [self tokenForConditionTag:(BDSKConditionTemplateTag *)tag defaultFont:defaultFont]))
                    [result addObject:token];
                else return nil;
                break;
            default:
                return nil;
        }
    }
    
    return result;
}

- (NSDictionary *)convertPubTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *itemTemplate;
    BDSKTemplateTag *tag = [templateArray count] ? [templateArray objectAtIndex:0] : nil;
    
    if ([tag type] == BDSKConditionTemplateTagType && [[(BDSKConditionTemplateTag *)tag keyPath] isEqualToString:@"pubType"]) {
        if ([(BDSKConditionTemplateTag *)tag matchType] != BDSKTemplateTagMatchEqual)
            return nil;
        
        NSArray *matchStrings = [(BDSKConditionTemplateTag *)tag matchStrings];
        NSUInteger i = 0, keyCount = [matchStrings count], count = [(BDSKConditionTemplateTag *)tag countOfSubtemplates];
        
        for (i = 0; i < count; i++) {
            if ((itemTemplate = [self convertItemTemplate:[(BDSKConditionTemplateTag *)tag objectInSubtemplatesAtIndex:i] defaultFont:defaultFont]))
                [result setObject:itemTemplate forKey:i < keyCount ? [(NSString *)[matchStrings objectAtIndex:i] entryType] : @""];
            else return nil;
        }
    } else {
        if ((itemTemplate = [self convertItemTemplate:templateArray defaultFont:defaultFont]))
            [result setObject:itemTemplate forKey:@""];
        else return nil;
    }
    
    return result;
}

@end

#pragma mark -

@interface NSTokenField (Private)
- (NSRange)textView:(NSTextView *)aTextView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange;
- (void)textViewDidChangeSelection:(NSNotification *)notification;
@end

@implementation BDSKTokenField

- (NSRange)textView:(NSTextView *)aTextView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange {
    if ([[BDSKTokenField superclass] instancesRespondToSelector:_cmd])
        newSelectedCharRange = [super textView:aTextView willChangeSelectionFromCharacterRange:oldSelectedCharRange toCharacterRange:newSelectedCharRange];
    if ([self isEditable] == NO && newSelectedCharRange.length > 1)
        newSelectedCharRange.length = 1;
    return newSelectedCharRange;
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    if ([[BDSKTokenField superclass] instancesRespondToSelector:_cmd])
        [super textViewDidChangeSelection:notification];
    if ([[self delegate] respondsToSelector:@selector(tokenField:textViewDidChangeSelection:)])
        [[self delegate] tokenField:self textViewDidChangeSelection:[notification object]];
}

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKTokenFieldDelegate>)delegate { return (id <BDSKTokenFieldDelegate>)[super delegate]; }
- (void)setDelegate:(id <BDSKTokenFieldDelegate>)newDelegate { [super setDelegate:newDelegate]; }
#endif

@end

#pragma mark -

@implementation BDSKFlippedClipView
- (BOOL)isFlipped { return YES; }
@end

#pragma mark -

@implementation BDSKValueOrNoneTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)string {
	return string ?: @"<None>";
}

- (id)reverseTransformedValue:(id)string {
	return [string isEqualToString:@"<None>"] ? nil : string;
}

@end

#pragma mark -

static inline NSRange makeRange(NSUInteger start, NSUInteger end) {
    NSRange r;
    r.location = start;
    r.length = end - start;
    return r;
}

static inline NSUInteger startOfTrailingEmptyLine(NSString *string, NSRange range, BOOL requireNL) {
    NSRange lastCharRange = [string rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:NSBackwardsSearch range:range];
    NSUInteger start = NSNotFound;
    if (lastCharRange.location != NSNotFound) {
        unichar lastChar = [string characterAtIndex:lastCharRange.location];
        NSUInteger rangeEnd = NSMaxRange(lastCharRange);
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar])
            start = rangeEnd;
    } else if (requireNL == NO) {
        start = range.location;
    }
    return start;
}

static inline NSUInteger endOfLeadingEmptyLine(NSString *string, NSRange range, BOOL requireNL) {
    NSRange firstCharRange = [string rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:0 range:range];
    NSUInteger end = NSNotFound;
    if (firstCharRange.location != NSNotFound) {
        unichar firstChar = [string characterAtIndex:firstCharRange.location];
        NSUInteger rangeEnd = NSMaxRange(firstCharRange);
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:firstChar]) {
            if (firstChar == NSCarriageReturnCharacter && rangeEnd < NSMaxRange(range) && [string characterAtIndex:rangeEnd] == NSNewlineCharacter)
                end = rangeEnd + 1;
            else 
                end = rangeEnd;
        }
    } else if (requireNL == NO) {
        end = NSMaxRange(range);
    }
    return end;
}

static inline BOOL getTemplateRanges(NSString *str, NSRange *prefixRangePtr, NSRange *suffixRangePtr, NSRange *separatorRangePtr, NSRange *itemRangePtr) {
    if ([str length] == 0)
        return NO;
    
    NSUInteger length = [str length], startLoc = NSNotFound, tmpLoc;
    NSRange startRange = [str rangeOfString:@"<$publications>"];
    NSRange endRange = { NSNotFound, 0 };
    NSRange sepRange = { NSNotFound, 0 };
    
    if (startRange.location != NSNotFound) {
        startLoc = startRange.location;
        
        tmpLoc = startOfTrailingEmptyLine(str, makeRange(0, startRange.location), NO);
        if (tmpLoc != NSNotFound)
            startRange = makeRange(tmpLoc, NSMaxRange(startRange));
        tmpLoc = endOfLeadingEmptyLine(str, makeRange(NSMaxRange(startRange), length), YES);
        if (tmpLoc != NSNotFound)
            startRange = makeRange(startRange.location, tmpLoc);
        
        endRange = [str rangeOfString:@"</$publications>" options:NSBackwardsSearch range:makeRange(NSMaxRange(startRange), length)];
        
        if (endRange.location != NSNotFound) {
            tmpLoc = startOfTrailingEmptyLine(str, makeRange(NSMaxRange(startRange), endRange.location), YES);
            if (tmpLoc != NSNotFound)
                endRange = makeRange(tmpLoc, NSMaxRange(endRange));
            tmpLoc = endOfLeadingEmptyLine(str, makeRange(NSMaxRange(endRange), length), NO);
            if (tmpLoc != NSNotFound)
                endRange = makeRange(endRange.location, tmpLoc);
            
            sepRange = [str rangeOfString:@"<?$publications>" options:NSBackwardsSearch range:makeRange(NSMaxRange(startRange), endRange.location)];
            if (sepRange.location != NSNotFound) {
                tmpLoc = startOfTrailingEmptyLine(str, makeRange(NSMaxRange(startRange), sepRange.location), YES);
                if (tmpLoc != NSNotFound)
                    sepRange = makeRange(tmpLoc, NSMaxRange(sepRange));
                tmpLoc = endOfLeadingEmptyLine(str, makeRange(NSMaxRange(sepRange), endRange.location), YES);
                if (tmpLoc != NSNotFound)
                    sepRange = makeRange(sepRange.location, tmpLoc);
            }
        }
    }
    
    if (endRange.location == NSNotFound)
        return NO;
    
    *prefixRangePtr = NSMakeRange(0, startRange.location);
    *suffixRangePtr = makeRange(NSMaxRange(endRange), length);
    if (sepRange.location == NSNotFound) {
        *separatorRangePtr = NSMakeRange(NSNotFound, 0);
        *itemRangePtr = makeRange(NSMaxRange(startRange), endRange.location);
    } else {
        *separatorRangePtr = makeRange(NSMaxRange(sepRange), endRange.location);
        *itemRangePtr = makeRange(NSMaxRange(startRange), sepRange.location);
    }
    return YES;
}
