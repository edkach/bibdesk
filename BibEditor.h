//  BibEditor.h

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

/*! @header BibEditor.h
    @discussion The class for editing BibItems. Handles the UI for the fields and notes.
*/ 

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "BDSKForm.h"

@class BDSKRatingButton;
@class BDSKRatingButtonCell;
@class BDSKComplexStringFormatter;
@class BDSKCrossrefFormatter;
@class BDSKCitationFormatter;
@class MacroFormWindowController;
@class BDSKImagePopUpButton;
@class BibItem;
@class BDSKStatusBar;
@class BDSKAlert;
@class BibAuthor;
@class BDSKZoomablePDFView;
@class BibEditor;
@class FileView;
@class BDSKSplitView;

/*!
    @class BibEditor
    @abstract WindowController for the edit window
    @discussion Subclass of the NSWindowController class, This handles making, reversing and keeping track of changes to the BibItem, and displaying a nice GUI.
*/
@interface BibEditor : NSWindowController <BDSKFormDelegate> {
	IBOutlet BDSKSplitView *mainSplitView;
	IBOutlet BDSKSplitView *fileSplitView;
	IBOutlet BDSKSplitView *fieldSplitView;
    IBOutlet NSPopUpButton *bibTypeButton;
    IBOutlet BDSKForm *bibFields;
    IBOutlet NSMatrix *extraBibFields;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTextView *notesView;
    IBOutlet NSTextView *abstractView;
    IBOutlet NSTextView* rssDescriptionView;
    IBOutlet NSView* fieldsAccessoryView;
    IBOutlet NSPopUpButton* fieldsPopUpButton;
	NSTextView *currentEditedView;
    NSUndoManager *notesViewUndoManager;
    NSUndoManager *abstractViewUndoManager;
    NSUndoManager *rssDescriptionViewUndoManager;
    BOOL ignoreFieldChange;
    // for the splitview double-click handling
    float lastMatrixHeight;
	float lastFileViewWidth;
    float lastAuthorsHeight;
    
	NSButtonCell *booleanButtonCell;
	NSButtonCell *triStateButtonCell;
	BDSKRatingButtonCell *ratingButtonCell;
    
    IBOutlet NSTextField* citeKeyField;
    IBOutlet NSTextField* citeKeyTitle;
	IBOutlet BDSKImagePopUpButton *actionMenuButton;
	IBOutlet BDSKImagePopUpButton *actionButton;
    IBOutlet NSMenu *actionMenu;
	IBOutlet NSButton *addFieldButton;
	
	IBOutlet NSWindow *chooseURLSheet;
	IBOutlet NSTextField *chooseURLField;
    
    // ----------------------------------------------------------------------------------------
    BibItem *publication;
    BOOL isEditable;
// ----------------------------------------------------------------------------------------
// status bar stuff
// ----------------------------------------------------------------------------------------
    IBOutlet BDSKStatusBar *statusBar;
	
// cite-key checking stuff:
	IBOutlet NSButton *citeKeyWarningButton;
	
// form cell formatter
    BDSKComplexStringFormatter *formCellFormatter;
    BDSKCrossrefFormatter *crossrefFormatter;
	BDSKCitationFormatter *citationFormatter;
    
// Author tableView
	IBOutlet NSTableView *authorTableView;

    // Macro editing stuff
    MacroFormWindowController *macroTextFieldWC;

	// edit field stuff
	BOOL forceEndEditing;

    BOOL didSetupForm;
	
	NSTextView *dragFieldEditor;
    
    IBOutlet FileView *fileView;
}

/*!
@method initWithPublication:
    @abstract designated Initializer
    @discussion
 @param aBib gives us a bib to edit
*/
- (id)initWithPublication:(BibItem *)aBib;

- (BibItem *)publication;

/*!
    @method     show
    @abstract   Shows the window.
    @discussion (comprehensive description)
*/
- (void)show;

- (IBAction)chooseLocalFile:(id)sender;
- (void)chooseLocalFilePanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)trashLocalFile:(id)sender;

- (IBAction)chooseRemoteURL:(id)sender;
- (IBAction)dismissChooseURLSheet:(id)sender;
- (void)chooseRemoteURLSheetDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)toggleStatusBar:(id)sender;

- (IBAction)raiseAddField:(id)sender;
- (IBAction)raiseDelField:(id)sender;
- (IBAction)raiseChangeFieldName:(id)sender;

/*!
    @method     editSelectedFieldAsRawBibTeX:
    @abstract   edits the current field as a macro.
    @discussion This is not necessary if the field is already a macro.
    @param      sender (description)
    @result     (description)
*/
- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender;

/*!
    @method     recordChangingField:toValue:
    @abstract   sets field to value in publication and does other stuff
    @discussion factored out because setting field and doing other things is done from more than one place.
    @param      fieldName (description)
    @param      value (description)
*/
- (void)recordChangingField:(NSString *)fieldName toValue:(NSString *)value;

- (void)needsToBeFiledDidChange:(NSNotification *)notification;

- (void)updateCiteKeyAutoGenerateStatus;

- (int)userChangedField:(NSString *)fieldName from:(NSString *)oldValue to:(NSString *)newValue;
- (int)userChangedField:(NSString *)fieldName from:(NSString *)oldValue to:(NSString *)newValue didAutoGenerate:(int)mask;

- (NSString *)status;
- (void)setStatus:(NSString *)status;

