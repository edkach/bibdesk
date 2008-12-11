//
//  BDSKTemplateParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/17/06.
/*
 This software is Copyright (c) 2006-2008
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
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION)HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE)ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKTemplateParser.h"
#import "BDSKTemplateTag.h"
#import "NSString_BDSKExtensions.h"
#import "BibAuthor.h"

#define START_TAG_OPEN_DELIM            @"<$"
#define END_TAG_OPEN_DELIM              @"</$"
#define ALT_TAG_OPEN_DELIM              @"<?$"
#define VALUE_TAG_CLOSE_DELIM           @"/>"
#define COLLECTION_TAG_CLOSE_DELIM      @">"
#define CONDITION_TAG_CLOSE_DELIM       @"?>"
#define CONDITION_TAG_EQUAL             @"="
#define CONDITION_TAG_CONTAIN           @"~"
#define CONDITION_TAG_SMALLER           @"<"
#define CONDITION_TAG_SMALLER_OR_EQUAL  @"<="

/*
        value tag: <$key/>
   collection tag: <$key> </$key> 
               or: <$key> <?$key> </$key>
    condition tag: <$key?> </$key?> 
               or: <$key?> <?$key?> </$key?>
               or: <$key=value?> </$key?>
               or: <$key=value?> <?$key?> </$key?>
               or: <$key~value?> </$key?>
               or: <$key~value?> <?$key?> </$key?>
               or: <$key<value?> </$key?>
               or: <$key<value?> <?$key?> </$key?>
               or: <$key<=value?> </$key?>
               or: <$key<=value?> <?$key?> </$key?>
*/

@implementation BDSKTemplateParser


static NSCharacterSet *keyCharacterSet = nil;
static NSCharacterSet *invertedKeyCharacterSet = nil;

+ (void)initialize {
    
    OBINITIALIZE;
    
    NSMutableCharacterSet *tmpSet = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [tmpSet addCharactersInString:@".-_:;@#"];
    keyCharacterSet = [tmpSet copy];
    [tmpSet release];
    
    invertedKeyCharacterSet = [[keyCharacterSet invertedSet] copy];
}

static inline NSString *endCollectionTagWithTag(NSString *tag){
    static NSMutableDictionary *endCollectionDict = nil;
    if(nil == endCollectionDict)
        endCollectionDict = [[NSMutableDictionary alloc] init];
    
    NSString *endTag = [endCollectionDict objectForKey:tag];
    if(nil == endTag){
        endTag = [NSString stringWithFormat:@"%@%@%@", END_TAG_OPEN_DELIM, tag, COLLECTION_TAG_CLOSE_DELIM];
        [endCollectionDict setObject:endTag forKey:tag];
    }
    return endTag;
}

static inline NSString *sepCollectionTagWithTag(NSString *tag){
    static NSMutableDictionary *sepCollectionDict = nil;
    if(nil == sepCollectionDict)
        sepCollectionDict = [[NSMutableDictionary alloc] init];
    
    NSString *altTag = [sepCollectionDict objectForKey:tag];
    if(nil == altTag){
        altTag = [NSString stringWithFormat:@"%@%@%@", ALT_TAG_OPEN_DELIM, tag, COLLECTION_TAG_CLOSE_DELIM];
        [sepCollectionDict setObject:altTag forKey:tag];
    }
    return altTag;
}

static inline NSString *endConditionTagWithTag(NSString *tag){
    static NSMutableDictionary *endConditionDict = nil;
    if(nil == endConditionDict)
        endConditionDict = [[NSMutableDictionary alloc] init];
    
    NSString *endTag = [endConditionDict objectForKey:tag];
    if(nil == endTag){
        endTag = [NSString stringWithFormat:@"%@%@%@", END_TAG_OPEN_DELIM, tag, CONDITION_TAG_CLOSE_DELIM];
        [endConditionDict setObject:endTag forKey:tag];
    }
    return endTag;
}

static inline NSString *altConditionTagWithTag(NSString *tag){
    static NSMutableDictionary *altConditionDict = nil;
    if(nil == altConditionDict)
        altConditionDict = [[NSMutableDictionary alloc] init];
    
    NSString *altTag = [altConditionDict objectForKey:tag];
    if(nil == altTag){
        altTag = [NSString stringWithFormat:@"%@%@%@", ALT_TAG_OPEN_DELIM, tag, CONDITION_TAG_CLOSE_DELIM];
        [altConditionDict setObject:altTag forKey:tag];
    }
    return altTag;
}

