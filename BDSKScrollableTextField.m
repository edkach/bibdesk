//
//  BDSKScrollableTextField.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 16/8/05.
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

#import "BDSKScrollableTextField.h"
#import "BDSKScrollableTextFieldCell.h"


@implementation BDSKScrollableTextField

+ (Class)cellClass {
	return [BDSKScrollableTextFieldCell class];
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    if (self) {
		NSTextFieldCell *oldCell = [self cell];
        if ([oldCell isKindOfClass:[[self class] cellClass]] == NO) {
            BDSKASSERT_NOT_REACHED("BDSKScrollableTextField has wrong cell");
            BDSKScrollableTextFieldCell *myCell = [[[[self class] cellClass] alloc] initTextCell:[oldCell stringValue]];
            
            [myCell setFont:[oldCell font]];
            [myCell setControlSize:[oldCell controlSize]];
            [myCell setControlTint:[oldCell controlTint]];
            [myCell setEnabled:[oldCell isEnabled]];
            [myCell setAlignment:NSLeftTextAlignment];
            [myCell setWraps:NO];
            [myCell setScrollable:NO];
            [myCell setBordered:NO];
            [myCell setSelectable:NO];
            [myCell setEditable:NO];
            
            [self setCell:myCell];
            [myCell release];
        }
	}
	return self;
}

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	BDSKScrollableTextFieldCell *cell = (BDSKScrollableTextFieldCell *)[self cell];
	NSRect leftButtonRect = [cell buttonRect:BDSKScrollLeftButton forBounds:[self bounds]];
	NSRect rightButtonRect = [cell buttonRect:BDSKScrollRightButton forBounds:[self bounds]];
	NSRect buttonRect = NSZeroRect;
	BDSKScrollButton button = -1;
    
	if (NSMouseInRect(mouseLoc, leftButtonRect, [self isFlipped])) {
		buttonRect = leftButtonRect;
		button = BDSKScrollLeftButton;
	} else if (NSMouseInRect(mouseLoc, rightButtonRect, [self isFlipped])) {
		buttonRect = rightButtonRect;
		button = BDSKScrollRightButton;
	} else {
		[super mouseDown:theEvent];
		return;
	}
	
	// track the mouse while it is down
	[cell setButton:button highlighted:YES];
	BOOL keepOn = YES;
	BOOL isInside = YES;
	while (keepOn) {
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		isInside = NSMouseInRect(mouseLoc, buttonRect, [self isFlipped]);
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
				[cell setButton:button highlighted:isInside];
				break;
			case NSLeftMouseUp:
				if (isInside) {
					if (button == BDSKScrollLeftButton)
						[cell scrollBack:self];
					else
						[cell scrollForward:self];
				}
				[cell setButton:button highlighted:NO];
				keepOn = NO;
				break;
			default:
				/* Ignore any other kind of event. */
				break;
		}
	}
}

@end
