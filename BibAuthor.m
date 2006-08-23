//  BibAuthor.m

//  Created by Michael McCracken on Wed Dec 19 2001.
/*
 This software is Copyright (c) 2001,2002,2003,2004,2005,2006
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

#import "BibAuthor.h"
#import "BibItem.h"
#import <OmniFoundation/OmniFoundation.h>
#import "BibPrefController.h"
#import "BibTeXParser.h"

@interface BibAuthor (Private)

- (void)splitName:(NSString *)newName;
- (void)setNormalizedName:(NSString *)theName;
- (void)setSortableName:(NSString *)theName;
- (void)cacheNames;
- (void)setVonPart:(NSString *)newVonPart;
- (void)setLastName:(NSString *)newLastName;
- (void)setFirstName:(NSString *)newFirstName;
- (void)setJrPart:(NSString *)newJrPart;
- (void)setFuzzyName:(NSString *)theName;
- (NSString *)fuzzyName; // this is an implementation detail, so other classes mustn't rely on it
- (void)setupAbbreviatedNames;

@end

static BibAuthor *emptyAuthorInstance = nil;

@implementation BibAuthor

+ (void)initialize{
    
    OBINITIALIZE;
    emptyAuthorInstance = [[BibAuthor alloc] initWithName:@"" andPub:nil];
}
    

+ (BOOL)accessInstanceVariablesDirectly{ 
    return NO; 
}

+ (BibAuthor *)authorWithName:(NSString *)newName andPub:(BibItem *)aPub{	
    return [[[BibAuthor alloc] initWithName:newName andPub:aPub] autorelease];
}

+ (BibAuthor *)authorWithVCardRepresentation:(NSData *)vCard andPub:aPub{
    ABPerson *person = [[ABPerson alloc] initWithVCardRepresentation:vCard];
    NSMutableString *name = [[NSMutableString alloc] initWithCapacity:10];
    
    if([person valueForKey:kABFirstNameProperty]){
        [name appendString:[person valueForKey:kABFirstNameProperty]];
        [name appendString:@" "];
    }
    if([person valueForKey:kABLastNameProperty])
        [name appendString:[person valueForKey:kABLastNameProperty]];
    
    [person release];
    
    BibAuthor *author = [NSString isEmptyString:name] ? [BibAuthor emptyAuthor] : [BibAuthor authorWithName:name andPub:aPub];
    [name release];
    
    return author;
}
    
    

+ (id)emptyAuthor{
    OBASSERT(emptyAuthorInstance != nil);
    return emptyAuthorInstance;
}

- (id)initWithName:(NSString *)aName andPub:(BibItem *)aPub{
	if (self = [super init]) {
        // zero the flags
        memset(&flags, 0, sizeof(BibAuthorFlags));

		// set this first so we have the document for parser errors
        publication = aPub; // don't retain this, since it retains us
        // this does all the name parsing
		[self splitName:aName];
	}
    
    return self;
}

- (void)dealloc{
    [firstNames release];
    [name release];
	[firstName release];
	[vonPart release];
	[lastName release];
	[jrPart release];
	[normalizedName release];
    [sortableName release];
    [abbreviatedName release];
    [abbreviatedNormalizedName release];
    [fuzzyName release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone{
    // authors are immutable
    return [self retain];
}

- (id)initWithCoder:(NSCoder *)coder{
    if([coder allowsKeyedCoding]){
        self = [super init];
        memset(&flags, 0, sizeof(BibAuthorFlags));
        [self splitName:[coder decodeObjectForKey:@"name"]]; // this should take care of the rest of the ivars, right?
        publication = [coder decodeObjectForKey:@"publication"];
    } else {
        [[super init] release];
        self = [[NSKeyedUnarchiver unarchiveObjectWithData:[coder decodeDataObject]] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
    if([coder allowsKeyedCoding]){
        [coder encodeObject:name forKey:@"name"];
        [coder encodeConditionalObject:publication forKey:@"publication"];
    } else {
        [coder encodeDataObject:[NSKeyedArchiver archivedDataWithRootObject:self]];
    }  
}

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    return [encoder isByref] ? (id)[NSDistantObject proxyWithLocal:self connection:[encoder connection]] : self;
}

- (BOOL)isEqual:(BibAuthor *)otherAuth{
    if (![otherAuth isKindOfClass:[self class]])
		return NO;
    return otherAuth == self ? YES : [normalizedName isEqualToString:otherAuth->normalizedName];
}

- (unsigned int)hash{
    // @@ assumes that these objects will not be modified while contained in a hashing collection
    return hash;
}

#pragma mark Comparison

// returns an array of first names, assuming that words and initials are separated by whitespace or '.'
- (NSArray *)firstNames{
    return firstNames;
}    

//
// Examples of the various cases we need to handle in comparing first names (for /fuzzy/ matching)
//
// Knuth, D. E.       Knuth, Donald E.
// Knuth, D.          Knuth, D. E.
// Knuth, Don E.      Knuth, Donald
// Knuth, Donald      Knuth, Donald E.
// Knuth, Donald E.   Knuth, Donald Ervin
//

static inline NSComparisonResult
__BibAuthorCompareFirstNames(CFArrayRef myFirstNames, CFArrayRef otherFirstNames)
{
    CFIndex i, cnt = MIN(CFArrayGetCount(myFirstNames), CFArrayGetCount(otherFirstNames));
    CFStringRef myName;
    CFStringRef otherName;
    CFRange range = CFRangeMake(0, 0);
    
    NSComparisonResult result;
    CFAllocatorRef allocator = CFAllocatorGetDefault();
    
    for(i = 0; i < cnt; i++){
        myName = CFArrayGetValueAtIndex(myFirstNames, i);
        otherName = CFArrayGetValueAtIndex(otherFirstNames, i);
        
        range.length = MIN(CFStringGetLength(myName), CFStringGetLength(otherName));
        myName = CFStringCreateWithSubstring(allocator, myName, range);
        otherName = CFStringCreateWithSubstring(allocator, otherName, range);
        
        result = CFStringCompare(myName, otherName, kCFCompareCaseInsensitive|kCFCompareLocalized);
        CFRelease(myName);
        CFRelease(otherName);
        
        if(result != NSOrderedSame)
            return result;
    }
    
    // all prefixes of all first name strings compared the same
    return NSOrderedSame;
}

- (NSComparisonResult)compare:(BibAuthor *)otherAuth{
	return [[self normalizedName] compare:[otherAuth normalizedName] options:NSCaseInsensitiveSearch];
}

// fuzzy tries to match despite common omissions.
// currently can't handle spelling errors.
- (NSComparisonResult)fuzzyCompare:(BibAuthor *)otherAuth{
    NSComparisonResult result;
    
    // check to see if last names match; if not, we can return immediately
    result = CFStringCompare((CFStringRef)fuzzyName, (CFStringRef)[otherAuth fuzzyName], kCFCompareCaseInsensitive|kCFCompareLocalized);
    
    if(result != kCFCompareEqualTo)
        return result;

    // if one of the first names is empty, no point in doing anything more sophisticated (unless we want to force the order here)
    if(BDIsEmptyString((CFStringRef)firstName) || BDIsEmptyString((CFStringRef)[otherAuth firstName]))
        return CFStringCompare((CFStringRef)firstName, (CFStringRef)[otherAuth firstName], kCFCompareCaseInsensitive|kCFCompareLocalized);
    else 
        return __BibAuthorCompareFirstNames((CFArrayRef)[self firstNames], (CFArrayRef)[otherAuth firstNames]);
}

- (NSComparisonResult)sortCompare:(BibAuthor *)otherAuth{ // used for tableview sorts; omits von and jr parts
    if(self == emptyAuthorInstance)
        return (otherAuth == emptyAuthorInstance ? NSOrderedSame : NSOrderedDescending);
    if(otherAuth == emptyAuthorInstance)
        return NSOrderedAscending;
    return [[self sortableName] localizedCaseInsensitiveCompare:[otherAuth sortableName]];
}


#pragma mark String Representations

- (NSString *)description{
    return normalizedName;
}

- (NSString *)displayName{
    OFPreferenceWrapper *prefs = [OFPreferenceWrapper sharedPreferenceWrapper];
    BOOL displayFirst = [prefs boolForKey:BDSKShouldDisplayFirstNamesKey];
    BOOL displayAbbreviated = [prefs boolForKey:BDSKShouldAbbreviateFirstNamesKey];
    BOOL displayLastFirst = [prefs boolForKey:BDSKShouldDisplayLastNameFirstKey];

    NSString *theName = nil;

    if(displayFirst == NO){
        theName = lastName; // and then ignore the other options
    } else {
        if(displayLastFirst)
            theName = displayAbbreviated ? [self abbreviatedNormalizedName] : normalizedName;
        else
            theName = displayAbbreviated ? [self abbreviatedName] : name;
    }
    return theName;
}


#pragma mark Component Accessors

- (NSString *)normalizedName{
	return normalizedName;
}

- (NSString *)sortableName{
    return sortableName;
}

- (NSString *)name{
    return name;
}

- (NSString *)firstName{
    return firstName;
}

- (NSString *)vonPart{
    return vonPart;
}

- (NSString *)lastName{
    return lastName;
}

- (NSString *)jrPart{
    return jrPart;
}

// Given a normalized name of "von Last, Jr, First Middle", this will return "F. M. von Last, Jr"
- (NSString *)abbreviatedName{
    if(abbreviatedName == nil)
        [self setupAbbreviatedNames];
    return abbreviatedName;
}

// Given a normalized name of "von Last, Jr, First Middle", this will return "von Last, Jr, F. M."
- (NSString *)abbreviatedNormalizedName{
    if(abbreviatedNormalizedName == nil)
        [self setupAbbreviatedNames];
    return abbreviatedNormalizedName;
}

- (NSString *)MODSStringWithRole:(NSString *)role{
    NSMutableString *s = [NSMutableString stringWithString:@"<name type=\"personal\">"];
    
    if(firstName){
        [s appendFormat:@"<namePart type=\"given\">%@</namePart>", firstName];
    }
    
    if(lastName){
        [s appendFormat:@"<namePart type=\"family\">%@%@</namePart>", (vonPart ? vonPart : @""),
            lastName];
    }
    
    if(role){
        [s appendFormat:@"<role> <roleTerm authority=\"marcrelator\" type=\"text\">%@</roleTerm></role>",
        role];
    }
    
    [s appendString:@"</name>"];
    
    return [[s copy] autorelease];
}

- (BibItem *)publication{
    return publication;
}

- (void)setPublication:(BibItem *)newPub{
    if(publication != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Attempt to modify non-nil attribute of immutable object %@", self] userInfo:nil];
    publication = newPub;
}

// Accessors for personController - we don't retain it to avoid cycles.
- (BibPersonController *)personController{
    return personController; 
}

- (void)setPersonController:(BibPersonController *)newPersonController{
	personController = newPersonController;
}

- (ABPerson *)personFromAddressBook{
    ABSearchElement *lastNameSearch = [ABPerson searchElementForProperty:kABLastNameProperty label:nil key:nil value:lastName comparison:kABEqualCaseInsensitive];
    ABSearchElement *firstNameSearch = [ABPerson searchElementForProperty:kABFirstNameProperty label:nil key:nil value:([firstNames count] ? [firstNames objectAtIndex:0] : @"") comparison:kABPrefixMatch];
    
    ABSearchElement *firstAndLastName = [ABSearchElement searchElementForConjunction:kABSearchAnd children:[NSArray arrayWithObjects:lastNameSearch, firstNameSearch, nil]];
    
    NSArray *matches = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:firstAndLastName];
    
    return [matches count] ? [matches objectAtIndex:0] : nil;
}

@end

@implementation BibAuthor (Private)

- (void)splitName:(NSString *)newName{
    
    NSParameterAssert(newName != nil);
    // @@ this is necessary because the hash method depends on the internal state of the object (which is itself necessary since we can have multiple author instances of the same author)
    if(name != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Attempt to modify non-nil attribute of immutable object %@", self] userInfo:nil];
    
    NSDictionary *nameDict = [BibTeXParser splitAuthorName:newName document:[[self publication] document]];
    
    [self setFirstName:[nameDict objectForKey:@"firstName"]];
    [self setVonPart:[nameDict objectForKey:@"vonPart"]];
    [self setLastName:[nameDict objectForKey:@"lastName"]];
    [self setJrPart:[nameDict objectForKey:@"jrPart"]];
    
    // create the name as "First Middle von Last, Jr", which is more readable and less sortable
    // @@ This will potentially alter data if BibItem ever saves based on -[BibAuthor name] instead of the original string it keeps in pubFields
    NSMutableString *mutableString = [[NSMutableString alloc] initWithCapacity:14];
    
    flags.hasFirst = !BDIsEmptyString((CFStringRef)firstName);
	flags.hasVon = !BDIsEmptyString((CFStringRef)vonPart);
	flags.hasLast = !BDIsEmptyString((CFStringRef)lastName);
    flags.hasJr = !BDIsEmptyString((CFStringRef)jrPart);
   
    // first and middle are associated
    if(flags.hasFirst){
        [mutableString appendString:firstName];
        [mutableString appendString:@" "];
    }
    
    if(flags.hasVon){
        [mutableString appendString:vonPart];
        [mutableString appendString:@" "];
    }
    
    if(flags.hasLast) [mutableString appendString:lastName];
    
    if(flags.hasJr){
        [mutableString appendString:@", "];
        [mutableString appendString:jrPart];
    }
    
    OBPRECONDITION(name == nil);
    name = [mutableString copy];
    
    [mutableString release];
	
    [self cacheNames];
    // we create abbreviated forms lazily as we might not always need them
}

- (void)setVonPart:(NSString *)newVonPart{
    if(vonPart != newVonPart){
        [vonPart release];
        vonPart = [newVonPart copy];
    }
}

- (void)setLastName:(NSString *)newLastName{
    if(lastName != newLastName){
        [lastName release];
        lastName = [newLastName copy];
    }
}

- (void)setFirstName:(NSString *)newFirstName{
    if(firstName != newFirstName){
        [firstName release];
        firstName = [newFirstName copy];
    }
}

- (void)setJrPart:(NSString *)newJrPart{
    if(jrPart != newJrPart){
        [jrPart release];
        jrPart = [newJrPart copy];
    }
}

- (void)setNormalizedName:(NSString *)theName{
    if(normalizedName != theName){
        [normalizedName release];
        normalizedName = [theName copy];
    }
}

// This follows the recommendations from Oren Patashnik's btxdoc.tex:
/*To summarize, BibTEX allows three possible forms for the name: 
"First von Last" 
"von Last, First" 
"von Last, Jr, First" 
You may almost always use the first form; you shouldn�t if either there�s a Jr part, or the Last part has multiple tokens but there�s no von part. 
*/
// Note that if there is only one word/token, it is the lastName, so that's assumed to always be there.

