//
//  BDSKGradientSegmentedControl.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/4/08.
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

#import "BDSKGradientSegmentedControl.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSBezierPath_CoreImageExtensions.h"
#import "CIImage_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"


#define SEGMENTED_CONTROL_HEIGHT 20.0
#define SEGMENTED_CONTROL_MARGIN 2.0


@implementation BDSKGradientSegmentedControl

+ (Class)cellClass {
    return [BDSKGradientSegmentedCell class];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if ([super initWithCoder:decoder]) {
        if ([[self cell] isKindOfClass:[[self class] cellClass]] == NO) {
            id cell = [[[[[self class] cellClass] alloc] init] autorelease];
            id oldCell = [self cell];
            unsigned int i, count = [self segmentCount];
            
            [cell setSegmentCount:count];
            [cell setTrackingMode:[oldCell trackingMode]];
            [cell setAction:[oldCell action]];
            [cell setTarget:[oldCell target]];
            [cell setTag:[oldCell tag]];
            [cell setEnabled:[oldCell isEnabled]];
            [cell setBezeled:NO];
            [cell setBordered:NO];
            
            for (i = 0; i < count; i++) {
                [cell setWidth:[oldCell widthForSegment:i] forSegment:i];
                [cell setImage:[oldCell imageForSegment:i] forSegment:i];
                [cell setLabel:[oldCell labelForSegment:i] forSegment:i];
                [cell setToolTip:[oldCell toolTipForSegment:i] forSegment:i];
                [cell setEnabled:[oldCell isEnabledForSegment:i] forSegment:i];
                [cell setSelected:[oldCell isSelectedForSegment:i] forSegment:i];
                [cell setMenu:[oldCell menuForSegment:i] forSegment:i];
                [cell setTag:[oldCell tagForSegment:i] forSegment:i];
            }
            
            [self setCell:cell];
        }
        NSRect frame = [self frame];
        frame.size.height = SEGMENTED_CONTROL_HEIGHT;
        [self setFrame:frame];
    }
    return self;
}

- (void)setFrame:(NSRect)newFrame {
    newFrame.size.height = SEGMENTED_CONTROL_HEIGHT;
    [super setFrame:newFrame];
}

- (void)setFrameSize:(NSSize)newFrameSize {
    newFrameSize.height = SEGMENTED_CONTROL_HEIGHT;
    [super setFrameSize:newFrameSize];
}

@end



@interface NSSegmentedCell (BDSKApplePrivateDeclarations)
- (int)_trackingSegment;
- (NSRect)_boundsForCellFrame:(NSRect)frame;
@end

@implementation BDSKGradientSegmentedCell

- (void)dealloc {
    if (layer != NULL)
        CGLayerRelease(layer);
    if (selectedLayer != NULL)
        CGLayerRelease(selectedLayer);
    if (highlightedLayer != NULL)
        CGLayerRelease(highlightedLayer);
    [super dealloc];
}

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView {
    NSRect rect = NSInsetRect(frame, SEGMENTED_CONTROL_MARGIN, 0.0);
    NSUInteger i, count = [self segmentCount];
    
    [NSGraphicsContext saveGraphicsState];
    [[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] setFill];
    NSRectFill(rect);
    [NSGraphicsContext restoreGraphicsState];
    
    rect = NSInsetRect(rect, 1.0, 0.0);
    for (i = 0; i < count; i++) {
        rect.size.width = [self widthForSegment:i];
        [self drawSegment:i inFrame:rect withView:controlView];
        rect.origin.x = NSMaxX(rect) + 1.0;
    }
}


