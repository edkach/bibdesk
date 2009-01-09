//
//  BDSKZoomablePDFView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/23/05.
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

#import "BDSKZoomablePDFView.h"
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>
#import "BDSKHeaderPopUpButton.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSScrollView_BDSKExtensions.h"


@interface NSResponder (BDSKGesturesPrivate)
- (void)magnifyWithEvent:(NSEvent *)theEvent;
- (void)beginGestureWithEvent:(NSEvent *)theEvent;
- (void)endGestureWithEvent:(NSEvent *)theEvent;
@end

@interface NSEvent (BDSKGesturesPrivate)
- (float)magnification;
@end

@implementation BDSKZoomablePDFView

/* For genstrings:
    NSLocalizedStringFromTable(@"Auto", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"10%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"20%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"25%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"35%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"50%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"60%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"71%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"85%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"100%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"120%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"141%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"170%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"200%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"300%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"400%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"600%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"800%", @"ZoomValues", @"Zoom popup entry")
*/   
static NSString *BDSKDefaultScaleMenuLabels[] = {@"Auto", @"10%", @"20%", @"25%", @"35%", @"50%", @"60%", @"71%", @"85%", @"100%", @"120%", @"141%", @"170%", @"200%", @"300%", @"400%", @"600%", @"800%"};
static float BDSKDefaultScaleMenuFactors[] = {0.0, 0.1, 0.2, 0.25, 0.35, 0.5, 0.6, 0.71, 0.85, 1.0, 1.2, 1.41, 1.7, 2.0, 3.0, 4.0, 6.0, 8.0};
static float BDSKScaleMenuFontSize = 11.0;

#pragma mark Instance methods

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        scalePopUpButton = nil;
        pinchZoomFactor = 1.0;
        [self makeScalePopUpButton];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        scalePopUpButton = nil;
        pinchZoomFactor = 1.0;
        [self makeScalePopUpButton];
    }
    return self;
}

#pragma mark Copying

// override so we can put the entire document on the pasteboard if there is no selection
- (void)copy:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, NSStringPboardType, NSRTFPboardType, nil] owner:nil];
    
    PDFSelection *theSelection = [self currentSelection];
    if(!theSelection)
        theSelection = [[self document] selectionForEntireDocument];
    NSAttributedString *attrString = [theSelection attributedString];
    
    [pboard setData:[[self document] dataRepresentation] forType:NSPDFPboardType];
    [pboard setString:[attrString string] forType:NSStringPboardType];
    [pboard setData:[attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil] forType:NSRTFPboardType];
}

- (void)copyAsPDF:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, nil] owner:nil];
    [pboard setData:[[self document] dataRepresentation] forType:NSPDFPboardType];
}

- (void)copyAsText:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NSRTFPboardType, nil] owner:nil];
    
    PDFSelection *theSelection = [self currentSelection];
    if(!theSelection)
        theSelection = [[self document] selectionForEntireDocument];
    NSAttributedString *attrString = [theSelection attributedString];
    
    [pboard setString:[attrString string] forType:NSStringPboardType];
    [pboard setData:[attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil] forType:NSRTFPboardType];
}

- (void)copyPDFPage:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, nil] owner:self];
    [pboard setData:[[self currentPage] dataRepresentation] forType:NSPDFPboardType];
}

- (void)saveDocumentSheetDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
{
    NSError *error = nil;
    if(returnCode == NSOKButton){
        // -[PDFDocument writeToURL:] returns YES even if you don't have write permission, so we'll use NSData rdar://problem/4475062
        NSData *data = [[self document] dataRepresentation];
        
        if([data writeToURL:[sheet URL] options:NSAtomicWrite error:&error] == NO){
            [sheet orderOut:nil];
            [self presentError:error];
        }
    }
}
    
