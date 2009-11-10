//
//  BDSKSplitView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/09.
/*
 This software is Copyright (c) 2009
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
#import "NSViewAnimation_BDSKExtensions.h"

#ifndef NSAppKitVersionNumber10_5
#define NSAppKitVersionNumber10_5 949
#endif

@implementation BDSKSplitView

- (id)initWithCoder:(NSCoder *)coder{
    if (self = [super initWithCoder:coder]) {
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5 && [self dividerStyle] == NSSplitViewDividerStyleThick)
            [self setDividerStyle:3]; // NSSplitViewDividerStylePaneSplitter
    }
    return self;
}

- (void)drawDividerInRect:(NSRect)aRect {
	if ([self dividerStyle] == NSSplitViewDividerStyleThick) {
        NSRect topRect, bottomRect, innerRect;
        NSDivideRect(aRect, &topRect, &innerRect, 1.0, NSMaxYEdge);
        NSDivideRect(innerRect, &bottomRect, &innerRect, 1.0, NSMinYEdge);
        
        [NSGraphicsContext saveGraphicsState];
        NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithDeviceWhite:0.98 alpha:1.0] endingColor:[NSColor colorWithDeviceWhite:0.91 alpha:1.0]] autorelease];
        [gradient drawInRect:innerRect angle:90.0];
        [[NSColor colorWithDeviceWhite:0.69 alpha:1.0] setFill];
        NSRectFill(topRect);
        NSRectFill(bottomRect);
        [NSGraphicsContext restoreGraphicsState];
    }
    [super drawDividerInRect:aRect];
}

- (CGFloat)dividerThickness {
	if ([self dividerStyle] == NSSplitViewDividerStyleThick)
        return 10.0;
    return [super dividerThickness];
}

- (void)adjustSubviews {
    [super adjustSubviews];
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_5)
        [self resetCursorRects];
}

- (void)endAnimation:(NSDictionary *)info {
    [self setPosition:[[info objectForKey:@"position"] doubleValue] ofDividerAtIndex:[[info objectForKey:@"dividerIndex"] integerValue]];
    animating = NO;
}

- (void)setPosition:(CGFloat)position ofDividerAtIndex:(NSInteger)dividerIndex animate:(BOOL)animate {
    NSTimeInterval duration = [NSViewAnimation defaultAnimationTimeInterval];
    
    if (animating) {
        return;
    } else if (animate == NO || duration <= 0.0) {
        [self setPosition:position ofDividerAtIndex:dividerIndex];
        return;
    }
    
    NSView *view1 = [[self subviews] objectAtIndex:dividerIndex];
    NSView *view2 = [[self subviews] objectAtIndex:dividerIndex + 1];
    NSSize size1 = [view1 frame].size;
    NSSize size2 = [view2 frame].size;
    BOOL collapsed1 = [self isSubviewCollapsed:view1];
    BOOL collapsed2 = [self isSubviewCollapsed:view2];
    CGFloat min = [self minPossiblePositionOfDividerAtIndex:dividerIndex];
    CGFloat thickness = [self dividerThickness];
    BOOL canHide = [[self delegate] respondsToSelector:@selector(splitView:shouldHideDividerAtIndex:)] &&
                   [[self delegate] splitView:self shouldHideDividerAtIndex:dividerIndex];
    
    if (collapsed1 && collapsed2)
        return;
    
    if (canHide) {
        // on 10.5 minPossiblePositionOfDividerAtIndex may wrongly return 0 for the first divider when it can hide
        if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_5 && dividerIndex == 0)
            min = -[self dividerThickness];
        min += thickness;
    }
    
    if ([self isVertical]) {
        if (collapsed1) {
            size1.width = 0.0;
            if (canHide) {
                size2.width -= thickness;
                if (size2.width < 0.0) {
                    size1.width += size2.width;
                    size2.width = 0.0;
                    if (size1.width < 0.0) {
                        [self setPosition:position ofDividerAtIndex:dividerIndex];
                        return;
                    }
                }
            }
            [view1 setFrameSize:size1];
            [view2 setFrameSize:size2];
            [view1 setHidden:NO];
        } else if (collapsed2) {
            size2.width = 0.0;
            if (canHide) {
                size1.width -= thickness;
                if (size1.width < 0.0) {
                    size2.width += size1.width;
                    size1.width = 0.0;
                    if (size2.width < 0.0) {
                        [self setPosition:position ofDividerAtIndex:dividerIndex];
                        return;
                    }
                }
            }
            [view1 setFrameSize:size1];
            [view2 setFrameSize:size2];
            [view2 setHidden:NO];
        }
        size2.width -= position - min - size1.width;
        size1.width = position - min;
        if (size2.width < 0.0) {
            size1.width += size2.width;
            size2.width = 0.0;
        }
        if (size1.width < 0.0) {
            size2.width += size1.width;
            size1.width = 0.0;
        }
    } else {
        if ((collapsed1 || collapsed2) && canHide && size1.height + size2.height < thickness) {
            [self setPosition:position ofDividerAtIndex:dividerIndex];
            return;
        }
        if (collapsed1) {
            size1.height = 0.0;
            if (canHide) {
                size2.height -= thickness;
                if (size2.height < 0.0) {
                    size1.height += size2.height;
                    size2.height = 0.0;
                    if (size1.height < 0.0) {
                        [self setPosition:position ofDividerAtIndex:dividerIndex];
                        return;
                    }
                }
            }
            [view1 setFrameSize:size1];
            [view2 setFrameSize:size2];
            [view1 setHidden:NO];
        } else if (collapsed2) {
            size2.height = 0.0;
            if (canHide) {
                size1.height -= thickness;
                if (size1.height < 0.0) {
                    size2.height += size1.height;
                    size1.height = 0.0;
                    if (size2.height < 0.0) {
                        [self setPosition:position ofDividerAtIndex:dividerIndex];
                        return;
                    }
                }
            }
            [view1 setFrameSize:size1];
            [view2 setFrameSize:size2];
            [view2 setHidden:NO];
        }
        size2.height -= position - min - size1.height;
        size1.height = position - min;
        if (size2.height < 0.0) {
            size1.height += size2.height;
            size2.height = 0.0;
        }
        if (size1.height < 0.0) {
            size2.height += size1.height;
            size1.height = 0.0;
        }
    }
    
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:position], @"position", [NSNumber numberWithInteger:dividerIndex], @"dividerIndex", nil];
    
    animating = YES;
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:duration];
    [[view1 animator] setFrameSize:size1];
    [[view2 animator] setFrameSize:size2];
    [NSAnimationContext endGrouping];
    
    [self performSelector:@selector(endAnimation:) withObject:info afterDelay:duration]; 
}

@end
