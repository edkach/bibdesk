//
//  BibDocument_Groups.m
//  Bibdesk
//
/*
 This software is Copyright (c) 2005
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

#import "BibDocument_Groups.h"
#import "BDSKGroupsArray.h"
#import "BDSKDocumentProtocol.h"
#import "BibDocument_Actions.h"
#import "BDSKGroupCell.h"
#import "NSImage+Toolbox.h"
#import "BDSKFilterController.h"
#import "BDSKGroupTableView.h"
#import "BDSKHeaderPopUpButtonCell.h"
#import "BibDocument_Search.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKAlert.h"
#import "BDSKFieldSheetController.h"
#import "BDSKCountedSet.h"
#import "BibAuthor.h"
#import "BibAppController.h"
#import "BibTypeManager.h"
#import "BDSKSharingBrowser.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKURLGroupSheetController.h"
#import "BDSKScriptGroupSheetController.h"
#import "BibEditor.h"
#import "BibPersonController.h"

@implementation BibDocument (Groups)

#pragma mark Selected group types

- (BOOL)hasAllPublicationsGroupSelected{
    return [groupTableView selectedRow] == 0;
}

- (BOOL)hasSharedGroupsSelected{
    return [groups hasSharedGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasURLGroupsSelected{
    return [groups hasURLGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasScriptGroupsSelected{
    return [groups hasScriptGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasSmartGroupsSelected{
    return [groups hasSmartGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasStaticGroupsSelected{
    return [groups hasStaticGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasCategoryGroupsSelected{
    return [groups hasCategoryGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasExternalGroupsSelected{
    return [groups hasExternalGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

/* 
The groupedPublications array is a subset of the publications array, developed by searching the publications array; shownPublications is now a subset of the groupedPublications array, and searches in the searchfield will search only within groupedPublications (which may include all publications).
*/

- (void)setCurrentGroupField:(NSString *)field{
	if (field != currentGroupField) {
		[currentGroupField release];
		currentGroupField = [field copy];
	}
}	

- (NSString *)currentGroupField{
	return currentGroupField;
}

- (NSArray *)selectedGroups {
    NSIndexSet *indexSet = [groupTableView selectedRowIndexes];
    // returns nil when groupTableView doesn't exist yet
	return nil == indexSet ? nil : [groups objectsAtIndexes:indexSet];
}

#pragma mark Notification handlers

- (void)handleGroupFieldChangedNotification:(NSNotification *)notification{
    // use the most recently changed group as default for newly opened documents; could also store on a per-document basis
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:currentGroupField forKey:BDSKCurrentGroupFieldKey];
	[self updateCategoryGroupsPreservingSelection:NO];
}

- (void)handleFilterChangedNotification:(NSNotification *)notification{
	[self updateAllSmartGroups];
}

- (void)handleGroupTableSelectionChangedNotification:(NSNotification *)notification{
    // Mail and iTunes clear search when changing groups; users don't like this, though.  Xcode doesn't clear its search field, so at least there's some precedent for the opposite side.
    [self displaySelectedGroups];
    // could force selection of row 0 in the main table here, so we always display a preview, but that flashes the group table highlights annoyingly and may cause other selection problems
}

- (void)handleStaticGroupChangedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    [groupTableView reloadData];
    if ([[self selectedGroups] containsObject:group])
        [self displaySelectedGroups];
}

- (void)handleSharedGroupUpdatedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    BOOL succeeded = [[[notification userInfo] objectForKey:@"succeeded"] boolValue];
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        [self sortGroupsByKey:sortGroupsKey];
    }else{
        [groupTableView reloadData];
        if ([[self selectedGroups] containsObject:group] && succeeded == YES)
            [self displaySelectedGroups];
    }
}

- (void)handleSharedGroupsChangedNotification:(NSNotification *)notification{
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupTableView setDelegate:nil];
	NSArray *selectedGroups = [self selectedGroups];
	
    NSMutableArray *array = [[[BDSKSharingBrowser sharedBrowser] sharedGroups] mutableCopy];
    
    id document;
    NSEnumerator *wcEnum = [[self windowControllers] objectEnumerator];
    NSWindowController *wc;
    while(wc = [wcEnum nextObject]){
        if([wc isKindOfClass:[MacroWindowController class]]){
            document = [[(MacroWindowController*)wc macroResolver] document];
            if ([document isKindOfClass:[BDSKSharedGroup class]] && [array containsObjectIdenticalTo:document] == NO)
                [wc hideWindow:nil];
        }
    }
    
    // reset the dictionary of spinners
    if (sharedGroupSpinners == nil) {
        sharedGroupSpinners = [[NSMutableDictionary alloc] initWithCapacity:5];
    } else {
        NSEnumerator *groupEnum = [[groups sharedGroups] objectEnumerator];
        BDSKSharedGroup *group;
        id uniqueID;
        while (group = [groupEnum nextObject]) {
            if([array indexOfObjectIdenticalTo:group] != NSNotFound)
                continue;
            uniqueID = [group uniqueID];
            [[sharedGroupSpinners objectForKey:uniqueID] removeFromSuperview];
            [sharedGroupSpinners removeObjectForKey:uniqueID];
        }
    }
    
    if (array != nil) {
        // now sort using the current column and order
        SEL sortSelector = ([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]) ? @selector(countCompare:) : @selector(nameCompare:);
        [array sortUsingSelector:sortSelector ascending:!docState.sortGroupsDescending];
    }
    [groups setSharedGroups:array];
    [array release];
    
    [groupTableView reloadData];
	NSMutableIndexSet *selIndexes = [[NSMutableIndexSet alloc] init];
	
	// select the current groups, if still around. Otherwise select Library
	if([selectedGroups count] != 0){
		unsigned int row = [groups count];
		while(row--){
			if([selectedGroups containsObject:[groups objectAtIndex:row]])
				[selIndexes addIndex:row];
		}
	}
	if ([selIndexes count] == 0)
		[selIndexes addIndex:0];
	[groupTableView selectRowIndexes:selIndexes byExtendingSelection:NO];
    [selIndexes release];
	
	[self displaySelectedGroups]; // the selection may not have changed, so we won't get this from the notification
    
	// reset ourself as delegate
    [groupTableView setDelegate:self];
}

