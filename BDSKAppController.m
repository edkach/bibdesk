//  BDSKAppController.m

//  Created by Michael McCracken on Sat Jan 19 2002.
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

#import "BDSKAppController.h"
#import "BDSKOwnerProtocol.h"
#import <Carbon/Carbon.h>
#import "BDSKStringConstants.h"
#import "BDSKPreviewer.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKTypeManager.h"
#import "BDSKCharacterConversion.h"
#import "BDSKFindController.h"
#import "BDSKScriptMenu.h"
#import "BibDocument.h"
#import "BibDocument_UI.h"
#import "BibDocument_Groups.h"
#import "BibDocument_Actions.h"
#import "BibItem.h"
#import "BDSKFormatParser.h"
#import "BDAlias.h"
#import "BDSKErrorObjectController.h"
#import "BDSKServiceProvider.h"
#import "BDSKCompletionServer.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKPreferenceController.h"
#import "BDSKTemplate.h"
#import "NSURL_BDSKExtensions.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKReadMeController.h"
#import "BDSKOrphanedFilesFinder.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKDocumentController.h"
#import "NSError_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFileMatcher.h"
#import "BDSKSearchBookmarkController.h"
#import "BDSKSearchBookmark.h"
#import "BDSKBookmarkController.h"
#import "BDSKBookmark.h"
#import "BDSKVersionNumber.h"
#import "BDSKURLGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKServerInfo.h"
#import "BDSKGroupsArray.h"
#import "BDSKWebGroup.h"
#import "BDSKWebGroupViewController.h"
#import "KFASHandlerAdditions-TypeTranslation.h"
#import "BDSKTask.h"
#import <Sparkle/Sparkle.h>
#import <WebKit/WebKit.h>
#import "NSDate_BDSKExtensions.h"

#define WEB_URL @"http://bibdesk.sourceforge.net/"
#define WIKI_URL @"http://sourceforge.net/apps/mediawiki/bibdesk/"
#define BUG_TRACKER_URL @"http://sourceforge.net/tracker/?group_id=61487&atid=497423"
#define RFE_TRACKER_URL @"http://sourceforge.net/tracker/?group_id=61487&atid=497426"

#define BDSKUpdateCheckIntervalKey @"BDSKUpdateCheckIntervalKey"

#define BDSKHistoryByDateKey @"BDSKHistoryByDate"
#define BDSKIsRelaunchKey @"BDSKIsRelaunch"
#define BDSKDidMigrateLocalUrlFormatDefaultsKey @"BDSKDidMigrateLocalUrlFormatDefaultsKey"

enum {
    BDSKStartupOpenUntitledFile,
    BDSKStartupDoNothing,
    BDSKStartupOpenDialog,
    BDSKStartupOpenDefaultFile,
    BDSKStartupOpenLastOpenFiles
};

@interface BDSKAppController (Private)
- (void)doSpotlightImportIfNeeded;
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;
@end

@implementation BDSKAppController

// remove legacy comparisons of added/created/modified strings in table column code from prefs
static void fixLegacyTableColumnIdentifiers()
{
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    NSMutableArray *fixedTableColumnIdentifiers = [[[sud arrayForKey:BDSKShownColsNamesKey] mutableCopy] autorelease];

    NSUInteger idx;
    BOOL didFixIdentifier = NO;
    NSDictionary *legacyKeys = [NSDictionary dictionaryWithObjectsAndKeys:BDSKDateAddedString, @"Added", BDSKDateAddedString, @"Created", BDSKDateModifiedString, @"Modified", BDSKAuthorEditorString, @"Authors Or Editors", BDSKAuthorString, @"Authors", nil];
    
    for (NSString *key in legacyKeys) {
        if ((idx = [fixedTableColumnIdentifiers indexOfObject:key]) != NSNotFound) {
            didFixIdentifier = YES;
            [fixedTableColumnIdentifiers replaceObjectAtIndex:idx withObject:[legacyKeys objectForKey:key]];
        }
    }
    if (didFixIdentifier)
        [sud setObject:fixedTableColumnIdentifiers forKey:BDSKShownColsNamesKey];
}

- (void)awakeFromNib{   
    // Add a Scripts menu; searches in (mainbundle)/Contents/Scripts and (Library domains)/Application Support/BibDesk/Scripts
    [NSApp scriptMenu];
}

