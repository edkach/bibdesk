//
//  BDSKCondition.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKCondition.h"
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import "NSDate_BDSKExtensions.h"
#import "BDSKTypeManager.h"
#import "BDSKSmartGroup.h"
#import "BDSKCondition+Scripting.h"

static char BDSKConditionObservationContext;

@interface BDSKCondition (Private)
- (NSDate *)cachedEndDate;
- (void)setCachedEndDate:(NSDate *)newCachedDate;
- (NSDate *)cachedStartDate;
- (void)setCachedStartDate:(NSDate *)newCachedDate;
- (void)updateCachedDates;
- (void)getStartDate:(NSDate **)startDate endDate:(NSDate **)endDate;
- (void)refreshCachedDate:(NSTimer *)timer;

- (void)startObserving;
- (void)endObserving;
@end

@implementation BDSKCondition

+ (void)initialize {
    [self setKeys:[NSArray arrayWithObjects:@"stringComparison", @"attachmentComparison", @"dateComparison", nil] triggerChangeNotificationsForDependentKey:@"comparison"];
    [self setKeys:[NSArray arrayWithObjects:@"stringValue", @"countValue", @"numberValue", @"andNumberValue", @"periodValue", @"dateValue", @"toDateValue", nil] triggerChangeNotificationsForDependentKey:@"value"];
    BDSKINITIALIZE;
}

+ (NSString *)dictionaryVersion {
    return @"1";
}

- (id)init {
    if (self = [super init]) {
        key = [@"" retain];
        stringValue = [@"" retain];
        stringComparison = BDSKContain;
        attachmentComparison = BDSKCountNotEqual;
        countValue = 0;
        dateComparison = BDSKToday;
        numberValue = 0;
        andNumberValue = 0;
        periodValue = BDSKPeriodDay;
        dateValue = nil;
        toDateValue = nil;
        group = nil;
        cachedStartDate = nil;
        cachedEndDate = nil;
		cacheTimer = nil;
        
        // when called from scripting we need to set the key and comparison first, so scripting setters know what type of field it is
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        if ([cmd isKindOfClass:[NSCreateCommand class]] && [[[(NSCreateCommand *)cmd createClassDescription] className] isEqualToString:@"condition"]) {
            [self setKey:[[(NSCreateCommand *)cmd resolvedKeyDictionary] objectForKey:@"scriptingKey"]];
            NSNumber *comparisonNumber = [[(NSCreateCommand *)cmd resolvedKeyDictionary] objectForKey:@"scriptingComparison"];
            if (comparisonNumber)
                [self setScriptingComparison:[comparisonNumber intValue]];
        }
        
        [self startObserving];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
	if (self = [self init]) {
        NSString *aKey = [dictionary objectForKey:@"key"];
        
        // Backwards compatibility check.  Old versions of BibDesk used BDSKAllFieldsString = NSLocalizedString(@"Any Field", @"").  Before the first localization was introduced, the definition was changed to @"AllFields", which is locale-independent and more clearly related to the constant string; unfortunately, I didn't realize the definition was being saved to disk in smart groups.  However, we use BDSKAllFieldsString consistentlyin the meaning of @"Any Field", in smart groups and searching. Rather than change the definition back again and break groups added in the meantime, we'll just check for "AllField" here (must be unlocalized) and use the new constant string.
        if ([aKey isEqualToString:@"AllFields"])
            aKey = BDSKAllFieldsString;
        
		NSString *aValue = [[dictionary objectForKey:@"value"] stringByUnescapingGroupPlistEntities];
		NSNumber *comparisonNumber = [dictionary objectForKey:@"comparison"];
		
		if (aKey != nil) 
			[self setKey:aKey];
		
		// the order is important
        if (comparisonNumber != nil) 
			[self setComparison:[comparisonNumber intValue]];
        
		if (aValue != nil)
			[self setValue:aValue];
        
        static BOOL didWarn = NO;
		
        if (([[dictionary objectForKey:@"version"] intValue] < [[[self class] dictionaryVersion] intValue]) &&
            [self isDateCondition] && didWarn == NO) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Smart Groups Need Updating", @"Message in alert dialog when smart groups with obsolete date format are detected") 
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The format for date conditions in smart groups has been changed. You should manually fix smart groups conditioning on Date-Added or Date-Modified.", @"Informative text in alert dialog")];
            [alert runModal];
            didWarn = YES;
        }
        
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [self init]) {
		// the order is important
		[self setKey:[decoder decodeObjectForKey:@"key"]];
		[self setComparison:[decoder decodeIntForKey:@"comparison"]];
		[self setValue:[decoder decodeObjectForKey:@"value"]];
		BDSKASSERT(key != nil);
		BDSKASSERT([self value] != nil);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:[self key] forKey:@"key"];
	[coder encodeInt:[self comparison] forKey:@"comparison"];
	[coder encodeObject:[self value] forKey:@"value"];
}

