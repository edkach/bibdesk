//
//  NSMenu_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/09/06.
/*
 This software is Copyright (c) 2006-2008
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

#import "NSMenu_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKVersionNumber.h"

static NSString *BDSKMenuTargetURL = @"BDSKMenuTargetURL";
static NSString *BDSKMenuApplicationURL = @"BDSKMenuApplicationURL";

@interface BDSKOpenWithMenuController : NSObject 
+ (id)sharedInstance;
- (void)openURLWithApplication:(id)sender;
@end

@interface NSMenu (BDSKPrivate)
- (void)replaceAllItemsWithApplicationsForURL:(NSURL *)aURL;
@end

@implementation NSMenu (BDSKExtensions)

- (void)addItemsFromMenu:(NSMenu *)other;
{
    unsigned i, count = [other numberOfItems];
    NSMenuItem *anItem;
    NSZone *zone = [self zone];
    for(i = 0; i < count; i++){
        anItem = [[other itemAtIndex:i] copyWithZone:zone];
        [self addItem:anItem];
        [anItem release];
    }
}

- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu atIndex:(unsigned int)idx;
{
    NSMenuItem *item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:itemTitle action:NULL keyEquivalent:@""];
    [item setSubmenu:submenu];
    [self insertItem:item atIndex:idx];
    [item release];
    return item;
}

- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu;
{
    return [self insertItemWithTitle:itemTitle submenu:submenu atIndex:[self numberOfItems]];
}

- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle submenuTitle:(NSString *)submenuTitle submenuDelegate:(id)delegate atIndex:(unsigned int)idx;
{
    NSMenuItem *item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:itemTitle action:NULL keyEquivalent:@""];
    NSMenu *submenu = [[NSMenu allocWithZone:[self zone]] initWithTitle:submenuTitle];
    [submenu setDelegate:delegate];
    [item setSubmenu:submenu];
    [self insertItem:item atIndex:idx];
    [submenu release];
    [item release];
    return item;
}

- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle submenuTitle:(NSString *)submenuTitle submenuDelegate:(id)delegate;
{
    return [self insertItemWithTitle:itemTitle submenuTitle:submenuTitle submenuDelegate:delegate atIndex:[self numberOfItems]];
}

- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle andSubmenuOfApplicationsForURL:(NSURL *)theURL atIndex:(unsigned int)idx;
{
    if (theURL == nil) {
        // just return an empty item
        return [self insertItemWithTitle:itemTitle action:NULL keyEquivalent:@"" atIndex:idx];
    }
    
    NSMenu *submenu;
    NSMenuItem *item;
    NSDictionary *representedObject;
    BDSKOpenWithMenuController *controller = [BDSKOpenWithMenuController sharedInstance];
    
    submenu = [[[NSMenu allocWithZone:[self zone]] initWithTitle:@""] autorelease];
    [submenu setDelegate:controller];
    
    // add the choose... item, the other items are inserted lazily by BDSKOpenWithMenuController
    item = [submenu addItemWithTitle:[NSLocalizedString(@"Choose", @"Menu item title") stringByAppendingEllipsis] action:@selector(openURLWithApplication:) keyEquivalent:@""];
    [item setTarget:controller];
    representedObject = [[NSDictionary alloc] initWithObjectsAndKeys:theURL, BDSKMenuTargetURL, nil];
    [item setRepresentedObject:representedObject];
    [representedObject release];
    
    return [self insertItemWithTitle:itemTitle submenu:submenu atIndex:idx];
}

- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle andSubmenuOfApplicationsForURL:(NSURL *)theURL;
{
    return [self insertItemWithTitle:itemTitle andSubmenuOfApplicationsForURL:theURL atIndex:[self numberOfItems]];
}

@end


@implementation NSMenu (BDSKPrivate)

static BOOL fileIsInApplicationsOrSystem(NSURL *fileURL)
{
    NSCParameterAssert([fileURL isFileURL]);    
    FSRef fileRef;
    Boolean result = false;
    if (CFURLGetFSRef((CFURLRef)fileURL, &fileRef)) {
        FSDetermineIfRefIsEnclosedByFolder(0, kApplicationsFolderType, &fileRef, &result);
        if (result == false)
            FSDetermineIfRefIsEnclosedByFolder(0, kSystemFolderType, &fileRef, &result);
    }
    return result;
}

static inline NSString *displayNameForURL(NSURL *appURL) {
    return [[[NSFileManager defaultManager] displayNameAtPath:[appURL path]] stringByDeletingPathExtension];
}

static inline NSArray *copyUniqueVersionedNamesAndURLsForURLs(NSArray *appURLs, NSString *appName, NSURL *defaultAppURL) {
    NSMutableArray *uniqueNamesAndURLs = [[NSMutableArray alloc] init];
    int i, count = [appURLs count];
    
    if (count > 1) {
        NSMutableSet *versionStrings = [[NSMutableSet alloc] init];
        
        for (i = 0; i < count; i++) {
            NSURL *appURL = [appURLs objectAtIndex:i];
            NSDictionary *appInfo = [[NSBundle bundleWithPath:[appURL path]] infoDictionary];
            NSString *versionString = [appInfo objectForKey:@"CFBundleShortVersionString"];
            if (versionString == nil)
                versionString = [appInfo objectForKey:@"CFBundleVersion"];
            // we make sure the default app is always included, and we prefer apps in Applications or System
            if ([versionStrings containsObject:versionString] && ([defaultAppURL isEqual:appURL] || fileIsInApplicationsOrSystem(appURL))) {
                unsigned int idx = [[uniqueNamesAndURLs valueForKey:@"versionString"] indexOfObject:versionString];
                if (idx != NSNotFound && [[[uniqueNamesAndURLs objectAtIndex:idx] objectForKey:@"appURL"] isEqual:defaultAppURL] == NO) {
                    [uniqueNamesAndURLs removeObjectAtIndex:idx];
                    [versionStrings removeObject:versionString];
                }
            }
            if ([versionStrings containsObject:versionString] == NO) {
                BDSKVersionNumber *versionNumber = versionString ? [[BDSKVersionNumber alloc] initWithVersionString:versionString] : nil;
                NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:appURL, @"appURL", appName, @"appName", versionString, @"versionString", versionNumber, @"versionNumber", nil];
                if (versionString)
                    [versionStrings addObject:versionString];
                [versionNumber release];
                [uniqueNamesAndURLs addObject:dict];
                [dict release];
            }
        }
        
        [versionStrings release];
        
        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"versionNumber" ascending:NO selector:@selector(compareToVersionNumber:)];
        [uniqueNamesAndURLs sortUsingDescriptors:[NSArray arrayWithObject:sort]];
        [sort release];
    } else if (count == 1) {
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:[appURLs lastObject], @"appURL", appName, @"appName", nil];
        [uniqueNamesAndURLs addObject:dict];
        [dict release];
    }
    
    return uniqueNamesAndURLs;
}

- (void)replaceAllItemsWithApplicationsForURL:(NSURL *)aURL;
{    
    // assumption: last item is "Choose..." item; note that this item may be the only thing retaining aURL
    OBASSERT([self numberOfItems] > 0);
    while([self numberOfItems] > 1)
        [self removeItemAtIndex:0];
    
    NSZone *menuZone = [NSMenu menuZone];
    NSMenuItem *item;
    
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSArray *appURLs = [workspace editorAndViewerURLsForURL:aURL];
    NSURL *defaultAppURL = [workspace defaultEditorOrViewerURLForURL:aURL];
    NSArray *namesAndURLs;
    NSURL *appURL;
    NSString *appName;
    NSString *version;
    NSDictionary *dict;
    unsigned int idx, i, j, subCount, count = [appURLs count];
    
    for (i = 0; i < count; i++) {
        appURL = [appURLs objectAtIndex:i];
        appName = displayNameForURL(appURL);
        
        j = i + 1;
        while (j < count && [displayNameForURL([appURLs objectAtIndex:j]) isEqualToString:appName]) j++;
        namesAndURLs = copyUniqueVersionedNamesAndURLsForURLs([appURLs subarrayWithRange:NSMakeRange(i, j - i)], appName, defaultAppURL);
        i = j - 1;
        
        subCount = [namesAndURLs count];
        for (j = 0; j < subCount; j++) {
            dict = [namesAndURLs objectAtIndex:j];
            appURL = [dict objectForKey:@"appURL"];
            appName = [dict objectForKey:@"appName"];
            if ([appURL isEqual:defaultAppURL])
                appName = [appName stringByAppendingString:NSLocalizedString(@" (default)", @"Menu item title, Need a single leading space")];
            if (subCount > 1 && (version = [dict objectForKey:@"versionString"]))
                appName = [appName stringByAppendingFormat:@" (%@)", version];
            item = [[NSMenuItem allocWithZone:menuZone] initWithTitle:appName action:@selector(openURLWithApplication:) keyEquivalent:@""];        
            [item setTarget:[BDSKOpenWithMenuController sharedInstance]];
            
            dict = [[NSDictionary alloc] initWithObjectsAndKeys:aURL, BDSKMenuTargetURL, appURL, BDSKMenuApplicationURL, nil];
            [item setRepresentedObject:dict];
            [dict release];
            
            // use NSWorkspace to get an image; using [NSImage imageForURL:] doesn't work for some reason
            [item setImageAndSize:[workspace iconForFileURL:appURL]];
            if ([appURL isEqual:defaultAppURL]) {
                [self insertItem:[NSMenuItem separatorItem] atIndex:0];
                [self insertItem:item atIndex:0];
            } else {
                [self insertItem:item atIndex:[self numberOfItems] - 1];
            }
            [item release];
        }
        [namesAndURLs release];
    }
    
    if ([self numberOfItems] > 1 && [[self itemAtIndex:[self numberOfItems] - 2] isSeparatorItem])
        [self insertItem:[NSMenuItem separatorItem] atIndex:[self numberOfItems] - 1];
}

@end

#pragma mark -

/* Private singleton to act as target for the "Open With..." menu item, or run a modal panel to choose a different application.
*/