- (void)checkFormatStrings {
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    BDSKTypeManager *btm = [BDSKTypeManager sharedManager];
    NSString *formatString = [sud objectForKey:BDSKCiteKeyFormatKey];
    NSString *error = nil;
    NSInteger button = 0;
    
    if ([BDSKFormatParser validateFormat:&formatString forField:BDSKCiteKeyString error:&error]) {
        [sud setObject:formatString forKey:BDSKCiteKeyFormatKey];
        [btm setRequiredFieldsForCiteKey: [BDSKFormatParser requiredFieldsForFormat:formatString]];
    }else{
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"The autogeneration format for Cite Key is invalid.", @"Message in alert dialog when detecting invalid cite key format")
                                         defaultButton:NSLocalizedString(@"Go to Preferences", @"Button title")
                                       alternateButton:NSLocalizedString(@"Revert to Default", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:@"%@", error];
        [alert setAlertStyle:NSCriticalAlertStyle];
        button = [alert runModal];
        if (button == NSAlertAlternateReturn){
            formatString = [[[NSUserDefaultsController sharedUserDefaultsController] initialValues] objectForKey:BDSKCiteKeyFormatKey];
            [sud setObject:formatString forKey:BDSKCiteKeyFormatKey];
            [btm setRequiredFieldsForCiteKey: [BDSKFormatParser requiredFieldsForFormat:formatString]];
        }else{
            [[BDSKPreferenceController sharedPreferenceController] showWindow:nil];
            [[BDSKPreferenceController sharedPreferenceController] selectPaneWithIdentifier:@"edu.ucsd.cs.mmccrack.bibdesk.prefpane.citekey"];
        }
    }
    
    formatString = [sud objectForKey:BDSKLocalFileFormatKey];
    error = nil;
    
    if ([sud boolForKey:BDSKDidMigrateLocalUrlFormatDefaultsKey] == NO) {
        id oldFormatString = [sud objectForKey:@"Local-Url Format"];
        if (oldFormatString) {
            NSInteger formatPresetChoice = [sud objectForKey:@"Local-Url Format Preset"] ? [sud integerForKey:@"Local-Url Format Preset"] : 2;
            id formatLowercase = [sud objectForKey:@"Local-Url Generate Lowercase"];
            id formatCleanOption = [sud objectForKey:@"Local-Url Clean Braces or TeX"];
            formatString = oldFormatString;
            if (formatPresetChoice != 0) {
                formatPresetChoice = MAX(1, formatPresetChoice - 1);
                switch (formatPresetChoice) {
                    case 1: formatString = @"%l%n0%e"; break;
                    case 2: formatString = @"%a1/%Y%u0%e"; break;
                    case 3: formatString = @"%a1/%T5%n0%e"; break;
                }
            }
            [sud setObject:formatString forKey:BDSKLocalFileFormatKey];
            [sud setInteger:0 forKey:BDSKLocalFileFormatPresetKey];
            if (formatLowercase)
                [sud setObject:formatLowercase forKey:BDSKLocalFileLowercaseKey];
            if (formatCleanOption)
                [sud setObject:formatCleanOption forKey:BDSKLocalFileCleanOptionKey];
        }
        [sud setBool:YES forKey:BDSKDidMigrateLocalUrlFormatDefaultsKey];
    }
    
    if ([BDSKFormatParser validateFormat:&formatString forField:BDSKLocalFileString error:&error]) {
        [sud setObject:formatString forKey:BDSKLocalFileFormatKey];
        [btm setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:formatString]];
    } else {
        NSString *fixedFormatString = nil;
        NSString *otherButton = nil;
        if ([formatString hasSuffix:@"%e"]) {
            NSUInteger i = [formatString length] - 2;
            fixedFormatString = [[formatString substringToIndex:i] stringByAppendingString:@"%n0%e"];
        } else if ([formatString hasSuffix:@"%L"]) {
            NSUInteger i = [formatString length] - 2;
            fixedFormatString = [[formatString substringToIndex:i] stringByAppendingString:@"%l%n0%e"];
        } else if ([formatString rangeOfString:@"."].length) {
            fixedFormatString = [[[formatString stringByDeletingPathExtension] stringByAppendingString:@"%n0"] stringByAppendingPathExtension:[formatString pathExtension]];
        }
        if (fixedFormatString && [BDSKFormatParser validateFormat:&fixedFormatString forField:BDSKLocalFileString error:NULL]) {
            [sud setObject:fixedFormatString forKey:BDSKLocalFileFormatKey];
            [btm setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:fixedFormatString]];
            otherButton = NSLocalizedString(@"Fix", @"Button title");
        }
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"The autogeneration format for local files is invalid.", @"Message in alert dialog when detecting invalid local file format")
                                         defaultButton:NSLocalizedString(@"Go to Preferences", @"Button title")
                                       alternateButton:NSLocalizedString(@"Revert to Default", @"Button title")
                                           otherButton:otherButton
                             informativeTextWithFormat:@"%@", error];
        [alert setAlertStyle:NSCriticalAlertStyle];
        button = [alert runModal];
        if (button == NSAlertDefaultReturn) {
            [sud setObject:fixedFormatString forKey:BDSKLocalFileFormatKey];
            [btm setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:fixedFormatString]];
            [[BDSKPreferenceController sharedPreferenceController] showWindow:nil];
            [[BDSKPreferenceController sharedPreferenceController] selectPaneWithIdentifier:@"edu.ucsd.cs.mmccrack.bibdesk.prefpane.autofile"];
        } else if (button == NSAlertAlternateReturn) {
            formatString = [[[NSUserDefaultsController sharedUserDefaultsController] initialValues] objectForKey:BDSKLocalFileFormatKey];			
            [sud setObject:formatString forKey:BDSKLocalFileFormatKey];
            [btm setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:formatString]];
        }
    }

}