static inline NSString *compareConditionTagWithTag(NSString *tag, BDSKTemplateTagMatchType matchType){
    static NSMutableDictionary *equalConditionDict = nil;
    static NSMutableDictionary *containConditionDict = nil;
    static NSMutableDictionary *smallerConditionDict = nil;
    static NSMutableDictionary *smallerOrEqualConditionDict = nil;
    NSString *altTag = nil;
    switch (matchType) {
        case BDSKTemplateTagMatchEqual:
            if(nil == equalConditionDict)
                equalConditionDict = [[NSMutableDictionary alloc] init];
            altTag = [equalConditionDict objectForKey:tag];
            if(nil == altTag){
                altTag = [NSString stringWithFormat:@"%@%@%@", ALT_TAG_OPEN_DELIM, tag, CONDITION_TAG_EQUAL];
                [equalConditionDict setObject:altTag forKey:tag];
            }
            break;
        case BDSKTemplateTagMatchContain:
            if(nil == containConditionDict)
                containConditionDict = [[NSMutableDictionary alloc] init];
            altTag = [containConditionDict objectForKey:tag];
            if(nil == altTag){
                altTag = [NSString stringWithFormat:@"%@%@%@", ALT_TAG_OPEN_DELIM, tag, CONDITION_TAG_CONTAIN];
                [containConditionDict setObject:altTag forKey:tag];
            }
            break;
        case BDSKTemplateTagMatchSmaller:
            if(nil == smallerConditionDict)
                smallerConditionDict = [[NSMutableDictionary alloc] init];
            altTag = [smallerConditionDict objectForKey:tag];
            if(nil == altTag){
                altTag = [NSString stringWithFormat:@"%@%@%@", ALT_TAG_OPEN_DELIM, tag, CONDITION_TAG_SMALLER];
                [smallerConditionDict setObject:altTag forKey:tag];
            }
            break;
        case BDSKTemplateTagMatchSmallerOrEqual:
            if(nil == smallerOrEqualConditionDict)
                smallerOrEqualConditionDict = [[NSMutableDictionary alloc] init];
            altTag = [smallerOrEqualConditionDict objectForKey:tag];
            if(nil == altTag){
                altTag = [NSString stringWithFormat:@"%@%@%@", ALT_TAG_OPEN_DELIM, tag, CONDITION_TAG_SMALLER_OR_EQUAL];
                [smallerOrEqualConditionDict setObject:altTag forKey:tag];
            }
            break;
    }
    return altTag;
}

static inline NSRange altConditionTagRange(NSString *template, NSString *altTag, NSString **argString) {
    NSRange altTagRange = [template rangeOfString:altTag];
    if (altTagRange.location != NSNotFound) {
        // find the end tag and the argument (match string)
        NSRange endRange = [template rangeOfString:CONDITION_TAG_CLOSE_DELIM options:0 range:NSMakeRange(NSMaxRange(altTagRange), [template length] - NSMaxRange(altTagRange))];
        if (endRange.location != NSNotFound) {
            *argString = [template substringWithRange:NSMakeRange(NSMaxRange(altTagRange), endRange.location - NSMaxRange(altTagRange))];
            altTagRange.length = NSMaxRange(endRange) - altTagRange.location;
        } else {
            altTagRange = NSMakeRange(NSNotFound, 0);
        }
    }
    return altTagRange;
}

static inline BOOL matchesCondition(NSString *keyValue, NSString *matchString, BDSKTemplateTagMatchType matchType) {
    switch (matchType) {
        case BDSKTemplateTagMatchEqual:
            return [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue templateStringValue] ?: @"" caseInsensitiveCompare:matchString] == NSOrderedSame;
        case BDSKTemplateTagMatchContain:
            return [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue templateStringValue] ?: @"" rangeOfString:matchString options:NSCaseInsensitiveSearch].location != NSNotFound;
        case BDSKTemplateTagMatchSmaller:
            return [matchString isEqualToString:@""] ? NO : [[keyValue templateStringValue] ?: @"" localizedCaseInsensitiveNumericCompare:matchString] == NSOrderedAscending;
        case BDSKTemplateTagMatchSmallerOrEqual:
            return [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue templateStringValue] ?: @"" localizedCaseInsensitiveNumericCompare:matchString] != NSOrderedDescending;
        default:
            return [keyValue isNotEmpty];
    }
}

static inline NSRange rangeAfterRemovingEmptyLines(NSString *string, BDSKTemplateTagType typeBefore, BDSKTemplateTagType typeAfter, BOOL isSubtemplate) {
    NSRange range = NSMakeRange(0, [string length]);
    
    if (typeAfter == BDSKCollectionTemplateTagType || typeAfter == BDSKConditionTemplateTagType || (isSubtemplate == -1 && typeAfter == -1)) {
        // remove whitespace at the end, just before the collection or condition tag
        NSRange lastCharRange = [string rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:NSBackwardsSearch range:range];
        if (lastCharRange.location != NSNotFound) {
            unichar lastChar = [string characterAtIndex:lastCharRange.location];
            unsigned int rangeEnd = NSMaxRange(lastCharRange);
            if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar])
                range.length = rangeEnd;
        } else if (typeBefore == -1) {
            range.length = 0;
        }
    }
    if (typeBefore == BDSKCollectionTemplateTagType || typeBefore == BDSKConditionTemplateTagType || (isSubtemplate == -1 && typeBefore == -1)) {
        // remove whitespace and a newline at the start, just after the collection or condition tag
        NSRange firstCharRange = [string rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:0 range:range];
        if (firstCharRange.location != NSNotFound) {
            unichar firstChar = [string characterAtIndex:firstCharRange.location];
            unsigned int rangeEnd = NSMaxRange(firstCharRange);
            if([[NSCharacterSet newlineCharacterSet] characterIsMember:firstChar]) {
                if (firstChar == NSCarriageReturnCharacter && rangeEnd < NSMaxRange(range) && [string characterAtIndex:rangeEnd] == NSNewlineCharacter)
                    range = NSMakeRange(rangeEnd + 1, NSMaxRange(range) - rangeEnd - 1);
                else 
                    range = NSMakeRange(rangeEnd, NSMaxRange(range) - rangeEnd);
            }
        } else if (typeAfter == -1) {
            range.length = 0;
        }
    }
    
    return range;
}

