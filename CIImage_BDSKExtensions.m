//
//  CIImage_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/7/06.
/*
 This software is Copyright (c) 2005,2006
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

#import "CIImage_BDSKExtensions.h"


@implementation CIImage (BDSKExtensions)

static CIFilter *colorFilter = nil;
static CIFilter *linearFilter = nil;
static CIFilter *gaussianFilter = nil;
static CIFilter *blendFilter = nil;
static CIFilter *gaussianBlurFilter = nil;
static CIFilter *transformFilter = nil;
static CIFilter *cropFilter = nil;

+ (void)load
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    static BOOL alreadyInit = NO;
    if(NO == alreadyInit){
        colorFilter = [[CIFilter filterWithName:@"CIConstantColorGenerator"] retain];    
        linearFilter = [[CIFilter filterWithName:@"CILinearGradient"] retain];    
        gaussianFilter = [[CIFilter filterWithName:@"CIGaussianGradient"] retain];    
        blendFilter = [[CIFilter filterWithName:@"CIBlendWithMask"] retain];    
        gaussianBlurFilter = [[CIFilter filterWithName:@"CIGaussianBlur"] retain];    
        transformFilter = [[CIFilter filterWithName:@"CIAffineTransform"] retain];
        cropFilter = [[CIFilter filterWithName:@"CICrop"] retain];
        alreadyInit = YES;
    }
    [pool release];
}

+ (CIImage *)imageWithConstantColor:(CIColor *)color;
{
    [colorFilter setValue:color forKey:@"inputColor"];
    
    return [colorFilter valueForKey:@"outputImage"];
}

+ (CIImage *)imageInRect:(CGRect)aRect withLinearGradientFromPoint:(CGPoint)startPoint toPoint:(CGPoint)endPoint fromColor:(CIColor *)startColor toColor:(CIColor *)endColor;
{
    [linearFilter setValue:startColor forKey:@"inputColor0"];
    [linearFilter setValue:endColor forKey:@"inputColor1"];
    
    [linearFilter setValue:[CIVector vectorWithX:startPoint.x Y:startPoint.y] forKey:@"inputPoint0"];
    [linearFilter setValue:[CIVector vectorWithX:endPoint.x Y:endPoint.y] forKey:@"inputPoint1"];
    
    return [linearFilter valueForKey:@"outputImage"];
}

+ (CIImage *)imageInRect:(CGRect)aRect withHorizontalGradientFromColor:(CIColor *)startColor toColor:(CIColor *)endColor;
{
    CGPoint startPoint = aRect.origin;
    CGPoint endPoint = startPoint;
    endPoint.x += CGRectGetWidth(aRect);
    return [self imageInRect:aRect withLinearGradientFromPoint:startPoint toPoint:endPoint fromColor:startColor toColor:endColor];
}

+ (CIImage *)imageInRect:(CGRect)aRect withVerticalGradientFromColor:(CIColor *)startColor toColor:(CIColor *)endColor;
{
    CGPoint startPoint = aRect.origin;
    CGPoint endPoint = startPoint;
    endPoint.y += CGRectGetHeight(aRect);
    return [self imageInRect:aRect withLinearGradientFromPoint:startPoint toPoint:endPoint fromColor:startColor toColor:endColor];
}

+ (CIImage *)imageInRect:(CGRect)aRect withHorizontalGradientFromColor:(CIColor *)fgStartColor toColor:(CIColor *)fgEndColor blendedAtTop:(BOOL)top ofVerticalGradientFromColor:(CIColor *)bgStartColor toColor:(CIColor *)bgEndColor;
{
    float radius = CGRectGetWidth(aRect) / 2;
    
    CIVector *centerVector = [CIVector vectorWithX:CGRectGetMidX(aRect) Y:(top ? CGRectGetMaxY(aRect) : CGRectGetMinY(aRect))];
    
    [gaussianFilter setValue:[CIColor colorWithWhite:1.0] forKey:@"inputColor0"];
    [gaussianFilter setValue:[CIColor colorWithWhite:0.0] forKey:@"inputColor1"];
    
    [gaussianFilter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    [gaussianFilter setValue:centerVector forKey:@"inputCenter"];
    
    CIImage *mask = [gaussianFilter valueForKey:@"outputImage"];
    
    CIImage *foreground = [self imageInRect:aRect withHorizontalGradientFromColor:fgStartColor toColor:fgEndColor];
    CIImage *background = [self imageInRect:aRect withVerticalGradientFromColor:bgStartColor toColor:bgEndColor];
    
    return [foreground blendedImageWithBackground:background usingMask:mask];
}

+ (CIImage *)imageInRect:(CGRect)aRect withVerticalGradientFromColor:(CIColor *)fgStartColor toColor:(CIColor *)fgEndColor blendedAtRight:(BOOL)right ofHorizontalGradientFromColor:(CIColor *)bgStartColor toColor:(CIColor *)bgEndColor;
{
    float radius = CGRectGetHeight(aRect) / 2;
    CIVector *centerVector = [CIVector vectorWithX:(right ? CGRectGetMaxX(aRect) : CGRectGetMinX(aRect)) Y:CGRectGetMidY(aRect)];
    
    [gaussianFilter setValue:[CIColor colorWithWhite:1.0] forKey:@"inputColor0"];
    [gaussianFilter setValue:[CIColor colorWithWhite:0.0] forKey:@"inputColor1"];
    
    [gaussianFilter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    [gaussianFilter setValue:centerVector forKey:@"inputCenter"];
    
    CIImage *mask = [gaussianFilter valueForKey:@"outputImage"];
    
    CIImage *foreground = [self imageInRect:aRect withVerticalGradientFromColor:fgStartColor toColor:fgEndColor];
    CIImage *background = [self imageInRect:aRect withHorizontalGradientFromColor:bgStartColor toColor:bgEndColor];
    
    return [foreground blendedImageWithBackground:background usingMask:mask];
}

+ (CIImage *)imageInRect:(CGRect)aRect withColor:(CIColor *)fgColor blendedAtRight:(BOOL)right ofVerticalGradientFromColor:(CIColor *)bgStartColor toColor:(CIColor *)bgEndColor;
{
    float startWhite = right ? 1.0 : 0.0;
    float endWhite = 1.0 - startWhite;
    
    CIImage *foreground = [self imageWithConstantColor:fgColor];
    CIImage *background = [self imageInRect:aRect withVerticalGradientFromColor:bgStartColor toColor:bgEndColor];
    CIImage *mask = [self imageInRect:aRect withHorizontalGradientFromColor:[CIColor colorWithWhite:startWhite] toColor:[CIColor colorWithWhite:endWhite]];
    
    return [foreground blendedImageWithBackground:background usingMask:mask];
}

+ (CIImage *)imageInRect:(CGRect)aRect withColor:(CIColor *)fgColor blendedAtTop:(BOOL)top ofHorizontalGradientFromColor:(CIColor *)bgStartColor toColor:(CIColor *)bgEndColor;
{
    float startWhite = top ? 1.0 : 0.0;
    float endWhite = 1.0 - startWhite;
    
    CIImage *foreground = [self imageWithConstantColor:fgColor];
    CIImage *background = [self imageInRect:aRect withHorizontalGradientFromColor:bgStartColor toColor:bgEndColor];
    CIImage *mask = [self imageInRect:aRect withVerticalGradientFromColor:[CIColor colorWithWhite:startWhite] toColor:[CIColor colorWithWhite:endWhite]];
    
    return [foreground blendedImageWithBackground:background usingMask:mask];
}

- (CIImage *)blendedImageWithBackground:(CIImage *)background usingMask:(CIImage *)mask;
{
    [blendFilter setValue:self forKey:@"inputImage"];
    [blendFilter setValue:background forKey:@"inputBackgroundImage"];
    [blendFilter setValue:mask forKey:@"inputMaskImage"];
    
    return [blendFilter valueForKey:@"outputImage"];
}

- (CIImage *)blurredImageWithBlurRadius:(float)radius;
{
    [gaussianBlurFilter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    [gaussianBlurFilter setValue:self forKey:@"inputImage"];
    
    return [gaussianBlurFilter valueForKey:@"outputImage"];
}

- (CIImage *)croppedImageWithRect:(CGRect)aRect;
{
    CIImage *image = self;
    
    if (CGPointEqualToPoint(aRect.origin, CGPointZero) == NO) {
        // shift the cropped rect to the origin
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:-CGRectGetMinX(aRect) yBy:-CGRectGetMinY(aRect)];
        [transformFilter setValue:transform forKey:@"inputTransform"];
        [transformFilter setValue:self forKey:@"inputImage"];
        
        image = [transformFilter valueForKey:@"outputImage"];
    }
    
    CIVector *cropVector = [CIVector vectorWithX:0 Y:0 Z:CGRectGetWidth(aRect) W:CGRectGetHeight(aRect)];
    
    [cropFilter setValue:cropVector forKey:@"inputRectangle"];
    [cropFilter setValue:image forKey:@"inputImage"];
    
    return [cropFilter valueForKey:@"outputImage"];
}

@end 


@implementation CIColor (BDSKExtensions)

+ (CIColor *)colorWithWhite:(float)white
{
    return [self colorWithRed:white green:white blue:white];
}

+ (CIColor *)colorWithNSColor:(NSColor *)color
{
    color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    return [CIColor colorWithRed:[color redComponent] green:[color greenComponent] blue:[color blueComponent] alpha:[color alphaComponent]];
}

@end
