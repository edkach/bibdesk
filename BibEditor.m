//  BibEditor.m

//  Created by Michael McCracken on Mon Dec 24 2001.
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


#import "BibEditor.h"
#import "BibEditor_Toolbar.h"
#import "BibDocument.h"
#import "BDAlias.h"
#import "NSImage+Toolbox.h"
#import "BDSKComplexString.h"
#import "BDSKScriptHookManager.h"
#import "BDSKZoomablePDFView.h"
#import "BDSKEdgeView.h"
#import "KFAppleScriptHandlerAdditionsCore.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKAlert.h"
#import "BDSKFieldSheetController.h"
#import "BibFiler.h"

#import "BibItem.h"
#import "BDSKCiteKeyFormatter.h"
#import "BDSKFieldNameFormatter.h"
#import "BDSKComplexStringFormatter.h"
#import "BDSKCrossrefFormatter.h"
#import "BibAppController.h"
#import "PDFImageView.h"
#import "BDSKImagePopUpButton.h"
#import "BDSKRatingButton.h"
#import "MacroTextFieldWindowController.h"
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

// this is a PDFDocument method; we can't link with it because the framework doesn't exist on pre-10.4 systems
@interface NSObject (PantherCompatibilityKludge)
- (id)initWithPostScriptData:(NSData *)data;
@end

@interface BibEditor (Private)

- (void)setupDrawer;
- (void)setupButtons;
- (void)setupForm;
- (void)setupTypePopUp;
- (void)registerForNotifications;
- (void)fixURLs;
- (void)breakTextStorageConnections;

@end

@implementation BibEditor

static int numberOfOpenEditors = 0;

- (NSString *)windowNibName{
    return @"BibEditor";
}

- (NSString *)representedFilename{
    NSString *fname = [theBib localUrlPath];
    return fname ? fname : @"";
}

- (id)initWithBibItem:(BibItem *)aBib document:(BibDocument *)doc{
    self = [super initWithWindowNibName:@"BibEditor"];
    
    numberOfOpenEditors++;
    
    fieldNumbers = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
    citeKeyFormatter = [[BDSKCiteKeyFormatter alloc] init];
    fieldNameFormatter = [[BDSKFieldNameFormatter alloc] init];
    formCellFormatter = [[BDSKComplexStringFormatter alloc] initWithDelegate:self macroResolver:[doc macroResolver]];
    crossrefFormatter = [[BDSKCrossrefFormatter alloc] init];
	
    theBib = aBib;
    currentType = [[theBib pubType] retain];    // do this once in init so it's right at the start.
                                    // has to be before we call [self window] because that calls windowDidLoad:.
    theDocument = doc; // don't retain - it retains us.
	pdfSnoopViewLoaded = NO;
	webSnoopViewLoaded = NO;
	drawerState = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKSnoopDrawerContentKey] | BDSKDrawerStateRightMask;
	drawerButtonState = BDSKDrawerUnknownState;
	
	windowLoaded = NO;
	drawerLoaded = NO;
	
	forceEndEditing = NO;
    didSetupForm = NO;
	
    macroTextFieldWC = [[MacroFormWindowController alloc] init];
    
    notesViewUndoManager = [[NSUndoManager alloc] init];
    abstractViewUndoManager = [[NSUndoManager alloc] init];
    rssDescriptionViewUndoManager = [[NSUndoManager alloc] init];

#if DEBUG
    NSLog(@"BibEditor alloc");
#endif
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
    [[self window] setDelegate:self];
    [[self window] registerForDraggedTypes:[NSArray arrayWithObjects:BDSKBibItemPboardType, NSStringPboardType, nil]];					
	[self setCiteKeyDuplicateWarning:![theBib isValidCiteKey:[theBib citeKey]]];
    [documentSnoopButton setIconImage:nil];
    [self fixURLs];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    return [theBib displayTitle];
}

- (BibItem *)currentBib{
    return theBib;
}

- (void)awakeFromNib{
	
	if (windowLoaded == YES) {
		// we must be loading the drawer
		[self setupDrawer];
		return;
	}
	
	// The rest is called when we load the window
	
    // Setup the default cells for the extraBibFields matrix
	booleanButtonCell = [[NSButtonCell alloc] initTextCell:@""];
	[booleanButtonCell setButtonType:NSSwitchButton];
	[booleanButtonCell setTarget:self];
	[booleanButtonCell setAction:@selector(changeFlag:)];
	
	triStateButtonCell = [booleanButtonCell copy];
	[triStateButtonCell setAllowsMixedState:YES];
	
	ratingButtonCell = [[BDSKRatingButtonCell alloc] initWithMaxRating:5];
	[ratingButtonCell setImagePosition:NSImageLeft];
	[ratingButtonCell setTarget:self];
	[ratingButtonCell setAction:@selector(changeRating:)];
	
	NSCell *cell = [[NSCell alloc] initTextCell:@""];
	[extraBibFields setPrototype:cell];
	[cell release];
    
    // Setup the toolbar
    [self setupToolbar];
	
    // Setup the statusbar
	[statusBar retain]; // we need to retain, as we might remove it from the window
	if (![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShowEditorStatusBarKey]) {
		[self toggleStatusBar:nil];
	}
	[statusBar setDelegate:self];
    [statusBar setTextOffset:NSMaxX([actionButton frame])];
    
    // Set the frame from prefs first, or setFrameAutosaveName: will overwrite the prefs with the nib values if it returns NO
    [[self window] setFrameUsingName:BDSKBibEditorFrameAutosaveName];
    // we should only cascade windows if we have multiple editors open; bug #1299305
    // the default cascading does not reset the next location when all windows have closed, so we do cascading ourselves
    static NSPoint nextWindowLocation = {0.0, 0.0};
    [self setShouldCascadeWindows:NO];
    if ([[self window] setFrameAutosaveName:BDSKBibEditorFrameAutosaveName]) {
        NSRect windowFrame = [[self window] frame];
        nextWindowLocation = NSMakePoint(NSMinX(windowFrame), NSMaxY(windowFrame));
    }
    nextWindowLocation = [[self window] cascadeTopLeftFromPoint:nextWindowLocation];
    
    // Setup the splitview autosave frame, should be done after the statusBar is setup
    [splitView setPositionAutosaveName:@"OASplitView Position BibEditor"];
    
    // Setup the form and the matrix
	BDSKEdgeView *edgeView = (BDSKEdgeView *)[[splitView subviews] objectAtIndex:0];
	[edgeView setEdges:BDSKMinYEdgeMask];
    NSRect ignored, frame = [edgeView contentRect];
    NSDivideRect([edgeView contentRect], &ignored, &frame, FORM_OFFSET, NSMinXEdge);
    [[bibFields enclosingScrollView] setFrame:frame];
	[edgeView addSubview:[bibFields enclosingScrollView]];
    // don't know why, but this is broken
    [bibTypeButton setNextKeyView:bibFields];
    
    edgeView = (BDSKEdgeView *)[[splitView subviews] objectAtIndex:1];
	[edgeView setEdges:BDSKMinYEdgeMask | BDSKMaxYEdgeMask];
    NSDivideRect([edgeView contentRect], &ignored, &frame, FORM_OFFSET, NSMinXEdge);
    [[extraBibFields enclosingScrollView] setFrame:frame];
	[edgeView addSubview:[extraBibFields enclosingScrollView]];

    [self setupForm];
    [bibFields registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, BDSKWeblocFilePboardType, nil]];
    
    // Setup the citekey textfield
    [citeKeyField setFormatter:citeKeyFormatter];
	[citeKeyField setStringValue:[theBib citeKey]];
	
    // Setup the type popup
    [self setupTypePopUp];
    
	// Setup the toolbar buttons.
    // The popupbutton needs to be set before fixURLs is called, and -windowDidLoad gets sent after awakeFromNib.
    [self setupButtons];

	[authorTableView setDoubleAction:@selector(showPersonDetailCmd:)];
    
    // Setup the textviews
    [notesView setString:[theBib valueOfField:BDSKAnnoteString inherit:NO]];
    [abstractView setString:[theBib valueOfField:BDSKAbstractString inherit:NO]];
    [rssDescriptionView setString:[theBib valueOfField:BDSKRssDescriptionString inherit:NO]];
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
	
	windowLoaded = YES;
    
    [self registerForNotifications];
    
    [bibFields setDelegate:self];
    
}

- (void)dealloc{
#if DEBUG
    NSLog(@"BibEditor dealloc");
#endif
    // release theBib? no...
    numberOfOpenEditors--;
	[authorTableView setDelegate:nil];
    [authorTableView setDataSource:nil];
    [notesViewUndoManager release];
    [abstractViewUndoManager release];
    [rssDescriptionViewUndoManager release];   
    [booleanButtonCell release];
    [triStateButtonCell release];
    [ratingButtonCell release];
    [currentType release];
    [citeKeyFormatter release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [fieldNumbers release];
    [fieldNameFormatter release];
	[dragFieldEditor release];
	[viewLocalToolbarItem release];
	[viewRemoteToolbarItem release];
	[documentSnoopToolbarItem release];
	[authorsToolbarItem release];
	[statusBar release];
	[toolbarItems release];
	[macroTextFieldWC release];
	[documentSnoopDrawer release];
	[pdfSnoopContainerView release];
	[textSnoopContainerView release];
	[webSnoopContainerView release];
    [formCellFormatter release];
    [crossrefFormatter release];
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
	[statusBar toggleBelowView:[tabView superview] offset:1.0];
	[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:[statusBar isVisible] forKey:BDSKShowEditorStatusBarKey];
}

- (IBAction)revealLinkedFile:(id)sender{
	NSString *field = [sender representedObject];
    if (field == nil)
		field = BDSKLocalUrlString;
    NSWorkspace *sw = [NSWorkspace sharedWorkspace];
	NSString *path = [theBib localFilePathForField:field];
	[sw selectFile:path inFileViewerRootedAtPath:nil];
}

- (IBAction)openLinkedFile:(id)sender{
    NSWorkspace *sw = [NSWorkspace sharedWorkspace];
	NSString *field = [sender representedObject];
    if (field == nil)
		field = BDSKLocalUrlString;
	
    BOOL err = NO;

    if(![sw openFile:[theBib localFilePathForField:field]]){
            err = YES;
    }
    if(err)
        NSBeginAlertSheet(NSLocalizedString(@"Can't Open Local File", @"can't open local file"),
                              NSLocalizedString(@"OK", @"OK"),
                              nil,nil, [self window],self, NULL, NULL, NULL,
                              NSLocalizedString(@"Sorry, the contents of the Local-Url Field are neither a valid file path nor a valid URL.",
                                                @"explanation of why the local-url failed to open"), nil);

}

- (IBAction)moveLinkedFile:(id)sender{
    NSString *field = [sender representedObject];
    if (field == nil)
		field = BDSKLocalUrlString;
    
    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setPrompt:NSLocalizedString(@"Move", @"Move file")];
    [sPanel setNameFieldLabel:NSLocalizedString(@"Move To:", @"Move To: label")];
    [sPanel setDirectory:[[theBib localFilePathForField:field] stringByDeletingLastPathComponent]];
	
    [sPanel beginSheetForDirectory:nil 
                              file:nil 
                    modalForWindow:[self window] 
                     modalDelegate:self 
                    didEndSelector:@selector(moveLinkedFilePanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:[field retain]];
}

- (void)moveLinkedFilePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSString *field = (NSString *)contextInfo;

    if(returnCode == NSOKButton){
        NSString *oldPath = [theBib localFilePathForField:field];
        NSString *newPath = [sheet filename];
        if([NSString isEmptyString:oldPath] == NO){
            NSArray *paperInfos = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:theBib, @"paper", oldPath, @"oldPath", newPath, @"newPath", nil]];
            
            [theBib setField:field toValue:[[NSURL fileURLWithPath:newPath] absoluteString]];
            [[BibFiler sharedFiler] movePapers:paperInfos forField:field fromDocument:theDocument options:0];
            
            [[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
		}
    }
    
    [field release];
}

- (IBAction)openRemoteURL:(id)sender{
	NSString *field = [sender representedObject];
	if (field == nil)
		field = BDSKUrlString;
    NSWorkspace *sw = [NSWorkspace sharedWorkspace];
    NSURL *url = [theBib remoteURLForField:field];
    if(url == nil){
        NSString *rurl = [theBib valueOfField:field];
        
        if([rurl isEqualToString:@""])
            return;
    
        if([rurl rangeOfString:@"://"].location == NSNotFound)
            rurl = [@"http://" stringByAppendingString:rurl];

        url = [NSURL URLWithString:rurl];
    }
    
    if(url != nil)
        [sw openURL:url];
    else
        NSBeginAlertSheet(NSLocalizedString(@"Error!", @"Error!"),
                          nil, nil, nil, [self window], nil, nil, nil, nil,
                          NSLocalizedString(@"Mac OS X does not recognize this as a valid URL.  Please check the URL field and try again.",
                                            @"Unrecognized URL, edit it and try again.") );
    
}

#pragma mark Menus

