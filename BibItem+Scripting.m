//
//  BibItemClassDescription.m
//  BibDesk
//
//  Created by Sven-S. Porst on Sat Jul 10 2004.
/*
 This software is Copyright (c) 2004-2008
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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
#import "BibItem+Scripting.h"
#import "BibAuthor.h"
#import "BDSKStringConstants.h"
#import "BibDocument.h"
#import "BDSKBibTeXParser.h"
#import "BDSKPublicationsArray.h"
#import "BDSKLinkedFile.h"
#import "NSURL_BDSKExtensions.h"

/* ssp
A Category on BibItem with a few additional methods to enable and enhance its scriptability beyond what comes for free with key value coding.
*/
@implementation BibItem (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

/* 
 ssp 2004-07-10
 Returns a path to the BibItem for Apple Script
 Needs a properly working -document method to work with multpiple documents.
*/
- (NSScriptObjectSpecifier *) objectSpecifier {
    // only items belonging to a BibDocument are scriptable
    BibDocument *myDoc = (BibDocument *)[self owner];
	NSArray * ar = [myDoc publications];
	unsigned idx = [ar indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [myDoc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"publications" index:idx] autorelease];
    } else {
        return nil;
    }
}


/* cmh:
 Access to arbitrary fields through 'proxy' objects BDSKField. 
 These are simply wrappers for the accessors in BibItem. 
*/
- (BDSKField *)valueInBibFieldsWithName:(NSString *)name
{
	return [[[BDSKField alloc] initWithName:[name fieldName] bibItem:self] autorelease];
}

- (NSArray *)bibFields
{
	NSEnumerator *fEnum = [pubFields keyEnumerator];
	NSString *name = nil;
	BDSKField *field = nil;
	NSMutableArray *bibFields = [NSMutableArray arrayWithCapacity:5];
	
	while (name = [fEnum nextObject]) {
		field = [[BDSKField alloc] initWithName:[name fieldName] bibItem:self];
		[bibFields addObject:field];
		[field release];
	}
	return bibFields;
}

- (unsigned int)countOfAsAuthors {
	return [[self pubAuthors] count];
}

- (BibAuthor *)objectInAsAuthorsAtIndex:(unsigned int)idx {
	return [[self pubAuthors] objectAtIndex:idx];
}

- (BibAuthor *)valueInAsAuthorsAtIndex:(unsigned int)idx {
    return [self objectInAsAuthorsAtIndex:idx];
}

- (BibAuthor *)valueInAsAuthorsWithName:(NSString *)name {
    // create a new author so we can use BibAuthor's isEqual: method for comparison
    // instead of trying to do string comparisons
    BibAuthor *newAuth = [BibAuthor authorWithName:name andPub:nil];
	NSEnumerator *authEnum = [[self pubAuthors] objectEnumerator];
	BibAuthor *auth;
	
	while (auth = [authEnum nextObject]) {
		if ([auth isEqual:newAuth]) {
			return auth;
		}
	}
	return nil;
}

- (unsigned int)countOfAsEditors {
	return [[self pubEditors] count];
}

- (BibAuthor *)objectInAsEditorsAtIndex:(unsigned int)idx {
	return [[self pubEditors] objectAtIndex:idx];
}

- (BibAuthor *)valueInAsEditorsAtIndex:(unsigned int)idx {
    return [self objectInAsEditorsAtIndex:idx];
}

- (BibAuthor *)valueInAsEditorsWithName:(NSString *)name {
    // create a new author so we can use BibAuthor's isEqual: method for comparison
    // instead of trying to do string comparisons
    BibAuthor *newAuth = [BibAuthor authorWithName:name andPub:nil];
	NSEnumerator *authEnum = [[self pubEditors] objectEnumerator];
	BibAuthor *auth;
	
	while (auth = [authEnum nextObject]) {
		if ([auth isEqual:newAuth]) {
			return auth;
		}
	}
	return nil;
}

- (NSArray *)linkedFiles {
    return [[self localFiles] valueForKey:@"URL"];
}

