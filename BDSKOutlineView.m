//
//  BDSKOutlineView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/09.
/*
 This software is Copyright (c) 2009
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

#import "BDSKOutlineView.h"
#import "BDSKTypeSelectHelper.h"
#import "NSLayoutManager_BDSKExtensions.h"


@implementation BDSKOutlineView

- (NSArray *)itemsAtRowIndexes:(NSIndexSet *)indexes {
    NSMutableArray *items = [NSMutableArray array];
    unsigned int idx = [indexes firstIndex];
    
    while (idx != NSNotFound) {
        [items addObject:[self itemAtRow:idx]];
        idx = [indexes indexGreaterThanIndex:idx];
    }
    return items;
}

- (NSArray *)selectedItems {
    return [self itemsAtRowIndexes:[self selectedRowIndexes]];
}

- (BDSKTypeSelectHelper *)typeSelectHelper {
    return typeSelectHelper;
}

- (void)setTypeSelectHelper:(BDSKTypeSelectHelper *)newTypeSelectHelper {
    if (typeSelectHelper != newTypeSelectHelper) {
        if ([typeSelectHelper dataSource] == self)
            [typeSelectHelper setDataSource:nil];
        [typeSelectHelper release];
        typeSelectHelper = [newTypeSelectHelper retain];
        [typeSelectHelper setDataSource:self];
    }
}

- (void)expandItem:(id)item expandChildren:(BOOL)collapseChildren {
    [super expandItem:item expandChildren:collapseChildren];
    [typeSelectHelper rebuildTypeSelectSearchCache];
}

- (void)collapseItem:(id)item collapseChildren:(BOOL)collapseChildren {
    [super collapseItem:item collapseChildren:collapseChildren];
    [typeSelectHelper rebuildTypeSelectSearchCache];
}

- (void)reloadData {
    [super reloadData];
    [typeSelectHelper rebuildTypeSelectSearchCache];
}

- (void)keyDown:(NSEvent *)theEvent {
    NSString *characters = [theEvent charactersIgnoringModifiers];
    unichar eventChar = [characters length] > 0 ? [characters characterAtIndex:0] : 0;
    unsigned int modifierFlags = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    
	if ((eventChar == NSEnterCharacter || eventChar == NSFormFeedCharacter || eventChar == NSNewlineCharacter || eventChar == NSCarriageReturnCharacter) && modifierFlags == 0) {
        [self insertNewline:self];
    } else if (eventChar == NSHomeFunctionKey && (modifierFlags & ~NSFunctionKeyMask) == 0) {
        [self scrollToBeginningOfDocument:self];
    } else if (eventChar == NSEndFunctionKey && (modifierFlags & ~NSFunctionKeyMask) == 0) {
        [self scrollToEndOfDocument:self];
    } else if ([typeSelectHelper processKeyDownEvent:theEvent] == NO) {
        [super keyDown:theEvent];
    }
}

- (void)invertSelection:(id)sender {
    NSIndexSet *selRows = [self selectedRowIndexes];
    if ([self allowsMultipleSelection]) {
        NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])];
        [indexesToSelect removeIndexes:selRows];
        [self selectRowIndexes:indexesToSelect byExtendingSelection:NO];
    } else {
        NSBeep();
    }
}

- (void)moveUp:(id)sender {
    NSIndexSet *rowIndexes = [self selectedRowIndexes];
    unsigned int row = [rowIndexes firstIndex];
    if (row == NSNotFound) { // If nothing was selected
        unsigned int numberOfRows = [self numberOfRows];
        if (numberOfRows > 0) // If there are rows in the table
            row = numberOfRows - 1; // Select the last row
        else
            return; // There are no rows: do nothing
    } else if (row > 0) {
        row--;
    }

    if ([self delegate] && [[self delegate] respondsToSelector:@selector(outlineView:shouldSelectItem:)])
        while ([[self delegate] outlineView:self shouldSelectItem:[self itemAtRow:row]] == NO)
            if (row-- == 0)
                return;	// If we never find a selectable row, don't do anything
    
    // If the first row was selected, select only the first row.  This is consistent with the behavior of many Apple apps.
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self scrollRowToVisible:row];
}

- (void)moveDown:(id)sender {
    NSIndexSet *rowIndexes = [self selectedRowIndexes];
    unsigned int row = [rowIndexes lastIndex], numberOfRows = [self numberOfRows];
    if (row == NSNotFound) { // If nothing was selected
        if (numberOfRows > 0) // If there are rows in the table
            row = 0; // Select the first row
        else
            return; // There are no rows: do nothing
    } else if (row < numberOfRows - 1) {
        ++row;
    }
    
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(outlineView:shouldSelectItem:)])
        while ([[self delegate] outlineView:self shouldSelectItem:[self itemAtRow:row]] == NO)
            if (++row > numberOfRows - 1)
                return;	// If we never find a selectable row, don't do anything
        
    // If the first row was selected, select only the first row.  This is consistent with the behavior of many Apple apps.
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self scrollRowToVisible:row];
}

- (void)scrollToBeginningOfDocument:(id)sender {
    if ([self numberOfRows])
        [self scrollRowToVisible:0];
}

- (void)scrollToEndOfDocument:(id)sender {
    if ([self numberOfRows])
        [self scrollRowToVisible:[self numberOfRows] - 1];
}

- (void)insertNewline:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(outlineViewInsertNewline:)])
        [[self delegate] outlineViewInsertNewline:self];
}

- (BOOL)canDelete {
    if ([self numberOfSelectedRows] == 0 || [[self dataSource] respondsToSelector:@selector(outlineView:deleteItems:)] == NO)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(outlineView:canDeleteItems:)])
        return [[self dataSource] outlineView:self canDeleteItems:[self selectedItems]];
    else
        return YES;
}

- (void)delete:(id)sender {
    if ([self canDelete]) {
        unsigned int originalNumberOfRows = [self numberOfRows];
        // -selectedRow is last row of multiple selection, no good for trying to select the row before the selection.
        unsigned int selectedRow = [[self selectedRowIndexes] firstIndex];
        [[self dataSource] outlineView:self deleteItems:[self selectedItems]];
        [self reloadData];
        unsigned int newNumberOfRows = [self numberOfRows];
        
        // Maintain an appropriate selection after deletions
        if (originalNumberOfRows != newNumberOfRows) {
            if (selectedRow == 0) {
                if ([[self delegate] respondsToSelector:@selector(outlineView:shouldSelectItem:)]) {
                    if ([[self delegate] outlineView:self shouldSelectItem:[self itemAtRow:0]])
                        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                    else
                        [self moveDown:nil];
                } else {
                    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                }
            } else {
                // Don't try to go past the new # of rows
                selectedRow = MIN(selectedRow - 1, newNumberOfRows - 1);
                
                // Skip all unselectable rows if the delegate responds to -outlineView:shouldSelectItem:
                if ([[self delegate] respondsToSelector:@selector(outlineView:shouldSelectItem:)]) {
                    while (selectedRow > 0 && [[self delegate] outlineView:self shouldSelectItem:[self itemAtRow:selectedRow]] == NO)
                        selectedRow--;
                }
                
                // If nothing was selected, move down (so that the top row is selected)
                if (selectedRow < 0)
                    [self moveDown:nil];
                else
                    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
            }
        }
    } else
        NSBeep();
}

- (BOOL)canCopy {
    if ([self numberOfSelectedRows] == 0 || [[self dataSource] respondsToSelector:@selector(outlineView:writeItems:toPasteboard:)] == NO)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(outlineView:canCopyItems:)])
        return [[self dataSource] outlineView:self canCopyItems:[self selectedItems]];
    else
        return YES;
}

- (void)copy:(id)sender {
    if ([self canCopy])
        [[self dataSource] outlineView:self writeItems:[self selectedItems] toPasteboard:[NSPasteboard generalPasteboard]];
    else
        NSBeep();
}

- (BOOL)canCut {
    return [self canDelete] && [self canCopy];
}

- (void)cut:(id)sender {
    if ([self canCut] && [[self dataSource] outlineView:self writeItems:[self selectedItems] toPasteboard:[NSPasteboard generalPasteboard]])
        [self delete:sender];
    else
        NSBeep();
}

- (BOOL)canPaste {
    if ([[self dataSource] respondsToSelector:@selector(outlineView:pasteFromPasteboard:)] == NO)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(outlineViewCanPasteFromPasteboard:)])
        return [[self dataSource] outlineViewCanPasteFromPasteboard:self];
    else
        return YES;
}

- (void)paste:(id)sender {
    if ([self canPaste])
        [[self dataSource] outlineView:self pasteFromPasteboard:[NSPasteboard generalPasteboard]];
    else
        NSBeep();
}

- (BOOL)canDuplicate {
    if ([self numberOfSelectedRows] == 0)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(outlineView:canDuplicateItems:)])
        return [[self dataSource] outlineView:self canDuplicateItems:[self selectedItems]];
    else if ([[self dataSource] respondsToSelector:@selector(outlineView:duplicateItems:)])
        return YES;
    else
        return [self canPaste] && [self canCopy];
}

- (void)duplicate:(id)sender {
    if ([self canDuplicate]) {
        if ([[self dataSource] respondsToSelector:@selector(outlineView:duplicateItems:)]) {
            [[self dataSource] outlineView:self duplicateItems:[self selectedItems]];
        } else {
            NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
            if ([[self dataSource] outlineView:self writeItems:[self selectedItems] toPasteboard:pboard])
                [[self dataSource] outlineView:self pasteFromPasteboard:pboard];
        }
    } else
        NSBeep();
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag {
    if ([[self dataSource] respondsToSelector:@selector(outlineView:draggingSourceOperationMaskForLocal:)])
        return [[self dataSource] outlineView:self draggingSourceOperationMaskForLocal:flag];
    else if (flag)
        return NSDragOperationEvery;
    else
        return NSDragOperationNone;        
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation {
    [super draggedImage:anImage endedAt:aPoint operation:operation];
	
    // We get NSDragOperationDelete now for dragging to the Trash.
    if (operation == NSDragOperationDelete && [draggedItems count] && [[self dataSource] respondsToSelector:@selector(outlineView:deleteItems:)] &&
        ([[self dataSource] respondsToSelector:@selector(outlineView:canDeleteItems:)] == NO || [[self dataSource] outlineView:self canDeleteItems:draggedItems])) {
        [[self dataSource] outlineView:self deleteItems:draggedItems];
        [self reloadData];
    }
    [draggedItems release];
    draggedItems = nil;
            
    if([[self dataSource] respondsToSelector:@selector(outlineView:concludeDragOperation:)]) 
		[[self dataSource] outlineView:self concludeDragOperation:operation];
    
    // flag changes during a drag are not forwarded to the application, so we fix that at the end of the drag
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset{
   	[draggedItems release];
    draggedItems = [[self itemsAtRowIndexes:dragRows] retain];
    
    if([[self dataSource] respondsToSelector:@selector(outlineView:dragImageForItems:)]) {
		NSImage *image = [[self dataSource] outlineView:self dragImageForItems:draggedItems];
		if (image != nil)
			return image;
	}
    return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(delete:))
        return [self canDelete];
    else if ([menuItem action] == @selector(copy:))
        return [self canCopy];
    else if ([menuItem action] == @selector(cut:))
        return [self canCut];
    else if ([menuItem action] == @selector(paste:))
        return [self canPaste];
    else if ([menuItem action] == @selector(duplicate:))
        return [self canDuplicate];
    else if ([menuItem action] == @selector(selectAll:))
        return [self allowsMultipleSelection];
    else if ([menuItem action] == @selector(deselectAll:))
        return [self allowsEmptySelection];
    else if ([menuItem action] == @selector(insertNewline:))
        return [[self delegate] respondsToSelector:@selector(outlineViewInsertNewline:)];
    else if ([menuItem action] == @selector(invertSelection:))
        return [self allowsMultipleSelection];
    else if ([[BDSKOutlineView superclass] instancesRespondToSelector:@selector(validateMenuItem:)])
        return [super validateMenuItem:menuItem];
    else
        return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *menu = nil;
    
    if ([[self delegate] respondsToSelector:@selector(outlineView:menuForTableColumn:item:)]) {
        NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        int row = [self rowAtPoint:mouseLoc];
        int column = [self columnAtPoint:mouseLoc];
        if (row != -1 && column != -1) {
            NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:column];
            menu = [[self delegate] outlineView:self menuForTableColumn:tableColumn item:[self itemAtRow:row]];
        }
    }
    
	return menu;
}

- (NSFont *)font {
    NSEnumerator *tcEnum = [[self tableColumns] objectEnumerator];
    NSTableColumn *tc;
    
    while (tc = [tcEnum nextObject]) {
        NSCell *cell = [tc dataCell];
        if ([cell type] == NSTextCellType)
            return [cell font];
    }
    return nil;
}

- (void)setFont:(NSFont *)font {
    NSEnumerator *tcEnum = [[self tableColumns] objectEnumerator];
    NSTableColumn *tc;
    
    while (tc = [tcEnum nextObject]) {
        NSCell *cell = [tc dataCell];
        if ([cell type] == NSTextCellType)
            [cell setFont:font];
    }
    
    [self setRowHeight:[NSLayoutManager defaultViewLineHeightForFont:font]];
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])]];
}

#pragma mark SKTypeSelectHelper datasource protocol

- (NSArray *)typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)aTypeSelectHelper {
    if ([[self delegate] respondsToSelector:@selector(outlineView:typeSelectHelperSelectionItems:)])
        return [[self delegate] outlineView:self typeSelectHelperSelectionItems:aTypeSelectHelper];
    return nil;
}

- (unsigned int)typeSelectHelperCurrentlySelectedIndex:(BDSKTypeSelectHelper *)aTypeSelectHelper {
    return [[self selectedRowIndexes] lastIndex];
}

- (void)typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper selectItemAtIndex:(unsigned int)itemIndex {
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
    [self scrollRowToVisible:itemIndex];
}

- (void)typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper didFailToFindMatchForSearchString:(NSString *)searchString {
    if ([[self delegate] respondsToSelector:@selector(outlineView:typeSelectHelper:didFailToFindMatchForSearchString:)])
        [[self delegate] outlineView:self typeSelectHelper:aTypeSelectHelper didFailToFindMatchForSearchString:searchString];
}

- (void)typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper updateSearchString:(NSString *)searchString {
    if ([[self delegate] respondsToSelector:@selector(outlineView:typeSelectHelper:updateSearchString:)])
        [[self delegate] outlineView:self typeSelectHelper:aTypeSelectHelper updateSearchString:searchString];
}

@end
