//
//  BibDocument_Actions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/14/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BibDocument_Actions.h"
#import "BibDocument_DataSource.h"
#import "BibDocument_Groups.h"
#import "BibDocument_Search.h"
#import "BDSKStringConstants.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BDSKGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKPublicationsArray.h"
#import "BDSKGroupsArray.h"

#import "BDSKEditor.h"
#import "BDSKPersonController.h"
#import "BDSKDocumentInfoWindowController.h"
#import "BDSKMacroWindowController.h"
#import "BDSKNotesWindowController.h"

#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSView_BDSKExtensions.h"

#import "BDSKTypeManager.h"
#import "BDSKScriptHookManager.h"
#import "BDSKAlert.h"
#import "BDSKFiler.h"
#import "BDSKTextImportController.h"
#import "BDSKStatusBar.h"
#import "BDSKSharingServer.h"
#import "BDSKSharingBrowser.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"
#import "BDSKMainTableView.h"
#import "BDSKGroupTableView.h"
#import "BDSKGradientSplitView.h"
#import "NSTask_BDSKExtensions.h"
#import "BDSKColoredBox.h"
#import "BDSKStringParser.h"
#import "BDSKZoomablePDFView.h"
#import "BDSKCustomCiteDrawerController.h"
#import "NSObject_BDSKExtensions.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKPreviewer.h"
#import "BDSKFileMigrationController.h"
#import <sys/stat.h>
#import <FileView/FileView.h>
#import "BDSKMacro.h"
#import "BDSKAppController.h"
#import "BDSKApplication.h"

@implementation BibDocument (Actions)

static BOOL changingColors = NO;

#pragma mark -
#pragma mark Publication actions

- (void)addNewPubAndEdit:(BibItem *)newBI{
    // add the publication; addToGroup:handleInherited: depends on the pub having a document
    [self addPublication:newBI];

	[[self undoManager] setActionName:NSLocalizedString(@"Add Publication", @"Undo action name")];
	
    NSEnumerator *groupEnum = [[self selectedGroups] objectEnumerator];
	BDSKGroup *group;
	BOOL isSingleValued = [[self currentGroupField] isSingleValuedGroupField];
    int count = 0;
    // we don't overwrite inherited single valued fields, they already have the field set through inheritance
    int op, handleInherited = isSingleValued ? BDSKOperationIgnore : BDSKOperationAsk;
    
    while (group = [groupEnum nextObject]) {
		if ([group isCategory]){
            if (isSingleValued && count > 0)
                continue;
			op = [newBI addToGroup:group handleInherited:handleInherited];
            if(op == BDSKOperationSet || op == BDSKOperationAppend){
                count++;
            }else if(op == BDSKOperationAsk){
                BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")
                                                     defaultButton:NSLocalizedString(@"Don't Change", @"Button title")
                                                   alternateButton:nil // "Set" would end up choosing an arbitrary one
                                                       otherButton:NSLocalizedString(@"Append", @"Button title")
                                         informativeTextWithFormat:NSLocalizedString(@"The new item has a group value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
                handleInherited = [alert runSheetModalForWindow:documentWindow];
                if(handleInherited != BDSKOperationIgnore){
                    [newBI addToGroup:group handleInherited:handleInherited];
                    count++;
                }
            }
        } else if ([group isStatic]) {
            [(BDSKStaticGroup *)group addPublication:newBI];
        }
    }
	
	if (isSingleValued && [groups numberOfCategoryGroupsAtIndexes:[groupTableView selectedRowIndexes]] > 1) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Cannot Add to All Groups", @"Message in alert dialog when trying to add to multiple single-valued field groups")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The new item can only be added to one of the selected \"%@\" groups", @"Informative text in alert dialog"), [[self currentGroupField]localizedFieldName]];
        [alert beginSheetModalForWindow:documentWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
    
    [self selectPublication:newBI];
    [self editPub:newBI];
}

- (void)createNewPub{
    BibItem *newBI = [[[BibItem alloc] init] autorelease];
    [self addNewPubAndEdit:newBI];
}

- (void)createNewPubUsingCrossrefForItem:(BibItem *)item{
    BibItem *newBI = [[BibItem alloc] init];
	NSString *parentType = [item pubType];
    
	[newBI setField:BDSKCrossrefString toValue:[item citeKey]];
	if ([parentType isEqualToString:BDSKProceedingsString]) {
		[newBI setPubType:BDSKInproceedingsString];
	} else if ([parentType isEqualToString:BDSKBookString] || 
			   [parentType isEqualToString:BDSKBookletString] || 
			   [parentType isEqualToString:BDSKTechreportString] || 
			   [parentType isEqualToString:BDSKManualString]) {
		if (![[[NSUserDefaults standardUserDefaults] stringForKey:BDSKPubTypeStringKey] isEqualToString:BDSKInbookString]) 
			[newBI setPubType:BDSKIncollectionString];
	}
    [self addNewPubAndEdit:newBI];
    [newBI release];
}

- (IBAction)createNewPubUsingCrossrefAction:(id)sender{
    BibItem *selectedBI = [[self selectedPublications] lastObject];
    [self createNewPubUsingCrossrefForItem:selectedBI];
}

- (IBAction)newPub:(id)sender{
    if ([NSApp currentModifierFlags] & NSAlternateKeyMask) {
        [self createNewPubUsingCrossrefAction:sender];
    } else {
        [self createNewPub];
    }
}

- (void)removePubsAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if ([alert checkValue] == YES)
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKWarnOnRemovalFromGroupKey];
    if (returnCode == NSAlertDefaultReturn)
        [self removePublications:[self selectedPublications] fromGroups:[self selectedGroups]];
}

// this method is called for the main table; it's a wrapper for delete or remove from group
- (IBAction)removeSelectedPubs:(id)sender{
	NSArray *selectedGroups = [self selectedGroups];
	
	if([self hasLibraryGroupSelected]){
		[self deleteSelectedPubs:sender];
	}else{
		BOOL canRemove = NO;
        if ([self hasStaticGroupsSelected])
            canRemove = YES;
        else if ([[self currentGroupField] isSingleValuedGroupField] == NO)
            canRemove = [self hasCategoryGroupsSelected];
		if(canRemove == NO){
			NSBeep();
			return;
		}
        // the items may not belong to the groups that you're trying to remove them from, but we'll warn as if they were
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnRemovalFromGroupKey]) {
            NSString *groupName = ([selectedGroups count] > 1 ? NSLocalizedString(@"multiple groups", @"multiple groups") : [NSString stringWithFormat:NSLocalizedString(@"group \"%@\"", @"group \"Name\""), [[selectedGroups firstObject] stringValue]]);
            BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog")
                                                 defaultButton:NSLocalizedString(@"Yes", @"Button title")
                                               alternateButton:nil
                                                   otherButton:NSLocalizedString(@"No", @"Button title")
                                     informativeTextWithFormat:NSLocalizedString(@"You are about to remove %i %@ from %@.  Do you want to proceed?", @"Informative text in alert dialog: You are about to remove [number] item(s) from [group \"Name\"]."), [self numberOfSelectedPubs], ([self numberOfSelectedPubs] > 1 ? NSLocalizedString(@"items", @"") : NSLocalizedString(@"item", @"")), groupName];
            [alert setHasCheckButton:YES];
            [alert setCheckValue:NO];
            // use didDismissSelector because the action may pop up its own sheet
            [alert beginSheetModalForWindow:documentWindow
                              modalDelegate:self 
                             didEndSelector:NULL 
                         didDismissSelector:@selector(removePubsAlertDidEnd:returnCode:contextInfo:) 
                                contextInfo:NULL];
            return;
        } else {
            [self removePublications:[self selectedPublications] fromGroups:selectedGroups];
        }
	}
}

