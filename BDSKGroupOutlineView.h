//
//  BDSKGroupOutlineView.h
//  Bibdesk
//
//  Created by Adam Maxwell on 10/19/05.
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
#import "BDSKOutlineView.h"

@class BDSKGroupOutlineView;

@protocol BDSKGroupOutlineViewDelegate <BDSKOutlineViewDelegate>
- (NSIndexSet *)outlineView:(BDSKGroupOutlineView *)anOutlineView indexesOfRowsToHighlightInRange:(NSRange)indexRange;
- (BOOL)outlineView:(BDSKGroupOutlineView *)anOutlineView isSingleSelectionItem:(id)item;
- (void)outlineView:(BDSKGroupOutlineView *)anOutlineView doubleClickedOnIconOfItem:(id)item;
- (BOOL)outlineViewShouldEditNextItemWhenEditingEnds:(BDSKGroupOutlineView *)anOutlineView;
@end


@interface BDSKGroupOutlineView : BDSKOutlineView {
    NSTextFieldCell *parentCell;
}

- (NSTextFieldCell *)parentCell;

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKGroupOutlineViewDelegate>)delegate;
- (void)setDelegate:(id <BDSKGroupOutlineViewDelegate>)newDelegate;
#endif

@end
