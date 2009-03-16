//
//  BDSKImagePopUpButton.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/22/05.
//
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

#import "BDSKImagePopUpButton.h"
#import "BDSKImagePopUpButtonCell.h"
#import "NSBezierPath_BDSKExtensions.h"


@implementation BDSKImagePopUpButton

+ (Class)cellClass{
    return [BDSKImagePopUpButtonCell class];
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]) {
		if ([[self cell] isKindOfClass:[[self class] cellClass]] == NO) {
			id oldCell = [self cell];
			id cell = [[[[[self class] cellClass] alloc] initImageCell:[oldCell image]] autorelease];
            
			[cell setEnabled:[oldCell isEnabled]];
			[cell setShowsFirstResponder:[oldCell showsFirstResponder]];
			[cell setUsesItemFromMenu:[oldCell usesItemFromMenu]];
            [cell setArrowPosition:[oldCell arrowPosition]];
			[cell setMenu:[oldCell menu]];
            
			[self setCell:cell];
		}
	}
	return self;
}

- (NSImage *)icon {
    return [[self cell] icon];
}

- (void)setIcon:(NSImage *)anImage {
    [[self cell] setIcon:anImage];
}

- (NSSize)iconSize {
    return [[self cell] iconSize];
}

- (void)setIconSize:(NSSize)newIconSize {
    [[self cell] setIconSize:newIconSize];
}

@end