- (void)deletePubsAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (alert != nil && [alert checkValue] == YES)
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKWarnOnDeleteKey];
    if (returnCode == NSAlertOtherReturn)
        return;
    
    // deletion changes the scroll position
    NSTableView *tv = [self isDisplayingFileContentSearch] ? [fileSearchController tableView] : tableView;
	int numSelectedPubs = [self numberOfSelectedPubs];
    
    // This is preserved as an ivar; since removePublications: triggers an async search as a UI update, restoring the selection/scroll position here will no longer work if a search is active.  Storing a row is safe since sort order should be stable.
    rowToSelectAfterDelete = [[tv selectedRowIndexes] lastIndex];
    scrollLocationAfterDelete = [[tv enclosingScrollView] scrollPositionAsPercentage];
	[self removePublications:[self selectedPublications]];
    
    if([NSString isEmptyString:[self searchString]]) {
        if(rowToSelectAfterDelete >= [tv numberOfRows])
            rowToSelectAfterDelete = [tv numberOfRows] - 1;
        if(rowToSelectAfterDelete != -1)
            [tv selectRowIndexes:[NSIndexSet indexSetWithIndex:rowToSelectAfterDelete] byExtendingSelection:NO];
        rowToSelectAfterDelete = -1;
        [[tv enclosingScrollView] setScrollPositionAsPercentage:scrollLocationAfterDelete];
        scrollLocationAfterDelete = NSZeroPoint;
    }
    
	NSString * pubSingularPlural;
	if (numSelectedPubs == 1) {
		pubSingularPlural = NSLocalizedString(@"publication", @"publication, in status message");
	} else {
		pubSingularPlural = NSLocalizedString(@"publications", @"publications, in status message");
	}
	
	[[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Delete %@", @"Undo action name: Delete Publication(s)"),pubSingularPlural]];
}

- (IBAction)deleteSelectedPubs:(id)sender{
	int numSelectedPubs = [self numberOfSelectedPubs];
    if (numSelectedPubs == 0 ||
        [self hasExternalGroupsSelected] == YES) {
        return;
    }
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnDeleteKey]) {
        NSString *info;
        if (numSelectedPubs > 1)
            info = [NSString stringWithFormat:NSLocalizedString(@"You are about to delete %i publications. Do you want to proceed?", @"Informative text in alert dialog"), numSelectedPubs];
        else
            info = NSLocalizedString(@"You are about to delete a publication. Do you want to proceed?", @"Informative text in alert dialog");
		BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog")
											 defaultButton:NSLocalizedString(@"OK", @"Button title")
										   alternateButton:nil
											   otherButton:NSLocalizedString(@"Cancel", @"Button title")
								 informativeTextWithFormat:info];
		[alert setHasCheckButton:YES];
		[alert setCheckValue:NO];
        // use didDismissSelector because the action may pop up its own sheet
        [alert beginSheetModalForWindow:documentWindow
                          modalDelegate:self 
                         didEndSelector:NULL 
                     didDismissSelector:@selector(deletePubsAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
	} else {
        [self deletePubsAlertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:NULL];
    }
}

// -delete:,  -alternateDelete:, -copy:, -cut:, -alternateCut:, -paste:, and -duplicate are defined in BDSKTableView and BDSKMainTableView using dataSource methods

- (IBAction)copyAsAction:(id)sender{
	int copyType = [sender tag];
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	NSString *citeString = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKCiteStringKey];
	[self writePublications:[self selectedPublications] forDragCopyType:copyType citeString:citeString toPasteboard:pboard];
}

- (BDSKEditor *)editorForPublication:(BibItem *)pub create:(BOOL)createNew{
    BDSKEditor *editor = nil;
	NSEnumerator *wcEnum = [[self windowControllers] objectEnumerator];
	NSWindowController *wc;
	
	while(wc = [wcEnum nextObject]){
		if([wc isKindOfClass:[BDSKEditor class]] && [[(BDSKEditor*)wc publication] isEqual:pub]){
			editor = (BDSKEditor*)wc;
			break;
		}
	}
    if(editor == nil && createNew){
        editor = [[BDSKEditor alloc] initWithPublication:pub];
        [self addWindowController:editor];
        [editor release];
    }
    return editor;
}

- (BDSKEditor *)editPub:(BibItem *)pub{
    BDSKEditor *editor = [self editorForPublication:pub create:YES];
    [editor show];
    return editor;
}

- (BDSKEditor *)editPubBeforePub:(BibItem *)pub{
    unsigned int idx = [shownPublications indexOfObject:pub];
    if(idx == NSNotFound){
        NSBeep();
        return nil;
    }
    if(idx-- == 0)
        idx = [shownPublications count] - 1;
    return [self editPub:[shownPublications objectAtIndex:idx]];
}

- (BDSKEditor *)editPubAfterPub:(BibItem *)pub{
    unsigned int idx = [shownPublications indexOfObject:pub];
    if(idx == NSNotFound){
        NSBeep();
        return nil;
    }
    if(++idx == [shownPublications count])
        idx = 0;
    return [self editPub:[shownPublications objectAtIndex:idx]];
}

- (void)editPubAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSArray *pubs = (NSArray *)contextInfo;
    if (returnCode == NSAlertAlternateReturn) {
        [self performSelector:@selector(editPub:) withObjectsFromArray:pubs];
    }
    [pubs release];
}

- (void)editPublications:(NSArray *)pubs{
    int n = [pubs count];
    if (n > 6) {
        // Do we really want a gazillion of editor windows?
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Edit publications", @"Message in alert dialog when trying to open a lot of publication editors")
                                         defaultButton:NSLocalizedString(@"No", @"Button title")
                                      alternateButton:NSLocalizedString(@"Yes", @"Button title")
                                          otherButton:nil
                            informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to open %i editor windows.  Is this really what you want?" , @"Informative text in alert dialog"), n]];
        [alert beginSheetModalForWindow:documentWindow
                          modalDelegate:self
                         didEndSelector:@selector(editPubAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:[pubs retain]];
    } else {
        [self editPubAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[pubs retain]];
    }
}

- (IBAction)editPubCmd:(id)sender{
    NSArray *pubs = [self selectedPublications];
    [self editPublications:pubs];
}

- (void)editAction:(id)sender {
	id firstResponder = [documentWindow firstResponder];
    if (firstResponder == tableView || firstResponder == [fileSearchController tableView])
		[self editPubCmd:sender];
	else if (firstResponder == groupTableView)
		[self editGroupAction:sender];
}

- (IBAction)editPubOrOpenURLAction:(id)sender{
    int column = [tableView clickedColumn];
    NSString *colID = column != -1 ? [[[tableView tableColumns] objectAtIndex:column] identifier] : nil;
    
    if([colID isLocalFileField]) {
		[self openLocalURLForField:colID];
    } else if([colID isRemoteURLField]) {
		[self openRemoteURLForField:colID];
    } else if([colID isEqualToString:BDSKLocalFileString]) {
        BibItem *pub = [[self selectedPublications] lastObject];
        NSArray *fileURLs = [[pub localFiles] valueForKey:@"URL"];
        if ([fileURLs count])
            [self openLinkedFileAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:(void *)[fileURLs retain]];
    } else if([colID isEqualToString:BDSKRemoteURLString]) {
        BibItem *pub = [[self selectedPublications] lastObject];
        NSArray *theURLs = [[pub remoteURLs] valueForKey:@"URL"];
        if ([theURLs count])
            [self openLinkedURLAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:(void *)[theURLs retain]];
    } else if([colID isEqualToString:BDSKColorString] || [colID isEqualToString:BDSKColorLabelString]) {
        int row = [tableView clickedRow];
        NSColor *color = row != -1 ? [[[self shownPublications] objectAtIndex:row] color] : nil;
        if (color) {
            changingColors = YES;
            [[NSColorPanel sharedColorPanel] setColor:color];
            changingColors = NO;
        }
        [[NSColorPanel sharedColorPanel] makeKeyAndOrderFront:nil];
    } else {
        [self editPubCmd:sender];
    }
}

- (void)showPerson:(BibAuthor *)person{
    BDSKASSERT(person != nil && [person isKindOfClass:[BibAuthor class]]);
    BDSKPersonController *pc = nil;
	NSEnumerator *wcEnum = [[self windowControllers] objectEnumerator];
	NSWindowController *wc;
	
	while(wc = [wcEnum nextObject]){
		if([wc isKindOfClass:[BDSKPersonController class]] && [[(BDSKPersonController *)wc person] fuzzyEqual:person]){
			pc = (BDSKPersonController *)wc;
			break;
		}
	}
    
    if(pc == nil){
        pc = [[BDSKPersonController alloc] initWithPerson:person];
        [self addWindowController:pc];
        [pc release];
    }
    [pc show];
}

- (IBAction)emailPubCmd:(id)sender{
    NSArray *pubs = [self selectedPublications];
    NSMutableArray *items = [pubs mutableCopy];
    NSEnumerator *e = [[pubs valueForKeyPath:@"@unionOfArrays.localFiles"] objectEnumerator];
    BDSKLinkedFile *file;
    BibItem *pub;
    
    NSString *path = nil;
    NSMutableString *body = [NSMutableString string];
    NSMutableArray *files = [NSMutableArray array];
    
    NSString *templateName = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKEmailTemplateKey];
    BDSKTemplate *template = nil;
    
    if ([NSString isEmptyString:templateName] == NO)
        template = [BDSKTemplate templateForStyle:templateName];
    
    while (file = [e nextObject]) {
        if (path = [[file URL] path])
            [files addObject:path];
    }
    
    if (template != nil) {
        if ([template templateFormat] & BDSKRichTextTemplateFormat)
            [body setString:[[BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:items documentAttributes:NULL] string]];
        else
            [body setString:[BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:items]];
    } else {
        NSArray *usedMacros = [pubs valueForKeyPath:@"@distinctUnionOfArrays.usedMacros"];
        BDSKMacro *macro;
        if ([usedMacros count]) {
            e = [usedMacros objectEnumerator];
            while (macro = [e nextObject]) {
                if ([macro value] && [[macro value] isEqual:[NSNull null]] == NO)
                    [body appendFormat:@"@string{%@ = %@}\n", [macro name], [macro bibTeXString]];
            }
            [body appendString:@"\n\n"];
        }
        e = [items objectEnumerator];
        while (pub = [e nextObject]) {
            // use the detexified version without internal fields, since TeXification introduces things that 
            // AppleScript can't deal with (emailTo:... may end up using AS)
            [body appendString:[pub bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask]];
            [body appendString:@"\n\n"];
        }
    }
    [items release];
    
    // ampersands are common in publication names
    [body replaceOccurrencesOfString:@"&" withString:@"\\&" options:NSLiteralSearch range:NSMakeRange(0, [body length])];
    // escape backslashes
    [body replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:NSLiteralSearch range:NSMakeRange(0, [body length])];
    // escape double quotes
    [body replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange(0, [body length])];

    [[NSApp delegate] emailTo:nil subject:@"BibDesk references" body:body attachments:files];
}

