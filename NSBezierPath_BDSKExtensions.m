//
//  NSBezierPath_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/22/05.
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

#import "NSBezierPath_BDSKExtensions.h"


@implementation NSBezierPath (BDSKExtensions)

+ (void)drawHighlightInRect:(NSRect)rect radius:(CGFloat)radius lineWidth:(CGFloat)lineWidth color:(NSColor *)color
{
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5 * lineWidth, 0.5 * lineWidth) xRadius:radius yRadius:radius];
    [path setLineWidth:lineWidth];
    [[color colorWithAlphaComponent:0.2] setFill];
    [[color colorWithAlphaComponent:0.8] setStroke];
    [path fill];
    [path stroke];
}

+ (void)fillHorizontalOvalInRect:(NSRect)rect
{
    NSBezierPath *p = [self bezierPathWithHorizontalOvalInRect:rect];
    [p fill];
}


+ (void)strokeHorizontalOvalInRect:(NSRect)rect
{
    NSBezierPath *p = [self bezierPathWithHorizontalOvalInRect:rect];
    [p stroke];
}

+ (NSBezierPath*)bezierPathWithHorizontalOvalInRect:(NSRect)rect
{
    BDSKASSERT([NSThread isMainThread]);
    BDSKPRECONDITION(NSWidth(rect) >= NSHeight(rect));
    
    CGFloat radius = 0.5f * NSHeight(rect);
    NSBezierPath *path = [self bezierPath];
    
    [path removeAllPoints];
    
    // Now draw our rectangle:
    [path moveToPoint: NSMakePoint(NSMinX(rect) + radius, NSMaxY(rect))];
    
    // Left half circle:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect) + radius, NSMidY(rect)) radius:radius startAngle:90.0 endAngle:270.0];
    // Bottom edge and right half circle:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect) - radius, NSMidY(rect)) radius:radius startAngle:-90.0 endAngle:90.0];
    // Top edge:
    [path closePath];
    
    return path;
}

+ (void)fillStarInRect:(NSRect)rect{
    [[self bezierPathWithStarInRect:rect] fill];
}

+ (void)fillInvertedStarInRect:(NSRect)rect{
    [[self bezierPathWithInvertedStarInRect:rect] fill];
}

+ (NSBezierPath *)bezierPathWithStarInRect:(NSRect)rect{
    CGFloat centerX = NSMidX(rect);
    CGFloat centerY = NSMidY(rect);
    CGFloat radiusX = 0.5 * NSWidth(rect);
    CGFloat radiusY = 0.5 * NSHeight(rect);
    NSInteger i = 0;
    NSBezierPath *path = [self bezierPath];
    
    [path removeAllPoints];
    
    [path moveToPoint: NSMakePoint(NSMidX(rect), NSMaxY(rect))];
    while(++i < 5)
        [path lineToPoint:NSMakePoint(centerX + sin(0.8 * M_PI * i) * radiusX, centerY + cos(0.8 * M_PI * i) * radiusY)];
    [path closePath];
    
    return path;
}

+ (NSBezierPath *)bezierPathWithInvertedStarInRect:(NSRect)rect{
    CGFloat centerX = NSMidX(rect);
    CGFloat centerY = NSMidY(rect);
    CGFloat radiusX = 0.5 * NSWidth(rect);
    CGFloat radiusY = 0.5 * NSHeight(rect);
    NSInteger i;
    NSBezierPath *path = [self bezierPath];
    
    [path removeAllPoints];
    
    [path moveToPoint:NSMakePoint(NSMidX(rect), NSMinY(rect))];
    for(i = 1; i < 5; i++)
        [path lineToPoint:NSMakePoint(centerX + sinf(0.8 * M_PI * i) * radiusX, centerY - cosf(0.8 * M_PI * i) * radiusY)];
    [path closePath];
    
    return path;
}

@end