#pragma mark Parsing string templates

+ (NSString *)stringByParsingTemplateString:(NSString *)template usingObject:(id)object {
    return [self stringByParsingTemplateString:template usingObject:object delegate:nil];
}

+ (NSString *)stringByParsingTemplateString:(NSString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    return [self stringFromTemplateArray:[self arrayByParsingTemplateString:template] usingObject:object atIndex:1 delegate:delegate];
}

+ (NSArray *)arrayByParsingTemplateString:(NSString *)template {
    return [self arrayByParsingTemplateString:template isSubtemplate:NO];
}

+ (NSArray *)arrayByParsingTemplateString:(NSString *)template isSubtemplate:(BOOL)isSubtemplate {
    NSScanner *scanner = [[NSScanner alloc] initWithString:template];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    id currentTag = nil;

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText = nil;
        NSString *tag = @"";
        int start;
                
        if ([scanner scanUpToString:START_TAG_OPEN_DELIM intoString:&beforeText]) {
            if (currentTag && [(BDSKTemplateTag *)currentTag type] == BDSKTextTemplateTagType) {
                [(BDSKTextTemplateTag *)currentTag appendText:beforeText];
            } else {
                currentTag = [[BDSKTextTemplateTag alloc] initWithText:beforeText];
                [result addObject:currentTag];
                [currentTag release];
            }
        }
        
        if ([scanner scanString:START_TAG_OPEN_DELIM intoString:nil]) {
            
            start = [scanner scanLocation];
            
            // scan the key, must be letters and dots. We don't allow extra spaces
            // scanUpToCharactersFromSet is used for efficiency instead of scanCharactersFromSet
            [scanner scanUpToCharactersFromSet:invertedKeyCharacterSet intoString:&tag];
            
            if ([scanner scanString:VALUE_TAG_CLOSE_DELIM intoString:nil]) {
                
                // simple template currentTag
                currentTag = [[BDSKValueTemplateTag alloc] initWithKeyPath:tag];
                [result addObject:currentTag];
                [currentTag release];
                
            } else if ([scanner scanString:COLLECTION_TAG_CLOSE_DELIM intoString:nil]) {
                
                NSString *itemTemplate = @"", *separatorTemplate = nil;
                NSString *endTag;
                NSRange sepTagRange;
                
                // collection template tag
                endTag = endCollectionTagWithTag(tag);
                [scanner scanUpToString:endTag intoString:&itemTemplate];
                if ([scanner scanString:endTag intoString:nil]) {
                    sepTagRange = [itemTemplate rangeOfString:sepCollectionTagWithTag(tag)];
                    if (sepTagRange.location != NSNotFound) {
                        separatorTemplate = [itemTemplate substringFromIndex:NSMaxRange(sepTagRange)];
                        itemTemplate = [itemTemplate substringToIndex:sepTagRange.location];
                    }
                    
                    currentTag = [[BDSKCollectionTemplateTag alloc] initWithKeyPath:tag itemTemplateString:itemTemplate separatorTemplateString:separatorTemplate];
                    [result addObject:currentTag];
                    [currentTag release];
                }
                
            } else {
                
                NSString *matchString = @"";
                BDSKTemplateTagMatchType matchType = BDSKTemplateTagMatchOther;
                
                if ([scanner scanString:CONDITION_TAG_EQUAL intoString:nil]) {
                    [scanner scanUpToString:CONDITION_TAG_CLOSE_DELIM intoString:&matchString];
                    matchType = BDSKTemplateTagMatchEqual;
                } else if ([scanner scanString:CONDITION_TAG_CONTAIN intoString:nil]) {
                    [scanner scanUpToString:CONDITION_TAG_CLOSE_DELIM intoString:&matchString];
                    matchType = BDSKTemplateTagMatchContain;
                } else if ([scanner scanString:CONDITION_TAG_SMALLER_OR_EQUAL intoString:nil]) {
                    [scanner scanUpToString:CONDITION_TAG_CLOSE_DELIM intoString:&matchString];
                    matchType = BDSKTemplateTagMatchSmallerOrEqual;
                } else if ([scanner scanString:CONDITION_TAG_SMALLER intoString:nil]) {
                    [scanner scanUpToString:CONDITION_TAG_CLOSE_DELIM intoString:&matchString];
                    matchType = BDSKTemplateTagMatchSmaller;
                }
                
                if ([scanner scanString:CONDITION_TAG_CLOSE_DELIM intoString:nil]) {
                    
                    NSMutableArray *subTemplates, *matchStrings;
                    NSString *subTemplate = @"";
                    NSString *endTag, *altTag;
                    NSRange altTagRange;
                    
                    // condition template tag
                    endTag = endConditionTagWithTag(tag);
                    [scanner scanUpToString:endTag intoString:&subTemplate];
                    if ([scanner scanString:endTag intoString:nil]) {
                        
                        subTemplates = [[NSMutableArray alloc] init];
                        matchStrings = [[NSMutableArray alloc] initWithObjects:matchString, nil];
                        
                        if (matchType != BDSKTemplateTagMatchOther) {
                            altTag = compareConditionTagWithTag(tag, matchType);
                            altTagRange = altConditionTagRange(subTemplate, altTag, &matchString);
                            while (altTagRange.location != NSNotFound) {
                                [subTemplates addObject:[subTemplate substringToIndex:altTagRange.location]];
                                [matchStrings addObject:matchString];
                                subTemplate = [subTemplate substringFromIndex:NSMaxRange(altTagRange)];
                                altTagRange = altConditionTagRange(subTemplate, altTag, &matchString);
                            }
                        }
                        
                        
                        altTagRange = [subTemplate rangeOfString:altConditionTagWithTag(tag)];
                        if (altTagRange.location != NSNotFound) {
                            [subTemplates addObject:[subTemplate substringToIndex:altTagRange.location]];
                            subTemplate = [subTemplate substringFromIndex:NSMaxRange(altTagRange)];
                        }
                        [subTemplates addObject:subTemplate];
                        
                        currentTag = [[BDSKConditionTemplateTag alloc] initWithKeyPath:tag matchType:matchType matchStrings:matchStrings subtemplates:subTemplates];
                        [result addObject:currentTag];
                        [currentTag release];
                        
                        [subTemplates release];
                        [matchStrings release];
                        
                    }
                    
                } else {
                    
                    // an open delimiter without a close delimiter, so no template tag. Rewind
                    if (currentTag && [(BDSKTemplateTag *)currentTag type] == BDSKTextTemplateTagType) {
                        [(BDSKTextTemplateTag *)currentTag appendText:START_TAG_OPEN_DELIM];
                    } else {
                        currentTag = [[BDSKTextTemplateTag alloc] initWithText:START_TAG_OPEN_DELIM];
                        [result addObject:currentTag];
                        [currentTag release];
                    }
                    [scanner setScanLocation:start];
                    
                }
            }
        } // scan START_TAG_OPEN_DELIM
    } // while
    [scanner release];
    
    // remove whitespace before and after collection and condition tags up till newlines
    int i, count = [result count];
    
    for (i = count - 1; i >= 0; i--) {
        BDSKTemplateTag *tag = [result objectAtIndex:i];
        
        if ([tag type] != BDSKTextTemplateTagType) continue;
        
        NSString *string = [(BDSKTextTemplateTag *)tag text];
        NSRange range = range = rangeAfterRemovingEmptyLines(string, i > 0 ? [(BDSKTemplateTag *)[result objectAtIndex:i - 1] type] : -1, i < count - 1 ? [(BDSKTemplateTag *)[result objectAtIndex:i + 1] type] : -1, isSubtemplate);
        
        if (range.length == 0)
            [result removeObjectAtIndex:i];
        else if (range.length != [string length])
            [(BDSKTextTemplateTag *)tag setText:[string substringWithRange:range]];
    }
    
    return [result autorelease];    
}

