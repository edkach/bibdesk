//  BDSKConverter.m
//  Created by Michael McCracken on Thu Mar 07 2002.
/*
This software is Copyright (c) 2001,2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "BDSKConverter.h"

static BDSKConverter *theConverter;

@implementation BDSKConverter

+ (BDSKConverter *)sharedConverter{
    if(!theConverter){
	theConverter = [[[BDSKConverter alloc] init] retain];
    }
    return theConverter;
}

- (id)init{
    if(self = [super init]){
	[self loadDict];
    }
    return self;
}

- (void)dealloc{
    [wholeDict release];
    [emptySet release];
    [finalCharSet release];
    [texifyConversions release];
    [detexifyConversions release];
    [super dealloc];
}
    

- (void)loadDict{
    
    //create a characterset from the characters we know how to convert
    NSMutableCharacterSet *workingSet;
    NSRange highCharRange;
    
    wholeDict = [[NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"CharacterConversion.plist"]] retain];
    emptySet = [[NSCharacterSet characterSetWithCharactersInString:@""] retain];
    
    highCharRange.location = (unsigned int) '~' + 1; //exclude tilde, or we'll get an alert on it
    highCharRange.length = 256; //this should get all the characters in the upper-range.
    workingSet = [[NSCharacterSet decomposableCharacterSet] mutableCopy];
    [workingSet addCharactersInRange:highCharRange];

    // Build a dictionary of one-way conversions that we know how to do, then add these to the character set
    NSDictionary *oneWayCharacters = [wholeDict objectForKey:@"One-Way Conversions"];
    NSEnumerator *e = [oneWayCharacters keyEnumerator];
    NSString *oneWayKey;
      while(oneWayKey = [e nextObject]){
	  [workingSet addCharactersInString:oneWayKey];
      }

    finalCharSet = [workingSet copy];
    [workingSet release];
    
    // set up the dictionaries
    NSMutableDictionary *tmpConversions = [wholeDict objectForKey:@"Roman to TeX"];
    [tmpConversions addEntriesFromDictionary:[wholeDict objectForKey:@"One-Way Conversions"]];
    texifyConversions = [tmpConversions copy];
    
    if(!texifyConversions){
        texifyConversions = [[NSDictionary dictionary] retain]; // an empty one won't break the code.
    }
    
    detexifyConversions = [[wholeDict objectForKey:@"TeX to Roman"] retain];
    
    if(!detexifyConversions){
        detexifyConversions = [[NSDictionary dictionary] retain]; // an empty one won't break the code.
    }
}

- (NSString *)stringByTeXifyingString:(NSString *)s{
    // s should be in UTF-8 or UTF-16 (i'm not sure which exactly) format (since that's what the property list editor spat)
    // This direction could be faster, since we're comparing characters to the keys, but that'll be left for later.
    NSScanner *scanner = [[NSScanner alloc] initWithString:s];
    NSString *tmpConv = nil;
    NSMutableString *convertedSoFar = [s mutableCopy];

    unsigned sLength = [s length];
    
    int offset=0;
    unsigned index = 0;
    NSString *TEXString;
    
    // convertedSoFar has s to begin with.
    // while scanner's not at eof, scan up to characters from that set into tmpOut

    while(![scanner isAtEnd]){

	[scanner scanUpToCharactersFromSet:finalCharSet intoString:nil];
	index = [scanner scanLocation];

	if(index >= sLength) // don't go past the end
	    break;
	
	tmpConv = [s substringWithRange:NSMakeRange(index, 1)];

	if(TEXString = [texifyConversions objectForKey:tmpConv]){
	    [convertedSoFar replaceCharactersInRange:NSMakeRange((index + offset), 1)
								      withString:TEXString];
	    [scanner setScanLocation:(index + 1)];
	    offset += [TEXString length] - 1;    // we're adding length-1 characters, so we have to make sure we insert at the right point in the future.
	} else {
	    TEXString = [self convertedStringWithAccentedString:tmpConv];

	    // Check to see if the unicode composition conversion worked.  If it fails, it returns the decomposed string, so we precompose it
	    // and compare it to tmpConv; if they're the same, we know that the unicode conversion failed.
	    if(![tmpConv isEqualToString:[TEXString precomposedStringWithCanonicalMapping]]){
		// NSLog(@"plist didn't work, using unicode magic");
		[convertedSoFar replaceCharactersInRange:NSMakeRange((index + offset), 1)
					      withString:TEXString];
		[scanner setScanLocation:(index + 1)];
		offset += [TEXString length] - 1;
	    } else {
		if(tmpConv != nil){ // if tmpConv is non-nil, we had a character that was accented and not convertable by us
		    [NSObject cancelPreviousPerformRequestsWithTarget:self 
							     selector:@selector(runConversionAlertPanel:)
							       object:tmpConv];
		    [self performSelector:@selector(runConversionAlertPanel:) withObject:tmpConv afterDelay:0.1];
		    [scanner setScanLocation:(index + 1)]; // increment the scanner to go past the character that we don't have in the dict
		}
	    }
        }
    }
		
    
    //clean up
    [scanner release];
    
    return([convertedSoFar autorelease]);
}

- (NSString *)convertedStringWithAccentedString:(NSString *)s{
    
    // decompose into D form, make mutable
    NSMutableString * t = [[[s decomposedStringWithCanonicalMapping] mutableCopy] autorelease];
    
    NSDictionary * accents = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Accents" ofType:@"plist"]];
    NSArray * accentArray = [accents allKeys];
    NSString * accentString = [accentArray componentsJoinedByString:@""];
    NSCharacterSet * accentSet = [NSCharacterSet characterSetWithCharactersInString:accentString];
    BOOL goOn = YES;
    NSRange searchRange = NSMakeRange(0,[t length]);
    NSRange foundRange;
    NSRange composedRange;
    NSString * replacementString;
    
    while (goOn) {
	foundRange = [t rangeOfCharacterFromSet:accentSet options:NSLiteralSearch range:searchRange];

	if (foundRange.location == NSNotFound) {
	    // no more accents => STOP
	    goOn = NO;
	} else {
	    // found an accent => process
	    composedRange = [t rangeOfComposedCharacterSequenceAtIndex:foundRange.location];
	    replacementString = [self convertBunch:[t substringWithRange:composedRange] usingDict:accents];
	    [t replaceCharactersInRange:composedRange withString:replacementString];
	    
	    // move searchable range
	    searchRange.location = composedRange.location;
	    searchRange.length = [t length] - composedRange.location;
	}
    }
    
    return t;
    
}


- (NSString*) convertBunch:(NSString*) s usingDict:(NSDictionary*) accents {
    // isolate accent
    NSString * unicodeAccent = [s substringFromIndex:[s length] -1];
    NSString * accent = [accents objectForKey:unicodeAccent];
    
    // isolate character(s)
    NSString * character = [s substringToIndex:[s length] - 1];
    
    // handle i and j (others as well?)
    if ([character isEqualToString:@"i"] || [character isEqualToString:@"j"]) {
	if (![accent isEqualToString:@"c"] && ![accent isEqualToString:@"d"] && ![accent isEqualToString:@"b"]) {
	    character = [@"\\" stringByAppendingString:character];
	}
    }
    
    /* The following lines might give support for multiply accented characters. These are available in Unicode but don't seem to work in TeX.
	
	if ([character length] > 1) {
	    character = [self convertBunch:character usingDict:accents];
	}
    */
    
    return [NSString stringWithFormat:@"{\\%@%@}", accent, character];
}