- (void)handleURLGroupUpdatedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    BOOL succeeded = [[[notification userInfo] objectForKey:@"succeeded"] boolValue];
    
    if ([[groups URLGroups] containsObject:group] == NO)
        return; /// must be from another document
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        [self sortGroupsByKey:sortGroupsKey];
    }else{
        [groupTableView reloadData];
        if ([[self selectedGroups] containsObject:group] && succeeded == YES)
            [self displaySelectedGroups];
    }
}

- (void)handleScriptGroupUpdatedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    BOOL succeeded = [[[notification userInfo] objectForKey:@"succeeded"] boolValue];
    
    if ([[groups scriptGroups] containsObject:group] == NO)
        return; /// must be from another document
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        [self sortGroupsByKey:sortGroupsKey];
    }else{
        [groupTableView reloadData];
        if ([[self selectedGroups] containsObject:group] && succeeded == YES)
            [self displaySelectedGroups];
    }
}

- (void)handleWillRemoveExternalGroupNotification:(NSNotification *)notification{
    NSArray *groupsToRemove = [[notification userInfo] valueForKey:@"groups"];
    NSEnumerator *groupEnum = [groupsToRemove objectEnumerator];
    BDSKGroup *group;
    NSProgressIndicator *spinner;
    NSMutableSet *macroResolvers = [NSMutableSet set];
    
    while(group = [groupEnum nextObject]){
        NSProgressIndicator *spinner = [sharedGroupSpinners objectForKey:[group uniqueID]];
        [spinner removeFromSuperview];
        [sharedGroupSpinners removeObjectForKey:[group uniqueID]];
    }
    
    NSEnumerator *wcEnum = [[self windowControllers] objectEnumerator];
    NSWindowController *wc;
    
    while(wc = [wcEnum nextObject]){
        id doc = nil;
        if([wc isKindOfClass:[MacroWindowController class]])
            doc = [[(MacroWindowController *)wc macroResolver] document];
        else if([wc isKindOfClass:[BibEditor class]])
            doc = [[(BibEditor *)wc publication] document];
        else if([wc isKindOfClass:[BibPersonController class]])
            doc = [[[(BibPersonController *)wc person] publication] document];
        if(doc && [groupsToRemove containsObject:doc])
            [wc hideWindow:nil];
    }
}

- (void)handleAddRemoveGroupNotification:(NSNotification *)notification{
    [groupTableView reloadData];
}

#pragma mark UI updating

// this method uses counted sets to compute the number of publications per group; each group object is just a name
// and a count, and a group knows how to compare itself with other groups for sorting/equality, but doesn't know 
// which pubs are associated with it
- (void)updateCategoryGroupsPreservingSelection:(BOOL)preserve{
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupTableView setDelegate:nil];
    
	NSArray *selectedGroups = [self selectedGroups];
	
    NSString *groupField = [self currentGroupField];
    
    if ([NSString isEmptyString:groupField]) {
        
        [groups setCategoryGroups:[NSArray array]];
        
    } else {
        
        BDSKCountedSet *countedSet;
        if([groupField isPersonField])
            countedSet = [[BDSKCountedSet alloc] initFuzzyAuthorCountedSet];
        else
            countedSet = [[BDSKCountedSet alloc] initCaseInsensitive:YES withCapacity:[publications count]];
        
        int emptyCount = 0;
        
        NSEnumerator *pubEnum = [publications objectEnumerator];
        BibItem *pub;
        
        NSSet *tmpSet = nil;
        while(pub = [pubEnum nextObject]){
            tmpSet = [pub groupsForField:groupField];
            if([tmpSet count])
                [countedSet unionSet:tmpSet];
            else
                emptyCount++;
        }
        
        NSMutableArray *mutableGroups = [[NSMutableArray alloc] initWithCapacity:[countedSet count] + 1];
        NSEnumerator *groupEnum = [countedSet objectEnumerator];
        id groupName;
        BDSKGroup *group;
                
        // now add the group names that we found from our BibItems, using a generic folder icon
        // use OATextWithIconCell keys
        while(groupName = [groupEnum nextObject]){
            group = [[BDSKCategoryGroup alloc] initWithName:groupName key:groupField count:[countedSet countForObject:groupName]];
            [mutableGroups addObject:group];
            [group release];
        }
        
        // now sort using the current column and order
        SEL sortSelector = ([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]) ?
                            @selector(countCompare:) : @selector(nameCompare:);
        [mutableGroups sortUsingSelector:sortSelector ascending:!docState.sortGroupsDescending];
        
        // add the "empty" group at index 0; this is a group of pubs whose value is empty for this field, so they
        // will not be contained in any of the other groups for the currently selected group field (hence multiple selection is desirable)
        if(emptyCount > 0){
            group = [[BDSKCategoryGroup alloc] initEmptyGroupWithKey:groupField count:emptyCount];
            [mutableGroups insertObject:group atIndex:0];
            [group release];
        }
        
        [groups setCategoryGroups:mutableGroups];
        [countedSet release];
        [mutableGroups release];
        
    }
    
    // update the count for the first item, not sure if it should be done here
    [[groups allPublicationsGroup] setCount:[publications count]];
	
    [groupTableView reloadData];
	NSMutableIndexSet *selIndexes = [[NSMutableIndexSet alloc] init];
	
	// select the current group, if still around. Otherwise select Library
	if(preserve && [selectedGroups count] != 0){
		unsigned int row = [groups count];
		while(row--){
			if([selectedGroups containsObject:[groups objectAtIndex:row]])
				[selIndexes addIndex:row];
		}
	}
	if ([selIndexes count] == 0)
		[selIndexes addIndex:0];
	[groupTableView selectRowIndexes:selIndexes byExtendingSelection:NO];
    [selIndexes release];
	
	[self displaySelectedGroups]; // the selection may not have changed, so we won't get this from the notification
    
	// reset ourself as delegate
    [groupTableView setDelegate:self];
}
	
