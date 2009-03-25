//
//  BibPref_InputManager.m
//  BibDesk
//
//  Created by Adam Maxwell on Fri Aug 27 2004.
/*
 This software is Copyright (c) 2004-2009
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



#import "BibPref_InputManager.h"
#import "BDSKStringConstants.h"
#import "BDSKTypeManager.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKTextWithIconCell.h"
#import "NSSet_BDSKExtensions.h"
#import "BDSKAppController.h"
#import "NSURL_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKGradientTableView.h"

CFStringRef BDSKInputManagerID = CFSTR("net.sourceforge.bibdesk.inputmanager");
CFStringRef BDSKInputManagerLoadableApplications = CFSTR("Application bundles that we recognize");

#define BDSKBundleIdentifierKey @"bundleIdentifierKey"
#define tableIconSize 24


@interface BibPref_InputManager (Private)
- (void)updateUI;
- (void)addApplicationsWithIdentifiers:(NSArray *)identifiers;
- (void)synchronizePreferences;
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end


@implementation BibPref_InputManager

- (void)awakeFromNib{
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    inputManagerPath = [[libraryPath stringByAppendingPathComponent:@"/InputManagers/BibDeskInputManager"] retain];

    applications = [[NSMutableArray alloc] initWithCapacity:3];

    CFPropertyListRef prefs = CFPreferencesCopyAppValue(BDSKInputManagerLoadableApplications, BDSKInputManagerID );
                                                      
    if(prefs != nil){
        [self addApplicationsWithIdentifiers:(NSArray *)prefs];
        CFRelease(prefs);
    }
    	
    BDSKTextWithIconCell *cell = [[[BDSKTextWithIconCell alloc] init] autorelease];
    [cell setHasDarkHighlight:YES];
    [[tableView tableColumnWithIdentifier:@"AppList"] setDataCell:cell];
    [tableView setRowHeight:(tableIconSize + 2)];
    [tableView setBackgroundColor:[NSColor controlBackgroundColor]];

    NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:BDSKTextWithIconCellStringKey ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)] autorelease];
    [arrayController setSortDescriptors:[NSArray arrayWithObject:sort]];
    
    [self updateUI];
}

- (void)defaultsDidRevert {
    // reset UI and prefs on disk, because the pref controller won't do this as these are not our prefs
    if ([self isWindowLoaded]) {
        [arrayController setContent:[NSArray array]];
        [self synchronizePreferences];
        [self updateUI];
    } else {
        CFPreferencesSetAppValue(BDSKInputManagerLoadableApplications, (CFArrayRef)[NSArray array], BDSKInputManagerID);
        BOOL success = CFPreferencesAppSynchronize( (CFStringRef)BDSKInputManagerID );
        if(success == NO)
            NSLog(@"Failed to synchronize preferences for %@", BDSKInputManagerID);
    }
}

- (void)addApplicationsWithIdentifiers:(NSArray *)identifiers{
    NSParameterAssert(identifiers);
        
    NSString *bundleID;

    // use a set so we don't add duplicate items to the array (not that it's particularly harmful)
    NSMutableSet *currentBundleIdentifiers = [NSMutableSet setForCaseInsensitiveStrings];
    [currentBundleIdentifiers addObjectsFromArray:[[arrayController content] valueForKey:BDSKTextWithIconCellStringKey]];
    
    NSEnumerator *identifierE = [identifiers objectEnumerator];
        
    while((bundleID = [identifierE nextObject]) && ([currentBundleIdentifiers containsObject:bundleID] == NO)){
    
        CFURLRef theURL = nil;
        NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:2];
        
        OSStatus err = LSFindApplicationForInfo( kLSUnknownCreator,
                                                 (CFStringRef)bundleID,
                                                 NULL,
                                                 NULL,
                                                 &theURL );
        
        if(err == noErr){
            [dictionary setValue:[[(NSURL *)theURL lastPathComponent] stringByDeletingPathExtension] forKey:BDSKTextWithIconCellStringKey];
            [dictionary setValue:[[NSWorkspace sharedWorkspace] iconForFileURL:(NSURL *)theURL] forKey:BDSKTextWithIconCellImageKey];
            [dictionary setValue:bundleID forKey:BDSKBundleIdentifierKey];
        } else {
            // if LS failed us (my cache was corrupt when I wrote this code, so it's been tested)
            [dictionary setValue:[NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"Unable to find icon for",@"Message when unable to find app for plugin"), bundleID] forKey:BDSKTextWithIconCellStringKey];
            [dictionary setValue:[NSImage iconWithSize:NSMakeSize(tableIconSize, tableIconSize) forToolboxCode:kGenericApplicationIcon] forKey:BDSKTextWithIconCellImageKey];
            [dictionary setValue:bundleID forKey:BDSKBundleIdentifierKey];
        }
        
        [arrayController addObject:dictionary];
        [dictionary release];
    
    }
    [arrayController rearrangeObjects];
    [self synchronizePreferences];
}

// writes current displayed list to preferences
- (void)synchronizePreferences{
    
    // this should be a unique list of the identifiers that we previously had in prefs; bundles are compared case-insensitively
    NSMutableSet *applicationSet = [NSMutableSet setForCaseInsensitiveStrings];
    [applicationSet addObjectsFromArray:[[arrayController content] valueForKey:BDSKBundleIdentifierKey]];
    
    CFPreferencesSetAppValue(BDSKInputManagerLoadableApplications, (CFArrayRef)[applicationSet allObjects], BDSKInputManagerID);
    BOOL success = CFPreferencesAppSynchronize( (CFStringRef)BDSKInputManagerID );
    if(success == NO)
        NSLog(@"Failed to synchronize preferences for %@", BDSKInputManagerID);
    
}

- (void)dealloc{
    [inputManagerPath release];
    [applications release];
	[arrayController release];
    [super dealloc];
}

- (void)updateUI{
    BOOL isCurrent;
    if([[NSApp delegate] isInputManagerInstalledAndCurrent:&isCurrent])
        [enableButton setTitle:isCurrent ? NSLocalizedString(@"Reinstall",@"Button title") : NSLocalizedString(@"Update", @"Button title")];
    
    // this is a hack to show the blue highlight for the tableview, since it keeps losing first responder status
    [[[self view] window] makeFirstResponder:tableView];
}

#pragma mark Citekey autocompletion

- (void)enableCompletionSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    
    if(returnCode == NSAlertAlternateReturn){
        // set tableview as first responder
        [self updateUI];
        return; // do nothing; user chickened out
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL err = NO;
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    if(![fm fileExistsAtPath:[libraryPath stringByAppendingPathComponent:@"InputManagers"]]){
        if(![fm createDirectoryAtPath:[libraryPath stringByAppendingPathComponent:@"InputManagers"] attributes:nil]){
            NSLog(@"Unable to create the InputManagers folder at path @%",[libraryPath stringByAppendingPathComponent:@"InputManagers"]);
            err = YES;
        }
    }
    
    if(err == NO && [fm fileExistsAtPath:inputManagerPath] && ([fm isDeletableFileAtPath:inputManagerPath] == NO || [fm removeFileAtPath:inputManagerPath handler:nil] == NO)){
        NSLog(@"Error occurred while removing file %@", inputManagerPath);
        err = YES;
    }
	
    if(err == NO){
        [fm copyPath:[[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"BibDeskInputManager"] toPath:inputManagerPath handler:nil];
    } else {
        NSAlert *anAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error!",@"Message in alert dialog when an error occurs")
					   defaultButton:nil
					 alternateButton:nil
					     otherButton:nil
			       informativeTextWithFormat:NSLocalizedString(@"Unable to install plugin at %@, please check file or directory permissions.", @"Informative text in alert dialog"), inputManagerPath];
	[anAlert beginSheetModalForWindow:[[self view] window]
			    modalDelegate:nil
			   didEndSelector:nil
			      contextInfo:nil];    
    }
    [self updateUI]; // change button to "Reinstall"
    
}

- (IBAction)enableAutocompletion:(id)sender{
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning!", @"Message in alert dialog")
                                     defaultButton:NSLocalizedString(@"Proceed", @"Button title")
                                   alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"This will install a plugin bundle in ~/Library/InputManagers/BibDeskInputManager.  If you experience text input problems or strange application behavior after installing the plugin, try removing the \"BibDeskInputManager\" subfolder.", @"Informative text in alert dialog")];
    [alert beginSheetModalForWindow:[[self view] window]
                      modalDelegate:self
                     didEndSelector:@selector(enableCompletionSheetDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (IBAction)addApplication:(id)sender{
    
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanChooseDirectories:NO];
    [op setAllowsMultipleSelection:NO];
    [op setPrompt:NSLocalizedString(@"Add", @"Prompt for dialog to add an app for plugin")];
    [op beginSheetForDirectory:[[NSFileManager defaultManager] applicationsDirectory]
			  file:nil
			 types:[NSArray arrayWithObject:@"app"]
		modalForWindow:[[self view] window]
		 modalDelegate:self
		didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
		   contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    if(returnCode == NSOKButton){
	
        // check to see if it's a Cocoa application (returns no for BBEdit Lite and MS Word, but yes for Carbon Emacs and Aqua LyX, so it's not foolproof)
        NSString *fileType = nil;
        [[NSWorkspace sharedWorkspace] getInfoForFile:[[sheet filenames] objectAtIndex:0]
                          application:nil
                             type:&fileType];
        if(![fileType isEqualToString:NSApplicationFileType]){
            [sheet orderOut:nil];
            NSAlert *anAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error!",@"Message in alert dialog when an error occurs")
                               defaultButton:nil
                             alternateButton:nil
                             otherButton:nil
                       informativeTextWithFormat:NSLocalizedString(@"%@ is not a Cocoa application.", @"Informative text in alert dialog"), [[sheet filenames] objectAtIndex:0]];
            [anAlert beginSheetModalForWindow:[[self view] window]
                    modalDelegate:nil
                       didEndSelector:nil
                      contextInfo:nil];
            return;
        }
        
        // LaTeX Equation Editor is Cocoa, but doesn't have a CFBundleIdentifier!  Perhaps there are others...
        NSString *bundleID = [[NSBundle bundleWithPath:[[sheet filenames] objectAtIndex:0]] bundleIdentifier];
        if(bundleID == nil){
            [sheet orderOut:nil];
            NSAlert *anAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"No Bundle Identifier!",@"Message in alert dialog when no bundle identifier could be found for application to set for plugin")
                               defaultButton:nil
                             alternateButton:nil
                             otherButton:nil
                       informativeTextWithFormat:NSLocalizedString(@"The selected application does not have a bundle identifier.  Please inform the author of %@.", @"Informative text in alert dialog"), [[sheet filenames] objectAtIndex:0]];
            [anAlert beginSheetModalForWindow:[[self view] window]
                    modalDelegate:nil
                       didEndSelector:nil
                      contextInfo:nil];
            return;
        } else {
            [self addApplicationsWithIdentifiers:[NSArray arrayWithObject:bundleID]];
            [self updateUI];
        }
    } else if(returnCode == NSCancelButton){
	    // do nothing
    }
}

- (IBAction)removeApplication:(id)sender{
    unsigned int selIndex = [arrayController selectionIndex];
    if (NSNotFound != selIndex)
        [arrayController removeObjectAtArrangedObjectIndex:selIndex];
    [self synchronizePreferences];
    [self updateUI];
}

@end