- (void)runConversionAlertPanel:(NSString *)tmpConv{
    NSLog(@"runConversionAlert");
    NSString *errorString = [NSString localizedStringWithFormat:@"The accented or Unicode character \"%@\" could not be converted.  Please enter the TeX code directly in your bib file.", tmpConv];
    int i = NSRunAlertPanel(NSLocalizedString(@"Character Conversion Error",
				              @"Title of alert when an error happens"),
		            NSLocalizedString(errorString,
				              @"Informative alert text when the error happens."),
			    @"Send e-mail", @"Edit", nil, nil);
    if(i == NSAlertDefaultReturn){
	NSString *urlString = [NSString stringWithFormat:@"mailto:bibdesk-develop@lists.sourceforge.net?subject=Character Conversion Error&body=Please enter a description of the accented character \"%@\" that failed to convert and its TeX equivalent.", tmpConv];
	CFStringRef escapedString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)urlString, NULL, NULL, kCFStringEncodingUTF8);
	NSURL *mailURL = [NSURL URLWithString:[(NSString *)escapedString autorelease]];
	[[NSWorkspace sharedWorkspace] openURL:mailURL];
    } else {
    }
}


- (NSString *)stringByDeTeXifyingString:(NSString *)s{
    NSScanner *scanner = [NSScanner scannerWithString:s];
    NSString *tmpPass;
    NSString *tmpConv;
    NSString *tmpConvB;
    NSString *TEXString;
    NSMutableString *convertedSoFar = [[NSMutableString alloc] initWithCapacity:10];

    if(!s || [s isEqualToString:@""]){
        [convertedSoFar release];
        return [NSString string];
    }
    
    [scanner setCharactersToBeSkipped:emptySet];
    //    NSLog(@"scanning string: %@",s);
    while(![scanner isAtEnd]){
        if([scanner scanUpToString:@"{\\" intoString:&tmpPass])
            [convertedSoFar appendString:tmpPass];
        if([scanner scanUpToString:@"}" intoString:&tmpConv]){
            tmpConvB = [NSString stringWithFormat:@"%@}", tmpConv];
            if(TEXString = [detexifyConversions objectForKey:tmpConvB]){
                [convertedSoFar appendString:TEXString];
                [scanner scanString:@"}" intoString:nil];
            }else{
                [convertedSoFar appendString:tmpConvB];
                // if there's another rightbracket hanging around, we want to scan past it:
                [scanner scanString:@"}" intoString:nil];
                // but what if that was the end?
            }
        }
    }
    
  return [convertedSoFar autorelease]; 
}