- (void)displaySelectedGroups{
    NSArray *selectedGroups = [self selectedGroups];
    NSArray *array;
    
    // optimize for single selections
    if ([selectedGroups count] == 1 && [self hasAllPublicationsGroupSelected]) {
        array = publications;
    } else if ([selectedGroups count] == 1 && ([self hasExternalGroupsSelected] || [self hasStaticGroupsSelected])) {
        unsigned int rowIndex = [[groupTableView selectedRowIndexes] firstIndex];
        BDSKGroup *group = [groups objectAtIndex:rowIndex];
        array = [(id)group publications];
    } else {
        // multiple selections are never shared groups, so they are contained in the publications
        NSEnumerator *pubEnum = [publications objectEnumerator];
        BibItem *pub;
        NSEnumerator *groupEnum;
        BDSKGroup *group;
        NSMutableArray *filteredArray = [NSMutableArray arrayWithCapacity:[publications count]];
        BOOL intersectGroups = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKIntersectGroupsKey];
        
        // to take union, we add the items contained in a selected group
        // to intersect, we remove the items not contained in a selected group
        if (intersectGroups)
            [filteredArray setArray:publications];
        
        while (pub = [pubEnum nextObject]) {
            groupEnum = [selectedGroups objectEnumerator];
            while (group = [groupEnum nextObject]) {
                if ([group containsItem:pub] == !intersectGroups) {
                    if (intersectGroups)
                        [filteredArray removeObject:pub];
                    else
                        [filteredArray addObject:pub];
                    break;
                }
            }
        }
        
        array = filteredArray;
    }
    
    [groupedPublications setArray:array];
    
    [self searchFieldAction:searchField]; // redo the search to update the table
}

- (void)selectGroups:(NSArray *)theGroups{
    unsigned count = [groups count];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    while(count--){
        if([theGroups containsObject:[groups objectAtIndex:count]])
            [indexes addIndex:count];
    }
    
    [groupTableView deselectAll:nil];
    [groupTableView selectRowIndexes:indexes byExtendingSelection:NO];
}

- (void)selectGroup:(BDSKGroup *)aGroup{
    [self selectGroups:[NSArray arrayWithObject:aGroup]];
}

// force the smart groups to refilter their items, so the group content and count get redisplayed
// if this becomes slow, we could make filters thread safe and update them in the background
- (void)updateAllSmartGroups{

	NSRange smartRange = [groups rangeOfSmartGroups];
    unsigned int row = NSMaxRange(smartRange);
	BOOL shouldUpdate = NO;
    
    while(NSLocationInRange(--row, smartRange)){
		[(BDSKSmartGroup *)[groups objectAtIndex:row] filterItems:publications];
		if([groupTableView isRowSelected:row])
			shouldUpdate = YES;
    }
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        NSPoint scrollPoint = [[tableView enclosingScrollView] scrollPositionAsPercentage];
        [self sortGroupsByKey:sortGroupsKey];
        [[tableView enclosingScrollView] setScrollPositionAsPercentage:scrollPoint];
    }else{
        [groupTableView reloadData];
        if(shouldUpdate == YES){
            // fix for bug #1362191: after changing a checkbox that removed an item from a smart group, the table scrolled to the top
            NSPoint scrollPoint = [[tableView enclosingScrollView] scrollPositionAsPercentage];
            [self displaySelectedGroups];
            [[tableView enclosingScrollView] setScrollPositionAsPercentage:scrollPoint];
        }
    }
}