- (void)menuNeedsUpdate:(NSMenu *)menu{
    NSString *menuTitle = [menu title];
	if (menu == [[viewLocalToolbarItem menuFormRepresentation] submenu]) {
        [self updateMenu:menu forImagePopUpButton:viewLocalButton];
	} else if (menu == [[viewRemoteToolbarItem menuFormRepresentation] submenu]) {
        [self updateMenu:menu forImagePopUpButton:viewRemoteButton];
	} else if (menu == [[documentSnoopToolbarItem menuFormRepresentation] submenu]) {
        [self updateMenu:menu forImagePopUpButton:documentSnoopButton];
	} else if (menu == [[authorsToolbarItem menuFormRepresentation] submenu]) {
        [self updateAuthorsToolbarMenu:menu];
	} else if([menuTitle isEqualToString:@"previewRecentDocumentsMenu"]){
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

- (NSMenu *)menuForImagePopUpButton:(BDSKImagePopUpButton *)view{
	NSMenu *menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
    [self updateMenu:menu forImagePopUpButton:view];
    return [menu autorelease];
}

- (void)updateMenu:(NSMenu *)menu forImagePopUpButton:(BDSKImagePopUpButton *)view{
	NSMenu *submenu;
	NSMenuItem *item;
	NSURL *theURL;
    
    int i = [menu numberOfItems];
    while (i-- > 1)
        [menu removeItemAtIndex:i];
    
	if (view == viewLocalButton) {
		NSEnumerator *e = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey] objectEnumerator];
		NSString *field = nil;
		
		// the first one has to be view Local-Url file, since it's also the button's action when you're clicking on the icon.
        int idx = 0;
		while (field = [e nextObject]) {
            
            if(idx++ > 0)
                [menu addItem:[NSMenuItem separatorItem]];

            item = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Open %@",@"Open Local-Url file"), field]
                                   action:@selector(openLinkedFile:)
                            keyEquivalent:@""];
            [item setTarget:self];
            [item setRepresentedObject:field];
            
            theURL = [theBib URLForField:field];
            if(nil != theURL){
                [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Open %@ With",@"Open Local-Url file"), field]
                        andSubmenuOfApplicationsForURL:theURL];
            }
            
			item = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Reveal %@ in Finder",@"Reveal Local-Url in finder"), field]
                                   action:@selector(revealLinkedFile:)
                            keyEquivalent:@""];
			[item setRepresentedObject:field];
            
			item = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Move %@%C",@"Move Local-Url..."), field, 0x2026]
                                   action:@selector(moveLinkedFile:)
                            keyEquivalent:@""];
			[item setRepresentedObject:field];
		}
		
		[menu addItem:[NSMenuItem separatorItem]];
		
		[menu addItemWithTitle:[NSString stringWithFormat:@"%@%C",NSLocalizedString(@"Choose File",@"Choose File..."),0x2026]
						action:@selector(chooseLocalURL:)
				 keyEquivalent:@""];
		
		// get Safari recent downloads
        item = [menu addItemWithTitle:NSLocalizedString(@"Safari Recent Downloads",@"Link to Download URL")
                         submenuTitle:@"safariRecentDownloadsMenu"
                      submenuDelegate:self];

        // get recent downloads (Tiger only) by searching the system downloads directory
        // should work for browsers other than Safari, if they use IC to get/set the download directory
        // don't create this in the delegate method; it needs to start working in the background
        if(submenu = [self recentDownloadsMenu]){
            item = [menu addItemWithTitle:NSLocalizedString(@"Link to Recent Download", @"") submenu:submenu];
        }
		
		// get Preview recent documents
        [menu addItemWithTitle:NSLocalizedString(@"Link to Recently Opened File",@"Link to Recently Opened or Modified File")
                  submenuTitle:@"previewRecentDocumentsMenu"
               submenuDelegate:self];
	}
	else if (view == viewRemoteButton) {
		NSEnumerator *e = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey] objectEnumerator];
		NSString *field = nil;
		
		// the first one has to be view Url in web brower, since it's also the button's action when you're clicking on the icon.
		while (field = [e nextObject]) {
			item = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"View %@ in Web Browser",@"View Url in web browser"), field]
                                   action:@selector(openRemoteURL:)
                            keyEquivalent:@""];
			[item setRepresentedObject:field];
            
            theURL = [theBib URLForField:field];
            if(nil != theURL){
                [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"View %@ With",@"Open URL"), field]
                        andSubmenuOfApplicationsForURL:theURL];
            }
		}
		
		// get Safari recent URLs
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:NSLocalizedString(@"Link to Download URL",@"Link to Download URL")
                  submenuTitle:@"safariRecentURLsMenu"
               submenuDelegate:self];
	}
	else if (view == documentSnoopButton) {
		
		item = [menu addItemWithTitle:NSLocalizedString(@"View File in Drawer",@"View file in drawer")
                               action:@selector(toggleSnoopDrawer:)
                        keyEquivalent:@""];
		[item setTag:0];
		
		item = [menu addItemWithTitle:NSLocalizedString(@"View File as Text in Drawer",@"View file as text in drawer")
                               action:@selector(toggleSnoopDrawer:)
                        keyEquivalent:@""];
		[item setTag:BDSKDrawerStateTextMask];
		
		item = [menu addItemWithTitle:NSLocalizedString(@"View Remote URL in Drawer",@"View remote URL in drawer")
                               action:@selector(toggleSnoopDrawer:)
                        keyEquivalent:@""];
		[item setTag:BDSKDrawerStateWebMask];
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
		
	int i = 0;
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
			NSString *fileName = [filePath lastPathComponent];
			NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:filePath];
			[image setSize: NSMakeSize(16, 16)];
			
			NSMenuItem *item = [menu addItemWithTitle:fileName
                                               action:@selector(setLocalURLPathFromMenuItem:)
                                        keyEquivalent:@""];
			[item setRepresentedObject:filePath];
			[item setImage:image];
		}
	}
    
    if (numberOfItems == 0) {
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Downloads",@"") action:NULL keyEquivalent:@""];
    }
}


- (void)updateSafariRecentURLsMenu:(NSMenu *)menu{
	NSArray *historyArray = [self safariDownloadHistory];
	unsigned numberOfItems = [historyArray count];
	int i = 0;
    
    [menu removeAllItems];
	
	for (i = 0; i < numberOfItems; i ++){
		NSDictionary *itemDict = [historyArray objectAtIndex:i];
		NSString *URLString = [itemDict objectForKey:@"DownloadEntryURL"];
		if (![NSString isEmptyString:URLString] && [NSURL URLWithString:URLString]) {
			NSImage *image = [NSImage smallGenericInternetLocationImage];
			[image setSize: NSMakeSize(16, 16)];
			
			NSMenuItem *item = [menu addItemWithTitle:URLString
                                               action:@selector(setRemoteURLFromMenuItem:)
                                        keyEquivalent:@""];
			[item setRepresentedObject:URLString];
			[item setImage:image];
		}
	}
    
    if (numberOfItems == 0) {
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Downloads",@"") action:NULL keyEquivalent:@""];
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
	
	int i = 0;
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
    NSImage *image;
    NSMenuItem *item;
    
    [menu removeAllItems];

    // now add all of the items from Preview, which are most likely what we want
    e = [previewRecentPaths objectEnumerator];
    while(filePath = [e nextObject]){
        if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            fileName = [filePath lastPathComponent];
            image = [NSImage smallImageForFile:filePath];
            
            item = [menu addItemWithTitle:fileName
                                   action:@selector(setLocalURLPathFromMenuItem:)
                            keyEquivalent:@""];
            [item setRepresentedObject:filePath];
            [item setImage:image];
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
            image = [NSImage smallImageForFile:filePath];
            
            item = [menu addItemWithTitle:fileName
                                   action:@selector(setLocalURLPathFromMenuItem:)
                            keyEquivalent:@""];
            [item setRepresentedObject:filePath];
            [item setImage:image];
        }
    }  
    
    if ([globalRecentPaths count] == 0) {
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Documents",@"") action:NULL keyEquivalent:@""];
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
    
    NSArray *paths = nil;
    
    // this should always return nil on OS versions < 10.4
    if(nil != [BDSKPersistentSearch sharedSearch]){
        
        // this was copied verbatim from a Finder saved search for all documents modified in the last week
        NSString *query = @"(kMDItemContentTypeTree = 'public.content') && (kMDItemFSContentChangeDate >= $time.today(-7)) && (kMDItemContentType != com.apple.mail.emlx) && (kMDItemContentType != public.vcard)";
        
        // limit the scope to the default downloads directory (from Internet Config)
        [[BDSKPersistentSearch sharedSearch] addQuery:query scopes:[NSArray arrayWithObject:[[NSFileManager defaultManager] internetConfigDownloadURL]]];
        paths = [[BDSKPersistentSearch sharedSearch] resultsForQuery:query attribute:(NSString *)kMDItemPath];
    }
    
    NSEnumerator *e = [paths objectEnumerator];
    
    NSString *filePath;
    NSImage *image;
    NSMenuItem *item;
    
    [menu removeAllItems];
    
    while(filePath = [e nextObject]){
        image = [NSImage smallImageForFile:filePath];
        
        item = [menu addItemWithTitle:[filePath lastPathComponent]
                               action:@selector(setLocalURLPathFromMenuItem:)
                        keyEquivalent:@""];
        [item setRepresentedObject:filePath];
        [item setImage:image];
    }
}

- (void)updateAuthorsToolbarMenu:(NSMenu *)menu{
    NSArray *thePeople = [theBib sortedPeople];
    int count = [thePeople count];
    int i = [menu numberOfItems];
    BibAuthor *person;
    NSMenuItem *item;
    while (i-- > 1)
        [menu removeItemAtIndex:i];
    if (count == 0)
        return;
    for (i = 0; i < count; i++) {
        person = [thePeople objectAtIndex:i];
        item = [menu addItemWithTitle:[person normalizedName] action:@selector(showPersonDetailCmd:) keyEquivalent:@""];
        [item setTag:i];
    }
    item = [menu addItemWithTitle:NSLocalizedString(@"Show All", @"Show all") action:@selector(showPersonDetailCmd:) keyEquivalent:@""];
    [item setTag:count];
}

- (void)dummy:(id)obj{}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem{
    
    SEL theAction = [menuItem action];
    
	if (theAction == nil ||
		theAction == @selector(dummy:)){ // Unused selector for disabled items. Needed to avoid the popupbutton to insert its own
		return NO;
	}
	else if (theAction == @selector(generateCiteKey:)) {
		// need to set the title, as the document can change it in the main menu
		[menuItem setTitle: NSLocalizedString(@"Generate Cite Key", @"Generate Cite Key")];
		return YES;
	}
	else if (theAction == @selector(consolidateLinkedFiles:)) {
		[menuItem setTitle: NSLocalizedString(@"Consolidate Linked File", @"Consolidate Linked File")];
		NSString *lurl = [theBib localUrlPath];
		return (lurl && [[NSFileManager defaultManager] fileExistsAtPath:lurl]);
	}
	else if (theAction == @selector(duplicateTitleToBooktitle:)) {
		// need to set the title, as the document can change it in the main menu
		[menuItem setTitle: NSLocalizedString(@"Duplicate Title to Booktitle", @"Duplicate Title to Booktitle")];
		return (![NSString isEmptyString:[theBib valueOfField:BDSKTitleString]]);
	}
	else if (theAction == @selector(selectCrossrefParentAction:)) {
        return ([NSString isEmptyString:[theBib valueOfField:BDSKCrossrefString inherit:NO]] == NO);
	}
	else if (theAction == @selector(createNewPubUsingCrossrefAction:)) {
        return ([NSString isEmptyString:[theBib valueOfField:BDSKCrossrefString inherit:NO]] == YES);
	}
	else if (theAction == @selector(openLinkedFile:)) {
		NSString *field = (NSString *)[menuItem representedObject];
		if (field == nil)
			field = BDSKLocalUrlString;
		NSURL *lurl = [[theBib URLForField:field] fileURLByResolvingAliases];
		if ([[menuItem menu] supermenu])
			[menuItem setTitle:NSLocalizedString(@"Open Linked File", @"Open Linked File")];
		return (lurl == nil ? NO : YES);
	}
	else if (theAction == @selector(revealLinkedFile:)) {
		NSString *field = (NSString *)[menuItem representedObject];
		if (field == nil)
			field = BDSKLocalUrlString;
		NSURL *lurl = [[theBib URLForField:field] fileURLByResolvingAliases];
		if ([[menuItem menu] supermenu])
			[menuItem setTitle:NSLocalizedString(@"Reveal Linked File in Finder", @"Reveal Linked File in Finder")];
		return (lurl == nil ? NO : YES);
	}
	else if (theAction == @selector(moveLinkedFile:)) {
		NSString *field = (NSString *)[menuItem representedObject];
		if (field == nil)
			field = BDSKLocalUrlString;
		NSURL *lurl = [[theBib URLForField:field] fileURLByResolvingAliases];
		if ([[menuItem menu] supermenu])
			[menuItem setTitle:NSLocalizedString(@"Move Linked File", @"Move Linked File")];
		return (lurl == nil ? NO : YES);
	}
	else if (theAction == @selector(toggleSnoopDrawer:)) {
		int requiredContent = [menuItem tag];
		int currentContent = drawerState & (BDSKDrawerStateTextMask | BDSKDrawerStateWebMask);
		BOOL isCloseItem = ((currentContent == requiredContent) && (drawerState & BDSKDrawerStateOpenMask));
		if (isCloseItem) {
			[menuItem setTitle:NSLocalizedString(@"Close Drawer", @"Close drawer")];
		} else if (requiredContent & BDSKDrawerStateWebMask) {
			[menuItem setTitle:NSLocalizedString(@"View Remote URL in Drawer", @"View remote URL in drawer")];
		} else if (requiredContent & BDSKDrawerStateTextMask) {
			[menuItem setTitle:NSLocalizedString(@"View File as Text in Drawer", @"View file as text in drawer")];
		} else {
			[menuItem setTitle:NSLocalizedString(@"View File in Drawer", @"View file in drawer")];
		}
		if (isCloseItem) {
			// always enable the close item
			return YES;
		} else if (requiredContent & BDSKDrawerStateWebMask) {
			return ([theBib remoteURL] != nil);
		} else {
            NSURL *lurl = [[theBib URLForField:BDSKLocalUrlString] fileURLByResolvingAliases];
            return (lurl == nil ? NO : YES);
		}
	}
	else if (theAction == @selector(openRemoteURL:)) {
		NSString *field = (NSString *)[menuItem representedObject];
		if (field == nil)
			field = BDSKUrlString;
		if ([[menuItem menu] supermenu])
			[menuItem setTitle:NSLocalizedString(@"Open URL in Browser", @"Open URL in Browser")];
		return ([theBib remoteURLForField:field] != nil);
	}
	else if (theAction == @selector(saveFileAsLocalUrl:)) {
		return ![[[remoteSnoopWebView mainFrame] dataSource] isLoading];
	}
	else if (theAction == @selector(downloadLinkedFileAsLocalUrl:)) {
		return NO;
	}
    else if (theAction == @selector(editSelectedFieldAsRawBibTeX:)) {
        id cell = [bibFields selectedCell];
		return (cell != nil && [bibFields currentEditor] != nil &&
				![macroTextFieldWC isEditing] && ![[cell title] isEqualToString:BDSKCrossrefString]);
    }
    else if (theAction == @selector(toggleStatusBar:)) {
		if ([statusBar isVisible]) {
			[menuItem setTitle:NSLocalizedString(@"Hide Status Bar", @"Hide Status Bar")];
		} else {
			[menuItem setTitle:NSLocalizedString(@"Show Status Bar", @"Show Status Bar")];
		}
		return YES;
    }
	return YES;
}

#pragma mark Cite Key handling methods

- (IBAction)showCiteKeyWarning:(id)sender{
    NSBeginAlertSheet(NSLocalizedString(@"Duplicate Cite Key", @""),nil,nil,nil,[self window],nil,NULL,NULL,NULL,NSLocalizedString(@"The citation key you entered is either already used in this document or is empty. Please provide a unique one.",@""));
}

- (IBAction)citeKeyDidChange:(id)sender{
    NSString *newKey = [sender stringValue];
	NSString *oldKey = [theBib citeKey];
	
   	if(![newKey isEqualToString:oldKey]){
		[theBib setCiteKey:newKey];
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Change Cite Key",@"")];
		
		// autofile paper if we have enough information
		if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey] &&
			 [theBib needsToBeFiled] && [theBib canSetLocalUrl] ) {
			[[BibFiler sharedFiler] filePapers:[NSArray arrayWithObject:theBib] fromDocument:[theBib document] check:NO];
			[theBib setNeedsToBeFiled:NO]; // unset the flag even when we fail, to avoid retrying at every edit
			[self setStatus:NSLocalizedString(@"Autofiled linked file.",@"Autofiled linked file.")];
		}

		// still need to check duplicates ourselves:
		if(![theBib isValidCiteKey:newKey]){
			[self setCiteKeyDuplicateWarning:YES];
		}else{
			[self setCiteKeyDuplicateWarning:NO];
		}
		
		BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
		if (scriptHook) {
			[scriptHook setField:BDSKCiteKeyString];
			[scriptHook setOldValues:[NSArray arrayWithObject:oldKey]];
			[scriptHook setNewValues:[NSArray arrayWithObject:newKey]];
			[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
		}
		
	}
}