@implementation BDSKOpenWithMenuController

static id sharedOpenWithController = nil;

+ (id)sharedInstance
{
    if(nil == sharedOpenWithController)
        sharedOpenWithController = [[self alloc] init];
    return sharedOpenWithController;
}

- (id)copyWithZone:(NSZone *)zone{
    return [sharedOpenWithController retain];
}

- (void)encodeWithCoder:(NSCoder *)coder{}

- (id)initWithCoder:(NSCoder *)decoder{
    [[self init] release];
    self = [sharedOpenWithController retain];
    return self;
}

- (void)chooseApplicationToOpenURL:(NSURL *)aURL;
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setPrompt:NSLocalizedString(@"Choose Viewer", @"Prompt for Choose panel")];
    
    int rv = [openPanel runModalForDirectory:[[NSFileManager defaultManager] applicationsDirectory] 
                                        file:nil 
                                       types:[NSArray arrayWithObjects:@"app", nil]];
    if(NSFileHandlingPanelOKButton == rv)
        [[NSWorkspace sharedWorkspace] openURL:aURL withApplicationURL:[[openPanel URLs] firstObject]];
}

// action for opening a file with a specific application
- (void)openURLWithApplication:(id)sender;
{
    NSURL *applicationURL = [[sender representedObject] valueForKey:BDSKMenuApplicationURL];
    NSURL *targetURL = [[sender representedObject] valueForKey:BDSKMenuTargetURL];
    
    if(nil == applicationURL)
        [self chooseApplicationToOpenURL:targetURL];
    else if([[NSWorkspace sharedWorkspace] openURL:targetURL withApplicationURL:applicationURL] == NO)
        NSBeep();
}

