//  BibDocument_DataSource.h
//  Created by Michael McCracken on Tue Mar 26 2002.
/*
 This software is Copyright (c) 2002-2012
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

#import <Cocoa/Cocoa.h>
#import "BibDocument.h"
#import "BDSKMainTableView.h"
#import "BDSKGroupOutlineView.h"
#import <FileView/FileView.h>

/*! @category  BibDocument(DataSource)
@discussion Additions to BibDocument for handling table views.
*/
@interface BibDocument (DataSource) <BDSKMainTableViewDelegate, BDSKMainTableViewDataSource, BDSKGroupOutlineViewDelegate, NSOutlineViewDataSource, FVFileViewDelegate, FVFileViewDataSource>

- (BOOL)writePublications:(NSArray*)pubs forDragCopyType:(NSInteger)dragCopyType toPasteboard:(NSPasteboard*)pboard;
- (BOOL)writePublications:(NSArray*)pubs fileNames:(NSArray *)fileNames forDragCopyType:(NSInteger)dragCopyType toPasteboard:(NSPasteboard*)pboard;
- (BOOL)writePublications:(NSArray*)pubs forDragCopyType:(NSInteger)dragCopyType citeString:(NSString *)citeString toPasteboard:(NSPasteboard*)pboard;
- (BOOL)writePublications:(NSArray*)pubs fileNames:(NSArray *)fileNames forDragCopyType:(NSInteger)dragCopyType citeString:(NSString *)citeString toPasteboard:(NSPasteboard*)pboard;
- (NSImage *)dragImageForPromisedItemsUsingCiteString:(NSString *)citeString;
- (void)clearPromisedDraggedItems;
- (NSDictionary *)currentTableColumnWidthsAndIdentifiers;
- (BOOL)isDragFromExternalGroups;
- (void)setDragFromExternalGroups:(BOOL)flag;
- (BOOL)selectItemsInAuxFileAtPath:(NSString *)auxPath;

@end