- (void)insertInLinkedFiles:(NSURL *)newURL atIndex:(unsigned int)idx {
    if ([[self owner] isDocument]) {
        BDSKLinkedFile *file = [[[BDSKLinkedFile alloc] initWithURL:newURL delegate:self] autorelease];
        if (file) {
            NSArray *localFiles = [self localFiles];
            if (idx > 0) {
                idx = [files indexOfObject:[localFiles objectAtIndex:idx - 1]];
                if (idx == NSNotFound)
                    idx = 0;
                else
                    idx++;
            }
            [self insertObject:file inFilesAtIndex:idx];
        }
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (void)insertInLinkedFiles:(NSURL *)newURL {
    [self insertInLinkedFiles:newURL atIndex:[[self localFiles] count]];
}

- (void)removeFromLinkedFilesAtIndex:(unsigned int)idx {
    [[self mutableArrayValueForKey:@"files"] removeObject:[[self localFiles] objectAtIndex:idx]];
}

- (NSArray *)linkedURLs {
    return [[self remoteURLs] valueForKeyPath:@"URL.absoluteString"];
}

- (void)insertInLinkedURLs:(NSString *)newURLString atIndex:(unsigned int)idx {
    if ([[self owner] isDocument]) {
        NSURL *newURL = [NSURL URLWithStringByNormalizingPercentEscapes:newURLString];
        BDSKLinkedFile *file = [[[BDSKLinkedFile alloc] initWithURL:newURL delegate:self] autorelease];
        if (file) {
            NSArray *remoteURLs = [self remoteURLs];
            if (idx < [remoteURLs count]) {
                idx = [files indexOfObject:[remoteURLs objectAtIndex:idx]];
                if (idx == NSNotFound)
                    idx = [self countOfFiles];
            } else {
                idx = [self countOfFiles];
            }
            [self insertObject:file inFilesAtIndex:idx];
        }
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (void)insertInLinkedURLs:(NSString *)newURLString {
    [self insertInLinkedURLs:newURLString atIndex:[[self remoteURLs] count]];
}

- (void)removeFromLinkedURLsAtIndex:(unsigned int)idx {
    [[self mutableArrayValueForKey:@"files"] removeObject:[[self remoteURLs] objectAtIndex:idx]];
}

- (id)asDocument {
    return [owner isDocument] ? (id)owner : (id)[NSNull null];
}

- (NSString *)asType {
	return [self pubType];
}

- (void)setAsType:(NSString *)newType {
    if ([[self owner] isDocument]) {
        [self setPubType:(NSString *)newType];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString *)asCiteKey {
	return [self citeKey];
}

- (void)setAsCiteKey:(NSString *)newKey {
    if ([[self owner] isDocument]) {
        [self setCiteKey:(NSString *)newKey];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*)asTitle {
	return [self valueOfField:BDSKTitleString];
}

- (void)setAsTitle:(NSString*)newTitle {
    if ([[self owner] isDocument]) {
        [self setField:BDSKTitleString toValue:newTitle];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString *) month {
	NSString *month = [self valueOfField:BDSKMonthString];
	return month ? month : @"";
}

- (void) setMonth:(NSString*) newMonth {
    if ([[self owner] isDocument]) {
        [self setField:BDSKMonthString toValue:newMonth];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString *) year {
	NSString *year = [self valueOfField:BDSKYearString];
	return year ? year : @"";
}

- (void) setYear:(NSString*) newYear {
    if ([[self owner] isDocument]) {
        [self setField:BDSKYearString toValue:newYear];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}


- (NSDate*)asDateAdded {
	NSDate * d = [self dateAdded];
	
	if (!d) return [NSDate dateWithTimeIntervalSince1970:0];
	else return d;
}

- (NSDate*)asDateModified {
	NSDate * d = [self dateModified];
	
	if (!d) return [NSDate dateWithTimeIntervalSince1970:0];
	else return d;
}





/*
 ssp: 2004-07-11
 Extra key-value-style accessor methods for the local and distant URLs, abstract and notes
 These might be particularly useful for scripting, so having them right in the scripting dictionary rather than hidden in the 'fields' record should be useful.
 I assume the same could be achieved more easily using -valueForUndefinedKey:, but that's X.3 and up 
 I am using generic NSStrings here. NSURLs and NSFileHandles might be nicer but as things are handled as strings both in the BibDesk backend and in AppleScript there wouldn't be much point to it.
 Any policies on whether to rather return copies of the strings in question here?
*/
- (NSString*) remoteURLString {
    NSArray *linkedURLs = [self linkedURLs];
    return [linkedURLs count] ? [linkedURLs objectAtIndex:0] : @"";
}

- (void) setRemoteURLString:(NSString*) newURLString{
    if ([[self owner] isDocument]) {
        BDSKLinkedFile *file = [[[BDSKLinkedFile alloc] initWithURLString:newURLString] autorelease];
        if (file == nil)
            return;
        NSArray *remoteURLs = [self remoteURLs];
        unsigned int idx = [self countOfFiles];
        if ([remoteURLs count]) {
            idx = [files indexOfObject:[remoteURLs objectAtIndex:0]];
            if (idx == NSNotFound)
                idx = [self countOfFiles];
            else
                [self removeObjectFromFilesAtIndex:idx];
        }
        [self insertObject:file inFilesAtIndex:idx];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*) localURLString {
    NSArray *linkedFiles = [self linkedFiles];
    return [linkedFiles count] ? [[linkedFiles objectAtIndex:0] path] : @"";
}

- (void) setLocalURLString:(NSString*) newPath {
    if ([[self owner] isDocument]) {
        NSURL *newURL = [newPath hasPrefix:@"file://"] ? [NSURL URLWithString:newPath] : [NSURL fileURLWithPath:[newPath stringByExpandingTildeInPath]];
        if (newURL == nil)
            return;
        BDSKLinkedFile *file = [[[BDSKLinkedFile alloc] initWithURL:newURL delegate:self] autorelease];
        if (file == nil)
            return;
        NSArray *localFiles = [self localFiles];
        unsigned int idx = 0;
        if ([localFiles count]) {
            idx = [files indexOfObject:[localFiles objectAtIndex:0]];
            if (idx == NSNotFound)
                idx = 0;
            else
                [self removeObjectFromFilesAtIndex:idx];
        }
        [self insertObject:file inFilesAtIndex:idx];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*) abstract {
	return [self valueOfField:BDSKAbstractString inherit:NO];
}

- (void) setAbstract:(NSString*) newAbstract {
    if ([[self owner] isDocument]) {
        [self setField:BDSKAbstractString toValue:newAbstract];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*) annotation {
	return [self valueOfField:BDSKAnnoteString inherit:NO];
}

- (void) setAnnotation:(NSString*) newAnnotation {
    if ([[self owner] isDocument]) {
        [self setField:BDSKAnnoteString toValue:newAnnotation];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*)rssDescription {
	return [self valueOfField:BDSKRssDescriptionString];
}

- (void) setRssDescription:(NSString*) newDesc {
    if ([[self owner] isDocument]) {
        [self setField:BDSKRssDescriptionString toValue:newDesc];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*)rssString {
	NSString *value = [self RSSValue];
	return value ? value : @"";
}

- (NSString*)risString {
	NSString *value = [self RISStringValue];
	return value ? value : @"";
}

- (NSTextStorage *)styledTextValue {
	return [[[NSTextStorage alloc] initWithAttributedString:[self attributedStringValue]] autorelease];
}

- (NSString *)keywords{
    NSString *keywords = [self valueOfField:BDSKKeywordsString];
	return keywords ? keywords : @"";
}

- (void)setKeywords:(NSString *)keywords{
    if ([[self owner] isDocument]) {
        [self setField:BDSKKeywordsString toValue:keywords];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (int)asRating{
    return [self rating];
}

- (void)setAsRating:(int)rating{
    if ([[self owner] isDocument]) {
        [self setRating:rating];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

/*
 ssp: 2004-07-11
 Make the bibTeXString settable.
 The only way I could figure out how to initialise a new record with a BibTeX string.
 This may be a bit of a hack for a few reasons: (a) there seems to be no good way to initialise a BibItem from a BibString when it already exists and (b) I suspect this isn't the way you're supposed to do AS.
*/
- (void) setBibTeXString:(NSString*) btString {
	NSScriptCommand * cmd = [NSScriptCommand currentCommand];

	// we do not allow setting the bibtex string after an edit, only at initialization
    if ([[self owner] isDocument] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
	} else if([self hasBeenEdited]){
		if (cmd) {
			[cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
			[cmd setScriptErrorString:NSLocalizedString(@"Cannot set BibTeX string after initialization.",@"Error description")];
		}
		return;
	}

    NSError *error = nil;
    BOOL isPartialData;
    NSArray *newPubs = [BDSKBibTeXParser itemsFromString:btString document:[self owner] isPartialData:&isPartialData error:&error];
	
	// try to do some error handling for AppleScript
	if(isPartialData) {
		if (cmd) {
			[cmd setScriptErrorNumber:NSInternalScriptError];
			[cmd setScriptErrorString:[NSString stringWithFormat:NSLocalizedString(@"BibDesk failed to process the BibTeX entry %@ with error %@. It may be malformed.",@"Error description"), btString, [error localizedDescription]]];
		}
		return;
	}
		
	// otherwise use the information of the first publication found in the string.
	BibItem * newPub = [newPubs objectAtIndex:0];
	
	// a parsed pub has no creation date set, so we need to copy first
	NSString *createdDate = [self valueOfField:BDSKDateAddedString inherit:NO];
	if (![NSString isEmptyString:createdDate])
		[newPub setField:BDSKDateAddedString toValue:createdDate];
	
	// ... and replace the current record with it.
	// hopefully, I don't understand the whole filetypes/pubtypes stuff	
	[self setPubType:[newPub pubType]];
	[self setFileType:[newPub fileType]];
	[self setCiteKey:[newPub citeKey]];
	[self setFields:[newPub pubFields]];
	
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
	// NSLog([newPub description]);
}

/*
 ssp: 2004-07-10
 Return attribute keys corresponding to the fields present in the current BibItem
 DOESNT SEEM TO WORK

- (NSArray *)attributeKeys {
	NSLog(@"BibItem attributeKeys");
	NSMutableArray * ar = [NSMutableArray arrayWithObjects:BibItemBasicObjects, nil];
	NSDictionary * f = [self fields];
	NSEnumerator * keyEnum = [f keyEnumerator];
	NSString * key;
	NSString * value;
	
	while (key = [keyEnum nextObject]) {
		value = [f objectForKey:key];
		if (![value isEqualTo:@""]) {
			[ar addObject:key];
		}
	}
	return ar;
}
*/

/*
 ssp: 2004-07-10
 This catches all the keys that aren't implemented, i.e. those we advertise in -attributeKeys but which actually come from the fields record.
 Not sure about the exception stuff. 
 Apparently this is X.3 and up only.

- (id)valueForUndefinedKey:(NSString *)key {
	NSString * s = (NSString*) [self valueOfField:key];
	if (!s) {
		[NSException raise:NSUndefinedKeyException format:@""];
	}		
	return s;
}
*/

@end