- (NSIndexSet *)_indexesOfRowsToHighlightInRange:(NSRange)indexRange tableView:(BDSKGroupTableView *)tview{
   
    if([tableView numberOfSelectedRows] == 0 || 
       [self hasExternalGroupsSelected] == YES)
        return [NSIndexSet indexSet];
    
    // This allows us to be slightly lazy, only putting the visible group rows in the dictionary
    NSIndexSet *visibleIndexes = [NSIndexSet indexSetWithIndexesInRange:indexRange];
    unsigned int cnt = [visibleIndexes count];
    NSRange categoryRange = [groups rangeOfCategoryGroups];
    NSString *groupField = [self currentGroupField];

    // Mutable dictionary with fixed capacity using NSObjects for keys with ints for values; this gives us a fast lookup of row name->index.  Dictionaries can use any pointer-size element for a key or value; see /Developer/Examples/CoreFoundation/Dictionary.  Keys are retained rather than copied for efficiency.  Shark says that BibAuthors are created with alloc/init when using the copy callbacks, so NSShouldRetainWithZone() must be returning NO?
    CFMutableDictionaryRef rowDict;
    
    // group objects are either BibAuthors or NSStrings; we need to use case-insensitive or fuzzy author matching, since that's the way groups are checked for containment
    if([groupField isPersonField]){
        rowDict = CFDictionaryCreateMutable(CFAllocatorGetDefault(), cnt, &BDSKFuzzyDictionaryKeyCallBacks, &OFIntegerDictionaryValueCallbacks);
    } else {
        rowDict = CFDictionaryCreateMutable(CFAllocatorGetDefault(), cnt, &BDSKCaseInsensitiveStringKeyDictionaryCallBacks, &OFIntegerDictionaryValueCallbacks);
    }
    
    cnt = [visibleIndexes firstIndex];
    
    // exclude smart and shared groups
    while(cnt != NSNotFound){
		if(NSLocationInRange(cnt, categoryRange))
			CFDictionaryAddValue(rowDict, (void *)[[[groups categoryGroups] objectAtIndex:cnt - categoryRange.location] name], (void *)cnt);
        cnt = [visibleIndexes indexGreaterThanIndex:cnt];
    }
    
    // Use this for the indexes we're going to return
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    // Unfortunately, we have to check all of the items in the main table, since hidden items may have a visible group
    NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
    unsigned int rowIndex = [rowIndexes firstIndex];
    CFSetRef possibleGroups;
        
    id *groupNamePtr;
    
    // use a static pointer to a buffer, with initial size of 10
    static id *groupValues = NULL;
    static int groupValueMaxSize = 10;
    if(NULL == groupValues)
        groupValues = (id *)NSZoneMalloc(NSDefaultMallocZone(), groupValueMaxSize * sizeof(id));
    int groupCount = 0;
    
    // we could iterate the dictionary in the outer loop and publications in the inner loop, but there are generally more publications than groups (and we only check visible groups), so this should be more efficient
    while(rowIndexes != nil && rowIndex != NSNotFound){ 
        
        // here are all the groups that this item can be a part of
        possibleGroups = (CFSetRef)[[shownPublications objectAtIndex:rowIndex] groupsForField:groupField];
        
        groupCount = CFSetGetCount(possibleGroups);
        if(groupCount > groupValueMaxSize){
            NSAssert1(groupCount < 1024, @"insane number of groups for %@", [[shownPublications objectAtIndex:rowIndex] citeKey]);
            groupValues = NSZoneRealloc(NSDefaultMallocZone(), groupValues, sizeof(id) * groupCount);
            groupValueMaxSize = groupCount;
        }
        
        // get all the groups (authors or strings)
        if(groupCount > 0){
            
            // this is the only way to enumerate a set with CF, apparently
            CFSetGetValues(possibleGroups, (const void **)groupValues);
            groupNamePtr = groupValues;
            
            while(groupCount--){
                // The dictionary only has visible group rows, so not all of the keys (potential groups) will exist in the dictionary
                if(CFDictionaryGetValueIfPresent(rowDict, (void *)*groupNamePtr++, (const void **)&cnt))
                    [indexSet addIndex:cnt];
            }
        }
        
        rowIndex = [rowIndexes indexGreaterThanIndex:rowIndex];
    }
    
    CFRelease(rowDict);
    
    // handle smart and static groups separately, since they have a different approach to containment
    NSMutableIndexSet *staticAndSmartIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:[groups rangeOfSmartGroups]];
    [staticAndSmartIndexes addIndexesInRange:[groups rangeOfStaticGroups]];
    
    if([staticAndSmartIndexes count]){
        rowIndexes = [tableView selectedRowIndexes];
        rowIndex = [rowIndexes firstIndex];
        
        int groupIndex;
        id aGroup;
        
        // enumerate selected publication indexes once, since it should be a much longer array than static + smart groups
        while(rowIndex != NSNotFound){
            
            BibItem *pub = [shownPublications objectAtIndex:rowIndex];
            groupIndex = [staticAndSmartIndexes firstIndex];
            
            // may not be worth it to check for visibility...
            while(groupIndex != NSNotFound && [visibleIndexes containsIndex:groupIndex]){
                aGroup = [groups objectAtIndex:groupIndex];
                if([aGroup containsItem:pub])
                    [indexSet addIndex:groupIndex];
                groupIndex = [staticAndSmartIndexes indexGreaterThanIndex:groupIndex];
            }
            rowIndex = [rowIndexes indexGreaterThanIndex:rowIndex];
        }
    }
    
    return indexSet;
}

- (NSIndexSet *)_tableViewSingleSelectionIndexes:(BDSKGroupTableView *)tview{
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:[groups rangeOfSharedGroups]];
    [indexes addIndexesInRange:[groups rangeOfURLGroups]];
    [indexes addIndexesInRange:[groups rangeOfScriptGroups]];
    [indexes addIndex:0];
    return indexes;
}

- (NSMenu *)groupFieldsMenu {
	NSMenu *menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
	NSMenuItem *menuItem;
	NSEnumerator *fieldEnum = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] objectEnumerator];
	NSString *field;
	
    [menu addItemWithTitle:NSLocalizedString(@"No Field", @"No Field") action:NULL keyEquivalent:@""];
	
	while (field = [fieldEnum nextObject]) {
		[menu addItemWithTitle:field action:NULL keyEquivalent:@""];
	}
    
    [menu addItem:[NSMenuItem separatorItem]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Add Field", @"") stringByAppendingEllipsis]
										  action:@selector(addGroupFieldAction:)
								   keyEquivalent:@""];
	[menuItem setTarget:self];
	[menu addItem:menuItem];
    [menuItem release];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Remove Field", @"") stringByAppendingEllipsis]
										  action:@selector(removeGroupFieldAction:)
								   keyEquivalent:@""];
	[menuItem setTarget:self];
	[menu addItem:menuItem];
    [menuItem release];
	
	return [menu autorelease];
}

- (NSMenu *)tableView:(BDSKGroupTableView *)aTableView menuForTableHeaderColumn:(NSTableColumn *)tableColumn onPopUp:(BOOL)flag{
	if ([[tableColumn identifier] isEqualToString:@"group"] && flag == NO) {
		return [[NSApp delegate] groupSortMenu];
	}
	return nil;
}

#pragma mark Actions

- (IBAction)sortGroupsByGroup:(id)sender{
	if ([sortGroupsKey isEqualToString:BDSKGroupCellStringKey]) return;
	[self sortGroupsByKey:BDSKGroupCellStringKey];
}

- (IBAction)sortGroupsByCount:(id)sender{
	if ([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]) return;
	[self sortGroupsByKey:BDSKGroupCellCountKey];
}

- (IBAction)changeGroupFieldAction:(id)sender{
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	NSString *field = ([headerCell indexOfSelectedItem] == 0) ? @"" : [headerCell titleOfSelectedItem];
    
	if(![field isEqualToString:currentGroupField]){
		[self setCurrentGroupField:field];
        [headerCell setTitle:field];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldChangedNotification
															object:self
														  userInfo:[NSDictionary dictionary]];
	}
}

// for adding/removing groups, we use the searchfield sheets
    
