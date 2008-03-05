//
//  BibDocument_Search.m
//  Bibdesk
//
/*
 This software is Copyright (c) 2001-2008
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
#import "BDSKTypeManager.h"
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
#import "BibDocument_Groups.h"
#import "BDSKMainTableView.h"
#import "BDSKFindController.h"
#import <OmniAppKit/OAFindControllerTargetProtocol.h>
#import <OmniAppKit/NSText-OAExtensions.h>
#import "BDSKSearchButtonController.h"
#import "BDSKItemSearchIndexes.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKOwnerProtocol.h"
#import "NSViewAnimation_BDSKExtensions.h"
#import "BDSKDocumentSearch.h"

@implementation BibDocument (Search)

- (IBAction)changeSearchType:(id)sender{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:[sender tag] forKey:BDSKSearchMenuTagKey];
    [self search:searchField];
}

- (IBAction)makeSearchFieldKey:(id)sender{

    NSToolbar *tb = [documentWindow toolbar];
    [tb setVisible:YES];
    if([tb displayMode] == NSToolbarDisplayModeLabelOnly)
        [tb setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    
	[documentWindow makeFirstResponder:searchField];
    [searchField selectText:sender];
}

- (NSString *)searchString {
	return [searchField stringValue];
}

- (void)setSearchString:(NSString *)filterterm {
    NSParameterAssert(filterterm != nil);
    if([[searchField stringValue] isEqualToString:filterterm] == NO){
        [searchField setStringValue:filterterm];
        [searchField sendAction:[searchField action] to:[searchField target]];
    }
}

- (void)buttonBarSelectionDidChange:(NSNotification *)aNotification;
{
    NSString *field = [searchButtonController selectedItemIdentifier];
    if (searchButtonController && nil == field) {
        OBASSERT_NOT_REACHED("the search button controller should always have a selected field");
        [searchButtonController selectItemWithIdentifier:BDSKAllFieldsString];
        field = BDSKAllFieldsString;
    }
    
    if([field isEqualToString:BDSKFileContentSearchString]) {
        [self searchByContent:nil];
    } else {
        if ([self isDisplayingFileContentSearch])
            [fileSearchController restoreDocumentState];
        
        NSArray *pubsToSelect = [self selectedPublications];
        NSString *searchString = [searchField stringValue];
        
        if([NSString isEmptyString:searchString]){
            [shownPublications setArray:groupedPublications];
            
            [tableView deselectAll:nil];
            [self sortPubsByKey:nil];
            [self updateStatus];
            if([pubsToSelect count])
                [self selectPublications:pubsToSelect];
            
        } else {
            
            [self displayPublicationsMatchingSearchString:searchString indexName:field];

        }
         
    }
}

/* 

Ensure that views are always ordered vertically from top to bottom as

---- toolbar
---- search button view
---- search group view OR file content

*/

- (void)showSearchButtonView;
{
    if (nil == searchButtonController)
        searchButtonController = [[BDSKSearchButtonController alloc] init];
    
    [searchButtonController setDelegate:self];
    
    if ([self hasExternalGroupsSelected]) {
        [searchButtonController removeSkimNotesItem];
        [searchButtonController removeFileContentItem];
    } else {
        [searchButtonController addSkimNotesItem];
        [searchButtonController addFileContentItem];
    }
    
    NSView *searchButtonView = [searchButtonController view];
    
    if ([self isDisplayingSearchButtons] == NO) {
        [searchButtonController selectItemWithIdentifier:BDSKAllFieldsString];
        [self insertControlView:searchButtonView atTop:YES];
        if ([tableView tableColumnWithIdentifier:BDSKRelevanceString] == nil)
            [tableView insertTableColumnWithIdentifier:BDSKRelevanceString atIndex:0];
        
    }
}

- (void)hideSearchButtonView
{
    NSView *searchButtonView = [searchButtonController view];
    if ([self isDisplayingSearchButtons]) {
        [tableView removeTableColumnWithIdentifier:BDSKRelevanceString];
        [self removeControlView:searchButtonView];
        [searchButtonController selectItemWithIdentifier:BDSKAllFieldsString];
        
        if ([previousSortKey isEqualToString:BDSKRelevanceString]) {
            [previousSortKey release];
            previousSortKey = [BDSKTitleString retain];
        }
        if ([sortKey isEqualToString:BDSKRelevanceString]) {
            NSString *newSortKey = [[previousSortKey retain] autorelease];
            docState.sortDescending = NO;
            [self sortPubsByKey:newSortKey];
        }
    }
    [searchButtonController setDelegate:nil];
}

- (IBAction)search:(id)sender{
    if ([[sender stringValue] isEqualToString:@""])
        [self hideSearchButtonView];
    else [self showSearchButtonView];
    
    [self buttonBarSelectionDidChange:nil];
}

