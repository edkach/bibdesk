//
//  BDSKOutlineView.h
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

#import <Cocoa/Cocoa.h>

@class BDSKTypeSelectHelper;

@interface BDSKOutlineView : NSOutlineView {
    BDSKTypeSelectHelper *typeSelectHelper;
    NSArray *draggedItems;
}

- (NSArray *)itemsAtRowIndexes:(NSIndexSet *)indexes;
- (NSArray *)selectedItems;

- (BDSKTypeSelectHelper *)typeSelectHelper;
- (void)setTypeSelectHelper:(BDSKTypeSelectHelper *)newTypeSelectHelper;

- (void)moveUp:(id)sender;
- (void)moveDown:(id)sender;
- (void)scrollToBeginningOfDocument:(id)sender;
- (void)scrollToEndOfDocument:(id)sender;
- (void)insertNewline:(id)sender;

- (void)delete:(id)sender;
- (void)copy:(id)sender;
- (void)cut:(id)sender;
- (void)paste:(id)sender;
- (void)duplicate:(id)sender;

- (BOOL)canDelete;
- (BOOL)canCopy;
- (BOOL)canCut;
- (BOOL)canPaste;
- (BOOL)canDuplicate;

- (NSFont *)font;
- (void)setFont:(NSFont *)font;

@end


@interface NSObject (BDSKOutlineViewDelegate)

- (void)outlineViewInsertNewline:(NSOutlineView *)anOutlineView;

- (NSMenu *)outlineView:(NSOutlineView *)anOutlineView menuForTableColumn:(NSTableColumn *)tableColumn item:(id)item;

- (NSArray *)outlineView:(NSOutlineView *)anOutlineView typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)aTypeSelectHelper;
- (void)outlineView:(NSOutlineView *)anOutlineView typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper didFailToFindMatchForSearchString:(NSString *)searchString;
- (void)outlineView:(NSOutlineView *)anOutlineView typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper updateSearchString:(NSString *)searchString;

@end


@interface NSObject (BDSKOutlineViewDataSource)

- (BOOL)outlineView:(NSOutlineView *)anOutlineView canCopyItems:(NSArray *)items;
- (void)outlineView:(NSOutlineView *)anOutlineView deleteItems:(NSArray *)items;
- (BOOL)outlineView:(NSOutlineView *)anOutlineView canDeleteItems:(NSArray *)items;
- (void)outlineView:(NSOutlineView *)anOutlineView pasteFromPasteboard:(NSPasteboard *)pboard;
- (BOOL)outlineViewCanPasteFromPasteboard:(NSOutlineView *)anOutlineView;
- (void)outlineView:(NSOutlineView *)anOutlineView duplicateItems:(NSArray *)items; // defaults to copy+paste
- (BOOL)outlineView:(NSOutlineView *)anOutlineView canDuplicateItems:(NSArray *)items;

- (NSDragOperation)outlineView:(NSOutlineView *)anOutlineView draggingSourceOperationMaskForLocal:(BOOL)flag;

- (NSImage *)outlineView:(NSOutlineView *)anOutlineView dragImageForItems:(NSArray *)items;

- (void)outlineView:(NSOutlineView *)anOutlineView concludeDragOperation:(NSDragOperation)operation;

@end