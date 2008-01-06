//
//  NSViewAnimation_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/27/07.
/*
 This software is Copyright (c) 2007,2008
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

#import "NSViewAnimation_BDSKExtensions.h"

NSTimeInterval BDSKDefaultAnimationTimeInterval = 0.15;

@implementation NSViewAnimation (BDSKExtensions)

+ (void)didLoad
{    
    NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:@"BDSKDefaultAnimationTimeInterval"];
    if (nil != n)
        BDSKDefaultAnimationTimeInterval = [n floatValue];
}

+ (void)animateWithViewAnimations:(NSArray *)viewAnimations {
    NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations:viewAnimations];
    
    [animation setAnimationBlockingMode:NSAnimationBlocking];
    [animation setDuration:BDSKDefaultAnimationTimeInterval];
    [animation setAnimationCurve:NSAnimationEaseInOut];
    [animation startAnimation];
    [animation release];
}

+ (void)animateResizeView:(NSView *)aView toRect:(NSRect)aRect {
    if (BDSKDefaultAnimationTimeInterval > 0.0) {
        NSDictionary *viewInfo = [NSDictionary dictionaryWithObjectsAndKeys:aView, NSViewAnimationTargetKey, [NSValue valueWithRect:aRect], NSViewAnimationEndFrameKey, nil];
        [self animateWithViewAnimations:[NSArray arrayWithObjects:viewInfo, nil]];
    } else {
        [aView setFrame:aRect];
    }
}

+ (void)animateFadeOutView:(NSView *)fadeOutView fadeInView:(NSView *)fadeInView {
    if (BDSKDefaultAnimationTimeInterval > 0.0) {
        NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:fadeOutView, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
        NSDictionary *fadeInDict = [[NSDictionary alloc] initWithObjectsAndKeys:fadeInView, NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
        [self animateWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, fadeInDict, nil]];
        [fadeOutDict release];
        [fadeInDict release];
    }
}

@end