/*!
    @method     finalizeChanges:
    @abstract   Makes sure that edits of fields are submitted.
    @discussion (comprehensive description)
    @param      aNotification Unused
*/
- (void)finalizeChanges:(NSNotification *)aNotification;

- (IBAction)openLinkedFile:(id)sender;

- (IBAction)revealLinkedFile:(id)sender;

- (IBAction)openLinkedURL:(id)sender;

- (IBAction)showNotesForLinkedFile:(id)sender;

- (IBAction)copyNotesForLinkedFile:(id)sender;

/*!
    @method     updateSafariRecentDownloadsMenu:
    @abstract   Updates the menu of items for local paths of recent downloads from Safari.
    @discussion (comprehensive description)
*/
- (void)updateSafariRecentDownloadsMenu:(NSMenu *)menu;

/*!
    @method     updateSafariRecentURLsMenu:
    @abstract   Updates the menu off items for remote URLs of recent downloads from Safari.
    @discussion (comprehensive description)
*/
- (void)updateSafariRecentURLsMenu:(NSMenu *)menu;

/*!
    @method     updatePreviewRecentDocumentsMenu:
    @abstract   Updates the menu of items for local paths of recent documents from Preview.
    @discussion (comprehensive description)
*/
- (void)updatePreviewRecentDocumentsMenu:(NSMenu *)menu;

/*!
    @method     recentDownloadsMenu
    @abstract   Returns a menu of modified files in the system download directory using Spotlight.
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSMenu *)recentDownloadsMenu;

/*!
    @method     addLinkedFileFromMenuItem
    @abstract   Action to select a local file path from a menu item.
    @discussion (comprehensive description)
*/
- (void)addLinkedFileFromMenuItem:(NSMenuItem *)sender;

/*!
    @method     addRemoteURLFromMenuItem
    @abstract   Action to select a remote URL from a menu item.
    @discussion (comprehensive description)
*/
- (void)addRemoteURLFromMenuItem:(NSMenuItem *)sender;

/*!
    @method     showCiteKeyWarning:
    @abstract   Action of the cite-key warning button. Shows the error string in an alert panel.
    @discussion (comprehensive description)
*/
- (IBAction)showCiteKeyWarning:(id)sender;

/*!
    @method     updateCiteKeyDuplicateWarning
    @abstract   Method to (un)set a warning to the user that the cite-key is a duplicate in te document. 
    @discussion (comprehensive description)
*/
- (void)updateCiteKeyDuplicateWarning;

/*!
    @method     bibTypeDidChange:
    @abstract   Action of a form field to set a new value for a bibliography field.
    @discussion (comprehensive description)
*/
- (IBAction)bibTypeDidChange:(id)sender;
/*!
    @method     updateTypePopup
    @abstract   Update the type popup menu based on the current bibitem's type.  Needed for dragging support (see BDSKDragWindow.m).
    @discussion (comprehensive description)
*/
- (void)updateTypePopup;
- (void)bibWasAddedOrRemoved:(NSNotification *)notification;

- (IBAction)changeRating:(id)sender;
- (IBAction)changeFlag:(id)sender;

/*!
    @method     generateCiteKey:
    @abstract   Action to generate a cite-key for the bibitem, using the cite-key format string. 
    @discussion (comprehensive description)
*/
- (IBAction)generateCiteKey:(id)sender;

/*!
    @method     consolidateLinkedFiles:
    @abstract   Action to auto file the linked paper, using the local-url format string. 
    @discussion (comprehensive description)
*/
- (IBAction)consolidateLinkedFiles:(id)sender;

/*!
    @method     duplicateTitleToBooktitle:
    @abstract   Action to copy the title field to the booktitle field. Overwrites the booktitle field.
    @discussion (comprehensive description)
*/
- (IBAction)duplicateTitleToBooktitle:(id)sender;

- (NSString *)keyField;
- (void)setKeyField:(NSString *)fieldName;

- (void)bibDidChange:(NSNotification *)notification;
- (void)typeInfoDidChange:(NSNotification *)aNotification;
- (void)customFieldsDidChange:(NSNotification *)aNotification;
- (void)fileURLDidChange:(NSNotification *)notification;

- (void)bibWillBeRemoved:(NSNotification *)notification;
- (void)groupWillBeRemoved:(NSNotification *)notification;

/*!
	@method     openParentItemForField:
	@abstract   opens an editor for the crossref parent item.
	@discussion (description)
*/
- (void)openParentItemForField:(NSString *)field;

- (IBAction)selectCrossrefParentAction:(id)sender;
- (IBAction)createNewPubUsingCrossrefAction:(id)sender;

- (void)editInheritedAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (NSUndoManager *)undoManager;

#pragma mark Person controller

/*!
    @method     showPersonDetail:
	 @abstract   opens a BDSKPersonController to show details of a pub
	 @discussion (description)
*/
- (IBAction)showPersonDetailCmd:(id)sender;
- (void)showPersonDetail:(BibAuthor *)person;

#pragma mark Macro support
    
/*!
    @method     editSelectedFormCellAsMacro
    @abstract   pops up a window above the form cell with extra info about a macro.
    @discussion (description)
*/
- (BOOL)editSelectedFormCellAsMacro;
- (void)macrosDidChange:(NSNotification *)aNotification;

@end


@interface BDSKTabView : NSTabView {}
@end

