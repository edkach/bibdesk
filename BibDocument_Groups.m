//
//  BibDocument_Groups.m
//  Bibdesk
//
/*
 This software is Copyright (c) 2005-2012
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
#import "BDSKOwnerProtocol.h"
#import "BibDocument_Actions.h"
#import "BDSKGroupCell.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFilterController.h"
#import "BDSKGroupOutlineView.h"
#import "BibDocument_Search.h"
#import "BibDocument_UI.h"
#import "BibDocument_DataSource.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKWebGroup.h"
#import "BDSKParentGroup.h"
#import "BDSKFieldSheetController.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BDSKAppController.h"
#import "BDSKTypeManager.h"
#import "BDSKSharingBrowser.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKURLGroupSheetController.h"
#import "BDSKScriptGroupSheetController.h"
#import "BDSKEditor.h"
#import "BDSKPersonController.h"
#import "BDSKCollapsibleView.h"
#import "BDSKSearchGroup.h"
#import "BDSKMainTableView.h"
#import "BDSKWebGroupViewController.h"
#import "BDSKSearchGroupSheetController.h"
#import "BDSKSearchGroupViewController.h"
#import "BDSKServerInfo.h"
#import "BDSKSearchBookmarkController.h"
#import "BDSKSearchBookmark.h"
#import "BDSKSharingClient.h"
#import "WebURLsWithTitles.h"
#import "NSColor_BDSKExtensions.h"
#import "NSView_BDSKExtensions.h"
#import "BDSKCFCallBacks.h"
#import "BDSKFileContentSearchController.h"
#import "NSEvent_BDSKExtensions.h"
#import "NSSplitView_BDSKExtensions.h"
#import "BDSKButtonBar.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKBookmarkSheetController.h"
#import "BDSKBookmarkController.h"


@implementation BibDocument (Groups)

#pragma mark Selected group types

- (BOOL)hasLibraryGroupSelected{
    return [[self selectedGroups] lastObject] == [groups libraryGroup];
}

- (BOOL)hasLastImportGroupSelected{
    return [[self selectedGroups] containsObject:[groups lastImportGroup]];
}

- (BOOL)hasWebGroupsSelected{
    return [[[self selectedGroups] lastObject] isWeb];
}

- (BOOL)hasSharedGroupsSelected{
    return [[[self selectedGroups] lastObject] isShared];
}

- (BOOL)hasURLGroupsSelected{
    return [[[self selectedGroups] lastObject] isURL];
}

- (BOOL)hasScriptGroupsSelected{
    return [[[self selectedGroups] lastObject] isScript];
}

- (BOOL)hasSearchGroupsSelected{
    return [[[self selectedGroups] lastObject] isSearch];
}

- (BOOL)hasSmartGroupsSelected{
    return [[[self selectedGroups] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isSmart == YES"]] count] > 0;
}

- (BOOL)hasStaticGroupsSelected{
    return [[[self selectedGroups] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isStatic == YES"]] count] > 0;
}

- (BOOL)hasCategoryGroupsSelected{
    return [[[self selectedGroups] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isCategory == YES"]] count] > 0;
}

- (BOOL)hasExternalGroupsSelected{
    return [[[self selectedGroups] lastObject] isExternal];
}

- (BOOL)hasLibraryGroupClickedOrSelected{
    return [[self clickedOrSelectedGroups] lastObject] == [groups libraryGroup];
}

- (BOOL)hasLastImportGroupClickedOrSelected{
    return [[self clickedOrSelectedGroups] containsObject:[groups lastImportGroup]];
}

- (BOOL)hasWebGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] lastObject] isWeb];
}

- (BOOL)hasSharedGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] lastObject] isShared];
}

- (BOOL)hasURLGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] lastObject] isURL];
}

- (BOOL)hasScriptGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] lastObject] isScript];
}

- (BOOL)hasSearchGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] lastObject] isSearch];
}

- (BOOL)hasSmartGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isSmart == YES"]] count] > 0;
}

- (BOOL)hasStaticGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isStatic == YES"]] count] > 0;
}

- (BOOL)hasCategoryGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isCategory == YES"]] count] > 0;
}

- (BOOL)hasExternalGroupsClickedOrSelected{
    return [[[self clickedOrSelectedGroups] lastObject] isExternal];
}

/* 
The groupedPublications array is a subset of the publications array, developed by searching the publications array; shownPublications is now a subset of the groupedPublications array, and searches in the searchfield will search only within groupedPublications (which may include all publications).
*/

- (void)setCurrentGroupField:(NSString *)field{
	if (field != currentGroupField) {
		[currentGroupField release];
		currentGroupField = [field copy];
		[[groups categoryParent] setName:[NSString isEmptyString:field] ? NSLocalizedString(@"FIELD", @"source list group row title") : [field uppercaseString]];
        // use the most recently changed group as default for newly opened documents; could also store on a per-document basis
        [[NSUserDefaults standardUserDefaults] setObject:currentGroupField forKey:BDSKCurrentGroupFieldKey];
        [self updateCategoryGroupsPreservingSelection:NO];
	}
}	

- (NSString *)currentGroupField{
	return currentGroupField;
}

- (NSArray *)selectedGroups {
    return [groupOutlineView selectedItems];
}

- (NSArray *)clickedOrSelectedGroups {
    NSInteger row = [groupOutlineView clickedRow];
    NSIndexSet *rowIndexes = [groupOutlineView selectedRowIndexes];
    if (row != -1 && [rowIndexes containsIndex:row] == NO)
        rowIndexes = [NSIndexSet indexSetWithIndex:row];
    return [groupOutlineView itemsAtRowIndexes:rowIndexes];
}

#pragma mark Search group view

- (void)showSearchGroupView {
    if (nil == searchGroupViewController)
        searchGroupViewController = [[BDSKSearchGroupViewController alloc] init];
    [self insertControlView:[searchGroupViewController view] atTop:NO];
    
    BDSKSearchGroup *group = [[self selectedGroups] firstObject];
    BDSKASSERT([group isSearch]);
    [searchGroupViewController setGroup:group];
}

- (void)hideSearchGroupView
{
    [self removeControlView:[searchGroupViewController view]];
    [searchGroupViewController setGroup:nil];
}


#pragma mark Web Group 

- (void)showWebGroupView {
    if (webGroupViewController == nil)
        webGroupViewController = [[BDSKWebGroupViewController alloc] init];
    [self insertControlView:[webGroupViewController view] atTop:NO];
    
    WebView *oldWebView = [webGroupViewController webView];
    
    BDSKWebGroup *group = [[self selectedGroups] firstObject];
    BDSKASSERT([group isWeb]);
    
    // load our start page when this was not used before, this must be done before calling [group webView]
    if ([group isWebViewLoaded] == NO)
        [group setURL:[NSURL URLWithString:@"bibdesk:webgroup"]];
    
    [webGroupViewController setWebView:[group webView]];
    
    NSView *webView = [group webView];
    if ([webView window] == nil) {
        if ([oldWebView window]) {
            [webView setFrame:[oldWebView frame]];
            [splitView replaceSubview:oldWebView with:webView];
        } else {
            NSView *view1 = [[splitView subviews] objectAtIndex:0];
            NSView *view2 = [[splitView subviews] objectAtIndex:1];
            NSRect svFrame = [splitView bounds];
            NSRect webFrame = svFrame;
            NSRect tableFrame = svFrame;
            NSRect previewFrame = svFrame;
            CGFloat height = NSHeight(svFrame) - 2 * [splitView dividerThickness];
            CGFloat oldFraction = [splitView fraction];
            
            if (docState.lastWebViewFraction <= 0.0)
                docState.lastWebViewFraction = 0.4;
            
            webFrame.size.height = round(height * docState.lastWebViewFraction);
            previewFrame.size.height = round((height - NSHeight(webFrame)) * oldFraction);
            tableFrame.size.height = height - NSHeight(webFrame) - NSHeight(previewFrame);
            tableFrame.origin.y = NSMaxY(previewFrame) + [splitView dividerThickness];
            webFrame.origin.y = NSMaxY(tableFrame) + [splitView dividerThickness];
            
            [webView setFrame:webFrame];
            [splitView addSubview:webView positioned:NSWindowBelow relativeTo:mainView];
            [webView setFrame:webFrame];
            [view1 setFrame:tableFrame];
            [view2 setFrame:previewFrame];
            [splitView adjustSubviews];
            [splitView setNeedsDisplay:YES];
        }
    }
}

