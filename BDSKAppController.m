//  BDSKAppController.m

//  Created by Michael McCracken on Sat Jan 19 2002.
/*
 This software is Copyright (c) 2002-2009
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
#import "BibItem.h"
#import "BibAuthor.h"
#import "BDSKPreviewer.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKTypeManager.h"
#import "BDSKCharacterConversion.h"
#import "BDSKFindController.h"
#import "BDSKScriptMenu.h"
#import "BibDocument.h"
#import "BibDocument_Search.h"
#import "BibDocument_Actions.h"
#import "BibDocument_Groups.h"
#import "BDSKFormatParser.h"
#import "BDAlias.h"
#import "BDSKErrorObjectController.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKSharingBrowser.h"
#import "BDSKSharingServer.h"
#import "BDSKPreferenceController.h"
#import "BDSKTemplateParser.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"
#import "NSSet_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKReadMeController.h"
#import "BDSKOrphanedFilesFinder.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "NSArray_BDSKExtensions.h"
#import "NSObject_BDSKExtensions.h"
#import "BDSKSearchForCommand.h"
#import "BDSKCompletionServerProtocol.h"
#import "BDSKDocumentController.h"
#import "NSError_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import <libkern/OSAtomic.h>
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
#import "BDSKMessageQueue.h"
#import <Sparkle/Sparkle.h>

#define WEB_URL @"http://bibdesk.sourceforge.net/"
#define WIKI_URL @"http://apps.sourceforge.net/mediawiki/bibdesk/"

@implementation BDSKAppController

// remove legacy comparisons of added/created/modified strings in table column code from prefs
static void fixLegacyTableColumnIdentifiers()
{
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    NSMutableArray *fixedTableColumnIdentifiers = [[[sud arrayForKey:BDSKShownColsNamesKey] mutableCopy] autorelease];

    unsigned idx;
    BOOL didFixIdentifier = NO;
    NSDictionary *legacyKeys = [NSDictionary dictionaryWithObjectsAndKeys:BDSKDateAddedString, @"Added", BDSKDateAddedString, @"Created", BDSKDateModifiedString, @"Modified", BDSKAuthorEditorString, @"Authors Or Editors", BDSKAuthorString, @"Authors", nil];
    NSEnumerator *keyEnum = [legacyKeys keyEnumerator];
    NSString *key;
    
    while (key = [keyEnum nextObject]) {
        if ((idx = [fixedTableColumnIdentifiers indexOfObject:key]) != NSNotFound) {
            didFixIdentifier = YES;
            [fixedTableColumnIdentifiers replaceObjectAtIndex:idx withObject:[legacyKeys objectForKey:key]];
        }
    }
    if (didFixIdentifier)
        [sud setObject:fixedTableColumnIdentifiers forKey:BDSKShownColsNamesKey];
}

- (id)init
{
    if(self = [super init]){
        requiredFieldsForCiteKey = nil;
        requiredFieldsForLocalFile = nil;
        
        metadataCacheLock = [[NSLock alloc] init];
        canWriteMetadata = 1;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[requiredFieldsForCiteKey release];
    [metadataCacheLock release];
    [super dealloc];
}

- (void)awakeFromNib{   
    // Add a Scripts menu; searches in (mainbundle)/Contents/Scripts and (Library domains)/Application Support/BibDesk/Scripts
    if([BDSKScriptMenu disabled] == NO){
        [BDSKScriptMenu addScriptsToMainMenu];
    }
    
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
        NSMenu *fileMenu = [[[NSApp mainMenu] itemAtIndex:1] submenu];
        unsigned int idx = [fileMenu indexOfItemWithTarget:nil andAction:@selector(runPageLayout:)];
        if (idx != NSNotFound)
            [fileMenu removeItemAtIndex:idx];
    }
}

- (void)copyAllExportTemplatesToApplicationSupportAndOverwrite:(BOOL)overwrite{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *applicationSupport = [fileManager currentApplicationSupportPathForCurrentUser];
    NSString *templates = @"Templates";
    NSString *templatesPath = [applicationSupport stringByAppendingPathComponent:templates];
    BOOL success = NO;
    
    if ([fileManager fileExistsAtPath:templatesPath isDirectory:&success] == NO) {
        success = [fileManager createDirectoryAtPath:templatesPath attributes:nil];
    }
    
    if (success) {
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"htmlExportTemplate.html"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"htmlItemExportTemplate.html"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"htmlExportStyleSheet.css"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"rssExportTemplate.rss"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"rtfExportTemplate.rtf"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"rtfdExportTemplate.rtfd"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"docExportTemplate.doc"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"citeServiceTemplate.txt"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"textServiceTemplate.txt"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"rtfServiceTemplate.rtf"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"rtfServiceTemplate default item.rtf"] overwrite:overwrite];
        [fileManager copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:@"rtfServiceTemplate book.rtf"] overwrite:overwrite];
    }    
}

- (void)checkFormatStrings {
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    NSString *formatString = [sud objectForKey:BDSKCiteKeyFormatKey];
    NSString *error = nil;
    int button = 0;
    
    if ([BDSKFormatParser validateFormat:&formatString forField:BDSKCiteKeyString inFileType:BDSKBibtexString error:&error]) {
        [sud setObject:formatString forKey:BDSKCiteKeyFormatKey];
        [self setRequiredFieldsForCiteKey: [BDSKFormatParser requiredFieldsForFormat:formatString]];
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
            [self setRequiredFieldsForCiteKey: [BDSKFormatParser requiredFieldsForFormat:formatString]];
        }else{
            [[BDSKPreferenceController sharedPreferenceController] showWindow:self];
            [[BDSKPreferenceController sharedPreferenceController] selectPaneWithIdentifier:@"edu.ucsd.cs.mmccrack.bibdesk.prefpane.citekey"];
        }
    }
    
    formatString = [sud objectForKey:BDSKLocalFileFormatKey];
    error = nil;
    
    if ([sud boolForKey:@"BDSKDidMigrateLocalUrlFormatDefaultsKey"] == NO) {
        id oldFormatString = [sud objectForKey:@"Local-Url Format"];
        if (oldFormatString) {
            int formatPresetChoice = [sud objectForKey:@"Local-Url Format Preset"] ? [sud integerForKey:@"Local-Url Format Preset"] : 2;
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
        [sud setBool:YES forKey:@"BDSKDidMigrateLocalUrlFormatDefaultsKey"];
    }
    
    if ([BDSKFormatParser validateFormat:&formatString forField:BDSKLocalFileString inFileType:BDSKBibtexString error:&error]) {
        [sud setObject:formatString forKey:BDSKLocalFileFormatKey];
        [self setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:formatString]];
    } else {
        NSString *fixedFormatString = nil;
        NSString *otherButton = nil;
        if ([formatString hasSuffix:@"%e"]) {
            unsigned i = [formatString length] - 2;
            fixedFormatString = [[formatString substringToIndex:i] stringByAppendingString:@"%n0%e"];
        } else if ([formatString hasSuffix:@"%L"]) {
            unsigned i = [formatString length] - 2;
            fixedFormatString = [[formatString substringToIndex:i] stringByAppendingString:@"%l%n0%e"];
        } else if ([formatString rangeOfString:@"."].length) {
            fixedFormatString = [[[formatString stringByDeletingPathExtension] stringByAppendingString:@"%n0"] stringByAppendingPathExtension:[formatString pathExtension]];
        }
        if (fixedFormatString && [BDSKFormatParser validateFormat:&fixedFormatString forField:BDSKLocalFileString inFileType:BDSKBibtexString error:NULL]) {
            [sud setObject:fixedFormatString forKey:BDSKLocalFileFormatKey];
            [self setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:fixedFormatString]];
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
            [self setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:fixedFormatString]];
            [[BDSKPreferenceController sharedPreferenceController] showWindow:self];
            [[BDSKPreferenceController sharedPreferenceController] selectPaneWithIdentifier:@"edu.ucsd.cs.mmccrack.bibdesk.prefpane.autofile"];
        } else if (button == NSAlertAlternateReturn) {
            formatString = [[[NSUserDefaultsController sharedUserDefaultsController] initialValues] objectForKey:BDSKLocalFileFormatKey];			
            [sud setObject:formatString forKey:BDSKLocalFileFormatKey];
            [self setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:formatString]];
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
    int idx = 0;
    if ([personFields containsObject:BDSKAuthorString] == NO || [personFields containsObject:BDSKEditorString] == NO) {
        personFields  = [personFields mutableCopy];
        if ([personFields containsObject:BDSKAuthorString] == NO)
            [(NSMutableArray *)personFields insertObject:BDSKAuthorString atIndex:idx++];
        if ([personFields containsObject:BDSKEditorString] == NO)
            [(NSMutableArray *)personFields insertObject:BDSKEditorString atIndex:idx];
        [sud setObject:personFields forKey:BDSKPersonFieldsKey];
        [personFields release];
    }
    
    // name image to make it available app wide, also in IB
    static NSImage *nsCautionIcon = nil;
    nsCautionIcon = [[NSImage iconWithSize:NSMakeSize(16.0, 16.0) forToolboxCode:kAlertCautionIcon] retain];
    [nsCautionIcon setName:@"BDSKSmallCautionIcon"];
    
    [NSImage makeBookmarkImages];
    [NSImage makeGroupImages];
    
    // register NSURL as conversion handler for file types
    [NSAppleEventDescriptor registerConversionHandler:[NSURL class]
                                             selector:@selector(fileURLWithAEDesc:)
                                   forDescriptorTypes:typeFileURL, typeFSS, typeAlias, typeFSRef, nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    // validate the Cite Key and LocalUrl format strings
    [self checkFormatStrings];
    
    // register URL handler
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    
    // register services
    [NSApp setServicesProvider:self];
    [NSApp registerServicesMenuSendTypes:[NSArray arrayWithObject:NSStringPboardType] returnTypes:[NSArray arrayWithObject:NSStringPboardType]];
    
    // register server for cite key completion
    completionConnection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
    NSProtocolChecker *checker = [NSProtocolChecker protocolCheckerWithTarget:self protocol:@protocol(BDSKCompletionServer)];
    [completionConnection setRootObject:checker];
    
    if ([completionConnection registerName:BIBDESK_SERVER_NAME] == NO)
        NSLog(@"failed to register completion connection; another BibDesk process must be running");  
    
    NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if(![versionString isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:BDSKLastVersionLaunchedKey]])
        [self showRelNotes:nil];
    if([[NSUserDefaults standardUserDefaults] objectForKey:BDSKLastVersionLaunchedKey] == nil) // show new users the readme file; others just see the release notes
        [self showReadMeFile:nil];
    [[NSUserDefaults standardUserDefaults] setObject:versionString forKey:BDSKLastVersionLaunchedKey];
    
    BOOL inputManagerIsCurrent;
    if([self isInputManagerInstalledAndCurrent:&inputManagerIsCurrent] && inputManagerIsCurrent == NO)
        [self showInputManagerUpdateAlert];
    
    // Ensure the previewer and TeX task get created now in order to avoid a spurious "unable to copy helper file" warning when quit->document window closes->first call to [BDSKPreviewer sharedPreviewer]
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey])
        [BDSKPreviewer sharedPreviewer];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShowingPreviewKey])
		[[BDSKPreviewer sharedPreviewer] showWindow:self];
    
    // copy files to application support
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [self copyAllExportTemplatesToApplicationSupportAndOverwrite:NO];        
    [fileManager copyFileFromSharedSupportToApplicationSupport:@"previewtemplate.tex" overwrite:NO];
    [fileManager copyFileFromSharedSupportToApplicationSupport:@"template.txt" overwrite:NO];   
    [fileManager copyFileFromSharedSupportToApplicationSupport:@"Bookmarks.plist" overwrite:NO];   

    NSString *scriptsPath = [[fileManager currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"Scripts"];
    if ([fileManager fileExistsAtPath:scriptsPath] == NO)
        [fileManager createDirectoryAtPath:scriptsPath attributes:nil];
    
    [self doSpotlightImportIfNeeded];
    
    // Improve web group perf on 10.5: http://lists.apple.com/archives/cocoa-dev/2007/Dec/msg00261.html
    // header does't say this is 10.5 only, but it doesn't show up in the 10.4u header
    if ([WebPreferences instancesRespondToSelector:@selector(setCacheModel:)])
        [[WebPreferences standardPreferences] setCacheModel:WebCacheModelDocumentBrowser];
    
    [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification{
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&canWriteMetadata);
    
    [[BDSKSharingServer defaultServer] disableSharing];
    
    [completionConnection registerName:nil];
    [[completionConnection receivePort] invalidate];
    [[completionConnection sendPort] invalidate];
    [completionConnection invalidate];
    [completionConnection release];
    
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
    switch ([[sud objectForKey:BDSKStartupBehaviorKey] intValue]) {
        case 0:
            return YES;
        case 1:
            return NO;
        case 2:
            [[NSDocumentController sharedDocumentController] openDocument:nil];
            return NO;
        case 3:
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
        case 4:
            {
                NSArray *files = [sud objectForKey:BDSKLastOpenFileNamesKey];
                NSEnumerator *fileEnum = [files objectEnumerator];
                NSDictionary *dict;
                NSURL *fileURL;
                while (dict = [fileEnum nextObject]){ 
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

// we don't want to reopen last open files when re-activating the app
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    int startupOption = [[[NSUserDefaults standardUserDefaults] objectForKey:BDSKStartupBehaviorKey] intValue];
    return flag == NO && (startupOption == 0 || startupOption == 3);
}

- (void)openRecentItemFromDock:(id)sender{
    BDSKASSERT([sender isKindOfClass:[NSMenuItem class]]);
    NSURL *url = [sender representedObject];
    if(url == nil) 
        return NSBeep();
    
    // open... methods automatically call addDocument, so we don't have to
    NSError *error;
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&error];
}    

- (NSMenu *)applicationDockMenu:(NSApplication *)sender{
    NSMenu *menu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""] autorelease];
    NSMenu *submenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""] autorelease];

    NSArray *urls = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
    NSURL *url;
    NSMenuItem *anItem;
    NSEnumerator *urlE = [urls objectEnumerator];

    anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Open Recent",  @"Recent Documents dock menu title") action:nil keyEquivalent:@""];
    [anItem setSubmenu:submenu];
	[menu addItem:anItem];
    [anItem release];
    
    while(url = [urlE nextObject]){
        anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[url lastPathComponent] action:@selector(openRecentItemFromDock:) keyEquivalent:@""];
        [anItem setTarget:self];
        [anItem setRepresentedObject:url];
        
        // Supposed to be able to set the image this way according to a post from jcr on cocoadev, but all I get is a weird [obj] image on 10.4.  Apparently this is possible with Carbon <http://developer.apple.com/documentation/Carbon/Conceptual/customizing_docktile/index.html> but it involves event handlers and other nasty things, even more painful than adding an image to an attributed string.
#if 0
        NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] init];
        NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] init];
        [attachmentCell setImage:[NSImage imageForURL:url]];
        
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        [attachment setAttachmentCell:attachmentCell];
        [attachmentCell release];
        [attrTitle appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
        [attachment release];
        
        [attrTitle appendString:@" " attributes:nil];
        [attrTitle appendString:[anItem title]];
        [anItem setAttributedTitle:attrTitle];
        [attrTitle release];
#endif        
        [submenu addItem:anItem];
        [anItem release];
    }
    
    return menu;
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

#pragma mark Updater

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"BDSKUpdateCheckIntervalKey"]) {
        // the user already used an older version of BibDesk
        [updater setAutomaticallyChecksForUpdates:[[NSUserDefaults standardUserDefaults] integerForKey:@"BDSKUpdateCheckIntervalKey"] >= 0];
        return NO;
    }
    return YES;
}

#pragma mark Menu stuff

- (NSMenu *)groupSortMenu {
	return groupSortMenu;
}

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
    int i, iMax = [bookmarks count];
    for (i = 0; i < iMax; i++) {
        BDSKSearchBookmark *bm = [bookmarks objectAtIndex:i];
        if ([bm bookmarkType] == BDSKSearchBookmarkTypeFolder) {
            NSString *label = [bm label];
            NSMenu *submenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:[bm label]] autorelease];
            NSMenuItem *item = [menu addItemWithTitle:label ?: @"" action:NULL keyEquivalent:@""];
            [item setImage:[bm icon]];
            [item setSubmenu:submenu];
            [self addMenuItemsForSearchBookmarks:[bm children] toMenu:submenu];
        } else if ([bm bookmarkType] == BDSKSearchBookmarkTypeSeparator) {
            [menu addItem:[NSMenuItem separatorItem]];
        } else {
            NSString *label = [bm label];
            NSMenuItem *item = [menu addItemWithTitle:label ?: @"" action:@selector(newSearchGroupFromBookmark:)  keyEquivalent:@""];
            [item setRepresentedObject:[bm info]];
            [item setImage:[bm icon]];
        }
    }
}

- (void)addMenuItemsForBookmarks:(NSArray *)bookmarks toMenu:(NSMenu *)menu {
    int i, iMax = [bookmarks count];
    for (i = 0; i < iMax; i++) {
        BDSKBookmark *bm = [bookmarks objectAtIndex:i];
        if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
            NSString *name = [bm name];
            NSMenu *submenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:[bm name]] autorelease];
            NSMenuItem *item = [menu addItemWithTitle:name ?: @"" action:NULL keyEquivalent:@""];
            [item setImage:[bm icon]];
            [item setSubmenu:submenu];
            [self addMenuItemsForBookmarks:[bm children] toMenu:submenu];
        } else if ([bm bookmarkType] == BDSKBookmarkTypeSeparator) {
            [menu addItem:[NSMenuItem separatorItem]];
        } else {
            NSString *name = [bm name];
            NSMenuItem *item = [menu addItemWithTitle:name ?: @"" action:@selector(openBookmark:)  keyEquivalent:@""];
            [item setRepresentedObject:[bm URL]];
            [item setImage:[bm icon]];
        }
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    
    if ([menu isEqual:columnsMenu]) {
                
        // remove all items; then fill it with the items from the current document
        while([menu numberOfItems])
            [menu removeItemAtIndex:0];
        
        BibDocument *document = (BibDocument *)[[NSDocumentController sharedDocumentController] currentDocument];
        [menu addItemsFromMenu:[document columnsMenu]];
        
    } else if ([menu isEqual:copyAsTemplateMenu]) {
    
        NSArray *styles = [BDSKTemplate allStyleNames];
        int i = [menu numberOfItems];
        while (i--) {
            if ([[menu itemAtIndex:i] tag] < BDSKTemplateDragCopyType)
                break;
            [menu removeItemAtIndex:i];
        }
        
        NSMenuItem *item;
        int count = [styles count];
        for (i = 0; i < count; i++) {
            item = [menu addItemWithTitle:[styles objectAtIndex:i] action:@selector(copyAsAction:) keyEquivalent:@""];
            [item setTag:BDSKTemplateDragCopyType + i];
        }
        
    } else if ([menu isEqual:previewDisplayMenu] || [menu isEqual:sidePreviewDisplayMenu]) {
    
        NSMutableArray *styles = [NSMutableArray arrayWithArray:[BDSKTemplate allStyleNamesForFileType:@"rtf"]];
        [styles addObjectsFromArray:[BDSKTemplate allStyleNamesForFileType:@"rtfd"]];
        [styles addObjectsFromArray:[BDSKTemplate allStyleNamesForFileType:@"doc"]];
        [styles addObjectsFromArray:[BDSKTemplate allStyleNamesForFileType:@"html"]];
        
        int i = [menu numberOfItems];
        while (i-- && [[menu itemAtIndex:i] isSeparatorItem] == NO)
            [menu removeItemAtIndex:i];
        
        NSMenuItem *item;
        NSEnumerator *styleEnum = [styles objectEnumerator];
        NSString *style;
        SEL action = [menu isEqual:previewDisplayMenu] ? @selector(changePreviewDisplay:) : @selector(changeSidePreviewDisplay:);
        while (style = [styleEnum nextObject]) {
            item = [menu addItemWithTitle:style action:action keyEquivalent:@""];
            [item setTag:BDSKPreviewDisplayText];
            [item setRepresentedObject:style];
        }
        
    } else if ([menu isEqual:searchBookmarksMenu]) {
        
        NSArray *bookmarks = [[[BDSKSearchBookmarkController sharedBookmarkController] bookmarkRoot] children];
        int i = [menu numberOfItems];
        while (--i > 2)
            [menu removeItemAtIndex:i];
        if ([bookmarks count] > 0)
            [menu addItem:[NSMenuItem separatorItem]];
        [self addMenuItemsForSearchBookmarks:bookmarks toMenu:menu];
        
    } else if ([menu isEqual:bookmarksMenu]) {
        
        NSArray *bookmarks = [[[BDSKBookmarkController sharedBookmarkController] bookmarkRoot] children];
        int i = [menu numberOfItems];
        while (--i > 1)
            [menu removeItemAtIndex:i];
        if ([bookmarks count] > 0)
            [menu addItem:[NSMenuItem separatorItem]];
        [self addMenuItemsForBookmarks:bookmarks toMenu:menu];
        
    }
}

- (IBAction)reportBug:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sourceforge.net/tracker/?group_id=61487&atid=497423"]];
}

- (IBAction)requestFeature:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sourceforge.net/tracker/?group_id=61487&atid=497426"]];
}

#pragma mark Auto generation format stuff

- (NSArray *)requiredFieldsForCiteKey{
	return requiredFieldsForCiteKey;
}

- (void)setRequiredFieldsForCiteKey:(NSArray *)newFields{
	[requiredFieldsForCiteKey autorelease];
	requiredFieldsForCiteKey = [newFields retain];
}

- (NSArray *)requiredFieldsForLocalFile{
	return requiredFieldsForLocalFile;
}

- (void)setRequiredFieldsForLocalFile:(NSArray *)newFields{
	[requiredFieldsForLocalFile autorelease];
	requiredFieldsForLocalFile = [newFields retain];
}

- (NSString *)folderPathForFilingPapersFromDocument:(id<BDSKOwner>)owner {
	NSString *papersFolderPath = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKPapersFolderPathKey];
	if ([NSString isEmptyString:papersFolderPath])
		papersFolderPath = [[[owner fileURL] path] stringByDeletingLastPathComponent];
	if ([NSString isEmptyString:papersFolderPath])
		papersFolderPath = NSHomeDirectory();
	return [papersFolderPath stringByExpandingTildeInPath];
}

#pragma mark DO completion

- (NSArray *)completionsForString:(NSString *)searchString;
{
	NSMutableArray *results = [NSMutableArray array];

    NSEnumerator *myEnum = [[NSApp orderedDocuments] objectEnumerator];
    BibDocument *document = nil;
    
    // for empty search string, return all items

    while (document = [myEnum nextObject]) {
        
        NSArray *pubs = [NSString isEmptyString:searchString] ? [document publications] : [document findMatchesFor:searchString];
        [results addObjectsFromArray:[pubs arrayByPerformingSelector:@selector(completionObject)]];
    }
	return results;
}

- (NSArray *)orderedDocumentURLs;
{
    NSMutableArray *theURLs = [NSMutableArray array];
    NSEnumerator *docE = [[NSApp orderedDocuments] objectEnumerator];
    id aDoc;
    while (aDoc = [docE nextObject]) {
        if ([aDoc fileURL])
            [theURLs addObject:[aDoc fileURL]];
    }
    return theURLs;
}

#pragma mark Input manager

- (BOOL)isInputManagerInstalledAndCurrent:(BOOL *)current{
    NSParameterAssert(current != NULL);
    
    // Someone may be mad enough to install this in NSLocalDomain or NSNetworkDomain, but we don't support that since it would require admin rights.  As of 10.5, input managers must be installed in NSLocalDomain, and have certain permissions set.  Because of this, and because the input manager has been a PITA to support, we ignore it on 10.5.
    NSString *inputManagerBundlePath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"/InputManagers/BibDeskInputManager/BibDeskInputManager.bundle"];

    NSString *bundlePath = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"BibDeskInputManager/BibDeskInputManager.bundle"];
    NSString *bundledVersion = [[[NSBundle bundleWithPath:bundlePath] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    NSString *installedVersion = [[[NSBundle bundleWithPath:inputManagerBundlePath] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    
    // one-time alert when launching on Leopard
    if (nil != installedVersion && floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKShowedLeopardInputManagerAlert"] == NO) {
            
            NSString *folderPath = [inputManagerBundlePath stringByDeletingLastPathComponent];
            
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Completion Plugin is Disabled", @"Leopard warning") defaultButton:NSLocalizedString(@"Show", @"") alternateButton:NSLocalizedString(@"Ignore",@"") otherButton:nil informativeTextWithFormat:NSLocalizedString(@"Due to security restrictions in Mac OS X 10.5, the completion plugin located in %@ is now disabled and will no longer be supported.  Show in Finder?", @"input manager warning"), [folderPath stringByAbbreviatingWithTildeInPath]];
            int rv = [alert runModal];
            if (NSAlertDefaultReturn == rv)
                [[NSWorkspace sharedWorkspace] selectFile:folderPath inFileViewerRootedAtPath:@""];
        }
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"BDSKShowedLeopardInputManagerAlert"];
        
        // set installed version to nil, so we never display an update alert
        installedVersion = nil;
    }
    
    *current = [bundledVersion isEqualToString:installedVersion];
    return installedVersion == nil ? NO : YES;
}

- (void)showInputManagerUpdateAlert{
    NSAlert *anAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Autocomplete Plugin Needs Update", @"Message in alert dialog when plugin version")
                                       defaultButton:[NSLocalizedString(@"Open", @"Button title") stringByAppendingString:[NSString horizontalEllipsisString]]
                                     alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                         otherButton:nil
                           informativeTextWithFormat:NSLocalizedString(@"You appear to be using the BibDesk autocompletion plugin, and a newer version is available.  Would you like to open the completion preferences so that you can update the plugin?", @"Informative text in alert dialog")];
    int rv = [anAlert runModal];
    if(rv == NSAlertDefaultReturn){
        [[BDSKPreferenceController sharedPreferenceController] showWindow:nil];
        [[BDSKPreferenceController sharedPreferenceController] selectPaneWithIdentifier:@"edu.ucsd.cs.mmccrack.bibdesk.prefpane.inputmanager"];
    }
    
}

#pragma mark Panels

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

#pragma mark URL handling code

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent{
    NSString *theURLString = [[event descriptorForKeyword:keyDirectObject] stringValue];
    NSURL *theURL = nil;
    BibDocument *document = nil;
    NSError *error = nil;
    
    if (theURLString) {
        if ([theURLString hasPrefix:@"<"] && [theURLString hasSuffix:@">"])
            theURLString = [theURLString substringWithRange:NSMakeRange(0, [theURLString length] - 2)];
        if ([theURLString hasPrefix:@"URL:"])
            theURLString = [theURLString substringFromIndex:4];
        theURL = [NSURL URLWithString:theURLString] ?: [NSURL URLWithStringByNormalizingPercentEscapes:theURLString];
    }
    
    if ([[theURL scheme] isEqualToString:@"x-bdsk"]) {
        
        NSString *citeKey = [[theURLString substringFromIndex:9] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *path = [[NSFileManager defaultManager] spotlightCacheFilePathWithCiteKey:citeKey];
        NSURL *fileURL;
        
        if (path && (fileURL = [NSURL fileURLWithPath:path])) {
            document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES error:&error];
        } else {
            error = [NSError mutableLocalErrorWithCode:kBDSKURLOperationFailed localizedDescription:NSLocalizedString(@"Unable to get item from bdsk:// URL.", @"error when opening bdskURL")];
        }
        
    } else if ([[theURL scheme] isEqualToString:@"x-bdsk-search"]) {
        
        BDSKSearchGroup *group = [[BDSKSearchGroup alloc] initWithURL:theURL];
        
        if (group) {
            // try the main document first
            document = [[NSDocumentController sharedDocumentController] mainDocument];
            if (nil == document) {
                document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&error];
                [document showWindows];
            }
            
            [[document groups] addSearchGroup:group];
            [group release];
        } else {
            error = [NSError mutableLocalErrorWithCode:kBDSKURLOperationFailed localizedDescription:NSLocalizedString(@"Unable to get search group from bdsksearch:// URL.", @"error when opening bdsksearch URL")];
        }
        
    } else if (([[theURL scheme] isEqualToString:@"http"] || [[theURL scheme] isEqualToString:@"https"]) &&
               [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldShowWebGroupPrefKey]) {
        
        // try the main document first
        document = [[NSDocumentController sharedDocumentController] mainDocument];
        if (nil == document) {
            document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&error];
            [document showWindows];
        }
        [document selectGroup:[[document groups] webGroup]];
        [[document webGroupViewController] setURLString:[theURL absoluteString]];
        
        if (document == nil && error)
            [NSApp presentError:error];
        
    } else {
        
        [[NSWorkspace sharedWorkspace] openURL:theURL];
        
    }
}

#pragma mark Service code

- (NSDictionary *)constraintsFromString:(NSString *)string{
    NSScanner *scanner;
    NSMutableDictionary *searchConstraints = [NSMutableDictionary dictionary];
    NSString *queryString = nil;
    NSString *queryKey = nil;
    NSCharacterSet *delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@":="];
    NSCharacterSet *ampersandSet =  [NSCharacterSet characterSetWithCharactersInString:@"&"];

    if([string rangeOfCharacterFromSet:delimiterSet].location == NSNotFound){
        [searchConstraints setObject:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:BDSKTitleString];
        return searchConstraints;
    }
    
    
    scanner = [NSScanner scannerWithString:string];
    
    // Now split the string into a key and value pair by looking for a delimiter
    // (we'll use a bunch of handy delimiters, including the first space, so it's flexible.)
    // alternatively we can just type the title, like we used to.
    [scanner setCharactersToBeSkipped:nil];
    NSSet *citeKeyStrings = [NSSet setForCaseInsensitiveStringsWithObjects:@"cite key", @"citekey", @"cite-key", @"key", nil];
    
    while(![scanner isAtEnd]){
        // set these to nil explicitly, since we check for that later
        queryKey = nil;
        queryString = nil;
        [scanner scanUpToCharactersFromSet:delimiterSet intoString:&queryKey];
        [scanner scanCharactersFromSet:delimiterSet intoString:nil]; // scan the delimiters away
        [scanner scanUpToCharactersFromSet:ampersandSet intoString:&queryString]; // scan to either the end, or the next query key.
        [scanner scanCharactersFromSet:ampersandSet intoString:nil]; // scan the ampersands away.
        
        // lose the whitespace, if any
        queryString = [queryString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        queryKey = [queryKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // allow some additional leeway with citekey
        if([citeKeyStrings containsObject:queryKey])
            queryKey = BDSKCiteKeyString;
        
        if(queryKey && queryString) // make sure we have both a key and a value
            [searchConstraints setObject:queryString forKey:[queryKey fieldName]]; // BibItem field names are capitalized
    }
    
    return searchConstraints;
}

- (void)completeCitationFromSelection:(NSPasteboard *)pboard
                             userData:(NSString *)userData
                                error:(NSString **)error{
    NSString *pboardString;
    NSArray *types;
    NSSet *items;
    BDSKTemplate *template = [BDSKTemplate templateForCiteService];
    BDSKPRECONDITION(nil != template && ([template templateFormat] & BDSKPlainTextTemplateFormat));
    
    types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    pboardString = [pboard stringForType:NSStringPboardType];
    if (!pboardString) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }

    NSDictionary *searchConstraints = [self constraintsFromString:pboardString];
    
    if(searchConstraints == nil){
        *error = NSLocalizedString(@"Error: invalid search constraints.",
                                   @"Error description for Service");
        return;
    }        

    items = [self itemsMatchingSearchConstraints:searchConstraints];
    
    if([items count] > 0){
        NSString *fileTemplate = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:[items allObjects]];
        
        types = [NSArray arrayWithObject:NSStringPboardType];
        [pboard declareTypes:types owner:nil];

        [pboard setString:fileTemplate forType:NSStringPboardType];
    }
    return;
}

- (void)completeTextBibliographyFromSelection:(NSPasteboard *)pboard
                                     userData:(NSString *)userData
                                        error:(NSString **)error{
    NSString *pboardString;
    NSArray *types;
    NSSet *items;
    BDSKTemplate *template = [BDSKTemplate templateForTextService];
    BDSKPRECONDITION(nil != template && ([template templateFormat] & BDSKPlainTextTemplateFormat));
    
    types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    pboardString = [pboard stringForType:NSStringPboardType];
    if (!pboardString) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }

    NSDictionary *searchConstraints = [self constraintsFromString:pboardString];
    
    if(searchConstraints == nil){
        *error = NSLocalizedString(@"Error: invalid search constraints.",
                                   @"Error description for Service");
        return;
    }        

    items = [self itemsMatchingSearchConstraints:searchConstraints];
    
    if([items count] > 0){
        NSString *fileTemplate = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:[items allObjects]];
        
        types = [NSArray arrayWithObject:NSStringPboardType];
        [pboard declareTypes:types owner:nil];

        [pboard setString:fileTemplate forType:NSStringPboardType];
    }
    return;
}

- (void)completeRichBibliographyFromSelection:(NSPasteboard *)pboard
                                     userData:(NSString *)userData
                                        error:(NSString **)error{
    NSString *pboardString;
    NSArray *types;
    NSSet *items;
    BDSKTemplate *template = [BDSKTemplate templateForRTFService];
    BDSKPRECONDITION(nil != template && [template templateFormat] == BDSKRTFTemplateFormat);
    
    types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    pboardString = [pboard stringForType:NSStringPboardType];
    if (!pboardString) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }

    NSDictionary *searchConstraints = [self constraintsFromString:pboardString];
    
    if(searchConstraints == nil){
        *error = NSLocalizedString(@"Error: invalid search constraints.",
                                   @"Error description for Service");
        return;
    }        

    items = [self itemsMatchingSearchConstraints:searchConstraints];
    
    if([items count] > 0){
        NSDictionary *docAttributes = nil;
        NSAttributedString *fileTemplate = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:[items allObjects] documentAttributes:&docAttributes];
        NSData *pboardData = [fileTemplate RTFFromRange:NSMakeRange(0, [fileTemplate length]) documentAttributes:docAttributes];
        
        types = [NSArray arrayWithObject:NSRTFPboardType];
        [pboard declareTypes:types owner:nil];

        [pboard setData:pboardData forType:NSRTFPboardType];
    }
    return;
}

// this only should return items that belong to a document, not items from external groups
// if this is ever changed, we should also change showPubWithKey:userData:error:
- (NSSet *)itemsMatchingSearchConstraints:(NSDictionary *)constraints{
    NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
    if([docs count] == 0)
        return nil;

    NSMutableSet *itemsFound = [NSMutableSet set];
    NSMutableArray *arrayOfSets = [NSMutableArray array];
    
    NSEnumerator *constraintsKeyEnum = [constraints keyEnumerator];
    NSString *constraintKey = nil;
    BibDocument *aDoc = nil;

    while(constraintKey = [constraintsKeyEnum nextObject]){
        
        NSEnumerator *docEnum = [docs objectEnumerator];
        
        while(aDoc = [docEnum nextObject]){ 
	    // this is an array of objects matching this particular set of search constraints; add them to the set
            [itemsFound addObjectsFromArray:[aDoc publicationsMatchingSubstring:[constraints objectForKey:constraintKey] 
                                                                        inField:constraintKey]];
        }
        // we have one set per search term, so copy it to an array and we'll get the next set of matches
        [arrayOfSets addObject:[[itemsFound copy] autorelease]];
        [itemsFound removeAllObjects];
    }
    
    // sort the sets in order of increasing length indexed 0-->[arrayOfSets length]
    NSSortDescriptor *setLengthSort = [[[NSSortDescriptor alloc] initWithKey:@"self.@count" ascending:YES selector:@selector(compare:)] autorelease];
    [arrayOfSets sortUsingDescriptors:[NSArray arrayWithObject:setLengthSort]];

    [itemsFound setSet:[arrayOfSets firstObject]]; // smallest set
    [itemsFound performSelector:@selector(intersectSet:) withObjectsFromArray:arrayOfSets];
    
    return itemsFound;
}

- (NSSet *)itemsMatchingCiteKey:(NSString *)citeKeyString{
    NSDictionary *constraints = [NSDictionary dictionaryWithObject:citeKeyString forKey:BDSKCiteKeyString];
    return [self itemsMatchingSearchConstraints:constraints];
}

- (void)completeCiteKeyFromSelection:(NSPasteboard *)pboard
                             userData:(NSString *)userData
                                error:(NSString **)error{

    NSArray *types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    NSString *pboardString = [pboard stringForType:NSStringPboardType];
    NSSet *items = [self itemsMatchingCiteKey:pboardString];
    
    // if no matches, we'll return the original string unchanged
    if ([items count]) {
        pboardString = [[[[items allObjects] arrayByPerformingSelector:@selector(citeKey)] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByComma];
    }
    
    types = [NSArray arrayWithObject:NSStringPboardType];
    [pboard declareTypes:types owner:nil];
    [pboard setString:pboardString forType:NSStringPboardType];
}

- (void)showPubWithKey:(NSPasteboard *)pboard
			  userData:(NSString *)userData
				 error:(NSString **)error{	
    NSArray *types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    NSString *pboardString = [pboard stringForType:NSStringPboardType];

    NSSet *items = [self itemsMatchingCiteKey:pboardString];
	BibItem *item;
	NSEnumerator *itemE = [items objectEnumerator];
    
    while(item = [itemE nextObject]){   
        // these should all be items belonging to a BibDocument, see remark before itemsMatchingSearchConstraints:
		[(BibDocument *)[item owner] editPub:item];
    }

}

- (void)newDocumentFromSelection:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error{	

    id doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
    NSError *nsError = nil;
    
    if([doc addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:NO error:&nsError] == NO){
        if(error)
            *error = [nsError localizedDescription];
        [doc presentError:nsError];
    }
}

- (void)addPublicationsFromSelection:(NSPasteboard *)pboard
						   userData:(NSString *)userData
							  error:(NSString **)error{	
	
	// add to the frontmost bibliography
	BibDocument * doc = [[NSDocumentController sharedDocumentController] mainDocument];
    if (nil == doc) {
        // create a new document if we don't have one, or else this method appears to fail mysteriosly (since the error isn't displayed)
        [self newDocumentFromSelection:pboard userData:userData error:error];
	} else {
        NSError *addError = nil;
        if([doc addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:NO error:&addError] == NO || addError != nil)
        if(error) *error = [addError localizedDescription];
    }
}

#pragma mark Spotlight support

- (void)privateRebuildMetadataCache:(id)userInfo{
    
    BDSKPRECONDITION([NSThread isMainThread] == NO);
    
    // we could unlock after checking the flag, but we don't want multiple threads writing to the cache directory at the same time, in case files have identical items
    [metadataCacheLock lock];
    OSMemoryBarrier();
    if(canWriteMetadata == 0){
        NSLog(@"Application will quit without writing metadata cache.");
        [metadataCacheLock unlock];
        return;
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [userInfo retain];
    
    NSArray *publications = [userInfo valueForKey:@"publications"];
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    @try{

        // hidden option to use XML plists for easier debugging, but the binary plists are more efficient
        BOOL useXMLFormat = [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKUseXMLSpotlightCache"];
        NSPropertyListFormat plistFormat = useXMLFormat ? NSPropertyListXMLFormat_v1_0 : NSPropertyListBinaryFormat_v1_0;

        NSString *cachePath = [fileManager spotlightCacheFolderPathByCreating:&error];
        if(cachePath == nil){
            error = [NSError localErrorWithCode:kBDSKFileOperationFailed localizedDescription:NSLocalizedString(@"Unable to create the cache folder for Spotlight metadata.", @"Error description") underlyingError:error];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to build metadata cache at path \"%@\"", cachePath] userInfo:nil];
        }
        
        NSURL *documentURL = [userInfo valueForKey:@"fileURL"];
        NSString *docPath = [documentURL path];
        
        // After this point, there should be no underlying NSError, so we'll create one from scratch
        
        if([fileManager objectExistsAtFileURL:documentURL] == NO){
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to find the file associated with this item.", @"Error description"), NSLocalizedDescriptionKey, docPath, NSFilePathErrorKey, nil]];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to build metadata cache for document at path \"%@\"", docPath] userInfo:nil];
        }
        
        NSString *path;
        NSString *citeKey;
        NSDictionary *anItem;
        
        BDAlias *alias = [[BDAlias alloc] initWithURL:documentURL];
        if(alias == nil){
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to create an alias for this document.", @"Error description"), NSLocalizedDescriptionKey, docPath, NSFilePathErrorKey, nil]];
            @throw [NSException exceptionWithName:NSObjectNotAvailableException reason:[NSString stringWithFormat:@"Unable to get an alias for file %@", docPath] userInfo:nil];
        }
        
        NSData *aliasData = [alias aliasData];
        [alias autorelease];
    
        NSEnumerator *entryEnum = [publications objectEnumerator];
        NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithCapacity:10];    
        
        while(anItem = [entryEnum nextObject]){
            OSMemoryBarrier();
            if(canWriteMetadata == 0){
                NSLog(@"Application will quit without finishing writing metadata cache.");
                break;
            }
            
            citeKey = [anItem objectForKey:@"net_sourceforge_bibdesk_citekey"];
            if(citeKey == nil)
                continue;
                        
            // we won't index this, but it's needed to reopen the parent file
            [metadata setObject:aliasData forKey:@"FileAlias"];
            // use doc path as a backup in case the alias fails
            [metadata setObject:docPath forKey:@"net_sourceforge_bibdesk_owningfilepath"];
            
            [metadata addEntriesFromDictionary:anItem];
			
            path = [fileManager spotlightCacheFilePathWithCiteKey:citeKey];

            // Save the plist; we can get an error if these are not plist objects, or the file couldn't be written.  The first case is a programmer error, and the second should have been caught much earlier in this code.
            if(path) {
                
                NSString *errString = nil;
                NSData *data = [NSPropertyListSerialization dataFromPropertyList:metadata format:plistFormat errorDescription:&errString];
                if(nil == data) {
                    error = [NSError mutableLocalErrorWithCode:kBDSKPropertyListSerializationFailed localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to save metadata cache file for item with cite key \"%@\".  The error was \"%@\"", @"Error description"), citeKey, errString]];
                    [errString release];
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to create cache file for %@", [anItem description]] userInfo:nil];
                } else {
                    if(NO == [data writeToFile:path options:NSAtomicWrite error:&error])
                        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to create cache file for %@", [anItem description]] userInfo:nil];
                }
            }
            [metadata removeAllObjects];
        }
    }    
    @catch (id localException){
        NSLog(@"-[%@ %@] discarding exception %@", [self class], NSStringFromSelector(_cmd), [localException description]);
        // log the error since presentError: only gives minimum info
        NSLog(@"%@", [error description]);
        [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
    }
    @finally{
        [userInfo release];
        [metadataCacheLock unlock];
        [pool release];
    }
}

- (void)rebuildMetadataCache:(id)userInfo{  
    [NSThread detachNewThreadSelector:@selector(privateRebuildMetadataCache:) toTarget:self withObject:userInfo];
}

- (void)doSpotlightImportIfNeeded {
    
    // This code finds the spotlight importer and re-runs it if the importer or app version has changed since the last time we launched.
    NSArray *pathComponents = [NSArray arrayWithObjects:[[NSBundle mainBundle] bundlePath], @"Contents", @"Library", @"Spotlight", @"BibImporter", nil];
    NSString *importerPath = [[NSString pathWithComponents:pathComponents] stringByAppendingPathExtension:@"mdimporter"];
    
    NSBundle *importerBundle = [NSBundle bundleWithPath:importerPath];
    NSString *importerVersion = [importerBundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    if (importerVersion) {
        BDSKVersionNumber *importerVersionNumber = [[[BDSKVersionNumber alloc] initWithVersionString:importerVersion] autorelease];
        NSDictionary *versionInfo = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKSpotlightVersionInfoKey];
        
        long sysVersion;
        OSStatus err = Gestalt(gestaltSystemVersion, &sysVersion);
        
        BOOL runImporter = NO;
        if ([versionInfo count] == 0) {
            runImporter = YES;
        } else {
            NSString *lastImporterVersion = [versionInfo objectForKey:@"lastImporterVersion"];
            BDSKVersionNumber *lastImporterVersionNumber = [[[BDSKVersionNumber alloc] initWithVersionString:lastImporterVersion] autorelease];
            
            long lastSysVersion = [[versionInfo objectForKey:@"lastSysVersion"] longValue];
            
            runImporter = noErr == err ? ([lastImporterVersionNumber compareToVersionNumber:importerVersionNumber] == NSOrderedAscending || sysVersion > lastSysVersion) : YES;
        }
        if (runImporter) {
            NSString *mdimportPath = @"/usr/bin/mdimport";
            if ([[NSFileManager defaultManager] isExecutableFileAtPath:mdimportPath]) {
                NSTask *importerTask = [[[NSTask alloc] init] autorelease];
                [importerTask setLaunchPath:mdimportPath];
                [importerTask setArguments:[NSArray arrayWithObjects:@"-r", importerPath, nil]];
                [importerTask launch];
                
                NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:sysVersion], @"lastSysVersion", importerVersion, @"lastImporterVersion", nil];
                [[NSUserDefaults standardUserDefaults] setObject:info forKey:BDSKSpotlightVersionInfoKey];
                
            }
            else NSLog(@"/usr/bin/mdimport not found!");
        }
    }
}

#pragma mark Email support

- (BOOL)emailTo:(NSString *)receiver subject:(NSString *)subject body:(NSString *)body attachments:(NSArray *)files {
    NSMutableString *scriptString = nil;
    
    NSString *mailAppName = nil;
    CFURLRef mailAppURL = NULL;
    OSStatus status = LSGetApplicationForURL((CFURLRef)[NSURL URLWithString:@"mailto:"], kLSRolesAll, NULL, &mailAppURL);
    if (status == noErr)
        mailAppName = [[[(NSURL *)mailAppURL path] lastPathComponent] stringByDeletingPathExtension];
    
    NSEnumerator *fileEnum = [files objectEnumerator];
    NSString *fileName;
    
    if ([mailAppName rangeOfString:@"Entourage" options:NSCaseInsensitiveSearch].length) {
        scriptString = [NSMutableString stringWithString:@"tell application \"Microsoft Entourage\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"set m to make new draft window with properties {subject: \"%@\"}\n", subject ?: @""];
        [scriptString appendString:@"tell m\n"];
        if (receiver)
            [scriptString appendFormat:@"set recipient to {address:{address: \"%@\", display name: \"%@\"}, recipient type:to recipient}}\n", receiver, receiver];
        if (body)
            [scriptString appendFormat:@"set content to \"%@\"\n", body];
        while (fileName = [fileEnum  nextObject])
            [scriptString appendFormat:@"make new attachment with properties {file:POSIX file \"%@\"}\n", fileName];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
    } else if ([mailAppName rangeOfString:@"Mailsmith" options:NSCaseInsensitiveSearch].length) {
        scriptString = [NSMutableString stringWithString:@"tell application \"Mailsmith\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"set m to make new message window with properties {subject: \"%@\"}\n", subject ?: @""];
        [scriptString appendString:@"tell m\n"];
        if (receiver)
            [scriptString appendFormat:@"make new to_recipient at end with properties {address: \"%@\"}\n", receiver];
        if (body)
            [scriptString appendFormat:@"set contents to \"%@\"\n", body];
        while (fileName = [fileEnum  nextObject])
            [scriptString appendFormat:@"make new enclosure with properties {file:POSIX file \"%@\"}\n", fileName];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
    } else {
        scriptString = [NSMutableString stringWithString:@"tell application \"Mail\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"set m to make new outgoing message with properties {subject: \"%@\", visible:true}\n", subject ?: @""];
        [scriptString appendString:@"tell m\n"];
        if (receiver)
            [scriptString appendFormat:@"make new to recipient at end of to recipients with properties {address: \"%@\"}\n", receiver];
        if (body)
            [scriptString appendFormat:@"set content to \"%@\"\n", body];
        [scriptString appendString:@"tell its content\n"];
        while (fileName = [fileEnum  nextObject])
            [scriptString appendFormat:@"make new attachment at after last character with properties {file name:\"%@\"}\n", fileName];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
    }
    
    if (scriptString) {
        NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:scriptString] autorelease];
        NSDictionary *errorDict = nil;
        if ([script compileAndReturnError:&errorDict] == NO) {
            NSLog(@"Error compiling mail to script: %@", errorDict);
            return NO;
        }
        if ([script executeAndReturnError:&errorDict] == NO) {
            NSLog(@"Error running mail to script: %@", errorDict);
            return NO;
        }
        return YES;
    }
    return NO;
}

@end
