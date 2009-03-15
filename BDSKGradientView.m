//
//  BDSKGradientView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/26/05.
/*
 This software is Copyright (c) 2005-2009
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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
/*
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BDSKGradientView.h"
#import "NSBezierPath_CoreImageExtensions.h"
#import "CIImage_BDSKExtensions.h"

@interface BDSKGradientView (Private)

- (void)setDefaultColors;

@end

@implementation BDSKGradientView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
        [self setDefaultColors];
    layer = NULL;
    return self;
}

- (void)dealloc
{
    CGLayerRelease(layer);
    [lowerColor release];
    [upperColor release];
    [super dealloc];
}

- (void)setBounds:(NSRect)aRect
{
    // since the gradient is vertical, we only have to reset the layer if the height changes; for most of our gradient views, this isn't likely to happen
    if (ABS(NSHeight(aRect) - NSHeight([self bounds])) > 0.01) {
        CGLayerRelease(layer);
        layer = NULL;
    }
    [super setBounds:aRect];
}

- (void)setBoundsSize:(NSSize)aSize
{
    // since the gradient is vertical, we only have to reset the layer if the height changes; for most of our gradient views, this isn't likely to happen
    if (ABS(aSize.height - NSHeight([self bounds])) > 0.01) {
        CGLayerRelease(layer);
        layer = NULL;
    }
    [super setBoundsSize:aSize];
}

- (void)setFrame:(NSRect)aRect
{
    // since the gradient is vertical, we only have to reset the layer if the height changes; for most of our gradient views, this isn't likely to happen
    if (ABS(NSHeight(aRect) - NSHeight([self frame])) > 0.01) {
        CGLayerRelease(layer);
        layer = NULL;
    }
    [super setFrame:aRect];
}

- (void)setFrameSize:(NSSize)aSize
{
    // since the gradient is vertical, we only have to reset the layer if the height changes; for most of our gradient views, this isn't likely to happen
    if (ABS(aSize.height - NSHeight([self frame])) > 0.01) {
        CGLayerRelease(layer);
        layer = NULL;
    }
    [super setFrameSize:aSize];
}

// fill entire view, not just the (possibly clipped) aRect

- (void)drawRect:(NSRect)aRect
{
    CGContextRef viewContext = [[NSGraphicsContext currentContext] graphicsPort];
    NSRect bounds = [self bounds];
    
    // see bug #1834337; drawing the status bar gradient is apparently really expensive on some hardware
    // suggestion from Scott Thompson on quartz-dev was to use a CGLayer; based on docs, this should be a good win
    if (NULL == layer) {
        NSSize layerSize = bounds.size;
        layer = CGLayerCreateWithContext(viewContext, NSSizeToCGSize(layerSize), NULL);
        
        CGContextRef layerContext = CGLayerGetContext(layer);
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:layerContext flipped:NO]];
        NSRect layerRect = NSZeroRect;
        layerRect.size = layerSize;
                
                [[NSBezierPath bezierPathWithRect:bounds] fillPathVerticallyWithStartColor:[self lowerColor] endColor:[self upperColor]];
        [NSGraphicsContext restoreGraphicsState];
    }
    
    // normal blend mode is copy
    CGContextSetBlendMode(viewContext, kCGBlendModeNormal);
    CGContextDrawLayerInRect(viewContext, NSRectToCGRect(bounds), layer);
}

// -[CIColor initWithColor:] fails (returns nil) with +[NSColor gridColor] rdar://problem/4789043
- (void)setLowerColor:(NSColor *)color
{
    [lowerColor autorelease];
    lowerColor = [[CIColor colorWithNSColor:color] retain];
}

- (void)setUpperColor:(NSColor *)color
{
    [upperColor autorelease];
    upperColor = [[CIColor colorWithNSColor:color] retain];
}    

- (CIColor *)lowerColor { return lowerColor; }
- (CIColor *)upperColor { return upperColor; }

// required in order for redisplay to work properly with the controls
- (BOOL)isOpaque{  return YES; }
- (BOOL)isFlipped { return NO; }

@end

@implementation BDSKGradientView (Private)

// provides an example implementation
- (void)setDefaultColors
{
    [self setLowerColor:[NSColor colorWithCalibratedWhite:0.65 alpha:1.0]];
    [self setUpperColor:[NSColor colorWithCalibratedWhite:0.8 alpha:1.0]];
}

@end