- (void)hideWebGroupView{
    NSView *webView = [webGroupViewController webView];
    if ([webView window]) {
        NSView *webGroupView = [webGroupViewController view];
        id firstResponder = [documentWindow firstResponder];
        if ([firstResponder respondsToSelector:@selector(isDescendantOf:)] && [firstResponder isDescendantOf:webGroupView])
            [documentWindow makeFirstResponder:tableView];
        docState.lastWebViewFraction = NSHeight([webView frame]) / fmax(1.0, NSHeight([splitView frame]) - 2 * [splitView dividerThickness]);
        [webView removeFromSuperview];
        [splitView adjustSubviews];
        [splitView setNeedsDisplay:YES];
    }
    
    [self removeControlView:[webGroupViewController view]];
    [webGroupViewController setWebView:nil];
}

#pragma mark Notification handlers

- (void)handleFilterChangedNotification:(NSNotification *)notification{
    if (NSNotFound != [[groups smartGroups] indexOfObjectIdenticalTo:[notification object]])
        [self updateSmartGroups];
}

- (void)handleGroupTableSelectionChangedNotification:(NSNotification *)notification{
    // called with notification == nil from showFileContentSearch, shouldn't redisplay group content in that case to avoid a loop
    
    NSString *newSortKey = nil;
    
    if ([self hasExternalGroupsSelected]) {
        if ([self isDisplayingSearchButtons]) {
            
            // file content and skim notes search are not compatible with external groups
            if ([BDSKFileContentSearchString isEqualToString:[searchButtonBar representedObjectOfSelectedButton]] || 
                [BDSKSkimNotesString isEqualToString:[searchButtonBar representedObjectOfSelectedButton]])
                [searchButtonBar selectButtonWithRepresentedObject:BDSKAllFieldsString];
            
            [self removeFileSearchItems];
        }
        
        BOOL wasSearch = [self isDisplayingSearchGroupView];
        BOOL wasWeb = [self isDisplayingWebGroupView];
        BOOL isSearch = [self hasSearchGroupsSelected];
        BOOL isWeb = [self hasWebGroupsSelected];
        
        if (isSearch == NO && wasSearch)
            [self hideSearchGroupView];            
        if (isWeb == NO && wasWeb)
            [self hideWebGroupView];
        if (isWeb) {
            if (wasWeb == NO)
                newSortKey = BDSKImportOrderString;
            [self showWebGroupView];
        }
        if (isSearch) {
            if (wasSearch == NO)
                newSortKey = BDSKImportOrderString;
            [self showSearchGroupView];
        }
        [tableView setAlternatingRowBackgroundColors:[NSColor alternateControlAlternatingRowBackgroundColors]];
        [tableView insertTableColumnWithIdentifier:BDSKImportOrderString atIndex:0];
        
    } else {
        if ([self isDisplayingSearchButtons]) {
            [self addFileSearchItems];
        }
        
        [tableView setAlternatingRowBackgroundColors:[NSColor controlAlternatingRowBackgroundColors]];
        [tableView removeTableColumnWithIdentifier:BDSKImportOrderString];
        if ([tmpSortKey isEqualToString:BDSKImportOrderString])
            newSortKey = sortKey;
        [self hideSearchGroupView];
        [self hideWebGroupView];
    }
    // Mail and iTunes clear search when changing groups; users don't like this, though.  Xcode doesn't clear its search field, so at least there's some precedent for the opposite side.
    if (notification)
        [self displaySelectedGroups];
    if (newSortKey)
        [self sortPubsByKey:newSortKey];
    // could force selection of row 0 in the main table here, so we always display a preview, but that flashes the group table highlights annoyingly and may cause other selection problems
}

- (void)handleGroupNameChangedNotification:(NSNotification *)notification{
    if([groups containsGroup:[notification object]] == NO)
        return;
    if([sortGroupsKey isEqualToString:BDSKGroupCellStringKey])
        [self sortGroupsByKey:nil];
    else
        [groupOutlineView setNeedsDisplay:YES];
}

- (void)handleStaticGroupChangedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    
    if ([[groups staticGroups] containsObject:group] == NO && [group isEqual:[groups lastImportGroup]] == NO)
        return; /// must be from another document
    
    [groupOutlineView reloadData];
    if ([[self selectedGroups] containsObject:group])
        [self displaySelectedGroups];
}

- (void)handleSharedGroupsChangedNotification:(NSNotification *)notification{

    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupOutlineView setDelegate:nil];
	NSArray *selectedGroups = [self selectedGroups];
	
    NSMutableSet *clientsToAdd = [[[BDSKSharingBrowser sharedBrowser] sharingClients] mutableCopy];
    NSMutableArray *currentGroups = [[groups sharedGroups] mutableCopy];
    NSArray *currentClients = [currentGroups valueForKey:@"client"];
    NSSet *currentClientsSet = [NSSet setWithArray:currentClients];
    NSMutableSet *clientsToRemove = [currentClientsSet mutableCopy];
    
    [clientsToRemove minusSet:clientsToAdd];
    [clientsToAdd minusSet:currentClientsSet];
    
    [currentGroups removeObjectsAtIndexes:[currentClients indexesOfObjects:[clientsToRemove allObjects]]];
    
    for (BDSKSharingClient *client in clientsToAdd) {
        BDSKSharedGroup *group = [(BDSKSharedGroup *)[BDSKSharedGroup alloc] initWithClient:client];
        [currentGroups addObject:group];
        [group release];
    }
    
    [groups setSharedGroups:currentGroups];
    
    [clientsToRemove release];
    [clientsToAdd release];
    [currentGroups release];
    
    [self removeSpinnersFromSuperview];
    [groupOutlineView reloadData];
    
	// reset ourself as delegate
    [groupOutlineView setDelegate:self];
	
	// select the current groups, if still around. Otherwise this selects Library
    [self selectGroups:selectedGroups];
    
    // the selection may not have changed, so we won't get this from the notification, and we're not the delegate now anyway
    [self displaySelectedGroups]; 
        
    // Don't flag as imported here, since that forces a (re)load of the shared groups, and causes the spinners to start when just opening a document.  The handleSharedGroupUpdatedNotification: should be enough.
}

- (void)handleExternalGroupUpdatedNotification:(NSNotification *)notification{
    BDSKExternalGroup *group = [notification object];
    
    if ([[group document] isEqual:self]) {
        BOOL succeeded = [[[notification userInfo] objectForKey:BDSKExternalGroupSucceededKey] boolValue];
        BOOL isWeb = [group isWeb];
        
        if (isWeb == NO && [sortGroupsKey isEqualToString:BDSKGroupCellCountKey]) {
            [self sortGroupsByKey:nil];
        } else {
            [groupOutlineView reloadData];
            if ([[self selectedGroups] containsObject:group] && (isWeb || succeeded))
                [self displaySelectedGroups];
        }
        
        if (succeeded)
            [self setImported:YES forPublications:publications inGroup:group];
    }
}