- (void)cacheNames{
	
	// temporary string storage
    NSMutableString *theName = [[NSMutableString alloc] initWithCapacity:14];
    
    // create the normalized name (see comment above method)
    
    if(flags.hasVon){
        [theName appendString:vonPart];
        [theName appendString:@" "];
    }
    
    if(flags.hasLast) [theName appendString:lastName];
    
    if(flags.hasJr){
        [theName appendString:@", "];
        [theName appendString:jrPart];
    }
    
    if(flags.hasFirst){
        [theName appendString:@", "];
        [theName appendString:firstName];
    }
    
    [self setNormalizedName:theName];
    
    // our hash is based upon the normalized name, so isEqual: must also be based upon the normalized name
    hash = [normalizedName hash];

    // create the sortable name
    // "Lastname Firstname" (no comma, von, or jr), with braces removed
        
    [theName setString:@""];
    [theName appendString:(flags.hasLast ? lastName : @"")];
    [theName appendString:(flags.hasFirst ? @" " : @"")];
    [theName appendString:(flags.hasFirst ? firstName : @"")];
    [theName deleteCharactersInCharacterSet:[NSCharacterSet curlyBraceCharacterSet]];
    [self setSortableName:theName];
    
    // components of the first name used in fuzzy comparisons
    
    static CFCharacterSetRef separatorSet = NULL;
    if(separatorSet == NULL)
        separatorSet = CFCharacterSetCreateWithCharactersInString(CFAllocatorGetDefault(), CFSTR(" ."));
    
    // @@ see note on firstLetterCharacterString() function for possible issues with this
    firstNames = (id)BDStringCreateComponentsSeparatedByCharacterSetTrimWhitespace(CFAllocatorGetDefault(), (CFStringRef)firstName, separatorSet, FALSE);

    // fuzzy comparison  name
    // don't bother with spaces for this comparison (and whitespace is already collapsed)
    
    [theName setString:@""];
    if(flags.hasVon) [theName appendString:vonPart];
	if(flags.hasLast) [theName appendString:lastName];
    [self setFuzzyName:theName];
    
    // dispose of the temporary mutable string
    [theName release];
}