- (void)setCiteKeyDuplicateWarning:(BOOL)set{
	if(set){
		[citeKeyWarningButton setImage:[NSImage cautionIconImage]];
		[citeKeyWarningButton setToolTip:NSLocalizedString(@"This cite-key is a duplicate",@"")];
	}else{
		[citeKeyWarningButton setImage:nil];
		[citeKeyWarningButton setToolTip:nil];
	}
	[citeKeyWarningButton setEnabled:set];
	[citeKeyField setTextColor:(set ? [NSColor redColor] : [NSColor blackColor])];
}

- (IBAction)generateCiteKey:(id)sender{
	[self finalizeChangesPreservingSelection:YES];
	
	BDSKScriptHook *scriptHook = nil;
	NSString *oldKey = [theBib citeKey];
	NSString *newKey = [theBib suggestedCiteKey];
	
	scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKWillGenerateCiteKeyScriptHookName];
	if (scriptHook) {
		[scriptHook setField:BDSKCiteKeyString];
		[scriptHook setOldValues:[NSArray arrayWithObject:oldKey]];
		[scriptHook setNewValues:[NSArray arrayWithObject:newKey]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
	}
	
	// get them again, as the script hook might have changed some values
	oldKey = [theBib citeKey];
	newKey = [theBib suggestedCiteKey];
    
    NSString *crossref = [theBib valueOfField:BDSKCrossrefString inherit:NO];
    if (crossref != nil && [crossref caseInsensitiveCompare:newKey] == NSOrderedSame) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Could not generate cite key",@"Could not generate cite key") 
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The cite key for \"%@\" could not be generated because the generated key would be the same as the crossref key.", @""), oldKey];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:NULL];
        return;
    }
	[theBib setCiteKey:newKey];
	
	scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKDidGenerateCiteKeyScriptHookName];
	if (scriptHook) {
		[scriptHook setField:BDSKCiteKeyString];
		[scriptHook setOldValues:[NSArray arrayWithObject:oldKey]];
		[scriptHook setNewValues:[NSArray arrayWithObject:newKey]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
	}
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Generate Cite Key",@"")];
	[tabView selectFirstTabViewItem:self];
}

- (void)consolidateAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertAlternateReturn){
        return;
    }else if(returnCode == NSAlertOtherReturn){
        [theBib setNeedsToBeFiled:YES];
        return;
    }
    
	[[BibFiler sharedFiler] filePapers:[NSArray arrayWithObject:theBib] fromDocument:[theBib document] check:NO];
	
	[tabView selectFirstTabViewItem:self];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Move File",@"")];
}

- (IBAction)consolidateLinkedFiles:(id)sender{
	[self finalizeChangesPreservingSelection:YES];
	
	if (![theBib canSetLocalUrl]){
		NSString *message = NSLocalizedString(@"Not all fields needed for generating the file location are set.  Do you want me to file the paper now using the available fields, or cancel autofile for this paper?",@"");
		NSString *otherButton = nil;
		if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
			message = NSLocalizedString(@"Not all fields needed for generating the file location are set. Do you want me to file the paper now using the available fields, cancel autofile for this paper, or wait until the necessary fields are set?",@""),
			otherButton = NSLocalizedString(@"Wait",@"Wait");
		}
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning",@"Warning") 
                                         defaultButton:NSLocalizedString(@"File Now",@"File without waiting")
                                       alternateButton:NSLocalizedString(@"Cancel",@"Cancel")
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
	
	[theBib duplicateTitleToBooktitleOverwriting:YES];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Duplicate Title",@"")];
}

- (IBAction)bibTypeDidChange:(id)sender{
    if (![[self window] makeFirstResponder:[self window]]){
        [[self window] endEditingFor:nil];
    }
    [self setCurrentType:[bibTypeButton titleOfSelectedItem]];
    if(![[theBib pubType] isEqualToString:currentType]){
        [theBib setPubType:currentType];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:currentType
                                                           forKey:BDSKPubTypeStringKey];
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Change Type",@"")];
    }
}

- (void)updateTypePopup{ // used to update UI after dragging into the editor
    [bibTypeButton selectItemWithTitle:[theBib pubType]];
}

- (void)setCurrentType:(NSString *)type{
    [currentType release];
    currentType = [type retain];
}

- (IBAction)changeRating:(id)sender{
	BDSKRatingButtonCell *cell = [sender selectedCell];
	NSString *field = [cell title];
	int oldRating = [theBib ratingValueOfField:field];
	int newRating = [cell rating];
		
	if(newRating != oldRating) {
		[theBib setField:field toRatingValue:newRating];
		
		BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
		if (scriptHook) {
			[scriptHook setField:field];
			[scriptHook setOldValues:[NSArray arrayWithObject:[NSString stringWithFormat:@"%i", oldRating]]];
			[scriptHook setNewValues:[NSArray arrayWithObject:[NSString stringWithFormat:@"%i", newRating]]];
			[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
		}
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Change Rating",@"")];
	}
}

- (IBAction)changeFlag:(id)sender{
	NSButtonCell *cell = [sender selectedCell];
	NSString *field = [cell title];
	
    NSCellStateValue oldState = [theBib triStateValueOfField:field];
    NSCellStateValue newState = [cell state];
	
    BOOL oldBool = [theBib boolValueOfField:field];
    BOOL newBool = [cell state] == NSOnState ? YES : NO;
    
    BOOL isTriState = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKTriStateFieldsKey] containsObject:field];
    
    BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];

    if(isTriState){
        if(newState == oldState) return;
        
        [theBib setField:field toTriStateValue:newState];
        
        if (scriptHook) {
            [scriptHook setField:field];
            [scriptHook setOldValues:[NSArray arrayWithObject:[NSString stringWithTriStateValue:oldState]]];
            [scriptHook setNewValues:[NSArray arrayWithObject:[NSString stringWithTriStateValue:newState]]];
            [[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
        }
    }else{
        if(newBool == oldBool) return;    
        
        [theBib setField:field toBoolValue:newBool];
        
        if (scriptHook) {
 			[scriptHook setField:field];
            [scriptHook setOldValues:[NSArray arrayWithObject:[NSString stringWithBool:oldBool]]];
            [scriptHook setNewValues:[NSArray arrayWithObject:[NSString stringWithBool:newBool]]];
 			[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
 		}
        
        
    }
    [[[self window] undoManager] setActionName:NSLocalizedString(@"Change Flag",@"")];
	
}

#pragma mark choose local-url or url support

- (IBAction)chooseLocalURL:(id)sender{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setResolvesAliases:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel setPrompt:NSLocalizedString(@"Choose", @"Choose")];
	
	NSArray *localFileFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey];
	[fieldsPopUpButton removeAllItems];
	[fieldsPopUpButton addItemsWithTitles:localFileFields];
	[fieldsPopUpButton selectItemWithTitle:BDSKLocalUrlString];
	if ([localFileFields count] > 1) 
		[oPanel setAccessoryView:fieldsAccessoryView];

    [oPanel beginSheetForDirectory:nil 
                              file:nil 
                    modalForWindow:[self window] 
                     modalDelegate:self 
                    didEndSelector:@selector(chooseLocalURLPanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:nil];
  
}

- (void)chooseLocalURLPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{

    if(returnCode == NSOKButton){
        NSString *fileURLString = [[NSURL fileURLWithPath:[[sheet filenames] objectAtIndex:0]] absoluteString];
		NSString *field = [fieldsPopUpButton titleOfSelectedItem];
        
		[theBib setField:field toValue:fileURLString];
		if ([field isEqualToString:BDSKLocalUrlString])
			[self autoFilePaper];
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
    }        
}

- (void)setLocalURLPathFromMenuItem:(NSMenuItem *)sender{
	NSString *path = [sender representedObject];
	
	[theBib setField:BDSKLocalUrlString toValue:[[NSURL fileURLWithPath:path] absoluteString]];
	[self autoFilePaper];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
}

- (void)setRemoteURLFromMenuItem:(NSMenuItem *)sender{
	[theBib setField:BDSKUrlString toValue:[sender representedObject]];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
}

// ----------------------------------------------------------------------------------------
#pragma mark add-Field-Sheet Support
// Add field sheet support
// ----------------------------------------------------------------------------------------

- (void)addFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *newField = [addFieldController field];
    if(returnCode == NSCancelButton || newField == nil)
        return;
    
    NSArray *currentFields = [theBib allFieldNames];
    newField = [newField capitalizedString];
    if([currentFields containsObject:newField] == NO){
		[tabView selectFirstTabViewItem:nil];
        [theBib addField:newField];
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Add Field",@"")];
		[self setupForm];
		[self makeKeyField:newField];
    }
}