- (void)saveDocumentAs:(id)sender;
{
    NSString *name = [[[self document] documentURL] lastPathComponent];
    [[NSSavePanel savePanel] beginSheetForDirectory:nil file:(name ?: NSLocalizedString(@"Untitled.pdf", @"Default file name for saved PDF")) modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(saveDocumentSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
{
    NSMenu *menu = [super menuForEvent:theEvent];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Copy Document as PDF", @"Menu item title") action:@selector(copyAsPDF:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Copy Page as PDF", @"Menu item title") action:@selector(copyPDFPage:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];

    NSString *title = (nil == [self currentSelection]) ? NSLocalizedString(@"Copy All Text", @"Menu item title") : NSLocalizedString(@"Copy Selected Text", @"Menu item title");
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:title action:@selector(copyAsText:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Save PDF As", @"Menu item title") stringByAppendingEllipsis] action:@selector(saveDocumentAs:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];

    return menu;
}

// Fix a bug in Tiger's PDFKit, tooltips lead to a crash when you reload a PDFDocument in a PDFView
// see http://www.cocoabuilder.com/archive/message/cocoa/2007/3/12/180190
- (void)scheduleAddingToolips {}
    
#pragma mark Popup button

- (void)makeScalePopUpButton {
    
    if (scalePopUpButton == nil) {
        
        NSScrollView *scrollView = [self scrollView];
        [scrollView setHasHorizontalScroller:YES];

        // create it        
        scalePopUpButton = [[BDSKHeaderPopUpButton allocWithZone:[self zone]] initWithFrame:NSMakeRect(0.0, 0.0, 1.0, 1.0) pullsDown:NO];
        
        NSControlSize controlSize = [[scrollView horizontalScroller] controlSize];
        [[scalePopUpButton cell] setControlSize:controlSize];

        // set a suitable font, the control size is 0, 1 or 2
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize: BDSKScaleMenuFontSize - controlSize]];

        unsigned cnt, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuLabels) / sizeof(NSString *));
        id curItem;
        NSString *label;
        float width, maxWidth = 0.0;
        NSSize size = NSMakeSize(1000.0, 1000.0);
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[scalePopUpButton font], NSFontAttributeName, nil];
        unsigned maxIndex = 0;
        
        // fill it
        for (cnt = 0; cnt < numberOfDefaultItems; cnt++) {
            label = [[NSBundle mainBundle] localizedStringForKey:BDSKDefaultScaleMenuLabels[cnt] value:@"" table:@"ZoomValues"];
            width = NSWidth([label boundingRectWithSize:size options:0 attributes:attrs]);
            if (width > maxWidth) {
                maxWidth = width;
                maxIndex = cnt;
            }
            [scalePopUpButton addItemWithTitle:label];
            curItem = [scalePopUpButton itemAtIndex:cnt];
            [curItem setRepresentedObject:(BDSKDefaultScaleMenuFactors[cnt] > 0.0 ? [NSNumber numberWithFloat:BDSKDefaultScaleMenuFactors[cnt]] : nil)];
        }
        // select the appropriate item, adjusting the scaleFactor if necessary
        if([self autoScales])
            [self setScaleFactor:0.0 adjustPopup:YES];
        else
            [self setScaleFactor:[self scaleFactor] adjustPopup:YES];

        // Make sure the popup is big enough to fit the largest cell
        cnt = [scalePopUpButton indexOfSelectedItem];
        [scalePopUpButton selectItemAtIndex:maxIndex];
        [scalePopUpButton sizeToFit];
        [scalePopUpButton selectItemAtIndex:cnt];

		// don't let it become first responder
		[scalePopUpButton setRefusesFirstResponder:YES];

        // hook it up
        [scalePopUpButton setTarget:self];
        [scalePopUpButton setAction:@selector(scalePopUpAction:)];

        // put it in the scrollview
        [scrollView setPlacards:[NSArray arrayWithObject:scalePopUpButton]];
        [scalePopUpButton release];
    }
}

- (void)scalePopUpAction:(id)sender {
    NSNumber *selectedFactorObject = [[sender selectedCell] representedObject];
    if(!selectedFactorObject)
        [super setAutoScales:YES];
    else
        [self setScaleFactor:[selectedFactorObject floatValue] adjustPopup:NO];
}

- (unsigned int)lowerIndexForScaleFactor:(float)scaleFactor {
    unsigned int i, count = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
    for (i = count - 1; i > 0; i--) {
        if (scaleFactor * 1.01 > BDSKDefaultScaleMenuFactors[i])
            return i;
    }
    return 1;
}

- (unsigned int)upperIndexForScaleFactor:(float)scaleFactor {
    unsigned int i, count = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
    for (i = 1; i < count; i++) {
        if (scaleFactor * 0.99 < BDSKDefaultScaleMenuFactors[i])
            return i;
    }
    return count - 1;
}

- (unsigned int)indexForScaleFactor:(float)scaleFactor {
    unsigned int lower = [self lowerIndexForScaleFactor:scaleFactor], upper = [self upperIndexForScaleFactor:scaleFactor];
    if (upper > lower && scaleFactor < 0.5 * (BDSKDefaultScaleMenuFactors[lower] + BDSKDefaultScaleMenuFactors[upper]))
        return lower;
    return upper;
}

