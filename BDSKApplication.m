//
//  BDSKApplication.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/26/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKApplication.h"
#import "BibDocument.h"
#import "BDAlias.h"

@interface NSWindow (BDSKApplication)
// these are implemented in AppKit as private methods
- (void)undo:(id)obj;
- (void)redo:(id)obj;
@end

@implementation BDSKApplication

- (IBAction)terminate:(id)sender {
    NSArray *fileNames = [[[NSDocumentController sharedDocumentController] documents] valueForKeyPath:@"@distinctUnionOfObjects.fileName"];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[fileNames count]];
    NSEnumerator *fEnum = [fileNames objectEnumerator];
    NSString *fileName;
    while(fileName = [fEnum nextObject]){
        NSData *data = [[BDAlias aliasWithPath:fileName] aliasData];
        if(data)
            [array addObject:[NSDictionary dictionaryWithObjectsAndKeys:fileName, @"fileName", data, @"_BDAlias", nil]];
        else
            [array addObject:[NSDictionary dictionaryWithObjectsAndKeys:fileName, @"fileName", nil]];
    }
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:array forKey:BDSKLastOpenFileNamesKey];
    
    [super terminate:sender];
}

// workaround for Tiger AppKit bug in target determination for undo in sheets, compare 
// http://developer.apple.com/documentation/Cocoa/Conceptual/NSPersistentDocumentTutorial/08_CreationSheet/chapter_9_section_6.html 

- (id)targetForAction:(SEL)anAction to:(id)aTarget from:(id)sender{
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4 && (anAction == @selector(undo:) || anAction == @selector(redo:))) {
        NSWindow *theKeyWindow = [self keyWindow];
        if ([theKeyWindow isSheet] && [theKeyWindow respondsToSelector:anAction])
            return theKeyWindow;
    }
    return [super targetForAction:anAction to:aTarget from:sender];
}

- (BOOL)sendAction:(SEL)anAction to:(id)theTarget from:(id)sender{
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4 && (anAction == @selector(undo:) || anAction == @selector(redo:))) {
        NSWindow *theKeyWindow = [self keyWindow];
        if ([theKeyWindow isSheet] && [theKeyWindow respondsToSelector:anAction])
            return [super sendAction:anAction to:theKeyWindow from:sender];
    }
    return [super sendAction:anAction to:theTarget from:sender];
}

