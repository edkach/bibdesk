//  BDSKPreviewer.m

//  Created by Michael McCracken on Tue Jan 29 2002.
/*
This software is Copyright (c) 2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "BDSKPreviewer.h"
#import "BibPrefController.h"
#import "BibAppController.h"
#import "DraggableScrollView.h"


/*! @const BDSKPreviewer helps to enforce a single object of this class */
static BDSKPreviewer *thePreviewer;

static unsigned threadCount = 0;

@implementation BDSKPreviewer

+ (BDSKPreviewer *)sharedPreviewer{
    if (!thePreviewer) {
        thePreviewer = [[BDSKPreviewer alloc] init];
    }
    return thePreviewer;
}

- (id)init{
    applicationSupportPath = [[[[NSFileManager defaultManager] applicationSupportDirectory:kUserDomain] stringByAppendingPathComponent:@"BibDesk"] retain];

    if(self = [super init]){
        bundle = [NSBundle mainBundle];
	usertexTemplatePath = [[applicationSupportPath stringByAppendingPathComponent:@"previewtemplate.tex"] retain];
        texTemplatePath = [[applicationSupportPath stringByAppendingPathComponent:@"bibpreview.tex"] retain];
        finalPDFPath = [[applicationSupportPath stringByAppendingPathComponent:@"bibpreview.pdf"] retain];
	nopreviewPDFPath = [[[bundle resourcePath] stringByAppendingPathComponent:@"nopreview.pdf"] retain];
        tmpBibFilePath = [[applicationSupportPath stringByAppendingPathComponent:@"bibpreview.bib"] retain];
	rtfFilePath = [[applicationSupportPath stringByAppendingPathComponent:@"bibpreview.rtf"] retain];
        binPathDir = [[NSString alloc] init]; // set from where we run the tasks, since some programs (e.g. XeLaTeX) need a real path setting
        countLock = [[NSLock alloc] init];
        workingLock = [[NSLock alloc] init];
    }
    return self;
}

- (void)awakeFromNib{
	DraggableScrollView *scrollView = (DraggableScrollView*)[imagePreviewView enclosingScrollView];
    float scaleFactor = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewPDFScaleFactorKey];
	[scrollView setScaleFactor:scaleFactor];
	scrollView = (DraggableScrollView*)[rtfPreviewView enclosingScrollView];
	scaleFactor = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewRTFScaleFactorKey];
	[scrollView setScaleFactor:scaleFactor];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
					     selector:@selector(appWillTerminate:)
						 name:NSApplicationWillTerminateNotification
					       object:NSApp];
	
	[self setWindowFrameAutosaveName:@"BDSKPreviewPanel"];
}

- (NSString *)windowNibName
{
    return @"Previewer";
}

- (void)windowDidLoad{ // we get this the first time the user selects "Show Preview"
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self performSelectorOnMainThread:@selector(resetPreviews)
                           withObject:nil
                        waitUntilDone:YES];
    [pool release];
}

