//
//  BDSKFileContentSearchController.m
//  BibDesk
//
//  Created by Adam Maxwell on 10/06/05.
/*
 This software is Copyright (c) 2005-2008
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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
#import "BDSKFileSearch.h"

@class BDSKFileSearchIndex, BDSKCollapsibleView, BDSKEdgeView;

@interface BDSKSelectionPreservingArrayController : NSArrayController
@end

@interface BDSKFileContentSearchController : NSWindowController <BDSKSearchDelegate>
{
    NSMutableArray *results;
    NSMutableArray *filteredResults;
    NSMutableSet *filterURLs;
    BDSKFileSearch *search;
    BDSKFileSearchIndex *searchIndex;
    
    IBOutlet BDSKSelectionPreservingArrayController *resultsArrayController;
    IBOutlet NSTableView *tableView;
    
    IBOutlet BDSKEdgeView *controlView;
    IBOutlet BDSKCollapsibleView *collapsibleView;
    IBOutlet NSButton *stopButton;
    IBOutlet NSView *progressView;
    IBOutlet NSProgressIndicator *indexProgressBar;
    BOOL canceledSearch;
    BOOL searchFieldDidEndEditing;
    
    NSSearchField *searchField;
}

// Use this method to instantiate a search controller for use within a document window
- (id)initForDocument:(id)aDocument;
- (NSView *)controlView;
- (NSTableView *)tableView;
// Use this to connect a search field and initiate a search
- (void)setSearchField:(NSSearchField *)aSearchField;

- (NSArray *)selectedIdentifierURLs;
- (NSArray *)selectedURLs;
- (NSArray *)selectedResults;

- (NSArray *)results;
- (void)setResults:(NSArray *)newResults;
- (NSArray *)filteredResults;
- (void)setFilteredResults:(NSArray *)newFilteredResults;

- (void)filterUsingURLs:(NSArray *)newFilterURLs;

- (NSData *)sortDescriptorData;
- (void)setSortDescriptorData:(NSData *)data;

- (void)saveSortDescriptors;
- (void)restoreDocumentState;
- (void)terminate;

- (IBAction)search:(id)sender;
- (IBAction)cancelCurrentSearch:(id)sender;
- (IBAction)tableAction:(id)sender;

- (void)handleApplicationWillTerminate:(NSNotification *)notification;
- (void)handleClipViewFrameChangedNotification:(NSNotification *)note;

@end


@protocol BDSKSearchContentView <NSObject>
// Single method required by the BDSKSearchContentView protocol; the implementor is responsible for restoring its state by removing the views and resetting search field target/action.  It is sent to the document in response to a search field action with an empty string as search string.
- (void)removeFileContentSearch:(BDSKFileContentSearchController *)fileContentSearchController;
@end