// raises the add field sheet
- (IBAction)raiseAddField:(id)sender{
    BibTypeManager *typeMan = [BibTypeManager sharedManager];
    NSArray *currentFields = [theBib allFieldNames];
    NSArray *fieldNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObject:BDSKCrossrefString] excluding:currentFields];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of field to add:",@"")
                                                                                              fieldsArray:fieldNames];
	[addFieldController beginSheetModalForWindow:[self window]
                                   modalDelegate:self
                                  didEndSelector:@selector(addFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (void)makeKeyField:(NSString *)fieldName{
    int sel = -1;
    int i = 0;

    for (i = 0; i < [bibFields numberOfRows]; i++) {
        if ([[[bibFields cellAtIndex:i] title] isEqualToString:fieldName]) {
            sel = i;
        }
    }
    if(sel > -1) [bibFields selectTextAtIndex:sel];
}

// ----------------------------------------------------------------------------------------
#pragma mark ||  delete-Field-Sheet Support
// ----------------------------------------------------------------------------------------

- (void)removeFieldSheetDidEnd:(BDSKRemoveFieldSheetController *)removeFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *oldField = [removeFieldController field];
    NSArray *removableFields = [removeFieldController fieldsArray];
    if(returnCode == NSCancelButton || oldField == nil || [removableFields count] == 0)
        return;
	
    [tabView selectFirstTabViewItem:nil];
    [theBib removeField:oldField];
    [[[self window] undoManager] setActionName:NSLocalizedString(@"Remove Field",@"")];
    [self setupForm];
}

// raises the del field sheet
- (IBAction)raiseDelField:(id)sender{
    // populate the popupbutton
	BibTypeManager *typeMan = [BibTypeManager sharedManager];
	NSMutableArray *removableFields = [[theBib allFieldNames] mutableCopy];
	[removableFields removeObjectsInArray:[NSArray arrayWithObjects:BDSKLocalUrlString, BDSKUrlString, BDSKAnnoteString, BDSKAbstractString, BDSKRssDescriptionString, nil]];
	[removableFields removeObjectsInArray:[typeMan requiredFieldsForType:currentType]];
	[removableFields removeObjectsInArray:[typeMan optionalFieldsForType:currentType]];
	[removableFields removeObjectsInArray:[typeMan userDefaultFieldsForType:currentType]];
    
    NSString *prompt = NSLocalizedString(@"Name of field to remove:",@"");
	if ([removableFields count]) {
		[removableFields sortUsingSelector:@selector(caseInsensitiveCompare:)];
	} else {
		prompt = NSLocalizedString(@"No fields to remove",@"");
	}
    
    BDSKRemoveFieldSheetController *removeFieldController = [[BDSKRemoveFieldSheetController alloc] initWithPrompt:prompt
                                                                                                       fieldsArray:removableFields];
	[removableFields release];
    
    NSString *selectedCellTitle = [[bibFields selectedCell] title];
    if([removableFields containsObject:selectedCellTitle]){
        [removeFieldController setField:selectedCellTitle];
        // if we don't deselect this cell, we can't remove it from the form
        [self finalizeChangesPreservingSelection:NO];
    }
	
	[removeFieldController beginSheetModalForWindow:[self window]
                                      modalDelegate:self
                                     didEndSelector:@selector(removeFieldSheetDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
    [removeFieldController release];
}

#pragma mark Text Change handling

- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender{
	if ([self editSelectedFormCellAsMacro])
		[[bibFields currentEditor] selectAll:sender];
}

- (BOOL)editSelectedFormCellAsMacro{
	NSCell *cell = [bibFields selectedCell];
	if ([macroTextFieldWC isEditing] || cell == nil || [[cell title] isEqualToString:BDSKCrossrefString]) 
		return NO;
	NSString *value = [theBib valueOfField:[cell title]];
	
	[formCellFormatter setEditAsComplexString:YES];
	[cell setObjectValue:value];
	return [macroTextFieldWC attachToView:bibFields atRow:[bibFields selectedRow] column:0 withValue:value];
}

- (BOOL)formatter:(BDSKComplexStringFormatter *)formatter shouldEditAsComplexString:(NSString *)object {
	[self editSelectedFormCellAsMacro];
	return YES;
}

// this is called when the user actually starts editing
- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor{
    if (control != bibFields) return YES;
    
    NSString *field = [[bibFields selectedCell] title];
	NSString *value = [theBib valueOfField:field];
    
	if([value isInherited] &&
	   [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKWarnOnEditInheritedKey]){
		BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"alert title")
											 defaultButton:NSLocalizedString(@"OK", @"OK")
										   alternateButton:NSLocalizedString(@"Cancel", @"Cancel")
											   otherButton:NSLocalizedString(@"Edit Parent", @"Edit Parent")
								 informativeTextWithFormat:NSLocalizedString(@"The value was inherited from the item linked to by the Crossref field. Do you want to overwrite the inherited value?", @"")];
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
			[self openParentItem:self];
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
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Entry", @"") 
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
        NSString *fieldName = [cell title];
		if ([fieldName isEqualToString:BDSKCrossrefString]) {
            // this may occur if the cite key formatter fails to format
            if(error != nil){
                BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Crossref Key", @"") 
                                                     defaultButton:nil
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:@"%@", error];
                
                [alert runSheetModalForWindow:[self window]];
                if(forceEndEditing)
                    [cell setStringValue:[theBib valueOfField:fieldName]];
            }else{
                NSLog(@"%@:%d formatter for control %@ failed for unknown reason", __FILENAMEASNSSTRING__, __LINE__, control);
            }
            return forceEndEditing;
        } else if ([formCellFormatter editAsComplexString]) {
			if (forceEndEditing) {
				// reset the cell's value to the last saved value and proceed
				[cell setStringValue:[theBib valueOfField:fieldName]];
				return YES;
			}
			// don't set the value
			return NO;
		} else {
			// this is a simple string, an error means that there are unbalanced braces
			NSString *message = nil;
			NSString *cancelButton = nil;
			
			if (forceEndEditing) {
				message = NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved.", @"");
			} else {
				message = NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved. Do you want to keep editing?", @"");
				cancelButton = NSLocalizedString(@"Cancel", @"Cancel");
			}
			
            BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Value", @"Invalid Value") 
                                                 defaultButton:NSLocalizedString(@"OK", @"OK")
                                               alternateButton:cancelButton
                                                   otherButton:nil
                                     informativeTextWithFormat:message];
            
            int rv = [alert runSheetModalForWindow:[self window]];
			
			if (forceEndEditing || rv == NSAlertAlternateReturn) {
				[cell setStringValue:[theBib valueOfField:fieldName]];
				return YES;
			} else {
				return NO;
			}
		}
	} else if (control == citeKeyField) {
        // this may occur if the cite key formatter fails to format
        if(error != nil){
            BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Cite Key", @"") 
                                                 defaultButton:nil
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"%@", error];
            
            [alert runSheetModalForWindow:[self window]];
            if(forceEndEditing)
                [control setStringValue:[theBib citeKey]];
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
		
		if ([[cell title] isEqualToString:BDSKCrossrefString]) {
			
			if ([[theBib citeKey] caseInsensitiveCompare:[cell stringValue]] == NSOrderedSame) {
				message = NSLocalizedString(@"An item cannot cross reference to itself.", @"");
			} else {
				NSString *parentCr = [[theDocument publicationForCiteKey:[cell stringValue]] valueOfField:BDSKCrossrefString inherit:NO];
				
				if (![NSString isEmptyString:parentCr]) {
					message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"");
				} else if ([theDocument citeKeyIsCrossreffed:[theBib citeKey]]) {
					message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"");
				}
			}
			
			if (message) {
                BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Crossref Value", @"Invalid Crossref Value") 
                                                     defaultButton:NSLocalizedString(@"OK", @"OK")
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:message];
                
                [alert runSheetModalForWindow:[self window]];
				[cell setStringValue:@""];
				return forceEndEditing;
			}
		}
        		
	} else if (control == citeKeyField) {
		
        NSCharacterSet *invalidSet = [[BibTypeManager sharedManager] fragileCiteKeyCharacterSet];
        NSRange r = [[control stringValue] rangeOfCharacterFromSet:invalidSet];
        
        if (r.location != NSNotFound) {
            NSString *message = nil;
            NSString *cancelButton = nil;
            
            if (forceEndEditing) {
                message = NSLocalizedString(@"The cite key you entered contains characters that could be invalid in TeX.", @"");
            } else {
                message = NSLocalizedString(@"The cite key you entered contains characters that could be invalid in TeX. Do you want to continue editing with the invalid characters removed?", @"");
                cancelButton = NSLocalizedString(@"Cancel", @"Cancel");
            }
            
            BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Value", @"Invalid Value") 
                                                 defaultButton:NSLocalizedString(@"OK", @"OK")
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
	if (control != bibFields)
		return;
	int index = [control indexOfSelectedItem];
	if (index == -1)
		return;
	
    NSCell *cell = [control cellAtIndex:index];
    NSString *title = [cell title];
	NSString *value = [cell stringValue];
	NSString *prevValue = [theBib valueOfField:title];

    if ([prevValue isInherited] &&
	    ([value isEqualAsComplexString:prevValue] || [value isEqualAsComplexString:@""]) ) {
		// make sure we keep the original inherited string value
		[cell setObjectValue:prevValue];
	} else if (![value isEqualAsComplexString:prevValue]) {
		[self recordChangingField:title toValue:value];
    }
	// do this here, the order is important!
	[formCellFormatter setEditAsComplexString:NO];
}

- (void)moveFileAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSDictionary *info = (NSDictionary *)contextInfo;
    if (returnCode == NSAlertDefaultReturn) {
        NSArray *paperInfos = [NSArray arrayWithObject:info];
        NSString *fieldName = [info objectForKey:@"fieldName"];
        [[BibFiler sharedFiler] movePapers:paperInfos forField:fieldName fromDocument:theDocument options:0];
    }
    [info release];
}

- (void)recordChangingField:(NSString *)fieldName toValue:(NSString *)value{
    NSString *oldValue = [[[theBib valueOfField:fieldName] copy] autorelease];
    BOOL isLocalFile = [[BibTypeManager sharedManager] isLocalFileField:fieldName];
    NSURL *oldURL = (isLocalFile) ? [[theBib URLForField:fieldName] fileURLByResolvingAliases] : nil;
    
    [theBib setField:fieldName toValue:value];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
    
	NSMutableString *status = [NSMutableString stringWithString:@""];
	
    // autogenerate cite key if we have enough information
    if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKCiteKeyAutogenerateKey] &&
         [theBib canGenerateAndSetCiteKey] ) {
        [self generateCiteKey:nil];
        if ([theBib hasEmptyOrDefaultCiteKey] == NO)
            [status appendString:NSLocalizedString(@"Autogenerated Cite Key.",@"Autogenerated Cite Key.")];
    }
    
    // autofile paper if we have enough information
    if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey] &&
         [theBib needsToBeFiled] && [theBib canSetLocalUrl] ) {
        [[BibFiler sharedFiler] filePapers:[NSArray arrayWithObject:theBib] fromDocument:[theBib document] check:NO];
        [theBib setNeedsToBeFiled:NO]; // unset the flag even when we fail, to avoid retrying at every edit
		if (![status isEqualToString:@""]) {
			[status appendString:@" "];
		}
		[status appendString:NSLocalizedString(@"Autofiled linked file.",@"Autofiled linked file.")];
    } else if (isLocalFile) {
        NSString *newPath = [theBib localFilePathForField:fieldName];
        if (oldURL != nil && newPath != nil && [[NSFileManager defaultManager] fileExistsAtPath:newPath] == NO) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Move File?", @"Move File?") 
                                             defaultButton:NSLocalizedString(@"Yes", @"Yes") 
                                           alternateButton:NSLocalizedString(@"No", @"No") 
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"Do you want me to move the linked file to the new location?", @"") ];

            NSArray *info = [[NSDictionary alloc] initWithObjectsAndKeys:theBib, @"paper", [oldURL path], @"oldPath", newPath, @"newPath", fieldName, @"fieldName", nil];
            [alert beginSheetModalForWindow:[self window]
                              modalDelegate:self
                             didEndSelector:@selector(moveFileAlertDidEnd:returnCode:contextInfo:)
                                contextInfo:info];
        }
    }
    
	if (![status isEqualToString:@""]) {
		[self setStatus:status];
	}
	
	BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
	if (scriptHook) {
		[scriptHook setField:fieldName];
		[scriptHook setOldValues:[NSArray arrayWithObject:oldValue]];
		[scriptHook setNewValues:[NSArray arrayWithObject:value]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
	}
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
		tooltip = NSLocalizedString(@"The cite key needs to be generated.", @"");
	} else if ([identifier isEqualToString:@"NeedsToBeFiled"]) {
		requiredFields = [[NSApp delegate] requiredFieldsForLocalUrl];
		tooltip = NSLocalizedString(@"The linked file needs to be filed.", @"");
	} else {
		return nil;
	}
	
	NSEnumerator *fieldEnum = [requiredFields objectEnumerator];
	NSString *field;
	
	while (field = [fieldEnum nextObject]) {
		if ([field isEqualToString:BDSKCiteKeyString]) {
			if ([theBib hasEmptyOrDefaultCiteKey])
				[missingFields addObject:field];
		} else if ([field isEqualToString:@"Document Filename"]) {
			if ([NSString isEmptyString:[[theBib document] fileName]])
				[missingFields addObject:field];
		} else if ([field isEqualToString:BDSKAuthorEditorString]) {
			if ([NSString isEmptyString:[theBib valueOfField:BDSKAuthorString]] && [NSString isEmptyString:[theBib valueOfField:BDSKEditorString]])
				[missingFields addObject:field];
		} else if ([NSString isEmptyString:[theBib valueOfField:field]]) {
			[missingFields addObject:field];
		}
	}
	
	if ([missingFields count])
		return [tooltip stringByAppendingFormat:NSLocalizedString(@" Missing fields: %@", @""), [missingFields componentsJoinedByString:@", "]];
	else
		return tooltip;
}

- (void)needsToBeFiledDidChange:(NSNotification *)notification{
	if ([theBib needsToBeFiled] == YES) {
		[self setStatus:NSLocalizedString(@"Linked file needs to be filed.",@"Linked file needs to be filed.")];
		if ([[statusBar iconIdentifiers] containsObject:@"NeedsToBeFiled"] == NO) {
			NSImage *icon = [NSImage smallImageNamed:@"genericFolderIcon"];
			NSString *tooltip = NSLocalizedString(@"The linked file needs to be filed.", @"");
			[statusBar addIcon:icon withIdentifier:@"NeedsToBeFiled" toolTip:tooltip];
		}
	} else {
		[self setStatus:@""];
		[statusBar removeIconWithIdentifier:@"NeedsToBeFiled"];
	}
}

- (void)updateCiteKeyAutoGenerateStatus{
	if ([theBib hasEmptyOrDefaultCiteKey] && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKCiteKeyAutogenerateKey]) {
		if ([[statusBar iconIdentifiers] containsObject:@"NeedsToGenerateCiteKey"] == NO) {
			NSImage *icon = [NSImage smallImageNamed:@"key"];
			NSString *tooltip = NSLocalizedString(@"The cite key needs to be generated.", @"");
			[statusBar addIcon:icon withIdentifier:@"NeedsToGenerateCiteKey" toolTip:tooltip];
		}
	} else {
		[statusBar removeIconWithIdentifier:@"NeedsToGenerateCiteKey"];
	}
}

- (void)autoFilePaper{
	if ([theBib autoFilePaper])
		[self setStatus:NSLocalizedString(@"Autofiled linked file.",@"Autofiled linked file.")];
}

