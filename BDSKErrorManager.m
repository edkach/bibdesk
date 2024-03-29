//
//  BDSKErrorManager.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/30/06.
/*
 This software is Copyright (c) 2006-2012
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKErrorManager.h"
#import "BDSKErrorObjectController.h"
#import "BDSKErrorObject.h"
#import "BDSKErrorEditor.h"
#import "BibDocument.h"
#import "NSWindowController_BDSKExtensions.h"


static char BDSKErrorManagerObservationContext;

@implementation BDSKErrorManager 

+ (id)allItemsErrorManager;
{
    static BDSKErrorManager *allItemsErrorManager = nil;
    if(allItemsErrorManager == nil) {
        allItemsErrorManager = [[BDSKErrorManager alloc] init];
        [allItemsErrorManager setDocumentDisplayName:NSLocalizedString(@"All", @"Popup menu item for error window")];
    }
    return allItemsErrorManager;
}

- (id)initWithDocument:(BibDocument *)aDocument;
{
    if(self = [super init]){
        errorController = nil;
        editors = [[NSMutableArray alloc] initWithCapacity:3];
        [self setSourceDocument:aDocument];
        documentStringEncoding = aDocument ? [aDocument documentStringEncoding] : [NSString defaultCStringEncoding];
    }
    return self;
}

- (id)init;
{
    return [self initWithDocument:nil];
}

- (void)dealloc;
{
    [document removeObserver:self forKeyPath:@"fileURL"];
    [document removeObserver:self forKeyPath:@"documentStringEncoding"];
    BDSKDESTROY(document);
    BDSKDESTROY(editors);
    BDSKDESTROY(documentDisplayName);
    [super dealloc];
}

- (BDSKErrorObjectController *)errorController;
{
    return errorController;
}

- (void)setErrorController:(BDSKErrorObjectController *)newController;
{
    if(errorController != newController){
        errorController = newController;
        [self updateDisplayName];
    }
}

- (BibDocument *)sourceDocument;
{
    return document;
}

- (void)setSourceDocument:(BibDocument *)newDocument;
{
    if (document != newDocument) {
        if(document){
            [document removeObserver:self forKeyPath:@"fileURL"];
            [document removeObserver:self forKeyPath:@"documentStringEncoding"];
        }
        [document release];
        document = [newDocument retain];
        [self updateDisplayName];
        if(document){
            [document addObserver:self forKeyPath:@"fileURL" options:0 context:&BDSKErrorManagerObservationContext];
            [document addObserver:self forKeyPath:@"documentStringEncoding" options:0 context:&BDSKErrorManagerObservationContext];
        }
    }
}

- (NSInteger)uniqueNumber;
{
    return uniqueNumber;
}

- (NSString *)documentDisplayName;
{
    return documentDisplayName;
}

- (void)setDocumentDisplayName:(NSString *)newName;
{
    if(newName != documentDisplayName){
        [documentDisplayName release];
        documentDisplayName = [newName retain];
    }
}

- (NSString *)displayName;
{
    return (uniqueNumber == 0) ? documentDisplayName : [NSString stringWithFormat:@"%@ (%ld)", documentDisplayName, (long)uniqueNumber];
}


- (void)updateDisplayName;
{
    // if the document closes, we want to keep the display name
    if(document == nil)
        return;
    
    [self willChangeValueForKey:@"displayName"];
    
    NSString *name = [document displayName];
    [self setDocumentDisplayName:name ?: @"?"];
    
    uniqueNumber = 0;
    
    for (BDSKErrorManager *manager in [errorController managers]){
        if(manager != self && [[manager documentDisplayName] isEqualToString:documentDisplayName])
            uniqueNumber = MAX(uniqueNumber, [manager uniqueNumber] + 1);
    }
    
    [self didChangeValueForKey:@"displayName"];
}

- (NSStringEncoding)documentStringEncoding;
{
    return documentStringEncoding;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if (context == &BDSKErrorManagerObservationContext) {
        if(object == document && [keyPath isEqualToString:@"fileURL"])
            [self updateDisplayName];
        else if(object == document && document && [keyPath isEqualToString:@"documentStringEncoding"])
            documentStringEncoding = [document documentStringEncoding];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (BDSKErrorEditor *)mainEditor;
{
    return mainEditor;
}

- (NSArray *)editors;
{
    return editors;
}

- (void)addEditor:(BDSKErrorEditor *)editor;
{
    [editor setManager:self];
    [editors addObject:editor];
    if([editor isPasteDrag] == NO)
        mainEditor = editor;
}

- (void)removeEditor:(BDSKErrorEditor *)editor;
{
    [errorController removeErrorsForEditor:editor];
    if(mainEditor == editor)
        mainEditor = nil;
    [editor setManager:nil];
    [editors removeObject:editor];
    if([editors count] == 0)
        [errorController removeManager:self];
}

- (void)removeClosedEditors;
{
    NSUInteger idx = [editors count];
    BDSKErrorEditor *editor;
    
    while(idx--){
        editor = [editors objectAtIndex:idx];
        if([editor isWindowVisible] == NO)
            [self removeEditor:editor];
    }
}

@end