- (IBAction)sendToLyX:(id)sender {
    if ([self numberOfSelectedPubs] == 0)
        return;
    
    NSString *lyxPipePath = [[NSUserDefaults standardUserDefaults] stringForKey:@"BDSKLyXPipePath"];
    NSFileManager *fm = [NSFileManager defaultManager];
    int fd = 0;
    
    if (lyxPipePath && [[lyxPipePath pathExtension] length] == 0)
        lyxPipePath = [lyxPipePath stringByAppendingPathExtension:@"in"];
    if (lyxPipePath == nil || [fm fileExistsAtPath:lyxPipePath] == NO)
        lyxPipePath = [fm newestLyXPipePath];
    
    if (lyxPipePath == nil) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to Find LyX Pipe", @"Message in alert dialog when LyX pipe cannot be found")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"BibDesk was unable to find the LyX pipe." , @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:documentWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        
    }
    // open non-blocking, so we don't hang if the pipe goes away
    else if (-1 != (fd = open([lyxPipePath fileSystemRepresentation], O_WRONLY | O_NONBLOCK))) {
        
        // check to see if the file is a named pipe; if not, show an error and close the file
        struct stat sb;
        if (fstat(fd, &sb) != 0 || (sb.st_mode & S_IFMT) != S_IFIFO) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid LyX Pipe", @"Alert dialog title") 
                                             defaultButton:nil 
                                           alternateButton:nil 
                                               otherButton:nil 
                                 informativeTextWithFormat:NSLocalizedString(@"The file at \"%@\" does not look like a LyX pipe.  You should quit LyX and possibly remove the file manually if this error persists.", @"Alert dialog text, single string format specifier"), lyxPipePath];
            [alert beginSheetModalForWindow:[self windowForSheet] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        }
        else {
            NSArray *citeKeys = [[self selectedPublications] valueForKey:@"citeKey"];
            NSMutableString *cites = [NSMutableString stringWithString:@"LYXCMD:BibDesk:citation-insert:"];
            [cites appendString:[citeKeys componentsJoinedByString:@","]];
            // pipe uses line buffering, so append a newline
            [cites appendString:@"\n"];
            
            // presumably the LyX document uses the same encoding as the .bib file, but citekeys should be 7 bit ASCII anyway
            NSData *data = [cites dataUsingEncoding:[self documentStringEncoding]];
            
            sig_t sig = signal(SIGPIPE, SIG_IGN);
            ssize_t len = write(fd, [data bytes], [data length]);
            if (len != (ssize_t)[data length])
                NSLog(@"Failed to write all data to LyX pipe \"%@\" (%d of %d bytes written)", lyxPipePath, len, [data length]);
            signal(SIGPIPE, sig);
            
            // Now read the reply message from the server's output pipe; no stat() check on this, since it's not critical.
            lyxPipePath = [[lyxPipePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"out"];
            int reader = open([lyxPipePath fileSystemRepresentation], O_RDONLY | O_NONBLOCK);
            
            if (-1 != reader) {
                
                NSMutableData *replyData = [NSMutableData data];
                char buf[1024];
                ssize_t readLength;
                sig = signal(SIGPIPE, SIG_IGN);
                
                // We passed O_NONBLOCK to open(), so block on the runloop with a short timeout in order to simulate a blocking read() on the pipe with a timeout.  Read() will only take this long in case of an error, in which case we'll probably get nothing out of the pipe anyway.
                NSTimeInterval stopTime = [NSDate timeIntervalSinceReferenceDate] + 1.0;
                
                do {
                    readLength = read(reader, buf, sizeof(buf));
                    if (readLength > 0) [replyData appendBytes:buf length:readLength];
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                } while (readLength > 0 || (readLength == -1 && EAGAIN == errno && [NSDate timeIntervalSinceReferenceDate] <= stopTime));
                signal(SIGPIPE, sig);
                
                if ([replyData length]) {
                    
                    // documented to return ASCII, so UTF-8 is okay (includes a trailing newline)
                    NSString *reply = [[[NSString alloc] initWithData:replyData encoding:NSUTF8StringEncoding] autorelease];
                    reply = [reply stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                    
                    // reply uses ERROR or INFO and whatever name and command we passed in
                    if ([reply hasPrefix:@"ERROR:BibDesk:citation-insert:"]) {
                        reply = [reply stringByRemovingPrefix:@"ERROR:BibDesk:citation-insert:"];
                        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"LyX Error", @"Alert dialog title") 
                                                         defaultButton:nil 
                                                       alternateButton:nil 
                                                           otherButton:nil 
                                             informativeTextWithFormat:NSLocalizedString(@"LyX replied with the following error message:  \"%@\"", @"Alert dialog text, single string format specifier"), reply];
                        [alert beginSheetModalForWindow:[self windowForSheet] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];                    
                    }
                }
                
                close(reader);
                
            } else {
                NSLog(@"Failed to open() LyX pipe \"%@\" for reading (%s)", lyxPipePath, strerror(errno));
            }            
        }
        
        close(fd);
        
    } else if (-1 == fd) {
        // local copy of errno since Foundation calls can overwrite it...
        int err = errno;
        // not clear why this happens, but a user reported it and the fix was removing the fifo manually in Terminal
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid LyX Pipe", @"Alert dialog title") 
                                         defaultButton:nil 
                                       alternateButton:nil 
                                           otherButton:nil 
                             informativeTextWithFormat:NSLocalizedString(@"Unable to open the LyX pipe at \"%@\" for writing.  You should quit LyX and possibly remove the pipe manually if this error persists.  The underlying system error code was %d (%s).", @"Alert dialog text"), lyxPipePath, err, strerror(err)];
        [alert beginSheetModalForWindow:[self windowForSheet] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
}

- (IBAction)postItemToWeblog:(id)sender{

	[NSException raise:BDSKUnimplementedException
				format:@"postItemToWeblog is unimplemented."];
	
	NSString *appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Blapp"]; // pref
	NSLog(@"%@",appPath);
#if 0	
	AppleEvent *theAE;
	OSERR err = AECreateAppleEvent (NNWEditDataItemAppleEventClass,
									NNWEditDataItemAppleEventID,
									'MMcC', // Blapp
									kAutoGenerateReturnID,
									kAnyTransactionID,
									&theAE);


	
	
	OSErr AESend (
				  const AppleEvent * theAppleEvent,
				  AppleEvent * reply,
				  AESendMode sendMode,
				  AESendPriority sendPriority,
				  SInt32 timeOutInTicks,
				  AEIdleUPP idleProc,
				  AEFilterUPP filterProc
				  );
#endif
}

- (void)changeColor:(id)sender {
    if ([self hasExternalGroupsSelected] == NO && [self isDisplayingFileContentSearch] == NO && [[self selectedPublications] count] && changingColors == NO) {
        changingColors = YES;
        [[self selectedPublications] makeObjectsPerformSelector:@selector(setColor:) withObject:[sender color]];
        changingColors = NO;
        [[self undoManager] setActionName:NSLocalizedString(@"Change Color", @"Undo action name")];
    }
}

#pragma mark URL actions

- (BOOL)textView:(NSTextView *)aTextView clickedOnLink:(id)aLink atIndex:(unsigned)charIndex
{
    if ([aLink respondsToSelector:@selector(isFileURL)] && [aLink isFileURL]) {
        NSString *searchString;
        if([[searchButtonController selectedItemIdentifier] isEqualToString:BDSKFileContentSearchString])
            searchString = [searchField stringValue];
        else
            searchString = @"";
        [[NSWorkspace sharedWorkspace] openURL:aLink withSearchString:searchString];
        return YES;
    } else if ([aLink isKindOfClass:[NSString class]]) {
        BibItem *pub = [[self publications] itemForCiteKey:aLink];
        return pub != nil && [self editPub:pub] != nil;
    }
    // let the next responder handle it if it was a non-file URL
    return NO;
}