- (void)handleWillRemoveGroupsNotification:(NSNotification *)notification{
    if([groupOutlineView editedRow] != -1 && [documentWindow makeFirstResponder:nil] == NO)
        [documentWindow endEditingFor:groupOutlineView];
    for (BDSKGroup *group in [[notification userInfo] valueForKey:BDSKGroupsArrayGroupsKey])
        [self removeSpinnerForGroup:group];
}

- (void)handleDidAddRemoveGroupNotification:(NSNotification *)notification{
    [self removeSpinnersFromSuperview];
    [groupOutlineView reloadData];
    [self handleGroupTableSelectionChangedNotification:notification];
}

#pragma mark UI updating

typedef struct _setAndBagContext {
    CFMutableSetRef set;
    CFMutableBagRef bag;
} setAndBagContext;

static void addObjectToSetAndBag(const void *value, void *context) {
    setAndBagContext *ctxt = context;
    CFSetAddValue(ctxt->set, value);
    CFBagAddValue(ctxt->bag, value);
}

// this method uses counted sets to compute the number of publications per group; each group object is just a name
// and a count, and a group knows how to compare itself with other groups for sorting/equality, but doesn't know 
// which pubs are associated with it
- (void)updateCategoryGroupsPreservingSelection:(BOOL)preserve{

    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    docFlags.ignoreGroupSelectionChange = YES;
    
    NSPoint scrollPoint = [tableView scrollPositionAsPercentage];    
    
	NSArray *selectedGroups = [self selectedGroups];
	
    NSString *groupField = [self currentGroupField];
    
    if ([NSString isEmptyString:groupField]) {
        
        [groups setCategoryGroups:[NSArray array]];
        
    } else {
        
        setAndBagContext setAndBag;
        if([groupField isPersonField]) {
            setAndBag.set = CFSetCreateMutable(kCFAllocatorDefault, 0, &kBDSKAuthorFuzzySetCallBacks);
            setAndBag.bag = CFBagCreateMutable(kCFAllocatorDefault, 0, &kBDSKAuthorFuzzyBagCallBacks);
        } else {
            setAndBag.set = CFSetCreateMutable(kCFAllocatorDefault, 0, &kBDSKCaseInsensitiveStringSetCallBacks);
            setAndBag.bag = CFBagCreateMutable(kCFAllocatorDefault, 0, &kBDSKCaseInsensitiveStringBagCallBacks);
        }
        
        NSArray *oldGroups = [groups categoryGroups];
        NSArray *oldGroupNames = [NSArray array];
        
        if ([groupField isEqualToString:[[oldGroups lastObject] key]] && [groupField isPersonField] == [[oldGroups lastObject] isKindOfClass:[BibAuthor class]])
            oldGroupNames = [oldGroups valueForKey:@"name"];
        else
            oldGroups = nil;
        
        NSInteger emptyCount = 0;
        
        NSSet *tmpSet = nil;
        for (BibItem *pub in publications) {
            tmpSet = [pub groupsForField:groupField];
            if([tmpSet count])
                CFSetApplyFunction((CFSetRef)tmpSet, addObjectToSetAndBag, &setAndBag);
            else
                emptyCount++;
        }
        
        NSMutableArray *mutableGroups = [[NSMutableArray alloc] initWithCapacity:CFSetGetCount(setAndBag.set) + 1];
        BDSKGroup *group;
                
        // now add the group names that we found from our BibItems, using a generic folder icon
        for (id groupName in (NSSet *)(setAndBag.set)) {
            NSUInteger idx = [oldGroupNames indexOfObject:groupName];
            if (idx == NSNotFound)
                group = [[BDSKCategoryGroup alloc] initWithName:groupName key:groupField];
            else
                group = [[oldGroups objectAtIndex:idx] retain];
            [group setCount:CFBagGetCountOfValue(setAndBag.bag, groupName)];
            [mutableGroups addObject:group];
            [group release];
        }
        
        // add the "empty" group at index 0; this is a group of pubs whose value is empty for this field, so they
        // will not be contained in any of the other groups for the currently selected group field (hence multiple selection is desirable)
        if (emptyCount > 0) {
            if ([oldGroups count] && [[oldGroups objectAtIndex:0] isEmpty])
                group = [[oldGroups objectAtIndex:0] retain];
            else
                group = [[BDSKCategoryGroup alloc] initWithName:nil key:groupField];
            [group setCount:emptyCount];
            [mutableGroups insertObject:group atIndex:0];
            [group release];
        }
        
        [groups setCategoryGroups:mutableGroups];
        CFRelease(setAndBag.set);
        CFRelease(setAndBag.bag);
        [mutableGroups release];
        
    }
    
    // update the count for the first item, not sure if it should be done here
    [[groups libraryGroup] setCount:[publications count]];
	
    [self removeSpinnersFromSuperview];
    [groupOutlineView reloadData];
	
	// select the current groups, if still around. Otherwise select Library
	BOOL didSelect = [self selectGroups:selectedGroups];
    
	[self displaySelectedGroups]; // the selection may not have changed, so we won't get this from the notification
    
    // The search: in displaySelectedGroups will change the main table's scroll location, which isn't necessarily what we want (say when clicking the add button for a search group pub).  If we selected the same groups as previously, we should scroll to the old location instead of centering.
    if (didSelect)
        [tableView setScrollPositionAsPercentage:scrollPoint];
    
	// reset
    docFlags.ignoreGroupSelectionChange = NO;
}

// force the smart groups to refilter their items, so the group content and count get redisplayed
// if this becomes slow, we could make filters thread safe and update them in the background
- (void)updateSmartGroupsCountAndContent:(BOOL)shouldUpdate{
    
	// !!! early return if not expanded in outline view
    if ([groupOutlineView isItemExpanded:[groups smartParent]] == NO)
        return;
    
    BOOL needsUpdate = shouldUpdate && [self hasSmartGroupsSelected];
    BOOL hideCount = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKHideGroupCountKey];
    BOOL sortByCount = [sortGroupsKey isEqualToString:BDSKGroupCellCountKey];
    NSArray *smartGroups = [groups smartGroups];
    
    if (hideCount == NO || sortByCount)
        [smartGroups makeObjectsPerformSelector:@selector(filterItems:) withObject:publications];
    
    if (sortByCount) {
        NSPoint scrollPoint = [groupOutlineView scrollPositionAsPercentage];
        [self sortGroupsByKey:nil];
        [groupOutlineView setScrollPositionAsPercentage:scrollPoint];
    } else if (needsUpdate) {
        [groupOutlineView reloadData];
        // fix for bug #1362191: after changing a checkbox that removed an item from a smart group, the table scrolled to the top
        NSPoint scrollPoint = [groupOutlineView scrollPositionAsPercentage];
        [self displaySelectedGroups];
        [groupOutlineView setScrollPositionAsPercentage:scrollPoint];
    } else if (hideCount == NO) {
        [groupOutlineView reloadData];
    }
}

- (void)updateSmartGroupsCount {
    [self updateSmartGroupsCountAndContent:NO];
}

- (void)updateSmartGroups {
    [self updateSmartGroupsCountAndContent:YES];
}

