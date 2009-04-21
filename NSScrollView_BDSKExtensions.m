//
//  NSScrollView_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/31/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "NSScrollView_BDSKExtensions.h"
#import "BDSKRuntime.h"
#import "BDSKEdgeView.h"
#import "NSView_BDSKExtensions.h"
#import "BDSKCFCallBacks.h"


@implementation NSScrollView (BDSKExtensions)

static void (*original_setHasHorizontalScroller)(id, SEL, BOOL) = NULL;
static void (*original_setAutohidesScrollers)(id, SEL, BOOL) = NULL;
static void (*original_dealloc)(id, SEL) = NULL;
static void (*original_tile)(id, SEL) = NULL;

static CFMutableDictionaryRef scrollViewPlacards = NULL;

- (void)replacement_dealloc;
{
    CFDictionaryRemoveValue(scrollViewPlacards, self);
    original_dealloc(self, _cmd);
}

- (void)replacement_setHasHorizontalScroller:(BOOL)flag;
{
    if ([[self placards] count] == 0)
        original_setHasHorizontalScroller(self, _cmd, flag);
}

- (void)replacement_setAutohidesScrollers:(BOOL)flag;
{
    if ([[self placards] count] == 0)
        original_setAutohidesScrollers(self, _cmd, flag);
}

- (void)replacement_tile {
    original_tile(self, _cmd);
    
    NSArray *placards = [self placards];
    
    if ([placards count]) {
        NSEnumerator *viewEnum = [placards objectEnumerator];
        NSView *view;
        NSScroller *horizScroller = [self horizontalScroller];
        NSRect viewFrame, horizScrollerFrame = [horizScroller frame];
        CGFloat height = NSHeight(horizScrollerFrame) - 1.0, totalWidth = 0.0;
        BDSKEdgeView *edgeView = (BDSKEdgeView *)[[[placards lastObject] superview] superview];
        
        if ([edgeView isDescendantOf:self] == NO) {
            edgeView = [[[BDSKEdgeView alloc] init] autorelease];
            [edgeView setEdgeColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]];
            [edgeView setEdges:BDSKMinXEdgeMask | BDSKMaxYEdgeMask];
            [self addSubview:edgeView];
        }
        
        while (view = [viewEnum nextObject]) {
            viewFrame = NSMakeRect(totalWidth, 0.0, NSWidth([view frame]), height);
            totalWidth += NSWidth(viewFrame);
            [view setFrame:viewFrame];
            if ([view isDescendantOf:edgeView] == NO)
                [edgeView addSubview:view];
        }
        
        NSDivideRect(horizScrollerFrame, &viewFrame, &horizScrollerFrame, totalWidth + 1.0, NSMaxXEdge);
        [horizScroller setFrame:horizScrollerFrame];
        [edgeView setFrame:viewFrame];
    }
}

+ (void)load{
    original_setHasHorizontalScroller = (void (*)(id, SEL, BOOL))BDSKReplaceInstanceMethodImplementationFromSelector(self, @selector(setHasHorizontalScroller:), @selector(replacement_setHasHorizontalScroller:));
    original_setAutohidesScrollers = (void (*)(id, SEL, BOOL))BDSKReplaceInstanceMethodImplementationFromSelector(self, @selector(setAutohidesScrollers:), @selector(replacement_setAutohidesScrollers:));
    original_dealloc = (void (*)(id, SEL))BDSKReplaceInstanceMethodImplementationFromSelector(self, @selector(dealloc), @selector(replacement_dealloc));
    original_tile = (void (*)(id, SEL))BDSKReplaceInstanceMethodImplementationFromSelector(self, @selector(tile), @selector(replacement_tile));
    
    // dictionary doesn't retain keys, so no retain cycles; pointer equality used to compare views
    scrollViewPlacards = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, NULL, &kCFTypeDictionaryValueCallBacks);
}

- (NSArray *)placards {
    return (NSArray *)CFDictionaryGetValue(scrollViewPlacards, self);
}

- (void)setPlacards:(NSArray *)newPlacards {
    NSMutableArray *placards = (NSMutableArray *)CFDictionaryGetValue(scrollViewPlacards, self);
    if (placards == nil && [newPlacards count]) {
        placards = [NSMutableArray array];
        CFDictionarySetValue(scrollViewPlacards, self, placards);
    }
    
    [[[[placards lastObject] superview] superview] removeFromSuperview];
    [placards setArray:newPlacards];
    
    if ([placards count] != 0) {
        original_setHasHorizontalScroller(self, @selector(setHasHorizontalScroller:), YES);
        original_setAutohidesScrollers(self, @selector(setAutohidesScrollers:), NO);
    } else if (placards) {
        CFDictionaryRemoveValue(scrollViewPlacards, self);
        placards = nil;
    }
    
    [self tile];
}

- (NSPoint)scrollPositionAsPercentage {
    return [[self documentView] scrollPositionAsPercentage];
}

- (void)setScrollPositionAsPercentage:(NSPoint)scrollPosition {
    [[self documentView] setScrollPositionAsPercentage:scrollPosition];
}

@end