- (void)dealloc {
	//NSLog(@"dealloc condition");
    [self endObserving];
    [key release], key  = nil;
    [stringValue release], stringValue  = nil;
    [cachedStartDate release], cachedStartDate  = nil;
    [cachedEndDate release], cachedEndDate  = nil;
    [cacheTimer invalidate], cacheTimer  = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone {
	BDSKCondition *copy = [[BDSKCondition allocWithZone:aZone] init];
    // the order is important
	[copy setKey:[self key]];
	[copy setComparison:[self comparison]];
	[copy setValue:[self value]];
	return copy;
}

- (NSDictionary *)dictionaryValue {
	NSNumber *comparisonNumber = [NSNumber numberWithInt:[self comparison]];
	NSString *escapedValue = [[self value] stringByEscapingGroupPlistEntities];
	NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:key, @"key", escapedValue, @"value", comparisonNumber, @"comparison", [[self class] dictionaryVersion], @"version", nil];
	return [dict autorelease];
}

- (BOOL)isEqual:(id)other {
	if (self == other)
		return YES;
	if (![other isKindOfClass:[BDSKCondition class]]) 
		return NO;
	return [[self key] isEqualToString:[(BDSKCondition *)other key]] &&
		   [[self value] isEqualToString:[(BDSKCondition *)other value]] &&
		   [self comparison] == [(BDSKCondition *)other comparison];
}