- (void)setScaleFactor:(float)newScaleFactor {
    NSPoint scrollPoint = (NSPoint)[self scrollPositionAsPercentage];
	[self setScaleFactor:newScaleFactor adjustPopup:YES];
    [self setScrollPositionAsPercentage:scrollPoint];
}

- (void)setScaleFactor:(float)newScaleFactor adjustPopup:(BOOL)flag {
    
	if (flag) {
		if (newScaleFactor < 0.01) {
            newScaleFactor = 0.0;
        } else {
            unsigned int i = [self indexForScaleFactor:newScaleFactor];
            [scalePopUpButton selectItemAtIndex:i];
            newScaleFactor = BDSKDefaultScaleMenuFactors[i];
        }
    }
    
    if(newScaleFactor < 0.01)
        [self setAutoScales:YES];
    else
        [super setScaleFactor:newScaleFactor];
}

- (void)setAutoScales:(BOOL)newAuto {
    [super setAutoScales:newAuto];
    
    if(newAuto)
		[scalePopUpButton selectItemAtIndex:0];
}

- (IBAction)zoomIn:(id)sender{
    if([self autoScales]){
        [super zoomIn:sender];
    }else{
        unsigned int numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
        unsigned int i = [self lowerIndexForScaleFactor:[self scaleFactor]];
        if (i < numberOfDefaultItems - 1) i++;
        [self setScaleFactor:BDSKDefaultScaleMenuFactors[i]];
    }
}

- (IBAction)zoomOut:(id)sender{
    if([self autoScales]){
        [super zoomOut:sender];
    }else{
        unsigned int i = [self upperIndexForScaleFactor:[self scaleFactor]];
        if (i > 1) i--;
        [self setScaleFactor:BDSKDefaultScaleMenuFactors[i]];
    }
}

- (BOOL)canZoomIn{
    if ([super canZoomIn] == NO)
        return NO;
    if([self autoScales])   
        return YES;
    unsigned int numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
    unsigned int i = [self lowerIndexForScaleFactor:[self scaleFactor]];
    return i < numberOfDefaultItems - 1;
}

- (BOOL)canZoomOut{
    if ([super canZoomOut] == NO)
        return NO;
    if([self autoScales])   
        return YES;
    unsigned int i = [self upperIndexForScaleFactor:[self scaleFactor]];
    return i > 1;
}

#pragma mark Scrollview

- (NSScrollView *)scrollView;
{
    return [[self documentView] enclosingScrollView];
}

- (void)setScrollerSize:(NSControlSize)controlSize;
{
    NSScrollView *scrollView = [[self documentView] enclosingScrollView];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [[scrollView horizontalScroller] setControlSize:controlSize];
    [[scrollView verticalScroller] setControlSize:controlSize];
	if(scalePopUpButton){
		[[scalePopUpButton cell] setControlSize:controlSize];
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize: BDSKScaleMenuFontSize - controlSize]];
	}
}

#pragma mark Gestures

- (void)beginGestureWithEvent:(NSEvent *)theEvent {
    if ([[BDSKZoomablePDFView superclass] instancesRespondToSelector:_cmd])
        [super beginGestureWithEvent:theEvent];
    pinchZoomFactor = 1.0;
}

- (void)endGestureWithEvent:(NSEvent *)theEvent {
    if (fabsf(pinchZoomFactor - 1.0) > 0.1)
        [self setScaleFactor:fmaxf(pinchZoomFactor * [self scaleFactor], BDSKDefaultScaleMenuFactors[1])];
    pinchZoomFactor = 1.0;
    if ([[BDSKZoomablePDFView superclass] instancesRespondToSelector:_cmd])
        [super endGestureWithEvent:theEvent];
}

- (void)magnifyWithEvent:(NSEvent *)theEvent {
    if ([theEvent respondsToSelector:@selector(magnification)]) {
        pinchZoomFactor *= 1.0 + fmaxf(-0.5, fminf(1.0 , [theEvent magnification]));
        float scaleFactor = pinchZoomFactor * [self scaleFactor];
        unsigned int i = [self indexForScaleFactor:fmaxf(scaleFactor, BDSKDefaultScaleMenuFactors[1])];
        if (i != [self indexForScaleFactor:[self scaleFactor]]) {
            [self setScaleFactor:BDSKDefaultScaleMenuFactors[i]];
            pinchZoomFactor = scaleFactor / [self scaleFactor];
        }
    }
}

@end
