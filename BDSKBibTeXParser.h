//
//  BDSKBibTeXParser.h
//  BibDesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
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

#import <Cocoa/Cocoa.h>

@class BDSKMacroResolver, BibItem;

@protocol BDSKOwner;

@interface BDSKBibTeXParser : NSObject {
}

+ (BOOL)canParseString:(NSString *)string;
+ (BOOL)canParseStringAfterFixingKeys:(NSString *)string;

/*!
    @method     itemsFromString:error:owner:encoding:error:
    @abstract   Convenience method that returns an array of BibItems from the input string; used by the pasteboard.  Uses libbtparse to parse the data.
    @discussion (comprehensive description)
    @param      aString (description)
    @param      anOwner (description)
    @param      outError (description)
    @result     (description)
*/
+ (NSArray *)itemsFromString:(NSString *)aString owner:(id<BDSKOwner>)anOwner isPartialData:(BOOL *)isPartialData error:(NSError **)outError;

+ (NSArray *)itemsFromData:(NSData *)inData
                    macros:(NSDictionary **)outMacros
                  filePath:(NSString *)filePath
                     owner:(id<BDSKOwner>)anOwner
                  encoding:(NSStringEncoding)parserEncoding
             isPartialData:(BOOL *)isPartialData
                     error:(NSError **)outError;

/*!
    @method     itemsFromData:macros:documentInfo:groups:frontMatter:filePath:owner:encoding:error:
    @abstract   Parsing method that returns an array of BibItems from data, using libbtparse; needs a document to act as macro resolver.
    @discussion (comprehensive description)
    @param      inData (description)
    @param      outMacros (description)
    @param      outDocumentInfo (description)
    @param      outGroups (description)
    @param      outFrontMatter (description)
    @param      filePath (description)
    @param      anOwner (description)
    @param      parserEncoding (description)
    @param      isPartialData Returns by reference an indication of whether problems occurred
    @param      outError May be NULL.  If non-NULL and the item has partial data, will be filled.
    @result     (description)
*/
+ (NSArray *)itemsFromData:(NSData *)inData
                    macros:(NSDictionary **)outMacros
              documentInfo:(NSDictionary **)outDocumentInfo
                    groups:(NSDictionary **)outGroups
               frontMatter:(NSString **)outFrontMatter
                  filePath:(NSString *)filePath
                     owner:(id<BDSKOwner>)anOwner
                  encoding:(NSStringEncoding)parserEncoding
             isPartialData:(BOOL *)isPartialData
                     error:(NSError **)outError;

/*!
    @method     macrosFromBibTeXString:document:
    @abstract   Returns a dictionary of macro definitions from a BibTeX file (.bib extension).
    @discussion The definitions take the form <tt>@STRING {ibmjrd = "IBM Journal of Research and Development"}</tt>
                The returned macros can contain circular macro definitions.
    @param      styleContents The contents of the bib file as a string
    @param      macroResolver (description)
    @result     Returns nil if nothing was found or an error occurred.
*/
+ (NSDictionary *)macrosFromBibTeXString:(NSString *)stringContents macroResolver:(BDSKMacroResolver *)macroResolver;

/*!
    @method     macrosFromBibTeXStyle:document:
    @abstract   Returns a dictionary of macro definitions from a BibTeX style file (.bst extension).
    @discussion The definitions take the form <tt>MACRO {ibmjrd} {"IBM Journal of Research and Development"}</tt>
                The returned macros can contain circular macro definitions.
    @param      styleContents The contents of the bst file as a string
    @param      macroResolver (description)
    @result     Returns nil if nothing was found or an error occurred.
*/
+ (NSDictionary *)macrosFromBibTeXStyle:(NSString *)styleContents macroResolver:(BDSKMacroResolver *)macroResolver;
    
/*!
    @method     authorsFromBibtexString:withPublication:forField
    @abstract   Parses a BibTeX author string (separates components joined by the string "and")
    @discussion (comprehensive description)
    @param      aString The author string
    @result     An array of BibAuthor objects.
*/
+ (NSArray *)authorsFromBibtexString:(NSString *)aString withPublication:(BibItem *)pub forField:(NSString *)field;

+ (NSDictionary *)nameComponents:(NSString *)aName forPublication:(BibItem *)pub;

@end
