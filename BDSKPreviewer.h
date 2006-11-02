//  BDSKPreviewer.h

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

/*! @header BDSKPreviewer.h
    @discussion Contains class declaration for the Tex task manager and preview window.
*/

#import <Cocoa/Cocoa.h>
#import <OmniFoundation/OFWeakRetainConcreteImplementation.h>

@class BibDocument, BDSKPreviewMessageQueue, PDFView, BDSKZoomablePDFView, BDSKTeXTask, BDSKOverlay;

/*!
    @class BDSKPreviewer
    @abstract TeX task manager and preview window controller
    @discussion ...
*/
@interface BDSKPreviewer : NSWindowController {
	BDSKTeXTask *texTask;
	
    IBOutlet BDSKZoomablePDFView *pdfView;
    IBOutlet NSTextView *rtfPreviewView;
    IBOutlet NSTabView *tabView;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet BDSKOverlay *progressOverlay;
    
    BibDocument *sourceDocument;
    
    BDSKPreviewMessageQueue *messageQueue;
	volatile int previewState;
    
    OFSimpleLockType stateLock;
}

/*!
    @method sharedPreviewer
    @abstract accesses the single object
	@result Pointer to the single BDSKPreviewer instance.
*/
+ (BDSKPreviewer *)sharedPreviewer;

- (id)initWithSourceDocument:(BibDocument *)aDocument;

- (PDFView *)pdfView;
- (NSTextView *)textView;

- (BOOL)isVisible;

- (void)shouldShowTeXPreferences:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)handlePreviewNeedsUpdate:(NSNotification *)notification;

/*!
    @method updateWithBibTeXString:
    @abstract Given a BibTeX string, generates the PDF and RTF data and updates the previews
    @discussion Takes the bibtex string, runs aproprate TeX tasks, and loads the resulting PDF and RTF into their views.
		Pass nil to reset the previews to their default state, showing the nopreview message. 
		This is the main method to be called from outside, and is completely thread safe. 
    @param bibStr The bibtex string source
*/
- (void)updateWithBibTeXString:(NSString *)bibStr;

/*!
    @method     drawPreviewsForState:
    @abstract   This will draw the previews or message in the appropriate views.
    @discussion This method sets the state flag and puts -performDrawingForState: on the main queue for drawing.
	@param		state An integer indicating the preview state for which to draw.
*/
- (void)drawPreviewsForState:(int)state;

/*!
    @method     performDrawingForState:
    @abstract   Draws the previews or a message in their appropriate views and starts or stops the spinner.
    @discussion This should only be called from the main thread. Don't call it directly, use -drawPreviewsForState.
	@param		state An integer indicating the preview state for which to draw.
*/
- (void)performDrawingForState:(int)state;

/*!
    @method     PDFDataWithString:color:
    @abstract   Converts the given string into PDF data, applying the given color to the entire range of the string.  This method is not thread safe.
    @discussion (comprehensive description)
    @param      string (description)
    @param      color (description)
    @result     (description)
*/
- (NSData *)PDFDataWithString:(NSString *)string color:(NSColor *)color;

/*!
    @method     PDFData
    @abstract   Returns the PDF data in the preview if it is valid. Otherwise returns nil.
    @discussion Any data is considered invalid if the previews were reset, our window is not visible, 
		or there are updates waiting. This should be thread safe. 
*/
- (NSData *)PDFData;

/*!
    @method     RTFData
    @abstract   Returns the RTF data in the preview if it is valid. Otherwise returns nil.
    @discussion Any data is considered invalid if the previews were reset, our window is not visible, 
		or there are updates waiting. This should be thread safe. 
*/
- (NSData *)RTFData;

/*!
    @method     LaTeXString
    @abstract   Returns the LaTeX string for the preview if it is valid. Otherwise returns nil.
    @discussion Any data is considered invalid if the previews were reset, our window is not visible, 
		or there are updates waiting. This should be thread safe. 
*/
- (NSString *)LaTeXString;

/*!
    @method     isEmpty
    @abstract   Returns YES if the previews were empty, and should show the default message for an empty selection. 
    @discussion This is mostly a convenience accessor to check if our data is valid. This accessor is thread safe. 
*/
- (BOOL)isEmpty;

/*!
    @method     previewState
    @abstract   Returns an integer indicating the currently expected state of the previews.
    @discussion This accessor is thread safe. 
	@result		An integer indicating the currently expected state. 0 = empty, 1 = waiting, 2 = showing. 
*/
- (int)previewState;

/*!
    @method     changePreviewState:
    @abstract   Sets the current preview state to a new value. Returns a boolean to indicate whether a change was made. 
    @discussion This accessor is thread safe. 
	@param		state The integer indicating the state to set
	@result		A boolean, return NO if the current state was aleady in the requested state.
*/
- (BOOL)changePreviewState:(int)state;

/*!
    @method     handleApplicationWillTerminate:
    @abstract   Perform cleanup actions here, since this object never gets deallocated.
    @discussion (comprehensive description)
    @param      notification (description)
*/
- (void)handleApplicationWillTerminate:(NSNotification *)notification;
@end
