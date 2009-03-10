//
//  BDSKFilePathCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/10/09.
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

#import "BDSKFilePathCell.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"


@implementation BDSKFilePathCell

static BDSKFilePathFormatter *filePathFormatter = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    
    filePathFormatter = [[BDSKFilePathFormatter alloc] init];
}

- (id)init {
    if (self = [super initTextCell:@""]) {
        [self setEditable:YES];
        [self setScrollable:YES];
        [self setLineBreakMode:NSLineBreakByTruncatingMiddle];
        [self setFormatter:filePathFormatter];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        if ([self formatter] == nil)
            [self setFormatter:filePathFormatter];
    }
    return self;
}

- (void)dealloc {
    [icon release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
    BDSKFilePathCell *copy = [super copyWithZone:zone];
    copy->icon = [icon retain];
    return copy;
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

#define BORDER_BETWEEN_EDGE_AND_IMAGE (1.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT (0.0)
#define IMAGE_OFFSET (1.0)

- (NSSize)cellSize {
    NSSize cellSize = [super cellSize];
    cellSize.width += cellSize.height + BORDER_BETWEEN_EDGE_AND_IMAGE + BORDER_BETWEEN_IMAGE_AND_TEXT;
    return cellSize;
}

- (void)drawIconWithFrame:(NSRect)iconRect inView:(NSView *)controlView {
    NSImage *img = [self icon];
    
    if (nil != img) {
        
        NSRect srcRect = NSZeroRect;
        srcRect.size = [img size];
        
        NSRect drawFrame = iconRect;
        float ratio = MIN(NSWidth(drawFrame) / srcRect.size.width, NSHeight(drawFrame) / srcRect.size.height);
        drawFrame.size.width = ratio * srcRect.size.width;
        drawFrame.size.height = ratio * srcRect.size.height;
        
        drawFrame = BDSKCenterRect(drawFrame, drawFrame.size, [controlView isFlipped]);
        
        NSGraphicsContext *ctxt = [NSGraphicsContext currentContext];
        [ctxt saveGraphicsState];
        
        // this is the critical part that NSImageCell doesn't do
        [ctxt setImageInterpolation:NSImageInterpolationHigh];
        
        [img drawFlipped:[controlView isFlipped] inRect:drawFrame fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
        
        [ctxt restoreGraphicsState];
    }
}

- (NSRect)textRectForBounds:(NSRect)aRect {
    float imageWidth = NSHeight(aRect) - 1;
    NSRect ignored, textRect = aRect;
    
    NSDivideRect(aRect, &ignored, &textRect, BORDER_BETWEEN_EDGE_AND_IMAGE + imageWidth + BORDER_BETWEEN_IMAGE_AND_TEXT, NSMinXEdge);
    
    return textRect;
}

- (NSRect)iconRectForBounds:(NSRect)aRect {
    float imageWidth = NSHeight(aRect) - 1;
    NSRect ignored, imageRect = aRect;
    
    NSDivideRect(aRect, &ignored, &imageRect, BORDER_BETWEEN_EDGE_AND_IMAGE, NSMinXEdge);
    NSDivideRect(imageRect, &imageRect, &ignored, imageWidth, NSMinXEdge);
    
    return imageRect;
}

- (void)drawWithFrame:(NSRect)aRect inView:(NSView *)controlView {
    // let super draw the text, but vertically center the text for tall cells, because NSTextFieldCell aligns at the top
    NSRect textRect = [self textRectForBounds:aRect];
    if (NSHeight(textRect) > [self cellSize].height + 2.0)
        textRect = BDSKCenterRectVertically(textRect, [self cellSize].height + 2.0, [controlView isFlipped]);
    [super drawWithFrame:textRect inView:controlView];
    
    // Draw the image
    NSRect imageRect = [self iconRectForBounds:aRect];
    float imageHeight = NSHeight(aRect) - 1;
    imageRect = BDSKCenterRectVertically(imageRect, imageHeight, [controlView isFlipped]);
    imageRect.origin.y += [controlView isFlipped] ? -IMAGE_OFFSET : IMAGE_OFFSET;
    [self drawIconWithFrame:imageRect inView:controlView];
}

- (NSImage *)icon {
    return icon;
}

- (void)setIcon:(NSImage *)newIcon {
    if (newIcon != icon) {
        [icon release];
        icon = [newIcon retain];
    }
}

- (void)setObjectValue:(id <NSCopying>)obj {
    [super setObjectValue:obj];
    
    NSImage *image = nil;
    if ([(id)obj isKindOfClass:[NSString class]]) {
        NSString *path = [(NSString *)obj stringByStandardizingPath];
        if(path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            image = [NSImage imageForFile:path];
    } else if ([(id)obj isKindOfClass:[NSURL class]]) {
        NSURL *fileURL = (NSURL *)obj;
        if([[NSFileManager defaultManager] objectExistsAtFileURL:fileURL])
            image = [NSImage imageForURL:fileURL];
    }
    [self setIcon:image];
}

@end

#pragma mark -

@implementation BDSKFilePathFormatter

- (NSString *)stringForObjectValue:(id)obj {
    NSString *path = [obj isKindOfClass:[NSURL class]] ? [obj path] : [obj description];
    return [path stringByAbbreviatingWithTildeInPath];
}

// this won't be used because we never edit in this cell type
- (NSString *)editingStringForObjectValue:(id)obj {
    return [obj isKindOfClass:[NSURL class]] ? [obj path] : [obj description];
}

// this won't be used because we never edit in this cell type
- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error {
    *obj = [string stringByExpandingTildeInPath];
    return YES;
}

@end
