//
//  BDSKSplitView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 31/10/05.
/*
 This software is Copyright (c) 2005,2006,2007
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

#import "BDSKSplitView.h"
#import "BDSKStatusBar.h"
#import "NSBezierPath_CoreImageExtensions.h"
#import "CIImage_BDSKExtensions.h"

#define END_JOIN_WIDTH 3.0f
#define END_JOIN_HEIGHT 20.0f

@interface BDSKSplitView (Private)

- (float)horizontalFraction;
- (void)setHorizontalFraction:(float)newFract;

- (float)verticalFraction;
- (void)setVerticalFraction:(float)newFract;

@end

@implementation BDSKSplitView

+ (CIColor *)startColor{
    static CIColor *startColor = nil;
    if (startColor == nil)
            startColor = [[CIColor colorWithNSColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1.0]] retain];
    return startColor;
}

+ (CIColor *)endColor{
    static CIColor *endColor = nil;
    if (endColor == nil)
            endColor = [[CIColor colorWithNSColor:[NSColor colorWithCalibratedWhite:0.85 alpha:1.0]] retain];
    return endColor;
}

- (id)initWithFrame:(NSRect)frameRect{
    if (self = [super initWithFrame:frameRect]) {
        blendStyle = 0;
    }
    return self;
}

- (void)dealloc {
    CGLayerRelease(dividerLayer);
    [super dealloc];
}

- (void)drawBlendedJoinEndAtBottomInRect:(NSRect)rect {
    // this blends us smoothly with the status bar
    // note that we are flipped, so we have to reverse the status bar colors
    [[NSBezierPath bezierPathWithRect:rect] fillPathWithHorizontalGradientFromColor:[[self class] startColor]
                                                                            toColor:[[self class] endColor]
                                                                         blendedAtTop:NO
                                                        ofVerticalGradientFromColor:[BDSKStatusBar upperColor]
                                                                            toColor:[BDSKStatusBar lowerColor]];
}

- (void)drawDividerInRect:(NSRect)aRect {
    // Draw gradient
    CGContextRef currentContext = [[NSGraphicsContext currentContext] graphicsPort];
    if (NULL == dividerLayer) {
        CGSize dividerSize = CGSizeMake(aRect.size.width, aRect.size.height);
        dividerLayer = CGLayerCreateWithContext(currentContext, dividerSize, NULL);
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:CGLayerGetContext(dividerLayer) flipped:NO];
        [NSGraphicsContext setCurrentContext:nsContext];
        NSRect rectToFill = aRect;
        rectToFill.origin = NSZeroPoint;
        [[NSBezierPath bezierPathWithRect:rectToFill] fillPathVertically:NO == [self isVertical] withStartColor:[[self class] startColor] endColor:[[self class] endColor]];
        [NSGraphicsContext restoreGraphicsState];
    }
    CGContextDrawLayerInRect(currentContext, *(CGRect *)&aRect, dividerLayer);
    
    if (blendStyle) {
        NSRect endRect, ignored;
        if (blendStyle & BDSKMinBlendStyleMask) {
            NSDivideRect(aRect, &endRect, &ignored, END_JOIN_WIDTH, [self isVertical] ? NSMinYEdge : NSMinXEdge);
            [[NSBezierPath bezierPathWithRect:endRect] fillPathVertically:[self isVertical] withStartColor:[CIColor clearColor] endColor:[[self class] startColor]];
        }
        if (blendStyle & BDSKMaxBlendStyleMask) {
            NSDivideRect(aRect, &endRect, &ignored, END_JOIN_WIDTH, [self isVertical] ? NSMaxYEdge : NSMaxXEdge);
            [[NSBezierPath bezierPathWithRect:endRect] fillPathVertically:[self isVertical] withStartColor:[[self class] endColor] endColor:[CIColor clearColor]];
        }
        if ([self isVertical] && (blendStyle & BDSKStatusBarBlendStyleMask)) {
            NSDivideRect(aRect, &endRect, &ignored, END_JOIN_HEIGHT, NSMaxYEdge);
            [self drawBlendedJoinEndAtBottomInRect:endRect];
        }
    }
    // Draw dimple
    [super drawDividerInRect:aRect];
}

- (float)dividerThickness {
	return 6.0;
}

- (void)adjustSubviews {
	// we send the notifications because NSSplitView doesn't and we need them for AutoSave of e.g. double click actions
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewWillResizeSubviewsNotification object:self];
	[super adjustSubviews];
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:self];
}

- (int)blendStyle {
    return blendStyle;
}

- (void)setBlendStyle:(int)mask {
    blendStyle = mask;
}

// arm: mouseDown: swallows mouseDragged: needlessly
- (void)mouseDown:(NSEvent *)theEvent {
    BOOL inDivider = NO;
    NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSArray *subviews = [self subviews];
    int i, count = [subviews count];
    id view;
    NSRect divRect;
    
    for (i = 0; i < count - 1; i++) {
        view = [subviews objectAtIndex:i];
        divRect = [view frame];
        if ([self isVertical]) {
            divRect.origin.x = NSMaxX(divRect);
            divRect.size.width = [self dividerThickness];
        } else {
            divRect.origin.y = NSMaxY(divRect);
            divRect.size.height = [self dividerThickness];
        }
        
        if (NSPointInRect(mouseLoc, divRect)) {
            inDivider = YES;
            break;
        }
    }
    
    if (inDivider) {
        if ([theEvent clickCount] > 1 && [[self delegate] respondsToSelector:@selector(splitView:doubleClickedDividerAt:)])
            [[self delegate] splitView:self doubleClickedDividerAt:i];
        else
            [super mouseDown:theEvent];
    } else {
        [[self nextResponder] mouseDown:theEvent];
    }
}


@end