- (void)menuNeedsUpdate:(NSMenu *)menu{
    OBASSERT([menu numberOfItems] > 0);
    NSURL *theURL = [[[[menu itemArray] lastObject] representedObject] valueForKey:BDSKMenuTargetURL];
    OBASSERT(theURL != nil);
    if(theURL != nil)
        [menu replaceAllItemsWithApplicationsForURL:theURL];
}

// this is needed to prevent the menu from being updated just to look for key equivalents, 
// which would lead to considerable slowdown of key events
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action{
    return NO;
}
 
- (BOOL)validateMenuItem:(NSMenuItem*)menuItem{
    if ([menuItem action] == @selector(openURLWithApplication:)) {
        NSURL *theURL = [[menuItem representedObject] valueForKey:BDSKMenuTargetURL];
        if([theURL isFileURL])
            theURL = [theURL fileURLByResolvingAliases];
        return (theURL == nil ? NO : YES);
    }
    return YES;
}

@end

@implementation NSMenuItem (BDSKImageExtensions)

- (void)setImageAndSize:(NSImage *)image;
{
    const NSSize dstSize = { 16.0, 16.0 };
    NSSize srcSize = [image size];
    if (NSEqualSizes(srcSize, dstSize)) {
        [self setImage:image];
    } else {
        NSImage *newImage = [[NSImage alloc] initWithSize:dstSize];
        NSGraphicsContext *ctxt = [NSGraphicsContext currentContext];
        [newImage lockFocus];
        [ctxt setImageInterpolation:NSImageInterpolationHigh];
        [image drawInRect:NSMakeRect(0, 0, 16.0, 16.0) fromRect:NSMakeRect(0, 0, srcSize.width, srcSize.height) operation:NSCompositeCopy fraction:1.0];
        [newImage unlockFocus];
        [self setImage:newImage];
        [newImage release];
    }
}
        
@end
