//
//  BDSKDragImageView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 28/11/05.
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

#import "BDSKDragImageView.h"
#import "NSBezierPath_BDSKExtensions.h"

@implementation BDSKDragImageView

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
		delegate = nil;
		highlight = NO;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
		delegate = nil;
		highlight = NO;
	}
	return self;
}

- (id<BDSKDragImageViewDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<BDSKDragImageViewDelegate>)newDelegate {
	delegate = newDelegate;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender{
    NSDragOperation dragOp = NSDragOperationNone;
	if ([delegate respondsToSelector:@selector(dragImageView:validateDrop:)])
		dragOp = [delegate dragImageView:self validateDrop:sender];
	if (dragOp != NSDragOperationNone) {
		highlight = YES;
        [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
		[self setNeedsDisplay:YES];
	}
	return dragOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender{
    highlight = NO;
    [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
	[self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    highlight = NO;
    [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
	[self setNeedsDisplay:YES];
	if ([delegate respondsToSelector:@selector(dragImageView:acceptDrop:)])
		return [delegate dragImageView:self acceptDrop:sender];
	return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
}

- (void)mouseDown:(NSEvent *)theEvent
{
    BOOL keepOn = YES;
    BOOL isInside = YES;
    NSPoint mouseLoc;
    while(keepOn){
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        isInside = [self mouse:mouseLoc inRect:[self bounds]];
        switch ([theEvent type]) {
            case NSLeftMouseDragged:
                if(isInside){
					NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
					
					if ([delegate respondsToSelector:@selector(dragImageView:writeDataToPasteboard:)] &&
						[delegate dragImageView:self writeDataToPasteboard:pboard]) {
                   
						NSImage *dragImage = nil;
                        NSSize imageSize = NSZeroSize;
						if ([delegate respondsToSelector:@selector(dragImageForDragImageView:)]) {
							dragImage = [delegate dragImageForDragImageView:self];
                            imageSize = [dragImage size];
						}
                        if (dragImage == nil) {
							NSImage *image = [self image];
                            imageSize = [image size];
                            dragImage = [[[NSImage alloc] initWithSize:imageSize] autorelease];
                            [dragImage lockFocus];
                            [image compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
                            [dragImage unlockFocus];
                        }
                        [self dragImage:dragImage at:NSMakePoint(mouseLoc.x - 0.5f * imageSize.width, mouseLoc.y - 0.5f * imageSize.height) offset:NSZeroSize event:theEvent pasteboard:pboard source:self slideBack:YES]; 
                    }
					keepOn = NO;
                    break;
                }
            case NSLeftMouseUp:
                keepOn = NO;
                break;
            default:
                keepOn = NO;
                break;
        }
    }
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination{
    if ([delegate respondsToSelector:@selector(dragImageView:namesOfPromisedFilesDroppedAtDestination:)])
		return [delegate dragImageView:self namesOfPromisedFilesDroppedAtDestination:dropDestination];
	return nil;
}    

- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)isLocal{ 
    return isLocal ? NSDragOperationNone : NSDragOperationCopy; 
}

// flag changes during a drag are not forwarded to the application, so we fix that at the end of the drag
- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

- (void)drawRect:(NSRect)aRect {
	[super drawRect:aRect];
	
	if (highlight == NO) return;
	
	[[NSColor alternateSelectedControlColor] set];
	[NSBezierPath setDefaultLineWidth:2.0];
	[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(aRect, 2.0, 2.0) xRadius:5.0 yRadius:5.0] stroke];
}

@end