- (void)displaySelectedGroups{
    NSArray *selectedGroups = [self selectedGroups];
    NSArray *array;
    
    // optimize for single selections
    if ([selectedGroups count] == 1 && [self hasLibraryGroupSelected]) {
        array = publications;
    } else if ([selectedGroups count] == 1 && ([self hasExternalGroupsSelected] || [self hasStaticGroupsSelected] || [self hasLastImportGroupSelected])) {
        array = [(id)[selectedGroups lastObject] publications];
    } else {
        // multiple selections are never shared groups, so they are contained in the publications
        NSMutableArray *filteredArray = [NSMutableArray arrayWithCapacity:[publications count]];
        BOOL intersectGroups = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKIntersectGroupsKey];
        
        // to take union, we add the items contained in a selected group
        // to intersect, we remove the items not contained in a selected group
        if (intersectGroups)
            [filteredArray setArray:publications];
        
        for (BibItem *pub in publications) {
            for (BDSKGroup *group in selectedGroups) {
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
    
    if ([self isDisplayingFileContentSearch])
        [fileSearchController filterUsingURLs:[groupedPublications valueForKey:@"identifierURL"]];
    
    [self redoSearch];
}

- (BOOL)selectGroups:(NSArray *)theGroups{
    // expand the parents, or rowForItem: will return -1
    for (id parent in [NSSet setWithArray:[theGroups valueForKey:@"parent"]])
        [groupOutlineView expandItem:parent];

    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    for (id group in theGroups) {
        NSInteger r = [groupOutlineView rowForItem:group];
        if (r != -1) [indexes addIndex:r];
    }
    
    if([indexes count] == 0) {
        // was deselectAll:nil, but that selects the group item...
        [indexes addIndex:1];
        [groupOutlineView selectRowIndexes:indexes byExtendingSelection:NO];
        return NO;
    } else {
        [groupOutlineView selectRowIndexes:indexes byExtendingSelection:NO];
        return YES;
    }
}

- (BOOL)selectGroup:(BDSKGroup *)aGroup{
    return [self selectGroups:[NSArray arrayWithObject:aGroup]];
}

#pragma mark Spinners

- (NSProgressIndicator *)spinnerForGroup:(BDSKGroup *)group{
    NSProgressIndicator *spinner = [groupSpinners objectForKey:group];
    
    if ([group isRetrieving]) {
        if (spinner == nil) {
            // don't use NSMutableDictionary because that copies the groups
            if (groupSpinners == nil)
                groupSpinners = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory | NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory | NSMapTableObjectPointerPersonality capacity:0];
            spinner = [[NSProgressIndicator alloc] init];
            [spinner setControlSize:NSSmallControlSize];
            [spinner setStyle:NSProgressIndicatorSpinningStyle];
            [spinner setDisplayedWhenStopped:NO];
            [spinner sizeToFit];
            [spinner setUsesThreadedAnimation:YES];
            [groupSpinners setObject:spinner forKey:group];
            [spinner release];
        }
        [spinner startAnimation:nil];
    } else if (spinner) {
        [spinner stopAnimation:nil];
        [spinner removeFromSuperview];
        [groupSpinners removeObjectForKey:group];
        spinner = nil;
    }
    
    return spinner;
}

- (void)removeSpinnerForGroup:(BDSKGroup *)group{
    NSProgressIndicator *spinner = [groupSpinners objectForKey:group];
    if (spinner) {
        [spinner stopAnimation:nil];
        [spinner removeFromSuperview];
        [groupSpinners removeObjectForKey:group];
    }
}

- (void)removeSpinnersFromSuperview {
    NSEnumerator *spinnerEnum = [groupSpinners objectEnumerator];
    NSProgressIndicator *spinner;
    while ((spinner = [spinnerEnum nextObject]))
        [spinner removeFromSuperview];
}

#pragma mark Actions

- (IBAction)sortGroupsByGroup:(id)sender{
	[self sortGroupsByKey:BDSKGroupCellStringKey];
}

- (IBAction)sortGroupsByCount:(id)sender{
	[self sortGroupsByKey:BDSKGroupCellCountKey];
}

- (IBAction)changeGroupFieldAction:(id)sender{
    NSString *field = [sender representedObject] ?: @"";
    
	if(NO == [field isEqualToString:currentGroupField])
		[self setCurrentGroupField:field];
}

// for adding/removing groups, we use the searchfield sheets
    
- (void)addGroupFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
	NSString *newGroupField = [addFieldController field];
    if(returnCode == NSCancelButton || newGroupField == nil)
        return; // the user canceled
    
	if([newGroupField isInvalidGroupField] || [newGroupField isEqualToString:@""]){
        [[addFieldController window] orderOut:nil];
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Field", @"Message in alert dialog when choosing an invalid group field")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                            informativeTextWithFormat:@"%@", [NSString stringWithFormat:NSLocalizedString(@"The field \"%@\" can not be used for groups.", @"Informative text in alert dialog"), [newGroupField localizedFieldName]]];
        [alert beginSheetModalForWindow:documentWindow modalDelegate:self didEndSelector:NULL contextInfo:NULL];
		return;
	}
	
	NSMutableArray *array = [[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGroupFieldsKey] mutableCopy];
	if ([array indexOfObject:newGroupField] == NSNotFound)
        [array addObject:newGroupField];
	[[NSUserDefaults standardUserDefaults] setObject:array forKey:BDSKGroupFieldsKey];	
    [self setCurrentGroupField:newGroupField];
    [array release];
}    