- (void)bibDidChange:(NSNotification *)notification{
// unused	BibItem *notifBib = [notification object];
	NSDictionary *userInfo = [notification userInfo];
	NSString *changeType = [userInfo objectForKey:@"type"];
	NSString *changeKey = [userInfo objectForKey:@"key"];
	NSString *newValue = [userInfo objectForKey:@"value"];
	BibItem *sender = (BibItem *)[notification object];
	NSString *crossref = [theBib valueOfField:BDSKCrossrefString inherit:NO];
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	BOOL parentDidChange = (crossref != nil && 
							([crossref caseInsensitiveCompare:[sender citeKey]] == NSOrderedSame || 
							 [crossref caseInsensitiveCompare:[userInfo objectForKey:@"oldCiteKey"]] == NSOrderedSame));
	
    // If it is not our item or his crossref parent, we don't care, but our parent may have changed his cite key
	if (sender != theBib && !parentDidChange)
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
	
    // Rebuild the form if the crossref changed, or our parent's cite key changed.
	if([changeKey isEqualToString:BDSKCrossrefString] || 
	   (parentDidChange && [changeKey isEqualToString:BDSKCiteKeyString])){
		[self setupForm];
		[[self window] setTitle:[theBib displayTitle]];
		[authorTableView reloadData];
		pdfSnoopViewLoaded = NO;
		webSnoopViewLoaded = NO;
		[self fixURLs];
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
			if([[entry title] isEqualToString:changeKey]){
				[entry setIntValue:[theBib intValueOfField:changeKey]];
				[extraBibFields setNeedsDisplay:YES];
				break;
			}
		}
		return;
	}
	
	if([changeKey isEqualToString:BDSKCiteKeyString]){
		[citeKeyField setStringValue:newValue];
		[self updateCiteKeyAutoGenerateStatus];
		// still need to check duplicates ourselves:
		if(![theBib isValidCiteKey:newValue]){
			[self setCiteKeyDuplicateWarning:YES];
		}else{
			[self setCiteKeyDuplicateWarning:NO];
		}
	}else{
		// essentially a cellWithTitle: for NSForm
		NSEnumerator *cellE = [[bibFields cells] objectEnumerator];
		NSFormCell *entry = nil;
		while(entry = [cellE nextObject]){
			if([[entry title] isEqualToString:changeKey]){
				[entry setObjectValue:[theBib valueOfField:changeKey]];
				[bibFields setNeedsDisplay:YES];
				break;
			}
		}
	}
	
	if([changeKey isEqualToString:BDSKLocalUrlString]){
		pdfSnoopViewLoaded = NO;
		[self fixURLs];
	}
	else if([changeKey isEqualToString:BDSKUrlString]){
		webSnoopViewLoaded = NO;
		[self fixURLs];
	}
	else if([changeKey isEqualToString:BDSKTitleString] || [changeKey isEqualToString:BDSKChapterString] || [changeKey isEqualToString:BDSKPagesString]){
		[[self window] setTitle:[theBib displayTitle]];
	}
	else if([changeKey isEqualToString:BDSKAuthorString]){
		[authorTableView reloadData];
	}
    else if([changeKey isEqualToString:BDSKAnnoteString]){
        if(ignoreFieldChange) return;
        // make a copy of the current value, so we don't overwrite it when we set the field value to the text storage
        NSString *tmpValue = [[theBib valueOfField:BDSKAnnoteString inherit:NO] copy];
        [notesView setString:(tmpValue == nil ? @"" : tmpValue)];
        [tmpValue release];
        if(currentEditedView == notesView)
            [[self window] makeFirstResponder:[self window]];
        [notesViewUndoManager removeAllActions];
    }
    else if([changeKey isEqualToString:BDSKAbstractString]){
        if(ignoreFieldChange) return;
        NSString *tmpValue = [[theBib valueOfField:BDSKAbstractString inherit:NO] copy];
        [abstractView setString:(tmpValue == nil ? @"" : tmpValue)];
        [tmpValue release];
        if(currentEditedView == abstractView)
            [[self window] makeFirstResponder:[self window]];
        [abstractViewUndoManager removeAllActions];
    }
    else if([changeKey isEqualToString:BDSKRssDescriptionString]){
        if(ignoreFieldChange) return;
        NSString *tmpValue = [[theBib valueOfField:BDSKRssDescriptionString inherit:NO] copy];
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
	NSString *crossref = [theBib valueOfField:BDSKCrossrefString inherit:NO];
	
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
	[self setupTypePopUp];
	[theBib makeType]; // make sure this is done now, and not later
	[self setupForm];
}
 
- (void)customFieldsDidChange:(NSNotification *)aNotification{
	[theBib makeType]; // make sure this is done now, and not later
	[self setupForm];
}

- (void)macrosDidChange:(NSNotification *)notification{
	BibDocument *changedDoc = [[notification object] document];
	if(changedDoc && changedDoc != theDocument)
		return; // only macro changes for our own document or the global macros
	
	NSArray *cells = [bibFields cells];
	NSEnumerator *cellE = [cells objectEnumerator];
	NSFormCell *entry = nil;
	NSString *value;
	
	while(entry = [cellE nextObject]){
		value = [theBib valueOfField:[entry title]];
		if([value isComplex]){
            // ARM: the cell must check pointer equality in the setter, or something; since it's the same object, setting the value again is a noop unless we set to nil first.  Fixes bug #1284205.
            [entry setObjectValue:nil];
			[entry setObjectValue:value];
        }
	}    
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
        [theBib setField:BDSKAnnoteString toValue:[[notesView textStorage] mutableString]];
        [[theBib undoManager] setActionName:NSLocalizedString(@"Edit Annotation",@"")];
    } else if(currentEditedView == abstractView){
        [theBib setField:BDSKAbstractString toValue:[[abstractView textStorage] mutableString]];
        [[theBib undoManager] setActionName:NSLocalizedString(@"Edit Abstract",@"")];
    }else if(currentEditedView == rssDescriptionView){
        [theBib setField:BDSKRssDescriptionString toValue:[[rssDescriptionView textStorage] mutableString]];
        [[theBib undoManager] setActionName:NSLocalizedString(@"Edit RSS Description",@"")];
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

// sent by the notesView and the abstractView
- (void)textDidEndEditing:(NSNotification *)aNotification{
	currentEditedView = nil;
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
	
	if ([pubs containsObject:theBib])
		[self close];
}

// these methods are for crossref interaction with the form
- (void)openParentItem:(id)sender{
    BibItem *parent = [theBib crossrefParent];
    if(parent)
        [theDocument editPub:parent];
}

- (IBAction)selectCrossrefParentAction:(id)sender{
    [[self document] selectCrossrefParentForItem:theBib];
}

- (IBAction)createNewPubUsingCrossrefAction:(id)sender{
    [[self document] createNewPubUsingCrossrefForItem:theBib];
}

- (void)deletePubAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (alert != nil && [alert checkValue] == YES) {
		[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:NO forKey:BDSKWarnOnDeleteKey];
	}
    if (returnCode == NSAlertOtherReturn)
        return;
    
	[[[self document] undoManager] setActionName:NSLocalizedString(@"Delete Publication", @"Delete Publication")];
    [[self document] setStatus:NSLocalizedString(@"Deleted 1 publication",@"Deleted 1 publication") immediate:NO];
	[[self document] removePublication:theBib];
}

- (IBAction)deletePub:(id)sender{
	if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKWarnOnDeleteKey]) {
		BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Delete Publication", @"Delete Publication")
											 defaultButton:NSLocalizedString(@"OK", @"OK")
										   alternateButton:nil
											   otherButton:NSLocalizedString(@"Cancel", @"Cancel")
								 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to delete the current item?", @"")];
		[alert setHasCheckButton:YES];
		[alert setCheckValue:NO];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(deletePubAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
	} else {
        [self deletePubAlertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:NULL];
    }
}

#pragma mark BDSKForm delegate methods

- (void)arrowClickedInFormCell:(id)cell{
	[self openParentItem:nil];
}

- (void)iconClickedInFormCell:(id)cell{
    [[NSWorkspace sharedWorkspace] openURL:[theBib URLForField:[cell title]]];
}

- (BOOL)formCellHasArrowButton:(id)cell{
	return ([[theBib valueOfField:[cell title]] isInherited] || 
			([[cell title] isEqualToString:BDSKCrossrefString] && [theBib crossrefParent]));
}

- (BOOL)formCellHasFileIcon:(id)cell{
    NSString *title = [cell title];
    if ([[BibTypeManager sharedManager] isURLField:title]) {
		// if we inherit a field, we don't show the file icon but the arrow button
		NSString *url = [theBib valueOfField:title inherit:NO];
		// we could also check for validity here
		if (![NSString isEmptyString:url])
			return YES;
	}
	return NO;
}

- (NSImage *)fileIconForFormCell:(id)cell{
    // we can assume that this cell should have a file icon
    return [theBib smallImageForURLField:[cell title]];
}

- (NSImage *)dragIconForFormCell:(id)cell{
    // we can assume that this cell should have a file icon
    return [theBib imageForURLField:[cell title]];
}

- (NSRange)control:(NSControl *)control textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange {
    if (control != bibFields) {
		return charRange;
	} else if ([macroTextFieldWC isEditing]) {
		return [[NSApp delegate] rangeForUserCompletion:charRange 
								  forBibTeXString:[textView string]];
	} else {
		return [[NSApp delegate] entry:[[bibFields selectedCell] title] 
				rangeForUserCompletion:charRange 
							  ofString:[textView string]];

	}
	return charRange;
}