#pragma mark Application delegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification{
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    
    // this makes sure that the defaults are registered
    [BDSKPreferenceController sharedPreferenceController];
    
    if([sud boolForKey:BDSKShouldAutosaveDocumentKey])
        [[NSDocumentController sharedDocumentController] setAutosavingDelay:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKAutosaveTimeIntervalKey]];
    
    // make sure we use Spotlight's plugins on 10.4 and later
    SKLoadDefaultExtractorPlugIns();

    [NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
    
    [NSString initializeStringConstants];
    
    // eliminate support for some legacy keys
    fixLegacyTableColumnIdentifiers();
    
    // legacy pref key removed prior to release of 1.3.1 (stored path instead of alias)
    NSString *filePath = [sud objectForKey:@"Default Bib File"];
    if(filePath) {
        BDAlias *alias = [BDAlias aliasWithPath:filePath];
        if(alias)
            [sud setObject:[alias aliasData] forKey:BDSKDefaultBibFileAliasKey];
        [sud removeObjectForKey:@"Default Bib File"];
    }
    
    // enforce Author and Editor as person fields
    NSArray *personFields = [sud stringArrayForKey:BDSKPersonFieldsKey];
    NSInteger idx = 0;
    if ([personFields containsObject:BDSKAuthorString] == NO || [personFields containsObject:BDSKEditorString] == NO) {
        personFields  = [personFields mutableCopy];
        if ([personFields containsObject:BDSKAuthorString] == NO)
            [(NSMutableArray *)personFields insertObject:BDSKAuthorString atIndex:idx++];
        if ([personFields containsObject:BDSKEditorString] == NO)
            [(NSMutableArray *)personFields insertObject:BDSKEditorString atIndex:idx];
        [sud setObject:personFields forKey:BDSKPersonFieldsKey];
        [personFields release];
        [[BDSKTypeManager sharedManager] updateCustomFields];
    }
    
    // name image to make it available app wide, also in IB
    [NSImage cautionImage];
    
    // register NSURL as conversion handler for file types
    [NSAppleEventDescriptor registerConversionHandler:[NSURL class]
                                             selector:@selector(fileURLWithAEDesc:)
                                   forDescriptorTypes:typeFileURL, typeAlias, typeFSRef, 'fss ', 'bmrk', nil];
    
    // register URL handler
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BDSKIsRelaunchKey];
    
    // register our help book, so it's available for methods that don't register this, e.g. the web group
    FSRef appRef;
    if (noErr == FSPathMakeRef((const UInt8 *)[[[NSBundle mainBundle] bundlePath] fileSystemRepresentation], &appRef, NULL))
        AHRegisterHelpBook(&appRef);
    
    // validate the Cite Key and LocalUrl format strings
    [self checkFormatStrings];
    
    // register services
    [NSApp setServicesProvider:[BDSKServiceProvider sharedServiceProvider]];
    
    // register server for cite key completion
    [BDSKCompletionServer sharedCompletionServer];
    
    NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if(![versionString isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:BDSKLastVersionLaunchedKey]])
        [self showRelNotes:nil];
    if([[NSUserDefaults standardUserDefaults] objectForKey:BDSKLastVersionLaunchedKey] == nil) // show new users the readme file; others just see the release notes
        [self showReadMeFile:nil];
    [[NSUserDefaults standardUserDefaults] setObject:versionString forKey:BDSKLastVersionLaunchedKey];
    
    // copy files to application support
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager copyAllExportTemplatesToApplicationSupportAndOverwrite:NO];        
    [fileManager copyFileFromSharedSupportToApplicationSupport:@"previewtemplate.tex" overwrite:NO];
    [fileManager copyFileFromSharedSupportToApplicationSupport:@"template.txt" overwrite:NO];   
    [fileManager copyFileFromSharedSupportToApplicationSupport:@"Bookmarks.plist" overwrite:NO];   

    NSString *scriptsPath = [[fileManager applicationSupportDirectory] stringByAppendingPathComponent:@"Scripts"];
    if ([fileManager fileExistsAtPath:scriptsPath] == NO)
        [fileManager createDirectoryAtPath:scriptsPath withIntermediateDirectories:NO attributes:nil error:NULL];
    
    // Ensure the previewer and TeX task get created now in order to avoid a spurious "unable to copy helper file" warning when quit->document window closes->first call to [BDSKPreviewer sharedPreviewer]
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey])
        [BDSKPreviewer sharedPreviewer];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShowingPreviewKey])
		[[BDSKPreviewer sharedPreviewer] showWindow:self];
    
    [self doSpotlightImportIfNeeded];
    
    [[WebPreferences standardPreferences] setCacheModel:WebCacheModelDocumentBrowser];
    
    WebHistory *history = [[[WebHistory alloc] init] autorelease];
    NSString *historyPath = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"History.plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:historyPath])
        [history loadFromURL:[NSURL fileURLWithPath:historyPath] error:NULL];
    [WebHistory setOptionalSharedHistory:history];
    
    [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
}