- (void)drawSegment:(NSInteger)segment inFrame:(NSRect)frame withView:(NSView *)controlView {
    CGContextRef viewContext = [[NSGraphicsContext currentContext] graphicsPort];
    
    // see bug #1834337; drawing the status bar gradient is apparently really expensive on some hardware
    // suggestion from Scott Thompson on quartz-dev was to use a CGLayer; based on docs, this should be a good win
    if (NULL == layer || NULL == selectedLayer || NULL == highlightedLayer) {
        NSSize layerSize = NSMakeSize(1.0, SEGMENTED_CONTROL_HEIGHT);
        NSRect layerRect = {NSZeroPoint, layerSize};
        CGContextRef layerContext;
        CIColor *startColor;
        CIColor *endColor;
        
        layer = CGLayerCreateWithContext(viewContext, *(CGSize *)&layerSize, NULL);
        selectedLayer = CGLayerCreateWithContext(viewContext, *(CGSize *)&layerSize, NULL);
        highlightedLayer = CGLayerCreateWithContext(viewContext, *(CGSize *)&layerSize, NULL);
        
        if ([controlView isFlipped]) {
            startColor = [CIColor colorWithWhite:0.9];
            endColor = [CIColor colorWithWhite:0.75];
        } else {
            startColor = [CIColor colorWithWhite:0.75];
            endColor = [CIColor colorWithWhite:0.9];
        }
        
        layerContext = CGLayerGetContext(layer);
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:layerContext flipped:NO]];
        [[NSBezierPath bezierPathWithRect:layerRect] fillPathVerticallyWithStartColor:startColor endColor:endColor];
        [NSGraphicsContext restoreGraphicsState];
        
        if ([controlView isFlipped]) {
            startColor = [CIColor colorWithWhite:0.7];
            endColor = [CIColor colorWithWhite:0.55];
        } else {
            startColor = [CIColor colorWithWhite:0.55];
            endColor = [CIColor colorWithWhite:0.7];
        }
        
        layerContext = CGLayerGetContext(selectedLayer);
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:layerContext flipped:NO]];
        [[NSBezierPath bezierPathWithRect:layerRect] fillPathVerticallyWithStartColor:startColor endColor:endColor];
        [NSGraphicsContext restoreGraphicsState];
        
        if ([controlView isFlipped]) {
            startColor = [CIColor colorWithWhite:0.45];
            endColor = [CIColor colorWithWhite:0.6];
        } else {
            startColor = [CIColor colorWithWhite:0.6];
            endColor = [CIColor colorWithWhite:0.45];
        }
        
        layerContext = CGLayerGetContext(highlightedLayer);
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:layerContext flipped:NO]];
        [[NSBezierPath bezierPathWithRect:layerRect] fillPathVerticallyWithStartColor:startColor endColor:endColor];
        [NSGraphicsContext restoreGraphicsState];
    }
    
    [NSGraphicsContext saveGraphicsState];
    CGContextSetBlendMode(viewContext, kCGBlendModeNormal);
    CGContextDrawLayerInRect(viewContext, *(CGRect *)&frame, [self _trackingSegment] == segment ? highlightedLayer : [self isSelectedForSegment:segment] ? selectedLayer : layer);
    [NSGraphicsContext restoreGraphicsState];
    
    NSImage *image = [self imageForSegment:segment];
    NSRect rect = BDSKCenterRect(frame, [image size], [controlView isFlipped]);
    NSRect fromRect = NSZeroRect;
    CGFloat f = [self isEnabledForSegment:segment] ? 1.0 : 0.5;
    fromRect.size = [image size];
    if ([controlView isFlipped])
        [image drawFlippedInRect:rect fromRect:fromRect operation:NSCompositeSourceOver fraction:f];
    else
        [image drawInRect:rect fromRect:fromRect operation:NSCompositeSourceOver fraction:f];
    
    if ([self menuForSegment:segment]) {
        CGFloat x = NSMaxX(frame) - 2.0;
        CGFloat z = -3.0, y = NSMidY(frame);
        
        if ([controlView isFlipped]) {
            y = ceil(y) + 1.0;
            z = 3.0;
        } else {
            y = floor(y) - 1.0;
        }
        
        NSBezierPath *arrowPath = [NSBezierPath bezierPath];
        [arrowPath moveToPoint:NSMakePoint(x, y)];
        [arrowPath relativeLineToPoint:NSMakePoint(-5.0, 0.0)];
        [arrowPath relativeLineToPoint:NSMakePoint(2.5, z)];
        [arrowPath closePath];
        
        [NSGraphicsContext saveGraphicsState];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.8 * f] setFill];
        [arrowPath fill];
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (NSRect)_boundsForCellFrame:(NSRect)frame {
    return frame;
}

@end
