//
//  PubMedParser.m
//  BibDesk
//
//  Created by Michael McCracken on Sun Nov 16 2003.
/*
 This software is Copyright (c) 2003,2004,2005,2006
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

#import "PubMedParser.h"
#import "html2tex.h"
#import "BibTypeManager.h"
#import "BibItem.h"
#import "BibAppController.h"
#import "AGRegex/AGRegex.h"

@interface PubMedParser (Private)

/*!
@function	addStringToDict
 @abstract   Used to add additional strings to an existing dictionary entry.
 @discussion This is useful for multiple authors and multiple keywords, so we don't wipe them out by overwriting.
 @param      wholeValue String object that we are adding (e.g. <tt>Ann Author</tt>).
 @param	pubDict NSMutableDictionary containing the current publication.
 @param	theKey NSString object with the key that we are adding an item to (e.g. <tt>Author</tt>).
 */
static void addStringToDict(NSMutableString *wholeValue, NSMutableDictionary *pubDict, NSString *theKey);
/*!
@function   chooseAuthors
 @abstract   PubMed has full author tags (FAU) which duplicate the AU. If available, we use those 
 for the Author field as it contains more information, otherwise we take AU. 
 @param      dict NSMutableDictionary containing a single RIS bibliography entry
 */
static void chooseAuthors(NSMutableDictionary *dict);

// creates a new BibItem from the dictionary
// caller is responsible for releasing the returned item
static BibItem *createBibItemWithPubMedDictionary(NSMutableDictionary *pubDict);
@end

@implementation PubMedParser

+ (NSMutableArray *)itemsFromString:(NSString *)itemString
                              error:(NSError **)outError{
    return [PubMedParser itemsFromString:itemString error:outError frontMatter:nil filePath:BDSKParserPasteDragString];
}

