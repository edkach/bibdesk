//
//  BDSKReadMeController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/8/06.
/*
 This software is Copyright (c) 2005-2012
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

#import "BDSKReadMeController.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSGeometry_BDSKExtensions.h"
#include <sys/utsname.h>

#define BDSKReadMeWindowFrameAutosaveName @"BDSKReadMeWindow"

#define DOWNLOAD_URL @"http://bibdesk.sourceforge.net/"

static BDSKReadMeController *sharedReadMeController = nil;
static BDSKRelNotesController *sharedRelNotesController = nil;

@implementation BDSKReadMeController

+ (id)sharedReadMeController {
    if (sharedReadMeController == nil) 
        sharedReadMeController = [[BDSKReadMeController alloc] init];
    return sharedReadMeController;
}

- (NSString *)windowNibName {
    return @"ReadMe";
}

- (void)windowDidLoad {
    [self setWindowFrameAutosaveName:BDSKReadMeWindowFrameAutosaveName];
    [[self window] setTitle:NSLocalizedString(@"ReadMe", "Window title")];
    [textView setString:@""];
    [textView replaceCharactersInRange:[textView selectedRange]
                               withRTF:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ReadMe" ofType:@"rtf"]]];
}

- (IBAction)download:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:DOWNLOAD_URL]];
}

@end

@implementation BDSKRelNotesController

+ (id)sharedRelNotesController {
    if (sharedRelNotesController == nil) 
        sharedRelNotesController = [[BDSKRelNotesController alloc] init];
    return sharedRelNotesController;
}

- (void)windowDidLoad {
    if(self == sharedRelNotesController){
        [[self window] setTitle:NSLocalizedString(@"Release Notes", "Window title")];
        [textView setString:@""];
        [textView replaceCharactersInRange:[textView selectedRange]
                                   withRTF:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RelNotes" ofType:@"rtf"]]];
    } else {
        [[self window] setTitle:NSLocalizedString(@"Latest Release Notes", @"Window title")];
        NSRect rect = [[textView enclosingScrollView] frame];
        rect = BDSKShrinkRect(rect, 61.0, NSMinYEdge);
        [[textView enclosingScrollView] setFrame:rect];
        [downloadButton setHidden:NO];
    }
}

- (void)displayAttributedString:(NSAttributedString *)attrString {
    if (attrString == nil)
        attrString = [[[NSAttributedString alloc] init] autorelease];
    [self window];
    [[textView textStorage] setAttributedString:attrString];
}

@end

@implementation BDSKExceptionViewer

+ (id)sharedViewer {
    static id sharedInstance = nil;
    
    @synchronized(@"BDSKExceptionViewer") {
        
        @try {
            if (sharedInstance == nil) {
                sharedInstance = [[self alloc] init];
                [sharedInstance window];
            }
        }
        @catch(id exception){
            NSLog(@"caught exception %@ in exception viewer", exception);
            sharedInstance = nil;
        }    
    }
    return sharedInstance;
}

static NSString *hostInfoString()
{
    struct utsname name;
    return uname(&name) ? @"Unknown" : [NSString stringWithFormat:@"%s running on %s", name.version, name.machine];
}

- (void)reportError:(id)sender {
    @try {
        NSString *shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        
        // see BibDesk_vers.c in the {intermediate products}/DerivedSources directory, generated by agvtool
        extern const unsigned char BibDeskVersionString[];
        NSString *build = [NSString stringWithUTF8String:(const char *)BibDeskVersionString];
        NSMutableString *body = [NSMutableString stringWithString:NSLocalizedString(@"Please tell us what you were doing at the time this error occurred.", @"Message when error occurs")];
        [body appendString:@"\n\n***** Do not modify below this line *****\n"];
        [body appendFormat:@"\t ***** ERROR LOG ***** \n\nBibDesk version: %@ (%@)\n", shortVersion, version];
        [body appendFormat:@"Build details: %@\nHost: %@\n%@", build, hostInfoString(), [textView string]];
        
        [[NSWorkspace sharedWorkspace] emailTo:@"bibdesk-exceptions@lists.sourceforge.net" subject:[NSString stringWithFormat:@"BibDesk %@ exception reported %@", version, [[NSDate date] description]] body:body attachments:nil];
    }
    @catch(id exception){
        NSLog(@"caught exception %@ in exception viewer", exception);
    }
}

- (void)windowDidLoad {
    @try {
        [[self window] setTitle:NSLocalizedString(@"Error Log", @"Window title")];
        NSRect rect = [[textView enclosingScrollView] frame];
        rect = BDSKShrinkRect(rect, 61.0, NSMinYEdge);
        [[textView enclosingScrollView] setFrame:rect];
        [downloadButton setHidden:NO];
        [downloadButton setTitle:NSLocalizedString(@"Report Error", @"Button title")];
        [downloadButton setAction:@selector(reportError:)];
        [downloadButton setTarget:self];
        [downloadButton sizeToFit];
    }
    @catch(id exception){
        NSLog(@"caught exception %@ in exception viewer", exception);
    }    
}

- (void)displayString:(NSString *)string {
    @try {
        [textView setString:(string ?: @"Nothing to display.")];
        [[textView textStorage] addAttribute:NSFontAttributeName value:[NSFont userFixedPitchFontOfSize:10.0f] range:NSMakeRange(0, [[textView textStorage] length])];
        [self showWindow:nil];
        
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"An Error Occurred", @"Message in alert dialog when an error occurs") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"The following diagnostic information may be useful to the application developer.  Please report this error.", @"Informative text in alert dialog when an error occurs")];
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
    @catch(id exception){
        NSLog(@"caught exception %@ in exception viewer", exception);
    }    
}

@end