- (BOOL)isSatisfiedByItem:(BibItem *)item {
	if ([NSString isEmptyString:key] == YES) 
		return YES; // empty condition matches anything
	
    if ([self isDateCondition]) {
        
        NSDate *date = nil;
        if ([key isEqualToString:BDSKDateAddedString])
            date = [item dateAdded];
        else if ([key isEqualToString:BDSKDateModifiedString])
            date = [item dateModified];
        return ((cachedStartDate == nil || [date compare:cachedStartDate] == NSOrderedDescending) &&
                (cachedEndDate == nil || [date compare:cachedEndDate] == NSOrderedAscending));
        
    } else if ([self isAttachmentCondition]) {
        
        int count = 0;
        if ([key isEqualToString:BDSKLocalFileString])
            count = [[item localFiles] count];
        else if ([key isEqualToString:BDSKRemoteURLString])
            count = [[item remoteURLs] count];
        
        switch (attachmentComparison) {
            case BDSKCountEqual:
                return count == countValue;
            case BDSKCountNotEqual:
                return count != countValue;
            case BDSKCountLarger:
                return count > countValue;
            case BDSKCountSmaller:
                return count < countValue;
            default:
                break; // other enum values are handled below, but the compiler doesn't know that
        }
        
        NSArray *itemValues = nil;
        if ([key isEqualToString:BDSKLocalFileString])
            itemValues = [[item existingLocalFiles] valueForKey:@"path"];
        else if ([key isEqualToString:BDSKRemoteURLString])
            itemValues = [[item remoteURLs] valueForKey:@"absoluteString"];
        NSEnumerator *itemEnum  = [itemValues objectEnumerator];
        NSString *itemValue;
        
        CFOptionFlags options = kCFCompareCaseInsensitive;
        if (attachmentComparison == BDSKAttachmentEndWith)
            options |= kCFCompareBackwards | kCFCompareAnchored;
        else if (attachmentComparison == BDSKAttachmentStartWith)
            options |= kCFCompareAnchored;
        BOOL matchReturnValue = (stringComparison != BDSKAttachmentNotContain);
        CFRange range;
        
        while (itemValue = [itemEnum nextObject]) {
            if (CFStringFindWithOptions((CFStringRef)itemValue, (CFStringRef)stringValue, CFRangeMake(0, [itemValue length]), options, &range))
                return matchReturnValue;
        }
        return NO == matchReturnValue;
        
    } else {
        
        BDSKASSERT(stringValue != nil);
        
        if (stringComparison == BDSKGroupContain || stringComparison == BDSKGroupNotContain) {
            if ([key isEqualToString:BDSKAllFieldsString]) {
                NSEnumerator *fieldEnum = [[item allFieldNames] objectEnumerator];
                NSString *field;
                BOOL isContain = stringComparison == BDSKGroupContain;
                while (field = [fieldEnum nextObject]) {
                    if ([field isInvalidGroupField] == NO && [item isContainedInGroupNamed:stringValue forField:field])
                        return isContain;
                }
                return NO == isContain;
            } else {
                if (stringComparison == BDSKGroupContain) 
                    return ([item isContainedInGroupNamed:stringValue forField:key] == YES);
                if (stringComparison == BDSKGroupNotContain) 
                    return ([item isContainedInGroupNamed:stringValue forField:key] == NO);
            }
        }
        
        // use local values, as we may change them to support "Any Field"
        int comparison = stringComparison;
        NSString *value = stringValue;
        // unset values are considered empty strings
        NSString *itemValue = [item stringValueOfField:key] ?: @"";
        // to speed up comparisons
        if ([itemValue isComplex] || [itemValue isInherited])
            itemValue = [NSString stringWithString:itemValue];
        
        if (comparison == BDSKEqual || comparison == BDSKNotEqual) {
            if ([key isEqualToString:BDSKAllFieldsString]) {
                comparison = comparison == BDSKEqual ? BDSKContain : BDSKNotContain;
                itemValue = [NSString stringWithFormat:@"%C%@%C", 0x1E, itemValue, 0x1E];
                value = [NSString stringWithFormat:@"%C%@%C", 0x1E, stringValue, 0x1E];
            } else {
                if (comparison == BDSKEqual) 
                    return ([value caseInsensitiveCompare:itemValue] == NSOrderedSame);
                else if (comparison == BDSKNotEqual) 
                    return ([value caseInsensitiveCompare:itemValue] != NSOrderedSame);
            }
        } 
        
        if (comparison == BDSKSmaller || comparison == BDSKLarger) {
            NSComparisonResult result = [value localizedCaseInsensitiveNumericCompare:itemValue];
            if (comparison == BDSKSmaller) 
                return (result == NSOrderedDescending);
            if (comparison == BDSKLarger) 
                return (result == NSOrderedAscending);
        }
        
        // minor optimization: Shark showed -[NSString rangeOfString:options:] as a bottleneck, calling through to CFStringFindWithOptions
        CFOptionFlags options = kCFCompareCaseInsensitive;
        if (comparison == BDSKEndWith || comparison == BDSKStartWith) {
            if ([key isEqualToString:BDSKAllFieldsString]) {
                if (comparison == BDSKEndWith) {
                    itemValue = [NSString stringWithFormat:@"%@%C", itemValue, 0x1E];
                    value = [NSString stringWithFormat:@"%@%C", stringValue, 0x1E];
                } else if (comparison == BDSKStartWith) {
                    itemValue = [NSString stringWithFormat:@"%C%@", 0x1E, itemValue];
                    value = [NSString stringWithFormat:@"%C%@", 0x1E, stringValue];
                }
            } else {
                if (comparison == BDSKEndWith)
                    options |= kCFCompareBackwards | kCFCompareAnchored;
                else if (comparison == BDSKStartWith)
                    options |= kCFCompareAnchored;
            }
        }
        CFRange range;
        CFIndex itemLength = CFStringGetLength((CFStringRef)itemValue);
        Boolean foundString = CFStringFindWithOptions((CFStringRef)itemValue, (CFStringRef)value, CFRangeMake(0, itemLength), options, &range);
        switch (comparison) {
            case BDSKContain:
            case BDSKStartWith:
            case BDSKEndWith:
                return foundString;
            case BDSKNotContain:
                return foundString == FALSE;
            default:
                break; // other enum types are handled before the switch, but the compiler doesn't know that
        }
        
    }
    
    BDSKASSERT_NOT_REACHED("undefined comparison");
    return NO;
}

