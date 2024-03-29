//
//  BDSKRatingButton.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/9/05.
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

#import "BDSKRatingButton.h"


@implementation BDSKRatingButton

+ (Class)cellClass {
	return [BDSKRatingButtonCell class];
}

// designated initializer
- (id)initWithFrame:(NSRect)frameRect{
	if ([super initWithFrame:frameRect]) {
		BDSKPOSTCONDITION([self cell] == nil || [[self cell] isKindOfClass:[BDSKRatingButtonCell class]]);
	}
	return self;
}

// for IB
- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
		NSButtonCell *oldCell = [self cell];
		if ([oldCell isKindOfClass:[[self class] cellClass]] == NO) {
            BDSKASSERT_NOT_REACHED("BDSKRatingButton has wrong cell");
			BDSKRatingButtonCell *newCell = [[[[self class] cellClass] alloc] init];
			[newCell setBordered:[oldCell isBordered]];
			[newCell setAlignment:[oldCell alignment]];
			[newCell setEditable:[oldCell isEditable]];
			[newCell setTarget:[oldCell target]];
			[newCell setAction:[oldCell action]];
			[self setCell:newCell];
			[newCell release];
		}
		BDSKPOSTCONDITION([self cell] == nil || [[self cell] isKindOfClass:[BDSKRatingButtonCell class]]);
	}
	return self;
}

- (NSUInteger)rating {
	id cell = [self cell];
    BDSKPRECONDITION(cell == nil || [cell isKindOfClass:[BDSKRatingButtonCell class]]);
    return [cell rating];
}

- (void)setRating:(NSUInteger)newRating {
	id cell = [self cell];
    BDSKPRECONDITION(cell == nil || [cell isKindOfClass:[BDSKRatingButtonCell class]]);
	[cell setRating:newRating];
}

- (NSUInteger)maxRating {
	id cell = [self cell];
    BDSKPRECONDITION(cell == nil || [cell isKindOfClass:[BDSKRatingButtonCell class]]);
    return [cell maxRating];
}

- (void)setMaxRating:(NSUInteger)newRating {
	id cell = [self cell];
    BDSKPRECONDITION(cell == nil || [cell isKindOfClass:[BDSKRatingButtonCell class]]);
    [cell setMaxRating:newRating];
}

- (void)keyDown:(NSEvent *)theEvent {
	if ([self isEnabled])  {
		NSString *characters = [theEvent characters];
		unichar character = 0;
		
		if ([characters length] > 0) {
			character = [characters characterAtIndex: 0];
		}
		
		// Handle number keys to set the rating
		if (character >= '0' && character <= '9' && character <= '0' + [self maxRating]) {
			[self setRating:(NSInteger)(character - '0')];
            [self sendAction:[self action] to:[self target]];
			return;
		}   
	}
	
	[super keyDown: theEvent];
}

- (void)moveLeft:(id)sender {
    if ([self rating] > 0) {
        [self setRating:[self rating] - 1];
        [self sendAction:[self action] to:[self target]];
    } else NSBeep();
}

- (void)moveRight:(id)sender {
    if ([self rating] <= [self maxRating]) {
        [self setRating:[self rating] + 1];
        [self sendAction:[self action] to:[self target]];
    } else NSBeep();
}

@end
