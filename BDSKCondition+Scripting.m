//
//  BDSKCondition+Scripting.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/08.
/*
 This software is Copyright (c) 2008
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

#import "BDSKCondition+Scripting.h"
#import "NSDate_BDSKExtensions.h"
#import "BDSKSmartGroup.h"
#import "BDSKFilter.h"

enum {
	BDSKASGroupContain = 'CGCt',
	BDSKASGroupNotContain = 'CGNC',
	BDSKASContain = 'CCnt',
	BDSKASNotContain = 'CNCt',
	BDSKASEqual = 'CEqu',
	BDSKASNotEqual = 'CNEq',
	BDSKASStartWith = 'CStt',
	BDSKASEndWith = 'CEnd',
	BDSKASSmaller = 'CBef',
	BDSKASLarger = 'CAft'
};

enum {
	BDSKASCountEqual = 'CCEq',
	BDSKASCountNotEqual = 'CCNE',
	BDSKASCountLarger = 'CCLa',
	BDSKASCountSmaller = 'CCSm'
};

enum {
    BDSKASToday = 'CTdy', 
    BDSKASYesterday = 'CYst', 
    BDSKASThisWeek = 'CTWk', 
    BDSKASLastWeek = 'CLWk', 
    BDSKASExactly = 'CAgo', 
    BDSKASInLast = 'CLPe', 
    BDSKASNotInLast = 'CNLP', 
    BDSKASBetween = 'CPeR', 
    BDSKASDate = 'CDat', 
    BDSKASAfterDate = 'CADt', 
    BDSKASBeforeDate = 'CCDt', 
    BDSKASInDateRange = 'CDtR'
};

enum {
    BDSKASPeriodDay = 'PDay',
    BDSKASPeriodWeek = 'PWek',
    BDSKASPeriodMonth = 'PMnt',
    BDSKASPeriodYear = 'PYer'
};

@interface BDSKCondition (BDSKPrivate)
- (void)startObserving;
@end

@implementation BDSKCondition (Scripting)

- (id)initWithScriptProperties:(NSDictionary *)dictionary {
    if (self = [super init]) {
        stringValue = [@"" retain];
        stringComparison = BDSKContain;
        countComparison = BDSKCountNotEqual;
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
        
        key = [[dictionary objectForKey:@"scriptingKey"] retain];
        if (key == nil)
            key = [@"" retain];
        
        [self startObserving];
    }
    return self;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
	NSArray *conditions = [[[self group] filter] conditions];
	unsigned idx = [conditions indexOfObjectIdenticalTo:self];
    if ([self group] && idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [(id)[self group] objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"conditions" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (NSString *)scriptingKey {
    return [self key];
}

- (void)setScriptingKey:(NSString *)newKey {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    }
}

- (int)scriptingComparison {
    int scriptingComparison = 0;
    if ([self isDateCondition]) {
        switch ([self dateComparison]) {
            case BDSKGroupContain:
                scriptingComparison = BDSKASGroupContain;
                break;
            case BDSKGroupNotContain:
                scriptingComparison = BDSKASGroupNotContain;
                break;
            case BDSKContain:
                scriptingComparison = BDSKASContain;
                break;
            case BDSKNotContain:
                scriptingComparison = BDSKASNotContain;
                break;
            case BDSKEqual:
                scriptingComparison = BDSKASEqual;
                break;
            case BDSKNotEqual:
                scriptingComparison = BDSKASNotEqual;
                break;
            case BDSKStartWith:
                scriptingComparison = BDSKASStartWith;
                break;
            case BDSKEndWith:
                scriptingComparison = BDSKASEndWith;
                break;
            case BDSKSmaller:
                scriptingComparison = BDSKASSmaller;
                break;
            case BDSKLarger:
                scriptingComparison = BDSKASLarger;
                break;
        }
    } else if ([self isCountCondition]) {
        switch ([self countComparison]) {
            case BDSKCountEqual:
                scriptingComparison = BDSKASCountEqual;
                break;
            case BDSKCountNotEqual:
                scriptingComparison = BDSKASCountNotEqual;
                break;
            case BDSKCountLarger:
                scriptingComparison = BDSKASCountLarger;
                break;
            case BDSKCountSmaller:
                scriptingComparison = BDSKASCountSmaller;
                break;
        }
    } else {
        switch ([self stringComparison]) {
            case BDSKToday:
                scriptingComparison = BDSKASToday;
                break; 
            case BDSKYesterday:
                scriptingComparison = BDSKASYesterday;
                break; 
            case BDSKThisWeek:
                scriptingComparison = BDSKASThisWeek;
                break; 
            case BDSKLastWeek:
                scriptingComparison = BDSKASLastWeek;
                break; 
            case BDSKExactly:
                scriptingComparison = BDSKASExactly;
                break; 
            case BDSKInLast:
                scriptingComparison = BDSKASInLast;
                break; 
            case BDSKNotInLast:
                scriptingComparison = BDSKASNotInLast;
                break; 
            case BDSKBetween:
                scriptingComparison = BDSKASBetween;
                break; 
            case BDSKDate:
                scriptingComparison = BDSKASDate;
                break; 
            case BDSKAfterDate:
                scriptingComparison = BDSKASAfterDate;
                break; 
            case BDSKBeforeDate:
                scriptingComparison = BDSKASBeforeDate;
                break; 
            case BDSKInDateRange:
                scriptingComparison = BDSKInDateRange;
                break;
        }
    }
    return scriptingComparison;
}

- (void)setScriptingComparison:(int)newComparison {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else {
        if ([self isDateCondition]) {
            switch (newComparison) {
                case BDSKASToday:
                    dateComparison = BDSKToday;
                    break; 
                case BDSKASYesterday:
                    dateComparison = BDSKYesterday;
                    break; 
                case BDSKASThisWeek:
                    dateComparison = BDSKThisWeek;
                    break; 
                case BDSKASLastWeek:
                    dateComparison = BDSKLastWeek;
                    break; 
                case BDSKASExactly:
                    dateComparison = BDSKExactly;
                    break; 
                case BDSKASInLast:
                    dateComparison = BDSKInLast;
                    break; 
                case BDSKASNotInLast:
                    dateComparison = BDSKNotInLast;
                    break; 
                case BDSKASBetween:
                    dateComparison = BDSKBetween;
                    break; 
                case BDSKASDate:
                    dateComparison = BDSKDate;
                    break; 
                case BDSKASAfterDate:
                    dateComparison = BDSKAfterDate;
                    break; 
                case BDSKASBeforeDate:
                    dateComparison = BDSKBeforeDate;
                    break; 
                case BDSKASInDateRange:
                    dateComparison = BDSKInDateRange;
                    break;
                default:
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
            }
        } else if ([self isCountCondition]) {
            switch (newComparison) {
                case BDSKASCountEqual:
                    countComparison = BDSKCountEqual;
                    break;
                case BDSKASCountNotEqual:
                    countComparison = BDSKCountNotEqual;
                    break;
                case BDSKASCountLarger:
                    countComparison = BDSKCountLarger;
                    break;
                case BDSKASCountSmaller:
                    countComparison = BDSKCountSmaller;
                    break;
                default:
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
            }
        } else {
            switch (newComparison) {
                case BDSKASGroupContain:
                    stringComparison = BDSKGroupContain;
                    break;
                case BDSKASGroupNotContain:
                    stringComparison = BDSKGroupNotContain;
                    break;
                case BDSKASContain:
                    stringComparison = BDSKContain;
                    break;
                case BDSKASNotContain:
                    stringComparison = BDSKNotContain;
                    break;
                case BDSKASEqual:
                    stringComparison = BDSKEqual;
                    break;
                case BDSKASNotEqual:
                    stringComparison = BDSKNotEqual;
                    break;
                case BDSKASStartWith:
                    stringComparison = BDSKStartWith;
                    break;
                case BDSKASEndWith:
                    stringComparison = BDSKEndWith;
                    break;
                case BDSKASSmaller:
                    stringComparison = BDSKSmaller;
                    break;
                case BDSKASLarger:
                    stringComparison = BDSKLarger;
                    break;
                default:
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
           }
        }
    }
}

- (NSString *)scriptingStringValue {
    return [self stringValue];
}

- (void)setScriptingStringValue:(NSString *)newStringValue {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else if ([self isDateCondition] || [self isCountCondition]) {
        [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
    } else {
        [self setStringValue:newStringValue];
    }
}

- (int)scriptingCountValue {
    return [self countValue];
}

- (void)setScriptingCountValue:(int)newCountValue {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else if ([self isCountCondition]) {
        [self setCountValue:newCountValue];
    } else {
        [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
    }
}

- (int)scriptingNumberValue {
    return [self andNumberValue];
}

- (void)setScriptingNumberValue:(int)newNumberValue {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else if ([self isDateCondition]) {
        [self setNumberValue:newNumberValue];
    } else {
        [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
    }
}

- (int)scriptingAndNumberValue {
    return [self numberValue];
}

- (void)setScriptingAndNumberValue:(int)newAndNumberValue {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else if ([self isDateCondition]) {
        [self setAndNumberValue:newAndNumberValue];
    } else {
        [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
    }
}

- (int)scriptingPeriodValue {
    int scriptingPeriodValue = 0;
    switch ([self periodValue]) {
        case BDSKPeriodDay:
            scriptingPeriodValue = BDSKASPeriodDay;
            break;
        case BDSKPeriodWeek:
            scriptingPeriodValue = BDSKASPeriodWeek;
            break;
        case BDSKPeriodMonth:
            scriptingPeriodValue = BDSKASPeriodMonth;
            break;
        case BDSKPeriodYear:
            scriptingPeriodValue = BDSKASPeriodYear;
            break;
    }
    return scriptingPeriodValue;
}

- (void)setScriptingPeriodValue:(int)newPeriodValue {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else if ([self isDateCondition]) {
        switch (newPeriodValue) {
            case BDSKASPeriodDay:
                periodValue = BDSKPeriodDay;
                break;
            case BDSKASPeriodWeek:
                periodValue = BDSKPeriodWeek;
                break;
            case BDSKASPeriodMonth:
                periodValue = BDSKPeriodMonth;
                break;
            case BDSKASPeriodYear:
                periodValue = BDSKPeriodYear;
                break;
            default:
                [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
                break;
        }
    } else {
        [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
    }
}

- (NSDate *)scriptingDateValue {
    return [self dateValue];
}

- (void)setScriptingDateValue:(NSDate *)newDateValue {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else if ([self isDateCondition]) {
        [self setDateValue:[[[NSCalendarDate alloc] initWithTimeInterval:0.0 sinceDate:newDateValue] autorelease]];
    } else {
        [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
    }
}

- (NSDate *)scriptingToDateValue {
    return [self toDateValue];
}

- (void)setScriptingToDateValue:(NSDate *)newToDateValue {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else if ([self isDateCondition]) {
        [self setToDateValue:[[[NSCalendarDate alloc] initWithTimeInterval:0.0 sinceDate:newToDateValue] autorelease]];
    } else {
        [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
    }
}

@end