#pragma mark Accessors

#pragma mark | generic

- (NSString *)key {
    return [[key retain] autorelease];
}

- (void)setKey:(NSString *)newKey {
	// we never want the key to be nil. It is set to nil sometimes by the binding mechanism
    if (key != newKey) {
        [key release];
        key = [(newKey ?: @"") copy];
    }
}

- (int)comparison {
    return [self isDateCondition] ? dateComparison : [self isAttachmentCondition] ? attachmentComparison : stringComparison;
}

- (void)setComparison:(int)newComparison {
    if ([self isDateCondition])
        [self setDateComparison:(BDSKDateComparison)newComparison];
    if ([self isAttachmentCondition])
        [self setAttachmentComparison:(BDSKAttachmentComparison)newComparison];
    else
        [self setStringComparison:(BDSKStringComparison)newComparison];
}

- (NSString *)value {
    if ([self isDateCondition]) {
        switch (dateComparison) {
            case BDSKExactly: 
            case BDSKInLast: 
            case BDSKNotInLast: 
                return [NSString stringWithFormat:@"%i %i", numberValue, periodValue];
            case BDSKBetween: 
                return [NSString stringWithFormat:@"%i %i %i", numberValue, andNumberValue, periodValue];
            case BDSKDate: 
            case BDSKAfterDate: 
            case BDSKBeforeDate: 
                return [dateValue standardDescription];
            case BDSKInDateRange:
                return [NSString stringWithFormat:@"%@ to %@", [dateValue standardDescription], [toDateValue standardDescription]];
            default:
                return @"";
        }
    } else if ([self isAttachmentCondition]) {
        switch (dateComparison) {
            case BDSKCountEqual: 
            case BDSKCountNotEqual: 
            case BDSKCountLarger: 
            case BDSKCountSmaller: 
                return [NSString stringWithFormat:@"%i", countValue];
            case BDSKAttachmentContain: 
            case BDSKAttachmentNotContain: 
            case BDSKAttachmentStartWith: 
            case BDSKAttachmentEndWith: 
            default:
                return [self stringValue];
        }
    } else {
        return [self stringValue];
    }
}