+ (NSString *)stringFromTemplateArray:(NSArray *)template usingObject:(id)object atIndex:(int)anIndex {
    return [self stringFromTemplateArray:template usingObject:object atIndex:anIndex delegate:nil];
}

+ (NSString *)stringFromTemplateArray:(NSArray *)template usingObject:(id)object atIndex:(int)anIndex delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSEnumerator *tagEnum = [template objectEnumerator];
    id tag;
    NSMutableString *result = [[NSMutableString alloc] init];
    
    while (tag = [tagEnum nextObject]) {
        BDSKTemplateTagType type = [(BDSKTemplateTag *)tag type];
        
        if (type == BDSKTextTemplateTagType) {
            
            [result appendString:[(BDSKTextTemplateTag *)tag text]];
            
        } else {
            
            NSString *keyPath = [tag keyPath];
            id keyValue = nil;
            
            if ([keyPath hasPrefix:@"#"]) {
                keyValue = [NSNumber numberWithInt:anIndex];
                if ([keyPath hasPrefix:@"#."] && [keyPath length] > 2)
                    keyValue = [keyValue templateValueForKeyPath:[keyPath substringFromIndex:2]];
            } else {
                keyValue = [object templateValueForKeyPath:keyPath];
            }
            
            if (type == BDSKValueTemplateTagType) {
                
                if (keyValue)
                    [result appendString:[keyValue templateStringValue]];
                
            } else if (type == BDSKCollectionTemplateTagType) {
                
                if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                    NSEnumerator *itemE = [keyValue objectEnumerator];
                    id nextItem, item = [itemE nextObject];
                    NSArray *itemTemplate = [[tag itemTemplate] arrayByAddingObjectsFromArray:[tag separatorTemplate]];
                    int idx = 0;
                    while (item) {
                        nextItem = [itemE nextObject];
                        if (nextItem == nil)
                            itemTemplate = [tag itemTemplate];
                        [delegate templateParserWillParseTemplate:itemTemplate usingObject:item isAttributed:NO];
                        keyValue = [self stringFromTemplateArray:itemTemplate usingObject:item atIndex:++idx delegate:delegate];
                        [delegate templateParserDidParseTemplate:itemTemplate usingObject:item isAttributed:NO];
                        if (keyValue != nil)
                            [result appendString:keyValue];
                        item = nextItem;
                    }
                }
                
            } else {
                
                NSString *matchString = nil;
                NSArray *matchStrings = [tag matchStrings];
                unsigned int i, count = [matchStrings count];
                NSArray *subtemplate = nil;
                
                for (i = 0; i < count; i++) {
                    matchString = [matchStrings objectAtIndex:i];
                    if ([matchString hasPrefix:@"$"])
                        matchString = [[object templateValueForKeyPath:[matchString substringFromIndex:1]] templateStringValue] ?: @"";
                    if (matchesCondition(keyValue, matchString, [tag matchType])) {
                        subtemplate = [tag subtemplateAtIndex:i];
                        break;
                    }
                }
                if (subtemplate == nil && [[tag subtemplates] count] > count)
                    subtemplate = [tag subtemplateAtIndex:count];
                if (subtemplate != nil) {
                    if (keyValue = [self stringFromTemplateArray:subtemplate usingObject:object atIndex:anIndex delegate:delegate])
                        [result appendString:keyValue];
                }
                
            }
                    
        }
    } // while
    
    return [result autorelease];    
}