- (IBAction)addGroupFieldAction:(id)sender{
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
	NSArray *groupFields = [[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGroupFieldsKey];
    NSArray *colNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCrossrefString, nil]
                                              excluding:[[[typeMan invalidGroupFieldsSet] allObjects] arrayByAddingObjectsFromArray:groupFields]];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of group field:", @"Label for adding group field")
                                                                                              fieldsArray:colNames];
	[addFieldController beginSheetModalForWindow:documentWindow
                                   modalDelegate:self
                                  didEndSelector:@selector(addGroupFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (void)removeGroupFieldSheetDidEnd:(BDSKRemoveFieldSheetController *)removeFieldController returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
	NSString *oldGroupField = [removeFieldController field];
    if(returnCode == NSCancelButton || [NSString isEmptyString:oldGroupField])
        return;
    
    NSMutableArray *array = [[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGroupFieldsKey] mutableCopy];
    [array removeObject:oldGroupField];
    [[NSUserDefaults standardUserDefaults] setObject:array forKey:BDSKGroupFieldsKey];
    [array release];
    
    if([oldGroupField isEqualToString:currentGroupField])
        [self setCurrentGroupField:@""];
}

- (IBAction)removeGroupFieldAction:(id)sender{
    BDSKRemoveFieldSheetController *removeFieldController = [[BDSKRemoveFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Group field to remove:", @"Label for removing group field")
                                                                                                       fieldsArray:[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGroupFieldsKey]];
	[removeFieldController beginSheetModalForWindow:documentWindow
                                      modalDelegate:self
                                     didEndSelector:@selector(removeGroupFieldSheetDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
    [removeFieldController release];
}    

- (IBAction)addSmartGroupAction:(id)sender {
	BDSKFilterController *filterController = [[BDSKFilterController alloc] init];
    [filterController beginSheetModalForWindow:documentWindow
                                 modalDelegate:self
                                didEndSelector:@selector(smartGroupSheetDidEnd:returnCode:contextInfo:)
                                   contextInfo:NULL];
	[filterController release];
}

- (void)editGroupWithoutWarning:(BDSKGroup *)group {
    [groupOutlineView expandItem:[group parent]];
    NSInteger i = [groupOutlineView rowForItem:group];
    BDSKASSERT(i != -1);
    
    if(i != -1){
        [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
        [groupOutlineView scrollRowToVisible:i];
        
        // don't show the warning sheet, since presumably the user wants to change the group name
        [groupOutlineView editColumn:0 row:i withEvent:nil select:YES];
    }
}

- (void)smartGroupSheetDidEnd:(BDSKFilterController *)filterController returnCode:(NSInteger) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
		BDSKSmartGroup *group = [[BDSKSmartGroup alloc] initWithFilter:[filterController filter]];
		[groups addSmartGroup:group];
        [self editGroupWithoutWarning:group];
		[group release];
        [[self undoManager] setActionName:NSLocalizedString(@"Add Smart Group", @"Undo action name")];
		// updating of the tables is done when finishing the edit of the name
	}
	
}

- (IBAction)addStaticGroupAction:(id)sender {
    BDSKStaticGroup *group = [[BDSKStaticGroup alloc] init];
    [groups addStaticGroup:group];
    [self editGroupWithoutWarning:group];
    [group release];
    [[self undoManager] setActionName:NSLocalizedString(@"Add Static Group", @"Undo action name")];
    // updating of the tables is done when finishing the edit of the name
}

- (IBAction)addWebGroupAction:(id)sender {
    BDSKWebGroup *group = [[BDSKWebGroup alloc] init];
    [groups addWebGroup:group];
    [groupOutlineView expandItem:[group parent]];
    NSInteger row = [groupOutlineView rowForItem:group];
    if (row != -1)
        [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [group release];
}

- (void)searchGroupSheetDidEnd:(BDSKSearchGroupSheetController *)sheetController returnCode:(NSInteger) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
        BDSKGroup *group = [sheetController group];
		[groups addSearchGroup:(id)group];
        [groupOutlineView expandItem:[group parent]];
        NSInteger row = [groupOutlineView rowForItem:group];
        if (row != -1)
            [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	}
}

- (IBAction)addSearchGroupAction:(id)sender {
    BDSKSearchGroupSheetController *sheetController = [[BDSKSearchGroupSheetController alloc] init];
    [sheetController beginSheetModalForWindow:documentWindow
                                modalDelegate:self
                               didEndSelector:@selector(searchGroupSheetDidEnd:returnCode:contextInfo:)
                                  contextInfo:NULL];
    [sheetController release];
}

- (IBAction)newSearchGroupFromBookmark:(id)sender {
    NSDictionary *dict = [sender representedObject];
    BDSKSearchGroup *group = [[[BDSKSearchGroup alloc] initWithDictionary:dict] autorelease];
    if (group) {
        [groups addSearchGroup:(id)group];        
        [groupOutlineView expandItem:[group parent]];
        NSInteger row = [groupOutlineView rowForItem:group];
        if (row != -1)
            [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    } else
        NSBeep();
}

- (void)searchBookmarkSheetDidEnd:(BDSKBookmarkSheetController *)sheetController returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        BDSKGroup *group = [[self selectedGroups] lastObject];
        BDSKSearchBookmark *bookmark = [BDSKSearchBookmark searchBookmarkWithInfo:[group dictionaryValue] label:[sheetController stringValue]];
        if (bookmark) {
            BDSKSearchBookmark *folder = [sheetController selectedFolder] ?: [[BDSKSearchBookmarkController sharedBookmarkController] bookmarkRoot];
            [folder insertObject:bookmark inChildrenAtIndex:[folder countOfChildren]];
        }
    }
}

- (void)addMenuItemsForBookmarks:(NSArray *)bookmarksArray level:(NSInteger)level toMenu:(NSMenu *)menu {
    for (BDSKSearchBookmark *bm in bookmarksArray) {
        if ([bm bookmarkType] == BDSKSearchBookmarkTypeFolder) {
            NSString *label = [bm label];
            NSMenuItem *item = [menu addItemWithTitle:label ?: @"" action:NULL keyEquivalent:@""];
            [item setImageAndSize:[bm icon]];
            [item setIndentationLevel:level];
            [item setRepresentedObject:bm];
            [self addMenuItemsForBookmarks:[bm children] level:level+1 toMenu:menu];
        }
    }
}

- (IBAction)addSearchBookmark:(id)sender {
    if ([self hasSearchGroupsSelected] == NO) {
        NSBeep();
        return;
    }
    
    BDSKSearchGroup *group = (BDSKSearchGroup *)[[self selectedGroups] lastObject];
    BDSKBookmarkSheetController *bookmarkSheetController = [[[BDSKBookmarkSheetController alloc] init] autorelease];
	NSPopUpButton *folderPopUp = [bookmarkSheetController folderPopUpButton];
    [bookmarkSheetController setStringValue:[NSString stringWithFormat:@"%@: %@", [[group serverInfo] name], [group name]]];
    [folderPopUp removeAllItems];
    BDSKSearchBookmark *bookmark = [[BDSKSearchBookmarkController sharedBookmarkController] bookmarkRoot];
    [self addMenuItemsForBookmarks:[NSArray arrayWithObjects:bookmark, nil] level:0 toMenu:[folderPopUp menu]];
    [folderPopUp selectItemAtIndex:0];
    
    [bookmarkSheetController beginSheetModalForWindow:[self windowForSheet]
                                        modalDelegate:self 
                                       didEndSelector:@selector(searchBookmarkSheetDidEnd:returnCode:contextInfo:)
                                          contextInfo:NULL];
}

- (IBAction)addURLGroupAction:(id)sender {
    BDSKURLGroupSheetController *sheetController = [[BDSKURLGroupSheetController alloc] init];
    [sheetController beginSheetModalForWindow:documentWindow
                                modalDelegate:self
                               didEndSelector:@selector(URLGroupSheetDidEnd:returnCode:contextInfo:)
                                  contextInfo:NULL];
    [sheetController release];
}

- (void)URLGroupSheetDidEnd:(BDSKURLGroupSheetController *)sheetController returnCode:(NSInteger) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
        BDSKURLGroup *group = [sheetController group];
		[groups addURLGroup:group];
        [group publications];
        [self editGroupWithoutWarning:group];
        [[self undoManager] setActionName:NSLocalizedString(@"Add External File Group", @"Undo action name")];
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

- (void)scriptGroupSheetDidEnd:(BDSKScriptGroupSheetController *)sheetController returnCode:(NSInteger) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
        BDSKScriptGroup *group = [sheetController group];
		[groups addScriptGroup:group];
        [group publications];
        [self editGroupWithoutWarning:group];
        [[self undoManager] setActionName:NSLocalizedString(@"Add Script Group", @"Undo action name")];
		// updating of the tables is done when finishing the edit of the name
	}
	
}

- (void)removeGroups:(NSArray *)theGroups {
    BOOL didRemove = NO;
	
	for (BDSKGroup *group in theGroups) {
		if ([group isSmart]) {
			[groups removeSmartGroup:(BDSKSmartGroup *)group];
			didRemove = YES;
		} else if ([group isStatic]) {
			[groups removeStaticGroup:(BDSKStaticGroup *)group];
			didRemove = YES;
		} else if ([group isURL]) {
			[groups removeURLGroup:(BDSKURLGroup *)group];
			didRemove = YES;
		} else if ([group isScript]) {
			[groups removeScriptGroup:(BDSKScriptGroup *)group];
			didRemove = YES;
		} else if ([group isSearch]) {
			[groups removeSearchGroup:(BDSKSearchGroup *)group];
		} else if ([group isWeb]) {
			[groups removeWebGroup:(BDSKWebGroup *)group];
        }
	}
	if (didRemove) {
		[[self undoManager] setActionName:NSLocalizedString(@"Remove Groups", @"Undo action name")];
        [self displaySelectedGroups];
	}
}

- (IBAction)removeSelectedGroups:(id)sender {
    [self removeGroups:[self clickedOrSelectedGroups]];
}