#pragma mark | URL Field actions

- (IBAction)openLocalURL:(id)sender{
	NSString *field = [sender representedObject] ?: BDSKLocalUrlString;
    [self openLocalURLForField:field];
}

- (void)openLocalURLAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSString *field = (NSString *)contextInfo;
    if (returnCode == NSAlertAlternateReturn) {
        NSEnumerator *e = [[self selectedPublications] objectEnumerator];
        BibItem *pub;
        NSURL *fileURL;
        
        NSString *searchString;
        // See bug #1344720; don't search if this is a known field (Title, Author, etc.).  This feature can be annoying because Preview.app zooms in on the search result in this case, in spite of your zoom settings (bug report filed with Apple).
        if([[searchButtonController selectedItemIdentifier] isEqualToString:BDSKFileContentSearchString])
            searchString = [searchField stringValue];
        else
            searchString = @"";
        
        // the user said to go ahead
        while (pub = [e nextObject]) {
            if (fileURL = [pub localFileURLForField:field])
                [[NSWorkspace sharedWorkspace] openURL:fileURL withSearchString:searchString];
        }
    }
    [field release];
}

- (void)openLocalURLForField:(NSString *)field{
	int n = [self numberOfSelectedPubs];
    
    if (n > 6) {
		// Do we really want a gazillion of files open?
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Open Linked Files", @"Message in alert dialog when opening a lot of linked files")
                                         defaultButton:NSLocalizedString(@"No", @"Button title")
                                       alternateButton:NSLocalizedString(@"Open", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to open %i linked files. Do you want to proceed?" , @"Informative text in alert dialog"), n]];
        [alert beginSheetModalForWindow:documentWindow
                          modalDelegate:self
                         didEndSelector:@selector(openLocalURLAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:[field retain]];
	} else {
        [self openLocalURLAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[field retain]];
    }
}

- (IBAction)revealLocalURL:(id)sender{
	NSString *field = [sender representedObject] ?: BDSKLocalUrlString;
    [self revealLocalURLForField:field];
}

- (void)revealLocalURLAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSString *field = (NSString *)contextInfo;
    if (returnCode == NSAlertAlternateReturn) {
        NSEnumerator *e = [[self selectedPublications] objectEnumerator];
        BibItem *pub;
        NSURL *fileURL;
        
        while (pub = [e nextObject]) {
            if (fileURL = [pub localFileURLForField:field])
                [[NSWorkspace sharedWorkspace]  selectFile:[fileURL path] inFileViewerRootedAtPath:nil];
        }
    }
    [field release];
}

- (void)revealLocalURLForField:(NSString *)field{
	int n = [self numberOfSelectedPubs];
    
    if (n > 6) {
		// Do we really want a gazillion of Finder windows?
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reveal Linked Files", @"Message in alert dialog when trying to reveal a lot of linked files")
                                         defaultButton:NSLocalizedString(@"No", @"Button title")
                                       alternateButton:NSLocalizedString(@"Reveal", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to reveal %i linked files. Do you want to proceed?" , @"Informative text in alert dialog"), n]];
        [alert beginSheetModalForWindow:documentWindow
                          modalDelegate:self
                         didEndSelector:@selector(revealLocalURLAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:[field retain]];
	} else {
        [self revealLocalURLAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[field retain]];
    }
}

- (IBAction)openRemoteURL:(id)sender{
	NSString *field = [sender representedObject] ?: BDSKUrlString;
    [self openRemoteURLForField:field];
}

- (void)openRemoteURLAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSString *field = (NSString *)contextInfo;
    if(returnCode == NSAlertAlternateReturn){
        NSEnumerator *e = [[self selectedPublications] objectEnumerator];
        BibItem *pub;
        
		while (pub = [e nextObject]) {
			[[NSWorkspace sharedWorkspace] openLinkedURL:[pub remoteURLForField:field]];
		}
	}
    [field release];
}

- (void)openRemoteURLForField:(NSString *)field{
	int n = [self numberOfSelectedPubs];
    
    if (n > 6) {
		// Do we really want a gazillion of browser windows?
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Open Remote URL", @"Message in alert dialog when trying to open a lot of remote URLs")
                                         defaultButton:NSLocalizedString(@"No", @"Button title")
                                      alternateButton:NSLocalizedString(@"Open", @"Button title")
                                          otherButton:nil
                            informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to open %i URLs. Do you want to proceed?" , @"Informative text in alert dialog"), n]];
        [alert beginSheetModalForWindow:documentWindow
                          modalDelegate:self
                         didEndSelector:@selector(openRemoteURLAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:[field retain]];
	} else {
        [self openRemoteURLAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[field retain]];
    }
}

- (IBAction)showNotesForLocalURL:(id)sender{
	NSString *field = [sender representedObject] ?: BDSKLocalUrlString;
    [self showNotesForLocalURLForField:field];
}

- (void)showNotesForLocalURLAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSString *field = (NSString *)contextInfo;
    if (returnCode == NSAlertAlternateReturn) {
        NSEnumerator *e = [[self selectedPublications] objectEnumerator];
        BibItem *pub;
        NSURL *fileURL;
        BDSKNotesWindowController *notesController;
        
        // the user said to go ahead
        while (pub = [e nextObject]) {
            fileURL = [pub URLForField:field];
            if(fileURL == nil) continue;
            notesController = [[[BDSKNotesWindowController alloc] initWithURL:fileURL] autorelease];
            [self addWindowController:notesController];
            [notesController showWindow:self];
        }
    }
    [field release];
}

- (void)showNotesForLocalURLForField:(NSString *)field{
	int n = [self numberOfSelectedPubs];
    
    if (n > 6) {
		// Do we really want a gazillion of files open?
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Show Skim Notes For Linked Files", @"Message in alert dialog when showing notes for a lot of linked files")
                                         defaultButton:NSLocalizedString(@"No", @"Button title")
                                       alternateButton:NSLocalizedString(@"Open", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to open windows for notes for %i linked files. Do you want to proceed?" , @"Informative text in alert dialog"), n]];
        [alert beginSheetModalForWindow:documentWindow
                          modalDelegate:self
                         didEndSelector:@selector(showNotesForLocalURLAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:[field retain]];
	} else {
        [self showNotesForLocalURLAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[field retain]];
    }
}

- (IBAction)copyNotesForLocalURL:(id)sender{
	NSString *field = [sender representedObject] ?: BDSKLocalUrlString;
    [self copyNotesForLocalURLForField:field];
}

- (void)copyNotesForLocalURLForField:(NSString *)field{
    NSEnumerator *e = [[self selectedPublications] objectEnumerator];
    BibItem *pub;
    NSURL *fileURL;
    NSString *string;
    NSMutableString *notes = [NSMutableString string];
    
    while (pub = [e nextObject]) {  
        fileURL = [pub URLForField:field];
        if(fileURL == nil) continue;
        string = [fileURL textSkimNotes];
        if ([NSString isEmptyString:string]) continue;
        if ([notes length])
            [notes appendString:@"\n\n"];
        [notes appendString:string];
    }
    
    if ([notes isEqualToString:@""] == NO) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [pboard setString:notes forType:NSStringPboardType];
    } else {
        NSBeep();
    }
}

#pragma mark | Linked File actions

- (void)openLinkedFileAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertAlternateReturn) {
        NSEnumerator *urlEnum;
        NSURL *fileURL;
        NSArray *fileURLs = [(NSArray *)contextInfo autorelease];
        
        if (fileURLs)
            urlEnum = [fileURLs objectEnumerator];
        else
            urlEnum = [[self selectedFileURLs] objectEnumerator];
        
        NSString *searchString;
        // See bug #1344720; don't search if this is a known field (Title, Author, etc.).  This feature can be annoying because Preview.app zooms in on the search result in this case, in spite of your zoom settings (bug report filed with Apple).
        if([[searchButtonController selectedItemIdentifier] isEqualToString:BDSKFileContentSearchString])
            searchString = [searchField stringValue];
        else
            searchString = @"";
        
        while (fileURL = [urlEnum nextObject]) {
            if ([fileURL isEqual:[NSNull null]] == NO) {
                [[NSWorkspace sharedWorkspace] openURL:fileURL withSearchString:searchString];
            }
        }
    }
}

- (IBAction)openLinkedFile:(id)sender{
    NSURL *fileURL = [sender representedObject];
    if (fileURL) {
        [self openLinkedFileAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:(void *)[[NSArray alloc] initWithObjects:fileURL, nil]];
    } else {
        int n = [[self selectedFileURLs] count];
        
        if (n > 6) {
            // Do we really want a gazillion of files open?
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Open Linked Files", @"Message in alert dialog when opening a lot of linked files")
                                             defaultButton:NSLocalizedString(@"No", @"Button title")
                                           alternateButton:NSLocalizedString(@"Open", @"Button title")
                                               otherButton:nil
                                 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to open %i linked files. Do you want to proceed?" , @"Informative text in alert dialog"), n]];
            [alert beginSheetModalForWindow:documentWindow
                              modalDelegate:self
                             didEndSelector:@selector(openLinkedFileAlertDidEnd:returnCode:contextInfo:) 
                                contextInfo:NULL];
        } else {
            [self openLinkedFileAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:NULL];
        }
    }
}

- (void)revealLinkedFileAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertAlternateReturn) {
        NSEnumerator *urlEnum;
        NSURL *fileURL;
        NSArray *fileURLs = [(NSArray *)contextInfo autorelease];
        
        if (fileURLs)
            urlEnum = [fileURLs objectEnumerator];
        else
            urlEnum = [[self selectedFileURLs] objectEnumerator];
        
        while (fileURL = [urlEnum nextObject]) {
            if ([fileURL isEqual:[NSNull null]] == NO) {
                [[NSWorkspace sharedWorkspace]  selectFile:[fileURL path] inFileViewerRootedAtPath:nil];
            }
        }
    }
}