- (void)setValue:(NSString *)newValue {
	// we never want the value to be nil. It is set to nil sometimes by the binding mechanism
	if (newValue == nil) newValue = @"";
    if ([self isDateCondition]) {
        NSArray *values = nil;
        switch (dateComparison) {
            case BDSKExactly: 
            case BDSKInLast: 
            case BDSKNotInLast: 
                values = [newValue componentsSeparatedByString:@" "];
                BDSKASSERT([values count] == 2);
                [self setNumberValue:[[values objectAtIndex:0] intValue]];
                [self setPeriodValue:[[values objectAtIndex:1] intValue]];
                break;
            case BDSKBetween: 
                values = [newValue componentsSeparatedByString:@" "];
                BDSKASSERT([values count] == 3);
                [self setNumberValue:[[values objectAtIndex:0] intValue]];
                [self setAndNumberValue:[[values objectAtIndex:1] intValue]];
                [self setPeriodValue:[[values objectAtIndex:2] intValue]];
                break;
            case BDSKDate: 
            case BDSKAfterDate: 
            case BDSKBeforeDate: 
                [self setDateValue:[NSDate dateWithString:newValue]];
                break;
            case BDSKInDateRange:
                values = [newValue componentsSeparatedByString:@" to "];
                BDSKASSERT([values count] == 2);
                [self setDateValue:[NSDate dateWithString:[values objectAtIndex:0]]];
                [self setToDateValue:[NSDate dateWithString:[values objectAtIndex:1]]];
                break;
            default:
                break;
        }
    } else if ([self isAttachmentCondition]) {
        switch (dateComparison) {
            case BDSKCountEqual: 
            case BDSKCountNotEqual: 
            case BDSKCountLarger: 
            case BDSKCountSmaller: 
                [self setCountValue:[newValue intValue]];
                break;
            case BDSKAttachmentContain: 
            case BDSKAttachmentNotContain: 
            case BDSKAttachmentStartWith: 
            case BDSKAttachmentEndWith: 
                [self setStringValue:newValue];
                break;
            default:
                break;
        }
    } else {
        [self setStringValue:newValue];
    }
}

#pragma mark | strings

- (BDSKStringComparison)stringComparison {
    return stringComparison;
}

- (void)setStringComparison:(BDSKStringComparison)newComparison {
    stringComparison = newComparison;
}

- (NSString *)stringValue {
    return [[stringValue retain] autorelease];
}

- (void)setStringValue:(NSString *)newValue {
	// we never want the value to be nil. It is set to nil sometimes by the binding mechanism
    if (stringValue != newValue) {
        [stringValue release];
        stringValue = [(newValue ?: @"") retain];
    }
}

#pragma mark | count (linked files/URLs)

- (BDSKAttachmentComparison)attachmentComparison {
    return attachmentComparison;
}

- (void)setAttachmentComparison:(BDSKAttachmentComparison)newComparison {
    attachmentComparison = newComparison;
}

- (int)countValue {
    return countValue;
}

- (void)setCountValue:(int)newValue {
    countValue = newValue;
}

#pragma mark | dates

- (BDSKDateComparison)dateComparison {
    return dateComparison;
}

- (void)setDateComparison:(BDSKDateComparison)newComparison {
    dateComparison = newComparison;
}

- (int)numberValue {
    return numberValue;
}

- (void)setNumberValue:(int)newNumber {
    numberValue = newNumber;
}

- (int)andNumberValue {
    return andNumberValue;
}

- (void)setAndNumberValue:(int)newNumber {
    andNumberValue = newNumber;
}

- (int)periodValue {
    return periodValue;
}

- (void)setPeriodValue:(int)newPeriod {
    periodValue = newPeriod;
}

- (NSDate *)dateValue {
    return [[dateValue retain] autorelease];
}

- (void)setDateValue:(NSDate *)newDate {
    if (dateValue != newDate) {
        [dateValue release];
        dateValue = [newDate retain];
    }
}

- (NSDate *)toDateValue {
    return [[toDateValue retain] autorelease];
}

- (void)setToDateValue:(NSDate *)newDate {
    if (toDateValue != newDate) {
        [toDateValue release];
        toDateValue = [newDate retain];
    }
}

#pragma mark Other 

- (BOOL)isDateCondition {
    return [key fieldType] == BDSKDateField;
}

- (BOOL)isAttachmentCondition {
    return [key fieldType] == BDSKLinkedField;
}

- (void)setDefaultComparison {
    // set some default comparison
    switch ([key fieldType]) {
        case BDSKDateField:
            [self setDateComparison:BDSKToday];
            break;
        case BDSKLinkedField:
            [self setAttachmentComparison:BDSKCountNotEqual];
            break;
        case BDSKStringField:
            [self setStringComparison:BDSKContain];
            break;
        default:
            [self setStringComparison:BDSKEqual];
            break;
    }
}