static BOOL fileIsInTrash(NSURL *fileURL)
{
    NSCParameterAssert([fileURL isFileURL]);    
    FSRef fileRef;
    Boolean result = false;
    if (CFURLGetFSRef((CFURLRef)fileURL, &fileRef)) {
        FSDetermineIfRefIsEnclosedByFolder(0, kTrashFolderType, &fileRef, &result);
        if (result == false)
            FSDetermineIfRefIsEnclosedByFolder(0, kSystemTrashFolderType, &fileRef, &result);
    }
    return result;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    NSInteger option = [[sud objectForKey:BDSKStartupBehaviorKey] integerValue];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKIsRelaunchKey])
        option = BDSKStartupOpenLastOpenFiles;
    switch (option) {
        case BDSKStartupOpenUntitledFile:
            return YES;
        case BDSKStartupDoNothing:
            return NO;
        case BDSKStartupOpenDialog:
            [[NSDocumentController sharedDocumentController] openDocument:nil];
            return NO;
        case BDSKStartupOpenDefaultFile:
            {
                NSData *data = [sud objectForKey:BDSKDefaultBibFileAliasKey];
                BDAlias *alias = nil;
                if([data length])
                    alias = [BDAlias aliasWithData:data];
                NSURL *fileURL = [alias fileURL];
                if(fileURL && NO == fileIsInTrash(fileURL))
                    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES error:NULL];
            }
            return NO;
        case BDSKStartupOpenLastOpenFiles:
            {
                NSArray *files = [sud objectForKey:BDSKLastOpenFileNamesKey];
                NSURL *fileURL;
                for (NSDictionary *dict in files){ 
                    fileURL = [[BDAlias aliasWithData:[dict objectForKey:@"_BDAlias"]] fileURL] ?: [NSURL fileURLWithPath:[dict objectForKey:@"fileName"]];
                    if(fileURL)
                        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES error:NULL];
                }
            }
            return NO;
        default:
            return NO;
    }
}

// we don't want to reopen last open files or show an Open dialog when re-activating the app
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    NSInteger startupOption = [[[NSUserDefaults standardUserDefaults] objectForKey:BDSKStartupBehaviorKey] integerValue];
    return flag || (startupOption == BDSKStartupOpenUntitledFile || startupOption == BDSKStartupOpenDefaultFile);
}

- (void)openRecentItemFromDock:(id)sender{
    BDSKASSERT([sender isKindOfClass:[NSMenuItem class]]);
    NSURL *url = [sender representedObject];
    NSError *error = nil;
    if (url == nil)
        NSBeep();
    else if (nil == [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&error] && error)
        [NSApp presentError:error];
}    

