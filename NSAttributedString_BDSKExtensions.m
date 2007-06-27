//
//  NSAttributedString_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 6/5/06.
/*
 This software is Copyright (c) 2006,2007
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

#import "NSAttributedString_BDSKExtensions.h"
#import "BDSKComplexString.h"
#import "NSString_BDSKExtensions.h"
#import "NSCharacterSet_BDSKExtensions.h"
#import "BDSKFontManager.h"

static NSString *BDSKRangeKey = @"__BDSKRange";

static void BDSKGetAttributeDictionariesAndFixString(NSMutableArray *attributeDictionaries, NSMutableString *mutableString, NSDictionary *attributes, NSRange *rangePtr)
{
    OBASSERT(nil != mutableString);
    
    // we need something to copy and add to the array
    if (nil == attributes)
        attributes = [NSDictionary dictionary];
    
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSString *texStyle = nil;    
    NSMutableDictionary *attrs;
    NSFont *font = [attributes objectForKey:NSFontAttributeName];
    if (font == nil)
        font = [NSFont systemFontOfSize:0];
    
    NSRange range = *rangePtr;
    NSRange searchRange = range;
    NSRange cmdRange;
    NSRange styleRange;
    unsigned startLoc; // starting character index to apply tex attributes
    unsigned endLoc;   // ending index to apply tex attributes
    
    CFAllocatorRef alloc = CFGetAllocator(mutableString);
    
    while( (cmdRange = [mutableString rangeOfTeXCommandInRange:searchRange]).location != NSNotFound){
        
        // copy the command
        texStyle = (NSString *)CFStringCreateWithSubstring(alloc, (CFStringRef)mutableString, CFRangeMake(cmdRange.location, cmdRange.length));
        
        // delete the command, now that we know what it was
        if ([texStyle isEqualToString:@"\\ "]) {
            
            [mutableString replaceCharactersInRange:cmdRange withString:@" "];
            range.length -= 1;
            
        } else {
            
            [mutableString deleteCharactersInRange:cmdRange];
            range.length -= cmdRange.length;
            
            startLoc = cmdRange.location;
            endLoc = NSNotFound;
            searchRange = NSMakeRange(startLoc, NSMaxRange(range) - startLoc);
            
            // see if this is a font command
            NSFontTraitMask newTrait = [fontManager fontTraitMaskForTeXStyle:texStyle];
            [texStyle release];
            
            if (0 != newTrait) {
                
                // remember, we deleted our command, but not the brace
                if([mutableString characterAtIndex:startLoc] == '{' && (endLoc = [mutableString indexOfRightBraceMatchingLeftBraceInRange:searchRange]) != NSNotFound){
                    
                    // have to delete the braces as we go along, or else ranges will be hosed after deleting at the end
                    [mutableString deleteCharactersInRange:NSMakeRange(startLoc, 1)];
                    
                    // deleting the left brace just shifted everything to the left
                    [mutableString deleteCharactersInRange:NSMakeRange(endLoc - 1, 1)];
                    
                    range.length -= 2;
                    
                    // account for the braces, since we'll be removing them
                    styleRange = NSMakeRange(startLoc, endLoc - startLoc - 1);
                    
                    attrs = [attributes mutableCopy];
                    [attrs setObject:[fontManager convertFont:font toHaveTrait:newTrait]
                              forKey:NSFontAttributeName];
                    
                    // recursively parse the part inside the braces, can change styleRange
                    BDSKGetAttributeDictionariesAndFixString(attributeDictionaries, mutableString, attrs, &styleRange);
                    
                    range.length -= endLoc - startLoc - 1 - styleRange.length;
                    endLoc = NSMaxRange(styleRange);
                    
                    [attrs setObject:[NSValue valueWithRange:styleRange] forKey:BDSKRangeKey];
                    [attributeDictionaries addObject:attrs];
                    [attrs release];
                }
            }
        }
        
        if (endLoc == NSNotFound)
            endLoc = startLoc + 1;
        
        // new range, since we've altered the string (we don't use endLoc because of possibly nested commands)
        searchRange = NSMakeRange(endLoc, NSMaxRange(range) - endLoc);
    }
    
    *rangePtr = range;
}

static void BDSKApplyAttributesToString(const void *value, void *context)
{
    NSDictionary *dict = (void *)value;
    NSMutableAttributedString *mas = context;
    [mas addAttributes:dict range:[[dict objectForKey:BDSKRangeKey] rangeValue]];    
}


@implementation NSAttributedString (BDSKExtensions)

- (id)initWithTeXString:(NSString *)string attributes:(NSDictionary *)attributes collapseWhitespace:(BOOL)collapse{

    NSMutableAttributedString *mas;
    
    // get rid of whitespace if we have to; we can't use this on the attributed string's content store, though
    if(collapse){
        if([string isComplex])
            string = [NSString stringWithString:string];
        string = [string fastStringByCollapsingWhitespaceAndRemovingSurroundingWhitespace];
    }
    
    NSMutableString *mutableString = [string mutableCopy];
    
    // Parse the TeX commands and remove them from the string, manipulating the NSMutableString as much as possible, since -[NSMutableAttributedString mutableString] returns a proxy object that's more expensive.
    NSMutableArray *attributeDictionaries = [[NSMutableArray alloc] init];
    NSRange range = NSMakeRange(0, [mutableString length]);
    BDSKGetAttributeDictionariesAndFixString(attributeDictionaries, mutableString, attributes, &range);
    
    unsigned numberOfDictionaries = [attributeDictionaries count];
    if (numberOfDictionaries > 0) {

        // discard the result of +alloc, since we're going to create a new object
        [[self init] release];

        // set the attributed string up with default attributes, after parsing and fixing the mutable string
        mas = [[NSMutableAttributedString alloc] initWithString:mutableString attributes:attributes]; 

        // now apply the previously determined attributes and ranges to the attributed string
        CFArrayApplyFunction((CFArrayRef)attributeDictionaries, CFRangeMake(0, numberOfDictionaries), BDSKApplyAttributesToString, mas);
        
        // not all of the braces were deleted when parsing the commands
        [[mas mutableString] deleteCharactersInCharacterSet:[NSCharacterSet curlyBraceCharacterSet]];
        
        self = [mas copy];
        [mas release];
        
    } else {
        
        // no font commands, so operate directly on the NSMutableString and then use the result of +alloc
        [mutableString deleteCharactersInCharacterSet:[NSCharacterSet curlyBraceCharacterSet]];
        self = [self initWithString:mutableString attributes:attributes];
    }
    
    [mutableString release];
    [attributeDictionaries release];
    
    return self;
}

- (id)initWithAttributedString:(NSAttributedString *)attributedString attributes:(NSDictionary *)attributes {
    [[self init] release];
    NSMutableAttributedString *tmpStr = [attributedString mutableCopy];
    unsigned index = 0, length = [attributedString length];
    NSRange range = NSMakeRange(0, length);
    NSDictionary *attrs;
    [tmpStr addAttributes:attributes range:range];
    while (index < length) {
        attrs = [attributedString attributesAtIndex:index effectiveRange:&range];
        if (range.length > 0) {
            [tmpStr addAttributes:attrs range:range];
            index = NSMaxRange(range);
        } else index++;
    }
    [tmpStr fixAttributesInRange:NSMakeRange(0, length)];
    self = [tmpStr copy];
    [tmpStr release];
    return self;
}

- (NSRect)boundingRectForDrawingInViewWithSize:(NSSize)size{
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:size];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [textContainer release];
    [layoutManager release];
    
    // drawing in views uses a different typesetting behavior from the current one which leads to a mismatch in line height
    // see http://www.cocoabuilder.com/archive/message/cocoa/2006/1/3/153669
    [layoutManager setTypesetterBehavior:NSTypesetterBehavior_10_2_WithCompatibility];
    [layoutManager glyphRangeForTextContainer:textContainer];
    
    NSRect rect = [layoutManager usedRectForTextContainer:textContainer];
    [textStorage release];
    
    return rect;
}

@end

@implementation NSAttributedString (TeXComparison)
- (NSComparisonResult)localizedCaseInsensitiveNonTeXNonArticleCompare:(NSAttributedString *)other;
{
    return [[self string] localizedCaseInsensitiveNonTeXNonArticleCompare:[other string]];
}

@end

