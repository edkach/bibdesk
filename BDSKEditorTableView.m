//
//  BDSKEditorTableView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/11/07.
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

#import "BDSKEditorTableView.h"
#import "BDSKEditorTextFieldCell.h"
#import "BDSKFieldEditor.h"


@implementation BDSKEditorTableView

- (void)mouseDown:(NSEvent *)theEvent {
    
    NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    int clickedColumn = [self columnAtPoint:location];
    int clickedRow = [self rowAtPoint:location];
    NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:clickedColumn];
    
    if (clickedRow != -1 && clickedColumn != -1) {
        NSRect cellFrame = [self frameOfCellAtColumn:clickedColumn row:clickedRow];
        id cell = [tableColumn dataCellForRow:clickedRow];
        BOOL isEditable = [tableColumn isEditable] && 
                ([[self delegate] respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)] == NO || 
                 [[self delegate] tableView:self shouldEditTableColumn:tableColumn row:clickedRow]);
        if ([[self delegate] respondsToSelector:@selector(tableView:willDisplayCell:forTableColumn:row:)])
            [[self delegate] tableView:self willDisplayCell:cell forTableColumn:tableColumn row:clickedRow];
        if ([cell respondsToSelector:@selector(buttonRectForBounds:)] &&
            NSMouseInRect(location, [cell buttonRectForBounds:cellFrame], [self isFlipped])) {
            if ([theEvent clickCount] > 1)
                theEvent = [NSEvent mouseEventWithType:[theEvent type] location:[theEvent locationInWindow] modifierFlags:[theEvent modifierFlags] timestamp:[theEvent timestamp] windowNumber:[theEvent windowNumber] context:[theEvent context] eventNumber:[theEvent eventNumber] clickCount:1 pressure:[theEvent pressure]];
        } else if ([cell isKindOfClass:[NSTextFieldCell class]] && isEditable) {
            if ([[self window] makeFirstResponder:nil]) {
                [self selectRowIndexes:[NSIndexSet indexSetWithIndex:clickedRow] byExtendingSelection:NO];
                [self editColumn:clickedColumn row:clickedRow withEvent:theEvent select:NO];
            }
            return;
        } else if (isEditable == NO && ([theEvent clickCount] != 2 || [self doubleAction] == NULL)) {
            return;
        }
    }
	[super mouseDown:theEvent];
}

- (void)textDidEndEditing:(NSNotification *)aNotification {
    int editedRow = [self editedRow];
    int editedColumn = [self editedColumn];
    
    endEditing = YES;
    [super textDidEndEditing:aNotification];
    endEditing = NO;
    
    // on Leopard, we have to manually handle tab/return movements to avoid losing focus
    // http://www.cocoabuilder.com/archive/message/cocoa/2007/10/31/191866
    
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
        int movement = [[[aNotification userInfo] objectForKey:@"NSTextMovement"] intValue];
        if ((editedRow != -1 && editedColumn != -1) && 
            (NSTabTextMovement == movement || NSBacktabTextMovement == movement || NSReturnTextMovement == movement)) {
            
            // assume NSReturnTextMovement
            int nextRow = editedRow;
            if (NSBacktabTextMovement == movement)
                nextRow = editedRow - 1;
            else if (NSTabTextMovement == movement)
                nextRow = editedRow + 1;
            
            if (nextRow < [self numberOfRows] && nextRow >= 0) {
            
                NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:editedColumn];
                BOOL isEditable = [tableColumn isEditable] && 
                                  ([[self delegate] respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)] == NO || 
                                   [[self delegate] tableView:self shouldEditTableColumn:tableColumn row:nextRow]);
                
                if (isEditable) {
                    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:nextRow] byExtendingSelection:NO];
                    [self editColumn:editedColumn row:nextRow withEvent:nil select:YES];
                }
            }
        }
    }
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect {}

- (BOOL)becomeFirstResponder {
    if ([super becomeFirstResponder]) {
        if ([self editedRow] == -1 && endEditing == NO) {
            int row = -1, column, numRows = [self numberOfRows], numCols = [self numberOfColumns];
            switch ([[self window] keyViewSelectionDirection]) {
                case NSSelectingNext:
                    row = 0;
                    break;
                case NSSelectingPrevious:
                    row = numRows - 1;
                    break;
                default:
                    break;
            }
            if (row != -1 && row < numRows) {
                for (column = 0; column < numCols; column++) {
                    NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:column];
                    BOOL isEditable = [tableColumn isEditable] && 
                                      ([[self delegate] respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)] == NO || 
                                       [[self delegate] tableView:self shouldEditTableColumn:tableColumn row:row]);
                    if (isEditable) {
                        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                        [self editColumn:column row:row withEvent:nil select:YES];
                        break;
                    }
                }
            }
        }
        return YES;
    } else {
        return NO;
    }
}

@end
