//
//  BDSKColoredView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/28/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKColoredView.h"


@implementation BDSKColoredView

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        backgroundColor = nil;
    }
    return self;
}

- (void)dealloc {
    [backgroundColor release];
    [super dealloc];
}

- (NSColor *)backgroundColor {
    return [[backgroundColor retain] autorelease];
}

- (void)setBackgroundColor:(NSColor *)newColor {
    if (backgroundColor != newColor) {
        [backgroundColor release];
        backgroundColor = [newColor retain];
    }
}

- (void)drawRect:(NSRect)rect {
	[NSGraphicsContext saveGraphicsState];
    [backgroundColor set];
    NSRectFill(rect);
	[NSGraphicsContext restoreGraphicsState];
    [super drawRect:rect];
}

@end