- (void)editGroup:(BDSKGroup *)group {
    
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
        BDSKASSERT([[group name] isKindOfClass:[BibAuthor class]]);
		[self showPerson:(BibAuthor *)[group name]];
	} else if ([group isURL]) {
        BDSKURLGroupSheetController *sheetController = [(BDSKURLGroupSheetController *)[BDSKURLGroupSheetController alloc] initWithGroup:(BDSKURLGroup *)group];
        [sheetController beginSheetModalForWindow:documentWindow];
        [sheetController release];
	} else if ([group isScript]) {
        BDSKScriptGroupSheetController *sheetController = [(BDSKScriptGroupSheetController *)[BDSKScriptGroupSheetController alloc] initWithGroup:(BDSKScriptGroup *)group];
        [sheetController beginSheetModalForWindow:documentWindow];
        [sheetController release];
	} else if ([group isSearch]) {
        BDSKSearchGroupSheetController *sheetController = [(BDSKSearchGroupSheetController *)[BDSKSearchGroupSheetController alloc] initWithGroup:(BDSKSearchGroup *)group];
        [sheetController beginSheetModalForWindow:documentWindow];
        [sheetController release];
	}
}

- (IBAction)editGroupAction:(id)sender {
    NSArray *selectedGroups = [self clickedOrSelectedGroups];
	if ([selectedGroups count] != 1) {
		NSBeep();
		return;
	} 
	[self editGroup:[selectedGroups lastObject]];
}

- (IBAction)renameGroupAction:(id)sender {
	NSInteger row = [groupOutlineView clickedRow];
    if (row == -1 && [groupOutlineView numberOfSelectedRows] == 1)
        row = [groupOutlineView selectedRow];
	if (row == -1) {
		NSBeep();
		return;
	} 
    
    NSTableColumn *tableColumn = [[groupOutlineView tableColumns] objectAtIndex:0];
    id item = [groupOutlineView itemAtRow:row];
    
    if ([groupOutlineView isRowSelected:row] == NO) {
        if ([self outlineView:groupOutlineView shouldSelectItem:item] == NO) {
            NSBeep();
            return;
        }
        [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
    if ([self outlineView:groupOutlineView shouldEditTableColumn:tableColumn item:item])
		[groupOutlineView editColumn:0 row:row withEvent:nil select:YES];
	
}

- (IBAction)copyGroupURLAction:(id)sender {
	id group = [[self clickedOrSelectedGroups] lastObject];
    NSURL *url = nil;
    NSString *title = nil;
    NSString *theUTI = nil;
    NSData *data = nil;
    
	if ([group isExternal] == NO) {
		NSBeep();
		return;
	} 
    if ([group isSearch]) {
        url = [(BDSKSearchGroup *)group bdsksearchURL];
        title = [[(BDSKSearchGroup *)group serverInfo] name];
    } else if ([group isURL]) {
        url = [(BDSKURLGroup *)group URL];
    } else if ([group isScript] && [(BDSKScriptGroup *)group scriptPath]) {
        url = [NSURL fileURLWithPath:[(BDSKScriptGroup *)group scriptPath]];
    } else if ([group isWeb]) {
        url = [(BDSKWebGroup *)group URL];
        title = [group label];
    }
    if (url == nil) {
		NSBeep();
		return;
	} 
    if (title == nil)
        title = [url isFileURL] ? [[url path] lastPathComponent] : [url absoluteString];
	
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    Class WebURLsWithTitlesClass = NSClassFromString(@"WebURLsWithTitles");
    if (NO == [WebURLsWithTitlesClass respondsToSelector:@selector(writeURLs:andTitles:toPasteboard:)])
        WebURLsWithTitlesClass = Nil;
    
    if ((data = [(NSData *)CFURLCreateData(nil, (CFURLRef)url, kCFStringEncodingUTF8, true) autorelease]))
        theUTI = (NSString *)([url isFileURL] ? kUTTypeFileURL : kUTTypeURL);
    
    if (WebURLsWithTitlesClass) {
        [pboard declareTypes:[NSArray arrayWithObjects:@"WebURLsWithTitlesPboardType", NSURLPboardType, NSStringPboardType, theUTI, @"public.url-name", nil] owner:nil];
        [WebURLsWithTitlesClass writeURLs:[NSArray arrayWithObjects:url, nil] andTitles:[NSArray arrayWithObjects:title, nil] toPasteboard:pboard];
    } else {
        [pboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, theUTI, @"public.url-name", nil] owner:nil];
    }
    
    [url writeToPasteboard:pboard];
    [pboard setString:[url absoluteString] forType:NSStringPboardType];
    
    if (theUTI) {
        [pboard setData:data forType:theUTI];
        [pboard setString:title forType:@"public.url-name"];
    }
}

- (IBAction)selectLibraryGroup:(id)sender {
	[groupOutlineView deselectAll:sender];
}

- (IBAction)changeIntersectGroupsAction:(id)sender {
    BOOL flag = (BOOL)[sender tag];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKIntersectGroupsKey] != flag) {
        [[NSUserDefaults standardUserDefaults] setBool:flag forKey:BDSKIntersectGroupsKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupTableSelectionChangedNotification object:self];
    }
}

- (IBAction)editNewStaticGroupWithSelection:(id)sender{
    NSArray *names = [[groups staticGroups] valueForKeyPath:@"@distinctUnionOfObjects.name"];
    NSArray *pubs = [self selectedPublications];
    NSString *baseName = NSLocalizedString(@"Untitled", @"");
    NSString *name = baseName;
    BDSKStaticGroup *group;
    NSUInteger i = 1;
    while([names containsObject:name]){
        name = [NSString stringWithFormat:@"%@%lu", baseName, (unsigned long)i++];
    }
    
    // first merge in shared groups
    if ([self hasExternalGroupsSelected])
        pubs = [self mergeInPublications:pubs];
    
    group = [[[BDSKStaticGroup alloc] initWithName:name publications:pubs] autorelease];
    
    [groups addStaticGroup:group];    
    [groupOutlineView deselectAll:nil];
    
    [self performSelector:@selector(editGroupWithoutWarning:) withObject:group afterDelay:0.0];
}

- (IBAction)editNewCategoryGroupWithSelection:(id)sender{
    if ([currentGroupField isEqualToString:@""]) {
        NSBeep();
        return;
    }
    
    BOOL isAuthor = [currentGroupField isPersonField];
    NSArray *names = [[groups categoryGroups] valueForKeyPath:isAuthor ? @"@distinctUnionOfObjects.name.lastName" : @"@distinctUnionOfObjects.name"];
    NSArray *pubs = [self selectedPublications];
    NSString *baseName = NSLocalizedString(@"Untitled", @"");
    id name = baseName;
    BDSKCategoryGroup *group;
    NSUInteger i = 1;
    
    while ([names containsObject:name])
        name = [NSString stringWithFormat:@"%@%lu", baseName, (unsigned long)i++];
    if (isAuthor)
        name = [BibAuthor authorWithName:name];
    group = [[[BDSKCategoryGroup alloc] initWithName:name key:currentGroupField] autorelease];
    
    // first merge in shared groups
    if ([self hasExternalGroupsSelected])
        pubs = [self mergeInPublications:pubs];
    
    [self addPublications:pubs toGroup:group];
    [groupOutlineView deselectAll:nil];
    [self updateCategoryGroupsPreservingSelection:NO];
    
    [self performSelector:@selector(editGroupWithoutWarning:) withObject:group afterDelay:0.0];
}