- (void)setFuzzyName:(NSString *)theName{
    if(fuzzyName != theName){
        [fuzzyName release];
        fuzzyName = [theName copy];
    }
}

- (NSString *)fuzzyName{
    return fuzzyName;
}

- (void)setSortableName:(NSString *)theName{
    if(sortableName != theName){
        [sortableName release];
        sortableName = [theName copy];
    }
}

// Bug #1436631 indicates that "Pomies, M.-P." was displayed as "M. -. Pomies", so we'll grab the first letter character instead of substringToIndex:1.  The technically correct solution may be to use "M. Pomies" in this case, but we split the first name at "." boundaries to generate the firstNames array.
static inline NSString *firstLetterCharacterString(NSString *string)
{
    NSRange range = [string rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]];
    return (range.location != NSNotFound) ? [string substringWithRange:range] : nil;
}

- (void)setAbbreviatedName:(NSString *)aName{
    if(aName != abbreviatedName){
        [abbreviatedName release];
        abbreviatedName = [aName copy];
    }
}

- (void)setAbbreviatedNormalizedName:(NSString *)aName{
    if(aName != abbreviatedNormalizedName){
        [abbreviatedNormalizedName release];
        abbreviatedNormalizedName = [aName copy];
    }
}

- (void)setupAbbreviatedNames{
    CFArrayRef theFirstNames = (CFArrayRef)[self firstNames];
    CFIndex idx, firstNameCount = CFArrayGetCount(theFirstNames);
    NSString *fragment = nil;
    NSString *firstLetter = nil;
    NSMutableString *abbrevName = [[NSMutableString alloc] initWithCapacity:[name length]];
    NSMutableString *abbrevFirstName = [[NSMutableString alloc] initWithCapacity:3 * firstNameCount];
    NSMutableString *abbrevLastName = [[NSMutableString alloc] initWithCapacity:[name length]];

    for(idx = 0; idx < firstNameCount; idx++){
        fragment = (NSString *)CFArrayGetValueAtIndex(theFirstNames, idx);
        firstLetter = firstLetterCharacterString(fragment);
        if (firstLetter != nil) {
            [abbrevFirstName appendString:firstLetter];
            [abbrevFirstName appendString:idx == firstNameCount - 1 ? @".", @". "];
        }
    }
    
    // abbrevName should be empty or have a single trailing space
    if(flags.hasVon){
        [abbrevLastName appendString:vonPart];
        [abbrevLastName appendString:@" "];
    }
    
    if(flags.hasLast)
        [abbrevLastName appendString:lastName];
    
    if(flags.hasJr){
        [abbrevLastName appendString:@", "];
        [abbrevLastName appendString:jrPart];
    }
    
    // first for the abbreviated form
    if(flags hasFirst){
        [abbrevName appendString:abbrevFirstName];
        [abbrevName appendString:@" "];
    }
    
    [abbrevName appendString:abbrevLastName];
    
    [self setAbbreviatedName:abbrevName];
    
    // now for the normalized abbreviated form
    [abbrevName setString:abbrevLastName];
    
    if(flags hasFirst){
        [abbrevName appendString:@", "];
        [abbrevName appendString:abbrevFirstName];
    }
    
    [self setAbbreviatedNormalizedName:abbrevName];
    [abbrevName release];
}

