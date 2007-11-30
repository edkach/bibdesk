//  BibEditor.m

//  Created by Michael McCracken on Mon Dec 24 2001.
/*
 This software is Copyright (c) 2001,2002,2003,2004,2005,2006,2007
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


#import "BibEditor.h"
#import "BDSKOwnerProtocol.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BDAlias.h"
#import "NSImage+Toolbox.h"
#import "BDSKComplexString.h"
#import "BDSKScriptHookManager.h"
#import "BDSKEdgeView.h"
#import "KFAppleScriptHandlerAdditionsCore.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKAlert.h"
#import "BDSKFieldSheetController.h"
#import "BDSKFiler.h"
#import "BDSKDragWindow.h"
#import "BibItem.h"
#import "BDSKCiteKeyFormatter.h"
#import "BDSKComplexStringFormatter.h"
#import "BDSKCrossrefFormatter.h"
#import "BDSKAppController.h"
#import "BDSKImagePopUpButton.h"
#import "BDSKRatingButton.h"
#import "BDSKMacroTextFieldWindowController.h"
#import "BDSKForm.h"
#import "BDSKStatusBar.h"
#import "BibAuthor.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKShellTask.h"
#import "BDSKFieldEditor.h"
#import "NSURL_BDSKExtensions.h"
#import "BDSKPreviewer.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKPersistentSearch.h"
#import "BDSKMacroResolver.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringParser.h"
#import "NSArray_BDSKExtensions.h"
#import "PDFDocument_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKCitationFormatter.h"
#import "BDSKNotesWindowController.h"
#import "BDSKSkimReader.h"
#import "BDSKSplitView.h"
#import <FileView/FileView.h>
#import "BDSKLinkedFile.h"

static NSString *BDSKBibEditorFrameAutosaveName = @"BibEditor window autosave name";

enum{
	BDSKDrawerUnknownState = -1,
	BDSKDrawerStateTextMask = 1,
	BDSKDrawerStateWebMask = 2,
	BDSKDrawerStateOpenMask = 4,
	BDSKDrawerStateRightMask = 8,
};

// offset of the form from the left window edge
#define FORM_OFFSET 13.0

@interface BibEditor (Private)

- (void)setupButtons;
- (void)setupForm;
- (void)setupMatrix;
- (void)matrixFrameDidChange:(NSNotification *)notification;
- (void)setupTypePopUp;
- (void)registerForNotifications;
- (void)breakTextStorageConnections;

@end

@implementation BibEditor

- (NSUInteger)numberOfIconsInFileView:(FileView *)aFileView { return [publication countOfFiles]; }

- (NSURL *)fileView:(FileView *)aFileView URLAtIndex:(NSUInteger)idx;
{
    return [[publication objectInFilesAtIndex:idx] displayURL];
}

- (BOOL)fileView:(FileView *)aFileView moveURLsAtIndexes:(NSIndexSet *)aSet toIndex:(NSUInteger)anIndex;
{
    [publication moveFilesAtIndexes:aSet toIndex:anIndex];
    return YES;
}

- (BOOL)fileView:(FileView *)fileView replaceURLsAtIndexes:(NSIndexSet *)aSet withURLs:(NSArray *)newURLs;
{
    BDSKLinkedFile *aFile;
    NSEnumerator *enumerator = [newURLs objectEnumerator];
    NSURL *aURL;
    NSUInteger idx = [aSet firstIndex];
    while ((aURL = [enumerator nextObject]) != nil && NSNotFound != idx) {
        aFile = [[BDSKLinkedFile alloc] initWithURL:aURL delegate:publication];
        if (aFile) {
            [publication removeObjectFromFilesAtIndex:idx];
            [publication insertObject:aFile inFilesAtIndex:idx];
            [publication autoFileLinkedFile:aFile];
            [aFile release];
        }
        idx = [aSet indexGreaterThanIndex:idx];
    }
    return YES;
}

- (BOOL)fileView:(FileView *)fileView deleteURLsAtIndexes:(NSIndexSet *)indexSet;
{
    NSUInteger idx = [indexSet lastIndex];
    while (NSNotFound != idx) {
        [publication removeObjectFromFilesAtIndex:idx];
        idx = [indexSet indexLessThanIndex:idx];
    }
    return YES;
}

- (void)fileView:(FileView *)aFileView insertURLs:(NSArray *)absoluteURLs atIndexes:(NSIndexSet *)aSet;
{
    BDSKLinkedFile *aFile;
    NSEnumerator *enumerator = [absoluteURLs objectEnumerator];
    NSURL *aURL;
    NSUInteger idx = [aSet firstIndex], offset = 0;
    while ((aURL = [enumerator nextObject]) != nil && NSNotFound != idx) {
        aFile = [[BDSKLinkedFile alloc] initWithURL:aURL delegate:publication];
        if (aFile) {
            [publication insertObject:aFile inFilesAtIndex:idx - offset];
            [publication autoFileLinkedFile:aFile];
            [aFile release];
        } else {
            // the indexes in aSet assume that we inserted the file
            offset++;
        }
        idx = [aSet indexGreaterThanIndex:idx];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == fileView && [keyPath isEqualToString:@"iconScale"]) {
        [[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:[fileView iconScale] forKey:BDSKEditorFileViewIconScaleKey];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSString *)windowNibName{
    return @"BibEditor";
}

- (id)initWithPublication:(BibItem *)aBib{
    if (self = [super initWithWindowNibName:@"BibEditor"]) {
        
        publication = [aBib retain];
        isEditable = [[publication owner] isDocument];
                
        forceEndEditing = NO;
        didSetupForm = NO;
    }
    return self;
}

// implement NSCoding because we might be encoded as the delegate of some menus
// mainly for the toolbar popups in a customization palette 
- (id)initWithCoder:(NSCoder *)decoder{
    [[self init] release];
    self = nil;
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder{}

- (void)windowDidLoad{
	
    // we should have a document at this point, as the nib is not loaded before -window is called, which shouldn't happen before the document shows us
    OBASSERT([self document]);
    
    [[self window] setBackgroundColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1.0]];
    
    [[bibFields prototype] setEditable:isEditable];
    [bibTypeButton setEnabled:isEditable];
    [addFieldButton setEnabled:isEditable];
    
    // Setup the default cells for the extraBibFields matrix
	booleanButtonCell = [[NSButtonCell alloc] initTextCell:@""];
	[booleanButtonCell setButtonType:NSSwitchButton];
	[booleanButtonCell setTarget:self];
	[booleanButtonCell setAction:@selector(changeFlag:)];
    [booleanButtonCell setEnabled:isEditable];
	
	triStateButtonCell = [booleanButtonCell copy];
	[triStateButtonCell setAllowsMixedState:YES];
	
	ratingButtonCell = [[BDSKRatingButtonCell alloc] initWithMaxRating:5];
	[ratingButtonCell setImagePosition:NSImageLeft];
	[ratingButtonCell setAlignment:NSLeftTextAlignment];
	[ratingButtonCell setTarget:self];
	[ratingButtonCell setAction:@selector(changeRating:)];
    [ratingButtonCell setEnabled:isEditable];
	
	NSCell *cell = [[NSCell alloc] initTextCell:@""];
	[extraBibFields setPrototype:cell];
	[cell release];
    
    // Setup the toolbar
    //[self setupToolbar];
	
    // Setup the statusbar
	[statusBar retain]; // we need to retain, as we might remove it from the window
	if (![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShowEditorStatusBarKey]) {
		[self toggleStatusBar:nil];
	}
	[statusBar setDelegate:self];
    [statusBar setTextOffset:NSMaxX([actionButton frame])];
    
    // Insert the tabView in the main window
    BDSKEdgeView *edgeView = [[mainSplitView subviews] objectAtIndex:0];
    [[tabView superview] setFrame:[edgeView frame]];
    [edgeView addSubview:tabView];
	[edgeView setEdges:BDSKMaxXEdgeMask];
    
    // Setup the form and the matrix
	edgeView = (BDSKEdgeView *)[[fieldSplitView subviews] objectAtIndex:0];
	[edgeView setEdges:BDSKMinYEdgeMask];
    NSRect ignored, frame;
    NSDivideRect([[edgeView contentView] bounds], &ignored, &frame, FORM_OFFSET, NSMinXEdge);
    [[bibFields enclosingScrollView] setFrame:frame];
	[edgeView addSubview:[bibFields enclosingScrollView]];
    // don't know why, but this is broken
    [bibTypeButton setNextKeyView:bibFields];
    
    edgeView = (BDSKEdgeView *)[[fieldSplitView subviews] objectAtIndex:1];
    [edgeView setEdges:BDSKMinYEdgeMask | BDSKMaxYEdgeMask];
    NSDivideRect([[edgeView contentView] bounds], &ignored, &frame, FORM_OFFSET, NSMinXEdge);
    [[extraBibFields enclosingScrollView] setFrame:frame];
	[edgeView addSubview:[extraBibFields enclosingScrollView]];
    
    edgeView = (BDSKEdgeView *)[[[notesView enclosingScrollView] superview] superview];
    [edgeView setEdges:BDSKMinYEdgeMask | BDSKMaxYEdgeMask];
    [edgeView setColor:[NSColor lightGrayColor] forEdge:NSMaxYEdge];
    edgeView = (BDSKEdgeView *)[[[abstractView enclosingScrollView] superview] superview];
    [edgeView setEdges:BDSKMinYEdgeMask | BDSKMaxYEdgeMask];
    [edgeView setColor:[NSColor lightGrayColor] forEdge:NSMaxYEdge];
    edgeView = (BDSKEdgeView *)[[[rssDescriptionView enclosingScrollView] superview] superview];
    [edgeView setEdges:BDSKMinYEdgeMask | BDSKMaxYEdgeMask];
    [edgeView setColor:[NSColor lightGrayColor] forEdge:NSMaxYEdge];
    
    [fileSplitView setBlendStyle:BDSKMinBlendStyleMask];
    
    [self setWindowFrameAutosaveNameOrCascade:BDSKBibEditorFrameAutosaveName];
    
    // Setup the splitview autosave frames, should be done after the statusBar and splitViews are setup
    [mainSplitView setPositionAutosaveName:@"BDSKSplitView Frame BibEditorMainSplitView"];
    [fieldSplitView setPositionAutosaveName:@"BDSKSplitView Frame BibEditorFieldSplitView"];
    [fileSplitView setPositionAutosaveName:@"BDSKSplitView Frame BibEditorFileSplitView"];
    if ([self windowFrameAutosaveName] == nil) {
        // Only autosave the frames when the window's autosavename is set to avoid inconsistencies
        [mainSplitView setPositionAutosaveName:nil];
        [fieldSplitView setPositionAutosaveName:nil];
        [fileSplitView setPositionAutosaveName:nil];
    }
    
    formCellFormatter = [[BDSKComplexStringFormatter alloc] initWithDelegate:self macroResolver:[[publication owner] macroResolver]];
    crossrefFormatter = [[BDSKCrossrefFormatter alloc] init];
    citationFormatter = [[BDSKCitationFormatter alloc] initWithDelegate:self];
    
    [self setupForm];
    if (isEditable)
        [bibFields registerForDraggedTypes:[NSArray arrayWithObjects:BDSKBibItemPboardType, nil]];
    
    // Setup the citekey textfield
    BDSKCiteKeyFormatter *citeKeyFormatter = [[BDSKCiteKeyFormatter alloc] init];
    [citeKeyField setFormatter:citeKeyFormatter];
    [citeKeyFormatter release];
	[citeKeyField setStringValue:[publication citeKey]];
    [citeKeyField setEditable:isEditable];
	
    // Setup the type popup
    [self setupTypePopUp];
    
	// Setup the toolbar buttons.
    // The popupbutton needs to be set before fixURLs is called, and -windowDidLoad gets sent after awakeFromNib.
    [self setupButtons];

    [authorTableView setDoubleAction:@selector(showPersonDetailCmd:)];
    
    // Setup the textviews
    [notesView setString:[publication valueOfField:BDSKAnnoteString inherit:NO]];
    [notesView setEditable:isEditable];
    [abstractView setString:[publication valueOfField:BDSKAbstractString inherit:NO]];
    [abstractView setEditable:isEditable];
    [rssDescriptionView setString:[publication valueOfField:BDSKRssDescriptionString inherit:NO]];
    [rssDescriptionView setEditable:isEditable];
	currentEditedView = nil;
    
    // Set up identifiers for the tab view items, since we receive delegate messages from it
    NSArray *tabViewItems = [tabView tabViewItems];
    [[tabViewItems objectAtIndex:0] setIdentifier:BDSKBibtexString];
    [[tabViewItems objectAtIndex:1] setIdentifier:BDSKAnnoteString];
    [[tabViewItems objectAtIndex:2] setIdentifier:BDSKAbstractString];
    [[tabViewItems objectAtIndex:3] setIdentifier:BDSKRssDescriptionString];
	
	// Update the statusbar message and icons
    [self needsToBeFiledDidChange:nil];
	[self updateCiteKeyAutoGenerateStatus];
    
    [self registerForNotifications];
    
    [bibFields setDelegate:self];
    
    [[self window] setDelegate:self];
    if (isEditable)
        [[self window] registerForDraggedTypes:[NSArray arrayWithObjects:BDSKBibItemPboardType, NSStringPboardType, nil]];					
	
    [self updateCiteKeyDuplicateWarning];
    
    [fileView setIconScale:[[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKEditorFileViewIconScaleKey]];
    [fileView addObserver:self forKeyPath:@"iconScale" options:0 context:NULL];
    [fileView setEditable:isEditable];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    return [publication displayTitle];
}

- (NSString *)representedFilenameForWindow:(NSWindow *)aWindow {
    NSString *fname = [[[publication localFiles] firstObject] path];
    return fname ? fname : @"";
}

- (BibItem *)publication{
    return publication;
}

- (void)dealloc{
    [publication release];
	[authorTableView setDelegate:nil];
    [authorTableView setDataSource:nil];
    [notesViewUndoManager release];
    [abstractViewUndoManager release];
    [rssDescriptionViewUndoManager release];   
    [booleanButtonCell release];
    [triStateButtonCell release];
    [ratingButtonCell release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[dragFieldEditor release];
	[statusBar release];
	[macroTextFieldWC release];
    [formCellFormatter release];
    [crossrefFormatter release];
    [citationFormatter release];
    [super dealloc];
}

- (void)show{
    [self showWindow:self];
}

// note that we don't want the - document accessor! It messes us up by getting called for other stuff.

- (void)finalizeChangesPreservingSelection:(BOOL)shouldPreserveSelection{

    NSResponder *firstResponder = [[self window] firstResponder];
    
	// need to finalize text field cells being edited or the abstract/annote text views, since the text views bypass the normal undo mechanism for speed, and won't cause the doc to be marked dirty on subsequent edits
	if([firstResponder isKindOfClass:[NSText class]]){
		NSText *textView = (NSText *)firstResponder;
		NSRange selection = [textView selectedRange];
		id textDelegate = [textView delegate];
        if(textDelegate == bibFields || textDelegate == citeKeyField)
            firstResponder = textDelegate; // the text field or the form (textView is the field editor)

		forceEndEditing = YES; // make sure the validation will always allow the end of the edit
		didSetupForm = NO; // if we we rebuild the form, the selection will become meaningless
        
		// now make sure we submit the edit
		if (![[self window] makeFirstResponder:[self window]]){
            // this will remove the field editor from the view, set its delegate to nil, and empty it of text
			[[self window] endEditingFor:nil];
            forceEndEditing = NO;
            return;
        }
        
		forceEndEditing = NO;
        
        if(shouldPreserveSelection == NO)
            return;
        
        // for inherited fields, we should do something here to make sure the user doesn't have to go through the warning sheet
		
		if([[self window] makeFirstResponder:firstResponder] &&
		   !(firstResponder == bibFields && didSetupForm)){
            if([[textView string] length] < NSMaxRange(selection)) // check range for safety
                selection = NSMakeRange([[textView string] length],0);
            [textView setSelectedRange:selection];
        }
            
	}
}

- (void)finalizeChanges:(NSNotification *)aNotification{
    [self finalizeChangesPreservingSelection:YES];
}

- (IBAction)toggleStatusBar:(id)sender{
	[statusBar toggleBelowView:mainSplitView offset:1.0];
	[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:[statusBar isVisible] forKey:BDSKShowEditorStatusBarKey];
}

- (IBAction)openLinkedFile:(id)sender{
    NSEnumerator *urlEnum = nil;
	NSURL *fileURL = [sender representedObject];
    
    if (fileURL)
        urlEnum = [[NSArray arrayWithObject:fileURL] objectEnumerator];
    else
        urlEnum = [[publication valueForKeyPath:@"localFiles.URL"] objectEnumerator];
    
    while (fileURL = [urlEnum nextObject]) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            [[NSWorkspace sharedWorkspace] openLinkedFile:[fileURL path]];
        }
    }
}

- (IBAction)revealLinkedFile:(id)sender{
    NSEnumerator *urlEnum = nil;
	NSURL *fileURL = [sender representedObject];
    
    if (fileURL)
        urlEnum = [[NSArray arrayWithObject:fileURL] objectEnumerator];
    else
        urlEnum = [[publication valueForKeyPath:@"remoteURLs.URL"] objectEnumerator];
    
    while (fileURL = [urlEnum nextObject]) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            [[NSWorkspace sharedWorkspace]  selectFile:[fileURL path] inFileViewerRootedAtPath:nil];
        }
    }
}

- (IBAction)openLinkedURL:(id)sender{
    NSEnumerator *urlEnum = nil;
	NSURL *remoteURL = [sender representedObject];
    
    if (remoteURL)
        urlEnum = [[NSArray arrayWithObject:remoteURL] objectEnumerator];
    else
        urlEnum = [[publication valueForKeyPath:@"remoteURLs.URL"] objectEnumerator];
    
    while (remoteURL = [urlEnum nextObject]) {
        if ([remoteURL isEqual:[NSNull null]] == NO) {
			[[NSWorkspace sharedWorkspace] openURL:remoteURL];
        }
    }
}

- (IBAction)showNotesForLinkedFile:(id)sender{
    NSEnumerator *urlEnum = nil;
	NSURL *fileURL = [sender representedObject];
    
    if (fileURL)
        urlEnum = [[NSArray arrayWithObject:fileURL] objectEnumerator];
    else
        urlEnum = [[publication valueForKeyPath:@"localFiles.URL"] objectEnumerator];
    
    while (fileURL = [urlEnum nextObject]) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            BDSKNotesWindowController *notesController = [[[BDSKNotesWindowController alloc] initWithURL:fileURL] autorelease];
        
            [[self document] addWindowController:notesController];
            [notesController showWindow:self];
        }
    }
}

- (IBAction)copyNotesForLinkedFile:(id)sender{
    NSEnumerator *urlEnum = nil;
	NSURL *fileURL = [sender representedObject];
    NSMutableString *string = [NSMutableString string];
    
    if (fileURL)
        urlEnum = [[NSArray arrayWithObject:fileURL] objectEnumerator];
    else
        urlEnum = [[publication valueForKeyPath:@"localFiles.URL"] objectEnumerator];
    
    while (fileURL = [urlEnum nextObject]) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            NSString *notes = [[BDSKSkimReader sharedReader] textNotesAtURL:fileURL];
            
            if ([notes length]) {
                if ([string length])
                    [string appendString:@"\n\n"];
                [string appendString:notes];
            }
            
        }
    }
    if ([string length]) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [pboard setString:string forType:NSStringPboardType];
    }
}

#pragma mark Menus

- (void)menuNeedsUpdate:(NSMenu *)menu{
    NSString *menuTitle = [menu title];
    if([menuTitle isEqualToString:@"previewRecentDocumentsMenu"]){
        [self updatePreviewRecentDocumentsMenu:menu];
    } else if([menuTitle isEqualToString:@"safariRecentDownloadsMenu"]){
        [self updateSafariRecentDownloadsMenu:menu];
    } else if([menuTitle isEqualToString:@"safariRecentURLsMenu"]){
        [self updateSafariRecentURLsMenu:menu];
    }
}

// prevents the menus from being updated just to look for key equivalents
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action{
    return NO;
}

- (void)fileView:(FileView *)aFileView willPopUpMenu:(NSMenu *)menu onIconAtIndex:(NSUInteger)anIndex {
    
    NSURL *theURL = anIndex == NSNotFound ? nil : [[publication objectInFilesAtIndex:anIndex] URL];
	NSMenu *submenu;
	NSMenuItem *item;
    int i = 0;
    
    if (theURL) {
        i = [menu indexOfItemWithTag:FVOpenMenuItemTag];
        [menu insertItemWithTitle:[NSLocalizedString(@"Open With",@"Menu item title") stringByAppendingEllipsis]
                andSubmenuOfApplicationsForURL:theURL atIndex:++i];
    }
    if ([theURL isFileURL]) {
        i = [menu indexOfItemWithTag:FVRevealMenuItemTag];
        item = [menu insertItemWithTitle:[NSLocalizedString(@"Skim Notes",@"Menu item title: Skim Note...") stringByAppendingEllipsis]
                                  action:@selector(showNotesForLinkedFile:)
                           keyEquivalent:@""
                                 atIndex:++i];
        [item setRepresentedObject:theURL];
        
        item = [menu insertItemWithTitle:[NSLocalizedString(@"Copy Skim Notes",@"Menu item title: Copy Skim Notes...") stringByAppendingEllipsis]
                                  action:@selector(copyNotesForLinkedFile:)
                           keyEquivalent:@""
                                 atIndex:++i];
        [item setRepresentedObject:theURL];
        
        if (isEditable) {
            item = [menu insertItemWithTitle:[NSLocalizedString(@"Replace File",@"Menu item title: Replace File...") stringByAppendingEllipsis]
                                      action:@selector(chooseLocalFile:)
                               keyEquivalent:@""
                                     atIndex:++i];
            [item setRepresentedObject:[NSNumber numberWithUnsignedInt:anIndex]];
            
            item = [menu insertItemWithTitle:NSLocalizedString(@"Move To Trash",@"Menu item title")
                                      action:@selector(trashLocalFile:)
                               keyEquivalent:@""
                                     atIndex:++i];
            [item setRepresentedObject:[NSNumber numberWithUnsignedInt:anIndex]];
        }
    } else if (theURL && isEditable) {
        item = [menu insertItemWithTitle:[NSLocalizedString(@"Replace URL",@"Menu item title: Replace File...") stringByAppendingEllipsis]
                                  action:@selector(chooseRemoteURL:)
                           keyEquivalent:@""
                                 atIndex:++i];
        [item setRepresentedObject:[NSNumber numberWithUnsignedInt:anIndex]];
    }
    
    if (isEditable) {
        [menu addItem:[NSMenuItem separatorItem]];
        
        [menu addItemWithTitle:[NSLocalizedString(@"Choose File", @"Menu item title") stringByAppendingEllipsis]
                        action:@selector(chooseLocalFile:)
                 keyEquivalent:@""];
        
        // get Safari recent downloads
        item = [menu addItemWithTitle:NSLocalizedString(@"Safari Recent Downloads", @"Menu item title")
                         submenuTitle:@"safariRecentDownloadsMenu"
                      submenuDelegate:self];

        // get recent downloads (Tiger only) by searching the system downloads directory
        // should work for browsers other than Safari, if they use IC to get/set the download directory
        // don't create this in the delegate method; it needs to start working in the background
        if(submenu = [self recentDownloadsMenu]){
            item = [menu addItemWithTitle:NSLocalizedString(@"Link to Recent Download", @"Menu item title") submenu:submenu];
        }
        
        // get Preview recent documents
        [menu addItemWithTitle:NSLocalizedString(@"Link to Recently Opened File", @"Menu item title")
                  submenuTitle:@"previewRecentDocumentsMenu"
               submenuDelegate:self];
            
        [menu addItem:[NSMenuItem separatorItem]];
        
        [menu addItemWithTitle:[NSLocalizedString(@"Choose URL", @"Menu item title") stringByAppendingEllipsis]
                        action:@selector(chooseRemoteURL:)
                 keyEquivalent:@""];
        
        // get Safari recent URLs
        [menu addItemWithTitle:NSLocalizedString(@"Link to Download URL", @"Menu item title")
                  submenuTitle:@"safariRecentURLsMenu"
               submenuDelegate:self];
    }
}

- (NSArray *)safariDownloadHistory{
    static CFURLRef downloadPlistURL = NULL;
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    if(NULL == downloadPlistURL){
        NSString *downloadPlistFileName = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
        downloadPlistFileName = [downloadPlistFileName stringByAppendingPathComponent:@"Safari"];
        downloadPlistFileName = [downloadPlistFileName stringByAppendingPathComponent:@"Downloads.plist"];
        downloadPlistURL = CFURLCreateWithFileSystemPath(alloc, (CFStringRef)downloadPlistFileName, kCFURLPOSIXPathStyle, FALSE);
    }
    Boolean success;
    CFReadStreamRef readStream = CFReadStreamCreateWithFile(alloc, downloadPlistURL);
    success = readStream != NULL;
        
    if(success)
        success = CFReadStreamOpen(readStream);
    
    NSDictionary *theDictionary = nil;
    CFPropertyListFormat format;
    CFStringRef errorString = nil;
    if(success)
        theDictionary = (NSDictionary *)CFPropertyListCreateFromStream(alloc, readStream, 0, kCFPropertyListImmutable, &format, &errorString);
    
    if(nil == theDictionary){
        NSLog(@"failed to read Safari download property list %@ (%@)", downloadPlistURL, errorString);
        if(errorString) CFRelease(errorString);
    }
    
    if(readStream){
        CFReadStreamClose(readStream);
        CFRelease(readStream);
    }
    
    NSArray *historyArray = [[theDictionary objectForKey:@"DownloadHistory"] retain];
    [theDictionary release];
	return [historyArray autorelease];
}

- (void)updateSafariRecentDownloadsMenu:(NSMenu *)menu{
	NSArray *historyArray = [self safariDownloadHistory];
		
	unsigned int i = 0;
	unsigned numberOfItems = [historyArray count];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [menu removeAllItems];
    
	for (i = 0; i < numberOfItems; i ++){
		NSDictionary *itemDict = [historyArray objectAtIndex:i];
		NSString *filePath = [itemDict objectForKey:@"DownloadEntryPath"];
		filePath = [filePath stringByStandardizingPath];
        
        // after uncompressing the file, the original path is gone
        if([fileManager fileExistsAtPath:filePath] == NO)
            filePath = [[itemDict objectForKey:@"DownloadEntryPostPath"] stringByStandardizingPath];
		if([fileManager fileExistsAtPath:filePath]){
			NSMenuItem *item = [menu addItemWithTitle:[filePath lastPathComponent]
                                               action:@selector(addLinkedFileFromMenuItem:)
                                        keyEquivalent:@""];
			[item setRepresentedObject:filePath];
			[item setImageAndSize:[NSImage imageForFile:filePath]];
		}
	}
    
    if (numberOfItems == 0) {
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Downloads", @"Menu item title") action:NULL keyEquivalent:@""];
    }
}


- (void)updateSafariRecentURLsMenu:(NSMenu *)menu{
	NSArray *historyArray = [self safariDownloadHistory];
	unsigned numberOfItems = [historyArray count];
	unsigned int i = 0;
    
    [menu removeAllItems];
	
	for (i = 0; i < numberOfItems; i ++){
		NSDictionary *itemDict = [historyArray objectAtIndex:i];
		NSString *URLString = [itemDict objectForKey:@"DownloadEntryURL"];
		if (![NSString isEmptyString:URLString] && [NSURL URLWithString:URLString]) {
			NSMenuItem *item = [menu addItemWithTitle:URLString
                                               action:@selector(addRemoteURLFromMenuItem:)
                                        keyEquivalent:@""];
			[item setRepresentedObject:URLString];
			[item setImageAndSize:[NSImage genericInternetLocationImage]];
		}
	}
    
    if (numberOfItems == 0) {
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Downloads", @"Menu item title") action:NULL keyEquivalent:@""];
    }
}

- (void)updatePreviewRecentDocumentsMenu:(NSMenu *)menu{
    // get all of the items from the Apple menu (works on 10.4, anyway), and build a set of the file paths for easy comparison as strings
    NSMutableSet *globalRecentPaths = [[NSMutableSet alloc] initWithCapacity:10];
    CFDictionaryRef globalRecentDictionary = CFPreferencesCopyAppValue(CFSTR("Documents"), CFSTR("com.apple.recentitems"));
    NSArray *globalItems = [(NSDictionary *)globalRecentDictionary objectForKey:@"CustomListItems"];
    [(id)globalRecentDictionary autorelease];
    
    NSEnumerator *e = [globalItems objectEnumerator];
    NSDictionary *itemDict = nil;
    NSData *aliasData = nil;
    NSString *filePath = nil;
    BDAlias *alias = nil;
    
    while(itemDict = [e nextObject]){
        aliasData = [itemDict objectForKey:@"Alias"];
        alias = [[BDAlias alloc] initWithData:aliasData];
        filePath = [alias fullPathNoUI];
        if(filePath)
            [globalRecentPaths addObject:filePath];
        [alias release];
    }
    
    // now get all of the recent items from Preview.app; this does not include items opened since Preview's last launch, unfortunately, regardless of the call to CFPreferencesSynchronize
	NSArray *historyArray = (NSArray *) CFPreferencesCopyAppValue(CFSTR("NSRecentDocumentRecords"), CFSTR("com.apple.Preview"));
    NSMutableSet *previewRecentPaths = [[NSMutableSet alloc] initWithCapacity:10];
	
	unsigned int i = 0;
	unsigned numberOfItems = [(NSArray *)historyArray count];
	for (i = 0; i < numberOfItems; i ++){
		itemDict = [(NSArray *)historyArray objectAtIndex:i];
		aliasData = [[itemDict objectForKey:@"_NSLocator"] objectForKey:@"_NSAlias"];
		
        alias = [[BDAlias alloc] initWithData:aliasData];
        filePath = [alias fullPathNoUI];
        if(filePath)
            [previewRecentPaths addObject:filePath];
        [alias release];
	}
	
	if(historyArray) CFRelease(historyArray);
    
    NSString *fileName;
    NSMenuItem *item;
    
    [menu removeAllItems];

    // now add all of the items from Preview, which are most likely what we want
    e = [previewRecentPaths objectEnumerator];
    while(filePath = [e nextObject]){
        if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            fileName = [filePath lastPathComponent];            
            item = [menu addItemWithTitle:fileName
                                   action:@selector(addLinkedFileFromMenuItem:)
                            keyEquivalent:@""];
            [item setRepresentedObject:filePath];
            [item setImageAndSize:[NSImage imageForFile:filePath]];
        }
    }
    
    // add a separator between Preview and global recent items, unless Preview has never been used
    if([previewRecentPaths count])
        [menu addItem:[NSMenuItem separatorItem]];

    // now add all of the items that /were not/ in Preview's recent items path; this works for files opened from Preview's open panel, as well as from the Finder
    e = [globalRecentPaths objectEnumerator];
    while(filePath = [e nextObject]){
        
        if(![previewRecentPaths containsObject:filePath] && [[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            fileName = [filePath lastPathComponent];            
            item = [menu addItemWithTitle:fileName
                                   action:@selector(addLinkedFileFromMenuItem:)
                            keyEquivalent:@""];
            [item setRepresentedObject:filePath];
            [item setImageAndSize:[NSImage imageForFile:filePath]];
        }
    }  
    
    if ([globalRecentPaths count] == 0) {
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Documents", @"Menu item title") action:NULL keyEquivalent:@""];
    }
        
    [globalRecentPaths release];
    [previewRecentPaths release];
}

- (NSMenu *)recentDownloadsMenu{
    NSMenu *menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
    
    [self updateRecentDownloadsMenu:menu]; 
    
    if ([menu numberOfItems] == 0) {
        [menu release];
        return nil;
    }
    
    return [menu autorelease];
}

- (void)updateRecentDownloadsMenu:(NSMenu *)menu{
    
    [menu removeAllItems];
    
    // limit the scope to the default downloads directory (from Internet Config)
    NSURL *downloadURL = [[NSFileManager defaultManager] downloadFolderURL];
    if(downloadURL){
        // this was copied verbatim from a Finder saved search for all items of kind document modified in the last week
        NSString *query = @"(kMDItemContentTypeTree = 'public.content') && (kMDItemFSContentChangeDate >= $time.today(-7)) && (kMDItemContentType != com.apple.mail.emlx) && (kMDItemContentType != public.vcard)";
        [[BDSKPersistentSearch sharedSearch] addQuery:query scopes:[NSArray arrayWithObject:downloadURL]];
        
        NSArray *paths = [[BDSKPersistentSearch sharedSearch] resultsForQuery:query attribute:(NSString *)kMDItemPath];
        NSEnumerator *e = [paths objectEnumerator];
        
        NSString *filePath;
        NSMenuItem *item;
        
        while(filePath = [e nextObject]){            
            item = [menu addItemWithTitle:[filePath lastPathComponent]
                                   action:@selector(addLinkedFileFromMenuItem:)
                            keyEquivalent:@""];
            [item setRepresentedObject:filePath];
            [item setImageAndSize:[NSImage imageForFile:filePath]];
        }
    }
}

- (void)dummy:(id)obj{}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
    
    SEL theAction = [menuItem action];
    
	if (theAction == nil ||
		theAction == @selector(dummy:)){ // Unused selector for disabled items. Needed to avoid the popupbutton to insert its own
		return NO;
	}
	else if (theAction == @selector(generateCiteKey:)) {
		return isEditable;
	}
	else if (theAction == @selector(consolidateLinkedFiles:)) {
		return (isEditable && [[publication localFiles] count]);
	}
	else if (theAction == @selector(duplicateTitleToBooktitle:)) {
		return (isEditable && ![NSString isEmptyString:[publication valueOfField:BDSKTitleString]]);
	}
	else if (theAction == @selector(selectCrossrefParentAction:)) {
        return ([NSString isEmptyString:[publication valueOfField:BDSKCrossrefString inherit:NO]] == NO);
	}
	else if (theAction == @selector(createNewPubUsingCrossrefAction:)) {
        return (isEditable && [NSString isEmptyString:[publication valueOfField:BDSKCrossrefString inherit:NO]] == YES);
	}
	else if (theAction == @selector(openLinkedFile:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(revealLinkedFile:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(openLinkedURL:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(showNotesForLinkedFile:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(copyNotesForLinkedFile:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
    else if (theAction == @selector(editSelectedFieldAsRawBibTeX:)) {
        if (isEditable == NO)
            return NO;
        id cell = [bibFields selectedCell];
		return (cell != nil && [bibFields currentEditor] != nil && [macroTextFieldWC isEditing] == NO && 
                [[cell representedObject] isEqualToString:BDSKCrossrefString] == NO && [[cell representedObject] isCitationField] == NO);
    }
    else if (theAction == @selector(toggleStatusBar:)) {
		if ([statusBar isVisible]) {
			[menuItem setTitle:NSLocalizedString(@"Hide Status Bar", @"Menu item title")];
		} else {
			[menuItem setTitle:NSLocalizedString(@"Show Status Bar", @"Menu item title")];
		}
		return YES;
    }
    else if (theAction == @selector(raiseAddField:) || 
             theAction == @selector(raiseDelField:) || 
             theAction == @selector(raiseChangeFieldName:) || 
             theAction == @selector(chooseLocalFile:) || 
             theAction == @selector(chooseRemoteURL:) || 
             theAction == @selector(addLinkedFileFromMenuItem:) || 
             theAction == @selector(addRemoteURLFromMenuItem:)) {
        return isEditable;
    }

	return YES;
}

#pragma mark Cite Key handling methods

- (IBAction)showCiteKeyWarning:(id)sender{
    if ([publication hasEmptyOrDefaultCiteKey])
        NSBeginAlertSheet(NSLocalizedString(@"Cite Key Not Set", @"Message in alert dialog when duplicate citye key was found"),nil,nil,nil,[self window],nil,NULL,NULL,NULL,NSLocalizedString(@"The cite key has not been set. Please provide one.", @"Informative text in alert dialog"));
    else if ([publication isValidCiteKey:[publication citeKey]] == NO)
        NSBeginAlertSheet(NSLocalizedString(@"Duplicate Cite Key", @"Message in alert dialog when duplicate citye key was found"),nil,nil,nil,[self window],nil,NULL,NULL,NULL,NSLocalizedString(@"The cite key you entered is either already used in this document. Please provide a unique one.", @"Informative text in alert dialog"));
}

- (void)updateCiteKeyDuplicateWarning{
    if (isEditable == NO)
        return;
    NSString *message = nil;
    if ([publication hasEmptyOrDefaultCiteKey])
        message = NSLocalizedString(@"The cite-key has not been set", @"Tool tip message");
    else if ([publication isValidCiteKey:[publication citeKey]] == NO)
        message = NSLocalizedString(@"This cite-key is a duplicate", @"Tool tip message");
	[citeKeyWarningButton setHidden:message == nil];
    [citeKeyWarningButton setToolTip:message];
	[citeKeyField setTextColor:(message ? [NSColor redColor] : [NSColor blackColor])];
}

- (void)generateCiteKeyAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	if([alert checkValue] == YES)
		[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:NO forKey:BDSKWarnOnCiteKeyChangeKey];
    
    if(returnCode == NSAlertAlternateReturn)
        return;
    
    // could use [[alert window] orderOut:nil] here, but we're using the didDismissSelector instead
    // This is problematic, since finalizeChangesPreservingSelection: ends up triggering a format failure sheet if the user deleted the citekey and then chose to generate (this might be common in case of duplicating an item, for instance).  Therefore, we'll catch that case here and reset the control to the publication's current value, since we're going to generate a new one anyway.
    if ([NSString isEmptyString:[citeKeyField stringValue]])
        [citeKeyField setStringValue:[publication citeKey]];
	[self finalizeChangesPreservingSelection:YES];
	
	BDSKScriptHook *scriptHook = nil;
	NSString *oldKey = [publication citeKey];
	NSString *newKey = [publication suggestedCiteKey];
	
	scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKWillGenerateCiteKeyScriptHookName];
	if (scriptHook) {
		[scriptHook setField:BDSKCiteKeyString];
		[scriptHook setOldValues:[NSArray arrayWithObject:oldKey]];
		[scriptHook setNewValues:[NSArray arrayWithObject:newKey]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:publication] document:[self document]];
	}
	
	// get them again, as the script hook might have changed some values
	oldKey = [publication citeKey];
	newKey = [publication suggestedCiteKey];
    
    NSString *crossref = [publication valueOfField:BDSKCrossrefString inherit:NO];
    if (crossref != nil && [crossref caseInsensitiveCompare:newKey] == NSOrderedSame) {
        NSAlert *nsAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Could not generate cite key", @"Message in alert dialog when failing to generate cite key") 
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The cite key for \"%@\" could not be generated because the generated key would be the same as the crossref key.", @"Informative text in alert dialog"), oldKey];
        [nsAlert beginSheetModalForWindow:[self window]
                            modalDelegate:nil
                           didEndSelector:NULL
                              contextInfo:NULL];
        return;
    }
	[publication setCiteKey:newKey];
	
	scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKDidGenerateCiteKeyScriptHookName];
	if (scriptHook) {
		[scriptHook setField:BDSKCiteKeyString];
		[scriptHook setOldValues:[NSArray arrayWithObject:oldKey]];
		[scriptHook setNewValues:[NSArray arrayWithObject:newKey]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:publication] document:[self document]];
	}
	
	[[self undoManager] setActionName:NSLocalizedString(@"Generate Cite Key", @"Undo action name")];
	[tabView selectFirstTabViewItem:self];
}

- (IBAction)generateCiteKey:(id)sender{
    if([publication hasEmptyOrDefaultCiteKey] == NO && 
       [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKWarnOnCiteKeyChangeKey]){
        BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Really Generate Cite Key?", @"Message in alert dialog when generating cite keys")
                                             defaultButton:NSLocalizedString(@"Generate", @"Button title")
                                           alternateButton:NSLocalizedString(@"Cancel", @"Button title") 
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"This action will generate a new cite key for the publication.  This action is undoable.", @"Informative text in alert dialog")];
        [alert setHasCheckButton:YES];
        [alert setCheckValue:NO];
           
        // use didDismissSelector or else we can have sheets competing for the window
        [alert beginSheetModalForWindow:[self window] 
                          modalDelegate:self 
                         didEndSelector:NULL
                     didDismissSelector:@selector(generateCiteKeyAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
    } else {
        [self generateCiteKeyAlertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:NULL];
    }
}

- (void)consolidateAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSArray *files = nil;
    
    if (returnCode == NSAlertAlternateReturn){
        return;
    }else if(returnCode == NSAlertOtherReturn){
        NSEnumerator *fileEnum = [[publication localFiles] objectEnumerator];
        BDSKLinkedFile *file;
        files = [NSMutableArray array];
        
        while(file = [fileEnum nextObject]){
            if([publication canSetURLForLinkedFile:file] == NO)
                [publication addFileToBeFiled:file];
            else
                [(NSMutableArray *)files addObject:file];
        }
    }else{
        files = [publication localFiles];
    }
    
    if ([files count] == 0)
        return;
    
	[[BDSKFiler sharedFiler] filePapers:files fromDocument:[self document] check:NO];
	
	[tabView selectFirstTabViewItem:self];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Move File", @"Undo action name")];
}

- (IBAction)consolidateLinkedFiles:(id)sender{
	[self finalizeChangesPreservingSelection:YES];
	
	BOOL canSet = YES;
    NSEnumerator *fileEnum = [[publication localFiles] objectEnumerator];
    BDSKLinkedFile *file;
    
    while(file = [fileEnum nextObject]){
        if([publication canSetURLForLinkedFile:file] == NO){
            canSet = NO;
            break;
        }
    }
    
	if (canSet == NO){
		NSString *message = NSLocalizedString(@"Not all fields needed for generating the file location are set.  Do you want me to file the paper now using the available fields, or cancel autofile for this paper?",@"");
		NSString *otherButton = nil;
		if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
			message = NSLocalizedString(@"Not all fields needed for generating the file location are set. Do you want me to file the paper now using the available fields, cancel autofile for this paper, or wait until the necessary fields are set?", @"Informative text in alert dialog"),
			otherButton = NSLocalizedString(@"Wait", @"Button title");
		}
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog") 
                                         defaultButton:NSLocalizedString(@"File Now", @"Button title")
                                       alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                           otherButton:otherButton
                             informativeTextWithFormat:message];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(consolidateAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
	} else {
        [self consolidateAlertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:NULL];
    }
}

- (IBAction)duplicateTitleToBooktitle:(id)sender{
	[self finalizeChangesPreservingSelection:YES];
	
	[publication duplicateTitleToBooktitleOverwriting:YES];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Duplicate Title", @"Undo action name")];
}

- (IBAction)bibTypeDidChange:(id)sender{
    if (![[self window] makeFirstResponder:[self window]]){
        [[self window] endEditingFor:nil];
    }
    NSString *newType = [bibTypeButton titleOfSelectedItem];
    if(![[publication pubType] isEqualToString:newType]){
        [publication setPubType:newType];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:newType
                                                          forKey:BDSKPubTypeStringKey];
		
		[[self undoManager] setActionName:NSLocalizedString(@"Change Type", @"Undo action name")];
    }
}

- (void)updateTypePopup{ // used to update UI after dragging into the editor
    [bibTypeButton selectItemWithTitle:[publication pubType]];
}

- (IBAction)changeRating:(id)sender{
	BDSKRatingButtonCell *cell = [sender selectedCell];
	NSString *field = [cell representedObject];
	int oldRating = [publication ratingValueOfField:field];
	int newRating = [cell rating];
		
	if(newRating != oldRating) {
		[publication setField:field toRatingValue:newRating];
        [self userChangedField:field from:[NSString stringWithFormat:@"%i", oldRating] to:[NSString stringWithFormat:@"%i", newRating]];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Rating", @"Undo action name")];
	}
}

- (IBAction)changeFlag:(id)sender{
	NSButtonCell *cell = [sender selectedCell];
	NSString *field = [cell representedObject];
    BOOL isTriState = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKTriStateFieldsKey] containsObject:field];
    
    if(isTriState){
        NSCellStateValue oldState = [publication triStateValueOfField:field];
        NSCellStateValue newState = [cell state];
        
        if(newState == oldState) return;
        
        [publication setField:field toTriStateValue:newState];
        [self userChangedField:field from:[NSString stringWithTriStateValue:oldState] to:[NSString stringWithTriStateValue:newState]];
    }else{
        BOOL oldBool = [publication boolValueOfField:field];
        BOOL newBool = [cell state] == NSOnState ? YES : NO;
        
        if(newBool == oldBool) return;    
        
        [publication setField:field toBoolValue:newBool];
        [self userChangedField:field from:[NSString stringWithBool:oldBool] to:[NSString stringWithBool:newBool]];
    }
    [[self undoManager] setActionName:NSLocalizedString(@"Change Flag", @"Undo action name")];
	
}

#pragma mark choose local-url or url support

- (IBAction)chooseLocalFile:(id)sender{
    unsigned int anIndex = NSNotFound;
    NSNumber *indexNumber = [sender representedObject];
    NSString *path = nil;
    if (indexNumber) {
        anIndex = [indexNumber unsignedIntValue];
        path = [[[publication objectInFilesAtIndex:anIndex] URL] path];
    }
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setResolvesAliases:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
	
    [oPanel beginSheetForDirectory:[path stringByDeletingLastPathComponent] 
                              file:[path lastPathComponent] 
                    modalForWindow:[self window] 
                     modalDelegate:self 
                    didEndSelector:@selector(chooseLocalFilePanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:(void *)anIndex];
  
}

- (void)chooseLocalFilePanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{

    if(returnCode == NSOKButton){
        unsigned int anIndex = (unsigned int)contextInfo;
        NSURL *aURL = [[sheet URLs] objectAtIndex:0];
        if (anIndex != NSNotFound) {
            BDSKLinkedFile *aFile = [[[BDSKLinkedFile alloc] initWithURL:aURL delegate:publication] autorelease];
            if (aFile == nil)
                return;
            [publication removeObjectFromFilesAtIndex:anIndex];
            [publication insertObject:aFile inFilesAtIndex:anIndex];
            [publication autoFileLinkedFile:aFile];
        } else {
            [publication addFileForURL:aURL autoFile:YES];
        }
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
    }        
}

- (void)addLinkedFileFromMenuItem:(NSMenuItem *)sender{
	NSString *path = [sender representedObject];
    NSURL *aURL = [NSURL fileURLWithPath:path];
    [publication addFileForURL:aURL autoFile:YES];
    [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
}

- (IBAction)trashLocalFile:(id)sender{
    unsigned int anIndex = [[sender representedObject] unsignedIntValue];
    NSString *path = [[[publication objectInFilesAtIndex:anIndex] URL] path];
    NSString *folderPath = [path stringByDeletingLastPathComponent];
    NSString *fileName = [path lastPathComponent];
    int tag = 0;
    [publication removeObjectFromFilesAtIndex:anIndex];
    [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:folderPath destination:nil files:[NSArray arrayWithObjects:fileName, nil] tag:&tag];
    [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
}

- (IBAction)chooseRemoteURL:(id)sender{
    unsigned int anIndex = NSNotFound;
    NSNumber *indexNumber = [sender representedObject];
    NSString *urlString = @"http://";
    if (indexNumber) {
        anIndex = [indexNumber unsignedIntValue];
        urlString = [[[publication objectInFilesAtIndex:anIndex] URL] absoluteString];
    }
	[chooseURLField setStringValue:urlString];
    
    [NSApp beginSheet:chooseURLSheet
       modalForWindow:[self window] 
        modalDelegate:self 
       didEndSelector:@selector(chooseRemoteURLSheetDidEnd:returnCode:contextInfo:) 
          contextInfo:(void *)anIndex];
}

- (void)chooseRemoteURLSheetDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{

    if (returnCode == NSOKButton) {
        NSString *aURLString = [chooseURLField stringValue];
        if ([NSString isEmptyString:aURLString])
            return;
        if ([aURLString rangeOfString:@"://"].location == NSNotFound)
            aURLString = [@"http://" stringByAppendingString:aURLString];
        NSURL *aURL = [NSURL URLWithString:aURLString];
        if (aURL == nil)
            return;
        unsigned int anIndex = (unsigned int)contextInfo;
        if (anIndex != NSNotFound) {
            BDSKLinkedFile *aFile = [[[BDSKLinkedFile alloc] initWithURL:aURL delegate:publication] autorelease];
            if (aFile == nil)
                return;
            [publication removeObjectFromFilesAtIndex:anIndex];
            [publication insertObject:aFile inFilesAtIndex:anIndex];
            [publication autoFileLinkedFile:aFile];
        } else {
            [publication addFileForURL:aURL autoFile:NO];
        }
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
    }        
}

- (IBAction)dismissChooseURLSheet:(id)sender{
    [NSApp endSheet:chooseURLSheet returnCode:[sender tag]];
    [chooseURLSheet orderOut:self];
}

- (void)addRemoteURLFromMenuItem:(NSMenuItem *)sender{
    NSURL *aURL = [sender representedObject];
    [publication addFileForURL:aURL autoFile:YES];
    [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
}

// ----------------------------------------------------------------------------------------
#pragma mark add-Field-Sheet Support
// Add field sheet support
// ----------------------------------------------------------------------------------------

- (void)addFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *newField = [addFieldController field];
    if(returnCode == NSCancelButton || newField == nil)
        return;
    
    NSArray *currentFields = [publication allFieldNames];
    newField = [newField fieldName];
    if([currentFields containsObject:newField] == NO){
		[tabView selectFirstTabViewItem:nil];
        [publication addField:newField];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Field", @"Undo action name")];
		[self setupForm];
		[self setKeyField:newField];
    }
}

// raises the add field sheet
- (IBAction)raiseAddField:(id)sender{
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSArray *currentFields = [publication allFieldNames];
    NSArray *fieldNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObject:BDSKCrossrefString] excluding:currentFields];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of field to add:", @"Label for adding field")
                                                                                              fieldsArray:fieldNames];
	[addFieldController beginSheetModalForWindow:[self window]
                                   modalDelegate:self
                                  didEndSelector:@selector(addFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

#pragma mark Key field

- (NSString *)keyField{
    NSString *keyField = nil;
    NSString *tabId = [[tabView selectedTabViewItem] identifier];
    if([tabId isEqualToString:BDSKBibtexString]){
        id firstResponder = [[self window] firstResponder];
        if ([firstResponder isKindOfClass:[NSText class]] && [firstResponder isFieldEditor])
            firstResponder = [firstResponder delegate];
        if(firstResponder == bibFields)
            keyField = [[bibFields selectedCell] representedObject];
        else if(firstResponder == extraBibFields)
            keyField = [[extraBibFields keyCell] representedObject];
        else if(firstResponder == citeKeyField)
            keyField = BDSKCiteKeyString;
        else if(firstResponder == bibTypeButton)
            keyField = BDSKPubTypeString;
    }else{
        keyField = tabId;
    }
    return keyField;
}

- (void)setKeyField:(NSString *)fieldName{
    if([NSString isEmptyString:fieldName]){
        return;
    }else if([fieldName isNoteField]){
        [tabView selectTabViewItemWithIdentifier:fieldName];
    }else if([fieldName isEqualToString:BDSKPubTypeString]){
        [[self window] makeFirstResponder:bibTypeButton];
    }else if([fieldName isEqualToString:BDSKCiteKeyString]){
        [citeKeyField selectText:nil];
    }else if([fieldName isBooleanField] || [fieldName isTriStateField] || [fieldName isRatingField]){
        int i, j, numRows = [extraBibFields numberOfRows], numCols = [extraBibFields numberOfColumns];
        id cell;
        
        for (i = 0; i < numRows; i++) {
            for (j = 0; j < numCols; j++) {
                cell = [extraBibFields cellAtRow:i column:j];
                if ([[cell representedObject] isEqualToString:fieldName]) {
                    [[self window] makeFirstResponder:extraBibFields];
                    [extraBibFields setKeyCell:cell];
                    return;
                }
            }
        }
    }else{
        int i, numRows = [bibFields numberOfRows];

        for (i = 0; i < numRows; i++) {
            if ([[[bibFields cellAtIndex:i] representedObject] isEqualToString:fieldName]) {
                [bibFields selectTextAtIndex:i];
                return;
            }
        }
    }
}

// ----------------------------------------------------------------------------------------
#pragma mark ||  delete-Field-Sheet Support
// ----------------------------------------------------------------------------------------

- (void)removeFieldSheetDidEnd:(BDSKRemoveFieldSheetController *)removeFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *oldField = [removeFieldController field];
    NSString *oldValue = [[[publication valueOfField:oldField] retain] autorelease];
    NSArray *removableFields = [removeFieldController fieldsArray];
    if(returnCode == NSCancelButton || oldField == nil || [removableFields count] == 0)
        return;
	
    [tabView selectFirstTabViewItem:nil];
    [publication removeField:oldField];
    [self userChangedField:oldField from:oldValue to:@""];
    [[self undoManager] setActionName:NSLocalizedString(@"Remove Field", @"Undo action name")];
    [self setupForm];
}

// raises the del field sheet
- (IBAction)raiseDelField:(id)sender{
    // populate the popupbutton
    NSString *currentType = [publication pubType];
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
	NSMutableArray *removableFields = [[publication allFieldNames] mutableCopy];
	[removableFields removeObjectsInArray:[NSArray arrayWithObjects:BDSKAnnoteString, BDSKAbstractString, BDSKRssDescriptionString, nil]];
	[removableFields removeObjectsInArray:[typeMan requiredFieldsForType:currentType]];
	[removableFields removeObjectsInArray:[typeMan optionalFieldsForType:currentType]];
	[removableFields removeObjectsInArray:[typeMan userDefaultFieldsForType:currentType]];
    
    NSString *prompt = NSLocalizedString(@"Name of field to remove:", @"Label for removing field");
	if ([removableFields count]) {
		[removableFields sortUsingSelector:@selector(caseInsensitiveCompare:)];
	} else {
		prompt = NSLocalizedString(@"No fields to remove", @"Label when no field to remove");
	}
    
    BDSKRemoveFieldSheetController *removeFieldController = [[BDSKRemoveFieldSheetController alloc] initWithPrompt:prompt
                                                                                                       fieldsArray:removableFields];
    
    NSString *selectedCellTitle = [[bibFields selectedCell] representedObject];
    if([removableFields containsObject:selectedCellTitle]){
        [removeFieldController setField:selectedCellTitle];
        // if we don't deselect this cell, we can't remove it from the form
        [self finalizeChangesPreservingSelection:NO];
    }
    
	[removableFields release];
	
	[removeFieldController beginSheetModalForWindow:[self window]
                                      modalDelegate:self
                                     didEndSelector:@selector(removeFieldSheetDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
    [removeFieldController release];
}

#pragma mark Change field name

- (void)changeFieldSheetDidEnd:(BDSKChangeFieldSheetController *)changeFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *oldField = [changeFieldController field];
    NSString *newField = [changeFieldController newField];
    NSString *oldValue = [[[publication valueOfField:oldField] retain] autorelease];
    int autoGenerateStatus = 0;
    
    if(returnCode == NSCancelButton || [NSString isEmptyString:newField] || 
       [newField isEqualToString:oldField] || [[publication allFieldNames] containsObject:newField])
        return;
    
    NSString *currentType = [publication pubType];
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSMutableSet *nonNilFields = [NSMutableSet setWithObjects:BDSKAnnoteString, BDSKAbstractString, BDSKRssDescriptionString, nil];
	[nonNilFields addObjectsFromArray:[typeMan requiredFieldsForType:currentType]];
	[nonNilFields addObjectsFromArray:[typeMan optionalFieldsForType:currentType]];
	[nonNilFields addObjectsFromArray:[typeMan userDefaultFieldsForType:currentType]];
    
    [tabView selectFirstTabViewItem:nil];
    [publication addField:newField];
    [publication setField:newField toValue:[publication valueOfField:oldField]];
    if([nonNilFields containsObject:oldField])
        [publication setField:oldField toValue:@""];
    else
        [publication removeField:oldField];
    autoGenerateStatus = [self userChangedField:oldField from:oldValue to:@""];
    [self userChangedField:newField from:@"" to:oldValue didAutoGenerate:autoGenerateStatus];
    [[self undoManager] setActionName:NSLocalizedString(@"Change Field Name", @"Undo action name")];
    [self setupForm];
    [self setKeyField:newField];
}

- (IBAction)raiseChangeFieldName:(id)sender{
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSArray *currentFields = [publication allFieldNames];
    NSArray *fieldNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObject:BDSKCrossrefString] excluding:currentFields];
	NSMutableArray *removableFields = [[publication allFieldNames] mutableCopy];
    [removableFields removeObjectsInArray:[[typeMan noteFieldsSet] allObjects]];
    
    if([removableFields count] == 0){
        NSBeep();
        [removableFields release];
        return;
    }
    
    BDSKChangeFieldSheetController *changeFieldController = [[BDSKChangeFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of field to change:", @"Label for changing field name")
                                                                                                       fieldsArray:removableFields
                                                                                                         newPrompt:NSLocalizedString(@"New field name:", @"Label for changing field name")
                                                                                                    newFieldsArray:fieldNames];
    
    NSString *selectedCellTitle = [[bibFields selectedCell] representedObject];
    if([removableFields containsObject:selectedCellTitle]){
        [changeFieldController setField:selectedCellTitle];
        // if we don't deselect this cell, we can't remove it from the form
        [self finalizeChangesPreservingSelection:NO];
    }else if(sender == self){
        // double clicked title of a field we cannot change
        [changeFieldController release];
        [removableFields release];
        return;
    }
    
	[removableFields release];
    
	[changeFieldController beginSheetModalForWindow:[self window]
                                      modalDelegate:self
                                     didEndSelector:@selector(changeFieldSheetDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
	[changeFieldController release];
}

#pragma mark Text Change handling

- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender{
	if ([self editSelectedFormCellAsMacro])
		[[bibFields currentEditor] selectAll:sender];
}

- (BOOL)editSelectedFormCellAsMacro{
	NSCell *cell = [bibFields selectedCell];
	if ([macroTextFieldWC isEditing] || cell == nil || [[cell representedObject] isEqualToString:BDSKCrossrefString] || [[cell representedObject] isCitationField]) 
		return NO;
	NSString *value = [publication valueOfField:[cell representedObject]];
	
	[formCellFormatter setEditAsComplexString:YES];
	[cell setObjectValue:value];
    
    if (macroTextFieldWC == nil)
        macroTextFieldWC = [[MacroFormWindowController alloc] init];
	
    return [macroTextFieldWC attachToView:bibFields atRow:[bibFields selectedRow] column:0 withValue:value];
}

- (BOOL)formatter:(BDSKComplexStringFormatter *)formatter shouldEditAsComplexString:(NSString *)object {
	[self editSelectedFormCellAsMacro];
	return YES;
}

// this is called when the user actually starts editing
- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor{
    if (control != bibFields) return YES;
    
    NSString *field = [[bibFields selectedCell] representedObject];
	NSString *value = [publication valueOfField:field];
    
	if([value isInherited] &&
	   [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKWarnOnEditInheritedKey]){
		BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")
											 defaultButton:NSLocalizedString(@"OK", @"Button title")
										   alternateButton:NSLocalizedString(@"Cancel", @"Button title")
											   otherButton:NSLocalizedString(@"Edit Parent", @"Button title")
								 informativeTextWithFormat:NSLocalizedString(@"The value was inherited from the item linked to by the Crossref field. Do you want to overwrite the inherited value?", @"Informative text in alert dialog")];
		[alert setHasCheckButton:YES];
		[alert setCheckValue:NO];
		int rv = [alert runSheetModalForWindow:[self window]
								 modalDelegate:self 
								didEndSelector:@selector(editInheritedAlertDidEnd:returnCode:contextInfo:)  
							didDismissSelector:NULL 
								   contextInfo:NULL];
		if (rv == NSAlertAlternateReturn) {
			return NO;
		} else if (rv == NSAlertOtherReturn) {
			[self openParentItemForField:field];
			return NO;
		}
	}
	return YES;
}

- (void)editInheritedAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if ([alert checkValue] == YES)
		[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:NO forKey:BDSKWarnOnEditInheritedKey];
}

// send by the formatter when validation failed
- (void)control:(NSControl *)control didFailToValidatePartialString:(NSString *)string errorDescription:(NSString *)error{
    if(error != nil){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Entry", @"Message in alert dialog when entering invalid entry") 
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"%@", error];
        
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:nil];
    }
}

// send by the formatter when formatting in getObjectValue... failed
// alert sheets must be app modal because this method returns a value and the editor window ccan close when this method returns
- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)aString errorDescription:(NSString *)error{
	if (control == bibFields) {
        NSCell *cell = [bibFields cellAtIndex:[bibFields indexOfSelectedItem]];
        NSString *fieldName = [cell representedObject];
		if ([fieldName isEqualToString:BDSKCrossrefString]) {
            // this may occur if the cite key formatter fails to format
            if(error != nil){
                BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Crossref Key", @"Message in alert dialog when entering invalid Crossref key") 
                                                     defaultButton:nil
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:@"%@", error];
                
                [alert runSheetModalForWindow:[self window]];
                if(forceEndEditing)
                    [cell setStringValue:[publication valueOfField:fieldName]];
            }else{
                NSLog(@"%@:%d formatter for control %@ failed for unknown reason", __FILENAMEASNSSTRING__, __LINE__, control);
            }
            return forceEndEditing;
		} else if ([fieldName isCitationField]) {
            // this may occur if the citation formatter fails to format
            if(error != nil){
                BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Citation Key", @"Message in alert dialog when entering invalid Crossref key") 
                                                     defaultButton:nil
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:@"%@", error];
                
                [alert runSheetModalForWindow:[self window]];
                if(forceEndEditing)
                    [cell setStringValue:[publication valueOfField:fieldName]];
            }else{
                NSLog(@"%@:%d formatter for control %@ failed for unknown reason", __FILENAMEASNSSTRING__, __LINE__, control);
            }
            return forceEndEditing;
        } else if ([formCellFormatter editAsComplexString]) {
			if (forceEndEditing) {
				// reset the cell's value to the last saved value and proceed
				[cell setStringValue:[publication valueOfField:fieldName]];
				return YES;
			}
			// don't set the value
			return NO;
		} else {
			// this is a simple string, an error means that there are unbalanced braces
			NSString *message = nil;
			NSString *cancelButton = nil;
			
			if (forceEndEditing) {
				message = NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved.", @"Informative text in alert dialog");
			} else {
				message = NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved. Do you want to keep editing?", @"Informative text in alert dialog");
				cancelButton = NSLocalizedString(@"Cancel", @"Button title");
			}
			
            BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Value", @"Message in alert dialog when entering an invalid value") 
                                                 defaultButton:NSLocalizedString(@"OK", @"Button title")
                                               alternateButton:cancelButton
                                                   otherButton:nil
                                     informativeTextWithFormat:message];
            
            int rv = [alert runSheetModalForWindow:[self window]];
			
			if (forceEndEditing || rv == NSAlertAlternateReturn) {
				[cell setStringValue:[publication valueOfField:fieldName]];
				return YES;
			} else {
				return NO;
			}
		}
	} else if (control == citeKeyField) {
        // this may occur if the cite key formatter fails to format
        if(error != nil){
            BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Cite Key", @"Message in alert dialog when enetring invalid cite key") 
                                                 defaultButton:nil
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"%@", error];
            
            [alert runSheetModalForWindow:[self window]];
            if(forceEndEditing)
                [control setStringValue:[publication citeKey]];
		}else{
            NSLog(@"%@:%d formatter for control %@ failed for unknown reason", __FILENAMEASNSSTRING__, __LINE__, control);
		}
        return forceEndEditing;
    } else {
        // shouldn't get here
        NSLog(@"%@:%d formatter failed for unknown reason", __FILENAMEASNSSTRING__, __LINE__);
        return forceEndEditing;
    }
}

// send when the user wants to end editing
// alert sheets must be app modal because this method returns a value and the editor window ccan close when this method returns
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor{
	if (control == bibFields) {
		
		NSCell *cell = [bibFields cellAtIndex:[bibFields indexOfSelectedItem]];
		NSString *message = nil;
		
		if ([[cell representedObject] isEqualToString:BDSKCrossrefString] && [NSString isEmptyString:[cell stringValue]] == NO) {
			
            // check whether we won't get a crossref chain
            int errorCode = [publication canSetCrossref:[cell stringValue] andCiteKey:[publication citeKey]];
            if (errorCode == BDSKSelfCrossrefError)
                message = NSLocalizedString(@"An item cannot cross reference to itself.", @"Informative text in alert dialog");
            else if (errorCode == BDSKChainCrossrefError)
                message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"Informative text in alert dialog");
            else if (errorCode == BDSKIsCrossreffedCrossrefError)
                message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"Informative text in alert dialog");
			
			if (message) {
                BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Crossref Value", @"Message in alert dialog when entering an invalid Crossref key") 
                                                     defaultButton:NSLocalizedString(@"OK", @"Button title")
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:message];
                
                [alert runSheetModalForWindow:[self window]];
				[cell setStringValue:@""];
				return forceEndEditing;
			}
		}
        		
	} else if (control == citeKeyField) {
		
        NSString *message = nil;
        NSString *cancelButton = nil;
        NSCharacterSet *invalidSet = [[BDSKTypeManager sharedManager] fragileCiteKeyCharacterSet];
        NSRange r = [[control stringValue] rangeOfCharacterFromSet:invalidSet];
        
        if (r.location != NSNotFound) {
            
            if (forceEndEditing) {
                message = NSLocalizedString(@"The cite key you entered contains characters that could be invalid in TeX.", @"Informative text in alert dialog");
            } else {
                message = NSLocalizedString(@"The cite key you entered contains characters that could be invalid in TeX. Do you want to continue editing with the invalid characters removed?", @"Informative text in alert dialog");
                cancelButton = NSLocalizedString(@"Cancel", @"Button title");
            }
            
        } else {
            // check whether we won't crossref to the new citekey
            int errorCode = [publication canSetCrossref:[publication valueOfField:BDSKCrossrefString inherit:NO] andCiteKey:[control stringValue]];
            if (errorCode == BDSKSelfCrossrefError)
                message = NSLocalizedString(@"An item cannot cross reference to itself.", @"Informative text in alert dialog");
            else if (errorCode != BDSKNoCrossrefError) // shouldn't happen
                message = NSLocalizedString(@"Cannot set this cite key as this would lead to a crossreff chain.", @"Informative text in alert dialog");
        }
        
        if (message) {
            BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Value", @"Message in alert dialog when entering an invalid value") 
                                                 defaultButton:NSLocalizedString(@"OK", @"Button title")
                                               alternateButton:cancelButton
                                                   otherButton:nil
                                     informativeTextWithFormat:message];
            
            int rv = [alert runSheetModalForWindow:[self window]];
            
            if (forceEndEditing || rv == NSAlertAlternateReturn) {
                return YES;
             } else {
                [control setStringValue:[[control stringValue] stringByReplacingCharactersInSet:invalidSet withString:@""]];
                return NO;
            }
		}
	}
	
	return YES;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification{
	id control = [aNotification object];
	
    if (control == bibFields) {
        
        int idx = [control indexOfSelectedItem];
        if (idx == -1)
            return;
        
        NSCell *cell = [control cellAtIndex:idx];
        NSString *title = [cell representedObject];
        NSString *value = [cell stringValue];
        NSString *prevValue = [publication valueOfField:title];

        if ([prevValue isInherited] &&
            ([value isEqualAsComplexString:prevValue] || [value isEqualAsComplexString:@""]) ) {
            // make sure we keep the original inherited string value
            [cell setObjectValue:prevValue];
        } else if (isEditable && prevValue != nil && [value isEqualAsComplexString:prevValue] == NO) {
            // if prevValue == nil, the field was removed and we're finalizing an edit for a field we should ignore
            [self recordChangingField:title toValue:value];
        }
        // do this here, the order is important!
        [formCellFormatter setEditAsComplexString:NO];
        
	} else if (control == citeKeyField) {

        NSString *newKey = [control stringValue];
        NSString *oldKey = [[[publication citeKey] retain] autorelease];
        
        if(isEditable && [newKey isEqualToString:oldKey] == NO){
            [publication setCiteKey:newKey];
            
            [self userChangedField:BDSKCiteKeyString from:oldKey to:newKey];
            
            [[self undoManager] setActionName:NSLocalizedString(@"Change Cite Key", @"Undo action name")];
            
            [self updateCiteKeyDuplicateWarning];
            
        }
    }
}

- (void)recordChangingField:(NSString *)fieldName toValue:(NSString *)value{
    NSString *oldValue = [[[publication valueOfField:fieldName] copy] autorelease];
    
    [publication setField:fieldName toValue:value];
    
    [self userChangedField:fieldName from:oldValue to:value];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
}

- (int)userChangedField:(NSString *)fieldName from:(NSString *)oldValue to:(NSString *)newValue didAutoGenerate:(int)mask{
    mask |= [[self document] userChangedField:fieldName ofPublications:[NSArray arrayWithObject:publication] from:[NSArray arrayWithObject:oldValue ? oldValue : @""] to:[NSArray arrayWithObject:newValue]];
    
    if (mask != 0) {
        NSString *status = nil;
		if (mask == 1)
            status = NSLocalizedString(@"Autogenerated Cite Key.", @"Status message");
		else if (mask == 2)
            status = NSLocalizedString(@"Autofiled linked file.", @"Status message");
		else if (mask == 3)
            status = NSLocalizedString(@"Autogenerated Cite Key and autofiled linked file.", @"Status message");
		[self setStatus:status];
    }
    
    return mask;
}

- (int)userChangedField:(NSString *)fieldName from:(NSString *)oldValue to:(NSString *)newValue{
    return [self userChangedField:fieldName from:oldValue to:newValue didAutoGenerate:0];
}

- (NSString *)status {
	return [statusBar stringValue];
}

- (void)setStatus:(NSString *)status {
	[statusBar setStringValue:status];
}

- (NSString *)statusBar:(BDSKStatusBar *)statusBar toolTipForIdentifier:(NSString *)identifier {
	NSArray *requiredFields = nil;
	NSMutableArray *missingFields = [[NSMutableArray alloc] initWithCapacity:5];
	NSString *tooltip = nil;
	
	if ([identifier isEqualToString:@"NeedsToGenerateCiteKey"]) {
		requiredFields = [[NSApp delegate] requiredFieldsForCiteKey];
		tooltip = NSLocalizedString(@"The cite key needs to be generated.", @"Tool tip message");
	} else if ([identifier isEqualToString:@"NeedsToBeFiled"]) {
		requiredFields = [[NSApp delegate] requiredFieldsForLocalFile];
		tooltip = NSLocalizedString(@"The linked file needs to be filed.", @"Tool tip message");
	} else {
		return nil;
	}
	
	NSEnumerator *fieldEnum = [requiredFields objectEnumerator];
	NSString *field;
	
	while (field = [fieldEnum nextObject]) {
		if ([field isEqualToString:BDSKCiteKeyString]) {
			if ([publication hasEmptyOrDefaultCiteKey])
				[missingFields addObject:field];
		} else if ([field isEqualToString:@"Document Filename"]) {
			if ([NSString isEmptyString:[[[self document] fileURL] path]])
				[missingFields addObject:field];
		} else if ([field isEqualToString:BDSKAuthorEditorString]) {
			if ([NSString isEmptyString:[publication valueOfField:BDSKAuthorString]] && [NSString isEmptyString:[publication valueOfField:BDSKEditorString]])
				[missingFields addObject:field];
		} else if ([NSString isEmptyString:[publication valueOfField:field]]) {
			[missingFields addObject:field];
		}
	}
	
	if ([missingFields count])
		return [tooltip stringByAppendingFormat:@" %@ %@", NSLocalizedString(@"Missing fields:", @"Tool tip message"), [missingFields componentsJoinedByString:@", "]];
	else
		return tooltip;
}

- (void)needsToBeFiledDidChange:(NSNotification *)notification{
	if ([[publication filesToBeFiled] count]) {
		[self setStatus:NSLocalizedString(@"Linked file needs to be filed.",@"Linked file needs to be filed.")];
		if ([[statusBar iconIdentifiers] containsObject:@"NeedsToBeFiled"] == NO) {
			NSString *tooltip = NSLocalizedString(@"The linked file needs to be filed.", @"Tool tip message");
			[statusBar addIcon:[NSImage imageNamed:@"genericFolderIcon"] withIdentifier:@"NeedsToBeFiled" toolTip:tooltip];
		}
	} else {
		[self setStatus:@""];
		[statusBar removeIconWithIdentifier:@"NeedsToBeFiled"];
	}
}

- (void)updateCiteKeyAutoGenerateStatus{
	if ([publication hasEmptyOrDefaultCiteKey] && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKCiteKeyAutogenerateKey]) {
		if ([[statusBar iconIdentifiers] containsObject:@"NeedsToGenerateCiteKey"] == NO) {
			NSString *tooltip = NSLocalizedString(@"The cite key needs to be generated.", @"Tool tip message");
			[statusBar addIcon:[NSImage imageNamed:@"key"] withIdentifier:@"NeedsToGenerateCiteKey" toolTip:tooltip];
		}
	} else {
		[statusBar removeIconWithIdentifier:@"NeedsToGenerateCiteKey"];
	}
}

- (void)bibDidChange:(NSNotification *)notification{
// unused	BibItem *notifBib = [notification object];
	NSDictionary *userInfo = [notification userInfo];
	NSString *changeType = [userInfo objectForKey:@"type"];
	NSString *changeKey = [userInfo objectForKey:@"key"];
	NSString *newValue = [userInfo objectForKey:@"value"];
	BibItem *sender = (BibItem *)[notification object];
	NSString *crossref = [publication valueOfField:BDSKCrossrefString inherit:NO];
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	BOOL parentDidChange = (crossref != nil && 
							([crossref caseInsensitiveCompare:[sender citeKey]] == NSOrderedSame || 
							 [crossref caseInsensitiveCompare:[userInfo objectForKey:@"oldCiteKey"]] == NSOrderedSame));
	
    // If it is not our item or his crossref parent, we don't care, but our parent may have changed his cite key
	if (sender != publication && !parentDidChange)
		return;

	if([changeType isEqualToString:@"Add/Del Field"]){
		if(![[pw stringArrayForKey:BDSKRatingFieldsKey] containsObject:changeKey] &&
		   ![[pw stringArrayForKey:BDSKBooleanFieldsKey] containsObject:changeKey] &&
		   ![[pw stringArrayForKey:BDSKTriStateFieldsKey] containsObject:changeKey]){
			// no need to rebuild the form when we have a field in the matrix
			[self setupForm];
			return;
		}
	}
	else if([changeType isEqualToString:@"Add/Del File"]){
        [fileView reloadIcons];
        return;
    }
	
    // Rebuild the form if the crossref changed, or our parent's cite key changed.
	if([changeKey isEqualToString:BDSKCrossrefString] || 
	   (parentDidChange && [changeKey isEqualToString:BDSKCiteKeyString])){
        // if we are editing a crossref field, we should first set the new value, because setupForm will set the edited value. This happens when it is set through drag/drop
        if ([[[bibFields selectedCell] representedObject] isEqualToString:changeKey])
            [[bibFields selectedCell] setObjectValue:[publication valueOfField:changeKey]];
		[self setupForm];
		[[self window] setTitle:[publication displayTitle]];
		[authorTableView reloadData];
		return;
	}

	if([changeKey isEqualToString:BDSKPubTypeString]){
		[self setupForm];
		[self updateTypePopup];
		return;
	}
	
	if([[pw stringArrayForKey:BDSKRatingFieldsKey] containsObject:changeKey] || 
	   [[pw stringArrayForKey:BDSKBooleanFieldsKey] containsObject:changeKey] || 
	   [[pw stringArrayForKey:BDSKTriStateFieldsKey] containsObject:changeKey]){
		
		NSEnumerator *cellE = [[extraBibFields cells] objectEnumerator];
		NSButtonCell *entry = nil;
		while(entry = [cellE nextObject]){
			if([[entry representedObject] isEqualToString:changeKey]){
				[entry setIntValue:[publication intValueOfField:changeKey]];
				[extraBibFields setNeedsDisplay:YES];
				break;
			}
		}
		return;
	}
	
	if([changeKey isEqualToString:BDSKCiteKeyString]){
		[citeKeyField setStringValue:newValue];
		[self updateCiteKeyAutoGenerateStatus];
        [self updateCiteKeyDuplicateWarning];
	}else{
		// essentially a cellWithTitle: for NSForm
		NSEnumerator *cellE = [[bibFields cells] objectEnumerator];
		NSFormCell *entry = nil;
		while(entry = [cellE nextObject]){
			if([[entry representedObject] isEqualToString:changeKey]){
				[entry setObjectValue:[publication valueOfField:changeKey]];
				[bibFields setNeedsDisplay:YES];
				break;
			}
		}
	}
	
    if([changeKey isEqualToString:BDSKTitleString] || [changeKey isEqualToString:BDSKChapterString] || [changeKey isEqualToString:BDSKPagesString]){
		[[self window] setTitle:[publication displayTitle]];
	}
	else if([changeKey isPersonField]){
		[authorTableView reloadData];
	}
    else if([changeKey isEqualToString:BDSKAnnoteString]){
        if(ignoreFieldChange) return;
        // make a copy of the current value, so we don't overwrite it when we set the field value to the text storage
        NSString *tmpValue = [[publication valueOfField:BDSKAnnoteString inherit:NO] copy];
        [notesView setString:(tmpValue == nil ? @"" : tmpValue)];
        [tmpValue release];
        if(currentEditedView == notesView)
            [[self window] makeFirstResponder:[self window]];
        [notesViewUndoManager removeAllActions];
    }
    else if([changeKey isEqualToString:BDSKAbstractString]){
        if(ignoreFieldChange) return;
        NSString *tmpValue = [[publication valueOfField:BDSKAbstractString inherit:NO] copy];
        [abstractView setString:(tmpValue == nil ? @"" : tmpValue)];
        [tmpValue release];
        if(currentEditedView == abstractView)
            [[self window] makeFirstResponder:[self window]];
        [abstractViewUndoManager removeAllActions];
    }
    else if([changeKey isEqualToString:BDSKRssDescriptionString]){
        if(ignoreFieldChange) return;
        NSString *tmpValue = [[publication valueOfField:BDSKRssDescriptionString inherit:NO] copy];
        [rssDescriptionView setString:(tmpValue == nil ? @"" : tmpValue)];
        [tmpValue release];
        if(currentEditedView == rssDescriptionView)
            [[self window] makeFirstResponder:[self window]];
        [rssDescriptionViewUndoManager removeAllActions];
    }
            
}
	
- (void)bibWasAddedOrRemoved:(NSNotification *)notification{
	NSEnumerator *pubEnum = [[[notification userInfo] objectForKey:@"pubs"] objectEnumerator];
	id pub;
	NSString *crossref = [publication valueOfField:BDSKCrossrefString inherit:NO];
	
	if ([NSString isEmptyString:crossref])
		return;
	while (pub = [pubEnum nextObject]) {
		if ([crossref caseInsensitiveCompare:[pub valueForKey:@"citeKey"]] != NSOrderedSame) 
			continue;
		[self setupForm];
		return;
	}
}
 
- (void)typeInfoDidChange:(NSNotification *)aNotification{
    // ensure that the pub updates first, since it observes this notification also
    [publication typeInfoDidChange:aNotification];
	[self setupTypePopUp];
	[self setupForm];
}
 
- (void)customFieldsDidChange:(NSNotification *)aNotification{
    // ensure that the pub updates first, since it observes this notification also
    [publication customFieldsDidChange:aNotification];
	[self setupForm];
    [authorTableView reloadData];
}

- (void)macrosDidChange:(NSNotification *)notification{
	id changedOwner = [[notification object] owner];
	if(changedOwner && changedOwner != [publication owner])
		return; // only macro changes for our own document or the global macros
	
	NSArray *cells = [bibFields cells];
	NSEnumerator *cellE = [cells objectEnumerator];
	NSFormCell *entry = nil;
	NSString *value;
	
	while(entry = [cellE nextObject]){
		value = [publication valueOfField:[entry representedObject]];
		if([value isComplex]){
            // ARM: the cell must check pointer equality in the setter, or something; since it's the same object, setting the value again is a noop unless we set to nil first.  Fixes bug #1284205.
            [entry setObjectValue:nil];
			[entry setObjectValue:value];
        }
	}    
}

- (void)fileURLDidChange:(NSNotification *)notification{
    [fileView reloadIcons];
}

#pragma mark annote/abstract/rss

- (void)textDidBeginEditing:(NSNotification *)aNotification{
    // Add the mutableString of the text storage to the item's pubFields, so changes
    // are automatically tracked.  We still have to update the UI manually.
    // The contents of the text views are initialized with the current contents of the BibItem in windowWillLoad:
	currentEditedView = [aNotification object];
    ignoreFieldChange = YES;
    // we need to preserve selection manually; otherwise you end up editing at the end of the string after the call to setField: below
    NSRange selRange = [currentEditedView selectedRange];
    if(currentEditedView == notesView){
        [publication setField:BDSKAnnoteString toValue:[[notesView textStorage] mutableString]];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Annotation",@"Undo action name")];
    } else if(currentEditedView == abstractView){
        [publication setField:BDSKAbstractString toValue:[[abstractView textStorage] mutableString]];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Abstract",@"Undo action name")];
    }else if(currentEditedView == rssDescriptionView){
        [publication setField:BDSKRssDescriptionString toValue:[[rssDescriptionView textStorage] mutableString]];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit RSS Description",@"Undo action name")];
    }
    if(selRange.location != NSNotFound && selRange.location < [[currentEditedView string] length])
        [currentEditedView setSelectedRange:selRange];
    ignoreFieldChange = NO;
}

// Clear all the undo actions when changing tab items, just in case; otherwise we
// crash if you edit in one view, switch tabs, switch back to the previous view and hit undo.
// We can't use textDidEndEditing, since just switching tabs doesn't change first responder.
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem{
    [notesViewUndoManager removeAllActions];
    [abstractViewUndoManager removeAllActions];
    [rssDescriptionViewUndoManager removeAllActions];
}

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem{
    if (currentEditedView && [[currentEditedView string] isStringTeXQuotingBalancedWithBraces:YES connected:NO] == NO) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Value", @"Message in alert dialog when entering an invalid value") 
                                         defaultButton:NSLocalizedString(@"OK", @"Button title")
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved.", @"Informative text in alert dialog")];
    
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        return NO;
    }
    return YES;
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem{
    // fix a weird keyview loop bug
    if([[tabViewItem identifier] isEqualToString:BDSKBibtexString])
        [bibTypeButton setNextKeyView:bibFields];
}

// sent by the notesView and the abstractView
- (void)textDidEndEditing:(NSNotification *)aNotification{
	currentEditedView = nil;
    
    if ([[[aNotification object] string] isStringTeXQuotingBalancedWithBraces:YES connected:NO] == NO) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Value", @"Message in alert dialog when entering an invalid value") 
                                         defaultButton:NSLocalizedString(@"OK", @"Button title")
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The value you entered contains unbalanced braces. If you save you might not be able to reopen the file.", @"Informative text in alert dialog")];
    
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
}

// sent by the notesView and the abstractView; this ensures that the annote/abstract preview gets updated
- (void)textDidChange:(NSNotification *)aNotification{
    NSNotification *notif = [NSNotification notificationWithName:BDSKPreviewDisplayChangedNotification object:nil];
    [[NSNotificationQueue defaultQueue] enqueueNotification:notif 
                                               postingStyle:NSPostWhenIdle 
                                               coalesceMask:NSNotificationCoalescingOnName 
                                                   forModes:nil];
}

#pragma mark document interaction
	
- (void)bibWillBeRemoved:(NSNotification *)notification{
	NSArray *pubs = [[notification userInfo] objectForKey:@"pubs"];
	
	if ([pubs containsObject:publication])
		[self close];
}
	
- (void)groupWillBeRemoved:(NSNotification *)notification{
	NSArray *groups = [[notification userInfo] objectForKey:@"groups"];
	
	if ([groups containsObject:[publication owner]])
		[self close];
}

// these methods are for crossref interaction with the form
- (void)openParentItemForField:(NSString *)field{
    BibItem *parent = [publication crossrefParent];
    if(parent){
        BibEditor *editor = [[self document] editPub:parent];
        if(editor && field)
            [editor setKeyField:field];
    }
}

- (IBAction)selectCrossrefParentAction:(id)sender{
    [[self document] selectCrossrefParentForItem:publication];
}

- (IBAction)createNewPubUsingCrossrefAction:(id)sender{
    [[self document] createNewPubUsingCrossrefForItem:publication];
}

#pragma mark BDSKForm delegate methods

- (void)doubleClickedTitleOfFormCell:(id)cell{
    [self raiseChangeFieldName:self];
}

- (void)arrowClickedInFormCell:(id)cell{
    NSString *field = [cell representedObject];
	[self openParentItemForField:[field isEqualToString:BDSKCrossrefString] ? nil : field];
}

- (BOOL)formCellHasArrowButton:(id)cell{
	return ([[publication valueOfField:[cell representedObject]] isInherited] || 
			([[cell representedObject] isEqualToString:BDSKCrossrefString] && [publication crossrefParent]));
}

- (NSRange)control:(NSControl *)control textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange {
    if (control != bibFields) {
		return charRange;
	} else if ([macroTextFieldWC isEditing]) {
		return [[NSApp delegate] rangeForUserCompletion:charRange 
								  forBibTeXString:[textView string]];
	} else {
		return [[NSApp delegate] entry:[[bibFields selectedCell] representedObject] 
				rangeForUserCompletion:charRange 
							  ofString:[textView string]];

	}
}

- (BOOL)control:(NSControl *)control textViewShouldAutoComplete:(NSTextView *)textview {
    if (control == bibFields)
		return [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKEditorFormShouldAutoCompleteKey];
	return NO;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)idx{
    if (control != bibFields) {
		return words;
	} else if ([macroTextFieldWC isEditing]) {
		return [[NSApp delegate] possibleMatches:[[[publication owner] macroResolver] allMacroDefinitions] 
						   forBibTeXString:[textView string] 
								partialWordRange:charRange 
								indexOfBestMatch:idx];
	} else {
		return [[NSApp delegate] entry:[[bibFields selectedCell] representedObject] 
						   completions:words 
				   forPartialWordRange:charRange 
							  ofString:[textView string] 
				   indexOfSelectedItem:idx];

	}
}

- (BOOL)textViewShouldLinkKeys:(NSTextView *)textView forFormCell:(id)aCell {
    return [[aCell representedObject] isCitationField];
}

static NSString *queryStringWithCiteKey(NSString *citekey)
{
    return [NSString stringWithFormat:@"(net_sourceforge_bibdesk_citekey = '%@'cd) && ((kMDItemContentType != *) || (kMDItemContentType != com.apple.mail.emlx))", citekey];
}

- (BOOL)textView:(NSTextView *)textView isValidKey:(NSString *)key forFormCell:(id)aCell {
    if ([[[publication owner] publications] itemForCiteKey:key] == nil) {
        // don't add a search with the query here, since it gets called on every keystroke; the formatter method gets called at the end, or when scrolling
        NSString *queryString = queryStringWithCiteKey(key);
        return [[[BDSKPersistentSearch sharedSearch] resultsForQuery:queryString attribute:(id)kMDItemPath] count] > 0;
    }
    return YES;
}

- (BOOL)textView:(NSTextView *)aTextView clickedOnLink:(id)aLink atIndex:(unsigned)charIndex forFormCell:(id)aCell {
    BibItem *pub = [[[publication owner] publications] itemForCiteKey:aLink];
    if (nil == pub) {
        NSString *path = [[[BDSKPersistentSearch sharedSearch] resultsForQuery:queryStringWithCiteKey(aLink) attribute:(id)kMDItemPath] firstObject];
        // if it was a valid key/link, we should definitely have a path, but better make sure
        if (path)
            [[NSWorkspace sharedWorkspace] openLinkedFile:path];
        else
            NSBeep();
    } else {
        [[self document] editPub:[[[publication owner] publications] itemForCiteKey:aLink]];
    }
    return YES;
}

- (BOOL)citationFormatter:(BDSKCitationFormatter *)formatter isValidKey:(NSString *)key {
    BOOL isValid;
    if ([[[publication owner] publications] itemForCiteKey:key] == nil) {
        NSString *queryString = queryStringWithCiteKey(key);
        if ([[BDSKPersistentSearch sharedSearch] hasQuery:queryString] == NO) {
            [[BDSKPersistentSearch sharedSearch] addQuery:queryString scopes:[NSArray arrayWithObject:[[NSFileManager defaultManager] spotlightCacheFolderPathByCreating:NULL]]];
        }
        isValid = ([[[BDSKPersistentSearch sharedSearch] resultsForQuery:queryString attribute:(id)kMDItemPath] count] > 0);
    } else {
        isValid = YES;
    }
    return isValid;
}

#pragma mark dragging destination delegate methods

- (NSDragOperation)dragOperation:(id <NSDraggingInfo>)sender forField:(NSString *)field{
	NSPasteboard *pboard = [sender draggingPasteboard];
    id dragSource = [sender draggingSource];
    NSString *dragSourceField = nil;
	NSString *dragType;
	
    if(dragSource == bibFields)
        dragSourceField = [[bibFields dragSourceCell] representedObject];
    
    if ([field isEqualToString:dragSourceField])
        return NSDragOperationNone;
    
	dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, nil]];
	
    if ([field isCitationField]){
		if ([dragType isEqualToString:BDSKBibItemPboardType]) {
			return NSDragOperationEvery;
        }
        return NSDragOperationNone;
	} else if ([field isEqualToString:BDSKCrossrefString]){
		if ([dragType isEqualToString:BDSKBibItemPboardType]) {
			return NSDragOperationEvery;
        }
        return NSDragOperationNone;
	} else {
		// we don't support dropping on a textual field. This is handled by the window
	}
	return NSDragOperationNone;
}

- (BOOL)receiveDrag:(id <NSDraggingInfo>)sender forField:(NSString *)field{
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *dragType;
    
	dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, nil]];
    
    if ([field isCitationField]){
        
		if ([dragType isEqualToString:BDSKBibItemPboardType]) {
            
            NSData *pbData = [pboard dataForType:BDSKBibItemPboardType];
            NSArray *draggedPubs = [[self document] newPublicationsFromArchivedData:pbData];
            NSString *citeKeys = [[draggedPubs valueForKey:@"citeKey"] componentsJoinedByString:@","];
            NSString *oldValue = [[[publication valueOfField:field inherit:NO] retain] autorelease];
            NSString *newValue;
            
            if ([draggedPubs count]) {
                if ([NSString isEmptyString:oldValue])   
                    newValue = citeKeys;
                else
                    newValue = [NSString stringWithFormat:@"%@,%@", oldValue, citeKeys];
                
                [publication setField:field toValue:newValue];
                
                [self userChangedField:field from:oldValue to:newValue];
                [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
                
                return YES;
            }
            
        }
        
	} else if ([field isEqualToString:BDSKCrossrefString]){
        
		if ([dragType isEqualToString:BDSKBibItemPboardType]) {
            
            NSData *pbData = [pboard dataForType:BDSKBibItemPboardType];
            NSArray *draggedPubs = [[self document] newPublicationsFromArchivedData:pbData];
            NSString *crossref = [[draggedPubs firstObject] citeKey];
            NSString *oldValue;
            
            if ([NSString isEmptyString:crossref])
                return NO;
            
            // first check if we don't create a Crossref chain
            int errorCode = [publication canSetCrossref:crossref andCiteKey:[publication citeKey]];
            NSString *message = nil;
            if (errorCode == BDSKSelfCrossrefError)
                message = NSLocalizedString(@"An item cannot cross reference to itself.", @"Informative text in alert dialog");
            else if (errorCode == BDSKChainCrossrefError)
                message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"Informative text in alert dialog");
            else if (errorCode == BDSKIsCrossreffedCrossrefError)
                message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"Informative text in alert dialog");
            
            if (message) {
                NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Crossref Value", @"Message in alert dialog when entering an invalid Crossref key") 
                                                 defaultButton:NSLocalizedString(@"OK", @"Button title")
                                               alternateButton:nil
                                                   otherButton:nil
                                      informativeTextWithFormat:message];
                [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
                return NO;
            }
            
            oldValue = [[[publication valueOfField:BDSKCrossrefString] retain] autorelease];
            
            [publication setField:BDSKCrossrefString toValue:crossref];
            
            [self userChangedField:BDSKCrossrefString from:oldValue to:crossref];
            [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
            
            return YES;
            
        }
        
	} else {
		// we don't at the moment support dropping on a textual field
	}
	return NO;
}

- (NSDragOperation)dragOperation:(id <NSDraggingInfo>)sender forFormCell:(id)cell{
	NSString *field = [cell representedObject];
	return [self dragOperation:sender forField:field];
}

- (BOOL)receiveDrag:(id <NSDraggingInfo>)sender forFormCell:(id)cell{
	NSString *field = [cell representedObject];
	return [self receiveDrag:sender forField:field];
}

- (NSDragOperation)dragWindow:(BDSKDragWindow *)window canReceiveDrag:(id <NSDraggingInfo>)sender{
    NSPasteboard *pboard = [sender draggingPasteboard];
    // weblocs also put strings on the pboard, so check for that type first so we don't get a false positive on NSStringPboardType
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, NSStringPboardType, nil]];
	
	if(pboardType == nil){
        return NSDragOperationNone;
    }
	// sniff the string to see if it's a format we can parse
    if([pboardType isEqualToString:NSStringPboardType]){
        NSString *pbString = [pboard stringForType:pboardType];    
        if([pbString contentStringType] == BDSKUnknownStringType)
            return NSDragOperationNone;
    }

    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
    // get the correct cursor depending on the modifiers
	if( ([NSApp currentModifierFlags] & (NSAlternateKeyMask | NSCommandKeyMask)) == (NSAlternateKeyMask | NSCommandKeyMask) ){
		return NSDragOperationLink;
    }else if (sourceDragMask & NSDragOperationCopy){
		return NSDragOperationCopy;
	} else {
        return NSDragOperationNone;
    }
}

- (BOOL)dragWindow:(BDSKDragWindow *)window receiveDrag:(id <NSDraggingInfo>)sender{
    
    NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, NSStringPboardType, nil]];
	NSArray *draggedPubs = nil;
    BOOL hasTemporaryCiteKey = NO;
    
	if([pboardType isEqualToString:NSStringPboardType]){
		NSString *pbString = [pboard stringForType:NSStringPboardType];
        NSError *error = nil;
        // this returns nil when there was a parser error and the user didn't decide to proceed anyway
        draggedPubs = [[self document] newPublicationsForString:pbString type:[pbString contentStringType] verbose:NO error:&error];
        // we ignore warnings for parsing with temporary keys, but we want to ignore the cite key in that case
        if([[error userInfo] objectForKey:@"temporaryCiteKey"] != nil){
            hasTemporaryCiteKey = YES;
            error = nil;
        }
	}else if([pboardType isEqualToString:BDSKBibItemPboardType]){
		NSData *pbData = [pboard dataForType:BDSKBibItemPboardType];
        // we can't just unarchive, as this gives complex strings with the wrong macroResolver
		draggedPubs = [[self document] newPublicationsFromArchivedData:pbData];
	}
    
    // this happens when we didn't find a valid pboardType or parsing failed
    if([draggedPubs count] == 0) 
        return NO;
	
	BibItem *tempBI = [draggedPubs objectAtIndex:0]; // no point in dealing with multiple pubs for a single editor

	// Test a keyboard mask so that we can override all fields when dragging into the editor window (option)
	// create a crossref (cmd-option), or fill empty fields (no modifiers)
	unsigned modifierFlags = [NSApp currentModifierFlags]; // use the Carbon function since [NSApp currentModifierFlags] won't work if we're not the front app
	
	// we always have sourceDragMask & NSDragOperationLink here for some reason, so test the mask manually
	if((modifierFlags & (NSAlternateKeyMask | NSCommandKeyMask)) == (NSAlternateKeyMask | NSCommandKeyMask)){
		
		// linking, try to set the crossref field
        NSString *crossref = [tempBI citeKey];
		NSString *message = nil;
        NSString *oldValue = [[[publication valueOfField:BDSKCrossrefString] retain] autorelease];
		
		// first check if we don't create a Crossref chain
        int errorCode = [publication canSetCrossref:crossref andCiteKey:[publication citeKey]];
		if (errorCode == BDSKSelfCrossrefError)
			message = NSLocalizedString(@"An item cannot cross reference to itself.", @"Informative text in alert dialog");
		else if (errorCode == BDSKChainCrossrefError)
            message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"Informative text in alert dialog");
		else if (errorCode == BDSKIsCrossreffedCrossrefError)
            message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"Informative text in alert dialog");
		
		if (message) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Crossref Value", @"Message in alert dialog when entering an invalid Crossref key") 
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                  informativeTextWithFormat:message];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			return NO;
		}
		
        // add the crossref field if it doesn't exist, then set it to the citekey of the drag source's bibitem
		[publication setField:BDSKCrossrefString toValue:crossref];
        
        [self userChangedField:BDSKCrossrefString from:oldValue to:crossref];
		[[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
		
        return YES;
        
	} else {
	
        // we aren't linking, so here we decide which fields to overwrite, and just copy values over
        NSEnumerator *newKeyE = [[tempBI allFieldNames] objectEnumerator];
        NSString *key = nil;
        NSString *oldValue = nil;
        NSString *newValue = nil;
        BOOL shouldOverwrite = (modifierFlags & NSAlternateKeyMask) != 0;
        int autoGenerateStatus = 0;
        
        [publication setPubType:[tempBI pubType]]; // do we want this always?
        
        while(key = [newKeyE nextObject]){
            newValue = [tempBI valueOfField:key inherit:NO];
            if([newValue isEqualToString:@""])
                continue;
            
            oldValue = [[[publication valueOfField:key inherit:NO] retain] autorelease]; // value is the value of key in the dragged-onto window.
            
            // only set the field if we force or the value was empty
            if(shouldOverwrite || [NSString isEmptyString:oldValue]){
                // if it's a crossref we should check if we don't create a crossref chain, otherwise we ignore
                if([key isEqualToString:BDSKCrossrefString] && 
                   [publication canSetCrossref:newValue andCiteKey:[publication citeKey]] != BDSKNoCrossrefError)
                    continue;
                [publication setField:key toValue:newValue];
                autoGenerateStatus = [self userChangedField:key from:oldValue to:newValue didAutoGenerate:autoGenerateStatus];
            }
        }
        
        // check cite key here in case we didn't autogenerate, or we're supposed to overwrite
        if((shouldOverwrite || [publication hasEmptyOrDefaultCiteKey]) && 
           [tempBI hasEmptyOrDefaultCiteKey] == NO && hasTemporaryCiteKey == NO && 
           [publication canSetCrossref:[publication valueOfField:BDSKCrossrefString inherit:NO] andCiteKey:[tempBI citeKey]] == BDSKNoCrossrefError) {
            oldValue = [[[publication citeKey] retain] autorelease];
            newValue = [tempBI citeKey];
            [publication setCiteKey:newValue];
            autoGenerateStatus = [self userChangedField:BDSKCiteKeyString from:oldValue to:newValue didAutoGenerate:autoGenerateStatus];
        }
        
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
        
        return YES;
    }
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
	if (anObject != bibFields)
		return nil;
	if (dragFieldEditor == nil) {
		dragFieldEditor = [[BDSKFieldEditor alloc] init];
        if (isEditable)
            [(BDSKFieldEditor *)dragFieldEditor registerForDelegatedDraggedTypes:[NSArray arrayWithObjects:BDSKBibItemPboardType, nil]];
	}
	return dragFieldEditor;
}

- (void)shouldCloseSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    switch (returnCode){
        case NSAlertOtherReturn:
            break; // do nothing
        case NSAlertAlternateReturn:
            [[publication retain] autorelease]; // make sure it stays around till we're closed
            [[self document] removePublication:publication]; // now fall through to default
        default:
            [sheet orderOut:nil];
            [self close];
    }
}

- (BOOL)windowShouldClose:(id)sender{
	// we shouldn't check external items
    if (isEditable == NO)
        return YES;
        
    // User may have started editing some field, e.g. deleted the citekey and not tabbed out; if the user then chooses to discard, the finalizeChangesPreservingSelection: in windowWillClose: ultimately results in a crash due to OAApplication's sheet queue interaction with modal BDSKAlerts.  Hence, we need to call it earlier.  
    [self finalizeChangesPreservingSelection:NO];
    
    // @@ Some of this might be handled automatically for us if we didn't use endEditingFor: to basically override formatter return values.  Forcing the field editor to end editing has always been problematic (see the comments in some of the sheet callbacks).  Perhaps we should just return NO here if [[self window] makeFirstResponder:[self window]] fails, rather than using finalizeChangesPreservingSelection:'s brute force behavior.

    // finalizeChangesPreservingSelection: may end up triggering other sheets, as well (move file, for example; bug #1565645), and we don't want to close the window when it has a sheet attached, since it's waiting for user input at that point.  This is sort of a hack, but there's too much state for us to keep track of and decide if the window should really close.
    if ([[self window] attachedSheet] != nil)
        return NO;
    
    NSString *errMsg = nil;
    NSString *discardMsg = NSLocalizedString(@"Discard", @"Button title");
    
    // case 1: the item has not been edited
    if(![publication hasBeenEdited]){
        errMsg = NSLocalizedString(@"The item has not been edited.  Would you like to keep it?", @"Informative text in alert dialog");
    // case 2: cite key hasn't been set, and paper needs to be filed
    }else if([publication hasEmptyOrDefaultCiteKey] && [[publication filesToBeFiled] count] && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
        errMsg = NSLocalizedString(@"The cite key for this entry has not been set, and AutoFile did not have enough information to file the paper.  Would you like to cancel and continue editing, or close the window and keep this entry as-is?", @"Informative text in alert dialog");
        discardMsg = nil; // this item has some fields filled out and has a paper associated with it; no discard option
    // case 3: only the paper needs to be filed
    }else if([[publication filesToBeFiled] count] && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
        errMsg = NSLocalizedString(@"AutoFile did not have enough information to file this paper.  Would you like to cancel and continue editing, or close the window and keep this entry as-is?", @"Informative text in alert dialog");
        discardMsg = nil; // this item has some fields filled out and has a paper associated with it; no discard option
    // case 4: only the cite key needs to be set
    }else if([publication hasEmptyOrDefaultCiteKey]){
        errMsg = NSLocalizedString(@"The cite key for this entry has not been set.  Would you like to cancel and edit the cite key, or close the window and keep this entry as-is?", @"Informative text in alert dialog");
	// case 5: good to go
    }else{
        return YES;
    }
	
    NSBeginAlertSheet(NSLocalizedString(@"Warning!", @"Message in alert dialog"),
                      NSLocalizedString(@"Keep", @"Button title"),   //default button NSAlertDefaultReturn
                      discardMsg,                        //far left button NSAlertAlternateReturn
                      NSLocalizedString(@"Cancel", @"Button title"), //middle button NSAlertOtherReturn
                      [self window],
                      self, // modal delegate
                      @selector(shouldCloseSheetDidEnd:returnCode:contextInfo:), 
                      NULL, // did dismiss sel
                      NULL,
                      errMsg);
    return NO; // this method returns before the callback

}

- (void)windowWillClose:(NSNotification *)notification{
    // @@ this finalizeChanges seems redundant now that it's in windowShouldClose:
	[self finalizeChangesPreservingSelection:NO];
    
    // close so it's not hanging around by itself; this works if the doc window closes, also
    [macroTextFieldWC close];
    
	// this can give errors when the application quits when an editor window is open
	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKCloseEditorWindowScriptHookName 
												 forPublications:[NSArray arrayWithObject:publication]
                                                        document:[self document]];
	
    // see method for notes
    [self breakTextStorageConnections];
    
    [fileView removeObserver:self forKeyPath:@"iconScale"];
    
    // @@ problem here:  BibEditor is the delegate for a lot of things, and if they get messaged before the window goes away, but after the editor goes away, we have crashes.  In particular, the finalizeChanges (or something?) ends up causing the window and form to be redisplayed if a form cell is selected when you close the window, and the form sends formCellHasArrowButton to a garbage editor.  Rather than set the delegate of all objects to nil here, we'll just hang around a bit longer.
    [[self retain] autorelease];
}

#pragma mark undo manager

- (NSUndoManager *)undoManager {
	return [[self document] undoManager];
}
    
// we want to have the same undoManager as our document, so we use this 
// NSWindow delegate method to return the doc's undomanager ...
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
	return [self undoManager];
}

// ... except for the abstract/annote/rss text views.
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)aTextView {
	if(aTextView == notesView){
        if(notesViewUndoManager == nil)
            notesViewUndoManager = [[NSUndoManager alloc] init];
        return notesViewUndoManager;
    }else if(aTextView == abstractView){
        if(abstractViewUndoManager == nil)
            abstractViewUndoManager = [[NSUndoManager alloc] init];
        return abstractViewUndoManager;
    }else if(aTextView == rssDescriptionView){
        if(rssDescriptionViewUndoManager == nil)
            rssDescriptionViewUndoManager = [[NSUndoManager alloc] init];
        return rssDescriptionViewUndoManager;
	}else return [self undoManager];
}

#pragma mark author table view datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)tableView{
	return [publication numberOfPeople];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    return [[[publication sortedPeople] objectAtIndex:row] displayName];
}

- (IBAction)showPersonDetailCmd:(id)sender{
    NSArray *thePeople = [publication sortedPeople];
    int count = [thePeople count];
    int i = -1;
    
    if([sender isKindOfClass:[NSMenuItem class]])
        i = [sender tag];
    else if (sender == authorTableView)
        i = [authorTableView clickedRow];
    
    if(i == -1){
        NSBeep();
    }else if (i == count){
        for(i = 0; i < count; i++)
            [self showPersonDetail:[thePeople objectAtIndex:i]];
    }else{
        [self showPersonDetail:[thePeople objectAtIndex:i]];
    }
}

- (void)showPersonDetail:(BibAuthor *)person{
    [[self document] showPerson:person];
}

#pragma mark Splitview delegate methods

- (void)splitView:(BDSKSplitView *)sender doubleClickedDividerAt:(int)offset {
    if ([sender isEqual:mainSplitView]) {
        NSView *tabs = [[mainSplitView subviews] objectAtIndex:0]; // tabs
        NSView *files = [[mainSplitView subviews] objectAtIndex:1]; // files+authors
        NSRect tabsFrame = [tabs frame];
        NSRect filesFrame = [files frame];
        
        if(NSWidth(filesFrame) > 0.0){ // not sure what the criteria for isSubviewCollapsed, but it doesn't work
            lastFileViewWidth = NSWidth(filesFrame); // cache this
            tabsFrame.size.width += lastFileViewWidth;
            filesFrame.size.width = 0.0;
        } else {
            if(lastFileViewWidth <= 0.0)
                lastFileViewWidth = 150.0; // a reasonable value to start
            filesFrame.size.width = lastFileViewWidth;
            tabsFrame.size.width = NSWidth([mainSplitView frame]) - lastFileViewWidth - [mainSplitView dividerThickness];
            if (NSWidth(tabsFrame) < 390.0) {
                tabsFrame.size.width = 390.0;
                filesFrame.size.width = NSWidth([mainSplitView frame]) - [mainSplitView dividerThickness] - 390.0;
                lastFileViewWidth = NSWidth(filesFrame);
            }
        }
        [tabs setFrame:tabsFrame];
        [files setFrame:filesFrame];
        [mainSplitView adjustSubviews];
        // fix for NSSplitView bug, which doesn't send this in adjustSubviews
        [[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:mainSplitView];
    } else if ([sender isEqual:fieldSplitView]) {
        NSView *form = [[fieldSplitView subviews] objectAtIndex:0]; // form
        NSView *matrix = [[fieldSplitView subviews] objectAtIndex:1]; // matrix
        NSRect formFrame = [form frame];
        NSRect matrixFrame = [matrix frame];
        
            if(NSHeight(matrixFrame) > 0.0){ // not sure what the criteria for isSubviewCollapsed, but it doesn't work
            lastMatrixHeight = NSHeight(matrixFrame); // cache this
            formFrame.size.height += lastMatrixHeight;
                matrixFrame.size.height = 0.0;
        } else {
                if(lastMatrixHeight <= 0.0)
                lastMatrixHeight = NSHeight([extraBibFields frame]); // a reasonable value to start
                matrixFrame.size.height = lastMatrixHeight;
                formFrame.size.height = NSHeight([fieldSplitView frame]) - lastMatrixHeight - [fieldSplitView dividerThickness];
                if (NSHeight(formFrame) < 1.0) {
                    formFrame.size.height = 1.0;
                    matrixFrame.size.height = NSHeight([fieldSplitView frame]) - [fieldSplitView dividerThickness] - 1.0;
                    lastMatrixHeight = NSHeight(matrixFrame);
                }
        }
        [form setFrame:formFrame];
        [matrix setFrame:matrixFrame];
        [fieldSplitView adjustSubviews];
        // fix for NSSplitView bug, which doesn't send this in adjustSubviews
        [[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:fieldSplitView];
    } else if ([sender isEqual:fileSplitView]) {
        NSView *files = [[fileSplitView subviews] objectAtIndex:0]; // files
        NSView *authors = [[fileSplitView subviews] objectAtIndex:1]; // authors
        NSRect filesFrame = [files frame];
        NSRect authorsFrame = [authors frame];
        
        if(NSHeight(authorsFrame) > 0.0){ // not sure what the criteria for isSubviewCollapsed, but it doesn't work
            lastAuthorsHeight = NSHeight(authorsFrame); // cache this
            filesFrame.size.height += lastMatrixHeight;
            authorsFrame.size.height = 0.0;
        } else {
            if(lastAuthorsHeight <= 0.0)
                lastAuthorsHeight = 150.0; // a reasonable value to start
            authorsFrame.size.height = lastAuthorsHeight;
            filesFrame.size.height = NSHeight([fileSplitView frame]) - lastAuthorsHeight - [fileSplitView dividerThickness];
            if (NSHeight(filesFrame) < 0.0) {
                filesFrame.size.height = 0.0;
                authorsFrame.size.height = NSHeight([fileSplitView frame]) - [fileSplitView dividerThickness];
                lastAuthorsHeight = NSHeight(authorsFrame);
            }
        }
        [files setFrame:filesFrame];
        [authors setFrame:authorsFrame];
        [fileSplitView adjustSubviews];
        // fix for NSSplitView bug, which doesn't send this in adjustSubviews
        [[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:fileSplitView];
    }
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset{
    if ([sender isEqual:mainSplitView]) {
        return fmaxf(proposedMin, 390.0);
    } else if ([sender isEqual:fieldSplitView]) {
        // don't lose the top edge of the splitter
        return proposedMin + 1.0;
    }
    return proposedMin;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize{
    if ([sender isEqual:mainSplitView]) {
        NSView *tabs = [[sender subviews] objectAtIndex:0]; // tabview
        NSView *files = [[sender subviews] objectAtIndex:1]; // files+authors
        NSRect tabsFrame = [tabs frame];
        NSRect filesFrame = [files frame];
        NSSize newSize = [sender frame].size;
        
        tabsFrame.size.width += newSize.width - oldSize.width;
        if (NSWidth(tabsFrame) < 390.0) {
            tabsFrame.size.width = 390.0;
            filesFrame.size.width = newSize.width - [mainSplitView dividerThickness] - 390.0;
            lastFileViewWidth = NSWidth(filesFrame);
        }
        [tabs setFrame:tabsFrame];
        [files setFrame:filesFrame];
        [mainSplitView adjustSubviews];
        // fix for NSSplitView bug, which doesn't send this in adjustSubviews
        [[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:mainSplitView];
    } else if ([sender isEqual:fieldSplitView]) {
    // keeps the matrix view at the same size and resizes the form view
        NSView *form = [[sender subviews] objectAtIndex:0]; // form
        NSView *matrix = [[sender subviews] objectAtIndex:1]; // matrix
        NSRect formFrame = [form frame];
        NSRect matrixFrame = [matrix frame];
        NSSize newSize = [sender frame].size;
        
        formFrame.size.height += newSize.height - oldSize.height;
        if (NSHeight(formFrame) < 1.0) {
            formFrame.size.height = 1.0;
            matrixFrame.size.height = newSize.height - [fieldSplitView dividerThickness] - 1.0;
            lastMatrixHeight = NSHeight(matrixFrame);
        }
        [form setFrame:formFrame];
        [matrix setFrame:matrixFrame];
        [fieldSplitView adjustSubviews];
        // fix for NSSplitView bug, which doesn't send this in adjustSubviews
        [[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:fieldSplitView];
    } else if ([sender isEqual:fileSplitView]) {
        NSView *files = [[sender subviews] objectAtIndex:0]; // files
        NSView *authors = [[sender subviews] objectAtIndex:1]; // authors
        NSRect filesFrame = [files frame];
        NSRect authorsFrame = [authors frame];
        NSSize newSize = [sender frame].size;
        
        filesFrame.size.height += newSize.height - oldSize.height;
        if (NSHeight(filesFrame) < 0.0) {
            filesFrame.size.height = 0.0;
            authorsFrame.size.height = newSize.height - [fileSplitView dividerThickness];
            lastAuthorsHeight = NSHeight(authorsFrame);
        }
        [files setFrame:filesFrame];
        [authors setFrame:authorsFrame];
        [fileSplitView adjustSubviews];
        // fix for NSSplitView bug, which doesn't send this in adjustSubviews
        [[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:fileSplitView];
    } else {
        [sender adjustSubviews];
    }
}

@end

@implementation BibEditor (Private)

- (void)setupButtons {
    
    // Set the properties of actionMenuButton that cannot be set in IB
	[actionMenuButton setShowsMenuWhenIconClicked:YES];
	[[actionMenuButton cell] setAltersStateOfSelectedItem:NO];
	[[actionMenuButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[actionMenuButton cell] setUsesItemFromMenu:NO];
	[[actionMenuButton cell] setRefreshesMenu:NO];
    
	[actionButton setAlternateImage:[NSImage imageNamed:@"GroupAction_Pressed"]];
	[actionButton setArrowImage:nil];
	[actionButton setShowsMenuWhenIconClicked:YES];
	[[actionButton cell] setAltersStateOfSelectedItem:NO];
	[[actionButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[actionButton cell] setUsesItemFromMenu:NO];
	[[actionButton cell] setRefreshesMenu:NO];
	
}    

#define AddFormEntries(fields, attrs) \
    e = [fields objectEnumerator]; \
    while(tmp = [e nextObject]){ \
        if ([ignoredKeys containsObject:tmp]) continue; \
		[ignoredKeys addObject:tmp]; \
		entry = [bibFields insertEntry:[tmp localizedFieldName] usingTitleFont:requiredFont attributesForTitle:attrs indexAndTag:i objectValue:[publication valueOfField:tmp]]; \
		[entry setRepresentedObject:tmp]; \
        if ([tmp isEqualToString:BDSKCrossrefString]) \
			[entry setFormatter:crossrefFormatter]; \
        else if ([tmp isCitationField]) \
			[entry setFormatter:citationFormatter]; \
		else \
			[entry setFormatter:formCellFormatter]; \
		if([editedTitle isEqualToString:tmp]) editedRow = i; \
		i++; \
    }

- (void)setupForm{
    static NSFont *requiredFont = nil;
    if(!requiredFont){
        requiredFont = [NSFont systemFontOfSize:13.0];
        [[NSFontManager sharedFontManager] convertFont:requiredFont
                                           toHaveTrait:NSBoldFontMask];
    }
    
	// if we were editing in the form, we will restore the selected cell and the selection
	NSResponder *firstResponder = [[self window] firstResponder];
	NSText *fieldEditor = nil;
	NSString *editedTitle = nil;
	int editedRow = -1;
	NSRange selection = NSMakeRange(0, 0);
	if([firstResponder isKindOfClass:[NSText class]] && [[(NSText *)firstResponder delegate] isEqual:bibFields]){
		fieldEditor = (NSText *)firstResponder;
		selection = [fieldEditor selectedRange];
		editedTitle = [(NSFormCell *)[bibFields selectedCell] representedObject];
		forceEndEditing = YES;
		if (![[self window] makeFirstResponder:[self window]])
			[[self window] endEditingFor:nil];
		forceEndEditing = NO;
	}
	
    NSString *tmp;
    NSFormCell *entry;
    NSArray *sKeys;
    int i=0;
    NSRect rect = [bibFields frame];
    NSPoint origin = rect.origin;
	NSEnumerator *e;
	
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSArray *ratingFields = [pw stringArrayForKey:BDSKRatingFieldsKey];
	NSArray *booleanFields = [pw stringArrayForKey:BDSKBooleanFieldsKey];
	NSArray *triStateFields = [pw stringArrayForKey:BDSKTriStateFieldsKey];

	NSMutableSet *ignoredKeys = [[NSMutableSet alloc] initWithObjects: BDSKAnnoteString, BDSKAbstractString, BDSKRssDescriptionString, BDSKDateAddedString, BDSKDateModifiedString, nil];
    [ignoredKeys addObjectsFromArray:ratingFields];
    [ignoredKeys addObjectsFromArray:booleanFields];
    [ignoredKeys addObjectsFromArray:triStateFields];

    NSDictionary *reqAtt = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects:[NSColor redColor],nil]
                                                         forKeys:[NSArray arrayWithObjects:NSForegroundColorAttributeName,nil]];
	
	// set up for adding all items 
    // remove all items in the NSForm
    [bibFields removeAllEntries];

    // make two passes to get the required entries at top.
    i=0;
    sKeys = [[publication allFieldNames] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	
	// now add the entries to the form
	AddFormEntries([[BDSKTypeManager sharedManager] requiredFieldsForType:[publication pubType]], reqAtt);
	AddFormEntries([[BDSKTypeManager sharedManager] optionalFieldsForType:[publication pubType]], nil);
	AddFormEntries(sKeys, nil);
    
    [ignoredKeys release];
    [reqAtt release];
    
    [bibFields sizeToFit];
    
    [bibFields setFrameOrigin:origin];
    [bibFields setNeedsDisplay:YES];
    
	// restore the edited cell and its selection
	if(editedRow != -1){
        OBASSERT(fieldEditor);
        [[self window] makeFirstResponder:bibFields];
        [bibFields selectTextAtRow:editedRow column:0];
        [fieldEditor setSelectedRange:selection];
	}
    
    // align the cite key field with the form cells
    if([bibFields numberOfRows] > 0){
        [bibFields drawRect:NSZeroRect];// this forces the calculation of the titleWidth
        float offset = [[bibFields cellAtIndex:0] titleWidth] + NSMinX([fieldSplitView frame]) + FORM_OFFSET + 4.0;
        NSRect frame = [citeKeyField frame];
        if(offset >= NSMaxX([citeKeyTitle frame]) + 8.0){
            frame.size.width = NSMaxX(frame) - offset;
            frame.origin.x = offset;
            [citeKeyField setFrame:frame];
            [[citeKeyField superview] setNeedsDisplay:YES];
        }
    }
    
	didSetupForm = YES;
    
	[self setupMatrix];
}

#define AddMatrixEntries(fields, cell) \
    e = [fields objectEnumerator]; \
    while(tmp = [e nextObject]){ \
		NSButtonCell *buttonCell = [cell copy]; \
		[buttonCell setTitle:[tmp localizedFieldName]]; \
		[buttonCell setRepresentedObject:tmp]; \
		[buttonCell setIntValue:[publication intValueOfField:tmp]]; \
        cellWidth = fmaxf(cellWidth, [buttonCell cellSize].width); \
        [cells addObject:buttonCell]; \
		[buttonCell release]; \
		if([editedTitle isEqualToString:tmp]) \
			editedIndex = [cells count] - 1; \
    }

- (void)setupMatrix{
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSArray *ratingFields = [pw stringArrayForKey:BDSKRatingFieldsKey];
	NSArray *booleanFields = [pw stringArrayForKey:BDSKBooleanFieldsKey];
	NSArray *triStateFields = [pw stringArrayForKey:BDSKTriStateFieldsKey];
    int numEntries = [ratingFields count] + [booleanFields count] + [triStateFields count];
    
	NSString *editedTitle = nil;
	int editedIndex = -1;
    if([[self window] firstResponder] == extraBibFields)
        editedTitle = [(NSFormCell *)[extraBibFields selectedCell] representedObject];
	
	NSEnumerator *e;
    NSString *tmp;
    NSMutableArray *cells = [NSMutableArray arrayWithCapacity:numEntries];
    float cellWidth = 0.0;
	
	AddMatrixEntries(ratingFields, ratingButtonCell);
	AddMatrixEntries(booleanFields, booleanButtonCell);
	AddMatrixEntries(triStateFields, triStateButtonCell);
	
    NSPoint origin = [extraBibFields frame].origin;
    float width = NSWidth([[extraBibFields enclosingScrollView] frame]) - [NSScroller scrollerWidth];
    float spacing = [extraBibFields intercellSpacing].width;
    int numCols = MIN(floor((width + spacing) / (cellWidth + spacing)), numEntries);
    numCols = MAX(numCols, 1);
    int numRows = (numEntries / numCols) + (numEntries % numCols == 0 ? 0 : 1);
    
    while ([extraBibFields numberOfRows])
		[extraBibFields removeRow:0];
	
    [extraBibFields renewRows:numRows columns:numCols];
    
    e = [cells objectEnumerator];
    NSCell *cell;
    int column = numCols;
    int row = -1;
    while(cell = [e nextObject]){
		if (++column >= numCols) {
			column = 0;
			row++;
		}
		[extraBibFields putCell:cell atRow:row column:column];
    }
    
	[extraBibFields sizeToFit];
    
    [extraBibFields setFrameOrigin:origin];
    [extraBibFields setNeedsDisplay:YES];
	
	// restore the edited cell
	if(editedIndex != -1){
        [[self window] makeFirstResponder:extraBibFields];
        [extraBibFields selectCellAtRow:editedIndex / numCols column:editedIndex % numCols];
	}
}

- (void)matrixFrameDidChange:(NSNotification *)notification {
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    int numEntries = [[typeMan booleanFieldsSet] count] + [[typeMan triStateFieldsSet] count] + [[typeMan ratingFieldsSet] count];
    float width = NSWidth([[extraBibFields enclosingScrollView] frame]) - [NSScroller scrollerWidth];
    float spacing = [extraBibFields intercellSpacing].width;
    float cellWidth = [extraBibFields cellSize].width;
    int numCols = MIN(floor((width + spacing) / (cellWidth + spacing)), numEntries);
    numCols = MAX(numCols, 1);
    if (numCols != [extraBibFields numberOfColumns])
        [self setupMatrix];
}

- (void)setupTypePopUp{
    [bibTypeButton removeAllItems];
    [bibTypeButton addItemsWithTitles:[[BDSKTypeManager sharedManager] bibTypesForFileType:[publication fileType]]];

    [bibTypeButton selectItemWithTitle:[publication pubType]];
}

- (void)registerForNotifications {
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibDidChange:)
												 name:BDSKBibItemChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(needsToBeFiledDidChange:)
												 name:BDSKNeedsToBeFiledChangedNotification
											   object:publication];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWasAddedOrRemoved:)
												 name:BDSKDocAddItemNotification
											   object:[self document]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWasAddedOrRemoved:)
												 name:BDSKDocDelItemNotification
											   object:[self document]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWillBeRemoved:)
												 name:BDSKDocWillRemoveItemNotification
											   object:[self document]];
    if(isEditable == NO)
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(groupWillBeRemoved:)
                                                     name:BDSKDidAddRemoveGroupNotification
                                                   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(finalizeChanges:)
												 name:BDSKFinalizeChangesNotification
											   object:[self document]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(fileURLDidChange:)
												 name:BDSKDocumentFileURLDidChangeNotification
											   object:[self document]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(typeInfoDidChange:)
												 name:BDSKBibTypeInfoChangedNotification
											   object:[BDSKTypeManager sharedManager]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(customFieldsDidChange:)
												 name:BDSKCustomFieldsChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(macrosDidChange:)
												 name:BDSKMacroDefinitionChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(matrixFrameDidChange:)
												 name:NSViewFrameDidChangeNotification
											   object:[extraBibFields enclosingScrollView]];
}


- (void)breakTextStorageConnections {
    
    // This is a fix for bug #1483613 (and others).  We set some of the BibItem's fields to -[[NSTextView textStorage] mutableString] for efficiency in tracking changes for live editing updates in the main window preview.  However, this causes a retain cycle, as the text storage retains its text view; any font changes to the editor text view will cause the retained textview to message its delegate (BibEditor) which is garbage in -[NSTextView _addToTypingAttributes].
    NSEnumerator *fieldE = [[[BDSKTypeManager sharedManager] noteFieldsSet] objectEnumerator];
    NSString *currentValue = nil;
    NSString *fieldName = nil;
    while(fieldName = [fieldE nextObject]){
        currentValue = [[publication valueOfField:fieldName inherit:NO] copy];
        // set without undo, or we dirty the document every time the editor is closed
        if(nil != currentValue)
            [publication setField:fieldName toValueWithoutUndo:currentValue];
        [currentValue release];
    }
}

@end


@implementation BDSKTabView

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent{
    NSEventType type = [theEvent type];
    // workaround for an NSForm bug: when selecting a button in a modal dialog after committing an edit it can try a keyEquivalent with the mouseUp event
    if (type != NSKeyDown && type != NSKeyUp)
        return NO;
    unichar c = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
    unsigned int flags = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    
    if((c == NSRightArrowFunctionKey || c == NSDownArrowFunctionKey) && (flags & NSCommandKeyMask) && (flags & NSAlternateKeyMask)){
        if([self indexOfTabViewItem:[self selectedTabViewItem]] == [self numberOfTabViewItems] - 1)
            [self selectFirstTabViewItem:nil];
        else
            [self selectNextTabViewItem:nil];
        return YES;
    }else if((c == NSLeftArrowFunctionKey || c == NSUpArrowFunctionKey)  && (flags & NSCommandKeyMask) && (flags & NSAlternateKeyMask)){
        if([self indexOfTabViewItem:[self selectedTabViewItem]] == 0)
            [self selectLastTabViewItem:nil];
        else
            [self selectPreviousTabViewItem:nil];
        return YES;
    }else if(c - '1' >= 0 && c - '1' < [self numberOfTabViewItems] && flags == NSCommandKeyMask){
        [self selectTabViewItemAtIndex:c - '1'];
        return YES;
    }
    return [super performKeyEquivalent:theEvent];
}

@end
