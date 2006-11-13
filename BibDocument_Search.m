//
//  BibDocument_Search.m
//  Bibdesk
//
/*
 This software is Copyright (c) 2001,2002,2003,2004,2005,2006
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

#import "BibDocument_Search.h"
#import "BibDocument.h"
#import "BibTypeManager.h"
#import <AGRegex/AGRegex.h>
#import "BibItem.h"
#import "CFString_BDSKExtensions.h"
#import "BDSKFieldSheetController.h"
#import "BDSKSplitView.h"
#import "BDSKFileContentSearchController.h"
#import "BDSKGroupTableView.h"
#import "NSTableView_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKZoomablePDFView.h"
#import "BDSKPreviewer.h"
#import "BDSKOverlay.h"

static NSString *BDSKFileContentLocalizedString = nil;
NSString *BDSKDocumentFormatForSearchingDates = nil;

@implementation BibDocument (Search)

+ (void)didLoad{
    BDSKFileContentLocalizedString = [NSLocalizedString(@"File Content", @"") copy];
    BDSKDocumentFormatForSearchingDates = [[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString] copy];
}

- (IBAction)makeSearchFieldKey:(id)sender{

    NSToolbar *tb = [documentWindow toolbar];
    [tb setVisible:YES];
    if([tb displayMode] == NSToolbarDisplayModeLabelOnly)
        [tb setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    
	[documentWindow makeFirstResponder:searchField];
}

- (NSMenu *)searchFieldMenu{
	NSMenu *cellMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Search Menu"] autorelease];
	NSMenuItem *anItem;
	
	anItem = [cellMenu addItemWithTitle:NSLocalizedString(@"Recent Searches", @"Recent Searches menu item") action:NULL keyEquivalent:@""];
	[anItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
	
    anItem = [cellMenu addItemWithTitle:@"" action:NULL keyEquivalent:@""];
	[anItem setTag:NSSearchFieldRecentsMenuItemTag];
    
	anItem = [cellMenu addItemWithTitle:NSLocalizedString(@"Clear Recent Searches", @"Clear menu item") action:NULL keyEquivalent:@""];
	[anItem setTag:NSSearchFieldClearRecentsMenuItemTag];
    
    // this tag conditionally inserts a separator if there are recent searches (is it safe to set a tag on the separator item?)
    anItem = [NSMenuItem separatorItem];
	[anItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
	[cellMenu addItem:anItem];
    
	[cellMenu addItemWithTitle:NSLocalizedString(@"Search Types", @"Searchfield menu separator title") action:NULL keyEquivalent:@""];
    [cellMenu addItemWithTitle:BDSKAllFieldsString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
    
    // add a separator if we have this option; it and "Any Field" are special (and "File Content" looks out of place between "Any Field" and "Author")
    [cellMenu addItemWithTitle:BDSKFileContentLocalizedString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
    [cellMenu addItem:[NSMenuItem separatorItem]];
        
	NSMutableArray *quickSearchKeys = [[NSMutableArray alloc] initWithObjects:BDSKAuthorString, BDSKDateString, BDSKTitleString, nil];
    [quickSearchKeys addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKQuickSearchKeys]];
    [quickSearchKeys sortUsingSelector:@selector(compare:)];
    
    NSString *aKey = nil;
    NSEnumerator *quickSearchKeyE = [quickSearchKeys objectEnumerator];
	
    while(aKey = [quickSearchKeyE nextObject]){
		[cellMenu addItemWithTitle:aKey action:@selector(searchFieldChangeKey:) keyEquivalent:@""]; 
    }
    [quickSearchKeys release];
	
	[cellMenu addItem:[NSMenuItem separatorItem]];
	
	[cellMenu addItemWithTitle:[NSLocalizedString(@"Add Field", @"Add Field... menu item") stringByAppendingEllipsis] action:@selector(quickSearchAddField:) keyEquivalent:@""];
	[cellMenu addItemWithTitle:[NSLocalizedString(@"Remove Field", @"Remove Field... menu item") stringByAppendingEllipsis] action:@selector(quickSearchRemoveField:) keyEquivalent:@""];
    
	return cellMenu;
}

-(NSString*) filterField {
	return [searchField stringValue];
}

- (void)setFilterField:(NSString*) filterterm {
    NSParameterAssert(filterterm != nil);
    
    NSResponder * oldFirstResponder = [documentWindow firstResponder];
    [documentWindow makeFirstResponder:searchField];
    
    [searchField setObjectValue:filterterm];
    [self searchFieldAction:searchField];
    
    [documentWindow makeFirstResponder:oldFirstResponder];
}

- (IBAction)searchFieldChangeKey:(id)sender{
    [self setSelectedSearchFieldKey:[sender title]];
}

- (void)setSelectedSearchFieldKey:(NSString *)newKey{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:newKey
                                                      forKey:BDSKCurrentQuickSearchKey];
	
	NSSearchFieldCell *searchCell = [searchField cell];
	[searchCell setPlaceholderString:[NSString stringWithFormat:NSLocalizedString(@"Search by %@",@""),newKey]];

	NSMenu *templateMenu = [searchCell searchMenuTemplate];
	if([quickSearchKey isEqualToString:newKey] == NO){
		// find current key's menuitem and set it to NSOffState
		NSMenuItem *oldItem = [templateMenu itemWithTitle:quickSearchKey];
		[oldItem setState:NSOffState];
		if ([searchField target] != self && [quickSearchKey isEqualToString:BDSKFileContentLocalizedString])
			[fileSearchController restoreDocumentState];
		[quickSearchKey release];
		quickSearchKey = [newKey copy];
	}
	
	// set new key's menuitem to NSOnState
	NSMenuItem *newItem = [templateMenu itemWithTitle:quickSearchKey];
	[newItem setState:NSOnState];
    
    // @@ weird...this is required or else the checkmark doesn't show up
	[searchCell setSearchMenuTemplate:templateMenu];

	if([quickSearchKey isEqualToString:BDSKFileContentLocalizedString])
		[self searchByContent:searchField];
 
	[self hidePublicationsWithoutSubstring:[searchField stringValue] //newQueryString
								   inField:quickSearchKey];
		
}

- (void)addSearchFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *newSearchKey = [addFieldController field];
    if(returnCode == NSCancelButton || [NSString isEmptyString:newSearchKey])
        return;
    
    newSearchKey = [newSearchKey capitalizedString];
    NSMutableArray *newSearchKeys = [NSMutableArray arrayWithCapacity:10];
    [newSearchKeys addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys]];
    [newSearchKeys addObject:newSearchKey];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:newSearchKeys
                                                      forKey:BDSKQuickSearchKeys];
    
    // this will sort the menu items for us
    [[searchField cell] setSearchMenuTemplate:[self searchFieldMenu]];
    [self setSelectedSearchFieldKey:newSearchKey];
}

- (IBAction)quickSearchAddField:(id)sender{
    // first we fill the popup
    BibTypeManager *typeMan = [BibTypeManager sharedManager];
    NSArray *searchKeys = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCiteKeyString, BDSKDateString, BDSKDateAddedString, BDSKDateModifiedString, nil]
                                                excluding:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys]];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Field to search:",@"")
                                                                                              fieldsArray:searchKeys];
	[addFieldController beginSheetModalForWindow:documentWindow
                                   modalDelegate:self
                                  didEndSelector:@selector(addSearchFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (void)removeSearchFieldSheetDidEnd:(BDSKRemoveFieldSheetController *)removeFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSMutableArray *searchKeys = [NSMutableArray arrayWithCapacity:10];
    [searchKeys addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys]];

	NSString *oldSearchKey = [removeFieldController field];
    if(returnCode == NSCancelButton || oldSearchKey == nil || [searchKeys count] == 0)
        return;
    
    [searchKeys removeObject:oldSearchKey];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:searchKeys
                                                      forKey:BDSKQuickSearchKeys];

    [[searchField cell] setSearchMenuTemplate:[self searchFieldMenu]];
    if([quickSearchKey isEqualToString:oldSearchKey])
        [self setSelectedSearchFieldKey:BDSKAllFieldsString];
}

- (IBAction)quickSearchRemoveField:(id)sender{
    NSMutableArray *searchKeys = [NSMutableArray arrayWithCapacity:10];
    [searchKeys addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys]];
    [searchKeys sortUsingSelector:@selector(caseInsensitiveCompare:)];

    NSString *prompt = NSLocalizedString(@"Search field to remove:",@"");
	if ([searchKeys count]) {
		[searchKeys sortUsingSelector:@selector(caseInsensitiveCompare:)];
	} else {
		prompt = NSLocalizedString(@"No search fields to remove",@"");
	}
    
    BDSKRemoveFieldSheetController *removeFieldController = [[BDSKRemoveFieldSheetController alloc] initWithPrompt:prompt
                                                                                                       fieldsArray:searchKeys];
	[removeFieldController beginSheetModalForWindow:documentWindow
                                      modalDelegate:self
                                     didEndSelector:@selector(removeSearchFieldSheetDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
    [removeFieldController release];
}

- (IBAction)searchFieldAction:(id)sender{

    if(sender != nil){
        if([quickSearchKey isEqualToString:BDSKFileContentLocalizedString]){
            [self searchByContent:sender];
        } else {
            [self hidePublicationsWithoutSubstring:[sender stringValue] inField:quickSearchKey];
        }
    }
}

#pragma mark -

- (void)hidePublicationsWithoutSubstring:(NSString *)substring inField:(NSString *)field{
	NSArray *pubsToSelect = [self selectedPublications];

    if([NSString isEmptyString:substring]){
        [shownPublications setArray:groupedPublications];
    }else{
		[shownPublications setArray:[self publicationsWithSubstring:substring inField:field forArray:groupedPublications]];
		if([shownPublications count] == 1)
			pubsToSelect = [NSMutableArray arrayWithObject:[shownPublications lastObject]];
	}
	
	[tableView deselectAll:nil];
    // @@ performance: this kills us on large files, since it gets called for every updateCategoryGroupsPreservingSelection (any add/del)
	[self sortPubsByColumn:nil]; // resort
	[self updateUI];
	if(pubsToSelect)
		[self selectPublications:pubsToSelect];
}
        
- (NSArray *)publicationsWithSubstring:(NSString *)substring inField:(NSString *)field forArray:(NSArray *)arrayToSearch{
        
    unsigned searchMask = NSCaseInsensitiveSearch;
    if([substring rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound)
        searchMask = 0;
    BOOL doLossySearch = YES;
    if(BDStringHasAccentedCharacters((CFStringRef)substring))
        doLossySearch = NO;
    
    static NSSet *dateFields = nil;
    if(nil == dateFields)
        dateFields = [[NSSet alloc] initWithObjects:BDSKDateString, BDSKDateAddedString, BDSKDateModifiedString, nil];
    
    // if it's a date field, figure out a format string to use based on the given date component(s)
    // this date format string is then made available to the BibItem as a global variable
    // don't convert substring->date->string, though, or it's no longer a substring and will only match exactly
    if([dateFields containsObject:field]){
        [BDSKDocumentFormatForSearchingDates release];
        BDSKDocumentFormatForSearchingDates = [[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString] copy];
        if(nil == [NSCalendarDate dateWithString:substring calendarFormat:BDSKDocumentFormatForSearchingDates]){
            [BDSKDocumentFormatForSearchingDates release];
            BDSKDocumentFormatForSearchingDates = [[[NSUserDefaults standardUserDefaults] objectForKey:NSDateFormatString] copy];
        }
    }
        
    NSMutableSet *aSet = [NSMutableSet setWithCapacity:10];
    NSArray *andComponents = [substring andSearchComponents];
    NSArray *orComponents = [substring orSearchComponents];
    
    int i, j, pubCount = [arrayToSearch count], andCount = [andComponents count], orCount = [orComponents count];
    BibItem *pub;
    BOOL match;

    // cache the IMP for the BibItem search method, since we're potentially calling it several times per item
    typedef BOOL (*searchIMP)(id, SEL, id, unsigned int, id, BOOL);
    SEL matchSelector = @selector(matchesSubstring:withOptions:inField:removeDiacritics:);
    searchIMP itemMatches = (searchIMP)[BibItem instanceMethodForSelector:matchSelector];
    OBASSERT(NULL != itemMatches);
    
    for(i = 0; i < pubCount; i++){
        pub = [arrayToSearch objectAtIndex:i];
        match = YES;
        for(j = 0; j < andCount; j++){
            if(itemMatches(pub, matchSelector, [andComponents objectAtIndex:j], searchMask, field, doLossySearch) == NO){
                match = NO;
                break;
            }
        }
        if(orCount > 0 && match == NO){
            for(j = 0; j < orCount; j++){
                if(itemMatches(pub, matchSelector, [orComponents objectAtIndex:j], searchMask, field, doLossySearch) == YES){
                    match = YES;
                    break;
                }
            }
        }
        if(match)
            [aSet addObject:pub];
    }
    
    return [aSet allObjects];
}

#pragma mark File Content Search

- (IBAction)searchByContent:(id)sender
{
    // Normal search if the fileSearchController is not present and the searchstring is empty, since the searchfield target has apparently already been reset (I think).  Fixes bug #1341802.
    OBASSERT(searchField != nil && [searchField target] != nil);
    if([searchField target] == self && [NSString isEmptyString:[searchField stringValue]]){
        [self hidePublicationsWithoutSubstring:[sender stringValue] inField:quickSearchKey];
        return;
    }
    
    // @@ File content search isn't really compatible with the group concept yet; this allows us to select publications when the content search is done, and also provides some feedback to the user that all pubs will be searched.  This is ridiculously complicated since we need to avoid calling searchByContent: in a loop.
    [tableView deselectAll:nil];
    [groupTableView updateHighlights];
    
    // here we avoid the table selection change notification that will result in an endless loop
    id tableDelegate = [groupTableView delegate];
    [groupTableView setDelegate:nil];
    [groupTableView deselectAll:nil];
    [groupTableView setDelegate:tableDelegate];
    
    // this is what displaySelectedGroup normally ends up doing
    [shownPublications setArray:publications];
    [tableView reloadData];
    [self sortPubsByColumn:nil];
    
    if(fileSearchController == nil){
        fileSearchController = [[BDSKFileContentSearchController alloc] initForDocument:self];
        NSData *sortDescriptorData = [[self mainWindowSetupDictionaryFromExtendedAttributes] objectForKey:BDSKFileContentSearchSortDescriptorKey defaultObject:[[NSUserDefaults standardUserDefaults] dataForKey:BDSKFileContentSearchSortDescriptorKey]];
        if(sortDescriptorData)
            [fileSearchController setSortDescriptorData:sortDescriptorData];
    }
    
    NSView *contentView = [fileSearchController searchContentView];
    NSRect frame = [splitView frame];
    [contentView setFrame:frame];
    [contentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [mainBox addSubview:contentView];
    
    NSViewAnimation *animation;
    NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:splitView, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
    NSDictionary *fadeInDict = [[NSDictionary alloc] initWithObjectsAndKeys:contentView, NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];

    animation = [[[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, fadeInDict, nil]] autorelease];
    [fadeOutDict release];
    [fadeInDict release];
    
    [animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
    [animation setDuration:0.75];
    [animation setAnimationCurve:NSAnimationEaseIn];
    [animation setDelegate:self];
    [animation startAnimation];
}

- (void)finishAnimation
{
    if([splitView isHidden]){
        
        [[previewer progressOverlay] remove];
        
        [splitView removeFromSuperview];
        // connect the searchfield to the controller and start the search
        [fileSearchController setSearchField:searchField];
        
    } else {
        
        // reconnect the searchfield
        [searchField setTarget:self];
        [searchField setDelegate:self];
        [searchField setAction:@selector(searchFieldAction:)];
        
        NSArray *titlesToSelect = [fileSearchController titlesOfSelectedItems];
        
        if([titlesToSelect count]){
            
            // clear current selection (just in case)
            [tableView deselectAll:nil];
            
            // we match based on title, since that's all the index knows about the BibItem at present
            NSMutableArray *pubsToSelect = [NSMutableArray array];
            NSEnumerator *pubEnum = [shownPublications objectEnumerator];
            BibItem *item;
            while(item = [pubEnum nextObject])
                if([titlesToSelect containsObject:[item title]]) 
                    [pubsToSelect addObject:item];
            [self selectPublications:pubsToSelect];
            [tableView scrollRowToCenter:[tableView selectedRow]];
            
            // if searchfield doesn't have focus (user clicked cancel button), switch to the tableview
            if ([[documentWindow firstResponder] isEqual:[searchField currentEditor]] == NO)
                [documentWindow makeFirstResponder:(NSResponder *)tableView];
        }
        
    }
}

// use the delegate method so we don't remove the view too early, but this must be done on the main thread
- (void)animationDidEnd:(NSAnimation*)animation
{
    [self performSelectorOnMainThread:@selector(finishAnimation) withObject:nil waitUntilDone:NO];
}

// Method required by the BDSKSearchContentView protocol; the implementor is responsible for restoring its state by removing the view passed as an argument and resetting search field target/action.
- (void)_restoreDocumentStateByRemovingSearchView:(NSView *)view
{
    
    NSRect frame = [view frame];
    [splitView setFrame:frame];
    [mainBox addSubview:splitView];
    
    if(currentPreviewView != [previewTextView enclosingScrollView])
        [[previewer progressOverlay] overlayView:currentPreviewView];
    
    NSViewAnimation *animation;
    NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:view, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
    NSDictionary *fadeInDict = [[NSDictionary alloc] initWithObjectsAndKeys:splitView, NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
    
    animation = [[[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, fadeInDict, nil]] autorelease];
    [fadeOutDict release];
    [fadeInDict release];
    
    [animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
    [animation setDuration:0.75];
    [animation setAnimationCurve:NSAnimationEaseIn];
    [animation setDelegate:self];
    [animation startAnimation];
}

#pragma mark Find panel

- (NSString *)selectedStringForFind {
    if([currentPreviewView isKindOfClass:[NSScrollView class]]){
        NSTextView *textView = (NSTextView *)[(NSScrollView *)currentPreviewView documentView];
        NSRange selRange = [textView selectedRange];
        if (selRange.location == NSNotFound)
            return nil;
        return [[textView string] substringWithRange:selRange];
    }else if([currentPreviewView isKindOfClass:[BDSKZoomablePDFView class]]){
        return [[(BDSKZoomablePDFView *)currentPreviewView currentSelection] string];
    }
    return nil;
}

- (IBAction)performFindPanelAction:(id)sender{
    NSString *selString = nil;
    NSPasteboard *findPasteboard;

	switch ([sender tag]) {
		case NSFindPanelActionShowFindPanel:
            if ([[documentWindow toolbar] isVisible] == NO) 
                [[documentWindow toolbar] setVisible:YES];
            if ([[documentWindow toolbar] displayMode] == NSToolbarDisplayModeLabelOnly) 
                [[documentWindow toolbar] setDisplayMode:NSToolbarDisplayModeDefault];
            [searchField selectText:nil];
            break;
		case NSFindPanelActionSetFindString:
            selString = nil;
            findPasteboard = [NSPasteboard pasteboardWithName:NSFindPboard];
            if ([findPasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
                selString = [findPasteboard stringForType:NSStringPboardType];    
            if ([NSString isEmptyString:selString] == NO)
                [searchField setStringValue:selString];
            [searchField selectText:nil];
            break;
        default:
            NSBeep();
            break;
	}
}

@end
