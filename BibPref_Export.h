//
//  BibPref_Export.h
//  Bibdesk
//
//  Created by Adam Maxwell on 05/18/06.
/*
 This software is Copyright (c) 2006-2012
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
#import "BDSKPreferencePane.h"
#import "BDSKOutlineView.h"

enum {
    BDSKExportTemplateList = 0,
    BDSKServiceTemplateList = 1
};
typedef NSUInteger BDSKTemplateListType;

@class BDSKTemplateOutlineView;

@protocol BDSKTemplateOutlineViewDelegate <BDSKOutlineViewDelegate>
@optional
- (BOOL)outlineViewShouldEditNextItemWhenEditingEnds:(BDSKTemplateOutlineView *)anOutlineView;
@end


@interface BDSKTemplateOutlineView : BDSKOutlineView
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKTemplateOutlineViewDelegate>)delegate;
- (void)setDelegate:(id <BDSKTemplateOutlineViewDelegate>)newDelegate;
#endif
@end


@interface BibPref_Export : BDSKPreferencePane <NSOutlineViewDelegate, NSOutlineViewDataSource> {
    IBOutlet NSOutlineView *outlineView;
    NSMutableArray *itemNodes;
    NSMutableArray *roles;    
    NSArray *fileTypes;    
    BDSKTemplateListType templatePrefList;
    IBOutlet NSSegmentedControl *addRemoveButton;
    IBOutlet NSMatrix *prefListRadio;
    IBOutlet NSWindow *chooseMainPageSheet;
    IBOutlet NSPopUpButton *chooseMainPagePopup;
}

- (IBAction)changePrefList:(id)sender;

- (IBAction)resetDefaultFiles:(id)sender;

- (IBAction)addRemoveNode:(id)sender;

- (IBAction)revealInFinder:(id)sender;
- (IBAction)chooseFile:(id)sender;
- (IBAction)chooseFileDoubleAction:(id)sender;

- (IBAction)dismissChooseMainPageSheet:(id)sender;

@end