- (void)reorganizeWindowsItem:(NSWindow *)aWindow {
    NSMenu *windowsMenu = [self windowsMenu];
    NSWindowController *windowController = [aWindow windowController];
    NSWindowController *mainWindowController = [[[[aWindow windowController] document] windowControllers] objectAtIndex:0];
    int numberOfItems = [windowsMenu numberOfItems];
    int itemIndex = [windowsMenu indexOfItemWithTarget:aWindow andAction:@selector(makeKeyAndOrderFront:)];
    
    if (itemIndex != -1) {
        NSMenuItem *item = [windowsMenu itemAtIndex:itemIndex];
        NSString *title = [item title];
        
        if ([windowController document] == nil) {
            int idx = numberOfItems;
            while (idx--) {
                NSMenuItem *anItem = [windowsMenu itemAtIndex:idx];
                if ([anItem isSeparatorItem] ||
                    [[[anItem target] windowController] document] != nil ||
                    [[anItem title] caseInsensitiveCompare:title] == NSOrderedAscending)
                    break;
            }
            ++idx;
            if (itemIndex != idx) {
                if (itemIndex < idx)
                    idx--;
                [item retain];
                [windowsMenu removeItem:item];
                [windowsMenu insertItem:item atIndex:idx];
                [item release];
            }
            if (idx > 0 && [[windowsMenu itemAtIndex:idx - 1] isSeparatorItem] == NO && [[[[windowsMenu itemAtIndex:idx - 1] target] windowController] document] != nil)
                [windowsMenu insertItem:[NSMenuItem separatorItem] atIndex:idx];
        } else if ([windowController isEqual:mainWindowController]) {
            NSMutableArray *subitems = [NSMutableArray array];
            NSMenuItem *anItem;
            int idx = numberOfItems;
            int nextIndex = numberOfItems;
            
            while (idx--) {
                anItem = [windowsMenu itemAtIndex:idx];
                if (anItem != item && [anItem action] == @selector(makeKeyAndOrderFront:)) {
                    id target = [anItem target];
                    NSWindowController *aMainWindowController = [[[[target windowController] document] windowControllers] objectAtIndex:0];
                    if ([aMainWindowController isEqual:mainWindowController]) {
                        [subitems insertObject:anItem atIndex:0];
                        [windowsMenu removeItemAtIndex:idx];
                        nextIndex--;
                        if (itemIndex > idx)
                            itemIndex--;
                    } else if ([aMainWindowController isEqual:[target windowController]]) {
                        NSComparisonResult comparison = [[anItem title] caseInsensitiveCompare:title];
                        if (comparison == NSOrderedDescending)
                            nextIndex = idx;
                    } else if ([[target windowController] document] == nil) {
                        nextIndex = idx;
                    }
                }
            }
            
            if (itemIndex != nextIndex) {
                [item retain];
                [windowsMenu removeItemAtIndex:itemIndex];
                if (nextIndex > itemIndex)
                    nextIndex--;
                if (itemIndex < [windowsMenu numberOfItems] && [[windowsMenu itemAtIndex:itemIndex] isSeparatorItem] && 
                    (itemIndex == [windowsMenu numberOfItems] - 1 || (itemIndex > 0 && [[windowsMenu itemAtIndex:itemIndex - 1] isSeparatorItem]))) {
                    [windowsMenu removeItemAtIndex:itemIndex];
                    if (nextIndex > itemIndex)
                        nextIndex--;
                }
                itemIndex = nextIndex++;
                [windowsMenu insertItem:item atIndex:itemIndex];
                [item release];
            }
            if (itemIndex > 1 && [[windowsMenu itemAtIndex:itemIndex - 1] isSeparatorItem] == NO) {
                [windowsMenu insertItem:[NSMenuItem separatorItem] atIndex:itemIndex];
                nextIndex++;
            }
            
            NSEnumerator *itemEnum = [subitems objectEnumerator];
            while (anItem = [itemEnum nextObject])
                [windowsMenu insertItem:anItem atIndex:nextIndex++];
            
            if (nextIndex < [windowsMenu numberOfItems] && [[windowsMenu itemAtIndex:nextIndex] isSeparatorItem] == NO)
                [windowsMenu insertItem:[NSMenuItem separatorItem] atIndex:nextIndex];
            
        } else {
            int mainIndex = [windowsMenu indexOfItemWithTarget:[mainWindowController window] andAction:@selector(makeKeyAndOrderFront:)];
            int idx = mainIndex;
            
            [item setIndentationLevel:1];
            
            if (idx >= 0) {
                while (++idx < numberOfItems) {
                    NSMenuItem *anItem = [windowsMenu itemAtIndex:idx];
                    if ([anItem isSeparatorItem] || [[anItem title] caseInsensitiveCompare:title] == NSOrderedDescending)
                        break;
                }
                if (itemIndex != idx - 1) {
                    if (itemIndex < idx)
                        idx--;
                    [item retain];
                    [windowsMenu removeItem:item];
                    [windowsMenu insertItem:item atIndex:idx];
                    [item release];
                }
            }
        }
    }
}

- (void)addWindowsItem:(NSWindow *)aWindow title:(NSString *)aString filename:(BOOL)isFilename {
    int itemIndex = [[self windowsMenu] indexOfItemWithTarget:aWindow andAction:@selector(makeKeyAndOrderFront:)];
    
    [super addWindowsItem:aWindow title:aString filename:isFilename];
    
    if (itemIndex == -1)
        [self reorganizeWindowsItem:aWindow];
}

- (void)changeWindowsItem:(NSWindow *)aWindow title:(NSString *)aString filename:(BOOL)isFilename {
    [super changeWindowsItem:aWindow title:aString filename:isFilename];
    
    [self reorganizeWindowsItem:aWindow];
}

- (void)removeWindowsItem:(NSWindow *)aWindow {
    [super removeWindowsItem:aWindow];
    
    int idx = [[self windowsMenu] numberOfItems];
    BOOL wasSeparator = YES;
    
    while (idx--) {
        if ([[[self windowsMenu] itemAtIndex:idx] isSeparatorItem]) {
            if (wasSeparator)
                [[self windowsMenu] removeItemAtIndex:idx];
            else
                wasSeparator = YES;
        } else {
            wasSeparator = NO;
        }
    }
}

#pragma mark Scripting support

- (NSArray *)orderedDocuments {
    NSMutableArray *orderedDocuments = [[[super orderedDocuments] mutableCopy] autorelease];
    int i = [orderedDocuments count];
    
    while (i--)
        if ([[orderedDocuments objectAtIndex:i] isKindOfClass:[BibDocument class]] == NO)
            [orderedDocuments removeObjectAtIndex:i];
    
    return orderedDocuments;
}

@end