@end

#pragma mark Specialized collections

// fuzzy equality requires that last names be equal case-insensitively, so equal objects are guaranteed the same hash
CFHashCode BibAuthorFuzzyHash(const void *item)
{
    OBASSERT([(id)item isKindOfClass:[BibAuthor class]]);
    return BDCaseInsensitiveStringHash([(BibAuthor *)item lastName]);
}

Boolean BibAuthorFuzzyEqual(const void *value1, const void *value2)
{        
    OBASSERT([(id)value1 isKindOfClass:[BibAuthor class]] && [(id)value2 isKindOfClass:[BibAuthor class]]);
    return [(BibAuthor *)value1 fuzzyCompare:(BibAuthor *)value2] == NSOrderedSame ? TRUE : FALSE;
}

const CFSetCallBacks BDSKAuthorFuzzySetCallbacks = {
    0,    // version
    OFNSObjectRetain,  // retain
    OFNSObjectRelease, // release
    OFNSObjectCopyDescription,
    BibAuthorFuzzyEqual,
    BibAuthorFuzzyHash,
};

const CFDictionaryKeyCallBacks BDSKFuzzyDictionaryKeyCallBacks = {
    0,
    OFNSObjectRetain,
    OFNSObjectRelease,
    OFNSObjectCopyDescription,
    BibAuthorFuzzyEqual,
    BibAuthorFuzzyHash,
};

const CFArrayCallBacks BDSKAuthorFuzzyArrayCallBacks = {
    0,    // version
    OFNSObjectRetain,  // retain
    OFNSObjectRelease, // release
    OFNSObjectCopyDescription,
    BibAuthorFuzzyEqual,
};

NSMutableSet *BDSKCreateFuzzyAuthorCompareMutableSet()
{
    return (NSMutableSet *)CFSetCreateMutable(CFAllocatorGetDefault(), 0, &BDSKAuthorFuzzySetCallbacks);
}

@implementation BDSKCountedSet (BibAuthor)

- (id)initFuzzyAuthorCountedSet
{
    return [self initWithKeyCallBacks:&BDSKFuzzyDictionaryKeyCallBacks];
}

@end

@implementation ABPerson (BibAuthor)

+ (ABPerson *)personWithAuthor:(BibAuthor *)author;
{
    
    ABPerson *person = [author personFromAddressBook];
    if(person == nil){    
        person = [[[ABPerson alloc] init] autorelease];
        [person setValue:[author lastName] forProperty:kABLastNameProperty];
        [person setValue:[author firstName] forProperty:kABFirstNameProperty];
    }
    return person;
}

@end