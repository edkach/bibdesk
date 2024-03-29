//  BDSKConverter.m
//  Created by Michael McCracken on Thu Mar 07 2002.
/*
 This software is Copyright (c) 2001-2012
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

#import "BDSKConverter.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKComplexString.h"
#import "BDSKAppController.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKStringNode.h"
#import "NSError_BDSKExtensions.h"

@interface BDSKConverter (Private)
- (void)setDetexifyAccents:(NSDictionary *)newAccents;
- (void)setAccentCharacterSet:(NSCharacterSet *)charSet;
- (void)setBaseCharacterSetForTeX:(NSCharacterSet *)charSet;
- (void)setTexifyAccents:(NSDictionary *)newAccents;
- (void)setFinalCharSet:(NSCharacterSet *)charSet;
- (void)setTexifyConversions:(NSDictionary *)newConversions;
- (void)setDeTexifyConversions:(NSDictionary *)newConversions;
static BOOL convertComposedCharacterToTeX(NSMutableString *charString, NSCharacterSet *baseCharacterSetForTeX, NSCharacterSet *accentCharSet, NSDictionary *texifyAccents);
static BOOL convertTeXStringToComposedCharacter(NSMutableString *texString, NSDictionary *detexifyAccents);
@end

@implementation BDSKConverter

static BDSKConverter *sharedConverter = nil;

+ (BDSKConverter *)sharedConverter{
    if (sharedConverter == nil)
        sharedConverter = [[self alloc] init];
    return sharedConverter;
}

- (id)init{
    BDSKPRECONDITION(sharedConverter == nil);
    self = [super init];
    if (self) {
        [self loadDict];
    }
    return self;
}

- (void)loadDict{
    
    NSDictionary *wholeDict = [NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:CHARACTER_CONVERSION_FILENAME]];
	NSDictionary *userWholeDict = nil;
    // look for the user file
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *charConvPath = [[fm applicationSupportDirectory] stringByAppendingPathComponent:CHARACTER_CONVERSION_FILENAME];
	
	if ([fm fileExistsAtPath:charConvPath]) {
		userWholeDict = [NSDictionary dictionaryWithContentsOfFile:charConvPath];
    }
    
    // set up the dictionaries
    NSMutableDictionary *tmpDetexifyDict = [NSMutableDictionary dictionary];
    [tmpDetexifyDict addEntriesFromDictionary:[wholeDict objectForKey:TEX_TO_ROMAN_KEY]];
    
    NSMutableDictionary *tmpTexifyDict = [NSMutableDictionary dictionary];
    [tmpTexifyDict addEntriesFromDictionary:[wholeDict objectForKey:ROMAN_TO_TEX_KEY]];
    [tmpTexifyDict addEntriesFromDictionary:[wholeDict objectForKey:ONE_WAY_CONVERSION_KEY]];
    
	if (userWholeDict) {
		[tmpTexifyDict addEntriesFromDictionary:[userWholeDict objectForKey:ROMAN_TO_TEX_KEY]];
		[tmpTexifyDict addEntriesFromDictionary:[userWholeDict objectForKey:ONE_WAY_CONVERSION_KEY]];
		[tmpDetexifyDict addEntriesFromDictionary:[userWholeDict objectForKey:TEX_TO_ROMAN_KEY]];
    }

    [self setTexifyConversions:tmpTexifyDict];
    [self setDeTexifyConversions:tmpDetexifyDict];
	
	// create a characterset from the characters we know how to convert
    NSMutableCharacterSet *workingSet;
	
    workingSet = [[NSCharacterSet characterSetWithRange:NSMakeRange(0x80, 0x1d0)] mutableCopy]; //this should get all the characters in Latin-1 Supplement, Latin Extended-A, and Latin Extended-B
    [workingSet addCharactersInRange:NSMakeRange(0x1e00, 0x100)]; //this should get all the characters in Latin Extended Additional.
    [workingSet formIntersectionWithCharacterSet:[NSCharacterSet decomposableCharacterSet]];
    for (NSString *string in [tmpTexifyDict allKeys])
        [workingSet addCharactersInString:string];
	
    [self setFinalCharSet:workingSet];
    [workingSet release];
            
	// build a character set of [a-z][A-Z] representing the base character set that we can decompose and recompose as TeX
    NSRange ucRange = NSMakeRange('A', 26);
    NSRange lcRange = NSMakeRange('a', 26);
    workingSet = [[NSCharacterSet characterSetWithRange:ucRange] mutableCopy];
    [workingSet addCharactersInRange:lcRange];
    [self setBaseCharacterSetForTeX:workingSet];
    [workingSet release];
	
    [self setTexifyAccents:[wholeDict objectForKey:ROMAN_TO_TEX_ACCENTS_KEY]];
    [self setAccentCharacterSet:[NSCharacterSet characterSetWithCharactersInString:[[texifyAccents allKeys] componentsJoinedByString:@""]]];
    [self setDetexifyAccents:[wholeDict objectForKey:TEX_TO_ROMAN_ACCENTS_KEY]];
}

- (NSString *)copyComplexString:(NSString *)cs byCopyingStringNodesUsingSelector:(SEL)copySelector {
    BDSKStringNode *newNode;
    NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:[[cs nodes] count]];
    NSString *string;
    
    for (BDSKStringNode *node in [cs nodes]) {
        if ([node type] == BDSKStringNodeString) {
            string = [self performSelector:copySelector withObject:[node value]];
            newNode = [[BDSKStringNode alloc] initWithQuotedString:string];
            [string release];
        } else {
            newNode = [node copy];
        }
        [nodes addObject:newNode];
        [newNode release];
    }
    
    string = [[NSString alloc] initWithNodes:nodes macroResolver:[cs macroResolver]];
    [nodes release];
    return string;
}

- (NSString *)copyStringByTeXifyingString:(NSString *)s{
    
	// TeXify only string nodes of complex strings;
	if([s isComplex]){
        return [self copyComplexString:s byCopyingStringNodesUsingSelector:_cmd];
	}
    
    if([NSString isEmptyString:s]){
        return [s retain];
    }
	
    // we expect to find composed accented characters, as this is also what we use in the CharacterConversion plist
    NSMutableString *precomposedString = [s mutableCopy];
    CFStringNormalize((CFMutableStringRef)precomposedString, kCFStringNormalizationFormC);
    
    NSMutableString *tmpConv = nil;
    NSMutableString *convertedSoFar = [precomposedString mutableCopy];

    CFIndex offset = 0;
    NSString *TEXString = nil;
    
    UniChar ch;
    CFIndex idx, numberOfCharacters = CFStringGetLength((CFStringRef)precomposedString);
    NSRange r;
    CFStringInlineBuffer inlineBuffer;
    CFStringInitInlineBuffer((CFStringRef)precomposedString, &inlineBuffer, CFRangeMake(0, numberOfCharacters));
    
    for (idx = 0; (idx < numberOfCharacters); idx++) {
        
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx);
        
        if ([finalCharSet characterIsMember:ch]){
            
            r = [precomposedString rangeOfComposedCharacterSequenceAtIndex:idx];
            
            if (r.length > 1) {
                // composed character could not be precomposed, we cannot handle this so leave it as is
                idx += r.length - 1;
                
            } else {
                tmpConv = [[NSMutableString alloc] initWithCharactersNoCopy:&ch length:1 freeWhenDone:NO];
        
                // try the dictionary first
                if((TEXString = [texifyConversions objectForKey:tmpConv])){
                    [convertedSoFar replaceCharactersInRange:NSMakeRange((idx + offset), 1) withString:TEXString];
                    // we're adding length-1 characters, so we have to make sure we insert at the right point in the future.
                    offset += [TEXString length] - 1;
                    
                // fall back to Unicode decomposition/conversion of the mutable string
                } else if(convertComposedCharacterToTeX(tmpConv, baseCharacterSetForTeX, accentCharSet, texifyAccents)){
                    [convertedSoFar replaceCharactersInRange:NSMakeRange((idx + offset), 1) withString:tmpConv];
                    // we're adding length-1 characters, so we have to make sure we insert at the right point in the future.
                    offset += [tmpConv length] - 1;
                    
                }
                [tmpConv release];
            }
            
        }
    }
    
    [precomposedString release];
    
    return convertedSoFar;
}

static BOOL convertComposedCharacterToTeX(NSMutableString *charString, NSCharacterSet *baseCharacterSetForTeX, NSCharacterSet *accentCharSet, NSDictionary *texifyAccents)
{        
    // decompose to canonical form
    CFStringNormalize((CFMutableStringRef)charString, kCFStringNormalizationFormD);
    NSUInteger decomposedLength = [charString length];
    
    // first check if we can convert this, we should have a base character + an accent we know
    if (decomposedLength == 0 || [baseCharacterSetForTeX characterIsMember:[charString characterAtIndex:0]] == NO)
        return NO;
    // no-op; this case will likely never happen
    else if (decomposedLength == 1)
        return YES;
    // @@ we could allow decomposedLength > 2, it doesn't break TeX (though it gives funny results)
    else if (decomposedLength > 2 || [accentCharSet characterIsMember:[charString characterAtIndex:1]] == NO)
        return NO;
    
    CFAllocatorRef alloc = CFGetAllocator(charString);
    // isolate accent
    NSString *accentChar = (NSString *)CFStringCreateWithSubstring(alloc, (CFStringRef)charString, CFRangeMake(1, 1));
    NSString *accent = [texifyAccents objectForKey:accentChar];
    [accentChar release];
    
    // isolate character
    NSString *character = (NSString *)CFStringCreateWithSubstring(alloc, (CFStringRef)charString, CFRangeMake(0, 1));
    
    // handle i and j (others as well?)
    if (([character isEqualToString:@"i"] || [character isEqualToString:@"j"]) &&
		![accent isEqualToString:@"c "] && ![accent isEqualToString:@"d "] && ![accent isEqualToString:@"b "]) {
        NSString *oldCharacter = character;
	    character = [[@"\\" stringByAppendingString:oldCharacter] copy];
        [oldCharacter release];
    }
    
    // [accent length] == 2 in some cases, and the 'character' may or may not have \\ prepended, so we'll just replace the entire string rather than trying to catch all of those cases by recomputing lengths
    [charString replaceCharactersInRange:NSMakeRange(0, decomposedLength) withString:@"{\\"];
    [charString appendString:accent];
    [charString appendString:character];
    [charString appendString:@"}"];
    
    [character release];
    
    return YES;
}

- (NSString *)copyStringByDeTeXifyingString:(NSString *)s{

	// deTeXify only string nodes of complex strings;
	if([s isComplex]){
        return [self copyComplexString:s byCopyingStringNodesUsingSelector:_cmd];
	}
    
    if([NSString isEmptyString:s]){
        return [s retain];
    }
	
    NSMutableString *tmpConv = nil;
    NSString *TEXString = nil;

    NSMutableString *convertedSoFar = nil;
    NSUInteger start, length = [s length];
    NSRange range = [s rangeOfString:@"{\\" options:0 range:NSMakeRange(0, length)];
    
    if (range.length){
        
        NSRange closingRange, replaceRange;
        convertedSoFar = [s mutableCopy];
        
        while (range.length) {
            
            start = NSMaxRange(range);
            closingRange = [convertedSoFar rangeOfString:@"}" options:0 range:NSMakeRange(start, length - start)];
            
            if (closingRange.length) {
                
                replaceRange = NSMakeRange(range.location, closingRange.location - range.location + 1);
                CFStringRef tmpString = CFStringCreateWithSubstring(NULL, (CFStringRef)convertedSoFar, CFRangeMake(replaceRange.location, replaceRange.length));
                tmpConv = [(NSString *)tmpString mutableCopy];
                CFRelease(tmpString);
                
                // see if the dictionary has a conversion, or try Unicode composition
                if(TEXString = [detexifyConversions objectForKey:tmpConv]){
                    [convertedSoFar replaceCharactersInRange:replaceRange withString:TEXString];
                }else if(convertTeXStringToComposedCharacter(tmpConv, detexifyAccents)) {
                    [convertedSoFar replaceCharactersInRange:replaceRange withString:tmpConv];
                }
                [tmpConv release];
                
                // advance the starting search range by a single character, so if replacement failed we don't start at {\ again
                // this is inside the if() since if there were no closing braces, there's no point in repeating the search
                length = [convertedSoFar length];
                range = [convertedSoFar rangeOfString:@"{\\" options:0 range:NSMakeRange(replaceRange.location + 1, length - replaceRange.location - 1)];
            } else {
                NSLog(@"missing brace in string %@", convertedSoFar);
                range = NSMakeRange(NSNotFound, 0);
            }
            
        }
    } else {
        
        // if there was no character, we don't bother creating a mutable copy of the string
        convertedSoFar = [s copy];
    }
    BDSKPOSTCONDITION(nil != convertedSoFar);
    return convertedSoFar; 
}

// takes a sequence such as "{\'i}" or "{\v S}" (no quotes) and converts to appropriate composed characters
// returns nil if unable to convert
static BOOL convertTeXStringToComposedCharacter(NSMutableString *texString, NSDictionary *detexifyAccents)
{        
    // check this before creating a scanner
    if (nil == texString)
        return NO;
    
	NSString *texAccent = nil;
	NSString *accent = nil;
    CFIndex idx = 0, length = [texString length];
    
    CFStringInlineBuffer inlineBuffer;
    CFStringInitInlineBuffer((CFStringRef)texString, &inlineBuffer, CFRangeMake(0, length));
    
    // check for {\ prefix
    if (CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx++) != '{' ||
        CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx++) != '\\')
        return NO;
    
    UniChar ch, accentCh = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx++);
    
    // convert the TeX form of the accent to a string and see if we can convert it
    texAccent = [[NSString alloc] initWithCharactersNoCopy:&accentCh length:1 freeWhenDone:NO];
    accent = [detexifyAccents objectForKey:texAccent];
    [texAccent release];
    
    if (nil == accent)
        return NO;    
    
    // get the character immediately following the accent
    ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx);
    
    if ([[NSCharacterSet letterCharacterSet] characterIsMember:accentCh] && ch != ' ')
        return NO; // error: if accentCh was a letter (e.g. {\v S}), it must be followed by a space
    else if (ch == ' ')
        idx++;      // TeX accepts {\' i} or {\'i}, but space shouldn't be included in the letter token
    
    CFIndex letterStart = idx;
    NSString *character = nil;
    
    for (idx = letterStart; idx < length; idx++) {
        
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx);

        // scan up to the closing brace, since we don't know the character substring length beforehand
        if (ch == '}') {

            CFAllocatorRef alloc = CFGetAllocator(texString);
            character = (NSString *)CFStringCreateWithSubstring(alloc, (CFStringRef)texString, CFRangeMake(letterStart, idx - letterStart));
            
            // special cases for old style i, j
            if ([character isEqualToString:@"\\i"]) {
                [character release];
                character = [@"i" retain];
            } else if ([character isEqualToString:@"\\j"]) {
                [character release];
                character = [@"j" retain];
            }
            
            if ([character length] == 1) {
                CFMutableStringRef mutableCharacter = CFStringCreateMutableCopy(alloc, 0, (CFStringRef)character);
                CFStringAppend(mutableCharacter, (CFStringRef)accent);
                CFStringNormalize(mutableCharacter, kCFStringNormalizationFormC);
                
                if (CFStringGetLength(mutableCharacter) == 1) {
                    [texString setString:(NSString *)mutableCharacter];
                } else {
                    // if it can't be composed to a single character, we won't be able to convert it back
                    [character release];
                    CFRelease(mutableCharacter);
                    return NO;
                }
                
                // should be at idx = length anyway
                [character release];
                CFRelease(mutableCharacter);
                return YES;
            } else {
                
                // incorrect length of the character
                [character release];
                return NO;
            }
        }
    }
    
    return NO;
}

@end

@implementation BDSKConverter (Private)

- (void)setDetexifyAccents:(NSDictionary *)newAccents{
    if(detexifyAccents != newAccents){
        [detexifyAccents release];
        detexifyAccents = [newAccents copy];
    }
}

- (void)setAccentCharacterSet:(NSCharacterSet *)charSet{
    if(accentCharSet != charSet){
        [accentCharSet release];
        accentCharSet = [charSet copy];
    }
}

- (void)setBaseCharacterSetForTeX:(NSCharacterSet *)charSet{
    if(baseCharacterSetForTeX != charSet){
        [baseCharacterSetForTeX release];
        baseCharacterSetForTeX = [charSet copy];
    }
}

- (void)setTexifyAccents:(NSDictionary *)newAccents{
    if(texifyAccents != newAccents){
        [texifyAccents release];
        texifyAccents = [newAccents copy];
    }
}

- (void)setFinalCharSet:(NSCharacterSet *)charSet{
    if(finalCharSet != charSet){
        [finalCharSet release];
        finalCharSet = [charSet copy];
    }
}

- (void)setTexifyConversions:(NSDictionary *)newConversions{
    if(texifyConversions != newConversions){
        [texifyConversions release];
        texifyConversions = [newConversions copy];
    }
}

- (void)setDeTexifyConversions:(NSDictionary *)newConversions{
    if(detexifyConversions != newConversions){
        [detexifyConversions release];
        detexifyConversions = [newConversions copy];
    }
}

@end

@implementation NSString (BDSKConverter)

- (NSString *)copyTeXifiedString { return [[BDSKConverter sharedConverter] copyStringByTeXifyingString:self]; }
- (NSString *)stringByTeXifyingString { return [[self copyTeXifiedString] autorelease]; }
- (NSString *)copyDeTeXifiedString { return [[BDSKConverter sharedConverter] copyStringByDeTeXifyingString:self]; }
- (NSString *)stringByDeTeXifyingString { return [[self copyDeTeXifiedString] autorelease]; }

@end