- (IBAction)revealLinkedFile:(id)sender{
    NSURL *fileURL = [sender representedObject];
    if (fileURL) {
        [self revealLinkedFileAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:(void *)[[NSArray alloc] initWithObjects:fileURL, nil]];
    } else {
        int n = [[self selectedFileURLs] count];
        
        if (n > 6) {
            // Do we really want a gazillion of Finder windows?
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reveal Linked Files", @"Message in alert dialog when trying to reveal a lot of linked files")
                                             defaultButton:NSLocalizedString(@"No", @"Button title")
                                           alternateButton:NSLocalizedString(@"Reveal", @"Button title")
                                               otherButton:nil
                                 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to reveal %i linked files. Do you want to proceed?" , @"Informative text in alert dialog"), n]];
            [alert beginSheetModalForWindow:documentWindow
                              modalDelegate:self
                             didEndSelector:@selector(revealLinkedFileAlertDidEnd:returnCode:contextInfo:) 
                                contextInfo:NULL];
        } else {
            [self revealLinkedFileAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:NULL];
        }
    }
}

- (void)openLinkedURLAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if(returnCode == NSAlertAlternateReturn){
        NSEnumerator *urlEnum;
        NSURL *remoteURL;
        NSArray *remoteURLs = [(NSArray *)contextInfo autorelease];
        
        if (remoteURLs)
            urlEnum = [remoteURLs objectEnumerator];
        else
            urlEnum = [[[self selectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs.URL"] objectEnumerator];
        
        while (remoteURL = [urlEnum nextObject]) {
            if ([remoteURL isEqual:[NSNull null]] == NO) {
                [[NSWorkspace sharedWorkspace] openLinkedURL:remoteURL];
            }
		}
	}
}

- (IBAction)openLinkedURL:(id)sender{
    NSURL *remoteURL = [sender representedObject];
    if (remoteURL) {
        [self openLinkedURLAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:(void *)[[NSArray alloc] initWithObjects:remoteURL, nil]];
    } else {
        int n = [[[self selectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs"] count];
        
        if (n > 6) {
            // Do we really want a gazillion of browser windows?
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Open Remote URL", @"Message in alert dialog when trying to open a lot of remote URLs")
                                             defaultButton:NSLocalizedString(@"No", @"Button title")
                                          alternateButton:NSLocalizedString(@"Open", @"Button title")
                                              otherButton:nil
                                informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to open %i URLs. Do you want to proceed?" , @"Informative text in alert dialog"), n]];
            [alert beginSheetModalForWindow:documentWindow
                              modalDelegate:self
                             didEndSelector:@selector(openLinkedURLAlertDidEnd:returnCode:contextInfo:) 
                                contextInfo:NULL];
        } else {
            [self openLinkedURLAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:NULL];
        }
    }
}

- (void)showNotesForLinkedFileAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertAlternateReturn) {
        NSEnumerator *urlEnum;
        NSURL *fileURL;
        NSArray *fileURLs = [(NSArray *)contextInfo autorelease];
        BDSKNotesWindowController *notesController;
        
        if (fileURLs)
            urlEnum = [fileURLs objectEnumerator];
        else
            urlEnum = [[self selectedFileURLs] objectEnumerator];
        
        while (fileURL = [urlEnum nextObject]) {
            if ([fileURL isEqual:[NSNull null]] == NO) {
                notesController = [[[BDSKNotesWindowController alloc] initWithURL:fileURL] autorelease];
                [self addWindowController:notesController];
                [notesController showWindow:self];
            }
        }
    }
}

- (IBAction)showNotesForLinkedFile:(id)sender{
    NSURL *fileURL = [sender representedObject];
    if (fileURL) {
        [self showNotesForLinkedFileAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:(void *)[[NSArray alloc] initWithObjects:fileURL, nil]];
    } else {
        int n = [[self selectedFileURLs] count];
        
        if (n > 6) {
            // Do we really want a gazillion of files open?
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Show Skim Notes For Linked Files", @"Message in alert dialog when showing notes for a lot of linked files")
                                             defaultButton:NSLocalizedString(@"No", @"Button title")
                                           alternateButton:NSLocalizedString(@"Open", @"Button title")
                                               otherButton:nil
                                 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"BibDesk is about to open windows for notes for %i linked files. Do you want to proceed?" , @"Informative text in alert dialog"), n]];
            [alert beginSheetModalForWindow:documentWindow
                              modalDelegate:self
                             didEndSelector:@selector(showNotesForLinkedFileAlertDidEnd:returnCode:contextInfo:) 
                                contextInfo:NULL];
        } else {
            [self showNotesForLinkedFileAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:NULL];
        }
    }
}

- (IBAction)copyNotesForLinkedFile:(id)sender{
    NSEnumerator *urlEnum;
    NSURL *fileURL = [sender representedObject];
    NSMutableString *notes = [NSMutableString string];
    NSString *string;
    
    if (fileURL)
        urlEnum = [[NSArray arrayWithObject:fileURL] objectEnumerator];
    else
        urlEnum = [[self selectedFileURLs] objectEnumerator];
    
    while (fileURL = [urlEnum nextObject]) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            string = [fileURL textSkimNotes];
            if ([NSString isEmptyString:string] == NO) {
                if ([notes length])
                    [notes appendString:@"\n\n"];
                [notes appendString:string];
            }
        }
    }
    
    if ([notes isEqualToString:@""] == NO) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [pboard setString:notes forType:NSStringPboardType];
    } else {
        NSBeep();
    }
}