- (BOOL)control:(NSControl *)control textViewShouldAutoComplete:(NSTextView *)textview {
    if (control == bibFields)
		return [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKEditorFormShouldAutoCompleteKey];
	return NO;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index{
    if (control != bibFields) {
		return words;
	} else if ([macroTextFieldWC isEditing]) {
		return [[NSApp delegate] possibleMatches:[[theDocument macroResolver] allMacroDefinitions] 
						   forBibTeXString:[textView string] 
								partialWordRange:charRange 
								indexOfBestMatch:index];
	} else {
		return [[NSApp delegate] entry:[[bibFields selectedCell] title] 
						   completions:words 
				   forPartialWordRange:charRange 
							  ofString:[textView string] 
				   indexOfSelectedItem:index];

	}
}

#pragma mark dragging destination delegate methods

- (BOOL)canReceiveDrag:(id <NSDraggingInfo>)sender forField:(NSString *)field{
	NSPasteboard *pboard = [sender draggingPasteboard];
    id dragSource = [sender draggingSource];
    NSString *dragSourceField = nil;
	NSString *dragType;
	
    if(dragSource == viewLocalButton)
        dragSourceField = BDSKLocalUrlString;
    else if(dragSource == viewRemoteButton)
        dragSourceField = BDSKUrlString;
    else if(dragSource == bibFields)
        dragSourceField = [[bibFields dragSourceCell] title];
    
    if ([field isEqualToString:dragSourceField])
        return NO;
    
	// we put webloc types first, as we always want to accept them for remote URLs, but never for local files
	dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKWeblocFilePboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
	
	if ([[BibTypeManager sharedManager] isLocalFileField:field]) {
		if ([dragType isEqualToString:NSFilenamesPboardType]) {
			return YES;
		} else if ([dragType isEqualToString:NSURLPboardType]) {
			// a file can put NSURLPboardType on the pasteboard
			// we really only want to receive local files for file URLs
			NSURL *fileURL = [NSURL URLFromPasteboard:pboard];
			if(fileURL && [fileURL isFileURL])
				return YES;
		}
		return NO;
	} else if ([[BibTypeManager sharedManager] isRemoteURLField:field]){
		if ([dragType isEqualToString:BDSKWeblocFilePboardType]) {
			return YES;
		} else if ([dragType isEqualToString:NSURLPboardType]) {
			// a file puts NSFilenamesPboardType and NSURLPboardType on the pasteboard
			// we really only want to receive webloc files for remote URLs, not file URLs
			NSURL *remoteURL = [NSURL URLFromPasteboard:pboard];
			if(remoteURL && ![remoteURL isFileURL])
				return YES;
		}
        return NO;
	} else {
		// we don't support dropping on a textual field. This is handled by the window
	}
	return NO;
}

- (BOOL)receiveDrag:(id <NSDraggingInfo>)sender forField:(NSString *)field{
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *dragType;
    
	// we put webloc types first, as we always want to accept them for remote URLs, but never for local files
	dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKWeblocFilePboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
    
	if ([[BibTypeManager sharedManager] isLocalFileField:field]) {
		// a file, we link the local file field
		NSURL *fileURL = nil;
		
		if ([dragType isEqualToString:NSFilenamesPboardType]) {
			NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
			if ([fileNames count] == 0)
				return NO;
			fileURL = [NSURL fileURLWithPath:[[fileNames objectAtIndex:0] stringByExpandingTildeInPath]];
		} else if ([dragType isEqualToString:NSURLPboardType]) {
			fileURL = [NSURL URLFromPasteboard:pboard];
			if (![fileURL isFileURL])
				return NO;
		} else {
			return NO;
		}
		
		if (fileURL == nil || 
            [fileURL isEqual:[theBib URLForField:field]])
			return NO;
		        
		[theBib setField:field toValue:[fileURL absoluteString]];

		// perform autofile on delay; see comment in -[BibDocument (DataSource) tableView:acceptDrop:row:dropOperation:] about drags from Finder
        if ([field isEqualToString:BDSKLocalUrlString])
            [self performSelector:@selector(autoFilePaper) withObject:nil afterDelay:0.7];
		[[theBib undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
        
		return YES;
		
	} else if ([[BibTypeManager sharedManager] isRemoteURLField:field]){
		// Check first for webloc files because we want to treat them differently    
		if ([dragType isEqualToString:BDSKWeblocFilePboardType]) {
			
			NSString *remoteURLString = [pboard stringForType:BDSKWeblocFilePboardType];
			
			if (remoteURLString == nil ||
				[[NSURL URLWithString:remoteURLString] isEqual:[theBib remoteURLForField:field]])
				return NO;
			
			[theBib setField:field toValue:remoteURLString];
			[[theBib undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];

			return YES;
			
		} else if ([dragType isEqualToString:NSURLPboardType]) {
			// a URL but not a file, we link the remote Url field
			NSURL *remoteURL = [NSURL URLFromPasteboard:pboard];
			
			if (remoteURL == nil || [remoteURL isFileURL] ||
				[remoteURL isEqual:[theBib remoteURLForField:field]])
				return NO;
			
			[theBib setField:field toValue:[remoteURL absoluteString]];
			[[theBib undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
			
			return YES;
			
		}
		
	} else {
		// we don't at the moment support dropping on a textual field
	}
	return NO;
}

- (BOOL)imagePopUpButton:(BDSKImagePopUpButton *)view canReceiveDrag:(id <NSDraggingInfo>)sender{
	if (view == [sender draggingSource])
		return NO;
	NSString *field = nil;
	if (view == viewLocalButton)
		field = BDSKLocalUrlString;
	else if (view == viewRemoteButton)
		field = BDSKUrlString;
	return [self canReceiveDrag:sender forField:field];
}

- (BOOL)imagePopUpButton:(BDSKImagePopUpButton *)view receiveDrag:(id <NSDraggingInfo>)sender{
	NSString *field = nil;
	if (view == viewLocalButton)
		field = BDSKLocalUrlString;
	else if (view == viewRemoteButton)
		field = BDSKUrlString;
	return [self receiveDrag:sender forField:field];
}

- (BOOL)canReceiveDrag:(id <NSDraggingInfo>)sender forFormCell:(id)cell{
	NSString *field = [cell title];
	return [self canReceiveDrag:sender forField:field];
}

- (BOOL)receiveDrag:(id <NSDraggingInfo>)sender forFormCell:(id)cell{
	NSString *field = [cell title];
	return [self receiveDrag:sender forField:field];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
	if (anObject != bibFields)
		return nil;
	if (dragFieldEditor == nil) {
		dragFieldEditor = [[BDSKFieldEditor alloc] init];
		[(BDSKFieldEditor *)dragFieldEditor registerForDelegatedDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, BDSKWeblocFilePboardType, nil]];
	}
	return dragFieldEditor;
}

#pragma mark dragging source delegate methods

- (BOOL)writeDataToPasteboard:(NSPasteboard *)pboard forField:(NSString *)field {

    NSURL *url = [theBib URLForField:field];
	
	if (url == nil)
		return NO;
	
	[self setPromisedDragURL:url];
	
	NSArray *types = nil;
	NSString *pathExtension = @"";
	
	if([url isFileURL]){
		NSString *path = [url path];
		pathExtension = [path pathExtension];
		types = [NSArray arrayWithObjects:NSURLPboardType, NSFilesPromisePboardType, nil];
		[pboard declareTypes:types owner:nil];
		[url writeToPasteboard:pboard];
		[self setPromisedDragFilename:[path lastPathComponent]];
		[pboard setPropertyList:[NSArray arrayWithObject:promisedDragFilename] forType:NSFilesPromisePboardType];
	} else {
		NSString *filename = [theBib displayTitle];
		if ([NSString isEmptyString:filename])
			filename = @"Remote URL";
		pathExtension = @"webloc";
		types = [NSArray arrayWithObjects:NSURLPboardType, NSFilesPromisePboardType, nil];
		[pboard declareTypes:types owner:nil];
		[url writeToPasteboard:pboard];
		[self setPromisedDragFilename:[filename stringByAppendingPathExtension:@"webloc"]];
		[pboard setPropertyList:[NSArray arrayWithObject:promisedDragFilename] forType:NSFilesPromisePboardType];
	}
	
	return YES;
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forField:(NSString *)field {
    NSString *dstPath = [dropDestination path];
    
    // queue the file creation so we don't block while waiting for this method to return
	// console warnings can occur but are harmless
    if([promisedDragURL isFileURL]){
        [[OFMessageQueue mainQueue] queueSelector:@selector(copyPath:toPath:handler:) 
                                        forObject:[NSFileManager defaultManager]
                                       withObject:[promisedDragURL path]
                                       withObject:[dstPath stringByAppendingPathComponent:promisedDragFilename]
                                       withObject:nil];
    } else {
        [[OFMessageQueue mainQueue] queueSelector:@selector(createWeblocFileAtPath:withURL:) 
                                        forObject:[NSFileManager defaultManager]
                                       withObject:[dstPath stringByAppendingPathComponent:promisedDragFilename]
                                       withObject:promisedDragURL];
    }
    
    return [NSArray arrayWithObject:promisedDragFilename];
}

- (void)cleanUpAfterDragOperation:(NSDragOperation)operation forField:(NSString *)field {
    [self setPromisedDragURL:nil];
    [self setPromisedDragFilename:nil];
}

- (BOOL)writeDataToPasteboard:(NSPasteboard *)pasteboard forFormCell:(id)cell {
	NSString *field = [cell title];
	return [self writeDataToPasteboard:pasteboard forField:field];
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forFormCell:(id)cell {
	NSString *field = [cell title];
	return [self namesOfPromisedFilesDroppedAtDestination:dropDestination forField:field];
}

- (void)cleanUpAfterDragOperation:(NSDragOperation)operation forFormCell:(id)cell {
	NSString *field = [cell title];
	[self cleanUpAfterDragOperation:operation forField:field];
}

- (BOOL)imagePopUpButton:(BDSKImagePopUpButton *)view writeDataToPasteboard:(NSPasteboard *)pasteboard {
	NSString *field = nil;
	if (view == viewLocalButton)
		field = BDSKLocalUrlString;
	else if (view == viewRemoteButton)
		field = BDSKUrlString;
	if (field != nil)
		return [self writeDataToPasteboard:pasteboard forField:field];
	return NO;
}

- (NSArray *)imagePopUpButton:(BDSKImagePopUpButton *)view namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination {
	NSString *field = nil;
	if (view == viewLocalButton)
		field = BDSKLocalUrlString;
	else if (view == viewRemoteButton)
		field = BDSKUrlString;
	if (field != nil)
		return [self namesOfPromisedFilesDroppedAtDestination:dropDestination forField:field];
	return nil;
}

- (void)imagePopUpButton:(BDSKImagePopUpButton *)view cleanUpAfterDragOperation:(NSDragOperation)operation {
	NSString *field = nil;
	if (view == viewLocalButton)
		field = BDSKLocalUrlString;
	else if (view == viewRemoteButton)
		field = BDSKUrlString;
	if (field != nil)
		[self cleanUpAfterDragOperation:operation forField:field];
}

// used to cache the destination webloc file's URL
- (void)setPromisedDragURL:(NSURL *)theURL{
    [theURL retain];
    [promisedDragURL release];
    promisedDragURL = theURL;
}

// used to cache the filename (not the full path) of the promised file
- (void)setPromisedDragFilename:(NSString *)theFilename{
    if(promisedDragFilename != theFilename){
        [promisedDragFilename release];
        promisedDragFilename = [theFilename copy];
    }
}

#pragma mark snoop drawer stuff

// update the arrow image direction when the window changes
- (void)windowDidMove:(NSNotification *)aNotification{
    [self updateDocumentSnoopButton];
}

- (void)windowDidResize:(NSNotification *)notification{
    [self updateDocumentSnoopButton];
}

// this correctly handles multiple displays and doesn't depend on the drawer being loaded
- (NSRectEdge)preferredDrawerEdge{
    
    if(drawerState & BDSKDrawerStateOpenMask)
        return [documentSnoopDrawer edge];
        
    NSRect screenFrame = [[[self window] screen] visibleFrame];
    NSRect windowFrame = [[self window] frame];
    
    float midScreen = NSMidX(screenFrame);
    float midWindow = NSMidX(windowFrame);
    
    return ( (midWindow - midScreen) < 0 ? NSMaxXEdge : NSMinXEdge);
}

- (void)updateDocumentSnoopButton
{
	int requiredContent = [[documentSnoopButton selectedItem] tag];
	int currentContent = drawerState & (BDSKDrawerStateTextMask | BDSKDrawerStateWebMask);
    NSString *lurl = [theBib localUrlPath];
    NSURL *rurl = [theBib remoteURL];
	int state = requiredContent;
	
	if ((requiredContent == currentContent) && (drawerState & BDSKDrawerStateOpenMask))
		state |= BDSKDrawerStateOpenMask;
	if ([self preferredDrawerEdge] == NSMaxXEdge)
        state |= BDSKDrawerStateRightMask;
	
	if (state == drawerButtonState)
		return; // we don't need to change the button
	
	drawerButtonState = state;
	
	if ( (state & BDSKDrawerStateOpenMask) || 
		 ((state & BDSKDrawerStateWebMask) && rurl) ||
		 (!(state & BDSKDrawerStateWebMask) && lurl && [[NSFileManager defaultManager] fileExistsAtPath:lurl]) ) {
		
		NSImage *drawerImage = [NSImage imageNamed:@"drawerRight"];
		NSImage *arrowImage = [NSImage imageNamed:@"drawerArrow"];
		NSImage *badgeImage = nil;
		
		if (state & BDSKDrawerStateWebMask)
			badgeImage = [NSImage smallGenericInternetLocationImage];
		else if (state & BDSKDrawerStateTextMask)
			badgeImage = [NSImage smallImageForFileType:@"txt"];
		else
			badgeImage = [theBib smallImageForURLField:BDSKLocalUrlString];
		
		NSRect iconRect = NSMakeRect(0, 0, 32, 32);
		NSSize arrowSize = [arrowImage size];
		NSRect arrowRect = {NSZeroPoint, arrowSize};
		NSRect arrowDrawRect = NSMakeRect(29 - arrowSize.width, ceilf(0.5f * (32-arrowSize.height)), arrowSize.width, arrowSize.height);
		NSRect badgeRect = {NSZeroPoint, [badgeImage size]};
		NSRect badgeDrawRect = NSMakeRect(15, 0, 16, 16);
		NSImage *image = [[[NSImage alloc] initWithSize:iconRect.size] autorelease];
		
		if (state & BDSKDrawerStateRightMask) {
			if (state & BDSKDrawerStateOpenMask)
				arrowImage = [arrowImage imageFlippedHorizontally];
		} else {
			arrowDrawRect.origin.x = 3;
			badgeDrawRect.origin.x = 1;
			drawerImage = [drawerImage imageFlippedHorizontally];
			if (!(state & BDSKDrawerStateOpenMask))
				arrowImage = [arrowImage imageFlippedHorizontally];
		}
		
		[image lockFocus];
		[drawerImage drawInRect:iconRect fromRect:iconRect  operation:NSCompositeSourceOver  fraction: 1.0];
		[badgeImage drawInRect:badgeDrawRect fromRect:badgeRect  operation:NSCompositeSourceOver  fraction: 1.0];
		[arrowImage drawInRect:arrowDrawRect fromRect:arrowRect  operation:NSCompositeSourceOver  fraction: 1.0];
		[image unlockFocus];
		
        [documentSnoopButton fadeIconImageToImage:image];
		
		if (state & BDSKDrawerStateOpenMask) {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"Close Drawer", @"Close drawer")];
		} else if (state & BDSKDrawerStateWebMask) {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"View Remote URL in Drawer", @"View remote URL in drawer")];
		} else if (state & BDSKDrawerStateTextMask) {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"View File as Text in Drawer", @"View file as text in drawer")];
		} else {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"View File in Drawer", @"View file in drawer")];
		}
		
		[documentSnoopButton setIconActionEnabled:YES];
	}
	else {
        [documentSnoopButton setIconImage:[NSImage imageNamed:@"drawerDisabled"]];
		
		if (state & BDSKDrawerStateOpenMask) {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"Close Drawer", @"Close drawer")];
		} else {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"Choose Content to View in Drawer", @"Choose content to view in drawer")];
		}
		
		[documentSnoopButton setIconActionEnabled:NO];
	}
}