- (NSMenu *)applicationDockMenu:(NSApplication *)sender{
    NSMenu *menu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""] autorelease];
    NSMenu *submenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""];

    for (NSURL *url in [[NSDocumentController sharedDocumentController] recentDocumentURLs]) {
        NSMenuItem *anItem = [submenu addItemWithTitle:[url lastPathComponent] action:@selector(openRecentItemFromDock:) keyEquivalent:@""];
        [anItem setTarget:self];
        [anItem setRepresentedObject:url];
    }
    
	[menu addItemWithTitle:NSLocalizedString(@"Open Recent",  @"Recent Documents dock menu title") submenu:submenu];
    [submenu release];
    
    return menu;
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    NSString *historyPath = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"History.plist"];
    [[WebHistory optionalSharedHistory] saveToURL:[NSURL fileURLWithPath:historyPath] error:NULL];
}

#pragma mark Updater

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:BDSKUpdateCheckIntervalKey]) {
        // the user already used an older version of BibDesk
        [updater setAutomaticallyChecksForUpdates:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKUpdateCheckIntervalKey] >= 0];
        return NO;
    }
    return YES;
}

- (void)updaterWillRelaunchApplication:(SUUpdater *)updater {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:BDSKIsRelaunchKey];
}

#pragma mark Menu stuff

- (BOOL) validateMenuItem:(NSMenuItem*)menuItem{
	SEL act = [menuItem action];

	if (act == @selector(toggleShowingPreviewPanel:)){ 
		// menu item for toggling the preview panel
		// set the on/off state according to the panel's visibility
		if ([[BDSKPreviewer sharedPreviewer] isWindowVisible]) {
			[menuItem setState:NSOnState];
		}else {
			[menuItem setState:NSOffState];
		}
		return YES;
	}
	else if (act == @selector(toggleShowingErrorPanel:)){ 
		// menu item for toggling the error panel
		// set the on/off state according to the panel's visibility
		if ([[BDSKErrorObjectController sharedErrorObjectController] isWindowVisible]) {
			[menuItem setState:NSOnState];
		}else {
			[menuItem setState:NSOffState];
		}
		return YES;
	}
    else if (act == @selector(toggleShowingOrphanedFilesPanel:)){ 
                
		// menu item for toggling the orphaned files panel
		// set the on/off state according to the panel's visibility
		if ([[BDSKOrphanedFilesFinder sharedFinder] isWindowVisible]) {
			[menuItem setState:NSOnState];
		}else {
			[menuItem setState:NSOffState];
		}
		return YES;
    }
    else if (act == @selector(toggleHistoryByDate:)){ 
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKHistoryByDateKey])
            [menuItem setTitle:NSLocalizedString(@"Only Today", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Organize By Date", @"Menu item title")];
		return YES;
	}
	return YES;
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {

	if ([toolbarItem action] == @selector(toggleShowingPreviewPanel:)) {
		return ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey]);
	}
	
    return [super validateToolbarItem:toolbarItem];
}

// implemented in order to prevent the Copy As > Template menu from being updated at every key event
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action { return NO; }

- (void)addMenuItemsForSearchBookmarks:(NSArray *)bookmarks toMenu:(NSMenu *)menu {
    for (BDSKSearchBookmark *bm in bookmarks) {
        if ([bm bookmarkType] == BDSKSearchBookmarkTypeFolder) {
            NSString *label = [bm label];
            NSMenu *submenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:[bm label]] autorelease];
            NSMenuItem *item = [menu addItemWithTitle:label ?: @"" submenu:submenu];
            [item setImageAndSize:[bm icon]];
            [self addMenuItemsForSearchBookmarks:[bm children] toMenu:submenu];
        } else if ([bm bookmarkType] == BDSKSearchBookmarkTypeSeparator) {
            [menu addItem:[NSMenuItem separatorItem]];
        } else {
            NSString *label = [bm label];
            NSMenuItem *item = [menu addItemWithTitle:label ?: @"" action:@selector(newSearchGroupFromBookmark:)  keyEquivalent:@""];
            [item setRepresentedObject:[bm info]];
            [item setImageAndSize:[bm icon]];
        }
    }
}

- (void)addMenuItemsForBookmarks:(NSArray *)bookmarks toMenu:(NSMenu *)menu {
    for (BDSKBookmark *bm in bookmarks) {
        if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
            NSString *name = [bm name];
            NSMenu *submenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:[bm name]] autorelease];
            NSMenuItem *item = [menu addItemWithTitle:name ?: @"" submenu:submenu];
            [item setImageAndSize:[bm icon]];
            [self addMenuItemsForBookmarks:[bm children] toMenu:submenu];
        } else if ([bm bookmarkType] == BDSKBookmarkTypeSeparator) {
            [menu addItem:[NSMenuItem separatorItem]];
        } else {
            NSString *name = [bm name];
            NSMenuItem *item = [menu addItemWithTitle:name ?: @"" action:@selector(openBookmark:)  keyEquivalent:@""];
            [item setRepresentedObject:[bm URL]];
            [item setImageAndSize:[bm icon]];
        }
    }
}