+ (NSMutableArray *)itemsFromString:(NSString *)itemString
                              error:(NSError **)outError
                        frontMatter:(NSMutableString *)frontMatter
                           filePath:(NSString *)filePath{
    
    // get rid of any leading whitespace or newlines, so our range checks at the beginning are more reliable
    // don't trim trailing whitespace/newlines, since that breaks parsing PubMed (possibly the RIS end tag regex?)
    itemString = [itemString stringByTrimmingPrefixCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // make sure that we only have one type of space and line break to deal with, since HTML copy/paste can have odd whitespace characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
    
    // the only problem here is the stuff that Ref Miner prepends to the PMID; other than that, it's just PubMed output
    if([itemString rangeOfString:@"PubMed,RM" options:0 range:NSMakeRange(0, 9)].location != NSNotFound)
        itemString = [itemString stringByFixingRefMinerPubMedTags];
    
    itemString = [itemString stringByAddingRISEndTagsToPubMedString];
        
    BibItem *newBI = nil;
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:10];
    
    //dictionary is the publication entry
    NSMutableDictionary *pubDict = [[NSMutableDictionary alloc] init];
    
    NSArray *sourceLines = [itemString sourceLinesBySplittingString];
    
    NSEnumerator *sourceLineE = [sourceLines objectEnumerator];
    NSString *sourceLine = nil;
    
    NSString *tag = nil;
    NSString *value = nil;
    NSMutableString *mutableValue = [NSMutableString string];
    BibTypeManager *typeManager = [BibTypeManager sharedManager];
    NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    NSSet *tagsNotToConvert = [NSSet setWithObjects:@"UR", @"L1", @"L2", @"L3", @"L4", nil];
    
    // This is used for stripping extraneous characters from BibTeX year fields
    AGRegex *findYearString = [AGRegex regexWithPattern:@"(.*)(\\d{4})(.*)"];
    
    while(sourceLine = [sourceLineE nextObject]){

        if(([sourceLine length] > 5 && [[sourceLine substringWithRange:NSMakeRange(4,2)] isEqualToString:@"- "]) ||
           [sourceLine isEqualToString:@"ER  -"]){
			// this is a "key - value" line
			
			// first save the last key/value pair if necessary
			if(tag && ![tag isEqualToString:@"ER"]){
				addStringToDict(mutableValue, pubDict, tag);
			}
			
			// get the tag...
            tag = [[sourceLine substringWithRange:NSMakeRange(0,4)] 
						stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
			
			if([tag isEqualToString:@"ER"]){
				// we are done with this publication
				
				if([[pubDict allKeys] count] > 0){
					newBI = createBibItemWithPubMedDictionary(pubDict);
					[returnArray addObject:newBI];
					[newBI release];
				}
				
				// reset these for the next pub
				[pubDict removeAllObjects];
				
				// we don't care about the rest, ER has no value
				continue;
			}
			
			// get the value...
			value = [[sourceLine substringWithRange:NSMakeRange(6,[sourceLine length]-6)]
						stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
			
			// don't convert specials in URL/link fields, bug #1244625
			if(![tagsNotToConvert containsObject:tag])
				value = [value stringByConvertingHTMLToTeX];
		
			// Scopus returns a PY with //// after it.  Others may return a full date, where BibTeX wants a year.  
			// Use a regex to find a substring with four consecutive digits and use that instead.  Not sure how robust this is.
			if([[typeManager fieldNameForPubMedTag:tag] isEqualToString:BDSKYearString])
				value = [findYearString replaceWithString:@"$2" inString:value];
			
			[mutableValue setString:value];                
			
		} else {
			// this is a continuation of a multiline value
			[mutableValue appendString:@" "];
			[mutableValue appendString:[sourceLine stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet]];
        }
        
    }
    
    if(outError) *outError = nil;
    
    [pubDict release];
    return returnArray;
}

@end

@implementation PubMedParser (Private)

static void addStringToDict(NSMutableString *value, NSMutableDictionary *pubDict, NSString *tag){
	NSString *key = nil;
	NSString *oldString = nil;
    NSString *newString = nil;
	
	// we handle fieldnames for authors later, as FAU can duplicate AU. All others are treated as AU. 
	if([tag isEqualToString:@"A1"] || [tag isEqualToString:@"A2"] || [tag isEqualToString:@"A3"])
		tag = @"AU";
    // PubMed uses IP for issue number and IS for ISBN
    if([tag isEqualToString:@"IP"])
        key = BDSKNumberString;
    else if([tag isEqualToString:@"IS"])
        key = @"Issn";
	else
        key = [[BibTypeManager sharedManager] fieldNameForPubMedTag:tag];
    if(key == nil || [key isEqualToString:BDSKAuthorString]) key = [tag capitalizedString];
	oldString = [pubDict objectForKey:key];
	
	BOOL isAuthor = ([key isEqualToString:@"Fau"] ||
					 [key isEqualToString:@"Au"] ||
					 [key isEqualToString:BDSKEditorString]);
    
    // sometimes we have authors as "Feelgood, D.R.", but BibTeX and btparse need "Feelgood, D. R." for parsing
    // this leads to some unnecessary trailing space, though, in some cases (e.g. "Feelgood, D. R. ") so we can
    // either ignore it, be clever and not add it after the last ".", or add it everywhere and collapse it later
    if(isAuthor){
		[value replaceOccurrencesOfString:@"." withString:@". " 
			options:NSLiteralSearch range:NSMakeRange(0, [value length])];
        // see bug #1584054, PubMed now doesn't use a comma between the lastName and the firstName
        // this should be OK for valid RIS, as that should be in the format "last, first"
        int firstSpace = [value rangeOfString:@" "].location;
        if([value rangeOfString:@","].location == NSNotFound && firstSpace != NSNotFound)
            [value insertString:@"," atIndex:firstSpace];
    }
	// concatenate authors and keywords, as they can appear multiple times
	// other duplicates keys should have at least different tags, so we use the tag instead
	if(![NSString isEmptyString:oldString]){
		if(isAuthor){
            newString = [[NSString alloc] initWithFormat:@"%@ and %@", oldString, value];
            // This next step isn't strictly necessary for splitting the names, since the name parsing will do it for us, but you still see duplicate whitespace when editing the author field
            NSString *collapsedWhitespaceString = (NSString *)BDStringCreateByCollapsingAndTrimmingWhitespace(NULL, (CFStringRef)newString);
            [newString release];
            newString = collapsedWhitespaceString;
        }else if([key isEqualToString:BDSKKeywordsString]){
            newString = [[NSString alloc] initWithFormat:@"%@, %@", oldString, value];
		}else{
			// we already had a tag mapping to the same fieldname, so use the tag instead
			key = [tag capitalizedString];
            oldString = [pubDict objectForKey:key];
            if (![NSString isEmptyString:oldString]){
                newString = [[NSString alloc] initWithFormat:@"%@, %@", oldString, value];
            }else{
                newString = [value copy];
            }
		}
    }else{
        // the default, just set the value
        newString = [value copy];
    }
    if(newString != nil){
        [pubDict setObject:newString forKey:key];
        [newString release];
    }
}

static void chooseAuthors(NSMutableDictionary *dict){
    NSString *authors;
    
    if(authors = [dict objectForKey:@"Fau"]){
        [dict setObject:authors forKey:BDSKAuthorString];
		[dict removeObjectForKey:@"Fau"];
		// should we remove the AU also?
    }else if(authors = [dict objectForKey:@"Au"]){
        [dict setObject:authors forKey:BDSKAuthorString];
		[dict removeObjectForKey:@"Au"];
	}
}

static BibItem *createBibItemWithPubMedDictionary(NSMutableDictionary *pubDict)
{
    
    BibTypeManager *typeManager = [BibTypeManager sharedManager];
    BibItem *newBI = nil;
    NSString *type = BDSKArticleString;
    
	// choose the authors from the FAU or AU tag as available
    chooseAuthors(pubDict);
	
    // set the pub type if we know the bibtex equivalent, otherwise leave it as misc
    if([typeManager bibtexTypeForPubMedType:[pubDict objectForKey:@"Pt"]] != nil)
		type = [typeManager bibtexTypeForPubMedType:[pubDict objectForKey:@"Pt"]];
    
    newBI = [[BibItem alloc] initWithType:type
								 fileType:BDSKBibtexString
								  citeKey:nil
								pubFields:pubDict
                                    isNew:YES];
    
    return newBI;
}

@end

@implementation NSString (PubMedExtensions)

- (NSString *)stringByConvertingHTMLToTeX;
{
    static NSCharacterSet *asciiSet = nil;
    if(asciiSet == nil)
        asciiSet = [[NSCharacterSet characterSetWithRange:NSMakeRange(0, 127)] retain];
    
    // set these up here, so we don't autorelease them every time we parse an entry
    // Some entries from Compendex have spaces in the tags, which is why we match 0-1 spaces between each character.
    static AGRegex *findSubscriptLeadingTag = nil;
    if(findSubscriptLeadingTag == nil)
        findSubscriptLeadingTag = [[AGRegex alloc] initWithPattern:@"< ?s ?u ?b ?>"];
    static AGRegex *findSubscriptOrSuperscriptTrailingTag = nil;
    if(findSubscriptOrSuperscriptTrailingTag == nil)
        findSubscriptOrSuperscriptTrailingTag = [[AGRegex alloc] initWithPattern:@"< ?/ ?s ?u ?[bp] ?>"];
    static AGRegex *findSuperscriptLeadingTag = nil;
    if(findSuperscriptLeadingTag == nil)
        findSuperscriptLeadingTag = [[AGRegex alloc] initWithPattern:@"< ?s ?u ?p ?>"];
    
    // This one might require some explanation.  An entry with TI of "Flapping flight as a bifurcation in Re<sub>&omega;</sub>"
    // was run through the html conversion to give "...Re<sub>$\omega$</sub>", then the find sub/super regex replaced the sub tags to give
    // "...Re$_$omega$$", which LaTeX barfed on.  So, we now search for <sub></sub> tags with matching dollar signs inside, and remove the inner
    // dollar signs, since we'll use the dollar signs from our subsequent regex search and replace; however, we have to
    // reject the case where there is a <sub><\sub> by matching [^<]+ (at least one character which is not <), or else it goes to the next </sub> tag
    // and deletes dollar signs that it shouldn't touch.  Yuck.
    static AGRegex *findNestedDollar = nil;
    if(findNestedDollar == nil)
        findNestedDollar = [[AGRegex alloc] initWithPattern:@"(< ?s ?u ?[bp] ?>[^<]+)(\\$)(.*)(\\$)(.*< ?/ ?s ?u ?[bp] ?>)"];
    
    // Run the value string through the HTML2LaTeX conversion, to clean up &theta; and friends.
    // NB: do this before the regex find/replace on <sub> and <sup> tags, or else your LaTeX math
    // stuff will get munged.  Unfortunately, the C code for HTML2LaTeX will destroy accented characters, so we only send it ASCII, and just keep
    // the accented characters to let BDSKConverter deal with them later.
    
    NSScanner *scanner = [[NSScanner alloc] initWithString:self];
    NSString *asciiAndHTMLChars, *nonAsciiAndHTMLChars;
    NSMutableString *fullString = [[NSMutableString alloc] initWithCapacity:[self length]];
    
    while(![scanner isAtEnd]){
        if([scanner scanCharactersFromSet:asciiSet intoString:&asciiAndHTMLChars])
            [fullString appendString:[NSString TeXStringWithHTMLString:asciiAndHTMLChars]];
		if([scanner scanUpToCharactersFromSet:asciiSet intoString:&nonAsciiAndHTMLChars])
			[fullString appendString:nonAsciiAndHTMLChars];
    }
    [scanner release];
    
    NSString *newValue = [[fullString copy] autorelease];
    [fullString release];
    
    // see if we have nested math modes and try to fix them; see note earlier on findNestedDollar
    if([findNestedDollar findInString:newValue] != nil){
        NSLog(@"WARNING: found nested math mode; trying to repair...");
        newValue = [findNestedDollar replaceWithString:@"$1$3$5"
                                              inString:newValue];
    }
    
    // Do a regex find and replace to put LaTeX subscripts and superscripts in place of the HTML
    // that Compendex (and possibly others) give us.
    newValue = [findSubscriptLeadingTag replaceWithString:@"\\$_{" inString:newValue];
    newValue = [findSuperscriptLeadingTag replaceWithString:@"\\$^{" inString:newValue];
    newValue = [findSubscriptOrSuperscriptTrailingTag replaceWithString:@"}\\$" inString:newValue];
    
    return newValue;
}

- (NSString *)stringByFixingRefMinerPubMedTags;
{    
    // Reference Miner puts its own goo at the front of each entry, so we remove it.  From looking at
    // the input string in gdb, we're getting something like "PubMed,RM122,PMID- 15639629," as the first line.
    AGRegex *startTags = [AGRegex regexWithPattern:@"^PubMed,RM[0-9]{3}," options:AGRegexMultiline];
    return [startTags replaceWithString:@"" inString:self];
}

- (NSArray *)sourceLinesBySplittingString;
{
    // ARM:  This code came from Art Isbell to cocoa-dev on Tue Jul 10 22:13:11 2001.  Comments are his.
    //       We were using componentsSeparatedByString:@"\r", but this is not robust.  Files from ScienceDirect
    //       have \n as newlines, so this code handles those cases as well as PubMed.
    unsigned stringLength = [self length];
    unsigned startIndex;
    unsigned lineEndIndex = 0;
    unsigned contentsEndIndex;
    NSRange range;
    NSMutableArray *sourceLines = [NSMutableArray array];
    
    // There is more than one way to terminate this loop.  Beware of an
    // invalid termination test which might exist in this untested example :-)
    while (lineEndIndex < stringLength)
    {
        // Include only a single character in range.  Not sure whether
        // this will work with empty lines, but if not, try a length of 0.
        range = NSMakeRange(lineEndIndex, 1);
        [self getLineStart:&startIndex 
                          end:&lineEndIndex 
                  contentsEnd:&contentsEndIndex 
                     forRange:range];
        
        // If you want to exclude line terminators...
        [sourceLines addObject:[self substringWithRange:NSMakeRange(startIndex, contentsEndIndex - startIndex)]];
    }
    return sourceLines;
}
    
+ (NSString *)TeXStringWithHTMLString:(NSString *)htmlString;
{
    const char *str = [htmlString UTF8String];
    int ln = strlen(str);
    FILE *freport = stdout;
    char *html_fn = NULL;
    BOOL in_math = NO;
    BOOL in_verb = NO;
    BOOL in_alltt = NO;
    
// ARM:  this code was taken directly from HTML2LaTeX.  I modified it to return
// an NSString object, since working with FILE* streams led to really nasty problems
// with NSPipe needing asynchronous reads to avoid blocking.
// The NSMutableString appendFormat method was used to replace all of the calls to
// fputc, fprintf, and fputs.
// The following copyright notice was taken verbatim from the HTML2LaTeX code:
    
/* HTML2LaTeX -- Converting HTML files to LaTeX
Copyright (C) 1995-2003 Frans Faase

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

GNU General Public License:
http://home.planet.nl/~faase009/GNU.txt
*/
     

    NSMutableString *mString = [NSMutableString stringWithCapacity:ln];
    
    BOOL option_warn = YES;
    
	for(; *str; str++)
	{   BOOL special = NO;
		int v = 0;
		char ch = '\0';
		char html_ch[10];
		html_ch[0] = '\0';

            if (*str == '&')
            {   int i = 0;
                BOOL correct = NO;
                
                if (isalpha(str[1]))
                {   for (i = 0; i < 9; i++)
					if (isalpha(str[i+1]))
						html_ch[i] = str[i+1];
					else
						break;
                    html_ch[i] = '\0';
                    for (v = 0; v < NR_CH_TABLE; v++)
                        if (   ch_table[v].html_ch != NULL
                               && !strcmp(html_ch, ch_table[v].html_ch))
                        {   special = YES;
                            correct = YES;
                            ch = ch_table[v].ch;
                            break;
                        }
                }
                    else if (str[1] == '#')
                    {   int code = 0;
                        html_ch[0] = '#';
                        for (i = 1; i < 9; i++)
                            if (isdigit(str[i+1]))
                            {   html_ch[i] = str[i+1];
                                code = code * 10 + str[i+1] - '0';
                            }
                                else
                                    break;
                        if ((code >= ' ' && code < 127) || code == 8)
                        {   correct = YES;
                            ch = code;
                        }
                        else if (code >= 160 && code <= 255)
                        {
                            correct = YES;
                            special = YES;
                            v = code - 160;
                            ch = ch_table[v].ch;
                        }
                    }
                    html_ch[i] = '\0';
                    
                    if (correct)
                    {   str += i;
                        if (str[1] == ';')
                            str++;
                    }
                    else 
                    {   if (freport != NULL && option_warn)
                        if (html_ch[0] == '\0')
                            fprintf(freport,
                                    "%s (%d) : Replace `&' by `&amp;'.\n",
                                    html_fn, ln);
                        else
                            fprintf(freport,
                                    "%s (%d) : Unknown sequence `&%s;'.\n",
                                    html_fn, ln, html_ch);
                        ch = *str;
                    }
            }
                else if (((unsigned char)*str >= ' ' && (unsigned char)*str <= HIGHASCII) || *str == '\t')
                    ch = *str;
                else if (option_warn && freport != NULL)
                    fprintf(freport,
                            "%s (%d) : Unknown character %d (decimal)\n",
                            html_fn, ln, (unsigned char)*str);
                if (mString)
                {   if (in_verb)
                {   
                    [mString appendFormat:@"%c", ch != '\0' ? ch : ' '];
                    if (   special && freport != NULL && option_warn
                           && v < NR_CH_M)
                    {   fprintf(freport, "%s (%d) : ", html_fn, ln);
                        if (html_ch[0] == '\0')
                            fprintf(freport, "character %d (decimal)", 
                                    (unsigned char) *str);
                        else
                            fprintf(freport, "sequence `&%s;'", html_ch);
                        fprintf(freport, " rendered as `%c' in verbatim\n",
                                ch != '\0' ? ch : ' ');
                    }
                }
                    else if (in_alltt)
                    {   if (special)
                    {   char *o = ch_table[v].tex_ch;
                        if (o != NULL)
                            if (*o == '$')
                                [mString appendFormat:@"\\(%s\\)", o + 1];
                            else
                                [mString appendFormat:@"%s", o];
                    }
                        else if (ch == '{' || ch == '}')
                            [mString appendFormat:@"\\%c", ch];
                        else if (ch == '\\')
                            [mString appendFormat:@"\\%c", ch];
                        else if (ch != '\0')
                            [mString appendFormat:@"%c", ch];
                    }
                    else if (special)
                    {   char *o = ch_table[v].tex_ch;
                        if (o == NULL)
                        {   if (freport != NULL && option_warn)
                        {   fprintf(freport,
                                    "%s (%d) : no LaTeX representation for ",
                                    html_fn, ln);
                            if (html_ch[0] == '\0')
                                fprintf(freport, "character %d (decimal)\n", 
                                        (unsigned char) *str);
                            else
                                fprintf(freport, "sequence `&%s;'\n", html_ch);
                        }
                        }
                        else if (*o == '$')
                            if (in_math)
                                [mString appendFormat:@"%s", o+1];
                            else
                                [mString appendFormat:@"{%s$}", o];
                        else
                            [mString appendFormat:@"%s", o];
                    }
                    else if (in_math)
                    {   if (ch == '#' || ch == '%')
                            [mString appendFormat:@"\\%c", ch];
                        else
                            [mString appendFormat:@"%c", ch];
                    }
                    else
                    {   switch(ch)
                    {   case '\0' : break;
                                        case '\t': [mString appendString:@"        "]; break;
					case '_': case '{': case '}':
					case '#': case '$': case '%':
                       [mString appendFormat:@"{\\%c}", ch]; break;
                                        case '@' : [mString appendFormat:@"{\\char64}"]; break;
					case '[' :
					case ']' : [mString appendFormat:@"{$%c$}", ch]; break;
					case '"' : [mString appendString:@"{\\tt{}\"{}}"]; break;
					case '~' : [mString appendString:@"\\~{}"]; break;
                                        case '^' : [mString appendString:@"\\^{}"]; break;
					case '|' : [mString appendString:@"{$|$}"]; break;
					case '\\': [mString appendString:@"{$\\backslash$}"]; break;
					case '&' : [mString appendString:@"\\&"]; break;
                                        default: [mString appendFormat:@"%c", ch]; break;
                    }
                    }
                }
	}
    return mString;
}

@end
