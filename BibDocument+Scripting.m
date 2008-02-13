//
//  BibDocument+Scripting.m
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 08 2004.
/*
 This software is Copyright (c) 2004-2008
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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
#import "BibDocument+Scripting.h"
#import "BibDocument_Groups.h"
#import "BibAuthor.h"
#import "BibItem.h"
#import "BDSKMacro.h"
#import "BDSKTeXTask.h"
#import "BDSKItemPasteboardHelper.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKPublicationsArray.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKWebGroup.h"
#import "BDSKGroupsArray.h"
#import "NSObject_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKMacroResolver.h"
#import "BDSKMacroResolver+Scripting.h"
#import "BDSKPreviewer.h"
#import "BibAuthor.h"
#import "BibAuthor+Scripting.h"
#import "BDSKTypeManager.h"
#import <Quartz/Quartz.h>
#import <OmniFoundation/OFCFCallbacks.h>


const CFArrayCallBacks BDSKCaseInsensitiveStringArrayCallBacks = {
    0,
    OFNSObjectRetain,
    OFCFTypeRelease,
    OFCFTypeCopyDescription,
    OFCaseInsensitiveStringIsEqual
};

@implementation BibDocument (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

// fix a bug in Apple's implementation, which ignores the file type (for export)
- (id)handleSaveScriptCommand:(NSScriptCommand *)command {
	NSDictionary *args = [command evaluatedArguments];
    id fileURL = [args objectForKey:@"File"];
    id fileType = [args objectForKey:@"FileType"];
    if ([fileType isEqualToString:@"BibTeX"]) {
        fileType = BDSKBibTeXDocumentType;
        NSMutableDictionary *arguments = [[command arguments] mutableCopy];
        [arguments setObject:fileType forKey:@"FileType"];
        [command setArguments:arguments];
        [arguments release];
    } else if ([fileType isEqualToString:@"Minimal BibTeX"]) {
        fileType = BDSKMinimalBibTeXDocumentType;
        NSMutableDictionary *arguments = [[command arguments] mutableCopy];
        [arguments setObject:fileType forKey:@"FileType"];
        [command setArguments:arguments];
        [arguments release];
    } else if ([fileType isEqualToString:@"RIS"]) {
        fileType = BDSKRISDocumentType;
        NSMutableDictionary *arguments = [[command arguments] mutableCopy];
        [arguments setObject:fileType forKey:@"FileType"];
        [command setArguments:arguments];
        [arguments release];
    }
    if ([fileType isEqualToString:@"BibTeX"]) {
        fileType = BDSKBibTeXDocumentType;
        NSMutableDictionary *arguments = [[command arguments] mutableCopy];
        [arguments setObject:fileType forKey:@"FileType"];
        [command setArguments:arguments];
        [arguments release];
    }
    if (fileURL) {
        if ([fileURL isKindOfClass:[NSURL class]] == NO) {
            [command setScriptErrorNumber:NSArgumentsWrongScriptError];
            [command setScriptErrorString:@"The file is not a file or alias."];
        } else {
            NSArray *fileExtensions = [[NSDocumentController sharedDocumentController] fileExtensionsFromType:fileType ? fileType : [self fileType]];
            NSString *extension = [[fileURL path] pathExtension];
            if (extension == nil) {
                extension = [fileExtensions objectAtIndex:0];
                fileURL = [NSURL fileURLWithPath:[[fileURL path] stringByAppendingPathExtension:extension]];
            }
            if ([fileExtensions containsObject:[extension lowercaseString]] == NO) {
                [command setScriptErrorNumber:NSArgumentsWrongScriptError];
                [command setScriptErrorString:[NSString stringWithFormat:@"Invalid file extension for this file type."]];
            } else if (fileType) {
                if ([self saveToURL:fileURL ofType:fileType forSaveOperation:NSSaveToOperation error:NULL] == NO) {
                    [command setScriptErrorNumber:NSInternalScriptError];
                    [command setScriptErrorString:@"Unable to export."];
                }
            } else if ([self saveToURL:fileURL ofType:[self fileType] forSaveOperation:NSSaveAsOperation error:NULL] == NO) {
                [command setScriptErrorNumber:NSInternalScriptError];
                [command setScriptErrorString:@"Unable to save."];
            }
        }
    } else if (fileType) {
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
        [command setScriptErrorString:@"Missing file argument."];
    } else {
        return [super handleSaveScriptCommand:command];
    }
    return nil;
}

- (id)handlePrintScriptCommand:(NSScriptCommand *)command {
    if([currentPreviewView isEqual:previewerBox] || [currentPreviewView isEqual:previewBox]) {
        // we let the PDFView handle printing
        
        NSDictionary *args = [command evaluatedArguments];
        id settings = [args objectForKey:@"PrintSettings"];
        // PDFView does not allow printing without showing the dialog, so we just ignore that setting
        
        NSPrintInfo *printInfo = [self printInfo];
        PDFView *pdfView = (PDFView *)[(NSBox *)currentPreviewView contentView];
        
        if ([settings isKindOfClass:[NSDictionary class]]) {
            settings = [[settings mutableCopy] autorelease];
            id value;
            if (value = [settings objectForKey:NSPrintDetailedErrorReporting])
                [settings setObject:[NSNumber numberWithBool:[value intValue] == 'lwdt'] forKey:NSPrintDetailedErrorReporting];
            if ((value = [settings objectForKey:NSPrintPrinterName]) && (value = [NSPrinter printerWithName:value]))
                [settings setObject:value forKey:NSPrintPrinter];
            if ([settings objectForKey:NSPrintFirstPage] || [settings objectForKey:NSPrintLastPage]) {
                [settings setObject:[NSNumber numberWithBool:NO] forKey:NSPrintAllPages];
                if ([settings objectForKey:NSPrintFirstPage] == nil)
                    [settings setObject:[NSNumber numberWithInt:1] forKey:NSPrintLastPage];
                if ([settings objectForKey:NSPrintLastPage] == nil)
                    [settings setObject:[NSNumber numberWithInt:[[pdfView document] pageCount]] forKey:NSPrintLastPage];
            }
            [[printInfo dictionary] addEntriesFromDictionary:settings];
        }
        
        [pdfView printWithInfo:printInfo autoRotate:NO];
        
        return nil;
    } else {
        return [super handlePrintScriptCommand:command];
    }
}

#pragma mark Publications

- (unsigned int)countOfPublications {
    return [[self publications] count];
}

- (BibItem *)objectInPublicationsAtIndex:(unsigned int)idx {
    return [self valueInPublicationsAtIndex:idx];
}

- (BibItem *)valueInPublicationsAtIndex:(unsigned int)idx {
    return [publications objectAtIndex:idx];
}

- (void)insertInPublications:(BibItem *)pub  atIndex:(unsigned int)idx {
	if ([pub owner] == nil) {
        [self insertPublication:pub atIndex:idx];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([[pub owner] isEqual:self] == NO) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add publication from another document or external group, use duplicate.",@"Error description")];
    } 
}

- (void)insertInPublications:(BibItem *)pub {
	if ([pub owner] == nil) {
        [self addPublication:pub];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([[pub owner] isEqual:self] == NO) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add publication from another document or external group.",@"Error description")];
    } 
}

- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx {
    return [self insertInPublications:pub atIndex:idx];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {log_method();
	[self removePublicationsAtIndexes:[NSIndexSet indexSetWithIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx {
    return [self removeFromPublicationsAtIndex:idx];
}

#pragma mark Macros

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

#pragma mark Authors and Editors

- (NSArray *)authors {
    return [BibAuthor authorsInPublications:[self publications]];
}

- (BibAuthor *)valueInAuthorsWithName:(NSString *)aName {
    return [BibAuthor authorWithName:aName inPublications:[self publications]];
}

- (NSArray *)editors {
    return [BibAuthor editorsInPublications:[self publications]];
}

- (BibAuthor *)valueInEditorsWithName:(NSString *)aName {
    return [BibAuthor editorWithName:aName inPublications:[self publications]];
}

#pragma mark Groups

- (unsigned int)countOfGroups {
    return [groups count];
}

- (BDSKGroup *)valueInGroupsAtIndex:(unsigned int)idx {
    return [groups objectAtIndex:idx];
}

- (BDSKGroup *)objectInGroupsAtIndex:(unsigned int)idx {
    return [self valueInGroupsAtIndex:idx];
}

- (BDSKGroup *)valueInGroupsWithName:(NSString *)name {
    NSArray *names = [groups valueForKey:@"stringValue"];
    unsigned int idx = [names indexOfObject:name];
    if (idx == NSNotFound) {
        NSMutableArray *fuzzyNames = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, [names count], &BDSKCaseInsensitiveStringArrayCallBacks);
        [fuzzyNames addObjectsFromArray:names];
        idx = [fuzzyNames indexOfObject:name];
        [fuzzyNames release];
    }
    return idx == NSNotFound ? nil : [groups objectAtIndex:idx];
}

- (void)insertInGroups:(BDSKGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
        return;
    } else if ([group isSmart] == YES) {
        [groups addSmartGroup:(BDSKSmartGroup *)group];
    } else if ([group isStatic] == YES && [group isKindOfClass:[BDSKLastImportGroup class]] == NO) {
        [groups addStaticGroup:(BDSKStaticGroup *)group];
    } else if ([group isURL] == YES) {
        [groups addURLGroup:(BDSKURLGroup *)group];
    } else if ([group isScript] == YES) {
        [groups addScriptGroup:(BDSKScriptGroup *)group];
    } else if ([group isSearch] == YES) {
        [groups addSearchGroup:(BDSKSearchGroup *)group];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
        return;
    }
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)insertInGroups:(BDSKGroup *)group atIndex:(unsigned int)idx {
    [self insertInGroups:group];
}

- (void)insertObject:(BDSKGroup *)group inGroupsAtIndex:(unsigned int)idx {
    [self insertInGroups:group];
}

- (void)removeFromGroupsAtIndex:(unsigned int)idx {
    BDSKGroup *group = [[groups staticGroups] objectAtIndex:idx];
    if ([group isSmart] == YES) {
        [groups removeSmartGroup:(BDSKSmartGroup *)group];
    } else if ([group isStatic] == YES && [group isEqual:[groups lastImportGroup]] == NO) {
        [groups removeStaticGroup:(BDSKStaticGroup *)group];
    } else if ([group isURL] == YES) {
        [groups removeURLGroup:(BDSKURLGroup *)group];
    } else if ([group isScript] == YES) {
        [groups removeScriptGroup:(BDSKScriptGroup *)group];
    } else if ([group isSearch] == YES) {
        [groups removeSearchGroup:(BDSKSearchGroup *)group];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot remove group.",@"Error description")];
        return;
    }
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    [self displaySelectedGroups];
}

- (void)removeObjectFromGroupsAtIndex:(unsigned int)idx {
    return [self removeFromGroupsAtIndex:idx];
}

#pragma mark -

- (unsigned int)countOfStaticGroups {
    return [[groups staticGroups] count];
}

- (BDSKStaticGroup *)valueInStaticGroupsAtIndex:(unsigned int)idx {
    return [[groups staticGroups] objectAtIndex:idx];
}

- (BDSKStaticGroup *)objectInStaticGroupsAtIndex:(unsigned int)idx {
    return [self valueInStaticGroupsAtIndex:idx];
}

- (BDSKStaticGroup *)valueInStaticGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups staticGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups staticGroups] objectAtIndex:idx];
}

- (void)insertInStaticGroups:(BDSKStaticGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addStaticGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertInStaticGroups:(BDSKStaticGroup *)group atIndex:(unsigned int)idx {
    [self insertInStaticGroups:group];
}

- (void)insertObject:(BDSKStaticGroup *)group inStaticGroupsAtIndex:(unsigned int)idx {
    [self insertInStaticGroups:group];
}

- (void)removeFromStaticGroupsAtIndex:(unsigned int)idx {
	[groups removeStaticGroup:[[groups staticGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromStaticGroupsAtIndex:(unsigned int)idx {
    return [self removeFromStaticGroupsAtIndex:idx];
}

#pragma mark -

- (unsigned int)countOfSmartGroups {
    return [[groups smartGroups] count];
}

- (BDSKSmartGroup *)valueInSmartGroupsAtIndex:(unsigned int)idx {
    return [[groups smartGroups] objectAtIndex:idx];
}

- (BDSKSmartGroup *)objectInSmartGroupsAtIndex:(unsigned int)idx {
    return [self valueInSmartGroupsAtIndex:idx];
}

- (BDSKSmartGroup *)valueInSmartGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups smartGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups smartGroups] objectAtIndex:idx];
}

- (void)insertInSmartGroups:(BDSKSmartGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addSmartGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertInSmartGroups:(BDSKSmartGroup *)group atIndex:(unsigned int)idx {
    [self insertInSmartGroups:group];
}

- (void)insertObject:(BDSKSmartGroup *)group inSmartGroupsAtIndex:(unsigned int)idx {
    [self insertInSmartGroups:group];
}

- (void)removeFromSmartGroupsAtIndex:(unsigned int)idx {
	[groups removeSmartGroup:[[groups smartGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromSmartGroupsAtIndex:(unsigned int)idx {
    return [self removeFromSmartGroupsAtIndex:idx];
}

#pragma mark -

- (unsigned int)countOfFieldGroups {
    return [[groups categoryGroups] count];
}

- (BDSKCategoryGroup *)valueInFieldGroupsAtIndex:(unsigned int)idx {
    return [[groups categoryGroups] objectAtIndex:idx];
}

- (BDSKCategoryGroup *)objectInFieldGroupsAtIndex:(unsigned int)idx {
    return [self valueInFieldGroupsAtIndex:idx];
}

- (BDSKCategoryGroup *)valueInFieldGroupsWithName:(NSString *)name {
    id field = [self currentGroupField];
    NSArray *names = [[groups categoryGroups] valueForKey:@"name"];
    id fuzzyName = name;
    NSMutableArray *fuzzyNames = nil;
    if ([field isPersonField]) {
        fuzzyNames = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, [names count], &BDSKAuthorFuzzyArrayCallBacks);
        fuzzyName = [NSString isEmptyString:name] ? [BibAuthor emptyAuthor] : [BibAuthor authorWithName:name andPub:nil];
    } else {
        fuzzyNames = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, [names count], &BDSKCaseInsensitiveStringArrayCallBacks);
    }
    [fuzzyNames addObjectsFromArray:names];
    unsigned int idx = [fuzzyNames indexOfObject:fuzzyName];
    [fuzzyNames release];
    return idx == NSNotFound ? nil : [[groups categoryGroups] objectAtIndex:idx];
}

#pragma mark -

- (unsigned int)countOfExternalFileGroups {
    return [[groups URLGroups] count];
}

- (BDSKURLGroup *)valueInExternalFileGroupsAtIndex:(unsigned int)idx {
    return [[groups URLGroups] objectAtIndex:idx];
}

- (BDSKURLGroup *)objectInExternalFileGroupsAtIndex:(unsigned int)idx {
    return [self valueInExternalFileGroupsAtIndex:idx];
}

- (BDSKURLGroup *)valueInExternalFileGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups URLGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups URLGroups] objectAtIndex:idx];
}

- (void)insertInExternalFileGroups:(BDSKURLGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addURLGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertInExternalFileGroups:(BDSKURLGroup *)group atIndex:(unsigned int)idx {
    [self insertInExternalFileGroups:group];
}

- (void)insertObject:(BDSKURLGroup *)group inExternalFileGroupsAtIndex:(unsigned int)idx {
    [self insertInExternalFileGroups:group];
}

- (void)removeFromExternalFileGroupsAtIndex:(unsigned int)idx {
	[groups removeURLGroup:[[groups scriptGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromExternalFileGroupsAtIndex:(unsigned int)idx {
    return [self removeFromExternalFileGroupsAtIndex:idx];
}

#pragma mark -

- (unsigned int)countOfScriptGroups {
    return [[groups scriptGroups] count];
}

- (BDSKScriptGroup *)valueInScriptGroupsAtIndex:(unsigned int)idx {
    return [[groups scriptGroups] objectAtIndex:idx];
}

- (BDSKScriptGroup *)objectInScriptGroupsAtIndex:(unsigned int)idx {
    return [self valueInScriptGroupsAtIndex:idx];
}

- (BDSKScriptGroup *)valueInScriptGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups scriptGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups scriptGroups] objectAtIndex:idx];
}

- (void)insertInScriptGroups:(BDSKScriptGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addScriptGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertInScriptGroups:(BDSKScriptGroup *)group atIndex:(unsigned int)idx {
    [self insertInScriptGroups:group];
}

- (void)insertObject:(BDSKScriptGroup *)group inScriptGroupsAtIndex:(unsigned int)idx {
    [self insertInScriptGroups:group];
}

- (void)removeFromScriptGroupsAtIndex:(unsigned int)idx {
	[groups removeScriptGroup:[[groups scriptGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromScriptGroupsAtIndex:(unsigned int)idx {
    return [self removeFromScriptGroupsAtIndex:idx];
}

#pragma mark -

- (unsigned int)countOfSearchGroups {
    return [[groups searchGroups] count];
}

- (BDSKSearchGroup *)valueInSearchGroupsAtIndex:(unsigned int)idx {
    return [[groups searchGroups] objectAtIndex:idx];
}

- (BDSKSearchGroup *)objectInSearchGroupsAtIndex:(unsigned int)idx {
    return [self valueInSearchGroupsAtIndex:idx];
}

- (BDSKSearchGroup *)valueInSearchGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups searchGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups searchGroups] objectAtIndex:idx];
}

- (void)insertInSearchGroups:(BDSKSearchGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addSearchGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleSearch",@"Undo action name for AppleSearch")];
    }
}

- (void)insertInSearchGroups:(BDSKSearchGroup *)group atIndex:(unsigned int)idx {
    [self insertInSearchGroups:group];
}

- (void)insertObject:(BDSKSearchGroup *)group inSearchGroupsAtIndex:(unsigned int)idx {
    [self insertInSearchGroups:group];
}

- (void)removeFromSearchGroupsAtIndex:(unsigned int)idx {
	[groups removeSearchGroup:[[groups searchGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleSearch",@"Undo action name for AppleSearch")];
}

- (void)removeObjectFromSearchGroupsAtIndex:(unsigned int)idx {
    return [self removeFromSearchGroupsAtIndex:idx];
}

#pragma mark -

- (unsigned int)countOfSharedGroups {
    return [[groups sharedGroups] count];
}

- (BDSKSharedGroup *)valueInSharedGroupsAtIndex:(unsigned int)idx {
    return [[groups sharedGroups] objectAtIndex:idx];
}

- (BDSKSharedGroup *)objectInSharedGroupsAtIndex:(unsigned int)idx {
    return [self valueInSharedGroupsAtIndex:idx];
}

- (BDSKSharedGroup *)valueInSharedGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups sharedGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups sharedGroups] objectAtIndex:idx];
}

#pragma mark -

- (unsigned int)countOfLibraryGroups {
    return 1;
}

- (BDSKGroup *)valueInLibraryGroupsAtIndex:(unsigned int)idx {
    return [[self groups] libraryGroup];
}

- (BDSKGroup *)objectInLibraryGroupsAtIndex:(unsigned int)idx {
    return [[self groups] libraryGroup];
}

- (BDSKGroup *)valueInLibraryGroupsWithName:(NSString *)name {
    BDSKGroup *group = [[self groups] libraryGroup];
    return [[group name] caseInsensitiveCompare:name] == NSOrderedSame ? group : nil;
}

#pragma mark -

- (unsigned int)countOfLastImportGroups {
    BDSKGroup *group = [[self groups] lastImportGroup];
    return [group count] ? 1 : 0;
}

- (BDSKGroup *)valueInLastImportGroupsAtIndex:(unsigned int)idx {
    return [[self groups] lastImportGroup];
}

- (BDSKGroup *)objectInLastImportGroupsAtIndex:(unsigned int)idx {
    return [[self groups] lastImportGroup];
}

- (BDSKGroup *)valueInLastImportGroupsWithName:(NSString *)name {
    BDSKGroup *group = [[self groups] lastImportGroup];
    return [[group name] caseInsensitiveCompare:name] == NSOrderedSame && [group count] ? group : nil;
}

#pragma mark -

- (unsigned int)countOfWebGroups {
    return [[self groups] webGroup] ? 1 : 0;
}

- (BDSKWebGroup *)valueInWebGroupsAtIndex:(unsigned int)idx {
    return [[self groups] webGroup];
}

- (BDSKWebGroup *)objectInWebGroupsAtIndex:(unsigned int)idx {
    return [[self groups] webGroup];
}

- (BDSKWebGroup *)valueInWebGroupsWithName:(NSString *)name {
    BDSKWebGroup *group = [[self groups] webGroup];
    return [[group name] caseInsensitiveCompare:name] == NSOrderedSame ? group : nil;
}

#pragma mark Properties

- (NSArray *)selection { 
    return [self selectedPublications];
}

- (void)setSelection:(NSArray *)newSelection {
	// on Tiger: debugging revealed that we get an array of NSIndexSpecifiers and not of BibItem
    // the index is relative to all the publications the document (AS container), not the shownPublications
	NSArray *pubsToSelect = newSelection;
    id lastObject = [newSelection lastObject];
    if ([lastObject isKindOfClass:[BibItem class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
        pubsToSelect = [newSelection arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
	[self selectPublications:pubsToSelect];
}

- (NSArray *)groupSelection { 
    return [self selectedGroups];
}

- (void)setGroupSelection:(NSArray *)newSelection {
	// on Tiger: debugging revealed that we get an array of NSIndexSpecifiers and not of BibItem
    // the index is relative to all the publications the document (AS container), not the shownPublications
    NSArray *groupsToSelect = newSelection;
    id lastObject = [newSelection lastObject];
    if ([lastObject isKindOfClass:[BDSKGroup class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
        groupsToSelect = [newSelection arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
    [self selectGroups:groupsToSelect];
}

- (NSTextStorage*) textStorageForPublications:(NSArray *)pubs {
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    [pboardHelper declareType:NSRTFPboardType dragCopyType:BDSKRTFDragCopyType forItems:pubs forPasteboard:pboard];
    NSData *data = [pboard dataForType:NSRTFPboardType];
    [pboardHelper clearPromisedTypesForPasteboard:pboard];
    
    if(data == nil) return [[[NSTextStorage alloc] init] autorelease];
    	
	return [[[NSTextStorage alloc] initWithRTF:data documentAttributes:NULL] autorelease];
}

- (id)clipboard {
    NSScriptClassDescription *containerClassDescription = (NSScriptClassDescription *)[NSClassDescription classDescriptionForClass:[NSApp class]];
    return [[[NSPropertySpecifier allocWithZone: [self zone]] 
          initWithContainerClassDescription: containerClassDescription 
                         containerSpecifier: nil // the application is the null container
                                        key: @"clipboard"] autorelease];
}

#pragma mark -

// The following "indicesOf..." methods are in support of scripting.  They allow more flexible range and relative specifiers to be used with the different group keys of a SKTDrawDocument.
// The scripting engine does not know about the fact that the "static groups" key is really just a subset of the "groups" key, so script code like "groups from static group 1 to field group 4" don't make sense to it.  But BibDesk does know and can answer such questions itself, with a little work.
// This is copied from Apple's Sketch sample code
- (NSArray *)indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)rangeSpec {
    NSString *key = [rangeSpec key];
    NSSet *groupKeys = [NSSet setWithObjects:@"groups", @"staticGroups", @"smartGroups", @"fieldGroups", @"externalFileGroups", @"scriptGroups", @"searchGroups", @"sharedGroups", @"libraryGroups", @"lastImportGroups", @"webGroups", nil];

    if ([groupKeys containsObject:key]) {
        // This is one of the keys we might want to deal with.
        NSScriptObjectSpecifier *startSpec = [rangeSpec startSpecifier];
        NSScriptObjectSpecifier *endSpec = [rangeSpec endSpecifier];
        NSString *startKey = [startSpec key];
        NSString *endKey = [endSpec key];

        if ((startSpec == nil) && (endSpec == nil))
            // We need to have at least one of these...
            return nil;
        
        if ([groups count] == 0)
            // If there are no groups, there can be no match.  Just return now.
            return [NSArray array];

        if ((startSpec == nil || [groupKeys containsObject:startKey]) && (endSpec == nil || [groupKeys containsObject:endKey])) {
            int startIndex;
            int endIndex;

            // The start and end keys are also ones we want to handle.

            // The strategy here is going to be to find the index of the start and stop object in the full groups array, regardless of what its key is.  Then we can find what we're looking for in that range of the groups key (weeding out objects we don't want, if necessary).

            // First find the index of the first start object in the groups array
            if (startSpec) {
                id startObject = [startSpec objectsByEvaluatingSpecifier];
                if ([startObject isKindOfClass:[NSArray class]]) {
                    startObject = [startObject count] ? [startObject objectAtIndex:0] : nil;
                }
                if (startObject == nil)
                    // Oops.  We could not find the start object.
                    return nil;
                
                startIndex = [groups indexOfObjectIdenticalTo:startObject];
                if (startIndex == NSNotFound)
                    // Oops.  We couldn't find the start object in the groups array.  This should not happen.
                    return nil;
                
            } else {
                startIndex = 0;
            }

            // Now find the index of the last end object in the groups array
            if (endSpec) {
                id endObject = [endSpec objectsByEvaluatingSpecifier];
                if ([endObject isKindOfClass:[NSArray class]]) {
                    endObject = [endObject count] ? [endObject lastObject] : nil;
                }
                if (endObject == nil)
                    // Oops.  We could not find the end object.
                    return nil;
                
                endIndex = [groups indexOfObjectIdenticalTo:endObject];
                if (endIndex == NSNotFound)
                    // Oops.  We couldn't find the end object in the groups array.  This should not happen.
                    return nil;
                
            } else {
                endIndex = [groups count] - 1;
            }

            if (endIndex < startIndex) {
                // Accept backwards ranges gracefully
                int temp = endIndex;
                endIndex = startIndex;
                startIndex = temp;
            }

            // Now startIndex and endIndex specify the end points of the range we want within the groups array.
            // We will traverse the range and pick the objects we want.
            // We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
            NSMutableArray *result = [NSMutableArray array];
            BOOL keyIsGroups = [key isEqual:@"groups"];
            NSArray *rangeKeyObjects = (keyIsGroups ? nil : [self valueForKey:key]);
            id curObj;
            unsigned int curKeyIndex;
            int i;

            for (i = startIndex; i <= endIndex; i++) {
                if (keyIsGroups) {
                    [result addObject:[NSNumber numberWithInt:i]];
                } else {
                    curObj = [groups objectAtIndex:i];
                    curKeyIndex = [rangeKeyObjects indexOfObjectIdenticalTo:curObj];
                    if (curKeyIndex != NSNotFound)
                        [result addObject:[NSNumber numberWithInt:curKeyIndex]];
                }
            }
            return result;
        }
    }
    return nil;
}

- (NSArray *)indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)relSpec {
    NSString *key = [relSpec key];
    NSSet *groupKeys = [NSSet setWithObjects:@"groups", @"staticGroups", @"smartGroups", @"fieldGroups", @"externalFileGroups", @"scriptGroups", @"searchGroups", @"sharedGroups", @"libraryGroups", @"lastImportGroups", @"webGroups", nil];

    if ([groupKeys containsObject:key]) {
        // This is one of the keys we might want to deal with.
        NSScriptObjectSpecifier *baseSpec = [relSpec baseSpecifier];
        NSString *baseKey = [baseSpec key];
        NSRelativePosition relPos = [relSpec relativePosition];

        if (baseSpec == nil)
            // We need to have one of these...
            return nil;
        
        if ([groups count] == 0)
            // If there are no groups, there can be no match.  Just return now.
            return [NSArray array];

        if ([groupKeys containsObject:baseKey]) {
            int baseIndex;

            // The base key is also one we want to handle.

            // The strategy here is going to be to find the index of the base object in the full groups array, regardless of what its key is.  Then we can find what we're looking for before or after it.

            // First find the index of the first or last base object in the groups array
            // Base specifiers are to be evaluated within the same container as the relative specifier they are the base of.  That's this document.
            id baseObject = [baseSpec objectsByEvaluatingWithContainers:self];
            if ([baseObject isKindOfClass:[NSArray class]]) {
                if ([baseObject count] == 0)
                    // Oops.  We could not find the base object.
                    return nil;
                
                baseObject = (relPos == NSRelativeBefore ? [baseObject objectAtIndex:0] : [baseObject lastObject]);
            }

            baseIndex = [groups indexOfObjectIdenticalTo:baseObject];
            if (baseIndex == NSNotFound)
                // Oops.  We couldn't find the base object in the groups array.  This should not happen.
                return nil;

            // Now baseIndex specifies the base object for the relative spec in the groups array.
            // We will start either right before or right after and look for an object that matches the type we want.
            // We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
            NSMutableArray *result = [NSMutableArray array];
            BOOL keyIsGroups = [key isEqual:@"groups"];
            NSArray *relKeyObjects = (keyIsGroups ? nil : [self valueForKey:key]);
            id curObj;
            unsigned curKeyIndex;
            int groupCount = [groups count];

            if (relPos == NSRelativeBefore)
                baseIndex--;
            else
                baseIndex++;
            
            while ((baseIndex >= 0) && (baseIndex < groupCount)) {
                if (keyIsGroups) {
                    [result addObject:[NSNumber numberWithInt:baseIndex]];
                    break;
                } else {
                    curObj = [groups objectAtIndex:baseIndex];
                    curKeyIndex = [relKeyObjects indexOfObjectIdenticalTo:curObj];
                    if (curKeyIndex != NSNotFound) {
                        [result addObject:[NSNumber numberWithInt:curKeyIndex]];
                        break;
                    }
                }
                if (relPos == NSRelativeBefore)
                    baseIndex--;
                else
                    baseIndex++;
            }

            return result;
        }
    }
    return nil;
}
    
- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier {
    // We want to handle some range and relative specifiers ourselves in order to support such things as "groups from static group 3 to static group 5" or "static groups from groups 7 to groups 10" or "static group before smart group 1".
    // Returning nil from this method will cause the specifier to try to evaluate itself using its default evaluation strategy.
	
    if ([specifier isKindOfClass:[NSRangeSpecifier class]])
        return [self indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)specifier];
    else if ([specifier isKindOfClass:[NSRelativeSpecifier class]])
        return [self indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)specifier];

    // If we didn't handle it, return nil so that the default object specifier evaluation will do it.
    return nil;
}

@end