- (void)addMenuItemsForHistoryItems:(NSArray *)historyItems toMenu:(NSMenu *)menu {
    for (WebHistoryItem *historyItem in historyItems) {
        NSString *title = [historyItem title];
        if ([NSString isEmptyString:title]) {
            NSURL *url = [NSURL URLWithString:[historyItem URLString]];
            title = [url isFileURL] ? [[url path] lastPathComponent] : [[url absoluteString] stringByReplacingPercentEscapes];
        }
        NSMenuItem *item = [menu addItemWithTitle:title action:@selector(openBookmark:) keyEquivalent:@""];
        [item setRepresentedObject:[NSURL URLWithString:[historyItem URLString]]];
        [item setImageAndSize:[NSImage imageNamed:@"Bookmark"]];
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    
    if ([menu isEqual:columnsMenu]) {
                
        // remove all items; then fill it with the items from the current document
        [menu removeAllItems];
        
        BibDocument *document = (BibDocument *)[[NSDocumentController sharedDocumentController] currentDocument];
        if ([document respondsToSelector:@selector(columnsMenu)]) {
            [menu addItemsFromMenu:[document columnsMenu]];
        } else {
            [menu addItemWithTitle:[NSLocalizedString(@"Add Other", @"Menu title") stringByAppendingEllipsis] action:NULL keyEquivalent:@""];
            [menu addItem:[NSMenuItem separatorItem]];
            [menu addItemWithTitle:NSLocalizedString(@"Autosize All Columns", @"Menu title") action:NULL keyEquivalent:@""];
        }
        
    } else if ([menu isEqual:groupFieldMenu]) {
        
        while ([[menu itemAtIndex:1] isSeparatorItem] == NO)
            [menu removeItemAtIndex:1];
        
        for (NSString *field in [[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGroupFieldsKey] reverseObjectEnumerator]) {
            NSMenuItem *menuItem = [menu insertItemWithTitle:field action:@selector(changeGroupFieldAction:) keyEquivalent:@"" atIndex:1];
            [menuItem setRepresentedObject:field];
        }
        
    } else if ([menu isEqual:copyAsTemplateMenu]) {
    
        NSArray *styles = [BDSKTemplate allStyleNames];
        NSInteger i = [menu numberOfItems];
        while (i--) {
            if ([[menu itemAtIndex:i] tag] < BDSKTemplateDragCopyType)
                break;
            [menu removeItemAtIndex:i];
        }
        
        NSMenuItem *item;
        NSInteger count = [styles count];
        for (i = 0; i < count; i++) {
            item = [menu addItemWithTitle:[styles objectAtIndex:i] action:@selector(copyAsAction:) keyEquivalent:@""];
            [item setTag:BDSKTemplateDragCopyType + i];
        }
        
    } else if ([menu isEqual:previewDisplayMenu] || [menu isEqual:sidePreviewDisplayMenu]) {
    
        NSArray *styles = [BDSKTemplate allStyleNamesForFormat:(BDSKRichTextTemplateFormat | BDSKPlainHTMLTemplateFormat)];
        
        NSInteger i = [menu numberOfItems];
        while (i-- && [[menu itemAtIndex:i] isSeparatorItem] == NO)
            [menu removeItemAtIndex:i];
        
        NSMenuItem *item;
        SEL action = [menu isEqual:previewDisplayMenu] ? @selector(changePreviewDisplay:) : @selector(changeSidePreviewDisplay:);
        for (NSString *style in styles) {
            item = [menu addItemWithTitle:style action:action keyEquivalent:@""];
            [item setTag:BDSKPreviewDisplayText];
            [item setRepresentedObject:style];
        }
        
    } else if ([menu isEqual:searchBookmarksMenu]) {
        
        NSArray *bookmarks = [[[BDSKSearchBookmarkController sharedBookmarkController] bookmarkRoot] children];
        NSInteger i = [menu numberOfItems];
        while (--i > 2)
            [menu removeItemAtIndex:i];
        if ([bookmarks count] > 0)
            [menu addItem:[NSMenuItem separatorItem]];
        [self addMenuItemsForSearchBookmarks:bookmarks toMenu:menu];
        
    } else if ([menu isEqual:bookmarksMenu]) {
        
        NSArray *bookmarks = [[[BDSKBookmarkController sharedBookmarkController] bookmarkRoot] children];
        NSInteger i = [menu numberOfItems];
        while (--i > 4)
            [menu removeItemAtIndex:i];
        if ([bookmarks count] > 0)
            [menu addItem:[NSMenuItem separatorItem]];
        [self addMenuItemsForBookmarks:bookmarks toMenu:menu];
        
    } else if ([menu isEqual:historyMenu]) {
        
        WebHistory *history = [WebHistory optionalSharedHistory];
        [historyMenu removeAllItems];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKHistoryByDateKey]) {
            NSArray *historyDays = [history orderedLastVisitedDays];
            for (NSDate *date in historyDays) {
                NSArray *historyItems = [history orderedItemsLastVisitedOnDay:(id)date];
                NSMenu *submenu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
                [historyMenu addItemWithTitle:[date dateDescription] submenu:submenu];
                [self addMenuItemsForHistoryItems:historyItems toMenu:submenu];
                [submenu release];
            }
        } else {
            NSArray *historyItems = [history orderedItemsLastVisitedOnDay:[NSDate date]];
            [self addMenuItemsForHistoryItems:historyItems toMenu:menu];
        }
        if ([historyMenu numberOfItems] > 0)
            [historyMenu addItem:[NSMenuItem separatorItem]];
        [historyMenu addItemWithTitle:NSLocalizedString(@"Organize By Date", @"Menu item title") action:@selector(toggleHistoryByDate:) keyEquivalent:@""];
        [historyMenu addItemWithTitle:NSLocalizedString(@"Clear", @"Menu item title") action:@selector(clearHistory:) keyEquivalent:@""];
    }
}