- (NSString *)stringBySanitizingString:(NSString *)string forField:(NSString *)fieldName inFileType:(NSString *)type
{
	NSCharacterSet *invalidCharSet = [[BibTypeManager sharedManager] strictInvalidCharactersForField:fieldName inFileType:type];
	
	if ([fieldName isEqualToString:@"Cite Key"] || [fieldName isEqualToString:@"Local-Url"]) {
		NSString *newString;
		
		if (string == nil || [string isEqualToString:@""]) {
			return @"";
		}
		newString = [self stringByDeTeXifyingString:string];
		newString = [newString stringByReplacingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
													 withString:@"-"];
		newString = [[[NSString alloc] initWithData:[newString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] 
											encoding:NSASCIIStringEncoding] autorelease];
		newString = [newString stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		
		return newString;
	}
	else {
		[NSException raise:@"unimpl. feat. exc." format:@"stringBySanitizingString:forField: is partly implemented"];
		return string;
	}
}

- (BOOL)validateFormat:(NSString **)formatString forField:(NSString *)fieldName inFileType:(NSString *)type error:(NSString **)error
{
	// implemented specifiers, the same for any field and type
	NSCharacterSet *validSpecifierChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789aAtmyYrRd"];
	NSCharacterSet *validLastSpecifierChars = [NSCharacterSet characterSetWithCharactersInString:@"uUn"];
	NSCharacterSet *invalidCharSet = [[BibTypeManager sharedManager] strictInvalidCharactersForField:fieldName inFileType:type];
	NSArray *components = [*formatString componentsSeparatedByString:@"%"];
	NSString *string;
	NSArray *arr;
	NSMutableString *sanitizedFormatString = [NSMutableString string];
	unichar specifier;
	int i;
	
	for (i = 0; i < [components count]; i++) {
		// or should we sanitize here?
		string = [components objectAtIndex:i];
		if (i > 0) { //first part can be anything
			[sanitizedFormatString appendString:@"%"];
			if ([string isEqualToString:@""]) {
				// we found a %% escape
				if ([invalidCharSet characterIsMember:'%']) {
					*error = [NSString stringWithFormat: NSLocalizedString(@"Invalid specifier %%%C in format.", @""), '%'];
					return NO;
				}
				continue;
			}
			specifier = [string characterAtIndex:0];
			if (![validSpecifierChars characterIsMember:specifier]) {
				if (specifier == '{') {
					arr = [string componentsSeparatedByString:@"}"];
					if ([arr count] != 2) {
						*error = NSLocalizedString(@"Incomplete specifier {'field'} in format.", @"");
						return NO;
					}
					string = [self stringBySanitizingString:[arr objectAtIndex:0] forField:fieldName inFileType:type];
					[sanitizedFormatString appendFormat:@"{%@}",string];
					string = [self stringBySanitizingString:[arr objectAtIndex:1] forField:fieldName inFileType:type];
				}
				else if (	i < [components count] - 1 || 
							![validLastSpecifierChars characterIsMember:specifier] ) {
				
					*error = [NSString stringWithFormat: NSLocalizedString(@"Invalid specifier %%%C in format.", @""), specifier];
					return NO;
				}
			}
		}
		// sanitize stuff in between, this should not affect any of our specifier chars
		string = [self stringBySanitizingString:string forField:fieldName inFileType:type];
		[sanitizedFormatString appendString:string];
	}
	
	// change formatString
	*formatString = [[sanitizedFormatString copy] autorelease];
	
	return YES;
}

- (NSArray *)requiredFieldsForFormat:(NSString *)formatString
{
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:1];
	NSEnumerator *cEnum = [[formatString componentsSeparatedByString:@"%"] objectEnumerator];
	NSString *string;
	
	[cEnum nextObject];
	while (string = [cEnum nextObject]) {
		switch ([string characterAtIndex:0]) {
			case 'a':
			case 'A':
				[arr addObject:@"Author"];
				break;
			case 't':
				[arr addObject:@"Title"];
				break;
			case 'y':
			case 'Y':
				[arr addObject:@"Year"];
				break;
			case 'm':
				[arr addObject:@"Month"];
				break;
			case '{':
				[arr addObject:[[[string componentsSeparatedByString:@"}"] objectAtIndex:0] substringFromIndex:1]];
		}
	}
	return arr;
}

@end