#pragma mark Parsing attributed string templates

+ (NSAttributedString *)attributedStringByParsingTemplateAttributedString:(NSAttributedString *)template usingObject:(id)object {
    return [self attributedStringByParsingTemplateAttributedString:template usingObject:object delegate:nil];
}

+ (NSAttributedString *)attributedStringByParsingTemplateAttributedString:(NSAttributedString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    return [self attributedStringFromTemplateArray:[self arrayByParsingTemplateAttributedString:template] usingObject:object atIndex:1 delegate:delegate];
}

+ (NSArray *)arrayByParsingTemplateAttributedString:(NSAttributedString *)template {
    return [self arrayByParsingTemplateAttributedString:template isSubtemplate:NO];
}

+ (NSArray *)arrayByParsingTemplateAttributedString:(NSAttributedString *)template isSubtemplate:(BOOL)isSubtemplate {
    NSString *templateString = [template string];
    NSScanner *scanner = [[NSScanner alloc] initWithString:templateString];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    id currentTag = nil;

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText = nil;
        NSString *tag = @"";
        int start;
        NSDictionary *attr = nil;
        
        start = [scanner scanLocation];
                
        if ([scanner scanUpToString:START_TAG_OPEN_DELIM intoString:&beforeText]) {
            if (currentTag && [(BDSKTemplateTag *)currentTag type] == BDSKTextTemplateTagType) {
                [(BDSKRichTextTemplateTag *)currentTag appendAttributedText:[template attributedSubstringFromRange:NSMakeRange(start, [beforeText length])]];
            } else {
                currentTag = [[BDSKRichTextTemplateTag alloc] initWithAttributedText:[template attributedSubstringFromRange:NSMakeRange(start, [beforeText length])]];
                [result addObject:currentTag];
                [currentTag release];
            }
        }
        
        if ([scanner scanString:START_TAG_OPEN_DELIM intoString:nil]) {
            
            attr = [template attributesAtIndex:[scanner scanLocation] - [START_TAG_OPEN_DELIM length] effectiveRange:NULL];
            start = [scanner scanLocation];
            
            // scan the key, must be letters and dots. We don't allow extra spaces
            // scanUpToCharactersFromSet is used for efficiency instead of scanCharactersFromSet
            [scanner scanUpToCharactersFromSet:invertedKeyCharacterSet intoString:&tag];

            if ([scanner scanString:VALUE_TAG_CLOSE_DELIM intoString:nil]) {
                
                // simple template tag
                currentTag = [[BDSKRichValueTemplateTag alloc] initWithKeyPath:tag attributes:attr];
                [result addObject:currentTag];
                [currentTag release];
                
            } else if ([scanner scanString:COLLECTION_TAG_CLOSE_DELIM intoString:nil]) {
                
                NSString *itemTemplateString = @"";
                NSAttributedString *itemTemplate = nil, *separatorTemplate = nil;
                NSString *endTag;
                NSRange sepTagRange;
                
                // collection template tag
                endTag = endCollectionTagWithTag(tag);
                if ([scanner scanString:endTag intoString:nil])
                    continue;
                start = [scanner scanLocation];
                [scanner scanUpToString:endTag intoString:&itemTemplateString];
                if ([scanner scanString:endTag intoString:nil]) {
                    itemTemplate = [template attributedSubstringFromRange:NSMakeRange(start, [itemTemplateString length])];
                    
                    sepTagRange = [[itemTemplate string] rangeOfString:sepCollectionTagWithTag(tag)];
                    if (sepTagRange.location != NSNotFound) {
                        separatorTemplate = [itemTemplate attributedSubstringFromRange:NSMakeRange(NSMaxRange(sepTagRange), [itemTemplate length] - NSMaxRange(sepTagRange))];
                        itemTemplate = [itemTemplate attributedSubstringFromRange:NSMakeRange(0, sepTagRange.location)];
                    }
                    
                    currentTag = [[BDSKRichCollectionTemplateTag alloc] initWithKeyPath:tag itemTemplateAttributedString:itemTemplate separatorTemplateAttributedString:separatorTemplate];
                    [result addObject:currentTag];
                    [currentTag release];
                    
                }
                
            } else {
                
                NSString *matchString = @"";
                BDSKTemplateTagMatchType matchType = BDSKTemplateTagMatchOther;
                
                if ([scanner scanString:CONDITION_TAG_EQUAL intoString:nil]) {
                    if([scanner scanUpToString:CONDITION_TAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKTemplateTagMatchEqual;
                } else if ([scanner scanString:CONDITION_TAG_CONTAIN intoString:nil]) {
                    if([scanner scanUpToString:CONDITION_TAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKTemplateTagMatchContain;
                } else if ([scanner scanString:CONDITION_TAG_SMALLER_OR_EQUAL intoString:nil]) {
                    if([scanner scanUpToString:CONDITION_TAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKTemplateTagMatchSmallerOrEqual;
                } else if ([scanner scanString:CONDITION_TAG_SMALLER intoString:nil]) {
                    if([scanner scanUpToString:CONDITION_TAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKTemplateTagMatchSmaller;
                }
                
                if ([scanner scanString:CONDITION_TAG_CLOSE_DELIM intoString:nil]) {
                    
                    NSMutableArray *subTemplates, *matchStrings;
                    NSAttributedString *subTemplate = @"";
                    NSString *subTemplateString, *endTag, *altTag;
                    NSRange altTagRange;
                    
                    // condition template tag
                    endTag = endConditionTagWithTag(tag);
                    altTag = altConditionTagWithTag(tag);
                    start = [scanner scanLocation];
                    [scanner scanUpToString:endTag intoString:&subTemplateString];
                    if ([scanner scanString:endTag intoString:nil]) {
                        subTemplate = [template attributedSubstringFromRange:NSMakeRange(start, [subTemplateString length])];
                        
                        subTemplates = [[NSMutableArray alloc] init];
                        matchStrings = [[NSMutableArray alloc] initWithObjects:matchString, nil];
                        
                        if (matchType != BDSKTemplateTagMatchOther) {
                            altTag = compareConditionTagWithTag(tag, matchType);
                            altTagRange = altConditionTagRange([subTemplate string], altTag, &matchString);
                            while (altTagRange.location != NSNotFound) {
                                [subTemplates addObject:[subTemplate attributedSubstringFromRange:NSMakeRange(0, altTagRange.location)]];
                                [matchStrings addObject:matchString];
                                subTemplate = [subTemplate attributedSubstringFromRange:NSMakeRange(NSMaxRange(altTagRange), [subTemplate length] - NSMaxRange(altTagRange))];
                                altTagRange = altConditionTagRange([subTemplate string], altTag, &matchString);
                            }
                        }
                        
                        altTagRange = [[subTemplate string] rangeOfString:altConditionTagWithTag(tag)];
                        if (altTagRange.location != NSNotFound) {
                            [subTemplates addObject:[subTemplate attributedSubstringFromRange:NSMakeRange(0, altTagRange.location)]];
                            subTemplate = [subTemplate attributedSubstringFromRange:NSMakeRange(NSMaxRange(altTagRange), [subTemplate length] - NSMaxRange(altTagRange))];
                        }
                        [subTemplates addObject:subTemplate];
                        
                        currentTag = [[BDSKRichConditionTemplateTag alloc] initWithKeyPath:tag matchType:matchType matchStrings:matchStrings subtemplates:subTemplates];
                        [result addObject:currentTag];
                        [currentTag release];
                        
                        [subTemplates release];
                        [matchStrings release];
                        
                    }
                    
                } else {
                    
                    // a START_TAG_OPEN_DELIM without COLLECTION_TAG_CLOSE_DELIM, so no template tag. Rewind
                    if (currentTag && [(BDSKTemplateTag *)currentTag type] == BDSKTextTemplateTagType) {
                        [(BDSKRichTextTemplateTag *)currentTag appendAttributedText:[template attributedSubstringFromRange:NSMakeRange(start - [START_TAG_OPEN_DELIM length], [START_TAG_OPEN_DELIM length])]];
                    } else {
                        currentTag = [[BDSKRichTextTemplateTag alloc] initWithAttributedText:[template attributedSubstringFromRange:NSMakeRange(start - [START_TAG_OPEN_DELIM length], [START_TAG_OPEN_DELIM length])]];
                        [result addObject:currentTag];
                        [currentTag release];
                    }
                    [scanner setScanLocation:start];
                    
                }
            }
        } // scan START_TAG_OPEN_DELIM
    } // while
    
    [scanner release];
    
    // remove whitespace before and after collection and condition tags up till newlines
    int i, count = [result count];
    
    for (i = count - 1; i >= 0; i--) {
        BDSKTemplateTag *tag = [result objectAtIndex:i];
        
        if ([tag type] != BDSKTextTemplateTagType) continue;
        
        NSAttributedString *attrString = [(BDSKRichTextTemplateTag *)tag attributedText];
        NSString *string = [attrString string];
        NSRange range = range = rangeAfterRemovingEmptyLines(string, i > 0 ? [(BDSKTemplateTag *)[result objectAtIndex:i - 1] type] : -1, i < count - 1 ? [(BDSKTemplateTag *)[result objectAtIndex:i + 1] type] : -1, isSubtemplate);
        
        if (range.length == 0)
            [result removeObjectAtIndex:i];
        else if (range.length != [string length])
            [(BDSKRichTextTemplateTag *)tag setAttributedText:[attrString attributedSubstringFromRange:range]];
    }
    
    return [result autorelease];    
}

+ (NSAttributedString *)attributedStringFromTemplateArray:(NSArray *)template usingObject:(id)object atIndex:(int)anIndex {
    return [self attributedStringFromTemplateArray:template usingObject:object atIndex:anIndex delegate:nil];
}

+ (NSAttributedString *)attributedStringFromTemplateArray:(NSArray *)template usingObject:(id)object atIndex:(int)anIndex delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSEnumerator *tagEnum = [template objectEnumerator];
    id tag;
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    
    while (tag = [tagEnum nextObject]) {
        BDSKTemplateTagType type = [(BDSKTemplateTag *)tag type];
        NSAttributedString *tmpAttrStr = nil;
        
        if (type == BDSKTextTemplateTagType) {
            
            [result appendAttributedString:[(BDSKRichTextTemplateTag *)tag attributedText]];
            
        } else {
            
            NSString *keyPath = [tag keyPath];
            id keyValue = nil;
            
            if ([keyPath hasPrefix:@"#"]) {
                keyValue = [NSNumber numberWithInt:anIndex];
                if ([keyPath hasPrefix:@"#."] && [keyPath length] > 2)
                    keyValue = [keyValue templateValueForKeyPath:[keyPath substringFromIndex:2]];
            } else {
                keyValue = [object templateValueForKeyPath:keyPath];
            }
            
            if (type == BDSKValueTemplateTagType) {
                
                if (keyValue)
                    [result appendAttributedString:[keyValue templateAttributedStringValueWithAttributes:[(BDSKRichValueTemplateTag *)tag attributes]]];
                
            } else if (type == BDSKCollectionTemplateTagType) {
                
                if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                    NSEnumerator *itemE = [keyValue objectEnumerator];
                    id nextItem, item = [itemE nextObject];
                    NSArray *itemTemplate = [[tag itemTemplate] arrayByAddingObjectsFromArray:[tag separatorTemplate]];
                    int idx = 0;
                    while (item) {
                        nextItem = [itemE nextObject];
                        if (nextItem == nil)
                            itemTemplate = [tag itemTemplate];
                        [delegate templateParserWillParseTemplate:itemTemplate usingObject:item isAttributed:YES];
                        tmpAttrStr = [self attributedStringFromTemplateArray:itemTemplate usingObject:item atIndex:++idx delegate:delegate];
                        [delegate templateParserDidParseTemplate:itemTemplate usingObject:item isAttributed:YES];
                        if (tmpAttrStr != nil)
                            [result appendAttributedString:tmpAttrStr];
                        item = nextItem;
                    }
                }
                
            } else {
                
                NSString *matchString = nil;
                NSArray *matchStrings = [tag matchStrings];
                unsigned int i, count = [matchStrings count];
                NSArray *subtemplate = nil;
                            
                count = [matchStrings count];
                subtemplate = nil;
                for (i = 0; i < count; i++) {
                    matchString = [matchStrings objectAtIndex:i];
                    if ([matchString hasPrefix:@"$"])
                        matchString = [[object templateValueForKeyPath:[matchString substringFromIndex:1]] templateStringValue] ?: @"";
                    if (matchesCondition(keyValue, matchString, [tag matchType])) {
                        subtemplate = [tag subtemplateAtIndex:i];
                        break;
                    }
                }
                if (subtemplate == nil && [[tag subtemplates] count] > count) {
                    subtemplate = [tag subtemplateAtIndex:count];
                }
                if (subtemplate != nil) {
                    if (tmpAttrStr = [self attributedStringFromTemplateArray:subtemplate usingObject:object atIndex:anIndex delegate:delegate])
                        [result appendAttributedString:tmpAttrStr];
                }
                
            }
            
        }
    } // while
    
    [result fixAttributesInRange:NSMakeRange(0, [result length])];
    
    return [result autorelease];    
}

@end

#pragma mark -

@implementation NSObject (BDSKTemplateParser)

- (BOOL)isNotEmpty {
    if ([self respondsToSelector:@selector(count)])
        return [(id)self count] > 0;
    if ([self respondsToSelector:@selector(length)])
        return [(id)self length] > 0;
    return YES;
}

- (id)templateValueForKeyPath:(NSString *)keyPath {
    id value = nil;
    NSString *trailingKeyPath = nil;
    unsigned int atIndex = [keyPath rangeOfString:@"@"].location;
    if (atIndex != NSNotFound) {
        unsigned int dotIndex = [keyPath rangeOfString:@"." options:0 range:NSMakeRange(atIndex + 1, [keyPath length] - atIndex - 1)].location;
        if (dotIndex != NSNotFound) {
            static NSSet *arrayOperators = nil;
            if (arrayOperators == nil)
                arrayOperators = [[NSSet alloc] initWithObjects:@"@avg", @"@max", @"@min", @"@sum", @"@distinctUnionOfArrays", @"@distinctUnionOfObjects", @"@distinctUnionOfSets", @"@unionOfArrays", @"@unionOfObjects", @"@unionOfSets", nil];
            if ([arrayOperators containsObject:[keyPath substringWithRange:NSMakeRange(atIndex, dotIndex - atIndex)]] == NO) {
                trailingKeyPath = [keyPath substringFromIndex:dotIndex + 1];
                keyPath = [keyPath substringToIndex:dotIndex];
            }
        }
    }
    @try{ value = [self valueForKeyPath:keyPath]; }
    @catch(id exception) { value = nil; }
    return trailingKeyPath ? [value templateValueForKeyPath:trailingKeyPath] : value;
}

- (NSString *)templateStringValue {
    if ([self respondsToSelector:@selector(stringValue)])
        return [(id)self stringValue] ?: @"";
    if ([self respondsToSelector:@selector(string)])
        return [(id)self string] ?: @"";
    return [self description];
}

- (NSAttributedString *)templateAttributedStringValueWithAttributes:(NSDictionary *)attributes {
    return [[[NSAttributedString alloc] initWithString:[self templateStringValue] attributes:attributes] autorelease];
}

@end

#pragma mark -

@implementation NSNull (BDSKTemplateParser)

- (NSString *)templateStringValue { return @""; }

- (BOOL)isNotEmpty { return NO; }

@end

#pragma mark -

@implementation NSString (BDSKTemplateParser)

- (NSString *)templateStringValue { return self; }

@end

#pragma mark -

@implementation NSAttributedString (BDSKTemplateParser)

- (NSAttributedString *)templateAttributedStringValueWithAttributes:(NSDictionary *)attributes {
    NSMutableAttributedString *attributedString = [self mutableCopy];
    unsigned idx = 0, length = [self length];
    NSRange range = NSMakeRange(0, length);
    NSDictionary *attrs;
    [attributedString addAttributes:attributes range:range];
    while (idx < length) {
        attrs = [self attributesAtIndex:idx effectiveRange:&range];
        if (range.length > 0) {
            [attributedString addAttributes:attrs range:range];
            idx = NSMaxRange(range);
        } else idx++;
    }
    [attributedString fixAttributesInRange:NSMakeRange(0, length)];
    return [attributedString autorelease];
}

@end

#pragma mark -

@implementation NSNumber (BDSKTemplateParser)

- (BOOL)isNotEmpty {
    return [self isEqualToNumber:[NSNumber numberWithBool:NO]] == NO && [self isEqualToNumber:[NSNumber numberWithInt:0]] == NO;
}

@end

#pragma mark -

@implementation BibAuthor (BDSKTemplateParser)

- (BOOL)isNotEmpty { return [BibAuthor emptyAuthor] != self; }

@end