#pragma mark -

// simplified search used by BDSKAppController's Service for legacy compatibility
- (NSArray *)publicationsMatchingSubstring:(NSString *)searchString inField:(NSString *)field{
    unsigned i, iMax = [publications count];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:100];
    for (i = 0; i < iMax; i++) {
        BibItem *pub = [publications objectAtIndex:i];
        if ([pub matchesSubstring:searchString withOptions:NSCaseInsensitiveSearch inField:field removeDiacritics:YES])
            [results addObject:pub];
    }
    return results;
}


NSString *BDSKSearchKitExpressionWithString(NSString *searchFieldString)
{
    // surround with wildcards for substring search; should we check for any operators?
    if ([[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKSearchMenuTagKey] == 0)
        searchFieldString = [NSString stringWithFormat:@"*%@*", searchFieldString];
    return searchFieldString;
}

- (void)handleSearchCallbackWithIdentifiers:(NSSet *)identifierURLs normalizedScores:(NSDictionary *)scores;
{
    id<BDSKOwner> owner = [self hasExternalGroupsSelected] ? [[self selectedGroups] firstObject] : self;    
    BDSKPublicationsArray *pubArray = [owner publications];    
    
    // we searched all publications, but we only want to keep the subset that's shown (if a group is selected)
    NSMutableSet *foundURLSet = [[identifierURLs mutableCopy] autorelease];
    NSMutableSet *identifierURLsToKeep = [NSMutableSet setWithArray:[groupedPublications valueForKey:@"identifierURL"]];
    [foundURLSet intersectSet:identifierURLsToKeep];
    
    NSEnumerator *keyEnum = [foundURLSet objectEnumerator];
    NSURL *aURL;
    BibItem *aPub;

    // iterate and normalize search scores
    while (aURL = [keyEnum nextObject]) {
        aPub = [pubArray itemForIdentifierURL:aURL];
        if (aPub) {
            [shownPublications addObject:aPub];
        }
    }
            
    NSEnumerator *pubEnum = [shownPublications objectEnumerator];
    while (aPub = [pubEnum nextObject]) {
        [aPub setSearchScore:[[scores objectForKey:[aPub identifierURL]] floatValue]];
    }
    
    [self sortPubsByKey:nil];
    [self updateStatus];
    
    [self selectPublications:[documentSearch previouslySelectedPublications]];
}
        
- (void)displayPublicationsMatchingSearchString:(NSString *)searchString indexName:(NSString *)field {
    searchString = BDSKSearchKitExpressionWithString(searchString);
        
    // we need the correct BDSKPublicationsArray for access to the identifierURLs
    id<BDSKOwner> owner = [self hasExternalGroupsSelected] ? [[self selectedGroups] firstObject] : self;
    SKIndexRef skIndex = [[owner searchIndexes] indexForField:field];
    
    NSArray *selPubs = [[self selectedPublications] retain];
    
    [shownPublications removeAllObjects];
    [tableView deselectAll:nil];
    [self sortPubsByKey:nil];
    [self updateStatus];
    
    [documentSearch searchForString:searchString index:skIndex selectedPublications:selPubs];
    [selPubs release];

}

#pragma mark File Content Search

- (IBAction)searchByContent:(id)sender
{
    if(fileSearchController == nil){
        fileSearchController = [[BDSKFileContentSearchController alloc] initForDocument:self];
        NSData *sortDescriptorData = [[self mainWindowSetupDictionaryFromExtendedAttributes] objectForKey:BDSKFileContentSearchSortDescriptorKey defaultObject:[[NSUserDefaults standardUserDefaults] dataForKey:BDSKFileContentSearchSortDescriptorKey]];
        if(sortDescriptorData)
            [fileSearchController setSortDescriptorData:sortDescriptorData];
    }
    
    [fileSearchController filterUsingURLs:[groupedPublications valueForKey:@"identifierURL"]];
    
    NSView *oldView = [tableView enclosingScrollView];
    NSView *newView = [[fileSearchController tableView] enclosingScrollView];
    
    [newView setFrame:[oldView frame]];
    [mainView addSubview:newView];
    [NSViewAnimation animateFadeOutView:oldView fadeInView:newView];
    [oldView removeFromSuperview];
    
    if ([fileSearchController shouldShowControlView])
        [self insertControlView:[fileSearchController controlView] atTop:NO];
    
    // connect the searchfield to the controller and start the search
    [fileSearchController setSearchField:searchField];
    
    // make sure the previews and fileview are updated
    [self handleTableSelectionChangedNotification:nil];
}

// Method required by the BDSKSearchContentView protocol; the implementor is responsible for restoring its state by removing the view passed as an argument and resetting search field target/action.
- (void)privateRemoveFileContentSearch:(BDSKFileContentSearchController *)controller
{
    NSView *oldView = [[fileSearchController tableView] enclosingScrollView];
    NSView *newView = [tableView enclosingScrollView];
    
    [newView setFrame:[oldView frame]];
    [mainView addSubview:newView];
    [NSViewAnimation animateFadeOutView:oldView fadeInView:newView];
    [oldView removeFromSuperview];
    
    [self removeControlView:[fileSearchController controlView]];
    
    // reconnect the searchfield
    [searchField setTarget:self];
    [searchField setDelegate:self];
    
    // privateRemoveFileContentSearch may be called after the user clicks a different search type, without changing the searchfield; in that case, we want to leave the search button view in place, and refilter the list.  Otherwise, select the pubs corresponding to the file content selection.
    if ([[searchField stringValue] isEqualToString:@""]) {
        [self hideSearchButtonView];
        
        // have to hide the search view before trying to select anything
        NSArray *itemsToSelect = [fileSearchController selectedIdentifierURLs];
        
        if([itemsToSelect count]){
            
            // clear current selection (just in case)
            [tableView deselectAll:nil];
            
            // we match based on title, since that's all the index knows about the BibItem at present
            NSMutableArray *pubsToSelect = [NSMutableArray array];
            NSEnumerator *itemEnum = [itemsToSelect objectEnumerator];
            NSURL *aURL;
            BibItem *pub;
            while(aURL = [itemEnum nextObject])
                if (pub = [publications itemForIdentifierURL:aURL])
                    [pubsToSelect addObject:pub];
            [self selectPublications:pubsToSelect];
            [tableView scrollRowToCenter:[tableView selectedRow]];
            
            // if searchfield doesn't have focus (user clicked cancel button), switch to the tableview
            if ([[documentWindow firstResponder] isEqual:[searchField currentEditor]] == NO)
                [documentWindow makeFirstResponder:(NSResponder *)tableView];
        } else {
            // make sure the previews and fileview are updated
            [self handleTableSelectionChangedNotification:nil];
        }
    } else {
        [mainView setNeedsDisplay:YES];
        // make sure the previews and fileview are updated
        [self handleTableSelectionChangedNotification:nil];
    }
}

#pragma mark Find panel

- (NSString *)selectedStringForFind;
{
    // @@ check for hidden?
    if (bottomPreviewDisplay == BDSKPreviewDisplayTeX) {
        return [[[previewer pdfView] currentSelection] string];
    } else if (bottomPreviewDisplay == BDSKPreviewDisplayText || sidePreviewDisplay == BDSKPreviewDisplayText) {
        NSTextView *textView = bottomPreviewDisplay == BDSKPreviewDisplayText ? bottomPreviewTextView : sidePreviewTextView;
        NSRange selRange = [textView selectedRange];
        if (selRange.location == NSNotFound)
            return nil;
        return [[textView string] substringWithRange:selRange];
    }
    return nil;
}

// OAFindControllerAware informal protocol
- (id <OAFindControllerTarget>)omniFindControllerTarget;
{
    if (bottomPreviewDisplay == BDSKPreviewDisplayText)
        return bottomPreviewTextView;
    else if (sidePreviewDisplay == BDSKPreviewDisplayText)
        return sidePreviewTextView;
    else
        return nil;
}

- (IBAction)performFindPanelAction:(id)sender{
    NSString *selString = nil;

	switch ([sender tag]) {
        case NSFindPanelActionShowFindPanel:
        case NSFindPanelActionNext:
        case NSFindPanelActionPrevious:
            if (bottomPreviewDisplay == BDSKPreviewDisplayText)
                [bottomPreviewTextView performFindPanelAction:sender];
            else if (sidePreviewDisplay == BDSKPreviewDisplayText)
                [sidePreviewTextView performFindPanelAction:sender];
            else
                NSBeep();
            break;
		case NSFindPanelActionSetFindString:
            selString = [self selectedStringForFind];
            if ([NSString isEmptyString:selString])
                return;
            id firstResponder = [documentWindow firstResponder];
            if (firstResponder == searchField || ([firstResponder isKindOfClass:[NSText class]] && [firstResponder delegate] == searchField)) {
                [searchField setStringValue:selString];
                [searchField selectText:nil];
            } else {
                [[BDSKFindController sharedFindController] setFindString:selString];
                if (bottomPreviewDisplay == BDSKPreviewDisplayText)
                    [bottomPreviewTextView performFindPanelAction:sender];
                else if (sidePreviewDisplay == BDSKPreviewDisplayText)
                    [sidePreviewTextView performFindPanelAction:sender];
            }
            break;
        default:
            NSBeep();
            break;
	}
}

@end
