//
//  BDSKCondition.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
/*
 This software is Copyright (c) 2005,2006
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
#import <OmniBase/assertions.h>
#import "BDSKDateStringFormatter.h"

@interface BDSKCondition (Private)
- (NSDate *)cachedEndDate;
- (void)setCachedEndDate:(NSDate *)newCachedDate;
- (NSDate *)cachedStartDate;
- (void)setCachedStartDate:(NSDate *)newCachedDate;
- (void)updateCachedDates;
- (void)getStartDate:(NSCalendarDate **)startDate endDate:(NSCalendarDate **)endDate;
- (void)refreshCachedDate:(NSTimer *)timer;

- (void)startObserving;
- (void)endObserving;
@end

@implementation BDSKCondition

+ (void)initialize {
    [self setKeys:[NSArray arrayWithObjects:@"valueComparison", @"dateComparison", nil] triggerChangeNotificationsForDependentKey:@"comparison"];
    [self setKeys:[NSArray arrayWithObjects:@"dateComparison", @"numberValue", @"andNumberValue", @"periodValue", @"dateValue", @"toDateValue", nil] triggerChangeNotificationsForDependentKey:@"value"];
}

- (id)init {
    self = [super init];
    if (self) {
        key = [@"" retain];
        value = [@"" retain];
        valueComparison = BDSKContain;
        dateComparison = BDSKToday;
        numberValue = 0;
        andNumberValue = 0;
        periodValue = BDSKPeriodDay;
        dateValue = nil;
        toDateValue = nil;
        cachedStartDate = nil;
        cachedEndDate = nil;
		cacheTimer = nil;
        [self startObserving];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
	if (self = [self init]) {
		NSString *aKey = [dictionary objectForKey:@"key"];
		NSMutableString *escapedValue = [[dictionary objectForKey:@"value"] mutableCopy];
		NSNumber *comparisonNumber = [dictionary objectForKey:@"comparison"];
		
		if (aKey != nil) 
			[self setKey:aKey];
		
		if (comparisonNumber != nil) 
			[self setComparison:[comparisonNumber intValue]];
        
		if (escapedValue != nil) {
			// we escape braces as they can give problems with btparse
			[escapedValue replaceAllOccurrencesOfString:@"%7B" withString:@"{"];
			[escapedValue replaceAllOccurrencesOfString:@"%7D" withString:@"}"];
			[escapedValue replaceAllOccurrencesOfString:@"%25" withString:@"%"];
			[self setValue:escapedValue];
			[escapedValue release];
        }
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [self init]) {
		[self setKey:[decoder decodeObjectForKey:@"key"]];
		[self setComparison:[decoder decodeIntForKey:@"comparison"]];
		[self setValue:[decoder decodeObjectForKey:@"value"]];
		OBASSERT(key != nil);
		OBASSERT([self value] != nil);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:[self key] forKey:@"key"];
	[coder encodeObject:[self value] forKey:@"value"];
	[coder encodeInt:[self comparison] forKey:@"comparison"];
}

- (void)dealloc {
	//NSLog(@"dealloc condition");
    [self endObserving];
    [key release], key  = nil;
    [value release], value  = nil;
    [cachedStartDate release], cachedStartDate  = nil;
    [cachedEndDate release], cachedEndDate  = nil;
    [cacheTimer invalidate], cacheTimer  = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone {
	BDSKCondition *copy = [[BDSKCondition allocWithZone:aZone] init];
	[copy setKey:[self key]];
	[copy setComparison:[self comparison]];
	[copy setValue:[self value]];
	return copy;
}

- (NSDictionary *)dictionaryValue {
	NSNumber *comparisonNumber = [NSNumber numberWithInt:[self comparison]];
	NSMutableString *escapedValue = [[self value] mutableCopy];
	// escape braces as they can give problems with btparse
	[escapedValue replaceAllOccurrencesOfString:@"%" withString:@"%25"];
	[escapedValue replaceAllOccurrencesOfString:@"{" withString:@"%7B"];
	[escapedValue replaceAllOccurrencesOfString:@"}" withString:@"%7D"];
	NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:key, @"key", escapedValue, @"value", comparisonNumber, @"comparison", nil];
	[escapedValue release];
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
        
    } else {
        
        OBASSERT(value != nil);
        
        if (valueComparison == BDSKGroupContain) 
            return ([item isContainedInGroupNamed:value forField:key] == YES);
        if (valueComparison == BDSKGroupNotContain) 
            return ([item isContainedInGroupNamed:value forField:key] == NO);
        
        NSString *itemValue = [item valueOfGenericField:key];
        // unset values are considered empty strings
        if (itemValue == nil)
            itemValue = @"";
        // to speed up comparisons
        if ([itemValue isComplex] || [itemValue isInherited])
            itemValue = [NSString stringWithString:itemValue];
        
        if (valueComparison == BDSKEqual) 
            return ([value caseInsensitiveCompare:itemValue] == NSOrderedSame);
        if (valueComparison == BDSKNotEqual) 
            return ([value caseInsensitiveCompare:itemValue] != NSOrderedSame);
        
        // minor optimization: Shark showed -[NSString rangeOfString:options:] as a bottleneck, calling through to CFStringFindWithOptions
        CFOptionFlags options = kCFCompareCaseInsensitive;
        if (valueComparison == BDSKEndWith)
            options = options | kCFCompareBackwards;
        CFRange range;
        CFIndex itemLength = CFStringGetLength((CFStringRef)itemValue);
        Boolean foundString = CFStringFindWithOptions((CFStringRef)itemValue, (CFStringRef)value, CFRangeMake(0, itemLength), options, &range);
        switch (valueComparison) {
            case BDSKContain:
                return foundString;
            case BDSKNotContain:
                return foundString == FALSE;
            case BDSKStartWith:
                return foundString && range.location == 0;
            case BDSKEndWith:
                return foundString && (range.location + range.length) == itemLength;
            default:
                break; // other enum types are handled before the switch, but the compiler doesn't know that
        }
        
        NSComparisonResult result = [value localizedCaseInsensitiveNumericCompare:itemValue];
        if (valueComparison == BDSKSmaller) 
            return (result == NSOrderedDescending);
        if (valueComparison == BDSKLarger) 
            return (result == NSOrderedAscending);
        
    }
    
    OBASSERT_NOT_REACHED("undefined comparison");
    return NO;
}

#pragma mark Accessors

- (NSString *)key {
    return [[key retain] autorelease];
}

- (void)setKey:(NSString *)newKey {
	// we never want the key to be nil. It is set to nil sometimes by the binding mechanism
	if (newKey == nil) newKey = @"";
    if (![key isEqualToString:newKey]) {
        [key release];
        key = [newKey copy];
    }
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
                return [NSString stringWithFormat:@"%@", dateValue];
            case BDSKInDateRange:
                return [NSString stringWithFormat:@"%@ to %@", dateValue, toDateValue];
            default:
                return @"";
        }
    } else {
        return [[value retain] autorelease];
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
                OBASSERT([values count] == 2);
                [self setNumberValue:[[values objectAtIndex:0] intValue]];
                [self setPeriodValue:[[values objectAtIndex:1] intValue]];
                break;
            case BDSKBetween: 
                values = [newValue componentsSeparatedByString:@" "];
                OBASSERT([values count] == 3);
                [self setNumberValue:[[values objectAtIndex:0] intValue]];
                [self setAndNumberValue:[[values objectAtIndex:1] intValue]];
                [self setPeriodValue:[[values objectAtIndex:2] intValue]];
                break;
            case BDSKDate: 
            case BDSKAfterDate: 
            case BDSKBeforeDate: 
                [self setDateValue:[NSCalendarDate dateWithNaturalLanguageString:newValue]];
                break;
            case BDSKInDateRange:
                values = [newValue componentsSeparatedByString:@" to "];
                OBASSERT([values count] == 2);
                [self setDateValue:[NSCalendarDate dateWithNaturalLanguageString:[values objectAtIndex:0]]];
                [self setToDateValue:[NSCalendarDate dateWithNaturalLanguageString:[values objectAtIndex:1]]];
                break;
            default:
                break;
        }
    } else if (![value isEqualToString:newValue]) {
        [value release];
        value = [newValue retain];
    }
}

- (int)comparison {
    return ([self isDateCondition]) ? dateComparison : valueComparison;
}

- (void)setComparison:(int)newComparison {
    if ([self isDateCondition])
        [self setDateComparison:(BDSKDateComparison)newComparison];
    else
        [self setValueComparison:(BDSKComparison)newComparison];
}

- (BDSKComparison)valueComparison {
    return valueComparison;
}

- (void)setValueComparison:(BDSKComparison)newComparison {
    valueComparison = newComparison;
}

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

- (NSCalendarDate *)dateValue {
    return [[dateValue retain] autorelease];
}

- (void)setDateValue:(NSCalendarDate *)newDate {
    if (dateValue != newDate) {
        [dateValue release];
        dateValue = [newDate retain];
    }
}

- (NSCalendarDate *)toDateValue {
    return [[toDateValue retain] autorelease];
}

- (void)setToDateValue:(NSCalendarDate *)newDate {
    if (toDateValue != newDate) {
        [toDateValue release];
        toDateValue = [newDate retain];
    }
}

- (BOOL)isDateCondition {
    return ([key isEqualToString:BDSKDateAddedString] || [key isEqualToString:BDSKDateModifiedString]);
}

- (void)setDefaultValue {
    // set some default values
    if ([self isDateCondition]) {
        NSCalendarDate *today = [NSCalendarDate date];
        [self setNumberValue:7];
        [self setAndNumberValue:9];
        [self setPeriodValue:BDSKPeriodDay];
        [self setDateValue:today];
        [self setToDateValue:today];
    } else {
        [self setValue:@""];
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
    NSCalendarDate *startDate = nil;
    NSCalendarDate *endDate = nil;
    
    [cacheTimer invalidate];
    cacheTimer = nil;
    
    if ([self isDateCondition]) {
        [self getStartDate:&startDate endDate:&endDate];
        if (dateComparison < BDSKDate) {
            // we fire every day at 1 second past midnight, because the condition changes at midnight
            NSCalendarDate *fireDate = [[[NSCalendarDate date] startOfDay] dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:1];
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
    NSCalendarDate *startDate = nil;
    NSCalendarDate *endDate = nil;
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
    
    if (changed) {
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFilterChangedNotification object:self];
    }
}

- (void)getStartDate:(NSCalendarDate **)startDate endDate:(NSCalendarDate **)endDate {
    NSCalendarDate *today = [[NSCalendarDate date] startOfDay];
    
    switch (dateComparison) {
        case BDSKToday:
            *startDate = today;
            *endDate = nil;
            break;
        case BDSKYesterday: 
            *startDate = [today dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
            *endDate = today;
            break;
        case BDSKThisWeek: 
            *startDate = [today startOfWeek];
            *endDate = nil;
            break;
        case BDSKLastWeek: 
            *endDate = [today startOfWeek];
            *startDate = [*endDate dateByAddingYears:0 months:0 days:-7 hours:0 minutes:0 seconds:0];
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
            *startDate = (dateValue == nil) ? nil : [dateValue startOfDay];
            *endDate = [*startDate dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
            break;
        case BDSKAfterDate: 
            *startDate = (dateValue == nil) ? nil : [dateValue endOfDay];
            *endDate = nil;
            break;
        case BDSKBeforeDate: 
            *startDate = nil;
            *endDate = (dateValue == nil) ? nil : [dateValue startOfDay];
            break;
        case BDSKInDateRange:
            *startDate = (dateValue == nil) ? nil : [dateValue startOfDay];
            *endDate = (toDateValue == nil) ? nil : [toDateValue endOfDay];
            break;
    }
}

#pragma mark KVO

- (void)startObserving {
    [self addObserver:self forKeyPath:@"key" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld  context:NULL];
    [self addObserver:self forKeyPath:@"value" options:0  context:NULL];
}

- (void)endObserving {
    [self removeObserver:self forKeyPath:@"key"];
    [self removeObserver:self forKeyPath:@"value"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"key"]) {
        NSString *oldKey = [change objectForKey:NSKeyValueChangeOldKey];
        NSString *newKey = [change objectForKey:NSKeyValueChangeNewKey];
        BOOL wasDate = ([oldKey isEqualToString:BDSKDateModifiedString] || [oldKey isEqualToString:BDSKDateAddedString]);
        BOOL isDate = ([newKey isEqualToString:BDSKDateModifiedString] || [newKey isEqualToString:BDSKDateAddedString]);
        if(wasDate != isDate){
            if ([self isDateCondition]) {
                [self setDateComparison:BDSKToday];
                [self setDefaultValue];
            } else {
                [self updateCachedDates]; // remove the cached date and stop the timer
                [self setValueComparison:BDSKContain];
                [self setDefaultValue];
            }
        }
    } else if ([keyPath isEqualToString:@"value"]) {
        if ([self isDateCondition]) {
            [self updateCachedDates];
        }
    }
}

@end
