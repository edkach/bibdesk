//  BibDocument_DataSource.m

//  Created by Michael McCracken on Tue Mar 26 2002.
/*
This software is Copyright (c) 2001,2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#import "BibDocument.h"
#import "BibItem.h"
#import "BibDocument_DataSource.h"

@class BibAuthor;

@implementation BibDocument (DataSource)

//
#pragma mark ||  Methods that support the outline view
//


- (void)outlineViewColumnDidResize:(NSNotification *)notification{
    [self tableViewColumnDidResize:notification];
}

- (void)outlineViewColumnDidMove:(NSNotification *)notification{
    [self tableViewColumnDidMove:notification];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification{
    [self tableViewSelectionDidChange:aNotification];
}

- (int)outlineView:(NSOutlineView *)oView numberOfChildrenOfItem:(id)item {
    if(item == nil){
        return [allAuthors count];
    }else{
        return [item numberOfChildren];
    }
}

- (BOOL)outlineView:(NSOutlineView *)oView isItemExpandable:(id)item {
    if(item == nil)
        return YES;
    else
        return ([item numberOfChildren] != 0);
}

- (id)outlineView:(NSOutlineView *)oView child:(int)index ofItem:(id)item {
    BibItem *bi = (BibItem *)item;
    if(item == nil){
        //       //NSLog(@"trying to give it %@",  [allAuthors objectAtIndex:index]);
        return [allAuthors objectAtIndex:index];
    }
    else{
        return [bi pubAtIndex: index];
    }
}

- (id)outlineView:(NSOutlineView *)oView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    BibItem *bi = (BibItem *)item;
    NSMutableString *value = [NSMutableString stringWithString:@""];
    NSString *s;
    
    if(bi == nil) {
#if DEBUG
        //NSLog(@"objvalue called for nil");
#endif
        return @"nil";
    }
    //this needs more work. -- might want to do something entirely special for the column that
    // displays the collapsor...
    if([bi numberOfChildren] > 0){
        if(tableColumn == [oView outlineTableColumn]){
            [value appendString: [bi name]];
        }else{
            [value appendString: @""];
        }
    }else{

        if([[tableColumn identifier] isEqualToString: @"Cite Key"] ){
            [value appendString: [bi citeKey]];
        }else if([[tableColumn identifier] isEqualToString: @"Title"] ){
            [value appendString: [bi title]];
        }else if([[tableColumn identifier] isEqualToString: @"Date"] ){
            if([bi date] == nil)
                [value appendString: @"No date"];
            else if([[bi valueOfField:@"Month"] isEqualToString:@""])
                [value appendString: [[bi date] descriptionWithCalendarFormat:@"%Y"]];
            else [value appendString: [[bi date] descriptionWithCalendarFormat:@"%b %Y"]];
        }else{
            // the tableColumn isn't something we handle in a custom way.
            s = [bi valueOfField:[tableColumn identifier]];
            if(s)
                [value appendString:s]; // might append nil, should be OK.
        }
    }

    return value;
}



// Delegate methods for outline view

- (BOOL)outlineView:(NSOutlineView *)oView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)olv
         writeItems:(NSArray*)items
       toPasteboard:(NSPasteboard*)pboard{
    NSEnumerator *itemsE = [items objectEnumerator];
    NSMutableArray *rowIndexArray = [[NSMutableArray alloc] initWithCapacity:10]; // rowIndexArray needs to become an index into shownPublications.
    id item = nil;
    NSEnumerator *childE = nil;
    id child = nil;
    
    while(item = [itemsE nextObject]){
        if([item isKindOfClass:[BibItem class]]){
            [rowIndexArray addObject:[NSNumber numberWithInt:[shownPublications indexOfObjectIdenticalTo:item]]];
        }else if([item isKindOfClass:[BibAuthor class]]){
            childE = [[item children] objectEnumerator];
            while(child = [childE nextObject]){
                if ([rowIndexArray indexOfObjectIdenticalTo:child] == NSNotFound) {
                    [rowIndexArray addObject:[NSNumber numberWithInt:[shownPublications indexOfObjectIdenticalTo:child]]];
                }
            }
        }
    }
    return [self tableView:outlineView writeRows:rowIndexArray toPasteboard:pboard];
}
    // This method is called after it has been determined that a drag should begin, but before the drag has been started.  To refuse the drag, return NO.  To start a drag, return YES and place the drag data onto the pasteboard (data, owner, etc...).  The drag image and other drag related information will be set up and provided by the outline view once this call returns with YES.  The items array is the list of items that will be participating in the drag.

- (NSDragOperation)outlineView:(NSOutlineView*)olv
                  validateDrop:(id <NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(int)index{
    if ([info draggingSource]) {
        if([info draggingSource] == outlineView)
        {
            // for now, we won't allow move onto same table
            return NSDragOperationNone;
        }
        [olv setDropRow:0 dropOperation:NSDragOperationCopy];
        return NSDragOperationCopy;
    }else{
        //it's not from me
        [olv setDropRow:0 dropOperation:NSDragOperationCopy];
        return NSDragOperationEvery; // if it's not from me, copying is OK
    }
}
// This method is used by NSOutlineView to determine a valid drop target.  Based on the mouse position, the outline view will suggest a proposed drop location.  This method must return a value that indicates which dragging operation the data source will perform.  The data source may "re-target" a drop if desired by calling setDropItem:dropChildIndex: and returning something other than NSDragOperationNone.  One may choose to re-target for various reasons (eg. for better visual feedback when inserting into a sorted position).

- (BOOL)outlineView:(NSOutlineView*)olv
         acceptDrop:(id <NSDraggingInfo>)info
               item:(id)item
         childIndex:(int)index{
    return NO;
}
    // This method is called when the mouse is released over an outline view that previously decided to allow a drop via the validateDrop method.  The data source should incorporate the data from the dragging pasteboard at this time.


//
#pragma mark ||  Methods to support table view.
//

- (void)tableView: (NSTableView *)aTableView willDisplayCell: (id)aCell
   forTableColumn: (NSTableColumn *)aTableColumn row: (int)aRowIndex
{
    [aCell setDrawsBackground: ((aRowIndex % 2) == 0)];
}

- (int)numberOfRowsInTableView:(NSTableView *)tView{
    if(tView == (NSTableView *)tableView){
        return [shownPublications count];
    }else if(tView == (NSTableView *)ccTableView){
        return [customStringArray count];
    }else{
// should raise an exception or something
        return 0;
    }
}

- (id)tableView:(NSTableView *)tView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    BibItem* pub = nil;
    NSArray *auths = nil;

    NSMutableString *value = [NSMutableString stringWithString:@""];
    NSString *s;
      
    if(tView == tableView){
        pub = [shownPublications objectAtIndex:row];
        auths = [pub pubAuthors];
        if([[tableColumn identifier] isEqualToString: @"Cite Key"] ){
            [value appendString: [pub citeKey]];
        }else if([[tableColumn identifier] isEqualToString: @"Title"] ){
            [value appendString: [pub title]];
        }else if([[tableColumn identifier] isEqualToString: @"Date"] ){
            if([pub date] == nil)
                [value appendString: @"No date"];
            else if([[pub valueOfField:@"Month"] isEqualToString:@""])
                [value appendString: [[pub date] descriptionWithCalendarFormat:@"%Y"]];
            else [value appendString: [[pub date] descriptionWithCalendarFormat:@"%b %Y"]];
        }else if([[tableColumn identifier] isEqualToString: @"1st Author"] ){
            if([auths count] > 0)
                [value appendString: [pub authorAtIndex:0]];
            else
                [value appendString: @"-"];
        }else if([[tableColumn identifier] isEqualToString: @"2nd Author"] ){
            if([auths count] > 1)
                [value appendString: [pub authorAtIndex:1]];
            else
                [value appendString: @"-"];
        }else if([[tableColumn identifier] isEqualToString: @"3rd Author"] ){
            if([auths count] > 2)
                [value appendString: [pub authorAtIndex:2]];
            else
                [value appendString: @"-"];
        }else{
            // the tableColumn isn't something we handle in a custom way.
            s = [pub valueOfField:[tableColumn identifier]];
            if(s)
                [value appendString:s]; // might append nil, should be OK.
        }

        return value;
    }else if(tView == (NSTableView *)ccTableView){
        return [customStringArray objectAtIndex:row];
    }
    else return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    [self updatePreviews:aNotification];
}


- (void)tableViewColumnDidResize:(NSNotification *)notification{
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    NSMutableDictionary *columns = [[[pw objectForKey:BDSKColumnWidthsKey] mutableCopy] autorelease];
    NSEnumerator *tcE = [[[notification object] tableColumns] objectEnumerator];
    NSTableColumn *tc = nil;

    if (!columns) columns = [NSMutableDictionary dictionaryWithCapacity:5];

    while(tc = (NSTableColumn *) [tcE nextObject]){
        [columns setObject:[NSNumber numberWithFloat:[tc width]]
                    forKey:[tc identifier]];
    }
    ////NSLog(@"tableViewColumnDidResize - setting %@ forKey: %@ ", columns, BDSKColumnWidthsKey);
    [pw setObject:columns forKey:BDSKColumnWidthsKey];
}


- (void)tableViewColumnDidMove:(NSNotification *)notification{
    NSMutableArray *columnsInOrder = [NSMutableArray arrayWithCapacity:5];

    NSEnumerator *tcE = [[[notification object] tableColumns] objectEnumerator];
    NSTableColumn *tc = nil;

    while(tc = (NSTableColumn *) [tcE nextObject]){
        [columnsInOrder addObject:[tc identifier]];
    }

    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:columnsInOrder
                                                      forKey:BDSKShownColsNamesKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentUpdateUINotification
                                                        object:nil];

}



// drag and drop support

// This method is called after it has been determined that a drag should begin, but before the drag has been started.  To refuse the drag, return NO.  To start a drag, return YES and place the drag data onto the pasteboard (data, owner, etc...).  The drag image and other drag related information will be set up and provided by the table view once this call returns with YES.  The rows array is the list of row numbers that will be participating in the drag.

- (BOOL)tableView:(NSTableView *)tv
        writeRows:(NSArray*)rows
     toPasteboard:(NSPasteboard*)pboard{
    OFPreferenceWrapper *sud = [OFPreferenceWrapper sharedPreferenceWrapper];
    BOOL yn;
    NSString *startCite = [NSString stringWithFormat:@"\\%@{",[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKCiteStringKey]];
#warning - extra spurious retain? not sure.
    NSMutableString *s = [[NSMutableString string] retain]; 
    NSMutableString *localPBString = [NSMutableString string];
    NSEnumerator *enumerator;
    NSNumber *i;
    BOOL sep = ([[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKSeparateCiteKey] == NSOnState);

    int dragType = [[sud objectForKey:BDSKDragCopyKey] intValue];

    NSEnumerator *selRowE;
    NSNumber *idx;
    NSMutableArray* newRows;

    if([tv numberOfSelectedRows] == 0) return NO;
    
    if(tv == (NSTableView *)ccTableView){
        startCite = [NSString stringWithFormat:@"\\%@{",[customStringArray objectAtIndex:[[rows objectAtIndex:0] intValue]]]; // rows oi:0 is ok because we don't allow multiple selections in ccTV.
        
        // if it's the ccTableView, then rows has the rows of the ccTV.
        // we need to change rows to be the main TV's selected rows,
        // so that the regular code still works           
        newRows = [NSMutableArray arrayWithCapacity:10];
        selRowE = [tv selectedRowEnumerator];
        while(idx = [selRowE nextObject]){
            [newRows addObject:idx];
        }
        rows = [NSArray arrayWithArray:newRows];
        ////NSLog(@"rows is %@", rows);
    }

    enumerator = [rows objectEnumerator];
        if((dragType == 1) && !sep)
            [s appendString:startCite];

        while (i = [enumerator nextObject]) {
            [localPBString appendString:[[shownPublications objectAtIndex:[i intValue]] bibTeXString]];
            if((dragType == 0) ||
               (dragType == 2)){
                [s appendString:[[shownPublications objectAtIndex:[i intValue]] bibTeXString]];
            }
            if(dragType == 1){
                if(sep) [s appendString:startCite];
                [s appendString:[[shownPublications objectAtIndex:[i intValue]] citeKey]];
                if(sep) [s appendString:@"}"];
                else [s appendString:@", "];
            }
        }// end while

        if(dragType == 1){
            if(!sep)[s replaceCharactersInRange:[s rangeOfString:@", " options:NSBackwardsSearch] withString:@"}"];
        }
        if((dragType == 0) ||
           (dragType == 1)){
            [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
            yn = [pboard setString:s forType:NSStringPboardType];
        }else{
            [pboard declareTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:nil];
            yn = [pboard setData:[PDFpreviewer PDFDataFromString:s] forType:NSPDFPboardType];
        }
        [localDragPboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [localDragPboard setString:localPBString forType:NSStringPboardType];
        return yn;

}


// This method is used by NSTableView to determine a valid drop target.  Based on the mouse position, the table view will suggest a proposed drop location.  This method must return a value that indicates which dragging operation the data source will perform.  The data source may "re-target" a drop if desired by calling setDropRow:dropOperation: and returning something other than NSDragOperationNone.  One may choose to re-target for various reasons (eg. for better visual feedback when inserting into a sorted position).
- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row
       proposedDropOperation:(NSTableViewDropOperation)op{
    if(tv == (NSTableView *)ccTableView){
        return NSDragOperationNone;// can't drag into that tv.
    }
    if ([info draggingSource]) {
       if([info draggingSource] == tableView)
       {
           // can't copy onto same table
           return NSDragOperationNone;
       }
        [tv setDropRow:[tv numberOfRows] dropOperation:NSDragOperationCopy];
        return NSDragOperationCopy;    
    }else{
        //it's not from me
        [tv setDropRow:[tv numberOfRows] dropOperation:NSDragOperationCopy];
        return NSDragOperationEvery; // if it's not from me, copying is OK
    }
}

// This method is called when the mouse is released over an outline view that previously decided to allow a drop via the validateDrop method.  The data source should incorporate the data from the dragging pasteboard at this time.
- (BOOL)tableView:(NSTableView*)tv
       acceptDrop:(id <NSDraggingInfo>)info
              row:(int)row
    dropOperation:(NSTableViewDropOperation)op{

    BibItem *newBI;
    NSPasteboard *pb;
    NSMutableArray *newBIs;
    NSEnumerator *fileNameEnum;
    NSString *pbString;
    NSArray *pbArray;
    NSArray *newPubs;
    NSEnumerator *newPubE;
    NSString *fnStr;
    NSArray *types;
    NSURL *url;
    BOOL hadProblems = NO;

    if(tv == (NSTableView *)ccTableView){
        return NO; // can't drag into that tv.
    }
    
    if([info draggingSource]){
        pb = localDragPboard;     // it's really local, so use the local pboard.
    }else{
       // pb = [NSPasteboard  pasteboardWithName:NSDragPboard];
        pb = [info draggingPasteboard];
    }
    types = [pb types];
#if DEBUG
    //NSLog(@"types is %@", types);
    //NSLog(@"pb is %@ and \n sender dpb is %@", pb, [info draggingPasteboard]);
#endif
    

    if([pb containsFiles]){
        // won't handle more than one right away! ? sure we wll, why not...
        newBIs = [NSMutableArray array];
        pbArray = [pb propertyListForType:NSFilenamesPboardType]; // we will get an array
        pbString = [pb stringForType:NSURLPboardType]; // we will get an array
#if DEBUG
        //NSLog(@"got filenames %@", pbArray);
#endif
        fileNameEnum = [pbArray objectEnumerator];
        while(fnStr = [fileNameEnum nextObject]){
            if(url = [NSURL fileURLWithPath:fnStr]){
                newBI = [[BibItem alloc] init];
                [publications addObject:newBI];
                [shownPublications addObject:newBI];
                [newBI setField:@"Local-Url" toValue:[[NSURL fileURLWithPath:
                    [fnStr stringByExpandingTildeInPath]]absoluteString]];
                [self updateUI];
                [self updateChangeCount:NSChangeDone];

                if([[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKEditOnPasteKey] == NSOnState){
                    [self editPub:newBI forceChange:YES];
                    //[[newBI editorObj] fixEditedStatus];  - deprecated
                }
            }
        }
        return YES;
    }else if([types containsObject:NSStringPboardType]){
        pbString = [pb stringForType:NSStringPboardType];
       // //NSLog(@"<STRING IS>%@ </STRING IS>", pbString);
        newPubs = [BibTeXParser itemsFromString:pbString
                                          error:&hadProblems];
        if(hadProblems) return NO;
            
        newPubE = [newPubs objectEnumerator];
        
        while(newBI = [newPubE nextObject]){

            if (newBI != nil) {
                [publications addObject:newBI];
                [shownPublications addObject:newBI];
                [self updateUI];
                [self updateChangeCount:NSChangeDone];
                if([[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKEditOnPasteKey] == NSOnState)
                    [self editPub:newBI forceChange:YES];
            }else{

            }
        }
    }else{
        return NO;
    }
    
    [self updateUI];
    return YES;
}


#pragma mark || Methods to support the type-ahead selector.
- (NSArray *)typeAheadSelectionItems{
    NSEnumerator *e = [shownPublications objectEnumerator];
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:10];
    BibItem *pub = nil;

    while(pub = [e nextObject]){
        [a addObject:[pub authorString]];
    }
    return a;
}
    // This is where we build the list of possible items which the user can select by typing the first few letters. You should return an array of NSStrings.

- (NSString *)currentlySelectedItem{
    int n = [self numberOfSelectedPubs];
    BibItem *bib;
    if (n == 1){
        bib = [shownPublications objectAtIndex:[[[self selectedPubEnumerator] nextObject] intValue]];
        return [bib authorString];
    }else{
        return nil;
    }
}
// Type-ahead-selection behavior can change if an item is currently selected (especially if the item was selected by type-ahead-selection). Return nil if you have no selection or a multiple selection.

// fixme -  also need to call the processkeychars in keydown...
- (void)typeAheadSelectItemAtIndex:(int)itemIndex{
    [self highlightBib:[shownPublications objectAtIndex:itemIndex] byExtendingSelection:NO];
}
// We call this when a type-ahead-selection match has been made; you should select the item based on its index in the array you provided in -typeAheadSelectionItems.



@end


// From JCR:
//To make it more readable, I'd added this category to NSPasteboard:

@implementation NSPasteboard (JCRDragWellExtensions)

- (BOOL) hasType:aType /*"Returns TRUE if aType is one of the types
available from the receiving pastebaord."*/
{ return ([[self types] indexOfObject:aType] == NSNotFound ? NO : YES); }

- (BOOL) containsFiles /*"Returns TRUE if there are filenames available
    in the receiving pasteboard."*/
{ return [self hasType:NSFilenamesPboardType]; }

- (BOOL) containsURL
{return [self hasType:NSURLPboardType];}

@end