#pragma mark Actions

- (IBAction)showReadMeFile:(id)sender{
    [[BDSKReadMeController sharedReadMeController] showWindow:self];
}

- (IBAction)showRelNotes:(id)sender{
    [[BDSKRelNotesController sharedRelNotesController] showWindow:self];
}

- (IBAction)showFindPanel:(id)sender{
    [[BDSKFindController sharedFindController] showWindow:self];
}

- (IBAction)visitWebSite:(id)sender{
    if(![[NSWorkspace sharedWorkspace] openURL:
        [NSURL URLWithString:WEB_URL]]){
        NSBeep();
    }
}

- (IBAction)visitWiki:(id)sender{
    if(![[NSWorkspace sharedWorkspace] openURL:
        [NSURL URLWithString:WIKI_URL]]){
        NSBeep();
    }
}

- (IBAction)reportBug:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:BUG_TRACKER_URL]];
}

- (IBAction)requestFeature:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:RFE_TRACKER_URL]];
}

- (IBAction)toggleShowingErrorPanel:(id)sender{
    [[BDSKErrorObjectController sharedErrorObjectController] toggleShowingWindow:sender];
}

- (IBAction)toggleShowingPreviewPanel:(id)sender{
    [[BDSKPreviewer sharedPreviewer] toggleShowingWindow:sender];
}

- (IBAction)toggleShowingOrphanedFilesPanel:(id)sender{
    [[BDSKOrphanedFilesFinder sharedFinder] toggleShowingWindow:sender];
}

- (IBAction)matchFiles:(id)sender{
    [[BDSKFileMatcher sharedInstance] showWindow:sender];
}

- (IBAction)editSearchBookmarks:(id)sender {
    [[BDSKSearchBookmarkController sharedBookmarkController] showWindow:self];
}

- (IBAction)showBookmarks:(id)sender{
    [[BDSKBookmarkController sharedBookmarkController] showWindow:sender];
}

- (IBAction)clearHistory:(id)sender {
    [[WebHistory optionalSharedHistory] removeAllItems];
}

- (IBAction)toggleHistoryByDate:(id)sender {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    [sud setBool:NO == [sud boolForKey:BDSKHistoryByDateKey] forKey:BDSKHistoryByDateKey];
}

#pragma mark URL handling code

- (BibDocument *)frontDocumentOfClass:(Class)aClass error:(NSError **)error {
    // try the main document first
    id document = [[NSDocumentController sharedDocumentController] mainDocument];
    if ([document isKindOfClass:aClass] == NO) {
        for (document in [NSApp orderedDocuments])
            if ([document isKindOfClass:aClass]) break;
        if (document == nil)
            document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:error];
    }
    return document;
}


- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent{
    NSString *theURLString = [[event descriptorForKeyword:keyDirectObject] stringValue];
    NSURL *theURL = nil;
    BibDocument *document = nil;
    NSError *error = nil;
    NSAppleEventDescriptor *errr = [event descriptorForKeyword:'errr'];
    BOOL errorReporting = errr ? [errr booleanValue] : YES;

    if (theURLString) {
        if ([theURLString hasPrefix:@"<"] && [theURLString hasSuffix:@">"])
            theURLString = [theURLString substringWithRange:NSMakeRange(0, [theURLString length] - 2)];
        if ([theURLString hasPrefix:@"URL:"])
            theURLString = [theURLString substringFromIndex:4];
        theURL = [NSURL URLWithString:theURLString] ?: [NSURL URLWithStringByNormalizingPercentEscapes:theURLString];
    }
    
    if ([[theURL scheme] isEqualToString:BDSKBibItemURLScheme]) {
        
        NSString *citeKey = [[theURLString substringFromIndex:9] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *path = [[NSFileManager defaultManager] spotlightCacheFilePathWithCiteKey:citeKey];
        NSURL *fileURL;
        
        if (path && (fileURL = [NSURL fileURLWithPath:path])) {
            document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES error:&error];
        } else {
            error = [NSError localErrorWithCode:kBDSKURLOperationFailed localizedDescription:NSLocalizedString(@"Unable to get item from bdsk:// URL.", @"error when opening bdskURL")];
        }
        
    } else if ([[theURL scheme] isEqualToString:BDSKSearchGroupURLScheme]) {
        
        BDSKSearchGroup *group = [[BDSKSearchGroup alloc] initWithURL:theURL];
        
        if (group) {
            document = [self frontDocumentOfClass:[BibDocument class] error:&error];
            [[document groups] addSearchGroup:group];
            [group release];
        } else {
            error = [NSError localErrorWithCode:kBDSKURLOperationFailed localizedDescription:NSLocalizedString(@"Unable to get search group from bdsksearch:// URL.", @"error when opening bdsksearch URL")];
        }
        
    } else if ([@"http" isCaseInsensitiveEqual:[theURL scheme]] || [@"https" isCaseInsensitiveEqual:[theURL scheme]]) {
        
        document = [self frontDocumentOfClass:[BibDocument class] error:&error];
        [document openURL:theURL];
        
    } else if (theURL) {
        
        [[NSWorkspace sharedWorkspace] openURL:theURL];
        
    }
    
    if (document == nil && error && errorReporting)
        [NSApp presentError:error];
}

#pragma mark Spotlight support

#define LAST_IMPORTER_VERSION_KEY @"lastImporterVersion"
#define LAST_SYS_VERSION_KEY @"lastSysVersion"

- (void)doSpotlightImportIfNeeded {
    
    // This code finds the spotlight importer and re-runs it if the importer or app version has changed since the last time we launched.
    NSArray *pathComponents = [NSArray arrayWithObjects:[[NSBundle mainBundle] bundlePath], @"Contents", @"Library", @"Spotlight", @"BibImporter", nil];
    NSString *importerPath = [[NSString pathWithComponents:pathComponents] stringByAppendingPathExtension:@"mdimporter"];
    
    NSBundle *importerBundle = [NSBundle bundleWithPath:importerPath];
    NSString *importerVersion = [importerBundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    if (importerVersion) {
        NSDictionary *versionInfo = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKSpotlightVersionInfoKey];
        
        SInt32 sysVersion;
        OSStatus err = Gestalt(gestaltSystemVersion, &sysVersion);
        
        BOOL runImporter = NO;
        if ([versionInfo count] == 0) {
            runImporter = YES;
        } else {
            NSString *lastImporterVersion = [versionInfo objectForKey:LAST_IMPORTER_VERSION_KEY];
            
            long lastSysVersion = [[versionInfo objectForKey:LAST_SYS_VERSION_KEY] longValue];
            
            runImporter = noErr == err ? ([BDSKVersionNumber compareVersionString:lastImporterVersion toVersionString:importerVersion] == NSOrderedAscending || sysVersion > lastSysVersion) : YES;
        }
        if (runImporter) {
            NSString *mdimportPath = @"/usr/bin/mdimport";
            if ([[NSFileManager defaultManager] isExecutableFileAtPath:mdimportPath]) {
                NSTask *importerTask = [[[BDSKTask alloc] init] autorelease];
                [importerTask setLaunchPath:mdimportPath];
                [importerTask setArguments:[NSArray arrayWithObjects:@"-r", importerPath, nil]];
                [importerTask launch];
                
                NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:sysVersion], LAST_SYS_VERSION_KEY, importerVersion, LAST_IMPORTER_VERSION_KEY, nil];
                [[NSUserDefaults standardUserDefaults] setObject:info forKey:BDSKSpotlightVersionInfoKey];
                
            }
            else NSLog(@"%@ not found!", mdimportPath);
        }
    }
}

@end
