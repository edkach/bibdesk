//
//  BDSKGroupCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 26/10/05.
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

#import "BDSKGroupCell.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import "NSParagraphStyle_BDSKExtensions.h"
#import "BDSKCenterScaledImageCell.h"


// names of these globals were changed to support key-value coding on BDSKGroup
NSString *BDSKGroupCellStringKey = @"stringValue";
NSString *BDSKGroupCellEditingStringKey = @"editingStringValue";
NSString *BDSKGroupCellImageKey = @"icon";
NSString *BDSKGroupCellCountKey = @"numberValue";
NSString *BDSKGroupCellIsRetrievingKey = @"isRetrieving";
NSString *BDSKGroupCellFailedDownloadKey = @"failedDownload";

@interface BDSKGroupCellFormatter : NSFormatter
@end

#pragma mark

@implementation BDSKGroupCell

static NSMutableDictionary *numberStringDictionary = nil;
static BDSKGroupCellFormatter *groupCellFormatter = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    numberStringDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"", [NSNumber numberWithInt:0], nil];
    groupCellFormatter = [[BDSKGroupCellFormatter alloc] init];
    
}

- (id)init {
    if (self = [super initTextCell:@""]) {
        [self setEditable:YES];
        [self setScrollable:YES];
        [self setWraps:NO];
        countString = [[NSMutableAttributedString alloc] init];
        [self setFormatter:groupCellFormatter];
    }
    return self;
}

// NSCoding

