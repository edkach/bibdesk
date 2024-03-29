//
//  BDSKSharedGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/03/06.
/*
 This software is Copyright (c) 2006-2012
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

#import "BDSKSharedGroup.h"
#import "BDSKSharingClient.h"
#import "NSArray_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacroResolver.h"
#import "BibItem.h"


@implementation BDSKSharedGroup

#pragma mark Class methods

// Cached icons

static NSImage *lockedIcon = nil;
static NSImage *unlockedIcon = nil;

+ (NSImage *)icon{
    return [NSImage imageNamed:NSImageNameBonjour];
}

static inline NSImage *createBadgedIcon(NSImage *icon, NSString *badgeName) {
    NSRect iconRect = NSMakeRect(0.0, 0.0, 32.0, 32.0);
    NSRect badgeRect = NSMakeRect(20.0, 0.0, 12.0, 16.0);
    NSImage *image = [[NSImage alloc] initWithSize:iconRect.size];
    NSImage *badge = [NSImage imageNamed:badgeName];
    
    [image lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    [badge drawInRect:badgeRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.65];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationDefault];
    [image unlockFocus];
    
    iconRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);
    badgeRect = NSMakeRect(10.0, 0.0, 6.0, 8.0);
    
    NSImage *tinyImage = [[NSImage alloc] initWithSize:iconRect.size];
    
    [tinyImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    [badge drawInRect:badgeRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.65];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationDefault];
    [tinyImage unlockFocus];
    [image addRepresentation:[[tinyImage representations] lastObject]];
    [tinyImage release];
    
    return image;
}

+ (NSImage *)lockedIcon {
    if(lockedIcon == nil)
        lockedIcon = createBadgedIcon([self icon], NSImageNameLockLockedTemplate);
    return lockedIcon;
}

+ (NSImage *)unlockedIcon {
    if(unlockedIcon == nil)
        unlockedIcon = createBadgedIcon([self icon], NSImageNameLockUnlockedTemplate);
    return unlockedIcon;
}

#pragma mark Init and dealloc

// old designated initializer
- (id)initWithName:(NSString *)aName;
{
    [self release];
    self = nil;
    return self;
}

// designated initializer
- (id)initWithClient:(BDSKSharingClient *)aClient;
{
    NSParameterAssert(aClient != nil);
    self = [super initWithName:[aClient name]];
    if (self) {

        client = [aClient retain];
        
        [self handleClientUpdatedNotification:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
               selector:@selector(handleClientUpdatedNotification:)
	               name:BDSKSharingClientUpdatedNotification
                 object:client];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    [self release];
    self = nil;
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(client);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone {
	return [(BDSKSharedGroup *)[[self class] allocWithZone:aZone] initWithClient:client];
}

// Logging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tneeds update: %@\n\tname: %@\n }", [self class], self, ([self needsUpdate] ? @"yes" : @"no"), name];
}

- (BDSKSharingClient *)client { return client; }

- (void)addPublications:(NSArray *)newPublications { [self doesNotRecognizeSelector:_cmd]; }

- (BOOL)shouldRetrievePublications {
    return [self needsUpdate] || [super shouldRetrievePublications];

}

- (void)retrievePublications {
    [client retrievePublications];
}

// BDSKGroup overrides

- (NSImage *)icon {
    if ([client needsAuthentication])
        return ([self publicationsWithoutUpdating] == nil) ? [[self class] lockedIcon] : [[self class] unlockedIcon];
    else
        return [[self class] icon];
}

- (BOOL)isRetrieving { return [client isRetrieving]; }

- (BOOL)failedDownload { return [client failedDownload]; }

- (BOOL)needsUpdate { return [client needsUpdate]; }

- (BOOL)isShared { return YES; }

- (NSString *)errorMessage { return [client errorMessage]; }

#pragma mark notification handlers

- (void)handleClientUpdatedNotification:(NSNotification *)notification {
    NSData *pubsArchive = [client archivedPublications];
    NSData *macrosArchive = [client archivedMacros];
    NSArray *pubs = nil;
    NSDictionary *macros = nil;
    
    [NSString setMacroResolverForUnarchiving:[self macroResolver]];
    if (pubsArchive)
        pubs = [NSKeyedUnarchiver unarchiveObjectWithData:pubsArchive];
    if (macrosArchive)
        macros = [NSKeyedUnarchiver unarchiveObjectWithData:macrosArchive];
    [NSString setMacroResolverForUnarchiving:nil];
    
    // we set the macroResolver so we know the fields of this item may refer to it, so we can prevent scripting from adding this to the wrong document
    [pubs setValue:macroResolver forKey:@"macroResolver"];
    
    [[self macroResolver] setMacroDefinitions:macros];
    [self setPublications:pubs];
}

@end