- (void)addGroupFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *newGroupField = [addFieldController field];
    if(returnCode == NSCancelButton || newGroupField == nil)
        return; // the user canceled
    
	if([[[BibTypeManager sharedManager] invalidGroupFields] containsObject:newGroupField] || [newGroupField isEqualToString:@""]){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Field", @"Invalid Field")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                            informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The field \"%@\" can not be used for groups.", @""), newGroupField]];
        [alert beginSheetModalForWindow:documentWindow modalDelegate:self didEndSelector:NULL contextInfo:NULL];
		return;
	}
	
	NSMutableArray *array = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] mutableCopy];
	[array addObject:newGroupField];
	[[OFPreferenceWrapper sharedPreferenceWrapper] setObject:array forKey:BDSKGroupFieldsKey];	
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldAddRemoveNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:newGroupField, NSKeyValueChangeNewKey, [NSNumber numberWithInt:NSKeyValueChangeInsertion], NSKeyValueChangeKindKey, nil]];        
    
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	
	[headerCell insertItemWithTitle:newGroupField atIndex:[array count]];
	[self setCurrentGroupField:newGroupField];
	[headerCell selectItemWithTitle:currentGroupField];
	[headerCell setTitle:currentGroupField];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldChangedNotification
														object:self
													  userInfo:[NSDictionary dictionary]];
    [array release];
}    

- (IBAction)addGroupFieldAction:(id)sender{
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	
	[headerCell setTitle:currentGroupField];
    if ([currentGroupField isEqualToString:@""])
        [headerCell selectItemAtIndex:0];
    else 
        [headerCell selectItemWithTitle:currentGroupField];
    
	BibTypeManager *typeMan = [BibTypeManager sharedManager];
	NSArray *groupFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey];
    NSArray *colNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCrossrefString, nil]
                                              excluding:[[[typeMan invalidGroupFields] allObjects] arrayByAddingObjectsFromArray:groupFields]];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of group field:",@"")
                                                                                              fieldsArray:colNames];
	[addFieldController beginSheetModalForWindow:documentWindow
                                   modalDelegate:self
                                  didEndSelector:NULL
                              didDismissSelector:@selector(addGroupFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (void)removeGroupFieldSheetDidEnd:(BDSKRemoveFieldSheetController *)removeFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *oldGroupField = [removeFieldController field];
    if(returnCode == NSCancelButton || [NSString isEmptyString:oldGroupField])
        return;
    
    NSMutableArray *array = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] mutableCopy];
    [array removeObject:oldGroupField];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:array forKey:BDSKGroupFieldsKey];
    [array release];
    
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	
    [headerCell removeItemWithTitle:oldGroupField];
    if([oldGroupField isEqualToString:currentGroupField]){
        [self setCurrentGroupField:@""];
        [headerCell selectItemAtIndex:0];
        [headerCell setTitle:@""];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldChangedNotification
                                                            object:self
                                                          userInfo:[NSDictionary dictionary]];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldAddRemoveNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldGroupField, NSKeyValueChangeNewKey, [NSNumber numberWithInt:NSKeyValueChangeRemoval], NSKeyValueChangeKindKey, nil]];        
}