- (id)initWithCoder:(NSCoder *)coder {
	if (self = [super initWithCoder:coder]) {
        countString = [[NSMutableAttributedString alloc] init];
        if ([self formatter] == nil)
            [self setFormatter:groupCellFormatter];
	}
	return self;
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone {
    BDSKGroupCell *copy = [super copyWithZone:zone];
    copy->countString = [countString mutableCopyWithZone:zone];
    return copy;
}

- (void)dealloc {
    [countString release];
	[super dealloc];
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

- (void)updateCountAttributes {
	NSFont *countFont = [NSFont fontWithName:@"Helvetica-Bold" size:([[self font] pointSize] - 1)] ?: [NSFont boldSystemFontOfSize:([[self font] pointSize] - 1)];
	BDSKPRECONDITION(countFont);     
    [countString addAttribute:NSFontAttributeName value:countFont range:NSMakeRange(0, [countString length])];
    [countString addAttribute:NSKernAttributeName value:[NSNumber numberWithFloat:-1.0] range:NSMakeRange(0, [countString length])];
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self updateCountAttributes];
}

// all the -[NSNumber stringValue] does is create a string with a localized format description, so we'll cache more strings than Foundation does, since this shows up in Shark as a bottleneck
static NSString *stringWithNumber(NSNumber *number)
{
    if (number == nil)
        return @"";
    NSString *string = [numberStringDictionary objectForKey:number];
    if (string == nil) {
        string = [number stringValue];
        [numberStringDictionary setObject:string forKey:number];
    }
    return string;
}

static id nonNullObjectValueForKey(id object, NSString *key) {
    id value = [object valueForKey:key];
    return [value isEqual:[NSNull null]] ? nil : value;
}

- (void)setObjectValue:(id <NSCopying>)obj {
    // we should not set a derived value such as the group name here, otherwise NSTableView will call tableView:setObjectValue:forTableColumn:row: whenever a cell is selected
    
    // this can happen initially from the init, as there's no initializer passing an objectValue
    if ([(id)obj isKindOfClass:[NSString class]])
        obj = [NSDictionary dictionaryWithObjectsAndKeys:obj, BDSKGroupCellStringKey, nil];
    
    [super setObjectValue:obj];
    
    [countString replaceCharactersInRange:NSMakeRange(0, [countString length]) withString:stringWithNumber(nonNullObjectValueForKey(obj, BDSKGroupCellCountKey))];
    [self updateCountAttributes];
}

- (NSImage *)icon {
    return nonNullObjectValueForKey([self objectValue], BDSKGroupCellImageKey);
}

- (int)count {
    return [nonNullObjectValueForKey([self objectValue], BDSKGroupCellCountKey) intValue];
}

- (BOOL)isRetrieving {
    return [nonNullObjectValueForKey([self objectValue], BDSKGroupCellIsRetrievingKey) boolValue];
}

- (BOOL)failedDownload {
    return [nonNullObjectValueForKey([self objectValue], BDSKGroupCellFailedDownloadKey) boolValue];
}

#pragma mark Drawing

#define BORDER_BETWEEN_EDGE_AND_IMAGE (3.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT (3.0)
#define BORDER_BETWEEN_EDGE_AND_COUNT (2.0)
#define BORDER_BETWEEN_COUNT_AND_TEXT (1.0)
#define TEXT_INSET                    (2.0)
#define IMAGE_SIZE_OFFSET             (2.0)

- (NSSize)iconSizeForBounds:(NSRect)aRect {
    return NSMakeSize(NSHeight(aRect) - IMAGE_SIZE_OFFSET, NSHeight(aRect) - IMAGE_SIZE_OFFSET);
}

- (NSRect)iconRectForBounds:(NSRect)aRect {
    NSSize imageSize = [self iconSizeForBounds:aRect];
    NSRect imageRect, ignored;
    NSDivideRect(aRect, &ignored, &imageRect, BORDER_BETWEEN_EDGE_AND_IMAGE, NSMinXEdge);
    NSDivideRect(imageRect, &imageRect, &ignored, imageSize.width, NSMinXEdge);
    return imageRect;
}

- (NSRect)countRectForBounds:(NSRect)aRect {
    NSSize countSize = NSZeroSize;
    
    if ([self isRetrieving]) {
        countSize = NSMakeSize(16.0, 16.0);
    } else if ([self failedDownload]) {
        countSize = [self iconSizeForBounds:aRect];
    } else if ([self count] > 0) {
        countSize = [countString boundingRectWithSize:aRect.size options:0].size;
        countSize.width += [self count] < 100 ? countSize.height : 0.5 * countSize.height; // add oval pading around count
    }
    NSRect countRect, ignored;
    if (countSize.width > 0.0) {
        NSDivideRect(aRect, &ignored, &countRect, BORDER_BETWEEN_EDGE_AND_COUNT, NSMaxXEdge);
        NSDivideRect(countRect, &countRect, &ignored, countSize.width, NSMaxXEdge);
        // now set the size of it to the string size
        countRect = BDSKCenterRect(countRect, countSize, YES);
    } else {
        NSDivideRect(aRect, &countRect, &ignored, 0.0, NSMaxXEdge);
    }
    return countRect;
}    

- (NSRect)textRectForBounds:(NSRect)aRect {
    NSRect textRect = aRect, countRect = [self countRectForBounds:aRect];
    textRect.origin.x = NSMaxX([self iconRectForBounds:aRect]) + BORDER_BETWEEN_IMAGE_AND_TEXT;
    if (NSWidth(countRect) > 0.0)
        textRect.size.width = NSMinX(countRect) - BORDER_BETWEEN_COUNT_AND_TEXT - NSMinX(textRect);
    else
        textRect.size.width = NSMaxX(aRect) - NSMinX(textRect);
    return NSInsetRect(textRect, 0.0, TEXT_INSET);
}

- (NSSize)cellSize {
    NSSize cellSize = [super cellSize];
    NSSize countSize = NSZeroSize;
    if ([self isRetrieving] || [self failedDownload]) {
        countSize = NSMakeSize(16, 16);
    } else if ([self count] > 0) {
        countSize = [countString boundingRectWithSize:cellSize options:0].size;
        countSize.width += [self count] < 100 ? countSize.height : 0.5 * countSize.height; // add oval pading around count
    }
    // cellSize.height approximates the icon size
    cellSize.width += BORDER_BETWEEN_EDGE_AND_IMAGE + cellSize.height + BORDER_BETWEEN_IMAGE_AND_TEXT;
    if (countSize.width > 0.0)
        cellSize.width += BORDER_BETWEEN_COUNT_AND_TEXT + countSize.width + BORDER_BETWEEN_EDGE_AND_COUNT;
    return cellSize;
}

- (NSColor *)textColor {
    if ([self respondsToSelector:@selector(backgroundStyle)] == NO) {
        if (settingUpFieldEditor)
            return [NSColor blackColor];
        else if ([self isHighlighted])
            return [NSColor textBackgroundColor];
    }
    return [super textColor];
}

- (void)drawInteriorWithFrame:(NSRect)aRect inView:(NSView *)controlView {
    BOOL isHighlighted;
    if ([self respondsToSelector:@selector(backgroundStyle)])
        isHighlighted = ([self backgroundStyle] == NSBackgroundStyleDark || [self backgroundStyle] == NSBackgroundStyleLowered);
    else
        isHighlighted = [self isHighlighted];
    
    // Draw the text
    NSRect textRect = [self textRectForBounds:aRect]; 
    NSFont *font = nil;
    NSAttributedString *label = [self attributedStringValue];
    if (isHighlighted) {
        // source list draws selected text bold, but only when the passing an NSString to setObjectValue:
        font = [[self font] retain];
        [super setFont:[[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask]];
    }
    [super drawInteriorWithFrame:textRect inView:controlView];
    if (font) {
        [super setFont:font];
        [font release];
    }
    
    // Draw the count bubble or caution icon, when we're retrieving we don't draw to leave space for the spinner
    if ([self isRetrieving] == NO) {
        NSRect countRect = [self countRectForBounds:aRect];
        int count = [self count];
        if ([self failedDownload]) {
            [self drawIcon:[NSImage imageNamed:@"BDSKSmallCautionIcon"] withFrame:countRect inView:controlView];
        } else if (count > 0) {
            float countInset = count < 100 ? 0.5 * NSHeight(countRect) : 0.25 * NSHeight(countRect);
            NSColor *fgColor;
            NSColor *bgColor;
            if ([controlView respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
                // On Leopard, use the blue or gray color taken from the center of the gradient highlight
                if ([[controlView window] isMainWindow] == NO) {
                    if (isHighlighted) {
                        fgColor = [NSColor colorWithDeviceRed:40606.0/65535.0 green:40606.0/65535.0 blue:40606.0/65535.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.95];
                    } else {
                        fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceRed:40606.0/65535.0 green:40606.0/65535.0 blue:40606.0/65535.0 alpha:0.95];
                    }
                } else if ([[controlView window] isKeyWindow] && [[controlView window] firstResponder] == controlView) {
                    if (isHighlighted) {
                        fgColor = [NSColor colorWithDeviceRed:14135.0/65535.0 green:29298.0/65535.0 blue:48830.0/65535.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.95];
                    } else {
                        fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceRed:34695.0/65535.0 green:39064.0/65535.0 blue:48316.0/65535.0 alpha:0.95];
                    }
                } else {
                    if (isHighlighted) {
                        fgColor = [NSColor colorWithDeviceRed:34695.0/65535.0 green:39064.0/65535.0 blue:48316.0/65535.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.95];
                    } else {
                        fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceRed:34695.0/65535.0 green:39064.0/65535.0 blue:48316.0/65535.0 alpha:0.95];
                    }
                }
            } else {
                // On Tiger use gray
                if (isHighlighted) {
                    fgColor = [NSColor disabledControlTextColor];
                    bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.8];
                } else {
                    fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                    bgColor = [[NSColor disabledControlTextColor] colorWithAlphaComponent:0.7];
                }
            }
            
            [NSGraphicsContext saveGraphicsState];
            [bgColor setFill];
            [NSBezierPath fillHorizontalOvalInRect:countRect];
            [NSGraphicsContext restoreGraphicsState];
            
            [countString addAttribute:NSForegroundColorAttributeName value:fgColor range:NSMakeRange(0, [countString length])];
            [countString drawWithRect:NSInsetRect(countRect, countInset, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
        }
    }
    
    // Draw the image
    NSRect imageRect = BDSKCenterRect([self iconRectForBounds:aRect], [self iconSizeForBounds:aRect], [controlView isFlipped]);
    if ([self icon])
        [self drawIcon:[self icon] withFrame:imageRect inView:controlView];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength {
    settingUpFieldEditor = YES;
    [super selectWithFrame:[self textRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
    settingUpFieldEditor = NO;
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView {
    NSRect textRect = [self textRectForBounds:cellFrame];
    NSPoint mouseLoc = [controlView convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger hit = NSCellHitNone;
    if (NSMouseInRect(mouseLoc, textRect, [controlView isFlipped]))
        hit = [super hitTestForEvent:event inRect:textRect ofView:controlView];
    else if (NSMouseInRect(mouseLoc, [self iconRectForBounds:cellFrame], [controlView isFlipped]))
        hit = NSCellHitContentArea;
    return hit;
}

@end

#pragma mark -

@implementation BDSKGroupCellFormatter

// this is actually never used, as BDSKGroupCell doesn't go through the formatter for display
- (NSString *)stringForObjectValue:(id)obj {
    //BDSKASSERT([obj isKindOfClass:[NSDictionary class]]);
    return [obj isKindOfClass:[NSString class]] ? obj : nonNullObjectValueForKey(obj, BDSKGroupCellStringKey);
}

- (NSString *)editingStringForObjectValue:(id)obj {
    BDSKASSERT([obj isKindOfClass:[NSDictionary class]]);
    return nonNullObjectValueForKey(obj, BDSKGroupCellEditingStringKey) ?: nonNullObjectValueForKey(obj, BDSKGroupCellStringKey);
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error {
    // even though 'string' is reported as immutable, it's actually changed after this method returns and before it's returned by the control!
    string = [[string copy] autorelease];
    *obj = [NSDictionary dictionaryWithObjectsAndKeys:string, BDSKGroupCellStringKey, string, BDSKGroupCellEditingStringKey, nil];
    return YES;
}

@end
