//
//  BibDocument+Menus.m
//  BibDesk
//
//  Created by Sven-S. Porst on Fri Jul 30 2004.
/*
 This software is Copyright (c) 2004-2008
 Sven-S. Porst. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Sven-S. Porst nor the names of any
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

#import "BibDocument+Menus.h"
#import "BDSKGroupCell.h"
#import "BDSKGroup.h"
#import "BibDocument_Groups.h"
#import "BDSKMainTableView.h"
#import "BDSKGroupTableView.h"
#import "BibItem.h"
#import "BDSKTypeManager.h"
#import "BDSKTemplate.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibDocument_Actions.h"
#import "BibDocument_Search.h"
#import "BDSKGroupsArray.h"
#import "BDSKCustomCiteDrawerController.h"
#import "BDSKPreviewer.h"

@implementation BibDocument (Menus)

- (BOOL) validateCutMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	id firstResponder = [documentWindow firstResponder];
	if ((firstResponder != tableView && firstResponder != [fileSearchController tableView]) ||
		[self numberOfSelectedPubs] == 0 ||
        [self hasExternalGroupsSelected] == YES) {
		// no selection or selection includes shared groups
		return NO;
	}
	else {
		// multiple selection
		return YES;
	}
}	

- (BOOL) validateAlternateCutMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	id firstResponder = [documentWindow firstResponder];
	if ((firstResponder != tableView && firstResponder != [fileSearchController tableView]) ||
		[self numberOfSelectedPubs] == 0 ||
        [self hasExternalGroupsSelected] == YES) {
		// no selection
		return NO;
	}
	else {
		// multiple selection
		return YES;
	}
}	

- (BOOL) validateCopyMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	id firstResponder = [documentWindow firstResponder];
	if ((firstResponder != tableView && firstResponder != [fileSearchController tableView]) ||
		[self numberOfSelectedPubs] == 0) {
		// no selection
		return NO;
	}
	else {
		// multiple selection
		return YES;
	}
}	

- (BOOL) validateCopyAsMenuItem:(NSMenuItem*) menuItem {
    BOOL usesTeX = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUsesTeXKey];
	int copyType = [menuItem tag];
    
    if (usesTeX == NO && (copyType == BDSKPDFDragCopyType || copyType == BDSKRTFDragCopyType || copyType == BDSKLaTeXDragCopyType || copyType == BDSKLTBDragCopyType))
        return NO;
    else
        return [self numberOfSelectedPubs] > 0;
}

- (BOOL)validatePasteMenuItem:(NSMenuItem *)menuItem{
	return ([documentWindow isKeyWindow] == YES && [[documentWindow firstResponder] isEqual:tableView]);
}

- (BOOL)validateDuplicateMenuItem:(NSMenuItem *)menuItem{
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	if ([[documentWindow firstResponder] isEqual:tableView] == NO ||
		[self numberOfSelectedPubs] == 0 ||
        [self hasExternalGroupsSelected] == YES)
		return NO;
	return YES;
}

- (BOOL) validateEditSelectionMenuItem:(NSMenuItem*) menuItem {
    return [self numberOfSelectedPubs] > 0;
}

- (BOOL) validateDeleteSelectionMenuItem:(NSMenuItem*) menuItem {
    return ([self numberOfSelectedPubs] > 0 && [self hasExternalGroupsSelected] == NO);
}	
		
- (BOOL) validateRemoveSelectionMenuItem:(NSMenuItem*) menuItem {
    if ([self numberOfSelectedPubs] == 0 && [self hasExternalGroupsSelected])
        return NO;
    if([self hasLibraryGroupSelected])
        return [self validateDeleteSelectionMenuItem:menuItem];
    
    NSIndexSet *selIndexes = [groupTableView selectedRowIndexes];
    int n = [groups numberOfStaticGroupsAtIndexes:selIndexes];
    // don't remove from single valued group field, as that will clear the field, which is most probably a mistake. See bug # 1435344
    if ([[self currentGroupField] isSingleValuedGroupField] == NO)
        n += [groups numberOfCategoryGroupsAtIndexes:selIndexes];
    return n > 0;
}	

- (BOOL)validateSendToLyXMenuItem:(NSMenuItem*) menuItem {
    if ([self numberOfSelectedPubs] == 0)
        return NO;
    
    if ([[NSFileManager defaultManager] newestLyXPipePath])
        return YES;
        
    return NO;
}

- (BOOL) validateOpenLocalURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject];
    if (field == nil)
		field = BDSKLocalUrlString;
    
    NSEnumerator *e = [[self selectedPublications] objectEnumerator];
	BibItem *pub = nil;
    
    while(pub = [e nextObject]){
        NSString *path = [[pub localFileURLForField:field] path];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
    }
    return NO;
}	

- (BOOL) validateRevealLocalURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject];
    if (field == nil)
		field = BDSKLocalUrlString;
    
    NSEnumerator *e = [[self selectedPublications] objectEnumerator];
	BibItem *pub = nil;
    
    while(pub = [e nextObject]){
        NSString *path = [[pub localFileURLForField:field] path];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
    }
    return NO;
}	

- (BOOL) validateOpenRemoteURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject];
    if (field == nil)
		field = BDSKUrlString;
    
    NSEnumerator *e = [[self selectedPublications] objectEnumerator];
	BibItem *pub = nil;
    
    while(pub = [e nextObject]){
        NSURL *url = [pub remoteURLForField:field];
        if (url)
            return YES;
    }
    return NO;
}	

- (BOOL) validateShowNotesForLocalURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject];
    if (field == nil)
		field = BDSKLocalUrlString;
    
    NSEnumerator *e = [[self selectedPublications] objectEnumerator];
	BibItem *pub = nil;
    
    while(pub = [e nextObject]){
        NSString *path = [[pub localFileURLForField:field] path];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
    }
    return NO;
}	

- (BOOL) validateCopyNotesForLocalURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject];
    if (field == nil)
		field = BDSKLocalUrlString;
    
    NSEnumerator *e = [[self selectedPublications] objectEnumerator];
	BibItem *pub = nil;
    
    while(pub = [e nextObject]){
        NSString *path = [[pub localFileURLForField:field] path];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
    }
    return NO;
}	

- (BOOL) validateOpenLinkedFileMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || [[self selectedFileURLs] count] > 0);
}	

- (BOOL) validateRevealLinkedFileMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || [[self selectedFileURLs] count] > 0);
}	

- (BOOL) validateOpenLinkedURLMenuItem:(NSMenuItem*) menuItem {
    return [menuItem representedObject] != nil || [[[self selectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs"] count] > 0;
}	

- (BOOL) validateShowNotesForLinkedFileMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || [[self selectedFileURLs] count] > 0);
}	

- (BOOL) validateCopyNotesForLinkedFileMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || [[self selectedFileURLs] count] > 0);
}	

- (BOOL) validatePreviewMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || 
            [[self selectedFileURLs] count] ||
            [[[self selectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs"] count]);
}	

- (BOOL) validateDuplicateTitleToBooktitleMenuItem:(NSMenuItem*) menuItem {
	return ([self numberOfSelectedPubs] > 0 && [self hasExternalGroupsSelected] == NO);
}

- (BOOL) validateGenerateCiteKeyMenuItem:(NSMenuItem*) menuItem {
	return ([self numberOfSelectedPubs] > 0 && [self hasExternalGroupsSelected] == NO);
}	

- (BOOL) validateConsolidateLinkedFilesMenuItem:(NSMenuItem*) menuItem {
	return ([self numberOfSelectedPubs] > 0 && [self hasExternalGroupsSelected] == NO);
}	

- (BOOL) validatePrintDocumentMenuItem:(NSMenuItem*) menuItem {
	if ([self numberOfSelectedPubs] == 0)
        return NO;
    // even if there is a selection, we may have an error condition with nothing to print
    // see comments on exception in -printableView, which is the main motivation for this validation
    else if([currentPreviewView isEqual:previewerBox])
        return [[previewer pdfView] document] != nil;
    else if ([currentPreviewView isEqual:previewBox])
        return [previewPdfView document] != nil;
    else if ([[previewer textView] isEqual:previewBox])
        return [[previewer textView] textStorage] != nil;
    else
        return [previewTextView textStorage] != nil;
}

- (BOOL) validateToggleToggleCustomCiteDrawerMenuItem:(NSMenuItem*) menuItem {
    NSString *s;
	if([drawerController isDrawerOpen]){
		s = NSLocalizedString(@"Hide Custom \\cite Commands", @"Menu item title");
		[menuItem setTitle:s];
	}else{
		s = NSLocalizedString(@"Show Custom \\cite Commands", @"Menu item title");
		[menuItem setTitle:s];
	}
	return YES;
}

- (BOOL) validateToggleStatusBarMenuItem:(NSMenuItem*) menuItem {
    NSString *s;
	if ([statusBar isVisible]){
		s = NSLocalizedString(@"Hide Status Bar", @"Menu item title");
		[menuItem setTitle:s];
	}
	else {
		s = NSLocalizedString(@"Show Status Bar", @"Menu item title");
		[menuItem setTitle:s];
	}
	return YES;
}

- (BOOL) validateNewPubFromPasteboardMenuItem:(NSMenuItem*) menuItem {
    NSString *s = [NSLocalizedString(@"New Publications from Clipboard", @"Menu item title") stringByAppendingEllipsis];
	[menuItem setTitle:s];
	return YES;
}

- (BOOL) validateNewPubFromFileMenuItem:(NSMenuItem*) menuItem {
    NSString *s = [NSLocalizedString(@"New Publications from File", @"Menu item title") stringByAppendingEllipsis];
	[menuItem setTitle:s];
	return YES;
}

- (BOOL) validateNewPubFromWebMenuItem:(NSMenuItem*) menuItem {
    NSString *s = [NSLocalizedString(@"New Publications from Web", @"Menu item title") stringByAppendingEllipsis];
	[menuItem setTitle:s];
	return YES;
}

- (BOOL)validateSortForCrossrefsMenuItem:(NSMenuItem *)menuItem{
    return ([self hasExternalGroupsSelected] == NO);
}

- (BOOL)validateSelectCrossrefParentMenuItem:(NSMenuItem *)menuItem{
    if([self isDisplayingFileContentSearch] == NO && [self numberOfSelectedPubs] == 1){
        BibItem *selectedBI = [[self selectedPublications] objectAtIndex:0];
        if(![NSString isEmptyString:[selectedBI valueOfField:BDSKCrossrefString inherit:NO]])
            return YES;
    }
	return NO;
}

- (BOOL)validateCreateNewPubUsingCrossrefMenuItem:(NSMenuItem *)menuItem{
    if([self numberOfSelectedPubs] == 1 && [self hasExternalGroupsSelected] == NO){
        BibItem *selectedBI = [[self selectedPublications] objectAtIndex:0];
        
        // only valid if the selected pub (parent-to-be) doesn't have a crossref field
        if([NSString isEmptyString:[selectedBI valueOfField:BDSKCrossrefString inherit:NO]])
            return YES;
    }
	return NO;
}

- (BOOL) validateSortGroupsByGroupMenuItem:(NSMenuItem *)menuItem{
	if([sortGroupsKey isEqualToString:BDSKGroupCellStringKey]){
		[menuItem setState:NSOnState];
	}else{
		[menuItem setState:NSOffState];
	}
	return YES;
} 

- (BOOL) validateSortGroupsByCountMenuItem:(NSMenuItem *)menuItem{
	if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
		[menuItem setState:NSOnState];
	}else{
		[menuItem setState:NSOffState];
	}
	return YES;
} 

- (BOOL) validateChangeGroupFieldMenuItem:(NSMenuItem *)menuItem{
	if([[menuItem title] isEqualToString:[self currentGroupField]])
		[menuItem setState:NSOnState];
	else
		[menuItem setState:NSOffState];
	return YES;
} 

- (BOOL) validateRemoveSelectedGroupsMenuItem:(NSMenuItem *)menuItem{
    return [groups numberOfSmartGroupsAtIndexes:[groupTableView selectedRowIndexes]] > 0 ||
           [groups numberOfStaticGroupsAtIndexes:[groupTableView selectedRowIndexes]] > 0 ||
           [groups numberOfURLGroupsAtIndexes:[groupTableView selectedRowIndexes]] > 0 ||
           [groups numberOfScriptGroupsAtIndexes:[groupTableView selectedRowIndexes]] > 0 ||
           [groups numberOfSearchGroupsAtIndexes:[groupTableView selectedRowIndexes]] > 0;
} 

- (BOOL) validateRenameGroupMenuItem:(NSMenuItem *)menuItem{
	int row = [groupTableView selectedRow];
	if ([groupTableView numberOfSelectedRows] == 1 &&
		row > 0 &&
        [[groups objectAtIndex:row] hasEditableName]) {
		// single group selection
		return YES;
	} else {
		// multiple selection or no group selected
		return NO;
	}
} 

- (BOOL) validateEditGroupMenuItem:(NSMenuItem *)menuItem{
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	int row = [groupTableView selectedRow];
	if ([groupTableView numberOfSelectedRows] == 1 && row > 0) {
		// single group selection
        return [[groups objectAtIndex:row] isEditable];
	} else {
		// multiple selection or no smart group selected
		return NO;
	}
} 

- (BOOL) validateEditActionMenuItem:(NSMenuItem *)menuItem{
    if ([documentWindow isKeyWindow] == NO) {
        [menuItem setTitle:NSLocalizedString(@"Get Info", @"Menu item title")];
        return NO;
	}
    id firstResponder = [documentWindow firstResponder];
	if (firstResponder == tableView || firstResponder == [fileSearchController tableView]) {
		return [self validateEditSelectionMenuItem:menuItem];
	} else if (firstResponder == groupTableView) {
		return [self validateEditGroupMenuItem:menuItem];
	} else {
		return NO;
	}
} 

- (BOOL) validateDeleteMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
    id firstResponder = [documentWindow firstResponder];
	if (firstResponder == tableView || tableView == [fileSearchController tableView]) {
		return [self validateRemoveSelectionMenuItem:menuItem];
	} else if (firstResponder == groupTableView) {
		return [self validateRemoveSelectedGroupsMenuItem:menuItem];
	} else {
		return NO;
	}
}

- (BOOL) validateAlternateDeleteMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	id firstResponder = [documentWindow firstResponder];
	if (firstResponder == tableView || tableView == [fileSearchController tableView]) {
		return [self validateDeleteSelectionMenuItem:menuItem];
	} else {
		return NO;
	}
}

- (BOOL)validateSelectAllPublicationsMenuItem:(NSMenuItem *)menuItem{
    return ([documentWindow isKeyWindow] == YES);
}

- (BOOL)validateDeselectAllPublicationsMenuItem:(NSMenuItem *)menuItem{
    return ([documentWindow isKeyWindow] == YES);
}

- (BOOL)validateSelectLibraryGroupMenuItem:(NSMenuItem *)menuItem{
    return ([documentWindow isKeyWindow] == YES);
}

- (BOOL) validateSelectDuplicatesMenuItem:(NSMenuItem *)menuItem{
    return YES;
}

- (BOOL) validateSelectPossibleDuplicatesMenuItem:(NSMenuItem *)menuItem{
    [menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Select Duplicates by %@", @"Menu item title"), [sortKey localizedFieldName]]];
    return ([self hasExternalGroupsSelected] == NO);
}

- (BOOL) validateSelectIncompletePublicationsMenuItem:(NSMenuItem *)menuItem{
    return ([self hasExternalGroupsSelected] == NO);
}

- (BOOL)validateFindPanelActionMenuItem:(NSMenuItem *)menuItem {
	switch ([menuItem tag]) {
        case NSFindPanelActionShowFindPanel:
        case NSFindPanelActionNext:
        case NSFindPanelActionPrevious:
        case NSFindPanelActionSetFindString:
			return YES;
		default:
			return NO;
	}
}

- (BOOL)validateEditNewStaticGroupWithSelectionMenuItem:(NSMenuItem *)menuItem {
    NSString *s;
    if ([self hasExternalGroupsSelected])
        s = NSLocalizedString(@"New Static Group With Merged Selection", @"Menu item title");
    else
        s = NSLocalizedString(@"New Static Group With Selection", @"Menu item title");
    [menuItem setTitle:s];
    return ([self numberOfSelectedPubs] > 0);
}

- (BOOL)validateEditNewCategoryGroupWithSelectionMenuItem:(NSMenuItem *)menuItem {
    NSString *s;
    if ([self hasExternalGroupsSelected])
        s = NSLocalizedString(@"New Field Group With Merged Selection", @"Menu item title");
    else
        s = NSLocalizedString(@"New Field Group With Selection", @"Menu item title");
    [menuItem setTitle:s];
    return ([self numberOfSelectedPubs] > 0 && [currentGroupField isEqualToString:@""] == NO);
}

- (BOOL)validateAddSearchBookmarkMenuItem:(NSMenuItem *)menuItem {
    return [self hasSearchGroupsSelected];
}

- (BOOL)validateRevertDocumentToSavedMenuItem:(NSMenuItem *)menuItem {
    return [self isDocumentEdited];
}

- (BOOL)validateChangePreviewDisplayMenuItem:(NSMenuItem *)menuItem {
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    int tag = [menuItem tag], state = NSOffState;
    NSString *style = [menuItem representedObject];
    if (tag == [pw integerForKey:BDSKPreviewDisplayKey] &&
        (tag != BDSKTemplatePreviewDisplay || [style isEqualToString:[pw stringForKey:BDSKPreviewTemplateStyleKey]]))
        state = NSOnState;
    [menuItem setState:state];
    return YES;
}

- (BOOL)validateChangeIntersectGroupsMenuItem:(NSMenuItem *)menuItem {
    [menuItem setState: ((BOOL)[menuItem tag] == [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKIntersectGroupsKey]) ? NSOnState : NSOffState];
    return YES;
}

- (BOOL)validateMergeInExternalGroupMenuItem:(NSMenuItem *)menuItem {
    if ([self hasSharedGroupsSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Shared Group", @"Menu item title")];
        return YES;
    } else if ([self hasURLGroupsSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In External File Group", @"Menu item title")];
        return YES;
    } else if ([self hasScriptGroupsSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Script Group", @"Menu item title")];
        return YES;
    } else if ([self hasSearchGroupsSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Search Group", @"Menu item title")];
        return YES;
    } else {
        [menuItem setTitle:NSLocalizedString(@"Merge In Shared Group", @"Menu item title")];
        return NO;
    }
}

- (BOOL)validateMergeInExternalPublicationsMenuItem:(NSMenuItem *)menuItem {
    if ([self hasSharedGroupsSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Shared Publications", @"Menu item title")];
        return [self numberOfSelectedPubs] > 0;
    } else if ([self hasURLGroupsSelected] || [self hasScriptGroupsSelected] || [self hasSearchGroupsSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In External Publications", @"Menu item title")];
        return [self numberOfSelectedPubs] > 0;
    } else {
        [menuItem setTitle:NSLocalizedString(@"Merge In External Publications", @"Menu item title")];
        return NO;
    }
}

- (BOOL)validateRefreshSharingMenuItem:(NSMenuItem *)menuItem {
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    return ([pw boolForKey:BDSKShouldShareFilesKey]);
}

- (BOOL)validateRefreshSharedBrowsingMenuItem:(NSMenuItem *)menuItem {
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    return ([pw boolForKey:BDSKShouldLookForSharedFilesKey]);
}

- (BOOL)validateRefreshURLGroupsMenuItem:(NSMenuItem *)menuItem {
    return [[groups URLGroups] count] > 0;
}

- (BOOL)validateRefreshScriptGroupsMenuItem:(NSMenuItem *)menuItem {
    return [[groups scriptGroups] count] > 0;
}

- (BOOL)validateRefreshSearchGroupsMenuItem:(NSMenuItem *)menuItem {
    return [[groups searchGroups] count] > 0;
}

- (BOOL)validateRefreshSelectedGroupsMenuItem:(NSMenuItem *)menuItem {
    if([self hasSharedGroupsSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh Shared Group", @"Menu item title")];
        return YES;
    }else if([self hasURLGroupsSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh External File Group", @"Menu item title")];
        return YES;
    }else if([self hasScriptGroupsSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh Script Group", @"Menu item title")];
        return YES;
    }else if([self hasSearchGroupsSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh Search Group", @"Menu item title")];
        return YES;
    } else {
        [menuItem setTitle:NSLocalizedString(@"Refresh External Group", @"Menu item title")];
        return NO;
    }
}

- (BOOL)validateRefreshAllExternalGroupsMenuItem:(NSMenuItem *)menuItem {
    return [[groups URLGroups] count] > 0 ||
           [[groups scriptGroups] count] > 0 ||
           [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldShareFilesKey];
}

- (BOOL)validateChangeSearchTypeMenuItem:(NSMenuItem *)menuItem {
    if ([[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKSearchMenuTagKey] == [menuItem tag])
        [menuItem setState:NSOnState];
    else
        [menuItem setState:NSOffState];
    return YES;
}

- (BOOL)validateOpenBookmarkMenuItem:(NSMenuItem *)menuItem {
    return YES;
}

- (BOOL)validateAddBookmarkMenuItem:(NSMenuItem *)menuItem {
    return [self hasWebGroupSelected];
}

- (BOOL) validateMenuItem:(NSMenuItem*)menuItem{
	SEL act = [menuItem action];

	if (act == @selector(cut:)) {
		return [self validateCutMenuItem:menuItem];
	}
	else if (act == @selector(alternateCut:)) {
		return [self validateAlternateCutMenuItem:menuItem];
	}
	else if (act == @selector(copy:)) {
		return [self validateCopyMenuItem:menuItem];
	}
	else if (act == @selector(copyAsAction:)) {
		return [self validateCopyAsMenuItem:menuItem];
	}
    else if (act == @selector(paste:)) {
		// called through NSTableView_BDSKExtensions
        return [self validatePasteMenuItem:menuItem];
	}
    else if (act == @selector(duplicate:)) {
        return [self validateDuplicateMenuItem:menuItem];
	}
	else if (act == @selector(editPubCmd:)) {
		return [self validateEditSelectionMenuItem:menuItem];
	}
	else if (act == @selector(duplicateTitleToBooktitle:)) {
		return [self validateDuplicateTitleToBooktitleMenuItem:menuItem];
	}
	else if (act == @selector(generateCiteKey:)) {
		return [self validateGenerateCiteKeyMenuItem:menuItem];
	}
	else if (act == @selector(consolidateLinkedFiles:)) {
		return [self validateConsolidateLinkedFilesMenuItem:menuItem];
	}
	else if (act == @selector(removeSelectedPubs:)) {
		return [self validateRemoveSelectionMenuItem:menuItem];
	}
	else if (act == @selector(deleteSelectedPubs:)) {
		return [self validateDeleteSelectionMenuItem:menuItem];
	}
	else if(act == @selector(emailPubCmd:)) {
		return ([self numberOfSelectedPubs] != 0);
	}
	else if(act == @selector(sendToLyX:)) {
		return [self validateSendToLyXMenuItem:menuItem];
	}
	else if(act == @selector(openLocalURL:)) {
		return [self validateOpenLocalURLMenuItem:menuItem];
	}
	else if(act == @selector(revealLocalURL:)) {
		return [self validateRevealLocalURLMenuItem:menuItem];
	}
	else if(act == @selector(openRemoteURL:)) {
		return [self validateOpenRemoteURLMenuItem:menuItem];
	}
	else if(act == @selector(showNotesForLocalURL:)) {
		return [self validateShowNotesForLocalURLMenuItem:menuItem];
	}
	else if(act == @selector(copyNotesForLocalURL:)) {
		return [self validateCopyNotesForLocalURLMenuItem:menuItem];
	}
	else if(act == @selector(openLinkedFile:)) {
		return [self validateOpenLinkedFileMenuItem:menuItem];
	}
	else if(act == @selector(revealLinkedFile:)) {
		return [self validateRevealLinkedFileMenuItem:menuItem];
	}
	else if(act == @selector(openLinkedURL:)) {
		return [self validateOpenLinkedURLMenuItem:menuItem];
	}
	else if(act == @selector(showNotesForLinkedFile:)) {
		return [self validateShowNotesForLinkedFileMenuItem:menuItem];
	}
	else if(act == @selector(copyNotesForLinkedFile:)) {
		return [self validateCopyNotesForLinkedFileMenuItem:menuItem];
	}
	else if(act == @selector(previewAction:)) {
		return [self validatePreviewMenuItem:menuItem];
	}
	else if(act == @selector(toggleShowingCustomCiteDrawer:)) {
		return [self validateToggleToggleCustomCiteDrawerMenuItem:menuItem];
	}
	else if (act == @selector(printDocument:)) {
		return [self validatePrintDocumentMenuItem:menuItem];
	}
	else if (act == @selector(toggleStatusBar:)) {
		return [self validateToggleStatusBarMenuItem:menuItem];
	}
	else if (act == @selector(importFromPasteboardAction:)) {
		return [self validateNewPubFromPasteboardMenuItem:menuItem];
	}
	else if (act == @selector(importFromFileAction:)) {
		return [self validateNewPubFromFileMenuItem:menuItem];
	}
	else if (act == @selector(importFromWebAction:)) {
		return [self validateNewPubFromWebMenuItem:menuItem];
	}
	else if (act == @selector(sortForCrossrefs:)) {
        return [self validateSortForCrossrefsMenuItem:menuItem];
	}
	else if (act == @selector(selectCrossrefParentAction:)) {
        return [self validateSelectCrossrefParentMenuItem:menuItem];
	}
	else if (act == @selector(createNewPubUsingCrossrefAction:)) {
        return [self validateCreateNewPubUsingCrossrefMenuItem:menuItem];
	}
	else if (act == @selector(sortGroupsByGroup:)) {
        return [self validateSortGroupsByGroupMenuItem:menuItem];
	}
	else if (act == @selector(sortGroupsByCount:)) {
        return [self validateSortGroupsByCountMenuItem:menuItem];
	}
	else if (act == @selector(changeGroupFieldAction:)) {
        return [self validateChangeGroupFieldMenuItem:menuItem];
	}
	else if (act == @selector(removeSelectedGroups:)) {
        return [self validateRemoveSelectedGroupsMenuItem:menuItem];
	}
	else if (act == @selector(editGroupAction:)) {
        return [self validateEditGroupMenuItem:menuItem];
	}
	else if (act == @selector(renameGroupAction:)) {
        return [self validateRenameGroupMenuItem:menuItem];
	}
	else if (act == @selector(removeGroupFieldAction:)) {
		// don't allow the removal of the last item
        return ([[menuItem menu] numberOfItems] > 4);
	}
	else if (act == @selector(editAction:)) {
        return [self validateEditActionMenuItem:menuItem];
	}
	else if (act == @selector(delete:)) {
		// called through NSTableView_BDSKExtensions
		return [self validateDeleteMenuItem:menuItem];
    }
	else if (act == @selector(alternateDelete:)) {
		return [self validateAlternateDeleteMenuItem:menuItem];
    }
	else if (act == @selector(selectAllPublications:)){
        return [self validateSelectAllPublicationsMenuItem:menuItem];
    }
	else if (act == @selector(deselectAllPublications:)){
        return [self validateDeselectAllPublicationsMenuItem:menuItem];
    }
	else if (act == @selector(selectLibraryGroup:)){
        return [self validateSelectLibraryGroupMenuItem:menuItem];
    }
	else if (act == @selector(selectDuplicates:)){
        return [self validateSelectDuplicatesMenuItem:menuItem];
    }
	else if (act == @selector(selectPossibleDuplicates:)){
        return [self validateSelectPossibleDuplicatesMenuItem:menuItem];
    }
	else if (act == @selector(selectIncompletePublications:)){
        return [self validateSelectIncompletePublicationsMenuItem:menuItem];
    }
	else if (act == @selector(performFindPanelAction:)){
        return [self validateFindPanelActionMenuItem:menuItem];
    }
    else if (act == @selector(editNewCategoryGroupWithSelection:)){
        return [self validateEditNewCategoryGroupWithSelectionMenuItem:menuItem];
    }
    else if (act == @selector(editNewStaticGroupWithSelection:)){
        return [self validateEditNewStaticGroupWithSelectionMenuItem:menuItem];
    }
    else if (act == @selector(addSearchBookmark:)){
        return [self validateAddSearchBookmarkMenuItem:menuItem];
    }
    else if (act == @selector(revertDocumentToSaved:)){
        return [self validateRevertDocumentToSavedMenuItem:menuItem];
    }
    else if (act == @selector(changePreviewDisplay:)){
        return [self validateChangePreviewDisplayMenuItem:menuItem];
    }
    else if (act == @selector(changeIntersectGroupsAction:)){
        return [self validateChangeIntersectGroupsMenuItem:menuItem];
    }
    else if (act == @selector(mergeInExternalGroup:)){
        return [self validateMergeInExternalGroupMenuItem:menuItem];
    }
    else if (act == @selector(mergeInExternalPublications:)){
        return [self validateMergeInExternalPublicationsMenuItem:menuItem];
    }
    else if (act == @selector(refreshSharing:)){
        return [self validateRefreshSharingMenuItem:menuItem];
    }
    else if (act == @selector(refreshSharedBrowsing:)){
        return [self validateRefreshSharedBrowsingMenuItem:menuItem];
    }
    else if (act == @selector(refreshURLGroups:)){
        return [self validateRefreshURLGroupsMenuItem:menuItem];
    }
    else if (act == @selector(refreshScriptGroups:)){
        return [self validateRefreshScriptGroupsMenuItem:menuItem];
    }
    else if (act == @selector(refreshSearchGroups:)){
        return [self validateRefreshSearchGroupsMenuItem:menuItem];
    }
    else if (act == @selector(refreshAllExternalGroups:)){
        return [self validateRefreshAllExternalGroupsMenuItem:menuItem];
    }
    else if (act == @selector(refreshSelectedGroups:)){
        return [self validateRefreshSelectedGroupsMenuItem:menuItem];
    }
    else if (act == @selector(changeSearchType:)){
        return [self validateChangeSearchTypeMenuItem:menuItem];
    }
    else if (act == @selector(openBookmark:)){
        return [self validateOpenBookmarkMenuItem:menuItem];
    }
    else if (act == @selector(addBookmark:)){
        return [self validateAddBookmarkMenuItem:menuItem];
    }
    else {
		return [super validateMenuItem:menuItem];
    }
}

@end