- (BOOL)PDFFromString:(NSString *)str{
    
    if(str == nil){
	[self resetPreviews];
	return YES;
    }
    // pool for MT
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // get a fresh copy of the file:
    NSString *texFile; 

    NSMutableString *bibTemplate; 
    NSString *prefix = [NSString string];
    NSString *postfix = [NSString string];
    NSString *style;
    NSMutableString *finalTexFile = [NSMutableString string];
    NSScanner *s;
    
    unsigned myThreadCount;

    [countLock lock];
    threadCount++;
    myThreadCount = threadCount;
    [countLock unlock];
    
    while(working){
        if(myThreadCount == threadCount){
            // if someone else is working and i'm the top go to sleep for a bit
            [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.2]];
        }else{
            // if someone else is working and I'm not the top, die.
            [pool release];
            return NO;
        }
    }

    // don't do anything if i'm not the top.
    if(myThreadCount < threadCount){
        [pool release];
        return NO;
    }
    
    [workingLock lock];
    working = YES;
    [workingLock unlock];

    // NSLog(@"**** starting thread %d", myThreadCount);
    
    // Files:  previewtemplate.tex is intended to be changed by the user, and so we allow opening
    // this file from the preview prefpane.  By using previewtemplate.tex as a base instead of the previous
    // bibpreview.tex file, we avoid problems.   Previously if the user was editing the 
    // bibpreview.tex file and we overwrote it by running another preview, the editor would lose the file.
    // Therefore, bibpreview.* are essentially temporary files, only modified by BibDesk.
    texFile = [NSString stringWithContentsOfFile:usertexTemplatePath];
    bibTemplate = [NSMutableString stringWithContentsOfFile:
        [[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath]];
    s = [NSScanner scannerWithString:texFile];

    [imagePreviewView setImage:[NSImage imageNamed:@"typesetting.pdf"]];

    // replace the appropriate style & bib files.
    style = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKBTStyleKey];
    [s scanUpToString:@"bibliographystyle{" intoString:&prefix];
    [s scanUpToString:@"}" intoString:nil];
    [s scanUpToString:@"\bye" intoString:&postfix];
    [finalTexFile appendFormat:@"%@bibliographystyle{%@%@", prefix, style, postfix];
    // overwrites the old bibpreview.tex file, replacing the previous bibliographystyle
    if(![[finalTexFile dataUsingEncoding:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKDefaultStringEncoding]] writeToFile:texTemplatePath atomically:YES]){
        NSLog(@"error replacing texfile");
        [workingLock lock];
        working = NO;
        [workingLock unlock];
        [pool release];
        return NO;
    }

    // write out the bib file with the template attached:
    [bibTemplate appendFormat:@"\n%@",str];
    if(![[bibTemplate dataUsingEncoding:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKDefaultStringEncoding]] writeToFile:tmpBibFilePath atomically:YES]){
        NSLog(@"Error replacing bibfile.");
        [workingLock lock];
        working = NO;
        [workingLock unlock];        
        [pool release];
        return NO;
    }
    
    NS_DURING
    if([self previewTexTasks:@"bibpreview.tex"]){ // run the TeX tasks

        if (myThreadCount >= threadCount){
            [self performSelectorOnMainThread:@selector(performDrawing)
                                                         withObject:nil
                                                  waitUntilDone:YES];
        }
        
    } else {
        NSLog(@"Task failure in -[%@ %@]", [self class], NSStringFromSelector(_cmd));
    }
    NS_HANDLER
        if([[localException name] isEqualToString:@"BDSKPreviewerPathNotFound"]){ // clean up and return
            NSLog(@"Task failure in -[%@ %@], executable(s) not found", [self class], NSStringFromSelector(_cmd));
            [pool release];
            [workingLock lock];
            working = NO;
            [workingLock unlock];
            return NO;
        } else {
            [localException raise]; // re-raise, it's not ours
        }
    NS_ENDHANDLER
    // Pool for MT
    [pool release];
    
    [workingLock lock];
    working = NO;
    [workingLock unlock];
    
    return YES;    
    
}

- (void)printDocument:(id)sender{ // first responder gets this
    NSView *printView = ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ? (NSView *)imagePreviewView : (NSView *)rtfPreviewView);
    
    // Construct the print operation and setup Print panel
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:printView
                                                          printInfo:[NSPrintInfo sharedPrintInfo]];
    [op setShowPanels:YES];
    [op setCanSpawnSeparateThread:YES];
    
    // Run operation, which shows the Print panel if showPanels was YES
    [op runOperationModalForWindow:[self window] delegate:nil didRunSelector:NULL contextInfo:NULL];
    
}

- (void)performDrawing{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if([tabView lockFocusIfCanDraw]){
        [imagePreviewView loadFromPath:finalPDFPath];
        [tabView unlockFocus];
        [self rtfPreviewFromData:[self rtfDataPreview]]; // does its own locking of the view
    }
    [pool release];
}	

