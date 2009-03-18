//
//  NSColor_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/31/09.
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

#import "NSColor_BDSKExtensions.h"


@implementation NSColor (BDSKExtensions)

+ (NSArray *)alternateControlAlternatingRowBackgroundColors {
    static NSArray *altColors = nil;
    if (altColors == nil)
        altColors = [[NSArray alloc] initWithObjects:[NSColor controlBackgroundColor], [NSColor colorWithCalibratedRed:0.934203 green:0.991608 blue:0.953552 alpha:1.0], nil];
    return altColors;
}

+ (NSColor *)sourceListBackgroundColor {
    static NSColor *sourceListBackgroundColor = nil;
    if (sourceListBackgroundColor == nil) {
        if ([NSOutlineView instancesRespondToSelector:@selector(setSelectionHighlightStyle:)]) {
            NSOutlineView *outlineView = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0,0,1,1)];
            [outlineView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
            sourceListBackgroundColor = [[[outlineView backgroundColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace] retain];
            [outlineView release];
        } else {
            // from Mail.app on 10.4
            CGFloat red = (231.0f/255.0f), green = (237.0f/255.0f), blue = (246.0f/255.0f);
            sourceListBackgroundColor = [[[NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0] colorUsingColorSpaceName:NSDeviceRGBColorSpace] retain];
        }
    }
    return sourceListBackgroundColor;
}

typedef union _BDSKRGBAInt {
    struct {
        uint8_t r;
        uint8_t g;
        uint8_t b;
        uint8_t a;
    } rgba;
    uint32_t uintValue;
} BDSKRGBAInt;

+ (NSColor *)colorWithFourByteString:(NSString *)string {
    NSColor *color = nil;
    if ([NSString isEmptyString:string] == NO) {
        BDSKRGBAInt u;
        u.uintValue = CFSwapInt32BigToHost([string unsignedIntValue]);
        color = [NSColor colorWithCalibratedRed:u.rgba.r / 255.0 green:u.rgba.g / 255.0 blue:u.rgba.b / 255.0 alpha:u.rgba.a / 255.0];
    }
    return color;
}

- (id)fourByteStringValue {
    NSString *string = nil;
    NSColor *rgbColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    if (rgbColor) {
        float r = 0.0, g = 0.0, b = 0.0, a = 0.0;
        [rgbColor getRed:&r green:&g blue:&b alpha:&a];
        // store a 32 bit color instead of the floating point values
        BDSKRGBAInt u;
        u.rgba.r = (uint32_t)(r * 255);
        u.rgba.g = (uint32_t)(g * 255);
        u.rgba.b = (uint32_t)(b * 255);
        u.rgba.a = (uint32_t)(a * 255);
        string = [NSString stringWithFormat:@"%u", CFSwapInt32HostToBig(u.uintValue)];
    }
    return string;
}

- (BOOL)isBlackOrWhiteOrTransparentForMargin:(float)margin {
    float r = 0.0, g = 0.0, b = 0.0, a = 0.0;
    [[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
    return ((r > 1.0-margin && g > 1.0-margin && b > 1.0-margin) || (r < margin && g < margin && b < margin) || a < margin);
}

- (NSComparisonResult)colorCompare:(id)other {
    if (NO == [other isKindOfClass:[NSColor class]])
        return NSOrderedAscending;
    float hue1 = 0.0, saturation1 = 0.0, brightness1 = 0.0, alpha1 = 0.0, hue2 = 0.0, saturation2 = 0.0, brightness2 = 0.0, alpha2 = 0.0;
    [[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getHue:&hue1 saturation:&saturation1 brightness:&brightness1 alpha:&alpha1];
    [[other colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getHue:&hue2 saturation:&saturation2 brightness:&brightness2 alpha:&alpha2];
    uint32_t h1 = (uint32_t)(hue1 * 255);
    uint32_t s1 = (uint32_t)(saturation1 * 255);
    uint32_t b1 = (uint32_t)(brightness1 * 255);
    uint32_t a1 = (uint32_t)(alpha1 * 255);
    uint32_t h2 = (uint32_t)(hue2 * 255);
    uint32_t s2 = (uint32_t)(saturation2 * 255);
    uint32_t b2 = (uint32_t)(brightness2 * 255);
    uint32_t a2 = (uint32_t)(alpha2 * 255);
    if (h1 < h2)
        return NSOrderedAscending;
    if (h1 > h2)
        return NSOrderedDescending;
    if (s1 < s2)
        return NSOrderedAscending;
    if (s1 > s2)
        return NSOrderedDescending;
    if (b1 < b2)
        return NSOrderedAscending;
    if (b1 > b2)
        return NSOrderedDescending;
    if (a1 < a2)
        return NSOrderedAscending;
    if (a1 > a2)
        return NSOrderedDescending;
    if (hue1 < hue2)
        return NSOrderedAscending;
    if (hue1 > hue2)
        return NSOrderedDescending;
    if (saturation1 < saturation2)
        return NSOrderedAscending;
    if (saturation1 > saturation2)
        return NSOrderedDescending;
    if (brightness1 < b2)
        return NSOrderedAscending;
    if (brightness1 > brightness2)
        return NSOrderedDescending;
    if (alpha1 < alpha2)
        return NSOrderedAscending;
    if (alpha1 > alpha2)
        return NSOrderedDescending;
    return NSOrderedSame;
}

+ (id)scriptingRgbaColorWithDescriptor:(NSAppleEventDescriptor *)descriptor {
    if ([descriptor numberOfItems] > 0) {
        float red, green, blue, alpha;
        red = green = blue = (float)[[descriptor descriptorAtIndex:1] int32Value] / 65535.0f;
        if ([descriptor numberOfItems] > 2) {
            green = (float)[[descriptor descriptorAtIndex:2] int32Value] / 65535.0f;
            blue = (float)[[descriptor descriptorAtIndex:3] int32Value] / 65535.0f;
        }
        if ([descriptor numberOfItems] == 2)
            alpha = (float)[[descriptor descriptorAtIndex:2] int32Value] / 65535.0f;
        else if ([descriptor numberOfItems] > 3)
            alpha = (float)[[descriptor descriptorAtIndex:4] int32Value] / 65535.0f;
        else
            alpha= 1.0;
        return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
    } else {
        // Cocoa Scripting defines coercions from string to color for some standard color names
        NSString *string = [descriptor stringValue];
        NSColor *color = string ? [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:string toClass:[NSColor class]] : nil;
        // We should check the return value, because NSScriptCoercionHandler returns the input when it fails rather than nil, stupid
        return [color isKindOfClass:[NSColor class]] ? color : nil;
    }
}

- (id)scriptingRgbaColorDescriptor {
    float red, green, blue, alpha;
    [[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:&alpha];
    
    NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor listDescriptor];
    [descriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:round(65535 * red)] atIndex:1];
    [descriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:round(65535 * green)] atIndex:2];
    [descriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:round(65535 * blue)] atIndex:3];
    [descriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:round(65535 * alpha)] atIndex:4];
    
    return descriptor;
}

@end
