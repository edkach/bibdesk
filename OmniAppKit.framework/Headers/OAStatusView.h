// Copyright 1997-2002 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.
//
// $Header$

#import <AppKit/NSView.h>

@class NSMutableDictionary;
@class NSColor, NSFont;
@class OAProgressView;

@interface OAStatusView : NSView
{
    NSString *status;
    NSMutableDictionary *attributes;
    int ascenderHackAroundRhapsodyBug;

    OAProgressView *progressView;
    struct {
        unsigned int hasProgressView:1;
    } flags;
}

- (void)setFont:(NSFont *)aFont;
- (void)setColor:(NSColor *)aColor;

- (void)setStatus:(NSString *)aStatus;
- (void)setStatus:(NSString *)aStatus withProgress:(unsigned int)amount ofTotal:(unsigned int)total;

// for easy overriding in subclasses
- (void)drawBackground;
- (void)drawStatus;

@end