- (IBAction)mergeInExternalGroup:(id)sender{
    // we should have a single external group selected
    id group = [[self clickedOrSelectedGroups] lastObject];
    if ([group isExternal] == NO) {
        NSBeep();
        return;
    }
    [self mergeInPublications:[group publications]];
}

- (IBAction)mergeInExternalPublications:(id)sender{
    if ([self hasExternalGroupsSelected] == NO || [self numberOfClickedOrSelectedPubs] == 0) {
        NSBeep();
        return;
    }
    [self mergeInPublications:[self clickedOrSelectedPublications]];
}

- (IBAction)refreshAllExternalGroups:(id)sender{
    [self refreshSharedBrowsing:sender];
    [[groups URLGroups] setValue:nil forKey:@"publications"];
    [[groups scriptGroups] setValue:nil forKey:@"publications"];
    [[groups searchGroups] setValue:nil forKey:@"publications"];
    for (BDSKWebGroup *group in [groups webGroups]) {
        if ([group isWebViewLoaded])
            [[group webView] reload:nil];
    }
    if ([self hasURLGroupsSelected] || [self hasScriptGroupsSelected] || [self hasSearchGroupsSelected])
        [[[self selectedGroups] lastObject] publications];
}

- (IBAction)refreshSelectedGroups:(id)sender{
    id group = [[self clickedOrSelectedGroups] lastObject];
    if ([group isWeb]) {
        if ([group isWebViewLoaded])
            [[group webView] reload:nil];
        else NSBeep();
    } else if ([group isExternal]) {
        [group setPublications:nil];
        if ([[self selectedGroups] containsObject:group])
            [group publications];
    } else NSBeep();
}

- (IBAction)openBookmark:(id)sender{
    if ([self openURL:[sender representedObject]] == NO)
        NSBeep();
}

- (IBAction)addBookmark:(id)sender {
    if ([self hasWebGroupsSelected])
        [[(BDSKWebGroup *)[[self selectedGroups] lastObject] webView] addBookmark:sender];
    else
        NSBeep();
}

#pragma mark Add or remove items

- (NSArray *)mergeInPublications:(NSArray *)items{
    // first construct a set of current items to compare based on BibItem equality callbacks
    CFIndex countOfItems = [publications count];
    BibItem **pubs = (BibItem **)NSZoneMalloc([self zone], sizeof(BibItem *) * countOfItems);
    [publications getObjects:pubs];
    NSSet *currentPubs = [(NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)pubs, countOfItems, &kBDSKBibItemEquivalenceSetCallBacks) autorelease];
    NSZoneFree([self zone], pubs);
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[items count]];
    
    for (BibItem *pub in items) {
        if ([currentPubs containsObject:pub] == NO)
            [array addObject:pub];
    }
    
    if ([array count] == 0)
        return [NSArray array];
    
    // archive and unarchive mainly to get complex strings with the correct macroResolver
    NSArray *newPubs = [BibItem publicationsFromArchivedData:[BibItem archivedPublications:array] macroResolver:[self macroResolver]];
    
    [self addPublications:newPubs publicationsToAutoFile:nil temporaryCiteKey:nil selectLibrary:YES edit:NO];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Merge External Publications", @"Undo action name")];
    
    return newPubs;
}