- (IBAction)previewAction:(id)sender {
    NSURL *theURL = [sender representedObject];
    if (theURL == nil) {
        NSArray *selectedURLs = [self selectedFileURLs];
        if ([selectedURLs count])
            theURL = [selectedURLs firstObject];
        else
            theURL = [[[self selectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs.URL"] firstObject];
    }
    if (theURL && [theURL isEqual:[NSNull null]] == NO) {
        [FVPreviewer setWebViewContextMenuDelegate:self];
        [FVPreviewer previewURL:theURL];
    }
}

- (IBAction)migrateFiles:(id)sender {
    if (nil == migrationController) {
        migrationController = [[BDSKFileMigrationController alloc] init];
    }
    if ([[self windowControllers] containsObject:migrationController] == NO) {
        [self addWindowController:migrationController];
    }
    [migrationController showWindow:self];
}

#pragma mark View Actions

- (IBAction)selectAllPublications:(id)sender {
    if ([self isDisplayingFileContentSearch])
        [[fileSearchController tableView] selectAll:sender];
    else
        [tableView selectAll:sender];
}

- (IBAction)deselectAllPublications:(id)sender {
	[tableView deselectAll:sender];
}

- (IBAction)toggleStatusBar:(id)sender{
	[statusBar toggleBelowView:mainBox offset:1.0];
	[[NSUserDefaults standardUserDefaults] setBool:[statusBar isVisible] forKey:BDSKShowStatusBarKey];
}

- (IBAction)changeMainTableFont:(id)sender{
    NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKMainTableViewFontNameKey];
    float fontSize = [[NSUserDefaults standardUserDefaults] floatForKey:BDSKMainTableViewFontSizeKey];
	[[NSFontManager sharedFontManager] setSelectedFont:[NSFont fontWithName:fontName size:fontSize] isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:sender];
    
    id firstResponder = [documentWindow firstResponder];
    if (firstResponder != tableView)
        [documentWindow makeFirstResponder:tableView];
}

- (IBAction)changeGroupTableFont:(id)sender{
    NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKGroupTableViewFontNameKey];
    float fontSize = [[NSUserDefaults standardUserDefaults] floatForKey:BDSKGroupTableViewFontSizeKey];
	[[NSFontManager sharedFontManager] setSelectedFont:[NSFont fontWithName:fontName size:fontSize] isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:sender];
    
    id firstResponder = [documentWindow firstResponder];
    if (firstResponder != groupTableView)
        [documentWindow makeFirstResponder:groupTableView];
}

- (IBAction)changePreviewDisplay:(id)sender{
    int tag = [sender respondsToSelector:@selector(selectedSegment)] ? [[sender cell] tagForSegment:[sender selectedSegment]] : [sender tag];
    NSString *style = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    BOOL changed = NO;
    
    if (bottomPreviewDisplay != tag) {
        bottomPreviewDisplay = tag;
        changed = YES;
    }
    if (tag == BDSKPreviewDisplayText && style && NO == [style isEqualToString:bottomPreviewDisplayTemplate]) {
        [bottomPreviewDisplayTemplate release];
        bottomPreviewDisplayTemplate = [style retain];
        changed = YES;
    }
    if (changed) {
        [self updateBottomPreviewPane];
        if ([sender isEqual:bottomPreviewButton] == NO)
            [bottomPreviewButton selectSegmentWithTag:bottomPreviewDisplay];
        [[NSUserDefaults standardUserDefaults] setInteger:bottomPreviewDisplay forKey:BDSKBottomPreviewDisplayKey];
        [[NSUserDefaults standardUserDefaults] setObject:bottomPreviewDisplayTemplate forKey:BDSKBottomPreviewDisplayTemplateKey];
    }
}

- (IBAction)changeSidePreviewDisplay:(id)sender{
    int tag = [sender respondsToSelector:@selector(selectedSegment)] ? [[sender cell] tagForSegment:[sender selectedSegment]] : [sender tag];
    NSString *style = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    BOOL changed = NO;
    
    if (sidePreviewDisplay != tag) {
        sidePreviewDisplay = tag;
        changed = YES;
    }
    if (tag == BDSKPreviewDisplayText && style && NO == [style isEqualToString:sidePreviewDisplayTemplate]) {
        [sidePreviewDisplayTemplate release];
        sidePreviewDisplayTemplate = [style retain];
        changed = YES;
    }
    if (changed) {
        [self updateSidePreviewPane];
        if ([sender isEqual:sidePreviewButton] == NO)
            [sidePreviewButton selectSegmentWithTag:sidePreviewDisplay];
        [[NSUserDefaults standardUserDefaults] setInteger:sidePreviewDisplay forKey:BDSKSidePreviewDisplayKey];
        [[NSUserDefaults standardUserDefaults] setObject:sidePreviewDisplayTemplate forKey:BDSKSidePreviewDisplayTemplateKey];
    }
}

- (void)pageDownInPreview:(id)sender{
    NSScrollView *scrollView = nil;
    
    if (bottomPreviewDisplay == BDSKPreviewDisplayText)
        scrollView = [bottomPreviewTextView enclosingScrollView];
    else if (bottomPreviewDisplay == BDSKPreviewDisplayFiles)
        scrollView = [bottomFileView enclosingScrollView];
    else if (bottomPreviewDisplay == BDSKPreviewDisplayTeX)
        scrollView = [(BDSKZoomablePDFView *)[previewer pdfView] scrollView];
    
    NSPoint p = [[scrollView documentView] scrollPositionAsPercentage];
    
    if(p.y > 0.99 || NSHeight([scrollView documentVisibleRect]) >= NSHeight([[scrollView documentView] bounds])){ // select next row if the last scroll put us at the end
        int i = [[tableView selectedRowIndexes] lastIndex];
        if (i == NSNotFound)
            i = 0;
        else if (i < [tableView numberOfRows])
            i++;
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
        [tableView scrollRowToVisible:i];
    }else{
        [scrollView pageDown:sender];
    }
}

- (void)pageUpInPreview:(id)sender{
    NSScrollView *scrollView = nil;
    
    if (bottomPreviewDisplay == BDSKPreviewDisplayText)
        scrollView = [bottomPreviewTextView enclosingScrollView];
    else if (bottomPreviewDisplay == BDSKPreviewDisplayFiles)
        scrollView = [bottomFileView enclosingScrollView];
    else if (bottomPreviewDisplay == BDSKPreviewDisplayTeX)
        scrollView = [(BDSKZoomablePDFView *)[previewer pdfView] scrollView];
    
    NSPoint p = [[scrollView documentView] scrollPositionAsPercentage];
    
    if(p.y < 0.01){ // select previous row if we're already at the top
        int i = [[tableView selectedRowIndexes] firstIndex];
		if (i == NSNotFound)
			i = 0;
		else if (i > 0)
			i--;
		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
        [tableView scrollRowToVisible:i];
    }else{
        [scrollView pageUp:sender];
    }
}

#pragma mark Showing related info windows

- (IBAction)toggleShowingCustomCiteDrawer:(id)sender{
    if(drawerController == nil)
        drawerController = [[BDSKCustomCiteDrawerController alloc] initForDocument:self];
    [drawerController toggle:sender];
    return;
}

- (IBAction)showDocumentInfoWindow:(id)sender{
    if (!infoWC) {
        infoWC = [(BDSKDocumentInfoWindowController *)[BDSKDocumentInfoWindowController alloc] initWithDocument:self];
    }
    [infoWC beginSheetModalForWindow:documentWindow];
}

- (IBAction)showMacrosWindow:(id)sender{
    if ([self hasExternalGroupsSelected]) {
        BDSKMacroResolver *resolver = [(id<BDSKOwner>)[groups objectAtIndex:[groupTableView selectedRow]] macroResolver];
        BDSKMacroWindowController *controller = nil;
        NSEnumerator *wcEnum = [[self windowControllers] objectEnumerator];
        NSWindowController *wc;
        while(wc = [wcEnum nextObject]){
            if([wc isKindOfClass:[BDSKMacroWindowController class]] && [(BDSKMacroWindowController*)wc macroResolver] == resolver)
                break;
        }
        if(wc){
            controller = (BDSKMacroWindowController *)wc;
        }else{
            controller = [[BDSKMacroWindowController alloc] initWithMacroResolver:resolver];
            [self addWindowController:controller];
            [controller release];
        }
        [controller showWindow:self];
    } else {
        if (!macroWC) {
            macroWC = [[BDSKMacroWindowController alloc] initWithMacroResolver:[self macroResolver]];
        }
        if ([[self windowControllers] containsObject:macroWC] == NO) {
            [self addWindowController:macroWC];
        }
        [macroWC showWindow:self];
    }
}

#pragma mark Sharing Actions

- (IBAction)refreshSharing:(id)sender{
    [[BDSKSharingServer defaultServer] restartSharingIfNeeded];
}

- (IBAction)refreshSharedBrowsing:(id)sender{
    [[BDSKSharingBrowser sharedBrowser] restartSharedBrowsingIfNeeded];
}

#pragma mark Text import sheet support

- (IBAction)importFromPasteboardAction:(id)sender{
    
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    NSString *type = [pasteboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKReferenceMinerStringPboardType, BDSKBibItemPboardType, NSStringPboardType, nil]];
    
    if(type != nil){
        NSError *error = nil;
        BOOL isKnownFormat = YES;
		if([type isEqualToString:NSStringPboardType]){
			// sniff the string to see if we should add it directly
			NSString *pboardString = [pasteboard stringForType:type];
			isKnownFormat = ([pboardString contentStringType] != BDSKUnknownStringType);
		}
		
        if(isKnownFormat && [self addPublicationsFromPasteboard:pasteboard selectLibrary:YES verbose:NO error:&error])
            return; // it worked, so we're done here
    }
    
    BDSKTextImportController *tic = [(BDSKTextImportController *)[BDSKTextImportController alloc] initWithDocument:self];

    [tic beginSheetForPasteboardModalForWindow:documentWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
	[tic release];
}

- (IBAction)importFromFileAction:(id)sender{
    BDSKTextImportController *tic = [(BDSKTextImportController *)[BDSKTextImportController alloc] initWithDocument:self];

    [tic beginSheetForFileModalForWindow:documentWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
	[tic release];
}

- (IBAction)importFromWebAction:(id)sender{
    BDSKTextImportController *tic = [(BDSKTextImportController *)[BDSKTextImportController alloc] initWithDocument:self];

    [tic beginSheetForWebModalForWindow:documentWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
	[tic release];
}

#pragma mark AutoFile stuff

- (void)consolidateAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    BOOL check = (returnCode == NSAlertDefaultReturn);
    if (returnCode == NSAlertAlternateReturn)
        return;

    // first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
    NSArray *selectedFiles = [[self selectedPublications] valueForKeyPath:@"@unionOfArrays.localFiles"];
    [[BDSKFiler sharedFiler] filePapers:selectedFiles fromDocument:self check:check];
	
	[[self undoManager] setActionName:NSLocalizedString(@"AutoFile Files", @"Undo action name")];
}

- (IBAction)consolidateLinkedFiles:(id)sender{
    if ([self hasExternalGroupsSelected] == YES) {
        NSBeep();
        return;
    }
    BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"AutoFile Linked Files", @"Message in alert dialog when consolidating files")
                                         defaultButton:NSLocalizedString(@"Move Complete Only", @"Button title")
                                       alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                           otherButton:NSLocalizedString(@"Move All", @"Button title")
                             informativeTextWithFormat:NSLocalizedString(@"This will put all files linked to the selected items in your Papers Folder, according to the format string. Do you want me to generate a new location for all linked files, or only for those for which all the bibliographical information used in the generated file name has been set?", @"Informative text in alert dialog")];
    // we need the callback in the didDismissSelector, because the sheet must be removed from the document before we call BDSKFiler 
    // as that will use a sheet as well, see bug # 1526145
	[alert beginSheetModalForWindow:documentWindow
                      modalDelegate:self
                     didEndSelector:NULL
                 didDismissSelector:@selector(consolidateAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
    
}

#pragma mark Cite Keys and Crossref support

- (void)generateCiteKeysForPublications:(NSArray *)pubs{
    
    unsigned int numberOfPubs = [pubs count];
    NSEnumerator *selEnum = [pubs objectEnumerator];
    BibItem *aPub;
    NSMutableArray *arrayOfPubs = [NSMutableArray arrayWithCapacity:numberOfPubs];
    NSMutableArray *arrayOfOldValues = [NSMutableArray arrayWithCapacity:numberOfPubs];
    NSMutableArray *arrayOfNewValues = [NSMutableArray arrayWithCapacity:numberOfPubs];
    BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKWillGenerateCiteKeyScriptHookName];
    
    // first we make sure all edits are committed
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
    
    // put these pubs into an array, since the indices can change after we set the cite key, due to sorting or searching
    while (aPub = [selEnum nextObject]) {
        [arrayOfPubs addObject:aPub];
        if(scriptHook){
            [arrayOfOldValues addObject:[aPub citeKey]];
            [arrayOfNewValues addObject:[aPub suggestedCiteKey]];
        }
    }
    
    if (scriptHook) {
        [scriptHook setField:BDSKCiteKeyString];
        [scriptHook setOldValues:arrayOfOldValues];
        [scriptHook setNewValues:arrayOfNewValues];
        [[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:arrayOfPubs document:self];
    }
    
    scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKDidGenerateCiteKeyScriptHookName];
    [arrayOfOldValues removeAllObjects];
    [arrayOfNewValues removeAllObjects];
    selEnum = [arrayOfPubs objectEnumerator];
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    while(aPub = [selEnum nextObject]){
        NSString *newKey = [aPub suggestedCiteKey];
        NSString *crossref = [aPub valueOfField:BDSKCrossrefString inherit:NO];
        if (crossref != nil && [crossref caseInsensitiveCompare:newKey] == NSOrderedSame) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Could not generate cite key",@"Message in alert dialog when failing to generate cite key") 
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The cite key for \"%@\" could not be generated because the generated key would be the same as the crossref key.", @"Informative text in alert dialog"), [aPub citeKey]];
            [alert beginSheetModalForWindow:documentWindow
                              modalDelegate:nil
                             didEndSelector:NULL
                                contextInfo:NULL];
            continue;
        }
        [aPub setCiteKey:newKey];
        
        if(scriptHook){
            [arrayOfOldValues addObject:[aPub citeKey]];
            [arrayOfNewValues addObject:newKey];
        }
        
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
    }
    
    // should be safe to release here since arrays were created outside the scope of this local pool
    [pool release];
    
    if (scriptHook) {
        [scriptHook setField:BDSKCiteKeyString];
        [scriptHook setOldValues:arrayOfOldValues];
        [scriptHook setNewValues:arrayOfNewValues];
        [[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:arrayOfPubs document:self];
    }
    
    [[self undoManager] setActionName:(numberOfPubs > 1 ? NSLocalizedString(@"Generate Cite Keys", @"Undo action name") : NSLocalizedString(@"Generate Cite Key", @"Undo action name"))];
}    

