//
//  NSMenu_BDSKExtensions.h
//  Bibdesk
//
//  Created by Adam Maxwell on 07/09/06.
/*
 This software is Copyright (c) 2006
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

// this must be implemented in the responder chain for submenuOfApplicationsForURL:, using the following implementation as reference
/*
 - (void)chooseApplicationToOpenURL:(NSURL *)aURL;
 {
     NSOpenPanel *openPanel = [NSOpenPanel openPanel];
     [openPanel setCanChooseDirectories:NO];
     [openPanel setAllowsMultipleSelection:NO];
     [openPanel setPrompt:NSLocalizedString(@"Choose Viewer", @"")];
     
     int rv = [openPanel runModalForDirectory:[[NSFileManager defaultManager] applicationsDirectory] 
                                         file:nil 
                                        types:[NSArray arrayWithObjects:@"app", nil]];
     if(NSFileHandlingPanelOKButton == rv)
         [[NSWorkspace sharedWorkspace] openURL:aURL withApplicationURL:[[openPanel URLs] firstObject]];
 }
 
 // action for opening a file with a specific application
 - (void)openURLWithApplication:(id)sender{
     NSURL *applicationURL = [[sender representedObject] valueForKey:@"applicationURL"];
     NSURL *targetURL = [[sender representedObject] valueForKey:@"targetURL"];
     
     if(nil == applicationURL)
         [self chooseApplicationToOpenURL:targetURL];
     else if([[NSWorkspace sharedWorkspace] openURL:targetURL withApplicationURL:applicationURL] == NO)
         NSBeep();
 }
*/

@interface NSObject (BDSKMenuExtensions)
- (void)openURLWithApplication:(id)sender;
@end

@interface NSMenu (BDSKExtensions)

+ (NSMenu *)submenuOfApplicationsForURL:(NSURL *)aURL;

@end
