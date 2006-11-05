//  BDSKPreviewer.m

//  Created by Michael McCracken on Tue Jan 29 2002.
/*
 This software is Copyright (c) 2002,2003,2004,2005,2006
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

#import "BDSKPreviewer.h"
#import "BibPrefController.h"
#import "BDSKTeXTask.h"
#import "BDSKOverlay.h"
#import "BibAppController.h"
#import "BDSKZoomableScrollView.h"
#import "BDSKZoomablePDFView.h"
#import "BDSKPreviewMessageQueue.h"
#import <OmniFoundation/NSThread-OFExtensions.h>
#import "BibDocument.h"
#import "BDSKFontManager.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKPrintableView.h"
#import <OmniFoundation/OFPreference.h>
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKCollapsibleView.h"

static NSString *BDSKPreviewPanelFrameAutosaveName = @"BDSKPreviewPanel";

@implementation BDSKPreviewer

+ (BDSKPreviewer *)sharedPreviewer{
    static BDSKPreviewer *sharedPreviewer = nil;

    if (sharedPreviewer == nil) {
        sharedPreviewer = [[self alloc] init];
    }
    return sharedPreviewer;
}

- (id)init{
    if(self = [super init]){
        texTask = [[BDSKTeXTask alloc] initWithFileName:@"bibpreview"];
        [texTask setDelegate:self];
        
        messageQueue = [[BDSKPreviewMessageQueue alloc] init];
        [messageQueue startBackgroundProcessors:1];
        [messageQueue setSchedulesBasedOnPriority:NO];
                
        // this reflects the currently expected state, not necessarily the actual state
        // it corresponds to the last drawing item added to the mainQueue
        previewState = BDSKUnknownPreviewState;
        
        // otherwise a document's previewer might mess up the window position of the shared previewer
        [self setShouldCascadeWindows:NO];
    }
    return self;
}

- (BOOL)isSharedPreviewer { return [self isEqual:[[self class] sharedPreviewer]]; }

#pragma mark UI setup and display

- (void)awakeFromNib{
    float pdfScaleFactor = 0.0;
    float rtfScaleFactor = 1.0;
    BDSKCollapsibleView *collapsibleView = (BDSKCollapsibleView *)[[progressIndicator superview] superview];
    
    // we use threads, so better let the progressIndicator also use them
    [progressIndicator setUsesThreadedAnimation:YES];
    [collapsibleView setMinSize:[progressIndicator frame].size];
    [collapsibleView setCollapseEdges:BDSKMinYEdgeMask | BDSKMaxXEdgeMask];
	
    if([self isSharedPreviewer]){
        pdfScaleFactor = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewPDFScaleFactorKey];
        rtfScaleFactor = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewRTFScaleFactorKey];
        
        [self setWindowFrameAutosaveName:BDSKPreviewPanelFrameAutosaveName];
        
        // overlay the progressIndicator over the contentView
        [progressOverlay overlayView:[[self window] contentView]];
        
        // register to observe when the preview needs to be updated (handle this here rather than on a per document basis as the preview is currently global for the application)
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillTerminate:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:NSApp];
        
        [OFPreference addObserver:self
                         selector:@selector(handlePreviewNeedsUpdate:)
                    forPreference:[OFPreference preferenceForKey:BDSKBTStyleKey]];
    }
        
    // empty document to avoid problem when zoom is set to auto
    PDFDocument *pdfDoc = [[[PDFDocument alloc] initWithData:[self PDFDataWithString:@"" color:nil]] autorelease];
    [pdfView setDocument:pdfDoc];
    
    // don't reset the scale factor until there's a document loaded, or else we get a huge gray border
    [pdfView setScaleFactor:pdfScaleFactor];
	[(BDSKZoomableScrollView *)[rtfPreviewView enclosingScrollView] setScaleFactor:rtfScaleFactor];
    
    [self displayPreviewsForState:BDSKEmptyPreviewState];
    
    [pdfView retain];
    [[rtfPreviewView enclosingScrollView] retain];
}

- (NSString *)windowNibName
{
    return @"Previewer";
}

- (void)updateRepresentedFilename
{
    NSString *path = nil;
	if([self previewState] == BDSKShowingPreviewState){
        path = ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0) ? [texTask PDFFilePath] : [texTask RTFFilePath];
        if(path == nil)
            path = [texTask logFilePath];
    }
    [[self window] setRepresentedFilename:path ? path : @""];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [self updateRepresentedFilename];
}

- (PDFView *)pdfView;
{
    [self window];
    return pdfView;
}

- (NSTextView *)textView;
{
    [self window];
    return rtfPreviewView;
}

- (BDSKOverlay *)progressOverlay;
{
    [self window];
    return progressOverlay;
}

- (BOOL)isVisible{
    return [[pdfView window] isVisible] || [[rtfPreviewView window] isVisible];
}

#pragma mark Actions

- (IBAction)showWindow:(id)sender{
    OBASSERT([self isSharedPreviewer]);
	[super showWindow:self];
	[progressOverlay orderFront:sender];
	[self handlePreviewNeedsUpdate:nil];
    if(![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUsesTeXKey])
        NSBeginAlertSheet(NSLocalizedString(@"Previewing is Disabled.", @"TeX preview is disabled"),
                          NSLocalizedString(@"Yes", @""),
                          NSLocalizedString(@"No", @""),
                          nil,
                          [self window],
                          self,
                          @selector(shouldShowTeXPreferences:returnCode:contextInfo:),
                          NULL, NULL,
                          NSLocalizedString(@"TeX previewing must be enabled in BibDesk's preferences in order to use this feature.  Would you like to open the preference pane now?", @"") );
}

- (void)shouldShowTeXPreferences:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    if(returnCode == NSAlertDefaultReturn){
        [[BDSKPreferenceController sharedPreferenceController] showPreferencesPanel:nil];
        [[BDSKPreferenceController sharedPreferenceController] setCurrentClientByClassName:@"BibPref_TeX"];
    }else{
		[self hideWindow:nil];
	}
}

- (void)handlePreviewNeedsUpdate:(NSNotification *)notification {
    OBASSERT([self isSharedPreviewer]);
    id document = [[NSDocumentController sharedDocumentController] currentDocument];
    if([document respondsToSelector:@selector(updatePreviews:)])
        [document updatePreviews:nil];
}

// first responder gets this
- (void)printDocument:(id)sender{
    if([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0){
        [pdfView printWithInfo:[NSPrintInfo sharedPrintInfo] autoRotate:NO];
    }else{
        BDSKPrintableView *printableView = [[BDSKPrintableView alloc] initForScreenDisplay:NO];
        [printableView setAttributedString:[rtfPreviewView textStorage]];    
        
        // Construct the print operation and setup Print panel
        NSPrintOperation *op = [NSPrintOperation printOperationWithView:printableView
                                                              printInfo:[NSPrintInfo sharedPrintInfo]];
        [op setShowPanels:YES];
        [op setCanSpawnSeparateThread:YES];
        
        // Run operation, which shows the Print panel if showPanels was YES
        [op runOperationModalForWindow:[self window] delegate:nil didRunSelector:NULL contextInfo:NULL];
    }
}

#pragma mark Drawing methods

- (NSData *)PDFDataWithString:(NSString *)string color:(NSColor *)color{
	NSData *data;
	BDSKPrintableView *printableView = [[BDSKPrintableView alloc] initForScreenDisplay:YES];
	[printableView setFont:[NSFontManager bodyFontForFamily:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKPreviewPaneFontFamilyKey]]];
	[printableView setTextColor:color];
	data = [printableView PDFDataWithString:string];
	[printableView release];
	return data;
}

- (void)displayPreviewsForState:(BDSKPreviewState)state{
    
    NSAssert2([NSThread inMainThread], @"-[%@ %@] must be called from the main thread!", [self class], NSStringFromSelector(_cmd));

	previewState = state;
	
	// if empty, flush the queue as any remaining invocations are not valid anymore
	if (state == BDSKEmptyPreviewState)
		[messageQueue removeAllInvocations];
		
    // start or stop the spinning wheel
    if(state == BDSKWaitingPreviewState)
        [progressIndicator startAnimation:nil];
    else
        [progressIndicator stopAnimation:nil];
	
    // if we're offscreen, no point in doing any extra work; we want to be able to reset offscreen though
    if(![self isVisible] && state != BDSKEmptyPreviewState){
        return;
    }
	
    NSString *message = nil;
    NSData *pdfData = nil;
	NSAttributedString *attrString = nil;
	static NSData *emptyMessagePDFData = nil;
	static NSData *generatingMessagePDFData = nil;
	
	// get the data to display
	if(state == BDSKShowingPreviewState){
        
        NSData *rtfData = nil;
		if([texTask hasRTFData] && (rtfData = [texTask RTFData]) != nil)
			attrString = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:NULL];
		else
			message = NSLocalizedString(@"***** ERROR:  unable to create preview *****", @"");
		
		if([texTask hasPDFData] == NO || (pdfData = [texTask PDFData]) == nil){
			// show the TeX log file in the view
			NSMutableString *errorString = [[NSMutableString alloc] initWithCapacity:200];
			[errorString appendString:NSLocalizedString(@"TeX preview generation failed.  Please review the log below to determine the cause.", @"")];
			[errorString appendString:@"\n\n"];
            NSString *logString = [texTask logFileString];
            if (nil == logString)
                logString = NSLocalizedString(@"Unable to read log file from TeX run.", @"");
			[errorString appendString:logString];
			pdfData = [self PDFDataWithString:errorString color:[NSColor redColor]];
			[errorString release];
		}
        
	}else if(state == BDSKEmptyPreviewState){
		
		message = NSLocalizedString(@"No items are selected.", @"No items are selected.");
		
		if (emptyMessagePDFData == nil)
			emptyMessagePDFData = [[self PDFDataWithString:message color:[NSColor grayColor]] retain];
		pdfData = emptyMessagePDFData;
		
	}else if(state == BDSKWaitingPreviewState){
		
		message = [NSString stringWithFormat:@"%@%C", NSLocalizedString(@"Generating preview", @"Generating preview..."), 0x2026];
		
		if (generatingMessagePDFData == nil)
			generatingMessagePDFData = [[self PDFDataWithString:message color:[NSColor grayColor]] retain];
		pdfData = generatingMessagePDFData;
		
	}
	
	OBPOSTCONDITION(pdfData != nil);
	
	// draw the PDF preview
    PDFDocument *pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
    [pdfView setDocument:pdfDocument];
    [pdfDocument release];
    
    // draw the RTF preview
	[rtfPreviewView setString:@""];
	[rtfPreviewView setTextContainerInset:NSMakeSize(20,20)];  // pad the edges of the text
	if(attrString){
		[[rtfPreviewView textStorage] appendAttributedString:attrString];
		[attrString release];
	} else if (message){
        NSTextStorage *ts = [rtfPreviewView textStorage];
        [[ts mutableString] setString:message];
        [ts addAttribute:NSForegroundColorAttributeName value:[NSColor grayColor] range:NSMakeRange(0, [ts length])];
	}
    
    if([self isSharedPreviewer])
        [self updateRepresentedFilename];
}

#pragma mark TeX Tasks

- (void)updateWithBibTeXString:(NSString *)bibStr{
    
	if([NSString isEmptyString:bibStr]){
		// reset, also removes any waiting tasks from the queue
        [self displayPreviewsForState:BDSKEmptyPreviewState];
		
    } else {
		// this will start the spinning wheel
        [self displayPreviewsForState:BDSKWaitingPreviewState];
		
        // put a new task on the queue
		[messageQueue queueSelector:@selector(runWithBibTeXString:) forObject:texTask withObject:bibStr];
	}	
}

- (BOOL)texTaskShouldStartRunning:(BDSKTeXTask *)texTask{
	// not really necessary, as we would never be called when previews were reset
	return ![self isEmpty];
}

- (void)texTask:(BDSKTeXTask *)aTexTask finishedWithResult:(BOOL)success{
	
    // ignore this task if we finished a task that was running when the previews were reset or have more updates waiting
	if([self isEmpty] == NO && [messageQueue hasInvocations] == NO) {
        // if we didn't have success, the drawing method will show the log file
        [self displayPreviewsForState:BDSKShowingPreviewState];
    }
}

#pragma mark Data accessors

- (NSData *)PDFData{
	if([texTask hasPDFData] && ![self isEmpty] && ![messageQueue hasInvocations] && [self isVisible]){
		return [texTask PDFData];
	}
	return nil;
}

- (NSData *)RTFData{
	if([texTask hasRTFData] && ![self isEmpty] && ![messageQueue hasInvocations] && [self isVisible]){
		return [texTask RTFData];
	}
	return nil;
}

- (NSString *)LaTeXString{
	if([texTask hasLaTeX] && ![self isEmpty] && ![messageQueue hasInvocations] && [self isVisible]){
		return [texTask LaTeXString];
	}
	return nil;
}

- (BOOL)isEmpty{
	return ([self previewState] == BDSKEmptyPreviewState);
}

- (BDSKPreviewState)previewState{
	return previewState;
}

#pragma mark Cleanup

- (void)windowWillClose:(NSNotification *)notification{
	[self displayPreviewsForState:BDSKEmptyPreviewState];
}

- (void)handleApplicationWillTerminate:(NSNotification *)notification{
    OBASSERT([self isSharedPreviewer]);
    
	// save the visibility of the previewer
	[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:[self isWindowVisible] forKey:BDSKShowingPreviewKey];
    // save the scalefactors of the views
    volatile float scaleFactor = ([pdfView autoScales] ? 0.0 : [pdfView scaleFactor]);

	if (scaleFactor != [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewPDFScaleFactorKey])
		[[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:scaleFactor forKey:BDSKPreviewPDFScaleFactorKey];
	scaleFactor = [(BDSKZoomableScrollView*)[rtfPreviewView enclosingScrollView] scaleFactor];
	if (scaleFactor != [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewRTFScaleFactorKey])
		[[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:scaleFactor forKey:BDSKPreviewRTFScaleFactorKey];
    
    // make sure we don't process anything else; the TeX task will take care of its own cleanup
    [messageQueue removeAllInvocations];
    [messageQueue release];
    messageQueue = nil;
    
	// call this here, since we can't guarantee that the task received the NSApplicationWillTerminate before we flushed the queue
    [texTask terminate];
	[texTask release]; // This removes the temporary directory. Doing this here as we are a singleton. 
	texTask = nil;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [OFPreference removeObserver:self forPreference:nil];
    // make sure we don't process anything else; the TeX task will take care of its own cleanup
    [messageQueue removeAllInvocations];
    [messageQueue release];
    [texTask terminate];
	[texTask release];
    [pdfView release];
    [[rtfPreviewView enclosingScrollView] release];
    [super dealloc];
}
@end