- (void)generateCiteKeyAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if([alert checkValue] == YES)
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKWarnOnCiteKeyChangeKey];
    
    if(returnCode == NSAlertDefaultReturn)
        [self generateCiteKeysForPublications:[self selectedPublications]];
}

- (IBAction)generateCiteKey:(id)sender
{
    unsigned int numberOfSelectedPubs = [self numberOfSelectedPubs];
	if (numberOfSelectedPubs == 0 ||
        [self hasExternalGroupsSelected] == YES) return;
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnCiteKeyChangeKey]){
        NSString *alertTitle = numberOfSelectedPubs > 1 ? NSLocalizedString(@"Really Generate Cite Keys?", @"Message in alert dialog when generating cite keys") : NSLocalizedString(@"Really Generate Cite Key?", @"Message in alert dialog when generating cite keys");
        NSString *message = numberOfSelectedPubs > 1 ? [NSString stringWithFormat:NSLocalizedString(@"This action will generate cite keys for %d publications.  This action is undoable.", @"Informative text in alert dialog"), numberOfSelectedPubs] : NSLocalizedString(@"This action will generate a cite key for the selected publication.  This action is undoable.", @"Informative text in alert dialog");
        BDSKAlert *alert = [BDSKAlert alertWithMessageText:alertTitle
                                             defaultButton:NSLocalizedString(@"Generate", @"Button title")
                                           alternateButton:NSLocalizedString(@"Cancel", @"Button title") 
                                               otherButton:nil
                                 informativeTextWithFormat:message];
        [alert setHasCheckButton:YES];
        [alert setCheckValue:NO];
        [alert beginSheetModalForWindow:documentWindow 
                          modalDelegate:self 
                         didEndSelector:@selector(generateCiteKeyAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
    } else {
        [self generateCiteKeysForPublications:[self selectedPublications]];
    }
}

- (void)performSortForCrossrefs{
    NSArray *copyOfPubs = [[NSArray alloc] initWithArray:publications];
	NSEnumerator *pubEnum = [copyOfPubs objectEnumerator];
	BibItem *pub = nil;
	BibItem *parent;
	NSString *key;
	NSMutableSet *prevKeys = [NSMutableSet set];
	BOOL moved = NO;
	NSArray *selectedPubs = [self selectedPublications];
    
    [copyOfPubs release];
	
	// We only move parents that come before a child.
	while (pub = [pubEnum nextObject]){
		key = [[pub valueOfField:BDSKCrossrefString inherit:NO] lowercaseString];
		if (![NSString isEmptyString:key] && [prevKeys containsObject:key]) {
            [prevKeys removeObject:key];
			parent = [publications itemForCiteKey:key];
			[publications removeObjectIdenticalTo:parent];
			[publications addObject:parent];
			moved = YES;
		}
		[prevKeys addObject:[[pub citeKey] lowercaseString]];
	}
	
	if (moved) {
		[self sortPubsByKey:nil];
		[self selectPublications:selectedPubs];
		[self setStatus:NSLocalizedString(@"Publications sorted for cross references.", @"Status message")];
	}
}

- (IBAction)sortForCrossrefs:(id)sender{
	NSUndoManager *undoManager = [self undoManager];
	[[undoManager prepareWithInvocationTarget:self] setPublications:publications];
	[undoManager setActionName:NSLocalizedString(@"Sort Publications", @"Undo action name")];
	
	[self performSortForCrossrefs];
}

- (void)selectCrossrefParentForItem:(BibItem *)item{
    BibItem *parent = [item crossrefParent];
    if(parent){
        [tableView deselectAll:nil];
        [self selectPublication:parent];
        [tableView scrollRowToCenter:[tableView selectedRow]];
    } else
        NSBeep(); // if no parent found
}

- (IBAction)selectCrossrefParentAction:(id)sender{
    BDSKASSERT([self isDisplayingFileContentSearch] == NO);
    BibItem *selectedBI = [[self selectedPublications] lastObject];
    [self selectCrossrefParentForItem:selectedBI];
}

- (void)dublicateTitleToBooktitleAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	BOOL overwrite = (returnCode == NSAlertAlternateReturn);
	
	NSSet *parentTypes = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKTypesForDuplicateBooktitleKey]];
	NSEnumerator *selEnum = [[self selectedPublications] objectEnumerator];
	BibItem *aPub;
	
    // first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
	
	while (aPub = [selEnum nextObject]) {
		if([parentTypes containsObject:[aPub pubType]])
			[aPub duplicateTitleToBooktitleOverwriting:overwrite];
	}
	[[self undoManager] setActionName:([self numberOfSelectedPubs] > 1 ? NSLocalizedString(@"Duplicate Titles", @"Undo action name") : NSLocalizedString(@"Duplicate Title", @"Undo action name"))];
}