- (BOOL)addPublications:(NSArray *)pubs toGroup:(BDSKGroup *)group{
    BDSKPRECONDITION([group isStatic] || [group isCategory]);
    
    if ([group isStatic]) {
        [(BDSKStaticGroup *)group addPublicationsFromArray:pubs];
		[[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Undo action name")];
        return YES;
    }
    
    NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSString *oldValue = nil;
    NSString *field = [group isCategory] ? [(BDSKCategoryGroup *)group key] : nil;
    NSInteger count = 0;
    NSInteger handleInherited = BDSKOperationAsk;
	NSInteger rv;
    
    for (BibItem *pub in pubs) {
        BDSKASSERT([pub isKindOfClass:[BibItem class]]);        
        
        if(field && [field isEqualToString:BDSKPubTypeString] == NO)
            oldValue = [[[pub valueOfField:field] retain] autorelease];
		rv = [pub addToGroup:group handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
            count++;
            if(field && [field isEqualToString:BDSKPubTypeString] == NO){
                [changedPubs addObject:pub];
                [oldValues addObject:oldValue ?: @""];
                [newValues addObject:[pub valueOfField:field]];
            }
		}else if(rv == BDSKOperationAsk){
			NSString *otherButton = nil;
			if([[self currentGroupField] isSingleValuedGroupField] == NO)
				otherButton = NSLocalizedString(@"Append", @"Button title");
			
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")
                                             defaultButton:NSLocalizedString(@"Don't Change", @"Button title")
                                           alternateButton:NSLocalizedString(@"Set", @"Button title")
                                               otherButton:otherButton
                                 informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
			rv = [alert runModal];
			handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
                [pub addToGroup:group handleInherited:handleInherited];
                count++;
                if(field && [field isEqualToString:BDSKPubTypeString] == NO){
                    [changedPubs addObject:pub];
                    [oldValues addObject:oldValue ?: @""];
                    [newValues addObject:[pub valueOfField:field]];
                }
			}
		}
    }
	
	if(count > 0){
        if([changedPubs count])
            [[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Undo action name")];
        [self userChangedField:field ofPublications:changedPubs from:oldValues to:newValues];
    }
    
    return YES;
}

- (BOOL)removePublications:(NSArray *)pubs fromGroups:(NSArray *)groupArray{
	NSInteger count = 0;
	NSInteger handleInherited = BDSKOperationAsk;
	NSString *groupName = nil;
    
    for (BDSKGroup *group in groupArray){
		if([group isCategory] == NO && [group isStatic] == NO)
			continue;
		
		if (groupName == nil)
			groupName = [NSString stringWithFormat:NSLocalizedString(@"group %@", @"Partial status message"), [group name]];
		else
			groupName = NSLocalizedString(@"selected groups", @"Partial status message");
		
        if ([group isStatic]) {
            [(BDSKStaticGroup *)group removePublicationsInArray:pubs];
            [[self undoManager] setActionName:NSLocalizedString(@"Remove From Group", @"Undo action name")];
            count = [pubs count];
            continue;
        }
        
        NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSString *oldValue = nil;
        NSString *field = [(BDSKCategoryGroup *)group key];
		NSInteger rv;
        NSInteger tmpCount = 0;
		
        if([field isSingleValuedGroupField] || [field isEqualToString:BDSKPubTypeString])
            continue;
        
		for (BibItem *pub in pubs) {
			BDSKASSERT([pub isKindOfClass:[BibItem class]]);        
			
            if(field)
                oldValue = [[[pub valueOfField:field] retain] autorelease];
			rv = [pub removeFromGroup:group handleInherited:handleInherited];
			
			if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
				tmpCount++;
                if(field){
                    [changedPubs addObject:pub];
                    [oldValues addObject:oldValue ?: @""];
                    [newValues addObject:[pub valueOfField:field]];
                }
			}else if(rv == BDSKOperationAsk){
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")
                                                 defaultButton:NSLocalizedString(@"Don't Change", @"Button title")
                                               alternateButton:nil
                                                   otherButton:NSLocalizedString(@"Remove", @"Button title")
                                     informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
				rv = [alert runModal];
				handleInherited = rv;
				if(handleInherited != BDSKOperationIgnore){
					[pub removeFromGroup:group handleInherited:handleInherited];
                    tmpCount++;
                    if(field){
                        [changedPubs addObject:pub];
                        [oldValues addObject:oldValue ?: @""];
                        [newValues addObject:[pub valueOfField:field]];
                    }
				}
			}
		}
        
        count = MAX(count, tmpCount);
        if([changedPubs count])
            [self userChangedField:field ofPublications:changedPubs from:oldValues to:newValues];
	}
	
	if(count > 0){
		[[self undoManager] setActionName:NSLocalizedString(@"Remove from Group", @"Undo action name")];
		NSString * pubSingularPlural;
		if (count == 1)
			pubSingularPlural = NSLocalizedString(@"publication", @"publication, in status message");
		else
			pubSingularPlural = NSLocalizedString(@"publications", @"publications, in status message");
		[self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Removed %ld %@ from %@", @"Status message: Removed [number] publications(s) from selected group(s)"), (long)count, pubSingularPlural, groupName] immediate:NO];
	}
    
    return YES;
}

- (BOOL)movePublications:(NSArray *)pubs fromGroup:(BDSKGroup *)group toGroupNamed:(NSString *)newGroupName{
	NSInteger count = 0;
	NSInteger handleInherited = BDSKOperationAsk;
	NSInteger rv;
	
	if([group isCategory] == NO)
		return NO;
    
    NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSString *oldValue = nil;
    NSString *field = [(BDSKCategoryGroup *)group key];
	
	for (BibItem *pub in pubs){
		BDSKASSERT([pub isKindOfClass:[BibItem class]]);        
		
        oldValue = [[[pub valueOfField:field] retain] autorelease];
		rv = [pub replaceGroup:group withGroupNamed:newGroupName handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
			count++;
            [changedPubs addObject:pub];
            [oldValues addObject:oldValue ?: @""];
            [newValues addObject:[pub valueOfField:field]];
        }else if(rv == BDSKOperationAsk){
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")
                                             defaultButton:NSLocalizedString(@"Don't Change", @"Button title")
                                           alternateButton:nil
                                               otherButton:NSLocalizedString(@"Remove", @"Button title")
                                 informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
			rv = [alert runModal];
			handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
				[pub replaceGroup:group withGroupNamed:newGroupName handleInherited:handleInherited];
                count++;
                [changedPubs addObject:pub];
                [oldValues addObject:oldValue ?: @""];
                [newValues addObject:[pub valueOfField:field]];
			}
        }
	}
	
	if(count > 0){
        [[self undoManager] setActionName:NSLocalizedString(@"Rename Group", @"Undo action name")];
        if([changedPubs count])
            [self userChangedField:field ofPublications:changedPubs from:oldValues to:newValues];
    }
    
    return YES;
}

#pragma mark Sorting

- (void)sortGroupsByKey:(NSString *)key{
    if (key == nil) {
		// nil key indicates resort
    } else if ([key isEqualToString:sortGroupsKey]) {
        // clicked the sort arrow in the table header, change sort order
        docFlags.sortGroupsDescending = !docFlags.sortGroupsDescending;
    } else {
        // change key
        // save new sorting selector, and re-sort the array.
        if ([key isEqualToString:BDSKGroupCellStringKey])
			docFlags.sortGroupsDescending = NO;
		else
			docFlags.sortGroupsDescending = YES; // more appropriate for default count sort
		[sortGroupsKey release];
        sortGroupsKey = [key retain];
        if ([sortGroupsKey isEqualToString:BDSKGroupCellCountKey] && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKHideGroupCountKey]) {
            // the smart group counts were not updated, so we need to do that now; this will get back to us, so just return here.
            [self updateSmartGroupsCount];
            return;
        }
	}
    
    if (key) {
        [[NSUserDefaults standardUserDefaults] setObject:sortGroupsKey forKey:BDSKSortGroupsKey];
        [[NSUserDefaults standardUserDefaults] setBool:docFlags.sortGroupsDescending forKey:BDSKSortGroupsDescendingKey];    
    }
    
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    docFlags.ignoreGroupSelectionChange = YES;

    // cache the selection
	NSArray *selectedGroups = [self selectedGroups];
    
    NSArray *sortDescriptors;
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        NSSortDescriptor *countSort = [[NSSortDescriptor alloc] initWithKey:@"numberValue" ascending:!docFlags.sortGroupsDescending  selector:@selector(compare:)];
        NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"self" ascending:docFlags.sortGroupsDescending  selector:@selector(nameCompare:)];
        sortDescriptors = [NSArray arrayWithObjects:countSort, nameSort, nil];
        [countSort release];
        [nameSort release];
    } else {
        NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"self" ascending:!docFlags.sortGroupsDescending  selector:@selector(nameCompare:)];
        sortDescriptors = [NSArray arrayWithObjects:nameSort, nil];
        [nameSort release];
    }
    
    [groups sortUsingDescriptors:sortDescriptors];
    
    [self removeSpinnersFromSuperview];
    [groupOutlineView reloadData];
	
	// select the current groups. Otherwise select Library
	[self selectGroups:selectedGroups];
	[self displaySelectedGroups];
	
    // reset
    docFlags.ignoreGroupSelectionChange = NO;
}

#pragma mark Importing

- (void)setImported:(BOOL)flag forPublications:(NSArray *)pubs inGroup:(BDSKExternalGroup *)aGroup{
    CFIndex countOfItems = [pubs count];
    BibItem **items = (BibItem **)NSZoneMalloc([self zone], sizeof(BibItem *) * countOfItems);
    [pubs getObjects:items];
    NSSet *pubSet = (NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)items, countOfItems, &kBDSKBibItemEquivalenceSetCallBacks);
    NSZoneFree([self zone], items);
    
    NSArray *groupsToTest = aGroup ? [NSArray arrayWithObject:aGroup] : [[groups externalParent] children];
    
    for (BDSKExternalGroup *group in groupsToTest) {
        // publicationsWithoutUpdating avoids triggering a load or update of external groups every time you add/remove a pub
        for (BibItem *pub in [group publicationsWithoutUpdating]) {
            if ([pubSet containsObject:pub])
                [pub setImported:flag];
        }
    }
    [pubSet release];
	
    NSTableColumn *tc = [tableView tableColumnWithIdentifier:BDSKImportOrderString];
    if(tc && [self hasExternalGroupsSelected])
        [tableView setNeedsDisplayInRect:[tableView rectOfColumn:[[tableView tableColumns] indexOfObject:tc]]];
}

- (void)tableView:(NSTableView *)aTableView importItemAtRow:(NSInteger)rowIndex{
    BibItem *pub = [shownPublications objectAtIndex:rowIndex];
    // also import a possible crossref parent if that wasn't already present
    BibItem *parent = [pub crossrefParent];
    if ([parent isImported])
        parent = nil;
    
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    NSArray *newPubs;
    
    [archiver encodeObject:[NSArray arrayWithObjects:pub, parent, nil] forKey:@"publications"];
    [archiver finishEncoding];
    [archiver release];
    
    newPubs = [BibItem publicationsFromArchivedData:data macroResolver:[self macroResolver]];
	
    [self addPublications:newPubs publicationsToAutoFile:nil temporaryCiteKey:nil selectLibrary:NO edit:NO];
    
	[[self undoManager] setActionName:NSLocalizedString(@"Import Publication", @"Undo action name")];
}

#pragma mark Opening a URL

- (BOOL)openURL:(NSURL *)url {
    BDSKWebGroup *group = nil;
    if ([self hasWebGroupsSelected]) {
        group = [[self selectedGroups] lastObject];
        [group setURL:url];
    } else {
        for (group in [groups webGroups])
            if ([group isWebViewLoaded] == NO) break;
        if (group == nil) {
            group = [[[BDSKWebGroup alloc] init] autorelease];
            [groups addWebGroup:group];
        }
        [group setURL:url];
        [self selectGroup:group];
    }
    return group != nil;
}

@end
