//
//  BDSKBookmarkController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/18/07.
/*
 This software is Copyright (c) 2007-2008
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

#import "BDSKBookmarkController.h"
#import "BDSKBookmark.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibDocument.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKBookmarkOutlineView.h"

static NSString *BDSKBookmarkRowsPboardType = @"BDSKBookmarkRowsPboardType";

static NSString *BDSKBookmarksToolbarIdentifier = @"BDSKBookmarksToolbarIdentifier";
static NSString *BDSKBookmarksNewBookmarkToolbarItemIdentifier = @"BDSKBookmarksNewBookmarkToolbarItemIdentifier";
static NSString *BDSKBookmarksNewFolderToolbarItemIdentifier = @"BDSKBookmarksNewFolderToolbarItemIdentifier";
static NSString *BDSKBookmarksNewSeparatorToolbarItemIdentifier = @"BDSKBookmarksNewSeparatorToolbarItemIdentifier";
static NSString *BDSKBookmarksDeleteToolbarItemIdentifier = @"BDSKBookmarksDeleteToolbarItemIdentifier";

static NSString *BDSKBookmarkChildrenKey = @"children";
static NSString *BDSKBookmarkNameKey = @"name";
static NSString *BDSKBookmarkUrlStringKey = @"urlString";

static NSString *BDSKBookmarkPropertiesObservationContext = @"BDSKBookmarkPropertiesObservationContext";


@interface BDSKBookmarkController (BDSKPrivate)
- (void)setupToolbar;
- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification;
- (void)endEditing;
- (void)startObservingBookmarks:(NSArray *)newBookmarks;
- (void)stopObservingBookmarks:(NSArray *)oldBookmarks;
@end

@implementation BDSKBookmarkController

+ (id)sharedBookmarkController {
    static id sharedBookmarkController = nil;
    if (sharedBookmarkController == nil) {
        sharedBookmarkController = [[self alloc] init];
    }
    return sharedBookmarkController;
}

- (id)init {
    if (self = [super init]) {
		undoManager = nil;
        
        NSMutableArray *bookmarks = [NSMutableArray array];
		NSString *applicationSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser]; 
		NSString *bookmarksPath = [applicationSupportPath stringByAppendingPathComponent:@"Bookmarks.plist"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:bookmarksPath]) {
			NSEnumerator *bEnum = [[NSArray arrayWithContentsOfFile:bookmarksPath] objectEnumerator];
			NSDictionary *dict;
			
			while(dict = [bEnum nextObject]){
                BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithDictionary:dict];
				[bookmarks addObject:bookmark];
                [bookmark release];
			}
		}
        
        bookmarkRoot = [[BDSKBookmark alloc] initFolderWithChildren:bookmarks name:nil];
        [self startObservingBookmarks:[NSArray arrayWithObject:bookmarkRoot]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminateNotification:) name:NSApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [self stopObservingBookmarks:[NSArray arrayWithObject:bookmarkRoot]];
    [bookmarkRoot release];
    [undoManager release];
    [super dealloc];
}

- (NSString *)windowNibName { return @"BookmarksWindow"; }

- (void)windowDidLoad {
    [self setupToolbar];
    [self setWindowFrameAutosaveName:@"BDSKBookmarksWindow"];
    [outlineView setAutoresizesOutlineColumn:NO];
    [outlineView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
}

- (BDSKBookmark *)bookmarkRoot {
    return bookmarkRoot;
}

- (NSArray *)minimumCoverForBookmarks:(NSArray *)items {
    NSEnumerator *bmEnum = [items objectEnumerator];
    BDSKBookmark *bm;
    BDSKBookmark *lastBm = nil;
    NSMutableArray *minimalCover = [NSMutableArray array];
    
    while (bm = [bmEnum nextObject]) {
        if ([bm isDescendantOf:lastBm] == NO) {
            [minimalCover addObject:bm];
            lastBm = bm;
        }
    }
    return minimalCover;
}

- (NSArray *)draggedBookmarks {
    return draggedBookmarks;
}

- (void)setDraggedBookmarks:(NSArray *)items {
    if (draggedBookmarks != items) {
        [draggedBookmarks release];
        draggedBookmarks = [items retain];
    }
}

- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name {
    [self addBookmarkWithUrlString:urlString name:name toFolder:nil];
}

- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name toFolder:(BDSKBookmark *)folder {
    BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithUrlString:urlString name:name];
    if (bookmark) {
        if (folder == nil) folder = bookmarkRoot;
        [folder insertObject:bookmark inChildrenAtIndex:[folder countOfChildren]];
        [bookmark release];
    }
}

- (void)addBookmarkSheetDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSString *urlString = (NSString *)contextInfo;
	if (returnCode == NSOKButton) {
        [self addBookmarkWithUrlString:urlString name:[bookmarkField stringValue] toFolder:[[folderPopUp selectedItem] representedObject]];
	}
    [urlString release]; //the contextInfo was retained
}

- (void)addMenuItemsForBookmarks:(NSArray *)bookmarksArray level:(int)level toMenu:(NSMenu *)menu {
    int i, iMax = [bookmarksArray count];
    for (i = 0; i < iMax; i++) {
        BDSKBookmark *bm = [bookmarksArray objectAtIndex:i];
        if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
            NSString *name = [bm name];
            NSMenuItem *item = [menu addItemWithTitle:name ? name : @"" action:NULL keyEquivalent:@""];
            [item setImage:[bm icon]];
            [item setIndentationLevel:level];
            [item setRepresentedObject:bm];
            [self addMenuItemsForBookmarks:[bm children] level:level+1 toMenu:menu];
        }
    }
}

- (void)addBookmarkWithUrlString:(NSString *)urlString proposedName:(NSString *)name modalForWindow:(NSWindow *)window {
    [self window];
    [bookmarkField setStringValue:name];
    [folderPopUp removeAllItems];
    NSMenuItem *item = [[folderPopUp menu] addItemWithTitle:NSLocalizedString(@"Bookmarks Menu", @"Menu item title") action:NULL keyEquivalent:@""];
    [item setImage:[NSImage imageNamed:@"SmallMenu"]];
    [item setRepresentedObject:bookmarkRoot];
    [self addMenuItemsForBookmarks:[bookmarkRoot children] level:1 toMenu:[folderPopUp menu]];
    [folderPopUp selectItemAtIndex:0];
	
	[NSApp beginSheet:addBookmarkSheet
       modalForWindow:window
        modalDelegate:self
       didEndSelector:@selector(addBookmarkSheetDidEnd:returnCode:contextInfo:)
          contextInfo:[urlString retain]];
}

- (IBAction)dismissAddBookmarkSheet:(id)sender {
    [NSApp endSheet:addBookmarkSheet returnCode:[sender tag]];
    [addBookmarkSheet orderOut:self];
}

#pragma mark Actions

- (IBAction)insertBookmark:(id)sender {
    BDSKBookmark *bookmark = [[[BDSKBookmark alloc] initWithUrlString:@"http://" name:nil] autorelease];
    int rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = bookmarkRoot;
    unsigned int idx = [[bookmarkRoot children] count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [[item children] indexOfObject:selectedItem] + 1;
        }
    }
    [item insertObject:bookmark inChildrenAtIndex:idx];
    
    int row = [outlineView rowForItem:bookmark];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [outlineView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)insertBookmarkFolder:(id)sender {
    BDSKBookmark *folder = [[[BDSKBookmark alloc] initFolderWithName:NSLocalizedString(@"Folder", @"default folder name")] autorelease];
    int rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = bookmarkRoot;
    unsigned int idx = [[bookmarkRoot children] count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [[item children] indexOfObject:selectedItem] + 1;
        }
    }
    [item insertObject:folder inChildrenAtIndex:idx];
    
    int row = [outlineView rowForItem:folder];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [outlineView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)insertBookmarkSeparator:(id)sender {
    BDSKBookmark *separator = [[[BDSKBookmark alloc] initSeparator] autorelease];
    int rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = bookmarkRoot;
    unsigned int idx = [[bookmarkRoot children] count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [[item children] indexOfObject:selectedItem] + 1;
        }
    }
    [item insertObject:separator inChildrenAtIndex:idx];
    
    int row = [outlineView rowForItem:separator];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

- (IBAction)deleteBookmark:(id)sender {
    [outlineView delete:sender];
}

#pragma mark Notification handlers

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification {
	NSString *error = nil;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:[[bookmarkRoot children] valueForKey:@"dictionaryValue"]
															  format:NSPropertyListXMLFormat_v1_0 
													errorDescription:&error];
	if (error) {
		NSLog(@"Error writing bookmarks: %@", error);
        [error release];
		return;
	}
	
	NSString *applicationSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser]; 
	NSString *bookmarksPath = [applicationSupportPath stringByAppendingPathComponent:@"Bookmarks.plist"];
	[data writeToFile:bookmarksPath atomically:YES];
}

- (void)endEditing {
    if ([outlineView editedRow] && [[self window] makeFirstResponder:outlineView] == NO)
        [[self window] endEditingFor:nil];
}

#pragma mark Undo support

- (NSUndoManager *)undoManager {
    if(undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender {
    return [self undoManager];
}

- (void)startObservingBookmarks:(NSArray *)newBookmarks {
    NSEnumerator *bmEnum = [newBookmarks objectEnumerator];
    BDSKBookmark *bm;
    while (bm = [bmEnum nextObject]) {
        if ([bm bookmarkType] != BDSKBookmarkTypeSeparator) {
            [bm addObserver:self forKeyPath:BDSKBookmarkNameKey options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:BDSKBookmarkPropertiesObservationContext];
            [bm addObserver:self forKeyPath:BDSKBookmarkUrlStringKey options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:BDSKBookmarkPropertiesObservationContext];
            if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
                [bm addObserver:self forKeyPath:BDSKBookmarkChildrenKey options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:BDSKBookmarkPropertiesObservationContext];
                [self startObservingBookmarks:[bm children]];
            }
        }
    }
}

- (void)stopObservingBookmarks:(NSArray *)oldBookmarks {
    NSEnumerator *bmEnum = [oldBookmarks objectEnumerator];
    BDSKBookmark *bm;
    while (bm = [bmEnum nextObject]) {
        if ([bm bookmarkType] != BDSKBookmarkTypeSeparator) {
            [bm removeObserver:self forKeyPath:BDSKBookmarkNameKey];
            [bm removeObserver:self forKeyPath:BDSKBookmarkUrlStringKey];
            if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
                [bm removeObserver:self forKeyPath:BDSKBookmarkChildrenKey];
                [self stopObservingBookmarks:[bm children]];
            }
        }
    }
}

- (void)insertObjects:(NSArray *)newChildren inChildrenOfBookmark:(BDSKBookmark *)bookmark atIndexes:(NSIndexSet *)indexes {
    [[bookmark mutableArrayValueForKey:BDSKBookmarkChildrenKey] insertObjects:newChildren atIndexes:indexes];
}

- (void)removeObjectsFromChildrenOfBookmark:(BDSKBookmark *)bookmark atIndexes:(NSIndexSet *)indexes {
    [[bookmark mutableArrayValueForKey:BDSKBookmarkChildrenKey] removeObjectsAtIndexes:indexes];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == BDSKBookmarkPropertiesObservationContext) {
        BDSKBookmark *bookmark = (BDSKBookmark *)object;
        id newValue = [change objectForKey:NSKeyValueChangeNewKey];
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        NSIndexSet *indexes = [change objectForKey:NSKeyValueChangeIndexesKey];
        
        if ([newValue isEqual:[NSNull null]]) newValue = nil;
        if ([oldValue isEqual:[NSNull null]]) oldValue = nil;
        
        switch ([[change objectForKey:NSKeyValueChangeKindKey] unsignedIntValue]) {
            case NSKeyValueChangeSetting:
                if ([keyPath isEqualToString:BDSKBookmarkChildrenKey]) {
                    NSMutableArray *old = [NSMutableArray arrayWithArray:oldValue];
                    NSMutableArray *new = [NSMutableArray arrayWithArray:newValue];
                    [old removeObjectsInArray:newValue];
                    [new removeObjectsInArray:oldValue];
                    [self stopObservingBookmarks:old];
                    [self startObservingBookmarks:new];
                    [[[self undoManager] prepareWithInvocationTarget:bookmark] setChildren:oldValue];
                } else if ([keyPath isEqualToString:BDSKBookmarkNameKey]) {
                    [(BDSKBookmark *)[[self undoManager] prepareWithInvocationTarget:bookmark] setName:oldValue];
                } else if ([keyPath isEqualToString:BDSKBookmarkUrlStringKey]) {
                    [[[self undoManager] prepareWithInvocationTarget:bookmark] setUrlString:oldValue];
                }
                break;
            case NSKeyValueChangeInsertion:
                if ([keyPath isEqualToString:BDSKBookmarkChildrenKey]) {
                    [self startObservingBookmarks:newValue];
                    [[[self undoManager] prepareWithInvocationTarget:self] removeObjectsFromChildrenOfBookmark:bookmark atIndexes:indexes];
                }
                break;
            case NSKeyValueChangeRemoval:
                if ([keyPath isEqualToString:BDSKBookmarkChildrenKey]) {
                    [self stopObservingBookmarks:oldValue];
                    [[[self undoManager] prepareWithInvocationTarget:self] insertObjects:oldValue inChildrenOfBookmark:bookmark atIndexes:indexes];
                }
                break;
            case NSKeyValueChangeReplacement:
                if ([keyPath isEqualToString:BDSKBookmarkChildrenKey]) {
                    [self stopObservingBookmarks:oldValue];
                    [self startObservingBookmarks:newValue];
                    [[[self undoManager] prepareWithInvocationTarget:self] removeObjectsFromChildrenOfBookmark:bookmark atIndexes:indexes];
                    [[[self undoManager] prepareWithInvocationTarget:self] insertObjects:oldValue inChildrenOfBookmark:bookmark atIndexes:indexes];
                }
                break;
        }
        
        [outlineView reloadData];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark NSOutlineView datasource methods

- (int)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
    if (item == nil) item = bookmarkRoot;
    return [[item children] count];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
    return [item bookmarkType] == BDSKBookmarkTypeFolder;
}

- (id)outlineView:(NSOutlineView *)ov child:(int)idx ofItem:(id)item {
    if (item == nil) item = bookmarkRoot;
    return [[item children]  objectAtIndex:idx];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"name"]) {
        return [NSDictionary dictionaryWithObjectsAndKeys:[item name], OATextWithIconCellStringKey, [item icon], OATextWithIconCellImageKey, nil];
    } else if ([tcID isEqualToString:@"url"]) {
        if ([item bookmarkType] == BDSKBookmarkTypeFolder) {
            int count = [[item children] count];
            return count == 1 ? NSLocalizedString(@"1 item", @"Bookmark folder description") : [NSString stringWithFormat:NSLocalizedString(@"%i items", @"Bookmark folder description"), count];
        } else {
            return [item urlString];
        }
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)ov setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"name"]) {
        if (object == nil)
            object = @"";
        if ([object isEqualToString:[item name]] == NO)
            [(BDSKBookmark *)item setName:object];
    } else if ([tcID isEqualToString:@"url"]) {
        if ([object length] == 0 || [NSURL URLWithString:object] == nil) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid URL", @"Message in alert dialog when setting an invalid URL") 
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"\"%@\" is not a valid URL.", @"Informative text in alert dialog"), object];
            [alert beginSheetModalForWindow:[self window]
                              modalDelegate:nil
                             didEndSelector:NULL
                                contextInfo:NULL];
            [outlineView reloadData];
        } else if ([object isEqualToString:[item urlString]] == NO) {
            [(BDSKBookmark *)item setUrlString:object];
        }
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
    [self setDraggedBookmarks:[self minimumCoverForBookmarks:items]];
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, nil] owner:nil];
    [pboard setData:[NSData data] forType:BDSKBookmarkRowsPboardType];
    return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    
    if ([type isEqualToString:BDSKBookmarkRowsPboardType]) {
        if (idx == NSOutlineViewDropOnItemIndex) {
            if ([item bookmarkType] == BDSKBookmarkTypeFolder && [outlineView isItemExpanded:item]) {
                [ov setDropItem:item dropChildIndex:0];
            } else if (item) {
                [ov setDropItem:(BDSKBookmark *)[item parent] == bookmarkRoot ? nil : [item parent] dropChildIndex:[[[item parent] children] indexOfObject:item] + 1];
            } else {
                [ov setDropItem:nil dropChildIndex:[[bookmarkRoot children] count]];
            }
        }
        return [item isDescendantOfArray:[self draggedBookmarks]] ? NSDragOperationNone : NSDragOperationMove;
    } else if (type) {
        if (idx == NSOutlineViewDropOnItemIndex && (item == nil || [item bookmarkType] != BDSKBookmarkTypeBookmark)) {
            if ([item bookmarkType] == BDSKBookmarkTypeFolder && [outlineView isItemExpanded:item]) {
                [ov setDropItem:item dropChildIndex:0];
            } else if (item) {
                [ov setDropItem:(BDSKBookmark *)[item parent] == bookmarkRoot ? nil : [item parent] dropChildIndex:[[[item parent] children] indexOfObject:item] + 1];
            } else {
                [ov setDropItem:nil dropChildIndex:[[bookmarkRoot children] count]];
            }
        }
        return NSDragOperationEvery;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    
    if (item == nil) item = bookmarkRoot;
    
    if ([type isEqualToString:BDSKBookmarkRowsPboardType]) {
        NSEnumerator *bmEnum = [[self draggedBookmarks] objectEnumerator];
        BDSKBookmark *bookmark;
				
        [self endEditing];
        
		while (bookmark = [bmEnum nextObject]) {
            BDSKBookmark *parent = [bookmark parent];
            int bookmarkIndex = [[parent children] indexOfObject:bookmark];
            if (item == parent) {
                if (idx > bookmarkIndex)
                    idx--;
                if (idx == bookmarkIndex)
                    continue;
            }
            [parent removeObjectFromChildrenAtIndex:bookmarkIndex];
            [(BDSKBookmark *)item insertObject:bookmark inChildrenAtIndex:idx++];
		}
        return YES;
    } else if (type) {
        NSString *urlString = nil;
        if ([type isEqualToString:BDSKWeblocFilePboardType])
            urlString = [pboard stringForType:BDSKWeblocFilePboardType];
        else if ([type isEqualToString:NSURLPboardType])
            urlString = [[NSURL URLFromPasteboard:pboard] absoluteString];
        if (urlString == nil)
            return NO;
        if (idx == NSOutlineViewDropOnItemIndex && [item bookmarkType] == BDSKBookmarkTypeBookmark) {
            [item setUrlString:urlString];
        } else {
            BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithUrlString:urlString name:nil];
            if (idx == NSOutlineViewDropOnItemIndex)
                idx = [[item children] count];
            [(BDSKBookmark *)item insertObject:bookmark inChildrenAtIndex:idx];
            [bookmark release];
        }
        return YES;
    }
    return NO;
}

- (void)tableView:(NSTableView *)aTableView concludeDragOperation:(NSDragOperation)operation {
    [self setDraggedBookmarks:nil];
}

#pragma mark NSOutlineView delegate methods

- (void)outlineView:(NSOutlineView *)ov willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([[tableColumn identifier] isEqualToString:@"url"]) {
        if ([item bookmarkType] == BDSKBookmarkTypeFolder)
            [cell setTextColor:[NSColor disabledControlTextColor]];
        else
            [cell setTextColor:[NSColor controlTextColor]];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([item bookmarkType] == BDSKBookmarkTypeBookmark)
        return YES;
    else if ([item bookmarkType] == BDSKBookmarkTypeFolder)
        return [[tableColumn identifier] isEqualToString:@"name"];
    return NO;
}

- (NSString *)outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation {
    NSString *tcID = [tc identifier];
    
    if ([tcID isEqualToString:@"name"]) {
        return [item name];
    } else if ([tcID isEqualToString:@"url"]) {
        return [item urlString];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv deleteRows:(NSArray *)rows {
    NSMutableArray *items = [NSMutableArray array];
    NSEnumerator *rowEnum = [rows objectEnumerator];
    NSNumber *row;
    
    while (row = [rowEnum nextObject])
        [items addObject:[outlineView itemAtRow:[row intValue]]];
    
    NSEnumerator *itemEnum = [[self minimumCoverForBookmarks:items] reverseObjectEnumerator];
    BDSKBookmark *item;
    
    [self endEditing];
    
    while (item = [itemEnum  nextObject]) {
        BDSKBookmark *parent = [item parent];
        unsigned int itemIndex = [[parent children] indexOfObject:item];
        if (itemIndex != NSNotFound)
            [parent removeObjectFromChildrenAtIndex:itemIndex];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov drawSeparatorRowForItem:(id)item {
    return [item bookmarkType] == BDSKBookmarkTypeSeparator;
}

#pragma mark Toolbar

- (void)setupToolbar {
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:BDSKBookmarksToolbarIdentifier] autorelease];
    OAToolbarItem *item;
    
    toolbarItems = [[NSMutableDictionary alloc] initWithCapacity:3];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeDefault];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Add template toolbar items
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewBookmarkToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Bookmark", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Bookmark", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Bookmark", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"NewBookmark"]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmark:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewBookmarkToolbarItemIdentifier];
    [item release];
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewFolderToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Folder", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"NewFolder"]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkFolder:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewFolderToolbarItemIdentifier];
    [item release];
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewSeparatorToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Separator", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"NewSeparator"]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkSeparator:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewSeparatorToolbarItemIdentifier];
    [item release];
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksDeleteToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Delete Selected Items", @"Tool tip message")];
    [item setImage:[NSImage imageWithSmallIconForToolboxCode:kToolbarDeleteIcon]];
    [item setTarget:self];
    [item setAction:@selector(deleteBookmark:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksDeleteToolbarItemIdentifier];
    [item release];
    
    // Attach the toolbar to the window
    [[self window] setToolbar:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)willBeInserted {
    NSToolbarItem *item = [toolbarItems objectForKey:itemIdent];
    if (willBeInserted == NO)
        item = [[item copy] autorelease];
    return item;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return [NSArray arrayWithObjects:
        BDSKBookmarksNewBookmarkToolbarItemIdentifier, 
        BDSKBookmarksNewFolderToolbarItemIdentifier, 
        BDSKBookmarksNewSeparatorToolbarItemIdentifier, 
        BDSKBookmarksDeleteToolbarItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [NSArray arrayWithObjects: 
        BDSKBookmarksNewBookmarkToolbarItemIdentifier, 
        BDSKBookmarksNewFolderToolbarItemIdentifier, 
        BDSKBookmarksNewSeparatorToolbarItemIdentifier, 
		BDSKBookmarksDeleteToolbarItemIdentifier, 
        NSToolbarFlexibleSpaceItemIdentifier, 
		NSToolbarSpaceItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, 
		NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
    NSString *identifier = [toolbarItem itemIdentifier];
    if ([identifier isEqualToString:BDSKBookmarksDeleteToolbarItemIdentifier]) {
        return [outlineView numberOfSelectedRows] > 0;
    } else {
        return YES;
    }
}

@end

#pragma mark -

@implementation WebView (BDSKExtensions)

- (IBAction)addBookmark:(id)sender {
	WebDataSource *datasource = [[self mainFrame] dataSource];
	NSString *URLString = [[[datasource request] URL] absoluteString];
	NSString *name = [datasource pageTitle];
	if(name == nil) name = [URLString lastPathComponent];
    
    if (URLString)
        [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:URLString proposedName:name modalForWindow:[self window]];
}

@end