- (IBAction)duplicateTitleToBooktitle:(id)sender{
	if ([self numberOfSelectedPubs] == 0 ||
        [self hasExternalGroupsSelected] == YES) return;
	
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Overwrite Booktitle?", @"Message in alert dialog when duplicating Title to Booktitle")
                                     defaultButton:NSLocalizedString(@"Don't Overwrite", @"Button title: overwrite Booktitle")
                                   alternateButton:NSLocalizedString(@"Overwrite", @"Button title: don't overwrite Booktitle")
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Do you want me to overwrite the Booktitle field when it was already entered?", @"Informative text in alert dialog")];
	[alert beginSheetModalForWindow:documentWindow
                      modalDelegate:self
                     didEndSelector:@selector(dublicateTitleToBooktitleAlertDidEnd:returnCode:contextInfo:) 
                        contextInfo:NULL];
}

#pragma mark Duplicate and Incomplete searching

// select duplicates, then allow user to delete/copy/whatever
- (IBAction)selectPossibleDuplicates:(id)sender{
    
	[self setSearchString:@""]; // make sure we can see everything
    
    [documentWindow makeFirstResponder:tableView]; // make sure tableview has the focus
    
    CFIndex idx = [shownPublications count];
    id object1 = nil, object2 = nil;
    
    BDSKASSERT(sortKey);
    
    NSMutableIndexSet *rowsToSelect = [NSMutableIndexSet indexSet];
    CFIndex countOfItems = 0;
    BOOL isURL = [sortKey isURLField];
    
    // Compare objects in the currently sorted table column using the isEqual: method to test adjacent cells in order to check for duplicates based on a specific sort key.  BibTool does this, but its effectiveness is obviously limited by the key used <http://lml.ls.fi.upm.es/manuales/bibtool/m_2_11_1.html>.
    while(idx--){
        object1 = object2;
        object2 = isURL ? [[shownPublications objectAtIndex:idx] valueOfField:sortKey] : [[shownPublications objectAtIndex:idx] displayValueOfField:sortKey];
        if([object1 isEqual:object2]){
            [rowsToSelect addIndexesInRange:NSMakeRange(idx, 2)];
            countOfItems++;
        }
    }
    
    if(countOfItems){
        [tableView selectRowIndexes:rowsToSelect byExtendingSelection:NO];
        [tableView scrollRowToCenter:[rowsToSelect firstIndex]];  // make sure at least one item is visible
    }else
        NSBeep();
    
	NSString *pubSingularPlural = (countOfItems == 1) ? NSLocalizedString(@"publication", @"publication, in status message") : NSLocalizedString(@"publications", @"publications, in status message");
    // update status line after the updateStatus notification, or else it gets overwritten
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"%i duplicate %@ found.", @"Status message: [number] duplicate publication(s) found"), countOfItems, pubSingularPlural]];
}

- (void)selectDuplicatesAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertAlternateReturn)
        return;
    
	[self setSearchString:@""]; // make sure we can see everything
    
    [documentWindow makeFirstResponder:tableView]; // make sure tableview has the focus
    
    NSMutableArray *pubsToRemove = nil;
    NSZone *zone = [self zone];
    CFIndex countOfItems = 0;
    BibItem **pubs;
    CFSetCallBacks callBacks = kBDSKBibItemEqualitySetCallBacks;
    
    if ([self hasExternalGroupsSelected]) {
        countOfItems = [publications count];
        pubs = (BibItem **)NSZoneMalloc(zone, sizeof(BibItem *) * countOfItems);
        [publications getObjects:pubs];
        pubsToRemove = [[NSMutableArray alloc] initWithArray:groupedPublications];
        callBacks = kBDSKBibItemEquivalenceSetCallBacks;
    } else {
        pubsToRemove = [[NSMutableArray alloc] initWithArray:publications];
        countOfItems = [publications count];
        pubs = (BibItem **)NSZoneMalloc(zone, sizeof(BibItem *) * countOfItems);
        [pubsToRemove getObjects:pubs];
        
        // Tests equality based on standard fields (high probability that these will be duplicates)
        countOfItems = [pubsToRemove count];
        NSSet *uniquePubs = (NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)pubs, countOfItems, &callBacks);
        NSEnumerator *pubEnum = [uniquePubs objectEnumerator];
        BibItem *pub;
        // remove all unique ones based on pointer equality
        while (pub = [pubEnum nextObject])
            [pubsToRemove removeObjectIdenticalTo:pub];
        [uniquePubs release];
        
        // original buffer should be large enough, since we've only removed items from pubsToRemove
        countOfItems = [pubsToRemove count];
        [pubsToRemove getObjects:pubs];
        [pubsToRemove setArray:publications];
    }
    
    if (returnCode == NSAlertDefaultReturn) {
    NSSet *removeSet = (NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)pubs, countOfItems, &callBacks);
    NSZoneFree(zone, pubs);
    
    CFIndex idx = [pubsToRemove count];
    
    while(idx--){
        if([removeSet containsObject:[pubsToRemove objectAtIndex:idx]] == NO)
            [pubsToRemove removeObjectAtIndex:idx];
    }
    
    [removeSet release];
        [self selectPublications:pubsToRemove];
    } else {
    [pubsToRemove release];
        pubsToRemove = [[NSMutableArray alloc] initWithObjects:pubs count:countOfItems];
        [self selectPublications:pubsToRemove];
    }
    [pubsToRemove release];
    
    if(countOfItems)
        [tableView scrollRowToCenter:[tableView selectedRow]];  // make sure at least one item is visible
    else
        NSBeep();
    
	NSString *pubSingularPlural = (countOfItems == 1) ? NSLocalizedString(@"publication", @"publication, in status message") : NSLocalizedString(@"publications", @"publications, in status message");
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"%i duplicate %@ found.", @"Status message: [number] duplicate publication(s) found"), countOfItems, pubSingularPlural]];
}

// select duplicates, then allow user to delete/copy/whatever
- (IBAction)selectDuplicates:(id)sender{
    if ([self hasExternalGroupsSelected]) {
        // for external groups we compare to the items in Library, so all duplicates should be selected
        [self selectDuplicatesAlertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:NULL];
    } else {
        // let the user decide if he wants to select all the duplicates, or randomly leave one duplicate out of the selection
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Select duplicates", @"Message in alert dialog when trying to find duplicates")
                                         defaultButton:NSLocalizedString(@"All Candidates", @"Button title")
                                      alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                          otherButton:NSLocalizedString(@"Only Duplicates", @"Button title")
                            informativeTextWithFormat:NSLocalizedString(@"Do you want to select all duplicate items, or only strict duplicates? If you choose \"Only Duplicates\", one randomly selected duplicate will be not be selected." , @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:documentWindow
                          modalDelegate:self
                         didEndSelector:@selector(selectDuplicatesAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
    }
}

- (IBAction)selectIncompletePublications:(id)sender{
	[self setSearchString:@""]; // make sure we can see everything
    
    [documentWindow makeFirstResponder:tableView]; // make sure tableview has the focus
    
    CFIndex i, idx = [shownPublications count], countOfItems = 0;
    BibItem *pub;
    NSMutableIndexSet *rowsToSelect = [NSMutableIndexSet indexSet];
    BDSKTypeManager *typeman = [BDSKTypeManager sharedManager];
    NSArray *reqFields;
    
    while(idx--){
        pub = [shownPublications objectAtIndex:idx];
        reqFields = [typeman requiredFieldsForType:[pub pubType]];
        i = [reqFields count];
        while(i--){
            if([NSString isEmptyString:[pub valueOfField:[reqFields objectAtIndex:i]]]){
                [rowsToSelect addIndex:idx];
                countOfItems++;
                break;
            }
        }
    }
    
    if(countOfItems){
        [tableView selectRowIndexes:rowsToSelect byExtendingSelection:NO];
        [tableView scrollRowToCenter:[rowsToSelect firstIndex]];  // make sure at least one item is visible
    }else
        NSBeep();
    
	NSString *pubSingularPlural = (countOfItems == 1) ? NSLocalizedString(@"publication", @"publication, in status message") : NSLocalizedString(@"publications", @"publications, in status message");
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"%i incomplete %@ found.", @"Status message: [number] incomplete publication(s) found"), countOfItems, pubSingularPlural]];
}

@end