- (void)updateSnoopDrawerContent{
    NSURL *lurl = [[theBib URLForField:BDSKLocalUrlString] fileURLByResolvingAliases];

	if ([documentSnoopDrawer contentView] == pdfSnoopContainerView) {

		if (!lurl || pdfSnoopViewLoaded) return;

        if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3){
            [documentSnoopImageView loadData:[NSData dataWithContentsOfURL:lurl]];
            [documentSnoopScrollView setDocumentViewAlignment:NSImageAlignTopLeft];
        } else {
            // see what type this is; we can open PDF or PS
            // check the UTI instead of the file extension (10.4 only)
            
            NSError *readError = nil;
            NSData *fileData = [NSData dataWithContentsOfURL:lurl options:NSUncachedRead error:&readError];
            if(fileData == nil)
                [[self window] presentError:readError];
            
            BOOL isPostScript = NO;
            NSString *theUTI = [[NSWorkspace sharedWorkspace] UTIForURL:lurl];
            
            if(theUTI == nil){
                // some error occurred, so we'll assume it's PDF and carry on
                NSLog(@"%@: error occurred getting UTI of %@", __FILENAMEASNSSTRING__, lurl);
            } else if([theUTI isEqualToUTI:@"com.adobe.postscript"]){
                isPostScript = YES;
            } else if([theUTI isEqualToUTI:@"com.pkware.zip-archive"] || [theUTI isEqualToUTI:@"org.gnu.gnu-zip-archive"]){    
                // OmniFoundation supports zip, gzip, and bzip2, AFAICT, but we have no UTI for bzip2
                OBPRECONDITION([fileData mightBeCompressed]);
                
                // try to decompress; OmniFoundation raises a variety of exceptions if this fails, so we'll just discard all of them
                @try {
                    fileData = [fileData decompressedData];
                }
                @catch( id exception ){
                    NSLog(@"discarding exception %@ raised while attempting to decompress file at %@", exception, [lurl path]);
                    fileData = nil;
                }
                
                // since we don't have an actual file on disk, we can't rely on LS to return the file type, so fall back to checking the extension
                NSString *nextToLastExtension = [[[lurl path] stringByDeletingPathExtension] pathExtension];
                OBPRECONDITION([NSString isEmptyString:nextToLastExtension] == NO);
                
                theUTI = [[NSWorkspace sharedWorkspace] UTIForPathExtension:nextToLastExtension];
                if([theUTI isEqualToUTI:@"com.adobe.postscript"])
                    isPostScript = YES;
            }
            
            id pdfDocument = isPostScript ? [[NSClassFromString(@"PDFDocument") alloc] initWithPostScriptData:fileData] : [[NSClassFromString(@"PDFDocument") alloc] initWithData:fileData];
            
            // if unable to create a PDFDocument from the given URL, display a warning message
            if(pdfDocument == nil){
                NSData *pdfData = [[BDSKPreviewer sharedPreviewer] PDFDataWithString:NSLocalizedString(@"Unable to determine file type, or an error occurred reading the file.  Only PDF and PostScript files can be displayed in the drawer at present.", @"") color:[NSColor redColor]];
                pdfDocument = [[NSClassFromString(@"PDFDocument") alloc] initWithData:pdfData];
            }
            
            id pdfView = [[pdfSnoopContainerView subviews] objectAtIndex:0];
            [(BDSKZoomablePDFView *)pdfView setDocument:pdfDocument];
            [pdfDocument release];
        }
        pdfSnoopViewLoaded = YES;
	}
	else if ([documentSnoopDrawer contentView] == textSnoopContainerView) {
		NSMutableString *path = [[[lurl path] mutableCopy] autorelease];
        
        // @@ 10.3 should check the file's UTI against com.adobe.pdf, but 10.3 doesn't have a way to get a UTI
        if([NSString isEmptyString:path] == NO){
            // escape single quotes that may be in the path; other characters should be handled by quoting in the command string
            [path replaceOccurrencesOfString:@"\'" withString:@"\\\'" options:0 range:NSMakeRange(0, [path length])];
            
            NSString *cmdString = [[NSBundle mainBundle] pathForResource:@"pdftotext" ofType:nil];
            cmdString = [NSString stringWithFormat:@"%@ -f 1 -l 1 \'%@\' -", cmdString, path];
            NSString *textSnoopString = [[BDSKShellTask shellTask] runShellCommand:cmdString withInputString:nil];
            if([NSString isEmptyString:textSnoopString])
                [documentSnoopTextView setString:NSLocalizedString(@"Unable to convert this file to text.  It may be a scanned image, or perhaps it's not a PDF file.", @"")];
            else
                [documentSnoopTextView setString:textSnoopString];
        } else {
            [documentSnoopTextView setString:NSLocalizedString(@"This entry does not have a Local-Url.", @"")];
        }
	}
	else if ([documentSnoopDrawer contentView] == webSnoopContainerView) {
		if (!webSnoopViewLoaded) {
			NSURL *rurl = [theBib remoteURL];
			if (rurl == nil) return;
			[[remoteSnoopWebView mainFrame] loadRequest:[NSURLRequest requestWithURL:rurl]];
			webSnoopViewLoaded = YES;
		}
	}
}

- (void)toggleSnoopDrawer:(id)sender{
	int requiredContent = [sender tag];
	int currentContent = drawerState & (BDSKDrawerStateTextMask | BDSKDrawerStateWebMask);
	
	if (drawerLoaded == NO) {
		if ([NSBundle loadNibNamed:@"BibEditorDrawer" owner:self]) {
			drawerLoaded = YES;
		}  else {
			[statusBar setStringValue:NSLocalizedString(@"Unable to load the drawer.",@"")];
			return;
		}
	}
	
	// we force a reload, as the user might have browsed
	if (requiredContent & BDSKDrawerStateWebMask) 
		webSnoopViewLoaded = NO;
	
    // sometimes the drawer is determined to open on the side with less screen available, so we'll set the edge manually (sending -[NSDrawer setPreferredEdge:] is unreliable)
    NSRectEdge edge = ([documentSnoopDrawer state] == NSDrawerOpenState ? [documentSnoopDrawer edge] : [self preferredDrawerEdge]);
    
    if (edge == NSMaxXEdge)
		drawerState |= BDSKDrawerStateRightMask;
    
	drawerState = requiredContent;
	
	if (currentContent == requiredContent) {
		if ([documentSnoopDrawer state] == NSDrawerClosedState || [documentSnoopDrawer state] == NSDrawerClosingState){
			drawerState |= BDSKDrawerStateOpenMask;
            [documentSnoopDrawer openOnEdge:edge];
        } else {
            [documentSnoopDrawer close:sender];
        }
	} else {
		drawerState |= BDSKDrawerStateOpenMask;
		if (requiredContent & BDSKDrawerStateTextMask) 
			[documentSnoopDrawer setContentView:textSnoopContainerView];
		else if (requiredContent & BDSKDrawerStateWebMask) 
			[documentSnoopDrawer setContentView:webSnoopContainerView];
		else
			[documentSnoopDrawer setContentView:pdfSnoopContainerView];
		[documentSnoopDrawer close:sender];
		[documentSnoopDrawer openOnEdge:edge];
	}
	
	// we remember the last item that was selected in the preferences, so it sticks between windows
	[[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:[documentSnoopButton indexOfSelectedItem]
													   forKey:BDSKSnoopDrawerContentKey];
}

- (void)drawerWillOpen:(NSNotification *)notification{
	[self updateSnoopDrawerContent];
	
	if([[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSnoopDrawerSavedSizeKey] != nil)
        [documentSnoopDrawer setContentSize:NSSizeFromString([[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSnoopDrawerSavedSizeKey])];
    [documentSnoopScrollView scrollToTop];
}

- (void)drawerDidOpen:(NSNotification *)notification{
	[self updateDocumentSnoopButton];
}

- (void)drawerWillClose:(NSNotification *)notification{
	[[self window] makeFirstResponder:nil]; // this is necessary to avoid a crash after browsing
}

- (void)drawerDidClose:(NSNotification *)notification{
	[self updateDocumentSnoopButton];
}

- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:NSStringFromSize(contentSize) forKey:BDSKSnoopDrawerSavedSizeKey];
    return contentSize;
}

- (BOOL)windowShouldClose:(id)sender{
    NSString *errMsg = nil;
    NSString *discardMsg = NSLocalizedString(@"Discard", @"");
    
    // case 1: the item has not been edited
    if(![theBib hasBeenEdited]){
        errMsg = NSLocalizedString(@"The item has not been edited.  Would you like to keep it?", @"");
    // case 2: cite key hasn't been set, and paper needs to be filed
    }else if([theBib hasEmptyOrDefaultCiteKey] && [theBib needsToBeFiled] && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
        errMsg = NSLocalizedString(@"The cite key for this entry has not been set, and AutoFile did not have enough information to file the paper.  Would you like to cancel and continue editing, or close the window and keep this entry as-is?", @"");
        discardMsg = nil; // this item has some fields filled out and has a paper associated with it; no discard option
    // case 3: only the paper needs to be filed
    }else if([theBib needsToBeFiled] && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
        errMsg = NSLocalizedString(@"AutoFile did not have enough information to file this paper.  Would you like to cancel and continue editing, or close the window and keep this entry as-is?", @"");
        discardMsg = nil; // this item has some fields filled out and has a paper associated with it; no discard option
    // case 4: only the cite key needs to be set
    }else if([theBib hasEmptyOrDefaultCiteKey]){
        errMsg = NSLocalizedString(@"The cite key for this entry has not been set.  Would you like to cancel and edit the cite key, or close the window and keep this entry as-is?", @"");
	// case 5: good to go
    }else{
        return YES;
    }
	
    NSBeginAlertSheet(NSLocalizedString(@"Warning!", @""),
                      NSLocalizedString(@"Keep", @""),   //default button NSAlertDefaultReturn
                      discardMsg,                        //far left button NSAlertAlternateReturn
                      NSLocalizedString(@"Cancel", @""), //middle button NSAlertOtherReturn
                      [self window],
                      self, // modal delegate
                      @selector(shouldCloseSheetDidEnd:returnCode:contextInfo:),
                      NULL, // did dismiss sel
                      NULL,
                      errMsg);
    return NO; // this method returns before the callback

}

- (void)shouldCloseSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    switch (returnCode){
        case NSAlertOtherReturn:
            break; // do nothing
        case NSAlertAlternateReturn:
            [[theBib retain] autorelease]; // make sure it stays around till we're closed
            [[theBib document] removePublication:theBib]; // now fall through to default
        default:
            [sheet orderOut:nil];
            [self close];
    }
}