- (IBAction)removeGroupFieldAction:(id)sender{
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	
	[headerCell setTitle:currentGroupField];
    if ([currentGroupField isEqualToString:@""])
        [headerCell selectItemAtIndex:0];
    else 
        [headerCell selectItemWithTitle:currentGroupField];
    
    BDSKRemoveFieldSheetController *removeFieldController = [[BDSKRemoveFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Group field to remove:",@"")
                                                                                                       fieldsArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey]];
	[removeFieldController beginSheetModalForWindow:documentWindow
                                      modalDelegate:self
                                     didEndSelector:@selector(removeGroupFieldSheetDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
    [removeFieldController release];
}    

- (void)handleGroupFieldAddRemoveNotification:(NSNotification *)notification{
    // Handle changes to the popup from other documents.  The userInfo for this notification uses key-value observing keys: NSKeyValueChangeNewKey is the affected field (whether add/remove), and NSKeyValueChangeKindKey will be either insert/remove
    if([notification object] != self){
        NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
        
        id userInfo = [notification userInfo];
        NSParameterAssert(userInfo && [userInfo valueForKey:NSKeyValueChangeKindKey]);

        NSString *field = [userInfo valueForKey:NSKeyValueChangeNewKey];
        NSParameterAssert(field);
        
        // Ignore this change if we already have that field (shouldn't happen), or are removing the current group field; in the latter case, it's already removed in prefs, so it'll be gone next time the document is opened.  Removing all fields means we have to deal with the add/remove menu items and separator, so avoid that.
        if([[headerCell titleOfSelectedItem] isEqualToString:field] == NO){
            int changeType = [[userInfo valueForKey:NSKeyValueChangeKindKey] intValue];
            
            if(changeType == NSKeyValueChangeInsertion)
                [headerCell insertItemWithTitle:field atIndex:0];
            else if(changeType == NSKeyValueChangeRemoval)
                [headerCell removeItemWithTitle:field];
            else [NSException raise:NSInvalidArgumentException format:@"Unrecognized change type %d", changeType];
        }
    }
}

- (IBAction)addSmartGroupAction:(id)sender {
	BDSKFilterController *filterController = [[BDSKFilterController alloc] init];
    [filterController beginSheetModalForWindow:documentWindow
                                 modalDelegate:self
                                didEndSelector:@selector(smartGroupSheetDidEnd:returnCode:contextInfo:)
                                   contextInfo:NULL];
	[filterController release];
}

- (void)smartGroupSheetDidEnd:(BDSKFilterController *)filterController returnCode:(int) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
		BDSKSmartGroup *group = [[BDSKSmartGroup alloc] initWithFilter:[filterController filter]];
        unsigned int insertIndex = NSMaxRange([groups rangeOfSmartGroups]);
		[groups addSmartGroup:group];
		[group release];
		
		[groupTableView reloadData];
		[groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
		[groupTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Smart Group",@"Add smart group")];
		// updating of the tables is done when finishing the edit of the name
	}
	
}

- (IBAction)addStaticGroupAction:(id)sender {
    BDSKStaticGroup *group = [[BDSKStaticGroup alloc] init];
    unsigned int insertIndex = NSMaxRange([groups rangeOfStaticGroups]);
    [groups addStaticGroup:group];
    [group release];
    
    [groupTableView reloadData];
    [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
    [groupTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
    [[self undoManager] setActionName:NSLocalizedString(@"Add Static Group",@"Add static group")];
    // updating of the tables is done when finishing the edit of the name
}

- (IBAction)addURLGroupAction:(id)sender {
    BDSKURLGroupSheetController *sheetController = [[BDSKURLGroupSheetController alloc] init];
    [sheetController beginSheetModalForWindow:documentWindow
                                modalDelegate:self
                               didEndSelector:@selector(URLGroupSheetDidEnd:returnCode:contextInfo:)
                                  contextInfo:NULL];
    [sheetController release];
}

- (void)URLGroupSheetDidEnd:(BDSKURLGroupSheetController *)sheetController returnCode:(int) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
        unsigned int insertIndex = NSMaxRange([groups rangeOfURLGroups]);
		[groups addURLGroup:[sheetController group]];
        
		[groupTableView reloadData];
		[groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
		[groupTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Add External File Group",@"Add external file group")];
		// updating of the tables is done when finishing the edit of the name
	}
}

- (IBAction)addScriptGroupAction:(id)sender {
    BDSKScriptGroupSheetController *sheetController = [[BDSKScriptGroupSheetController alloc] init];
    [sheetController beginSheetModalForWindow:documentWindow
                                modalDelegate:self
                               didEndSelector:@selector(scriptGroupSheetDidEnd:returnCode:contextInfo:)
                                  contextInfo:NULL];
    [sheetController release];
}

- (void)scriptGroupSheetDidEnd:(BDSKScriptGroupSheetController *)sheetController returnCode:(int) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
        unsigned int insertIndex = NSMaxRange([groups rangeOfScriptGroups]);
		[groups addScriptGroup:[sheetController group]];
        
		[groupTableView reloadData];
		[groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
		[groupTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Script Group",@"Add script group")];
		// updating of the tables is done when finishing the edit of the name
	}
	
}

- (IBAction)addGroupButtonAction:(id)sender {
    if ([NSApp currentModifierFlags] & NSAlternateKeyMask)
        [self addSmartGroupAction:sender];
    else
        [self addStaticGroupAction:sender];
}

- (IBAction)removeSelectedGroups:(id)sender {
	NSIndexSet *rowIndexes = [groupTableView selectedRowIndexes];
    unsigned int rowIndex = [rowIndexes lastIndex];
	BDSKGroup *group;
	unsigned int count = 0;
	
	while (rowIndexes != nil && rowIndex != NSNotFound) {
		group = [groups objectAtIndex:rowIndex];
		if ([group isSmart] == YES) {
			[groups removeSmartGroup:(BDSKSmartGroup *)group];
			count++;
		} else if ([group isStatic] == YES && group != [groups lastImportGroup]) {
			[groups removeStaticGroup:(BDSKStaticGroup *)group];
			count++;
		} else if ([group isURL] == YES) {
			[groups removeURLGroup:(BDSKURLGroup *)group];
			count++;
		} else if ([group isScript] == YES) {
			[groups removeScriptGroup:(BDSKScriptGroup *)group];
			count++;
        }
		rowIndex = [rowIndexes indexLessThanIndex:rowIndex];
	}
	if (count == 0) {
		NSBeep();
	} else {
		[[self undoManager] setActionName:NSLocalizedString(@"Remove Groups",@"Remove groups")];
        [groupTableView reloadData];
        [self displaySelectedGroups];
	}
}

- (IBAction)editGroupAction:(id)sender {
	if ([groupTableView numberOfSelectedRows] != 1) {
		NSBeep();
		return;
	} 
	
	int row = [groupTableView selectedRow];
	OBASSERT(row != -1);
	if(row <= 0) return;
	BDSKGroup *group = [groups objectAtIndex:row];
	
    if ([group isEditable] == NO) {
		NSBeep();
        return;
    }
    
	if ([group isSmart]) {
		BDSKFilter *filter = [(BDSKSmartGroup *)group filter];
		BDSKFilterController *filterController = [[BDSKFilterController alloc] initWithFilter:filter];
        [filterController beginSheetModalForWindow:documentWindow];
        [filterController release];
	} else if ([group isCategory]) {
        // this must be a person field
        OBASSERT([[group name] isKindOfClass:[BibAuthor class]]);
		[self showPerson:(BibAuthor *)[group name]];
	} else if ([group isURL]) {
        BDSKURLGroupSheetController *sheetController = [(BDSKURLGroupSheetController *)[BDSKURLGroupSheetController alloc] initWithGroup:(BDSKURLGroup *)group];
        [sheetController beginSheetModalForWindow:documentWindow];
        [sheetController release];
	} else if ([group isScript]) {
        BDSKScriptGroupSheetController *sheetController = [(BDSKScriptGroupSheetController *)[BDSKScriptGroupSheetController alloc] initWithGroup:(BDSKScriptGroup *)group];
        [sheetController beginSheetModalForWindow:documentWindow];
        [sheetController release];
	}
}

- (IBAction)renameGroupAction:(id)sender {
	if ([groupTableView numberOfSelectedRows] != 1) {
		NSBeep();
		return;
	} 
	
	int row = [groupTableView selectedRow];
	OBASSERT(row != -1);
	if (row <= 0) return;
    
    if([self tableView:groupTableView shouldEditTableColumn:[[groupTableView tableColumns] objectAtIndex:0] row:row])
		[groupTableView editColumn:0 row:row withEvent:nil select:YES];
	
}

- (IBAction)selectAllPublicationsGroup:(id)sender {
	[groupTableView deselectAll:sender];
}

- (IBAction)changeIntersectGroupsAction:(id)sender {
    BOOL flag = (BOOL)[sender tag];
    if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKIntersectGroupsKey] != flag) {
        [[OFPreferenceWrapper sharedPreferenceWrapper] setBool:flag forKey:BDSKIntersectGroupsKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupTableSelectionChangedNotification object:self];
    }
}

- (IBAction)editNewGroupWithSelection:(id)sender{
    NSArray *names = [[groups staticGroups] valueForKeyPath:@"@distinctUnionOfObjects.name"];
    NSArray *pubs = [self selectedPublications];
    NSString *baseName = NSLocalizedString(@"Untitled", @"");
    NSString *name = baseName;
    BDSKStaticGroup *group;
    unsigned int i = 1;
    while([names containsObject:name]){
        name = [NSString stringWithFormat:@"%@%d", baseName, i++];
    }
    
    // first merge in shared groups
    if ([self hasExternalGroupsSelected])
        pubs = [self mergeInPublications:pubs];
    
    group = [[[BDSKStaticGroup alloc] initWithName:name publications:pubs] autorelease];
    
    [groups addStaticGroup:group];    
    [groupTableView deselectAll:nil];
    
    i = [[groups staticGroups] indexOfObject:group];
    OBASSERT(i != NSNotFound);
    
    if(i != NSNotFound){
        i += [groups rangeOfStaticGroups].location;
        [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
        [groupTableView scrollRowToVisible:i];
        
        [groupTableView editColumn:0 row:i withEvent:nil select:YES];
    }
}

- (IBAction)mergeInExternalGroup:(id)sender{
    if ([self hasExternalGroupsSelected] == NO) {
        NSBeep();
        return;
    }
    // we should have a single external group selected
    NSArray *pubs = [[[self selectedPublications] lastObject] publications];
    [self mergeInPublications:pubs];
}

- (IBAction)mergeInExternalPublications:(id)sender{
    if ([self hasExternalGroupsSelected] == NO || [self numberOfSelectedPubs] == 0) {
        NSBeep();
        return;
    }
    [self mergeInPublications:[self selectedPublications]];
}

- (IBAction)refreshURLGroups:(id)sender{
    [[groups URLGroups] makeObjectsPerformSelector:@selector(setPublications:) withObject:nil];
}

- (IBAction)refreshScriptGroups:(id)sender{
    [[groups scriptGroups] makeObjectsPerformSelector:@selector(setPublications:) withObject:nil];
}

- (IBAction)refreshAllExternalGroups:(id)sender{
    [self refreshSharedBrowsing:sender];
    [self refreshURLGroups:sender];
    [self refreshScriptGroups:sender];
}

#pragma mark Add or remove items

- (NSArray *)mergeInPublications:(NSArray *)items{
    // first construct a set of current items to compare based on BibItem equality callbacks
    CFIndex countOfItems = [publications count];
    BibItem **pubs = (BibItem **)NSZoneMalloc([self zone], sizeof(BibItem *) * countOfItems);
    [publications getObjects:pubs];
    NSSet *currentPubs = (NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)pubs, countOfItems, &BDSKBibItemEqualityCallBacks);
    NSZoneFree([self zone], pubs);
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[items count]];
    NSEnumerator *pubEnum = [items objectEnumerator];
    BibItem *pub;
    
    while (pub = [pubEnum nextObject]) {
        if ([currentPubs containsObject:pub] == NO)
            [array addObject:pub];
    }
    
    if ([array count] == 0)
        return [NSArray array];
    
    // archive and unarchive mainly to get complex strings with the correct macroResolver
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    NSArray *newPubs;
    
    [archiver encodeObject:array forKey:@"publications"];
    [archiver finishEncoding];
    [archiver release];
    
    newPubs = [self newPublicationsFromArchivedData:data];
    
    [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];    
	[self addPublications:newPubs];
	[self selectPublications:newPubs];
    
    [groups setLastImportedPublications:newPubs];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Merge Shared Publications",@"")];
    
    return newPubs;
}

- (BOOL)addPublications:(NSArray *)pubs toGroup:(BDSKGroup *)group{
	OBASSERT([group isSmart] == NO && [group isExternal] == NO && group != [groups allPublicationsGroup] && group != [groups lastImportGroup]);
    
    if ([group isStatic]) {
        [(BDSKStaticGroup *)group addPublicationsFromArray:pubs];
		[[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Add to group")];
        return YES;
    }
    
    NSEnumerator *pubEnum = [pubs objectEnumerator];
    BibItem *pub;
	int count = 0;
	int handleInherited = BDSKOperationAsk;
	int rv;
    
    while(pub = [pubEnum nextObject]){
        OBASSERT([pub isKindOfClass:[BibItem class]]);        
        
		rv = [pub addToGroup:group handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
			count++;
		}else if(rv == BDSKOperationAsk){
			NSString *otherButton = nil;
			if([[self currentGroupField] isSingleValuedField] == NO)
				otherButton = NSLocalizedString(@"Append", @"Append");
			
			BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"alert title")
												 defaultButton:NSLocalizedString(@"Don't Change", @"Don't change")
											   alternateButton:NSLocalizedString(@"Set", @"Set")
												   otherButton:otherButton
									 informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"")];
			rv = [alert runSheetModalForWindow:documentWindow];
			handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
				[pub addToGroup:group handleInherited:handleInherited];
                count++;
			}
		}
    }
	
	if(count > 0)
		[[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Add to group")];
    
    return YES;
}

- (BOOL)removePublications:(NSArray *)pubs fromGroups:(NSArray *)groupArray{
    NSEnumerator *groupEnum = [groupArray objectEnumerator];
	BDSKGroup *group;
	int count = 0;
	int handleInherited = BDSKOperationAsk;
	NSString *groupName = nil;
    
    while(group = [groupEnum nextObject]){
		if([group isSmart] == YES || [group isExternal] == YES || group == [groups allPublicationsGroup] || group == [groups lastImportGroup])
			continue;
		
		if (groupName == nil)
			groupName = [NSString stringWithFormat:@"group %@", [group name]];
		else
			groupName = @"selected groups";
		
        if ([group isStatic]) {
            [(BDSKStaticGroup *)group removePublicationsInArray:pubs];
            [[self undoManager] setActionName:NSLocalizedString(@"Remove From Group", @"Remove from group")];
            count = [pubs count];
            continue;
        } else if ([group isCategory] && [[(BDSKCategoryGroup *)group key] isSingleValuedField]) {
            continue;
        }
		
		NSEnumerator *pubEnum = [pubs objectEnumerator];
		BibItem *pub;
		int rv;
        int tmpCount = 0;
		
		while(pub = [pubEnum nextObject]){
			OBASSERT([pub isKindOfClass:[BibItem class]]);        
			
			rv = [pub removeFromGroup:group handleInherited:handleInherited];
			
			if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
				tmpCount++;
			}else if(rv == BDSKOperationAsk){
				BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"alert title")
													 defaultButton:NSLocalizedString(@"Don't Change", @"Don't change")
												   alternateButton:nil
													   otherButton:NSLocalizedString(@"Remove", @"Remove")
										 informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"")];
				rv = [alert runSheetModalForWindow:documentWindow];
				handleInherited = rv;
				if(handleInherited != BDSKOperationIgnore){
					[pub removeFromGroup:group handleInherited:handleInherited];
                    tmpCount++;
				}
			}
		}
        
        count = MAX(count, tmpCount);
	}
	
	if(count > 0){
		[[self undoManager] setActionName:NSLocalizedString(@"Remove from Group", @"Remove from group")];
		NSString * pubSingularPlural;
		if (count == 1)
			pubSingularPlural = NSLocalizedString(@"publication", @"publication");
		else
			pubSingularPlural = NSLocalizedString(@"publications", @"publications");
		[self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Removed %i %@ from %@",@"Removed [number] publications(s) from selected group(s)"), count, pubSingularPlural, groupName] immediate:NO];
	}
    
    return YES;
}