- (BOOL)previewTexTasks:(NSString *)fileName{ // we set working dir in NSTask
        
    NSTask *pdftex1;
    NSTask *pdftex2;
    NSTask *bibtex;
    NSString *pdftexbinpath = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKTeXBinPathKey];
    NSString *bibtexbinpath = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKBibTeXBinPathKey];
    NSTask *latex2rtf;
    NSString *latex2rtfpath = [NSString stringWithFormat:@"%@/latex2rtf",[[NSBundle mainBundle] resourcePath]];
    
    if(![[pdftexbinpath stringByDeletingLastPathComponent] isEqualToString:binPathDir]){
        [binPathDir release];
        binPathDir = [[pdftexbinpath stringByDeletingLastPathComponent] retain];
        NSString *original_path = [NSString stringWithCString: getenv("PATH")];
        NSString *new_path = [NSString stringWithFormat: @"%@:%@", original_path, binPathDir];
        setenv("PATH", [new_path cString], 1);
    }
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:pdftexbinpath]){
        [NSException raise:@"BDSKPreviewerPathNotFound" format:@"File does not exist at %@", pdftexbinpath];    
    }
    if(![[NSFileManager defaultManager] fileExistsAtPath:bibtexbinpath]){        
        [NSException raise:@"BDSKPreviewerPathNotFound" format:@"File does not exist at %@", bibtexbinpath];     
    }

    // remove the old pdf file.
    [[NSFileManager defaultManager] removeFileAtPath:[applicationSupportPath stringByAppendingPathComponent:@"bibpreview.pdf"]
                                             handler:nil];
    
    // Now start the tex task fun.

    pdftex1 = [[NSTask alloc] init];
    [pdftex1 setCurrentDirectoryPath:applicationSupportPath];
    [pdftex1 setLaunchPath:pdftexbinpath];
    [pdftex1 setArguments:[NSArray arrayWithObjects:@"-interaction=batchmode", [NSString stringWithString:fileName],
        nil ]];
    [pdftex1 setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

    NS_DURING
        [pdftex1 launch];
        [pdftex1 waitUntilExit];
    NS_HANDLER
        if([pdftex1 isRunning])
            [pdftex1 terminate];
        NSLog(@"%@ %@ failed", [pdftex1 description], [pdftex1 launchPath]);
        [pdftex1 release];
        return NO;
    NS_ENDHANDLER
    
    [pdftex1 release];

    bibtex = [[NSTask alloc] init];
    [bibtex setCurrentDirectoryPath:applicationSupportPath];
    [bibtex setLaunchPath:bibtexbinpath];
    [bibtex setArguments:[NSArray arrayWithObjects:[fileName stringByDeletingPathExtension],nil ]];
    [bibtex setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

    NS_DURING
        [bibtex launch];
        [bibtex waitUntilExit];
    NS_HANDLER
        if([bibtex isRunning])
            [bibtex terminate];
        NSLog(@"%@ %@ failed", [bibtex description], [bibtex launchPath]);
        [bibtex release];
        return NO;
    NS_ENDHANDLER
    
    [bibtex release];

    pdftex2 = [[NSTask alloc] init];
    [pdftex2 setCurrentDirectoryPath:applicationSupportPath];
    [pdftex2 setLaunchPath:pdftexbinpath];
    [pdftex2 setArguments:[NSArray arrayWithObjects:@"-interaction=batchmode",[NSString stringWithString:fileName],
        nil ]];
    [pdftex2 setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    
    NS_DURING
        [pdftex2 launch];
        [pdftex2 waitUntilExit];
    NS_HANDLER
        if([pdftex2 isRunning])
            [pdftex2 terminate];
        NSLog(@"%@ %@ failed", [pdftex2 description], [pdftex2 launchPath]);
        [pdftex2 release];
        return NO;
    NS_ENDHANDLER
    
    [pdftex2 release];

    // This task runs latex2rtf on our tex file to generate bibpreview.rtf
    latex2rtf = [[NSTask alloc] init];
    [latex2rtf setCurrentDirectoryPath:applicationSupportPath];
    [latex2rtf setLaunchPath:latex2rtfpath];  // full path to the binary
    // the arguments: it needs -P "path" which is the path to the cfg files in the app wrapper
    [latex2rtf setArguments:[NSArray arrayWithObjects:[NSString stringWithString:@"-P"],
	                   [[NSBundle mainBundle] resourcePath],
	                   [NSString stringWithString:fileName],nil ]];
    [latex2rtf setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    [latex2rtf setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    
    NS_DURING
        [latex2rtf launch];
        [latex2rtf waitUntilExit];
    NS_HANDLER
        if([latex2rtf isRunning])
            [latex2rtf terminate];
        NSLog(@"%@ %@ failed", [latex2rtf description], [latex2rtf launchPath]);
        [latex2rtf release];
        return NO;
    NS_ENDHANDLER

    [latex2rtf release];

    return YES;

}

- (NSData *)PDFDataFromString:(NSString *)str{
    if([self PDFFromString:str])
        return [NSData dataWithContentsOfFile:finalPDFPath];
    else
        return nil;
}

- (NSAttributedString *)rtfStringPreview:(NSString *)filePath{      // RTF Preview support
    rtfString = [[[NSAttributedString alloc] initWithPath:filePath documentAttributes:nil] autorelease];
    return rtfString;
}

- (NSData *)rtfDataPreview{   // Returns the RTF as NSData, used for pasteboard ops
    NSData *d = [NSData dataWithContentsOfFile:rtfFilePath];
    return d;
}


// accessor
- (NSImageView*) pdfView { 
	return imagePreviewView;
}


- (BOOL)rtfPreviewFromData:(NSData *)rtfdata{  // This draws the RTF in a textview
    NSSize inset = NSMakeSize(20,20); // set this for the margin
    
    if([tabView lockFocusIfCanDraw]){
	[rtfPreviewView setString:@""];   // clean the view
	[rtfPreviewView setTextContainerInset:inset];  // pad the edges of the text
	[tabView unlockFocus];
    }

    // we get a zero-length string if a bad bibstyle is used, so check for it
    if([rtfdata length] > 0 && [tabView lockFocusIfCanDraw]){
        [rtfPreviewView replaceCharactersInRange:[rtfPreviewView selectedRange]
                                         withRTF:rtfdata];
        [tabView unlockFocus];
        return YES;
    } else {
        NSString *errstr = [NSString stringWithString:@"***** ERROR:  unable to create preview *****"];
        if([tabView lockFocusIfCanDraw]){
            [rtfPreviewView replaceCharactersInRange: [rtfPreviewView selectedRange]
                          withString:errstr];
            [tabView unlockFocus];
        }
    	return NO;
    }
	
}

- (void)windowWillClose:(NSNotification *)notification{
	[self resetPreviews];
}

- (void)appWillTerminate:(NSNotification *)notification{
	// save the scalefactors of the views
    float scaleFactor = [(DraggableScrollView*)[imagePreviewView enclosingScrollView] scaleFactor];
	if (scaleFactor != [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewPDFScaleFactorKey])
		[[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:scaleFactor forKey:BDSKPreviewPDFScaleFactorKey];
	scaleFactor = [(DraggableScrollView*)[rtfPreviewView enclosingScrollView] scaleFactor];
	if (scaleFactor != [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewRTFScaleFactorKey])
		[[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:scaleFactor forKey:BDSKPreviewRTFScaleFactorKey];
}

- (void)resetPreviews{
    if([tabView lockFocusIfCanDraw]){
        [imagePreviewView loadFromPath:nopreviewPDFPath];
        [tabView unlockFocus];
    }
    if([tabView lockFocusIfCanDraw]){
        [rtfPreviewView setString:@""];
        [rtfPreviewView setTextContainerInset:NSMakeSize(20, 20)];
        [rtfPreviewView replaceCharactersInRange:[rtfPreviewView selectedRange]
                                      withString:NSLocalizedString(@"Please select an item or items from the bibliography list for LaTeX to preview.",@"")];
        [tabView unlockFocus];
    }
}


- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [usertexTemplatePath release];
    [texTemplatePath release];
    [finalPDFPath release];
    [nopreviewPDFPath release];
    [tmpBibFilePath release];
    [rtfFilePath release];
    [applicationSupportPath release];
    [binPathDir release];
    [countLock release];
    [workingLock release];
    [super dealloc];
}
@end
