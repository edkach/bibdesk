//  BibDocument_DataSource.m

//  Created by Michael McCracken on Tue Mar 26 2002.
/*
 This software is Copyright (c) 2002,2003,2004,2005,2006
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BibDocument_DataSource.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "NSImage+Toolbox.h"
#import "BDSKGroupCell.h"
#import "BDSKGroup.h"
#import "BDSKScriptHookManager.h"
#import "BibDocument_Groups.h"
#import "BibDocument_Search.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "BDSKPreviewer.h"
#import "BDSKTeXTask.h"
#import "BDSKMainTableView.h"
#import "BDSKGroupTableView.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKAlert.h"
#import "BibTypeManager.h"
#import "NSURL_BDSKExtensions.h"
#import "NSFileManager_ExtendedAttributes.h"
#import "NSSet_BDSKExtensions.h"
#import "BibEditor.h"
#import "NSGeometry_BDSKExtensions.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"
#import "BDSKTypeSelectHelper.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSTableView_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKStringParser.h"
#import "BDSKGroupsArray.h"
#import "BDSKItemPasteboardHelper.h"
#import "NSMenu_BDSKExtensions.h"

#define MAX_DRAG_IMAGE_WIDTH 700.0

@interface NSPasteboard (BDSKExtensions)
- (BOOL)containsUnparseableFile;
@end

#pragma mark -

@implementation BibDocument (DataSource)

#pragma mark TableView data source

- (int)numberOfRowsInTableView:(NSTableView *)tv{
    if(tv == (NSTableView *)tableView){
        return [shownPublications count];
    }else if(tv == groupTableView){
        return [groups count];
    }else{
// should raise an exception or something
        return 0;
    }
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    if(tv == tableView){
        return [[shownPublications objectAtIndex:row] displayValueOfField:[tableColumn identifier]];
    }else if(tv == groupTableView){
		return [groups objectAtIndex:row];
    }else return nil;
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    if(tv == tableView){

		NSString *tcID = [tableColumn identifier];
		if([tcID isRatingField]){
			BibItem *pub = [shownPublications objectAtIndex:row];
			int oldRating = [pub ratingValueOfField:tcID];
			int newRating = [object intValue];
			if(newRating != oldRating) {
				[pub setField:tcID toRatingValue:newRating];
				BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
				if (scriptHook) {
					[scriptHook setField:tcID];
					[scriptHook setOldValues:[NSArray arrayWithObject:[NSString stringWithFormat:@"%i", oldRating]]];
					[scriptHook setNewValues:[NSArray arrayWithObject:[NSString stringWithFormat:@"%i", newRating]]];
					[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:pub] document:self];
				}
				[[pub undoManager] setActionName:NSLocalizedString(@"Change Rating",@"Change Rating")];
			}
		}else if([tcID isBooleanField]){
			BibItem *pub = [shownPublications objectAtIndex:row];
            NSCellStateValue oldStatus = [pub boolValueOfField:tcID];
			NSCellStateValue newStatus = [object intValue];
			if(newStatus != oldStatus) {
				[pub setField:tcID toBoolValue:newStatus];
				BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
				if (scriptHook) {
					[scriptHook setField:tcID];
					[scriptHook setOldValues:[NSArray arrayWithObject:[NSString stringWithBool:oldStatus]]];
					[scriptHook setNewValues:[NSArray arrayWithObject:[NSString stringWithBool:newStatus]]];
					[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:pub] document:self];
				}
				[[pub undoManager] setActionName:NSLocalizedString(@"Change Check Box",@"Change Check Box")];
			}
		}else if([tcID isTriStateField]){
			BibItem *pub = [shownPublications objectAtIndex:row];
            NSCellStateValue oldStatus = [pub triStateValueOfField:tcID];
			NSCellStateValue newStatus = [object intValue];
			if(newStatus != oldStatus) {
				[pub setField:tcID toTriStateValue:newStatus];
				BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
				if (scriptHook) {
					[scriptHook setField:tcID];
					[scriptHook setOldValues:[NSArray arrayWithObject:[NSString stringWithTriStateValue:oldStatus]]];
					[scriptHook setNewValues:[NSArray arrayWithObject:[NSString stringWithTriStateValue:newStatus]]];
					[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:pub] document:self];
				}
				[[pub undoManager] setActionName:NSLocalizedString(@"Change Check Box",@"Change Check Box")];
			}
		}
	}else if(tv == groupTableView){
		BDSKGroup *group = [groups objectAtIndex:row];
		// we need to check for this because for some reason setObjectValue:... is called when the row is selected in this tableView
		if([NSString isEmptyString:object] || [[group stringValue] isEqualToString:object])
			return;
		if([group hasEditableName]){
			[(BDSKMutableGroup *)group setName:object];
			[[self undoManager] setActionName:NSLocalizedString(@"Rename Group",@"Rename group")];
			if([sortGroupsKey isEqualToString:BDSKGroupCellStringKey])
                [self sortGroupsByKey:sortGroupsKey];
		}else if([group isCategory]){
			NSArray *pubs = [groupedPublications copy];
			[self movePublications:pubs fromGroup:group toGroupNamed:object];
			[pubs release];
		}
	}
}

#pragma mark TableView delegate

- (void)disableWarningAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if ([alert checkValue] == YES) {
		[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:NO forKey:BDSKWarnOnRenameGroupKey];
	}
}

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)row{
    if(tv == groupTableView){
		if ([[groups objectAtIndex:row] hasEditableName] == NO) 
			return NO;
		else if (NSLocationInRange(row, [groups rangeOfCategoryGroups]) &&
				 [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKWarnOnRenameGroupKey]) {
			
			BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Warning")
												 defaultButton:NSLocalizedString(@"OK", @"OK")
											   alternateButton:nil
												   otherButton:NSLocalizedString(@"Cancel", @"Cancel")
									 informativeTextWithFormat:NSLocalizedString(@"This action will change the %@ field in %i items. Do you want to proceed?", @""), currentGroupField, [groupedPublications count]];
			[alert setHasCheckButton:YES];
			[alert setCheckValue:NO];
			int rv = [alert runSheetModalForWindow:documentWindow
									 modalDelegate:self 
									didEndSelector:@selector(disableWarningAlertDidEnd:returnCode:contextInfo:) 
								didDismissSelector:NULL 
									   contextInfo:BDSKWarnOnRenameGroupKey];
			if (rv == NSAlertOtherReturn)
				return NO;
		}
		return YES;
	}
    return NO;
}
    
- (void)tableView:(NSTableView *)tv willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)row{
    if (row == -1) return;
    if (tv == tableView) {
        if ([aCell isKindOfClass:[NSButtonCell class]]) {
            if ([[[shownPublications objectAtIndex:row] owner] isEqual:self]) 
                [aCell setEnabled:YES];
            else
                [aCell setEnabled:NO];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
	NSTableView *tv = [aNotification object];
    if(tv == tableView){
        NSNotification *note = [NSNotification notificationWithName:BDSKTableSelectionChangedNotification object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
	}else if(tv == groupTableView){
        NSNotification *note = [NSNotification notificationWithName:BDSKGroupTableSelectionChangedNotification object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
    }
}

- (NSDictionary *)defaultColumnWidthsForTableView:(NSTableView *)aTableView{
    NSMutableDictionary *defaultTableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKColumnWidthsKey]];
    [defaultTableColumnWidths addEntriesFromDictionary:[[self mainWindowSetupDictionaryFromExtendedAttributes] objectForKey:BDSKColumnWidthsKey]];
    return defaultTableColumnWidths;
}

- (NSDictionary *)currentTableColumnWidthsAndIdentifiers {
    NSEnumerator *tcE = [[tableView tableColumns] objectEnumerator];
    NSTableColumn *tc = nil;
    NSMutableDictionary *columns = [NSMutableDictionary dictionaryWithCapacity:5];
    
    while(tc = [tcE nextObject]){
        [columns setObject:[NSNumber numberWithFloat:[tc width]]
                    forKey:[tc identifier]];
    }
    return columns;
}    

- (void)tableViewColumnDidResize:(NSNotification *)notification{
	if([notification object] != tableView) return;
      
    // current setting will override those already in the prefs; we may not be displaying all the columns in prefs right now, but we want to preserve their widths
    NSMutableDictionary *defaultWidths = [[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKColumnWidthsKey] mutableCopy];
    [defaultWidths addEntriesFromDictionary:[self currentTableColumnWidthsAndIdentifiers]];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:defaultWidths forKey:BDSKColumnWidthsKey];
    [defaultWidths release];
}


- (void)tableViewColumnDidMove:(NSNotification *)notification{
	if([notification object] != tableView) return;
    
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[tableView tableColumnIdentifiers]
                                                      forKey:BDSKShownColsNamesKey];
}

- (void)tableView:(NSTableView *)tv didClickTableColumn:(NSTableColumn *)tableColumn{
	// check whether this is the right kind of table view and don't re-sort when we have a contextual menu click
    if ([[NSApp currentEvent] type] == NSRightMouseDown) 
        return;
    if (tableView == tv){
        [self sortPubsByKey:[tableColumn identifier]];
	}else if (groupTableView == tv){
        [self sortGroupsByKey:nil];
	}

}

- (NSMenu *)tableView:(NSTableView *)tv contextMenuForRow:(int)row column:(int)column {
	NSMenu *myMenu = nil;
    NSMenuItem *theItem = nil;
    
	if (column == -1 || row == -1) 
		return nil;
	
	if(tv == tableView){
		
		NSString *tcId = [[[tableView tableColumns] objectAtIndex:column] identifier];
        NSURL *theURL = nil;
        
		if([tcId isLocalFileField]){
			myMenu = [[fileMenu copyWithZone:[NSMenu menuZone]] autorelease];
			[[myMenu itemAtIndex:0] setRepresentedObject:tcId];
			[[myMenu itemAtIndex:1] setRepresentedObject:tcId];
            if([tableView numberOfSelectedRows] == 1)
                theURL = [[shownPublications objectAtIndex:row] URLForField:tcId];
            if(nil != theURL){
                theItem = [myMenu insertItemWithTitle:NSLocalizedString(@"Open With", @"Open with") 
                                    andSubmenuOfApplicationsForURL:theURL atIndex:1];
            }
		}else if([tcId isRemoteURLField]){
			myMenu = [[URLMenu copyWithZone:[NSMenu menuZone]] autorelease];
			[[myMenu itemAtIndex:0] setRepresentedObject:tcId];
            if([tableView numberOfSelectedRows] == 1)
                theURL = [[shownPublications objectAtIndex:row] URLForField:tcId];
            if(nil != theURL){
                theItem = [myMenu insertItemWithTitle:NSLocalizedString(@"Open With", @"Open with") 
                                    andSubmenuOfApplicationsForURL:theURL atIndex:1];
            }            
		}else{
			myMenu = [[actionMenu copyWithZone:[NSMenu menuZone]] autorelease];
		}
		
	}else if (tv == groupTableView){
		myMenu = [[groupMenu copyWithZone:[NSMenu menuZone]] autorelease];
	}else{
		return nil;
	}
	
	// kick out every item we won't need:
	int i = [myMenu numberOfItems];
    BOOL wasSeparator = YES;
	
	while (--i >= 0) {
		theItem = (NSMenuItem*)[myMenu itemAtIndex:i];
		if ([self validateMenuItem:theItem] == NO || ((wasSeparator || i == 0) && [theItem isSeparatorItem]))
			[myMenu removeItem:theItem];
        else
            wasSeparator = [theItem isSeparatorItem];
	}
	while([myMenu numberOfItems] > 0 && [(NSMenuItem*)[myMenu itemAtIndex:0] isSeparatorItem])	
		[myMenu removeItemAtIndex:0];
	
	if([myMenu numberOfItems] == 0)
		return nil;
	
	return myMenu;
}

- (BOOL)tableViewShouldEditNextItemWhenEditingEnds:(NSTableView *)tv{
	if (tv == groupTableView && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKWarnOnRenameGroupKey])
		return NO;
	return YES;
}

- (NSString *)tableViewFontNamePreferenceKey:(NSTableView *)tv {
    if (tv == tableView)
        return BDSKMainTableViewFontNameKey;
    else if (tv == groupTableView)
        return BDSKGroupTableViewFontNameKey;
    else 
        return nil;
}

- (NSString *)tableViewFontSizePreferenceKey:(NSTableView *)tv {
    if (tv == tableView)
        return BDSKMainTableViewFontSizeKey;
    else if (tv == groupTableView)
        return BDSKGroupTableViewFontSizeKey;
    else 
        return nil;
}

#pragma mark TableView dragging source

// for 10.3 compatibility and OmniAppKit dataSource methods
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard{
	NSMutableIndexSet *rowIndexes = [NSMutableIndexSet indexSet];
	NSEnumerator *rowEnum = [rows objectEnumerator];
	NSNumber *row;
	
	while (row = [rowEnum nextObject]) 
		[rowIndexes addIndex:[row intValue]];
	
	return [self tableView:tv writeRowsWithIndexes:rowIndexes toPasteboard:pboard];
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard{
    OFPreferenceWrapper *sud = [OFPreferenceWrapper sharedPreferenceWrapper];
    int index = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? 1 : 0;
	int dragCopyType = [[[sud arrayForKey:BDSKDragCopyTypesKey] objectAtIndex:index] intValue];
    BOOL yn = NO;
	NSString *citeString = [sud stringForKey:BDSKCiteStringKey];
    NSArray *pubs = nil;
    
	OBPRECONDITION(pboard == [NSPasteboard pasteboardWithName:NSDragPboard] || pboard == [NSPasteboard pasteboardWithName:NSGeneralPboard]);

    docState.dragFromSharedGroups = NO;
	
    if(tv == groupTableView){
		if([rowIndexes containsIndex:0]){
			pubs = [NSArray arrayWithArray:publications];
		}else if([rowIndexes count] > 1){
			// multiple dragged rows always are the selected rows
			pubs = [NSArray arrayWithArray:groupedPublications];
		}else if([rowIndexes count] == 1){
            // a single row, not necessarily the selected one
            BDSKGroup *group = [groups objectAtIndex:[rowIndexes firstIndex]];
            if ([group isExternal]) {
                pubs = [NSArray arrayWithArray:[(id)group publications]];
			} else {
                NSMutableArray *pubsInGroup = [NSMutableArray arrayWithCapacity:[publications count]];
                NSEnumerator *pubEnum = [publications objectEnumerator];
                BibItem *pub;
                
                while (pub = [pubEnum nextObject]) {
                    if ([group containsItem:pub]) 
                        [pubsInGroup addObject:pub];
                }
                pubs = pubsInGroup;
            }
            docState.dragFromSharedGroups = [groups hasExternalGroupsAtIndexes:rowIndexes];
		}
		if([pubs count] == 0){
            NSBeginAlertSheet(NSLocalizedString(@"Empty Groups", @""),nil,nil,nil,documentWindow,nil,NULL,NULL,NULL,
                              NSLocalizedString(@"The groups you want to drag do not contain any items.", @""));
            return NO;
        }
			
    }else if(tv == tableView){
		// drag from the main table
		pubs = [shownPublications objectsAtIndexes:rowIndexes];
        
        docState.dragFromSharedGroups = [self hasExternalGroupsSelected];

		if(pboard == [NSPasteboard pasteboardWithName:NSDragPboard]){
			// see where we clicked in the table
			// if we clicked on a local file column that has a file, we'll copy that file
			// if we clicked on a remote URL column that has a URL, we'll copy that URL
			// but only if we were passed a single row for now
			
			// we want the drag to occur for the row that is dragged, not the row that is selected
			if([rowIndexes count]){
				NSPoint eventPt = [[tv window] mouseLocationOutsideOfEventStream];
				NSPoint dragPosition = [tv convertPoint:eventPt fromView:nil];
				int dragColumn = [tv columnAtPoint:dragPosition];
				NSString *dragColumnId = nil;
						
				if(dragColumn == -1)
					return NO;
				
				dragColumnId = [[[tv tableColumns] objectAtIndex:dragColumn] identifier];
				
				if([dragColumnId isLocalFileField]){

                    // if we have more than one row, we can't put file contents on the pasteboard, but most apps seem to handle file names just fine
                    unsigned row = [rowIndexes firstIndex];
                    BibItem *pub = nil;
                    NSString *path;
                    NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
                    [pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil] owner:nil];

                    while(row != NSNotFound){
                        pub = [shownPublications objectAtIndex:row];
                        path = [pub localFilePathForField:dragColumnId];
                        if(path != nil){
                            [filePaths addObject:path];
                            NSError *xerror = nil;
                            // we can always write xattrs; this doesn't alter the original file's content in any way, but fails if you have a really long abstract/annote
                            if([[NSFileManager defaultManager] setExtendedAttributeNamed:OMNI_BUNDLE_IDENTIFIER @".bibtexstring" toValue:[[pub bibTeXString] dataUsingEncoding:NSUTF8StringEncoding] atPath:path options:nil error:&xerror] == NO)
                                NSLog(@"%@ line %d: adding xattrs failed with error %@", __FILENAMEASNSSTRING__, __LINE__, xerror);
                            // writing the standard PDF metadata alters the original file, so we'll make it a separate preference; this is also really slow
                            if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldWritePDFMetadata])
                                [pub addPDFMetadataToFileForLocalURLField:dragColumnId];
                        }
                        row = [rowIndexes indexGreaterThanIndex:row];
                    }

                    return [pboard setPropertyList:filePaths forType:NSFilenamesPboardType];
                    
				}else if([dragColumnId isRemoteURLField]){
					// cache this so we know which column (field) was dragged
					[self setPromiseDragColumnIdentifier:dragColumnId];
					
					BibItem *pub = [shownPublications objectAtIndex:[rowIndexes firstIndex]];
					NSURL *url = [pub remoteURLForField:dragColumnId];
					if(url != nil){
						// put the URL and a webloc file promise on the pasteboard
                        [pboard declareTypes:[NSArray arrayWithObjects:NSFilesPromisePboardType, NSURLPboardType, nil] owner:self];
                        yn = [pboard setPropertyList:[NSArray arrayWithObject:[[pub displayTitle] stringByAppendingPathExtension:@"webloc"]] forType:NSFilesPromisePboardType];
                        [url writeToPasteboard:pboard];
						return yn;
					}
				}
			}
		}
    }
	
	return [self writePublications:pubs forDragCopyType:dragCopyType citeString:citeString toPasteboard:pboard];
}
	
- (BOOL)writePublications:(NSArray *)pubs forDragCopyType:(int)dragCopyType citeString:(NSString *)citeString toPasteboard:(NSPasteboard*)pboard{
	NSString *mainType = nil;
	NSString *string = nil;
	NSData *data = nil;
	
	switch(dragCopyType){
		case BDSKBibTeXDragCopyType:
			mainType = NSStringPboardType;
			string = [self bibTeXStringForPublications:pubs];
			OBASSERT(string != nil);
			break;
		case BDSKCiteDragCopyType:
			mainType = NSStringPboardType;
			string = [self citeStringForPublications:pubs citeString:citeString];
			OBASSERT(string != nil);
			break;
		case BDSKPDFDragCopyType:
			mainType = NSPDFPboardType;
			if([pubs isEqualToArray:[self selectedPublications]]){
                // reuse the PDF data from a previewer if available
                data = [previewer PDFData];
                if(data == nil && [self isCurrentDocument])
                    data = [[BDSKPreviewer sharedPreviewer] PDFData];
			}
			break;
		case BDSKRTFDragCopyType:
			mainType = NSRTFPboardType;
			if([pubs isEqualToArray:[self selectedPublications]]){
                // reuse the RTF data from a previewer if available
                data = [previewer RTFData];
                if(data == nil && [self isCurrentDocument])
                    data = [[BDSKPreviewer sharedPreviewer] RTFData];
			}
			break;
		case BDSKLaTeXDragCopyType:
			mainType = NSStringPboardType;
			if([pubs isEqualToArray:[self selectedPublications]]){
                // reuse the LaTeX string from a previewer if available
                string = [previewer LaTeXString];
                if(string == nil && [self isCurrentDocument])
                    string = [[BDSKPreviewer sharedPreviewer] LaTeXString];
			}
			break;
		case BDSKLTBDragCopyType:
			mainType = NSStringPboardType;
			break;
		case BDSKMinimalBibTeXDragCopyType:
			mainType = NSStringPboardType;
			string = [self bibTeXStringDroppingInternal:YES forPublications:pubs];
			OBASSERT(string != nil);
			break;
		case BDSKRISDragCopyType:
			mainType = NSStringPboardType;
			string = [self RISStringForPublications:pubs];
			break;
		default:
            do{
                NSString *style = [[BDSKTemplate allStyleNames] objectAtIndex:dragCopyType - BDSKTemplateDragCopyType];
                BDSKTemplate *template = [BDSKTemplate templateForStyle:style];
                BDSKTemplateFormat format = [template templateFormat];
                if (format & BDSKTextTemplateFormat) {
                    mainType = NSStringPboardType;
                    string = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:pubs];
                } else if (format & BDSKRichTextTemplateFormat) {
                    NSDictionary *docAttributes = nil;
                    NSAttributedString *templateString = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:pubs documentAttributes:&docAttributes];
                    if (format & BDSKRTFDTemplateFormat) {
                        mainType = NSRTFDPboardType;
                        data = [templateString RTFDFromRange:NSMakeRange(0,[templateString length]) documentAttributes:docAttributes];
                    } else {
                        mainType = NSRTFPboardType;
                        data = [templateString RTFFromRange:NSMakeRange(0,[templateString length]) documentAttributes:docAttributes];
                    }
                }
            }while(0);
	}
    
	[pboardHelper declareType:mainType dragCopyType:dragCopyType forItems:pubs forPasteboard:pboard];
	
    if(string != nil)
        [pboardHelper setString:string forType:mainType forPasteboard:pboard];
	else if(data != nil)
        [pboardHelper setData:data forType:mainType forPasteboard:pboard];

    return YES;
}

- (void)tableView:(NSTableView *)aTableView concludeDragOperation:(NSDragOperation)operation{
    [self clearPromisedDraggedItems];
}

- (void)clearPromisedDraggedItems{
	[pboardHelper clearPromisedTypesForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
}

- (NSDragOperation)tableView:(NSTableView *)tv draggingSourceOperationMaskForLocal:(BOOL)isLocal{
    return isLocal ? NSDragOperationEvery : NSDragOperationCopy;
}

- (NSImage *)tableView:(NSTableView *)tv dragImageForRowsWithIndexes:(NSIndexSet *)dragRows{
    return [self dragImageForPromisedItemsUsingCiteString:[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKCiteStringKey]];
}

- (NSImage *)dragImageForPromisedItemsUsingCiteString:(NSString *)citeString{
    NSImage *image = nil;
    
    NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
    NSString *dragType = [pb availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, NSFilesPromisePboardType, NSPDFPboardType, NSRTFPboardType, NSStringPboardType, nil]];
	NSArray *promisedDraggedItems = [pboardHelper promisedItemsForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
	int dragCopyType = -1;
	int count = 0;
    BOOL inside = NO;
	
    if ([dragType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pb propertyListForType:NSFilenamesPboardType];
		count = [fileNames count];
		image = [[NSWorkspace sharedWorkspace] iconForFiles:fileNames];
    
    } else if ([dragType isEqualToString:NSURLPboardType]) {
        count = 1;
        image = [[[NSImage imageForURL:[NSURL URLFromPasteboard:pb]] copy] autorelease];
		[image setSize:NSMakeSize(32,32)];
    
	} else if ([dragType isEqualToString:NSFilesPromisePboardType]) {
		NSArray *fileNames = [pb propertyListForType:NSFilesPromisePboardType];
		count = [fileNames count];
        image = [[NSWorkspace sharedWorkspace] iconForFiles:fileNames];
    
	} else {
		OFPreferenceWrapper *sud = [OFPreferenceWrapper sharedPreferenceWrapper];
        int index = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? 1 : 0;
		NSMutableString *s = [NSMutableString string];
		BibItem *firstItem = [promisedDraggedItems objectAtIndex:0];
        
        dragCopyType = [[[sud arrayForKey:BDSKDragCopyTypesKey] objectAtIndex:index] intValue];
		
		// don't depend on this being non-zero; this method gets called for drags where promisedDraggedItems is nil
		count = [promisedDraggedItems count];
		
		// we draw only the first item and indicate other items using ellipsis
		switch (dragCopyType) {
			case BDSKBibTeXDragCopyType:
			case BDSKMinimalBibTeXDragCopyType:
				[s appendString:[firstItem bibTeXStringDroppingInternal:YES]];
				if (count > 1) {
					[s appendString:@"\n"];
					[s appendString:[NSString horizontalEllipsisString]];
				}
                inside = YES;
				break;
			case BDSKCiteDragCopyType:
				// Are we using a custom citeString (from the drawer?)
                [s appendString:[self citeStringForPublications:[NSArray arrayWithObject:firstItem] citeString:citeString]];
				if (count > 1) 
					[s appendString:[NSString horizontalEllipsisString]];
				break;
			case BDSKPDFDragCopyType:
			case BDSKRTFDragCopyType:
				[s appendString:@"["];
				[s appendString:[firstItem citeKey]]; 
				[s appendString:@"]"];
				if (count > 1) 
					[s appendString:[NSString horizontalEllipsisString]];
				break;
			case BDSKLaTeXDragCopyType:
				[s appendString:@"\\bibitem{"];
				[s appendString:[firstItem citeKey]];
				[s appendString:@"}"];
				if (count > 1) 
					[s appendString:[NSString horizontalEllipsisString]];
				break;
			case BDSKLTBDragCopyType:
				[s appendString:@"\\bib{"];
				[s appendString:[firstItem citeKey]];
				[s appendString:@"}{"];
				[s appendString:[firstItem pubType]];
				[s appendString:@"}"];
				if (count > 1) 
					[s appendString:[NSString horizontalEllipsisString]];
				break;
			case BDSKRISDragCopyType:
                [s appendString:[firstItem RISStringValue]];
				if (count > 1) 
					[s appendString:[NSString horizontalEllipsisString]];
                inside = YES;
				break;
		}
		
		NSAttributedString *attrString = [[[NSAttributedString alloc] initWithString:s] autorelease];
		NSSize size = [attrString size];
		NSRect rect = NSZeroRect;
		NSPoint point = NSMakePoint(3.0, 2.0); // offset of the string
		NSColor *color = [NSColor secondarySelectedControlColor];
		
        if (size.width <= 0 || size.height <= 0) {
            NSLog(@"string size was zero");
            size = NSMakeSize(30.0,20.0); // work around bug in NSAttributedString
        }
        if (size.width > MAX_DRAG_IMAGE_WIDTH)
            size.width = MAX_DRAG_IMAGE_WIDTH;
        
		size.width += 2 * point.x;
		size.height += 2 * point.y;
		rect.size = size;
		rect = NSInsetRect(rect, 1.0, 1.0); // inset by half of the linewidth
		
		image = [[[NSImage alloc] initWithSize:size] autorelease];
        
        [image lockFocus];
        
		[NSGraphicsContext saveGraphicsState];
		[[color colorWithAlphaComponent:0.2] setFill];
		[NSBezierPath fillRoundRectInRect:rect radius:4.0];
		[[color colorWithAlphaComponent:0.8] setStroke];
		[NSBezierPath setDefaultLineWidth:2.0];
		[NSBezierPath strokeRoundRectInRect:rect radius:4.0];
		
		NSRectClip(NSInsetRect(rect, 2.0, 2.0));
        [attrString drawAtPoint:point];
		[NSGraphicsContext restoreGraphicsState];
        
        [image unlockFocus];
	}
	
    return [image dragImageWithCount:count inside:inside];
}

#pragma mark TableView dragging destination

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row
       proposedDropOperation:(NSTableViewDropOperation)op{
    
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
    BOOL isDragFromMainTable = [[info draggingSource] isEqual:tableView];
    BOOL isDragFromGroupTable = [[info draggingSource] isEqual:groupTableView];
    BOOL isDragFromDrawer = [[info draggingSource] isEqual:[drawerController tableView]];
    
    if(tv == tableView){
        if([self hasExternalGroupsSelected] || type == nil) 
			return NSDragOperationNone;
		if (isDragFromGroupTable && docState.dragFromSharedGroups && [self hasLibraryGroupSelected]) {
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
            return NSDragOperationCopy;
        }
        if(isDragFromMainTable || isDragFromGroupTable || isDragFromDrawer) {
			// can't copy onto same table
			return NSDragOperationNone;
		}
        // set drop row to -1 and NSTableViewDropOperation to NSTableViewDropOn, when we don't target specific rows http://www.corbinstreehouse.com/blog/?p=123
        if(row == -1 || op == NSTableViewDropAbove){
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
		}else if(([type isEqualToString:NSFilenamesPboardType] == NO || [[info draggingPasteboard] containsUnparseableFile] == NO) &&
                 [type isEqualToString:BDSKWeblocFilePboardType] == NO && [type isEqualToString:NSURLPboardType] == NO){
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
        }
        if ([type isEqualToString:BDSKBibItemPboardType])   
            return NSDragOperationCopy;
        else
            return NSDragOperationEvery;
    }else if(tv == groupTableView){
		if ((isDragFromGroupTable || isDragFromMainTable) && docState.dragFromSharedGroups) {
            if (row != 0)
                return NSDragOperationNone;
            [tv setDropRow:row dropOperation:NSTableViewDropOn];
            return NSDragOperationCopy;
        }
            
        // not sure why this check is necessary, but it silences an error message when you drag off the list of items
        if(isDragFromDrawer || isDragFromGroupTable || row >= [tv numberOfRows] || [[groups objectAtIndex:row]  isValidDropTarget] == NO || type == nil || (row == 0 && isDragFromMainTable)) 
            return NSDragOperationNone;
        
        // here we actually target a specific row
        [tv setDropRow:row dropOperation:NSTableViewDropOn];
        if(isDragFromMainTable){
            if([type isEqualToString:BDSKBibItemPboardType])
                return NSDragOperationLink;
            else
                return NSDragOperationNone;
        } else if([type isEqualToString:BDSKBibItemPboardType]){
            return NSDragOperationCopy; // @@ can't drag row indexes from another document; should use NSArchiver instead
        }else{
            return NSDragOperationEvery;
        }
    }
    return NSDragOperationNone;
}

// This method is called when the mouse is released over a table view that previously decided to allow a drop via the validateDrop method.  The data source should incorporate the data from the dragging pasteboard at this time.

- (BOOL)tableView:(NSTableView*)tv
       acceptDrop:(id <NSDraggingInfo>)info
              row:(int)row
    dropOperation:(NSTableViewDropOperation)op{
	
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
    
    if(tv == tableView){
        if([self hasExternalGroupsSelected])
            return NO;
		if(row != -1){
            BibItem *pub = [shownPublications objectAtIndex:row];
            NSURL *theURL = nil;
            
            if([type isEqualToString:NSFilenamesPboardType]){
                NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
                if ([fileNames count] == 0)
                    return NO;
                theURL = [NSURL fileURLWithPath:[[fileNames objectAtIndex:0] stringByExpandingTildeInPath]];
            }else if([type isEqualToString:BDSKWeblocFilePboardType]){
                theURL = [NSURL URLWithString:[pboard stringForType:BDSKWeblocFilePboardType]];
            }else if([type isEqualToString:NSURLPboardType]){
                theURL = [NSURL URLFromPasteboard:pboard];
            }else return NO;
            
            NSString *field = ([theURL isFileURL]) ? BDSKLocalUrlString : BDSKUrlString;
            
            if(theURL == nil || [theURL isEqual:[pub URLForField:field]])
                return NO;
            
            [pub setField:field toValue:[theURL absoluteString]];
            
            if([field isEqualToString:BDSKLocalUrlString])
                [pub autoFilePaper];
            
            [self selectPublication:pub];
            [[pub undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
            return YES;
            
        }else{
            [self selectLibraryGroup:nil];
            
            if([type isEqualToString:NSFilenamesPboardType]){
                NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
                if([filenames count] == 1){
                    NSString *file = [filenames lastObject];
                    if([[file pathExtension] caseInsensitiveCompare:@"aux"] == NSOrderedSame){
                        NSString *auxString = [NSString stringWithContentsOfFile:file encoding:[self documentStringEncoding] guessEncoding:YES];
                        
                        if (auxString == nil)
                            return NO;
                        
                        NSScanner *scanner = [NSScanner scannerWithString:auxString];
                        NSString *key = nil;
                        NSArray *items = nil;
                        NSMutableArray *selItems = [NSMutableArray array];
                        
                        while ([scanner isAtEnd] == NO && 
                               [scanner scanUpToString:@"\\bibcite{" intoString:NULL] && 
                               [scanner scanString:@"\\bibcite{" intoString:NULL]) {
                            if([scanner scanUpToString:@"}" intoString:&key]) {
                                if (items = [publications allItemsForCiteKey:key])
                                    [selItems addObjectsFromArray:items];
                            }
                        }
                        [self selectPublications:selItems];
                        
                        return YES;
                    }
                }
            }
            
            BOOL result = [self addPublicationsFromPasteboard:pboard error:NULL];
            
            if (result) [self updateUI];
            return result;
        }
    } else if(tv == groupTableView){
        NSArray *pubs = nil;
        BOOL isDragFromMainTable = [[info draggingSource] isEqual:tableView];
        BOOL isDragFromGroupTable = [[info draggingSource] isEqual:groupTableView];
        BOOL isDragFromDrawer = [[info draggingSource] isEqual:[drawerController tableView]];
        
        // retain is required to fix bug #1356183
        BDSKGroup *group = [[[groups objectAtIndex:row] retain] autorelease];
        BOOL shouldSelect = [[self selectedGroups] containsObject:group];
		
		if ((isDragFromGroupTable || isDragFromMainTable) && docState.dragFromSharedGroups && row == 0) {
            return [self addPublicationsFromPasteboard:pboard error:NULL];
        } else if(isDragFromGroupTable || isDragFromDrawer || [group isValidDropTarget] == NO) {
            return NO;
        } else if(isDragFromMainTable){
            // we already have these publications, so we just want to add them to the group, not the document
            
			pubs = [pboardHelper promisedItemsForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
        } else {
            if([self addPublicationsFromPasteboard:pboard error:NULL] == NO)
                return NO;
            
            pubs = [self selectedPublications];            
        }

        OBPRECONDITION([pubs count]);
        
        // add to the group we're dropping on, /not/ the currently selected group; no need to add to all pubs group, though
        if(group != nil && row != 0){
            [self addPublications:pubs toGroup:group];
            // reselect if necessary, or we default to selecting the all publications group (which is really annoying when creating a new pub by dropping a PDF on a group)
            if(shouldSelect) 
                [self selectGroup:group];
            [groupTableView reloadData];
        }
        
        return YES;
    }
      
    return NO;
}

#pragma mark HFS Promise drags

// promise drags (currently used for webloc files)
- (NSArray *)tableView:(NSTableView *)tv namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedRowsWithIndexes:(NSIndexSet *)indexSet;
{

    unsigned rowIdx = [indexSet firstIndex];
    NSMutableDictionary *fullPathDict = [NSMutableDictionary dictionaryWithCapacity:[indexSet count]];
    
    // We're supposed to return this to our caller (usually the Finder); just an array of file names, not full paths
    NSMutableArray *fileNames = [NSMutableArray arrayWithCapacity:[indexSet count]];
    
    NSURL *url = nil;
    NSString *fullPath = nil;
    BibItem *theBib = nil;
    
    // this ivar stores the field name (e.g. Url, L2)
    NSString *fieldName = [self promiseDragColumnIdentifier];
    BOOL isLocalFile = [fieldName isLocalFileField];
    
    NSString *originalPath;
    NSString *fileName;
    NSString *basePath = [dropDestination path];

    while(rowIdx != NSNotFound){
        theBib = [shownPublications objectAtIndex:rowIdx];
        if(isLocalFile){
            originalPath = [theBib localFilePathForField:fieldName];
            fileName = [originalPath lastPathComponent];
            NSParameterAssert(fileName);
            fullPath = [basePath stringByAppendingPathComponent:fileName];
            [fileNames addObject:fileName];
            // create a dictionary with each original file path (source) as key, and destination path as value
            [fullPathDict setValue:fullPath forKey:originalPath];
            
        } else if((url = [theBib remoteURLForField:fieldName])){
                fullPath = [[basePath stringByAppendingPathComponent:[theBib displayTitle]] stringByAppendingPathExtension:@"webloc"];
                // create a dictionary with each destination file path as key (handed to us from the Finder/dropDestination) and each item's URL as value
                [fullPathDict setValue:url forKey:fullPath];
                [fileNames addObject:[theBib displayTitle]];
        }
        rowIdx = [indexSet indexGreaterThanIndex:rowIdx];
    }
    [self setPromiseDragColumnIdentifier:nil];
    
    // We generally want to run promised file creation in the background to avoid blocking our UI, although webloc files are so small it probably doesn't matter.
    if(isLocalFile)
        [[NSFileManager defaultManager] copyFilesInBackgroundThread:fullPathDict];
    else
        [[NSFileManager defaultManager] createWeblocFilesInBackgroundThread:fullPathDict];

    return fileNames;
}

- (void)setPromiseDragColumnIdentifier:(NSString *)identifier;
{
    if(promiseDragColumnIdentifier != identifier){
        [promiseDragColumnIdentifier release];
        promiseDragColumnIdentifier = [identifier copy];
    }
}

- (NSString *)promiseDragColumnIdentifier;
{
    return promiseDragColumnIdentifier;
}

#pragma mark -

- (BOOL)isDragFromSharedGroups;
{
    return docState.dragFromSharedGroups;
}

- (void)setDragFromSharedGroups:(BOOL)flag;
{
    docState.dragFromSharedGroups = flag;
}

#pragma mark TableView actions

// the next 3 are called from tableview actions defined in NSTableView_OAExtensions

- (void)tableView:(NSTableView *)tv insertNewline:(id)sender{
	if (tv == tableView) {
		[self editPubCmd:sender];
	} else if (tv == groupTableView) {
		[self renameGroupAction:sender];
	}
}

- (void)tableView:(NSTableView *)tv deleteRows:(NSArray *)rows{
	// the rows are always the selected rows
	if (tv == tableView) {
		[self removeSelectedPubs:nil];
	} else if (tv == groupTableView) {
		[self removeSelectedGroups:nil];
	}
}

- (void)tableView:(NSTableView *)tv addItemsFromPasteboard:(NSPasteboard *)pboard{

	if (tv != tableView) {
		NSBeep();
		return;
	}

    NSError *error = nil;
	if ([self addPublicationsFromPasteboard:pboard error:&error] == NO) {
        if(error != nil && [NSResponder instancesRespondToSelector:@selector(presentError:)])
            [tv presentError:error];
		else
            NSBeep();
	}
}

// as the window delegate, we receive these from NSInputManager and doCommandBySelector:
- (void)moveLeft:(id)sender{
    if([documentWindow firstResponder] != groupTableView && [documentWindow makeFirstResponder:groupTableView])
        if([groupTableView numberOfSelectedRows] == 0)
            [self selectLibraryGroup:nil];
}

- (void)moveRight:(id)sender{
    if([documentWindow firstResponder] != tableView && [documentWindow makeFirstResponder:tableView]){
        if([tableView numberOfSelectedRows] == 0)
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    } else if([documentWindow firstResponder] == tableView)
        [self editPubCmd:nil];
}

#pragma mark -
#pragma mark TypeSelectHelper delegate

// used for status bar
- (void)typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper updateSearchString:(NSString *)searchString{
    if(searchString == nil || sortKey == nil)
        [self updateUI]; // resets the status line to its default value
    else
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Finding item with %@: \"%@\"", @""), sortKey, searchString]];
}

// This is where we build the list of possible items which the user can select by typing the first few letters. You should return an array of NSStrings.
- (NSArray *)typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)typeSelectHelper{
    if(typeSelectHelper == [tableView typeSelectHelper]){    
        
        // Some users seem to expect that the currently sorted table column is used for typeahead;
        // since the datasource method already knows how to convert columns to BibItem values, we
        // can it almost directly.  It might be possible to cache this in the datasource method itself
        // to avoid calling it twice on -reloadData, but that will only work if -reloadData reloads
        // all rows instead of just visible rows.
        
        unsigned int i, count = [shownPublications count];
        NSMutableArray *a = [NSMutableArray arrayWithCapacity:count];

        // table datasource returns an NSImage for URL fields, so we'll ignore those columns
        if([sortKey isURLField] == NO && nil != sortKey){
            BibItem *pub;
            id value;
            
            for (i = 0; i < count; i++){
                pub = [shownPublications objectAtIndex:i];
                value = [pub displayValueOfField:sortKey];
                
                // use @"" for nil values; ensure typeahead index matches shownPublications index
                [a addObject:value ? [value description] : @""];
            }
        }else{
            for (i = 0; i < count; i++)
                [a addObject:@""];
        }
        return a;
        
    } else if(typeSelectHelper == [groupTableView typeSelectHelper]){
        
        int i;
		int groupCount = [groups count];
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:groupCount];
        BDSKGroup *group;
        
		OBPRECONDITION(groupCount);
        for(i = 0; i < groupCount; i++){
			group = [groups objectAtIndex:i];
            [array addObject:[group stringValue]];
		}
        return array;
        
    } else return [NSArray array];
}

// Type-ahead-selection behavior can change if an item is currently selected (especially if the item was selected by type-ahead-selection). Return nil if you have no selection or a multiple selection.
- (unsigned int)typeSelectHelperCurrentlySelectedIndex:(BDSKTypeSelectHelper *)typeSelectHelper{
    if(typeSelectHelper == [tableView typeSelectHelper]){    
        if ([self numberOfSelectedPubs] == 1){
            return [tableView selectedRow];
        }else{
            return NSNotFound;
        }
    } else if(typeSelectHelper == [groupTableView typeSelectHelper]){
        if([groupTableView numberOfSelectedRows] != 1)
            return NSNotFound;
        else
            return [[groupTableView selectedRowIndexes] firstIndex];
    } else return NSNotFound;
}

// We call this when a type-ahead-selection match has been made; you should select the item based on its index in the array you provided in -typeAheadSelectionItems.
- (void)typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper selectItemAtIndex:(unsigned int)itemIndex{
    NSTableView *tv = nil;
    if(typeSelectHelper == [tableView typeSelectHelper])
        tv = tableView;
    else if(typeSelectHelper == [groupTableView typeSelectHelper])
        tv = groupTableView;
    else
        return;
    [tv selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
    [tv scrollRowToVisible:itemIndex];
}

#pragma mark -
#pragma mark Tracking rects

- (BOOL)tableView:(NSTableView *)tv shouldTrackTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    // this can happen when we revert
    if (row == -1 || row >= [self numberOfRowsInTableView:tv])
        return NO;
    
    NSString *tcID = [tableColumn identifier];
    return [tcID isURLField] && [[shownPublications objectAtIndex:row] URLForField:tcID];
}

- (void)tableView:(NSTableView *)tv mouseEnteredTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    if (row == -1 || row >= [self numberOfRowsInTableView:tv])
        return;
    
    BibItem *pub = [shownPublications objectAtIndex:row];
    NSURL *url = [pub URLForField:[tableColumn identifier]];
    if (url)
        [self setStatus:[url isFileURL] ? [[url path] stringByAbbreviatingWithTildeInPath] : [url absoluteString]];
}

- (void)tableView:(NSTableView *)tv mouseExitedTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    [self updateUI];
}

@end

#pragma mark -

@implementation NSPasteboard (BDSKExtensions)

- (BOOL)containsUnparseableFile{
    NSString *type = [self availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]];
    
    if(type == nil)
        return NO;
    
    NSArray *fileNames = [self propertyListForType:NSFilenamesPboardType];
    
    if([fileNames count] != 1)  
        return NO;
        
    NSString *fileName = [fileNames lastObject];
    NSSet *unreadableTypes = [NSSet caseInsensitiveStringSetWithObjects:@"pdf", @"ps", @"eps", @"doc", @"htm", @"textClipping", @"webloc", @"html", @"rtf", @"tiff", @"tif", @"png", @"jpg", @"jpeg", nil];
    NSSet *readableTypes = [NSSet caseInsensitiveStringSetWithObjects:@"bib", @"aux", @"ris", @"fcgi", @"refman", nil];
    
    if([unreadableTypes containsObject:[fileName pathExtension]])
        return YES;
    if([readableTypes containsObject:[fileName pathExtension]])
        return NO;
    
    NSString *contentString = [[NSString alloc] initWithContentsOfFile:fileName encoding:NSUTF8StringEncoding guessEncoding:YES];
    
    if(contentString == nil)
        return YES;
    if([contentString contentStringType] == BDSKUnknownStringType){
        [contentString release];
        return YES;
    }
    [contentString release];
    return NO;
}

@end