- (BOOL)movePublications:(NSArray *)pubs fromGroup:(BDSKGroup *)group toGroupNamed:(NSString *)newGroupName{
	int count = 0;
	int handleInherited = BDSKOperationAsk;
	NSEnumerator *pubEnum = [pubs objectEnumerator];
	BibItem *pub;
	int rv;
	
	if([group isCategory] == NO)
		return NO;
	
	while(pub = [pubEnum nextObject]){
		OBASSERT([pub isKindOfClass:[BibItem class]]);        
		
		rv = [pub replaceGroup:group withGroupNamed:newGroupName handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
			count++;
		}else if(rv == BDSKOperationAsk){
			BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"alert title")
												 defaultButton:NSLocalizedString(@"Don't Change", @"Don't change")
											   alternateButton:nil
												   otherButton:NSLocalizedString(@"Remove", @"Remove")
									 informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"")];
			rv = [alert runSheetModalForWindow:documentWindow];
			handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
				[pub replaceGroup:group withGroupNamed:newGroupName handleInherited:handleInherited];
                count++;
			}
		}
	}
	
	if(count > 0)
		[[self undoManager] setActionName:NSLocalizedString(@"Rename Group", @"Rename group")];
    
    return YES;
}

#pragma mark Sorting

- (void)sortGroupsByKey:(NSString *)key{
    if (key == nil) {
        // clicked the sort arrow in the table header, change sort order
        docState.sortGroupsDescending = !docState.sortGroupsDescending;
    } else if ([key isEqualToString:sortGroupsKey]) {
		// same key, resort
    } else {
        // change key
        // save new sorting selector, and re-sort the array.
        if ([key isEqualToString:BDSKGroupCellStringKey])
			docState.sortGroupsDescending = NO;
		else
			docState.sortGroupsDescending = YES; // more appropriate for default count sort
		[sortGroupsKey release];
        sortGroupsKey = [key retain];
	}
    
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupTableView setDelegate:nil];
	
    // cache the selection
	NSArray *selectedGroups = [self selectedGroups];
    
	NSSortDescriptor *countSort = [[NSSortDescriptor alloc] initWithKey:@"numberValue" ascending:!docState.sortGroupsDescending  selector:@selector(compare:)];
    [countSort autorelease];

    // could use "name" as key path, but then we'd still have to deal with names that are not NSStrings
    NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"self" ascending:!docState.sortGroupsDescending  selector:@selector(nameCompare:)];
    [nameSort autorelease];

    NSArray *sortDescriptors;
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        if(docState.sortGroupsDescending)
            // doc bug: this is supposed to return a copy of the receiver, but sending -release results in a zombie error
            nameSort = [countSort reversedSortDescriptor];
        sortDescriptors = [NSArray arrayWithObjects:countSort, nameSort, nil];
    } else {
        if(docState.sortGroupsDescending)
            countSort = [countSort reversedSortDescriptor];
        sortDescriptors = [NSArray arrayWithObjects:nameSort, countSort, nil];
    }
    
    [groups sortUsingDescriptors:sortDescriptors];
    
    // Set the graphic for the new column header
	BDSKHeaderPopUpButtonCell *headerPopup = (BDSKHeaderPopUpButtonCell *)[groupTableView popUpHeaderCell];
	[headerPopup setIndicatorImage:[NSImage imageNamed:docState.sortGroupsDescending ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator"]];

    [groupTableView reloadData];
	NSMutableIndexSet *selIndexes = [[NSMutableIndexSet alloc] init];
	
	// select the current groups. Otherwise select Library
	if([selectedGroups count] != 0){
		unsigned int groupsCount = [groups count];
		unsigned int row = -1;
		while(++row < groupsCount){
			if([selectedGroups containsObject:[groups objectAtIndex:row]])
				[selIndexes addIndex:row];
		}
	}
	if ([selIndexes count] == 0)
		[selIndexes addIndex:0];
	[groupTableView selectRowIndexes:selIndexes byExtendingSelection:NO];
	[self displaySelectedGroups];
	
    // reset ourself as delegate
    [groupTableView setDelegate:self];
}

@end
