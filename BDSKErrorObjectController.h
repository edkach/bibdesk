//
//  BDSKErrorObjectController.h
//  Bibdesk
//
//  Created by Adam Maxwell on 08/12/05.
/*
 This software is Copyright (c) 2005-2012
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

@class BibDocument, BibItem, BDSKErrorObject, BDSKErrorManager, BDSKErrorEditor, BDSKFilteringArrayController, BDSKTableView;

@interface BDSKErrorObjectController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource> {
    NSMutableArray *errors;
    NSMutableArray *managers;
    NSMutableArray *currentErrors;
    
    NSUInteger lastIndex;
    
    // error-handling stuff:
    IBOutlet BDSKTableView *errorTableView;
    IBOutlet BDSKFilteringArrayController *errorsController;
    BOOL handledNonIgnorableError;
}

+ (BDSKErrorObjectController *)sharedErrorObjectController;

- (NSArray *)errors;
- (NSUInteger)countOfErrors;
- (id)objectInErrorsAtIndex:(NSUInteger)index;
- (void)insertObject:(id)obj inErrorsAtIndex:(NSUInteger)index;
- (void)removeObjectFromErrorsAtIndex:(NSUInteger)index;

- (NSArray *)managers;
- (NSUInteger)countOfManagers;
- (id)objectInManagersAtIndex:(NSUInteger)theIndex;
- (void)insertObject:(id)obj inManagersAtIndex:(NSUInteger)theIndex;
- (void)removeObjectFromManagersAtIndex:(NSUInteger)theIndex;
- (void)addManager:(BDSKErrorManager *)manager;
- (void)removeManager:(BDSKErrorManager *)manager;

// called from the tableView doubleclick
- (void)showEditorForErrorObject:(BDSKErrorObject *)errObj;
// called to edit a failed paste/drag or revert
- (void)showEditorForLastErrors;

- (void)documentFailedLoad:(BibDocument *)document shouldEdit:(BOOL)shouldEdit;
- (void)handleRemoveDocumentNotification:(NSNotification *)notification;
- (void)handleRemovePublicationNotification:(NSNotification *)notification;
- (void)removeErrorsForPublications:(NSArray *)pubs;
- (void)removeErrorsForEditor:(BDSKErrorEditor *)editor;

// tableView actions
- (IBAction)copy:(id)sender;
- (IBAction)gotoError:(id)sender;

// any use of btparse should be bracketed by a pair of startObservingErrors/endObservingErrorsFor... calls
- (void)startObservingErrors;
- (void)endObservingErrorsForPublication:(BibItem *)pub;
- (void)endObservingErrorsForDocument:(BibDocument *)document pasteDragData:(NSData *)data;

- (void)reportError:(BDSKErrorObject *)error;

@end

#pragma mark -

@interface BDSKFilteringArrayController : NSArrayController {
    BDSKErrorManager *filterManager;
    BOOL hideWarnings;
}

- (BDSKErrorManager *)filterManager;
- (void)setFilterManager:(BDSKErrorManager *)manager;
- (BOOL)hideWarnings;
- (void)setHideWarnings:(BOOL)flag;

@end