- (void)windowWillClose:(NSNotification *)notification{
	[self finalizeChangesPreservingSelection:NO];
    [macroTextFieldWC close]; // close so it's not hanging around by itself; this works if the doc window closes, also
    [documentSnoopDrawer close];
	// this can give errors when the application quits when an editor window is open
	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKCloseEditorWindowScriptHookName 
												 forPublications:[NSArray arrayWithObject:theBib]];
	
    // see method for notes
    [self breakTextStorageConnections];
    
    // @@ problem here:  BibEditor is the delegate for a lot of things, and if they get messaged before the window goes away, but after the editor goes away, we have crashes.  In particular, the finalizeChanges (or something?) ends up causing the window and form to be redisplayed if a form cell is selected when you close the window, and the form sends formCellHasArrowButton to a garbage editor.  Rather than set the delegate of all objects to nil here, we'll just hang around a bit longer.
    [[self retain] autorelease];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems{
	NSMutableArray *menuItems = [NSMutableArray arrayWithCapacity:8];
	NSMenuItem *item;
	
	NSEnumerator *iEnum = [defaultMenuItems objectEnumerator];
	while (item = [iEnum nextObject]) { 
		if ([item tag] == WebMenuItemTagCopy ||
			[item tag] == WebMenuItemTagCopyLinkToClipboard ||
			[item tag] == WebMenuItemTagCopyImageToClipboard) {
			
			[menuItems addObject:item];
		}
	}
	if ([menuItems count] > 0) 
		[menuItems addObject:[NSMenuItem separatorItem]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Back",@"Back")
									  action:@selector(goBack:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Forward",@"Forward")
									  action:@selector(goForward:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Reload",@"Reload")
									  action:@selector(reload:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Stop",@"Stop")
									  action:@selector(stopLoading:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Increase Text Size",@"Increase Text Size")
									  action:@selector(makeTextLarger:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Decrease Text Size",@"Increase Text Size")
									  action:@selector(makeTextSmaller:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	[menuItems addObject:[NSMenuItem separatorItem]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Save as Local File",@"Save as local file")
									  action:@selector(saveFileAsLocalUrl:)
							   keyEquivalent:@""];
	[item setTarget:self];
	[menuItems addObject:[item autorelease]];
	
	return menuItems;
}

- (void)saveFileAsLocalUrl:(id)sender{
	WebDataSource *dataSource = [[remoteSnoopWebView mainFrame] dataSource];
	if (!dataSource || [dataSource isLoading]) 
		return;
	
	NSString *fileName = [[[[dataSource request] URL] relativePath] lastPathComponent];
	NSString *extension = [fileName pathExtension];
   
	NSSavePanel *sPanel = [NSSavePanel savePanel];
    if (![extension isEqualToString:@""]) 
		[sPanel setRequiredFileType:extension];
    int result = [sPanel runModalForDirectory:nil file:fileName];
    if (result == NSOKButton) {
		if ([[dataSource data] writeToFile:[sPanel filename] atomically:YES]) {
			NSString *fileURLString = [[NSURL fileURLWithPath:[sPanel filename]] absoluteString];
			
			[theBib setField:BDSKLocalUrlString toValue:fileURLString];
			[self autoFilePaper];
			
			[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
		} else {
			NSLog(@"Could not write downloaded file.");
		}
    }
}

- (void)downloadLinkedFileAsLocalUrl:(id)sender{
    OBASSERT_NOT_REACHED("not yet implemented");
	// NSURL *linkURL = (NSURL *)[sender representedObject];
	// not yet implemented 
}

#pragma mark undo manager

// we want to have the same undoManager as our document, so we use this 
// NSWindow delegate method to return the doc's undomanager, except for
// the abstract/annote/rss text views.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
    // work around for a bug(?) in Panther, as the main menu appears to use this method rather than -undoManagerForTextView:
	id firstResponder = [sender firstResponder];
	if(firstResponder == notesView)
        return notesViewUndoManager;
    else if(firstResponder == abstractView)
        return abstractViewUndoManager;
    else if(firstResponder == rssDescriptionView)
        return rssDescriptionViewUndoManager;
	
	return [theDocument undoManager];
}


#pragma mark author table view datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)tableView{
	return [theBib numberOfPeople];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn 
			row:(int)row{
    return [[theBib sortedPeople] objectAtIndex:row];
}

- (IBAction)showPersonDetailCmd:(id)sender{
    NSArray *thePeople = [theBib sortedPeople];
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
    [theDocument showPerson:person];
}

#pragma mark Splitview delegate methods

- (void)splitViewDoubleClick:(OASplitView *)sender{
    NSView *form = [[splitView subviews] objectAtIndex:0]; // form
    NSView *matrix = [[splitView subviews] objectAtIndex:1]; // matrix
    NSRect formFrame = [form frame];
    NSRect matrixFrame = [matrix frame];
    
    if(NSHeight([matrix frame]) != 0){ // not sure what the criteria for isSubviewCollapsed, but it doesn't work
        lastMatrixHeight = NSHeight(matrixFrame); // cache this
        formFrame.size.height += lastMatrixHeight;
        matrixFrame.size.height = 0;
    } else {
        if(lastMatrixHeight == 0)
            lastMatrixHeight = NSHeight([extraBibFields frame]); // a reasonable value to start
		matrixFrame.size.height = lastMatrixHeight;
        formFrame.size.height = NSHeight([splitView frame]) - lastMatrixHeight - [splitView dividerThickness];
		if (NSHeight(formFrame) < 1.0) {
			formFrame.size.height = 1.0;
			matrixFrame.size.height = NSHeight([splitView frame]) - [splitView dividerThickness] - 1.0;
			lastMatrixHeight = NSHeight(matrixFrame);
		}
    }
    [form setFrame:formFrame];
    [matrix setFrame:matrixFrame];
    [splitView adjustSubviews];
	// fix for NSSplitView bug, which doesn't send this in adjustSubviews
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:splitView];
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset{
	// don't loose the top edge of the splitter
	return proposedMin + 1.0;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize{
    // keeps the matrix view at the same size and resizes the form view
	NSView *form = [[sender subviews] objectAtIndex:0]; // form
    NSView *matrix = [[sender subviews] objectAtIndex:1]; // matrix
    NSRect formFrame = [form frame];
    NSRect matrixFrame = [matrix frame];
	NSSize newSize = [sender frame].size;
	
	formFrame.size.height += newSize.height - oldSize.height;
	if (NSHeight(formFrame) < 1.0) {
		formFrame.size.height = 1.0;
		matrixFrame.size.height = newSize.height - [splitView dividerThickness] - 1.0;
		lastMatrixHeight = NSHeight(matrixFrame);
	}
    [form setFrame:formFrame];
    [matrix setFrame:matrixFrame];
    [splitView adjustSubviews];
	// fix for NSSplitView bug, which doesn't send this in adjustSubviews
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:splitView];
}

@end

@implementation BibEditor (Private)

- (void)setupDrawer {
    
    [documentSnoopDrawer setParentWindow:[self window]];
    if (drawerState & BDSKDrawerStateTextMask)
        [documentSnoopDrawer setContentView:textSnoopContainerView];
    else if (drawerState & BDSKDrawerStateWebMask)
        [documentSnoopDrawer setContentView:webSnoopContainerView];
    else
        [documentSnoopDrawer setContentView:pdfSnoopContainerView];
    
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_3) {
        NSSize drawerContentSize = [documentSnoopDrawer contentSize];
        id pdfView = [[NSClassFromString(@"BDSKZoomablePDFView") alloc] initWithFrame:NSMakeRect(0, 0, drawerContentSize.width, drawerContentSize.height)];
        
        // release the old scrollview/PDFImageView combination and replace with the PDFView
        [pdfSnoopContainerView replaceSubview:documentSnoopScrollView with:pdfView];
        [pdfView release];
        [pdfView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
        
        [pdfView setScrollerSize:NSSmallControlSize];
        documentSnoopScrollView = nil;
    }
    
}

- (void)setupButtons {
    
    // Set the properties of viewLocalButton that cannot be set in IB
	[viewLocalButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
	[viewLocalButton setShowsMenuWhenIconClicked:NO];
	[[viewLocalButton cell] setAltersStateOfSelectedItem:NO];
	[[viewLocalButton cell] setAlwaysUsesFirstItemAsSelected:YES];
	[[viewLocalButton cell] setUsesItemFromMenu:NO];
	[viewLocalButton setRefreshesMenu:YES];
	[viewLocalButton setDelegate:self];
    [viewLocalButton registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];
    
	[viewLocalButton setMenu:[self menuForImagePopUpButton:viewLocalButton]];
    
	// Set the properties of viewRemoteButton that cannot be set in IB
	[viewRemoteButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
	[viewRemoteButton setShowsMenuWhenIconClicked:NO];
	[[viewRemoteButton cell] setAltersStateOfSelectedItem:NO];
	[[viewRemoteButton cell] setAlwaysUsesFirstItemAsSelected:YES];
	[[viewRemoteButton cell] setUsesItemFromMenu:NO];
	[viewRemoteButton setRefreshesMenu:YES];
	[viewRemoteButton setDelegate:self];
    [viewRemoteButton registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, BDSKWeblocFilePboardType, nil]];
    
	[viewRemoteButton setMenu:[self menuForImagePopUpButton:viewRemoteButton]];
    
	// Set the properties of documentSnoopButton that cannot be set in IB
	[documentSnoopButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
	[documentSnoopButton setShowsMenuWhenIconClicked:NO];
	[[documentSnoopButton cell] setAltersStateOfSelectedItem:YES];
	[[documentSnoopButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[documentSnoopButton cell] setUsesItemFromMenu:NO];
	[[documentSnoopButton cell] setRefreshesMenu:NO];
	
	[documentSnoopButton setMenu:[self menuForImagePopUpButton:documentSnoopButton]];
	[documentSnoopButton selectItemAtIndex:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKSnoopDrawerContentKey]];
    
    // Set the properties of actionMenuButton that cannot be set in IB
	[actionMenuButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
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
		entry = [bibFields insertEntry:tmp usingTitleFont:requiredFont attributesForTitle:attrs indexAndTag:i objectValue:[theBib valueOfField:tmp]]; \
		if ([tmp isEqualToString:BDSKCrossrefString]) \
			[entry setFormatter:crossrefFormatter]; \
		else \
			[entry setFormatter:formCellFormatter]; \
		if([editedTitle isEqualToString:tmp]) editedRow = i; \
		i++; \
    }

#define AddMatrixEntries(fields, cell) \
    e = [fields objectEnumerator]; \
    while(tmp = [e nextObject]){ \
		if (++j >= nc) { \
			j = 0; \
			i++; \
			[extraBibFields addRow]; \
		} \
		NSButtonCell *buttonCell = [cell copy]; \
		[buttonCell setTitle:tmp]; \
		[buttonCell setIntValue:[theBib intValueOfField:tmp]]; \
		[extraBibFields putCell:buttonCell atRow:i column:j]; \
		[buttonCell release]; \
		if([editedTitle isEqualToString:tmp]){ \
			editedRow = i; \
			editedColumn = j; \
		} \
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
	int editedColumn = -1;
	NSRange selection;
	if([firstResponder isKindOfClass:[NSText class]] && [(NSText *)firstResponder delegate] == bibFields){
		fieldEditor = (NSText *)firstResponder;
		selection = [fieldEditor selectedRange];
		editedTitle = [(NSFormCell *)[bibFields selectedCell] title];
		forceEndEditing = YES;
		if (![[self window] makeFirstResponder:[self window]])
			[[self window] endEditingFor:nil];
		forceEndEditing = NO;
	}else if(firstResponder == extraBibFields){
		editedTitle = [(NSFormCell *)[extraBibFields selectedCell] title];
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
    sKeys = [[theBib allFieldNames] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	
	// now add the entries to the form
	AddFormEntries([[BibTypeManager sharedManager] requiredFieldsForType:[theBib pubType]], reqAtt);
	AddFormEntries([[BibTypeManager sharedManager] optionalFieldsForType:[theBib pubType]], nil);
	AddFormEntries(sKeys, nil);
    
    [ignoredKeys release];
    [reqAtt release];
    
    [bibFields sizeToFit];
    
    [bibFields setFrameOrigin:origin];
    [bibFields setNeedsDisplay:YES];
    
	rect = [extraBibFields frame];
	origin = rect.origin;
	
    while ([extraBibFields numberOfRows])
		[extraBibFields removeRow:0];
	
	int nc = [extraBibFields numberOfColumns];
	int j = nc;
	
	i = -1;
	AddMatrixEntries(ratingFields, ratingButtonCell);
	AddMatrixEntries(booleanFields, booleanButtonCell);
	AddMatrixEntries(triStateFields, triStateButtonCell);
	
	[extraBibFields sizeToFit];
    
    [extraBibFields setFrameOrigin:origin];
    [extraBibFields setNeedsDisplay:YES];
	
	// restore the edited cell and its selection
	if(editedRow != -1){
		if(fieldEditor){
			[[self window] makeFirstResponder:bibFields];
			[bibFields selectTextAtRow:editedRow column:0];
			[fieldEditor setSelectedRange:selection];
		}else{
			[[self window] makeFirstResponder:extraBibFields];
			[extraBibFields selectCellAtRow:editedRow column:editedColumn];
		}
	}
    
    // align the cite key field with the form cells
    if([bibFields numberOfRows] > 0){
        [bibFields drawRect:NSZeroRect];// this forces the calculation of the titleWidth
        float offset = [[bibFields cellAtIndex:0] titleWidth] + NSMinX([splitView frame]) + FORM_OFFSET + 4.0;
        NSRect frame = [citeKeyField frame];
        if(offset != NSMinX(frame) && offset >= NSMaxX([citeKeyTitle frame]) + 8.0){
            frame.size.width = NSMaxX(frame) - offset;
            frame.origin.x = offset;
            [citeKeyField setFrame:frame];
            [[citeKeyField superview] setNeedsDisplay:YES];
        }
    }
    
	didSetupForm = YES;
}

- (void)setupTypePopUp{
    NSEnumerator *typeNamesE = [[[BibTypeManager sharedManager] bibTypesForFileType:[theBib fileType]] objectEnumerator];
    NSString *typeName = nil;

    [bibTypeButton removeAllItems];
    while(typeName = [typeNamesE nextObject]){
        [bibTypeButton addItemWithTitle:typeName];
    }

    [bibTypeButton selectItemWithTitle:currentType];
}

- (void)registerForNotifications {
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibDidChange:)
												 name:BDSKBibItemChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(needsToBeFiledDidChange:)
												 name:BDSKNeedsToBeFiledChangedNotification
											   object:theBib];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWasAddedOrRemoved:)
												 name:BDSKDocAddItemNotification
											   object:theDocument];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWasAddedOrRemoved:)
												 name:BDSKDocDelItemNotification
											   object:theDocument];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWillBeRemoved:)
												 name:BDSKDocWillRemoveItemNotification
											   object:theDocument];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(finalizeChanges:)
												 name:BDSKFinalizeChangesNotification
											   object:theDocument];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(typeInfoDidChange:)
												 name:BDSKBibTypeInfoChangedNotification
											   object:[BibTypeManager sharedManager]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(customFieldsDidChange:)
												 name:BDSKCustomFieldsChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(macrosDidChange:)
												 name:BDSKMacroDefinitionChangedNotification
											   object:nil];
}

- (void)fixURLs{
    NSURL *lurl = [[theBib URLForField:BDSKLocalUrlString] fileURLByResolvingAliases];
    NSString *rurl = [theBib valueOfField:BDSKUrlString];
    NSImage *icon;
    BOOL drawerWasOpen = ([documentSnoopDrawer state] == NSDrawerOpenState ||
						  [documentSnoopDrawer state] == NSDrawerOpeningState);
	BOOL drawerShouldReopen = NO;
	
	// we need to reopen with the correct content
    if(drawerWasOpen) [documentSnoopDrawer close];
    
    // either missing file or the document icon
    icon = [theBib imageForURLField:BDSKLocalUrlString];
    if(icon == nil) // nil for an empty field; we use missing file icon for a placeholder in that case
        icon = [NSImage missingFileImage];
    [viewLocalButton setIconImage:icon];
    
    if (lurl){
		[viewLocalButton setIconActionEnabled:YES];
		[viewLocalToolbarItem setToolTip:NSLocalizedString(@"Open the file or option-drag to copy it",@"View file")];
		[[self window] setRepresentedFilename:[lurl path]];
		if([documentSnoopDrawer contentView] != webSnoopContainerView)
			drawerShouldReopen = drawerWasOpen;
    }else{
		[viewLocalButton setIconActionEnabled:NO];
        [viewLocalToolbarItem setToolTip:NSLocalizedString(@"Choose a file to link with in the Local-Url Field", @"bad/empty local url field")];
        [[self window] setRepresentedFilename:@""];
    }

    NSURL *remoteURL = [theBib remoteURL];
    if(remoteURL != nil){
        icon = [NSImage imageForURL:remoteURL];
		[viewRemoteButton setIconImage:icon];
        [viewRemoteButton setIconActionEnabled:YES];
        [viewRemoteToolbarItem setToolTip:rurl];
		if([documentSnoopDrawer contentView] == webSnoopContainerView)
			drawerShouldReopen = drawerWasOpen;
    }else{
        [viewRemoteButton setIconImage:[NSImage imageNamed:@"WeblocFile_Disabled"]];
		[viewRemoteButton setIconActionEnabled:NO];
        [viewRemoteToolbarItem setToolTip:NSLocalizedString(@"Choose a URL to link with in the Url Field", @"bad/empty url field")];
    }
	
    drawerButtonState = BDSKDrawerUnknownState; // this makes sure the button will be updated
    if (drawerShouldReopen){
		// this takes care of updating the button and the drawer content
		[documentSnoopDrawer open];
	}else{
		[self updateDocumentSnoopButton];
	}
}

- (void)breakTextStorageConnections {
    
    // This is a fix for bug #1483613 (and others).  We set some of the BibItem's fields to -[[NSTextView textStorage] mutableString] for efficiency in tracking changes for live editing updates in the main window preview.  However, this causes a retain cycle, as the text storage retains its text view; any font changes to the editor text view will cause the retained textview to message its delegate (BibEditor) which is garbage in -[NSTextView _addToTypingAttributes].
    NSEnumerator *fieldE = [[[BibTypeManager sharedManager] noteFieldsSet] objectEnumerator];
    NSString *currentValue = nil;
    NSString *fieldName = nil;
    while(fieldName = [fieldE nextObject]){
        currentValue = [[theBib valueOfField:fieldName inherit:NO] copy];
        // set without undo, or we dirty the document every time the editor is closed
        if(nil != currentValue)
            [theBib setField:fieldName toValueWithoutUndo:currentValue];
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
    unsigned int flags = [theEvent modifierFlags];
    
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
    }
    return [super performKeyEquivalent:theEvent];
}

@end