- (void)setDefaultValue {
    // set some default values
    switch ([key fieldType]) {
        case BDSKDateField:
        {
            NSDate *today = [NSDate date];
            [self setNumberValue:7];
            [self setAndNumberValue:9];
            [self setPeriodValue:BDSKPeriodDay];
            [self setDateValue:today];
            [self setToDateValue:today];
            break;
        }
        case BDSKLinkedField:
            [self setCountValue:0];
            [self setStringValue:@""];
            break;
        case BDSKBooleanField:
            [self setStringValue:[NSString stringWithBool:NO]];
            break;
        case BDSKTriStateField:
            [self setStringValue:[NSString stringWithTriStateValue:NSOffState]];
            break;
        case BDSKRatingField:
            [self setStringValue:@"0"];
            break;
        default:
            [self setStringValue:@""];
            break;
    }
}

- (BDSKSmartGroup *)group {
    return group;
}

- (void)setGroup:(BDSKSmartGroup *)newGroup {
    if (group != newGroup) {
        group = newGroup;
        if ([self isDateCondition])
            [self updateCachedDates];
    }
}

@end

@implementation BDSKCondition (Private)

#pragma mark Cached dates

- (NSDate *)cachedEndDate {
    return cachedEndDate;
}

- (void)setCachedEndDate:(NSDate *)newCachedDate {
    if (cachedEndDate != newCachedDate) {
        [cachedEndDate release];
        cachedEndDate = [newCachedDate retain];
	}
}

- (NSDate *)cachedStartDate {
    return cachedStartDate;
}

- (void)setCachedStartDate:(NSDate *)newCachedDate {
    if (cachedStartDate != newCachedDate) {
        [cachedStartDate release];
        cachedStartDate = [newCachedDate retain];
	}
}

- (void)updateCachedDates {
    NSDate *startDate = nil;
    NSDate *endDate = nil;
    
    [cacheTimer invalidate];
    cacheTimer = nil;
    
    if ([self isDateCondition]) {
        [self getStartDate:&startDate endDate:&endDate];
        if (dateComparison < BDSKDate && group) {
            // we fire every day at 1 second past midnight, because the condition changes at midnight
            NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            NSDateComponents *components = [NSDateComponents dateComponentsWithYear:0 month:0 day:1 hour:0 minute:0 second:1];
            NSDate *fireDate = [calendar dateByAddingComponents:components toDate:[[NSDate date] startOfDay] options:0];
            [calendar release];
            NSTimeInterval refreshInterval = 24 * 3600;
            cacheTimer = [[NSTimer alloc] initWithFireDate:fireDate interval:refreshInterval target:self selector:@selector(refreshCachedDate:) userInfo:NULL repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:cacheTimer forMode:NSDefaultRunLoopMode];
            [cacheTimer release];
        }
    }
    
    [self setCachedStartDate:startDate];
    [self setCachedEndDate:endDate];
}

- (void)refreshCachedDate:(NSTimer *)timer {
    NSDate *startDate = nil;
    NSDate *endDate = nil;
    BOOL changed = NO;
    
	[self getStartDate:&startDate endDate:&endDate];
    if (startDate != nil && [cachedStartDate compare:startDate] != NSOrderedSame) {
        [self setCachedStartDate:startDate];
        changed = YES;
    }
    if (endDate != nil && [cachedEndDate compare:endDate] != NSOrderedSame) {
        [self setCachedEndDate:endDate];
        changed = YES;
    }
    
    if (changed && group) {
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFilterChangedNotification object:group];
    }
}

