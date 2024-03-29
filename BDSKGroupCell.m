//
//  BDSKGroupCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 26/10/05.
/*
 This software is Copyright (c) 2005-2012
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
#import "NSGeometry_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import "NSParagraphStyle_BDSKExtensions.h"
#import "NSColor_BDSKExtensions.h"
#import "NSFont_BDSKExtensions.h"


// names of these globals were changed to support key-value coding on BDSKGroup
NSString *BDSKGroupCellStringKey = @"stringValue";
NSString *BDSKGroupCellEditingStringKey = @"editingStringValue";
NSString *BDSKGroupCellLabelKey = @"label";
NSString *BDSKGroupCellImageKey = @"icon";
NSString *BDSKGroupCellCountKey = @"numberValue";
NSString *BDSKGroupCellIsRetrievingKey = @"isRetrieving";
NSString *BDSKGroupCellFailedDownloadKey = @"failedDownload";

#define LABEL_FONTSIZE_OFFSET 2.0

@interface BDSKGroupCellFormatter : NSFormatter
@end

#pragma mark

@implementation BDSKGroupCell

static NSMutableDictionary *numberStringDictionary = nil;
static BDSKGroupCellFormatter *groupCellFormatter = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    numberStringDictionary = [[NSMutableDictionary alloc] init];
    groupCellFormatter = [[BDSKGroupCellFormatter alloc] init];
    
}

- (void)commonInit {
    imageCell = [[NSImageCell alloc] init];
    [imageCell setImageScaling:NSImageScaleProportionallyUpOrDown];
    labelCell = [[NSTextFieldCell alloc] initTextCell:@""];
    [labelCell setFont:[[NSFontManager sharedFontManager] convertFont:[self font] toSize:[[self font] pointSize] - LABEL_FONTSIZE_OFFSET]];
    [labelCell setWraps:NO];
    [labelCell setLineBreakMode:NSLineBreakByClipping];
    countString = [[NSMutableAttributedString alloc] init];
    if ([self formatter] == nil)
        [self setFormatter:groupCellFormatter];
}

- (id)initTextCell:(NSString *)aString {
    self = [super initTextCell:aString];
    if (self) {
        [self setEditable:YES];
        [self setScrollable:YES];
        [self setWraps:NO];
        [self commonInit];
    }
    return self;
}

// NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
	}
	return self;
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone {
    BDSKGroupCell *copy = [super copyWithZone:zone];
    copy->imageCell = [imageCell copyWithZone:zone];
    copy->labelCell = [labelCell copyWithZone:zone];
    copy->countString = [countString mutableCopyWithZone:zone];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(imageCell);
    BDSKDESTROY(labelCell);
    BDSKDESTROY(countString);
	[super dealloc];
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

- (void)updateCountAttributes {
	NSFont *countFont = [NSFont fontWithName:@"Helvetica-Bold" size:[[self font] pointSize]] ?: [NSFont boldSystemFontOfSize:[[self font] pointSize]];
	BDSKPRECONDITION(countFont);     
    [countString addAttribute:NSFontAttributeName value:countFont range:NSMakeRange(0, [countString length])];
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [labelCell setFont:[[NSFontManager sharedFontManager] convertFont:font toSize:[font pointSize] - LABEL_FONTSIZE_OFFSET]];
    [self updateCountAttributes];
}

- (void)setBackgroundStyle:(NSBackgroundStyle)style {
    [super setBackgroundStyle:style];
    [imageCell setBackgroundStyle:style];
    [labelCell setBackgroundStyle:style];
}

// all the -[NSNumber stringValue] does is create a string with a localized format description, so we'll cache more strings than Foundation does, since this shows up in Shark as a bottleneck
static NSString *stringWithNumber(NSNumber *number)
{
    if (number == nil)
        return @"0";
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
    
    [labelCell setObjectValue:nonNullObjectValueForKey(obj, BDSKGroupCellLabelKey)];
    
    [imageCell setImage:nonNullObjectValueForKey(obj, BDSKGroupCellImageKey)];
    
    [countString replaceCharactersInRange:NSMakeRange(0, [countString length]) withString:stringWithNumber(nonNullObjectValueForKey(obj, BDSKGroupCellCountKey))];
    [self updateCountAttributes];
}

- (NSString *)label {
    return nonNullObjectValueForKey([self objectValue], BDSKGroupCellLabelKey);
}

- (NSImage *)icon {
    return nonNullObjectValueForKey([self objectValue], BDSKGroupCellImageKey);
}

- (NSInteger)count {
    return [nonNullObjectValueForKey([self objectValue], BDSKGroupCellCountKey) integerValue];
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

- (CGFloat)countPaddingForSize:(NSSize)countSize {
    NSInteger count = [self count];
    return (count < 10 ? 1.0 : count < 100 ? 0.9 : 0.7) * countSize.height;
}

- (NSSize)iconSizeForBounds:(NSRect)aRect {
    CGFloat height = [super cellSizeForBounds:aRect].height + IMAGE_SIZE_OFFSET;
    return NSMakeSize(height, height);
}

- (NSRect)iconRectForBounds:(NSRect)aRect {
    NSSize imageSize = [self iconSizeForBounds:aRect];
    return BDSKSliceRect(BDSKShrinkRect(aRect, BORDER_BETWEEN_EDGE_AND_IMAGE, NSMinXEdge), imageSize.width, NSMinXEdge);
}

- (NSRect)countRectForBounds:(NSRect)aRect {
    NSSize countSize = NSZeroSize;
    
    if ([self isRetrieving]) {
        countSize = NSMakeSize(16.0, 16.0);
    } else if ([self failedDownload]) {
        countSize = [countString boundingRectWithSize:aRect.size options:0].size;
        countSize.width = countSize.height;
    } else if ([self count] > 0) {
        countSize = [countString boundingRectWithSize:aRect.size options:0].size;
        countSize.width += [self countPaddingForSize:countSize]; // add oval pading around count
    }
    NSRect countRect;
    if (countSize.width > 0.0)
        // now set the size of it to the string size
        countRect = BDSKCenterRect(BDSKSliceRect(BDSKShrinkRect(aRect, BORDER_BETWEEN_EDGE_AND_COUNT, NSMaxXEdge), countSize.width, NSMaxXEdge), countSize, YES);
    else
        countRect = BDSKSliceRect(aRect, 0.0, NSMaxXEdge);
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

- (CGFloat)labelHeight {
    return [[labelCell font] defaultViewLineHeight];
}

- (NSSize)cellSizeForBounds:(NSRect)aRect {
    NSSize cellSize = [super cellSizeForBounds:aRect];
    NSSize countSize = NSZeroSize;
    CGFloat iconHeight = cellSize.height + IMAGE_SIZE_OFFSET;
    if ([self label]) {
        cellSize.width = fmax(cellSize.width, [labelCell cellSize].width);
        cellSize.height += [self labelHeight];
    }
    cellSize.height += 2.0 * TEXT_INSET - 1.0;
    if ([self isRetrieving]) {
        countSize = NSMakeSize(16, 16);
    } else if ([self count] > 0 || [self failedDownload]) {
        countSize = [countString boundingRectWithSize:cellSize options:0].size;
        if ([self failedDownload])
            countSize.width = countSize.height;
        else
            countSize.width += [self countPaddingForSize:countSize]; // add oval pading around count
    }
    // cellSize.height approximates the icon size
    cellSize.width += BORDER_BETWEEN_EDGE_AND_IMAGE + iconHeight + BORDER_BETWEEN_IMAGE_AND_TEXT;
    if (countSize.width > 0.0)
        cellSize.width += BORDER_BETWEEN_COUNT_AND_TEXT + countSize.width + BORDER_BETWEEN_EDGE_AND_COUNT;
    cellSize.width = fmin(cellSize.width, NSWidth(aRect));
    cellSize.height = fmin(cellSize.height, NSHeight(aRect));
    return cellSize;
}

- (void)drawInteriorWithFrame:(NSRect)aRect inView:(NSView *)controlView {
    BOOL isHighlighted = ([self backgroundStyle] == NSBackgroundStyleDark || [self backgroundStyle] == NSBackgroundStyleLowered);
    
    // Draw the text
    NSRect textRect = [self textRectForBounds:aRect]; 
    NSFont *font = nil;
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
        NSInteger count = [self count];
        if (count > 0 || [self failedDownload]) {
            
            NSColor *fgColor;
            NSColor *bgColor;
            // On Leopard, use the blue or gray color taken from the center of the gradient highlight
            if ([[controlView window] isKeyWindow] && [[controlView window] firstResponder] == controlView)
                // the key state color does not look nice for the count bubble background
                bgColor = isHighlighted ? [NSColor keySourceListHighlightColor] : [NSColor mainSourceListHighlightColor];
            else if ([[controlView window] isMainWindow] || [[controlView window] isKeyWindow])
                bgColor = [NSColor mainSourceListHighlightColor];
            else
                bgColor = [NSColor disabledSourceListHighlightColor];
            if (isHighlighted) {
                fgColor = bgColor;
                bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.95];
            } else {
                fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                bgColor = [bgColor colorWithAlphaComponent:0.95];
            }
            
            [NSGraphicsContext saveGraphicsState];
            
            if ([self failedDownload]) {
                
                [bgColor setFill];
                [[NSBezierPath bezierPathWithOvalInRect:countRect] fill];
                [fgColor setFill];
                CGFloat u = [controlView isFlipped] ? NSWidth(countRect) / 14.0 : NSWidth(countRect) / -14.0;
                NSPoint top = NSMakePoint(NSMidX(countRect), [controlView isFlipped] ? NSMinY(countRect) : NSMaxY(countRect));
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(top.x, top.y + 2.0 * u)];
                [path relativeLineToPoint:NSMakePoint(-5.0 * u, 8.0 * u)];
                [path relativeLineToPoint:NSMakePoint(10.0 * u, 0)];
                [path closePath];
                [path fill];
                [bgColor setFill];
                path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(top.x - u, top.y + 4.0 * u)];
                [path relativeLineToPoint:NSMakePoint(2.0 * u, 0)];
                [path relativeLineToPoint:NSMakePoint(0, 3.0 * u)];
                [path relativeLineToPoint:NSMakePoint(-2 * u, 0)];
                [path closePath];
                [path relativeMoveToPoint:NSMakePoint(0, 4.0 * u)];
                [path relativeLineToPoint:NSMakePoint(2.0 * u, 0)];
                [path relativeLineToPoint:NSMakePoint(0, u)];
                [path relativeLineToPoint:NSMakePoint(-2.0 * u, 0)];
                [path closePath];
                [path setWindingRule:NSEvenOddWindingRule];
                [path fill];
                [path fill];
                
            } else {
                
                CGFloat countInset = 0.5 * [self countPaddingForSize:countRect.size];
                
                [bgColor setFill];
                [NSBezierPath fillHorizontalOvalInRect:countRect];
                
                [countString addAttribute:NSForegroundColorAttributeName value:fgColor range:NSMakeRange(0, [countString length])];
                [countString drawWithRect:NSInsetRect(countRect, countInset, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
                
            }
            
            [NSGraphicsContext restoreGraphicsState];
        }
    }
    
    if ([self label]) {
        textRect = BDSKSliceRect(textRect, [self labelHeight], [controlView isFlipped] ? NSMaxYEdge : NSMinYEdge);
        [labelCell drawInteriorWithFrame:textRect inView:controlView];
    }
    
    // Draw the image
    NSRect imageRect = BDSKCenterRect([self iconRectForBounds:aRect], [self iconSizeForBounds:aRect], [controlView isFlipped]);
    [imageCell drawInteriorWithFrame:imageRect inView:controlView];
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
    [super editWithFrame:[self textRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
    [super selectWithFrame:[self textRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
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