- (void)getStartDate:(NSDate **)startDate endDate:(NSDate **)endDate {
    NSDate *today = [[NSDate date] startOfDay];
    
    switch (dateComparison) {
        case BDSKToday:
            *startDate = today;
            *endDate = nil;
            break;
        case BDSKYesterday: 
            *startDate = [today dateByAddingNumber:-1 ofPeriod:BDSKPeriodDay];
            *endDate = today;
            break;
        case BDSKThisWeek: 
            *startDate = [today startOfWeek];
            *endDate = nil;
            break;
        case BDSKLastWeek: 
            *endDate = [today startOfWeek];
            *startDate = [*endDate dateByAddingNumber:-1 ofPeriod:BDSKPeriodWeek];
            break;
        case BDSKExactly: 
            *startDate = [today dateByAddingNumber:-numberValue ofPeriod:periodValue];
            *endDate = [*startDate dateByAddingNumber:1 ofPeriod:periodValue];
            break;
        case BDSKInLast: 
            *startDate = [today dateByAddingNumber:1-numberValue ofPeriod:periodValue];
            *endDate = nil;
            break;
        case BDSKNotInLast: 
            *startDate = nil;
            *endDate = [today dateByAddingNumber:1-numberValue ofPeriod:periodValue];
            break;
        case BDSKBetween: 
            *startDate = [today dateByAddingNumber:-MAX(numberValue,andNumberValue) ofPeriod:periodValue];
            *endDate = [today dateByAddingNumber:1-MIN(numberValue,andNumberValue) ofPeriod:periodValue];
            break;
        case BDSKDate: 
            *startDate = [dateValue startOfDay];
            *endDate = [*startDate dateByAddingNumber:1 ofPeriod:BDSKPeriodDay];
            break;
        case BDSKAfterDate: 
            *startDate = [dateValue endOfDay];
            *endDate = nil;
            break;
        case BDSKBeforeDate: 
            *startDate = nil;
            *endDate = [dateValue startOfDay];
            break;
        case BDSKInDateRange:
            *startDate = [dateValue startOfDay];
            *endDate = [toDateValue endOfDay];
            break;
    }
}

#pragma mark KVO

- (void)startObserving {
    [self addObserver:self forKeyPath:@"key" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld  context:&BDSKConditionObservationContext];
    [self addObserver:self forKeyPath:@"comparison" options:0  context:&BDSKConditionObservationContext];
    [self addObserver:self forKeyPath:@"value" options:0  context:&BDSKConditionObservationContext];
}

- (void)endObserving {
    [self removeObserver:self forKeyPath:@"key"];
    [self removeObserver:self forKeyPath:@"comparison"];
    [self removeObserver:self forKeyPath:@"value"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKConditionObservationContext) {
        if ([keyPath isEqualToString:@"key"]) {
            NSString *oldKey = [change objectForKey:NSKeyValueChangeOldKey];
            NSString *newKey = [change objectForKey:NSKeyValueChangeNewKey];
            int oldFieldType = [oldKey fieldType];
            int newFieldType = [newKey fieldType];
            if(oldFieldType != newFieldType){
                if (oldFieldType == BDSKDateField)
                    [self updateCachedDates]; // remove the cached date and stop the timer
                [self setDefaultComparison];
                [self setDefaultValue];
            }
        } else if (([keyPath isEqualToString:@"comparison"] || [keyPath isEqualToString:@"value"]) && [self isDateCondition]) {
            [self updateCachedDates];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


@implementation NSString (BDSKConditionExtensions)

- (int)fieldType {
    if ([self isEqualToString:BDSKDateAddedString] || [self isEqualToString:BDSKDateModifiedString])
        return BDSKDateField;
    else if ([self isEqualToString:BDSKLocalFileString] || [self isEqualToString:BDSKRemoteURLString])
        return BDSKLinkedField;
    else if ([self isBooleanField])
        return BDSKBooleanField;
    else if ([self isTriStateField])
        return BDSKTriStateField;
    else if ([self isRatingField])
        return BDSKRatingField;
    else
        return BDSKStringField;
}

@end
