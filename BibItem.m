//  BibItem.m
//  Created by Michael McCracken on Tue Dec 18 2001.
/*
 This software is Copyright (c) 2001,2002, Michael O. McCracken
 All rights reserved.

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


#import "BibItem.h"

#define addokey(s) if([pubFields objectForKey: s] == nil){[pubFields setObject:@"" forKey: s];} [removeKeys removeObject: s];
#define addrkey(s) if([pubFields objectForKey: s] == nil){[pubFields setObject:@"" forKey: s];} [requiredFieldNames addObject: s]; [removeKeys removeObject: s];

/* Fonts and paragraph styles cached for efficiency. */
static NSDictionary* _cachedFonts = nil; // font cached across all BibItems for speed.
static NSParagraphStyle* _keyParagraphStyle = nil;
static NSParagraphStyle* _bodyParagraphStyle = nil;

// private function to get the cached Font.
void _setupFonts(){
    NSMutableParagraphStyle* defaultStyle = nil;
    if(_cachedFonts == nil){
        defaultStyle = [[NSMutableParagraphStyle alloc] init];
        [defaultStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
        _cachedFonts = [[NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont fontWithName:@"Gill Sans Bold Italic" size:14.0], @"Title",
            [NSFont fontWithName:@"Gill Sans" size:10.0], @"Type",
            [NSFont fontWithName:@"Gill Sans Bold" size:12.0], @"Key",
            [NSFont fontWithName:@"Gill Sans" size:12.0], @"Body",
            nil] retain]; // we'll never release this
        
// ?        [defaultStyle setAlignment:NSLeftTextAlignment];
        _keyParagraphStyle = [defaultStyle copy];
        [defaultStyle setHeadIndent:50];
        [defaultStyle setFirstLineHeadIndent:50];
        [defaultStyle setTailIndent:-30];
        _bodyParagraphStyle = [defaultStyle copy];
    }
}

@implementation BibItem

- (id)initWithType:(NSString *)type fileType:(NSString *)inFileType authors:(NSMutableArray *)authArray{ // this is the designated initializer.
    if (self = [super init]){
        pubFields = [[NSMutableDictionary alloc] init];
        requiredFieldNames = [[NSMutableArray alloc] init];
        pubAuthors = [authArray mutableCopy];     // copy, it's mutable
        editorObj = nil;
		undoManager = nil;
        [self setFileType:inFileType];
        [self makeType:type];
        [self setCiteKey:@"cite-key"];
        [self setDate: nil];
		[self setDateCreated: nil];
		[self setDateModified: nil];
        [self setFileOrder:-1];
        _setupFonts();
    }

    //NSLog(@"bibitem init");
    return self;
}

- (id)copyWithZone:(NSZone *)zone{
    BibItem *theCopy = [[[self class] allocWithZone: zone] initWithType:pubType
                                                               fileType:fileType
                                                                authors:[pubAuthors mutableCopy]];
    [theCopy setCiteKey: [citeKey copy]];
    [theCopy setDate: [pubDate copy]];
	
	NSCalendarDate *currentDate = [NSCalendarDate calendarDate];
	[theCopy setDateModified:currentDate];
	[theCopy setDateCreated:currentDate];
	
    [theCopy setFields: [pubFields mutableCopy]];
    [theCopy setRequiredFieldNames: [requiredFieldNames mutableCopy]];
    return theCopy;
}

- (void)makeType:(NSString *)type{
    
    NSString *fieldString;
    NSEnumerator *e;
    NSString *tmp;
    BibTypeManager *typeMan = [BibTypeManager sharedManager];
    NSMutableArray *removeKeys = [[typeMan allRemovableFieldNames] mutableCopy];
    NSEnumerator *reqFieldsE = [[typeMan requiredFieldsForType:type] objectEnumerator];
    NSEnumerator *optFieldsE = [[typeMan optionalFieldsForType:type] objectEnumerator];
    NSEnumerator *defFieldsE = [[typeMan userDefaultFieldsForType:type] objectEnumerator];

  
    while(fieldString = [reqFieldsE nextObject]){
        addrkey(fieldString)
    }
    while(fieldString = [optFieldsE nextObject]){
        addokey(fieldString)
    }
    while(fieldString = [defFieldsE nextObject]){
        addokey(fieldString)
    }    
    
    //I don't enforce Keywords, but since there's GUI depending on them, I will enforce these others:
    addokey(@"Url") addokey(@"Local-Url") addokey(@"Annote") addokey(@"Abstract") addokey(@"Rss-Description")

        // remove from removeKeys things that aren't == @"" in pubFields
        // this includes things left over from the previous bibtype - that's good.
        e = [[pubFields allKeys] objectEnumerator];

    while (tmp = [e nextObject]) {
        if (![[pubFields objectForKey:tmp] isEqualToString:@""]) {
            [removeKeys removeObject:tmp];
        }
    }
    // now remove everything that's left in remove keys from pubfields
    [pubFields removeObjectsForKeys:removeKeys];
    [removeKeys release];
    // and don't forget to set what we say our type is:
    [self setType:type];
}

//@@ type - move to type class
- (BOOL)isRequired:(NSString *)rString{
    if([requiredFieldNames indexOfObject:rString] == NSNotFound)
        return NO;
    else
        return YES;
}

- (void)dealloc{
	// NSLog([NSString stringWithFormat:@"bibitem Dealloc, rt: %d", [self retainCount]]);
    [pubFields release];
    [requiredFieldNames release];
	[pubAuthors release];

	[pubType release];
	[fileType release];
	[citeKey release];
    [pubDate release];
	[dateCreated release];
	[dateModified release];
	
    [super dealloc];
}

- (BibEditor *)editorObj{
    return editorObj; // if we haven't been given an editor object yet this should be nil.
}

- (void)setEditorObj:(BibEditor *)editor{
    editorObj = editor; // don't retain it- that will create a cycle!
}

- (NSString *)description{
    return [NSString stringWithFormat:@"%@ %@", [self citeKey], [pubFields description]];
}


- (BOOL)isEqual:(BibItem *)aBI{
    return ([pubType isEqualToString:[aBI type]]) && 
	([citeKey isEqualToString:[aBI citeKey]]) &&
	([pubFields isEqual:[aBI pubFields]]);
}

#pragma mark Comparison functions
- (NSComparisonResult)pubTypeCompare:(BibItem *)aBI{
	return [[self type] caseInsensitiveCompare:[aBI type]];
}

- (NSComparisonResult)keyCompare:(BibItem *)aBI{
    return [citeKey caseInsensitiveCompare:[aBI citeKey]];
}

- (NSComparisonResult)titleCompare:(BibItem *)aBI{
    return [[self title] caseInsensitiveCompare:[aBI title]];
}

- (NSComparisonResult)dateCompare:(BibItem *)aBI{
	return [pubDate compare:[aBI date]];
}

- (NSComparisonResult)createdDateCompare:(BibItem *)aBI{
	return [pubDate compare:[aBI date]];
}

- (NSComparisonResult)modDateCompare:(BibItem *)aBI{
	return [pubDate compare:[aBI date]];
}



- (NSComparisonResult)auth1Compare:(BibItem *)aBI{
    if([pubAuthors count] > 0){
        if([aBI numberOfAuthors] > 0){
            return [[self authorAtIndex:0] compare:
                [aBI authorAtIndex:0]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}
- (NSComparisonResult)auth2Compare:(BibItem *)aBI{
    if([pubAuthors count] > 1){
        if([aBI numberOfAuthors] > 1){
            return [[self authorAtIndex:1] compare:
                [aBI authorAtIndex:1]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}
- (NSComparisonResult)auth3Compare:(BibItem *)aBI{
    if([pubAuthors count] > 2){
        if([aBI numberOfAuthors] > 2){
            return [[self authorAtIndex:2] compare:
                [aBI authorAtIndex:2]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}

- (NSComparisonResult)fileOrderCompare:(BibItem *)aBI{
    int aBIOrd = [aBI fileOrder];
    if (_fileOrder == -1) return NSOrderedDescending; //@@ file order for crossrefs - here is where we would change to accommodate new pubs in crossrefs...
    if (_fileOrder < aBIOrd) {
        return NSOrderedAscending;
    }
    if (_fileOrder > aBIOrd){
        return NSOrderedDescending;
    }else{
        return NSOrderedSame;
    }
}

// accessors for fileorder
- (int)fileOrder{
    return _fileOrder;
}

- (void)setFileOrder:(int)ord{
    _fileOrder = ord;
}
- (NSString *)fileType { return fileType; }

- (void)setFileType:(NSString *)someFileType {
    [someFileType retain];
    [fileType release];
    fileType = someFileType;
}

#pragma mark Author Handling code

- (int)numberOfAuthors{
    return [pubAuthors count];
}

- (void)addAuthorWithName:(NSString *)newAuthorName{
    NSEnumerator *presentAuthE = nil;
    BibAuthor *bibAuthor = nil;
    BibAuthor *existingAuthor = nil;
  
    presentAuthE = [pubAuthors objectEnumerator];
    while(bibAuthor = [presentAuthE nextObject]){
        if([[bibAuthor name] isEqualToString:newAuthorName]){ // @@ TODO: fuzzy author handling
            existingAuthor = bibAuthor;
        }
    }
    if(!existingAuthor){
        existingAuthor =  [BibAuthor authorWithName:newAuthorName andPub:self]; //@@author - why was andPub:nil before?!
        [pubAuthors addObject:existingAuthor];
    }
    return;
}

- (NSArray *)pubAuthors{
    return pubAuthors;
}

- (BibAuthor *)authorAtIndex:(int)index{ 
    if ([pubAuthors count] > index)
        return [pubAuthors objectAtIndex:index];
    else
        return nil;
}

- (void)setAuthorsFromBibtexString:(NSString *)aString{
    char *str = nil;

    if (aString == nil) return;

    if(![aString canBeConvertedToEncoding:[NSString defaultCStringEncoding]]){
	NSLog(@"An author name could not be displayed losslessly.");
	NSLog(@"Using lossy encoding for %@", aString);
	str = (char *)[aString lossyCString];
    } else  str = (char *)[aString cString];
    
//    [aString getCString:str]; // str will be autoreleased. (freed?)
    bt_stringlist *sl = nil;
    int i=0;
#warning - Exception - might want to add an exception handler that notifies the user of the warning...
    [pubAuthors removeAllObjects];
    sl = bt_split_list(str, "and", "BibTex Name", 1, "inside setAuthorsFromBibtexString");
    if (sl != nil) {
        for(i=0; i < sl->num_items; i++){
            if(sl->items[i] != nil){
				NSString *s = [NSString stringWithCString: sl->items[i]];
                [self addAuthorWithName:s];
                
            }
        }
       // bt_free_list(sl); // hey! got to free the memory!
    }
    //    NSLog(@"%@", pubAuthors);
}

- (NSString *)bibtexAuthorString{
    NSEnumerator *en = [pubAuthors objectEnumerator];
    NSString *rs;
    BibAuthor *author;
    if([pubAuthors count] == 0) return @"";
    if([pubAuthors count] == 1){
        author = [pubAuthors objectAtIndex:0];
        return [author name];
    }else{
        author = [en nextObject];
        rs = [[NSString alloc] initWithString:[author name]];
        // since this method is used for display, BibAuthor -name is right above.
        
        while(author = [en nextObject]){
            rs = [rs stringByAppendingString:@" and "];
            rs = [rs stringByAppendingString:[author name]];
        }
        return rs;
    }
        
}

- (NSString *)title{
  NSString *t = [pubFields objectForKey: @"Title"];
  if(t == nil)
    return @"Empty Title";
  else
    return t;
}

- (void)setTitle:(NSString *)title{
  [self setField:@"Title" toValue:title];
}

- (void)setDate: (NSCalendarDate *)newDate{
    [pubDate autorelease];
    pubDate = [newDate copy];
    
}
- (NSCalendarDate *)date{
    return pubDate;
}

- (NSCalendarDate *)dateCreated {
    return [[dateCreated retain] autorelease];
}

- (void)setDateCreated:(NSCalendarDate *)newDateCreated {
    if (dateCreated != newDateCreated) {
        [dateCreated release];
        dateCreated = [newDateCreated copy];
    }
}

- (NSCalendarDate *)dateModified {
    return [[dateModified retain] autorelease];
}

- (void)setDateModified:(NSCalendarDate *)newDateModified {
    if (dateModified != newDateModified) {
        [dateModified release];
        dateModified = [newDateModified copy];
    }
}

- (void)setType: (NSString *)newType{
    [pubType autorelease];
    pubType = [newType retain];
}
- (NSString *)type{
    return pubType;
}

- (void)setCiteKeyFormat: (NSString *)newKeyFormat{
    // in the future, this will allow us to set how we want the citeKey computed
}

- (NSString *)sanitizedCiteKeyString:(NSString *)key{
    // only call this for keys that we generate internally, as it uses a restrictive character set
	NSCharacterSet *invalidSet = [[BibTypeManager sharedManager] sanitizedCiteKeyCharSet];
		
	NSString *newCiteKey = [key stringByReplacingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
												   withString:@"-"];
	newCiteKey = [newCiteKey stringByReplacingCharactersInSet:invalidSet withString:@""];
	
	return newCiteKey;
}

- (NSString *)suggestedCiteKey{
	NSString *authString = @"";
    NSString *yearString = @"";
    NSString *titleString = @"";
	
	if([self numberOfAuthors] > 0){
		authString = [[self authorAtIndex:0] lastName];
		if(!authString) 
			authString = @"";
	}
	if([self date]){
		yearString = [[self date] descriptionWithCalendarFormat:@"%y"];
	}
	if([self title]){
		titleString = [self title];
	}
	NSString *cs = [NSString stringWithFormat:@"%@%@%@", authString, yearString, titleString];
	cs = [self sanitizedCiteKeyString:cs];
	if([cs isEqualToString:@""]){
		return @"empty";
	}else{
	   return cs;
	}
}

- (void)setCiteKey:(NSString *)newCiteKey{
    if(editorObj){
        // NSLog(@"setCiteKey called with a valid editor");
        if(!undoManager){
            undoManager = [[editorObj window] undoManager];
        }

        [[undoManager prepareWithInvocationTarget:self] setCiteKey:citeKey];
        [undoManager setActionName:NSLocalizedString(@"Change Cite Key",@"")];
    }
	
    [citeKey autorelease];
		
    if([newCiteKey isEqualToString:@""]){
        citeKey = [[self suggestedCiteKey] retain];
    } else {
        citeKey = [newCiteKey retain];
    }
		
    NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:citeKey, @"value", @"Cite Key", @"key",nil];
    NSNotification *aNotification = [NSNotification notificationWithName:BDSKBibItemChangedNotification
                                                                  object:self
                                                                userInfo:notifInfo];
    // Queue the notification, since this can be expensive when opening large files
    [[NSNotificationQueue defaultQueue] enqueueNotification:aNotification
                                               postingStyle:NSPostWhenIdle
                                               coalesceMask:NSNotificationCoalescingOnSender
                                                   forModes:nil];
}

- (NSString *)citeKey{
    if(!citeKey || [@"" isEqualToString:citeKey]){
		// NSLog(@"setting suggested to %@",[self suggestedCiteKey]);
        [self setCiteKey:[self suggestedCiteKey]]; 
    }
    return citeKey;
}

- (void)setFields: (NSDictionary *)newFields{
	if(newFields != pubFields){
		[pubFields release];
		pubFields = [newFields mutableCopy];
		[self updateMetadataForKey:nil];
    }
}

- (void)updateMetadataForKey:(NSString *)key{
    NSMutableString *tmp = [NSMutableString string];
	
	if([key isEqualToString:@"Annote"] || 
	   [key isEqualToString:@"Abstract"] || 
	   [key isEqualToString:@"Rss-Description"]){
		// don't do anything for fields we don't need to update.
		return;
	}

    if((![@"" isEqualToString:[pubFields objectForKey: @"Author"]]) && 
	   ([pubFields objectForKey: @"Author"] != nil))
    {
        [self setAuthorsFromBibtexString:[pubFields objectForKey: @"Author"]];
    }else{
        [self setAuthorsFromBibtexString:[pubFields objectForKey: @"Editor"]]; // or what else?
    }

    // re-call make type to make sure we still have all the appropriate bibtex defined fields...
	//@@ 3/5/2004: moved why is this here? 
	[self makeType:[self type]];

	NSString *yearValue = [pubFields objectForKey:@"Year"];
    if (yearValue && ![yearValue isEqualToString:@""]) {
		
		NSString *monthValue = [pubFields objectForKey:@"Month"];
        if (monthValue && ![monthValue isEqualToString:@""]) {
			
            [tmp appendString:monthValue];
            [tmp appendString:@" "];
    	}
        [tmp appendString:[pubFields objectForKey:@"Year"]];
        [self setDate:[NSCalendarDate dateWithNaturalLanguageString:tmp]];
    }else{
        [self setDate:nil];    // nil means we don't have a good date.
    }
	
	NSString *dateCreatedValue = [pubFields objectForKey:BDSKDateCreatedString];
    if (dateCreatedValue && ![dateCreatedValue isEqualToString:@""]) {
		[self setDateCreated:[NSCalendarDate dateWithNaturalLanguageString:dateCreatedValue]];
	}
	
	NSString *dateModValue = [pubFields objectForKey:BDSKDateModifiedString];
    if (dateModValue && ![dateModValue isEqualToString:@""]) {
		// NSLog(@"updating date %@", dateModValue);
		[self setDateModified:[NSCalendarDate dateWithNaturalLanguageString:dateModValue]];
	}
	
}

- (void)setRequiredFieldNames: (NSMutableArray *)newRequiredFieldNames{
    [requiredFieldNames autorelease];
    requiredFieldNames = [newRequiredFieldNames mutableCopy];
}

- (void)setField: (NSString *)key toValue: (NSString *)value{
	[self setField:key toValue:value withModDate:[NSCalendarDate date]];
}

- (void)setField:(NSString *)key toValue:(NSString *)value withModDate:(NSCalendarDate *)date{
	if(!undoManager){
		undoManager = [[editorObj window] undoManager];
	}

	id oldValue = [pubFields objectForKey:key];
	NSCalendarDate *oldModDate = [self dateModified];
	
	[[undoManager prepareWithInvocationTarget:self] setField:key 
													 toValue:oldValue
													  withModDate:oldModDate];
	[undoManager setActionName:NSLocalizedString(@"Edit publication",@"")];

	
    [pubFields setObject: value forKey: key];
	NSString *dateString = [date description];
	[pubFields setObject:dateString forKey:BDSKDateModifiedString];
	[self updateMetadataForKey:key];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:value, @"value", key, @"key", @"Change", @"type",nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];
    // to allow autocomplete:
	[[NSApp delegate] addString:value forCompletionEntry:key];
}

// for 10.2
- (id)handleQueryWithUnboundKey:(NSString *)key{
    return [self valueForUndefinedKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key{
    id obj = [pubFields objectForKey:key];
    if (obj != nil){
        return obj;
    }else{
        // handle 10.2
        if ([super respondsToSelector:@selector(valueForUndefinedKey:)]){
            return [super valueForUndefinedKey:key];
        }else{
            return [super handleQueryWithUnboundKey:key];
        }
    }
}

- (NSString *)valueOfField: (NSString *)key{
    NSString* value = [pubFields objectForKey:key];
	return [[value retain] autorelease];
}

- (void)addField:(NSString *)key{
	[self addField:key withModDate:[NSCalendarDate date]];
}

- (void)addField:(NSString *)key withModDate:(NSCalendarDate *)date{
	if(!undoManager){
		undoManager = [[editorObj window] undoManager];
	}
	
	[[undoManager prepareWithInvocationTarget:self] removeField:key
													withModDate:[self dateModified]];
	[undoManager setActionName:NSLocalizedString(@"Add Field",@"")];
	
	NSString *msg = [NSString stringWithFormat:@"%@ %@",
		NSLocalizedString(@"Add data for field:", @""), key];
	[pubFields setObject:msg forKey:key];
	
	NSString *dateString = [date description];
	[pubFields setObject:dateString forKey:BDSKDateModifiedString];
	[self updateMetadataForKey:key];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add/Del Field", @"type",nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];

}

- (void)removeField: (NSString *)key{
	[self removeField:key withModDate:[NSCalendarDate date]];
}

- (void)removeField: (NSString *)key withModDate:(NSCalendarDate *)date{
	
	if(!undoManager){
		undoManager = [[editorObj window] undoManager];
	}

	[[undoManager prepareWithInvocationTarget:self] addField:key
												 withModDate:[self dateModified]];
	[undoManager setActionName:NSLocalizedString(@"Remove Field",@"")];

    [pubFields removeObjectForKey:key];
	
	NSString *dateString = [date description];
	[pubFields setObject:dateString forKey:BDSKDateModifiedString];
	[self updateMetadataForKey:key];

	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add/Del Field", @"type",nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];
	
}

- (NSMutableDictionary *)pubFields{
    return [[pubFields retain] autorelease];
}

- (NSData *)PDFValue{
    // Obtain the PDF of a bibtex formatted version of the bibtex entry as is.
    //* we won't be doing this on a per-item basis. this is deprecated. */
    return [[self title] dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:YES];
}

- (NSData *)RTFValue{
    NSString *key;
    NSEnumerator *e = [[[pubFields allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];

    NSDictionary *titleAttributes =
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_cachedFonts objectForKey:@"Title"], _keyParagraphStyle, nil]
                                    forKeys:[NSArray arrayWithObjects:NSFontAttributeName,  NSParagraphStyleAttributeName, nil]];

    NSDictionary *typeAttributes =
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_cachedFonts objectForKey:@"Type"], [NSColor colorWithCalibratedWhite:0.4 alpha:0.0], nil]
                                    forKeys:[NSArray arrayWithObjects:NSFontAttributeName, NSForegroundColorAttributeName, nil]];

    NSDictionary *keyAttributes =
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_cachedFonts objectForKey:@"Key"], _keyParagraphStyle, nil]
                                    forKeys:[NSArray arrayWithObjects:NSFontAttributeName, NSParagraphStyleAttributeName, nil]];

    NSDictionary *bodyAttributes =
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_cachedFonts objectForKey:@"Body"],
          /*  [NSColor colorWithCalibratedWhite:0.9 alpha:0.0], */
            _bodyParagraphStyle, nil]
                                    forKeys:[NSArray arrayWithObjects:NSFontAttributeName, /*NSBackgroundColorAttributeName, */NSParagraphStyleAttributeName, nil]];

    NSMutableAttributedString* aStr = [[NSMutableAttributedString alloc] init];

    NSMutableArray *nonReqKeys = [NSMutableArray arrayWithCapacity:5]; // yep, arbitrary


    [aStr appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:
                      [NSString stringWithFormat:@"%@\n",[self citeKey]] attributes:typeAttributes] autorelease]];
    [aStr appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:
                     [NSString stringWithFormat:@"%@ ",[self title]] attributes:titleAttributes] autorelease]];

    
    [aStr appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:
                       [NSString stringWithFormat:@"(%@)\n",[self type]] attributes:typeAttributes] autorelease]];

    

    while(key = [e nextObject]){
        if(![[pubFields objectForKey:key] isEqualToString:@""] &&
           ![key isEqualToString:@"Title"]){
            if([self isRequired:key]){
                [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",key]
                                                                              attributes:keyAttributes] autorelease]];

                [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",[pubFields objectForKey:key]]
                                                                              attributes:bodyAttributes] autorelease]];
            }else{
                [nonReqKeys addObject:key];
            }
        }
    }// end required keys
    
    e = [nonReqKeys objectEnumerator];
    while(key = [e nextObject]){
        if(![[pubFields objectForKey:key] isEqualToString:@""]){
            [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",key]
                                                                          attributes:keyAttributes] autorelease]];

            [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",[pubFields objectForKey:key]]
                                                                          attributes:bodyAttributes] autorelease]];

        }
    }

    [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:@" "
                                                                  attributes:nil] autorelease]];


    return 	[aStr RTFFromRange:NSMakeRange(0,[aStr length]) documentAttributes:nil];
}

- (NSString *)bibTeXString{
    NSString *k;
    NSString *v;
    NSMutableString *s = [[[NSMutableString alloc] init] autorelease];
    NSArray *keys = [[pubFields allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSEnumerator *e = [keys objectEnumerator];

    //build BibTeX entry:
    [s appendString:@"@"];
    [s appendString:pubType];
    [s appendString:@"{"];
    [s appendString:[self citeKey]];
    while(k = [e nextObject]){
        // Get TeX version of each field.
	// Don't run the converter on Local-Url or Url fields, so we don't trash ~ and % escapes.
	// Note that NSURLs comply with RFC 2396, and can't contain high-bit characters anyway.
	if([k isEqualToString:@"Local-Url"] || [k isEqualToString:@"Url"]){
	    v = [pubFields objectForKey:k];
	} else {
	    v = [[BDSKConverter sharedConverter] stringByTeXifyingString:[pubFields objectForKey:k]];
	}
	
        if(![v isEqualToString:@""]){
            [s appendString:@",\n\t"];
            [s appendFormat:@"%@ = {%@}",k,v];
        }
    }
    [s appendString:@"}"];
    return s;
}

- (NSString *)RSSValue{
    NSMutableString *s = [[[NSMutableString alloc] init] autorelease];

    NSString *descField = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKRSSDescriptionFieldKey];

    [s appendString:@"<item>\n"];
    [s appendString:@"<description>\n"];
    if([self valueOfField:descField]){
        [s appendString:[[self valueOfField:descField] xmlString]];
    }
    [s appendString:@"</description>\n"];
    [s appendString:@"<link>"];
    [s appendString:[self valueOfField:@"Url"]];
    [s appendString:@"</link>\n"];
    //[s appendString:@"<bt:source><![CDATA[\n"];
    //    [s appendString:[[self bibTeXString] xmlString]];
    //    [s appendString:@"]]></bt:source>\n"];
    [s appendString:@"</item>\n"];
    return s;
}

- (NSString *)HTMLValueUsingTemplateString:(NSString *)templateString{
    return [templateString stringByParsingTagsWithStartDelimeter:@"<$" endDelimeter:@"/>" usingObject:self];
}

- (NSString *)allFieldsString{
    NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
    NSEnumerator *pubFieldsE = [pubFields objectEnumerator];
    NSString *field = nil;
    
	[result appendString:[self citeKey]];
		
    while(field = [pubFieldsE nextObject]){
        [result appendFormat:@" %@ ", field];
    }
    return [[result copy] autorelease];
}

- (NSString *)localURLPathRelativeTo:(NSString *)base{
    NSURL *local = nil;
    NSString *lurl = [self valueOfField:@"Local-Url"];

    if (!lurl || [lurl isEqualToString:@""]) return nil;

    if(base &&
       ![lurl containsString:@"file://"] &&
       ![[lurl substringWithRange:NSMakeRange(0,1)] isEqualToString:@"/"] &&
       ![[lurl substringWithRange:NSMakeRange(0,1)] isEqualToString:@"~"]){
        lurl = [base stringByAppendingPathComponent:lurl];
    }

    
    if(![@"" isEqualToString:lurl]){
        local = [NSURL URLWithString:lurl];
        return [[local path] stringByExpandingTildeInPath];
    }else{
        local = nil;
        return lurl;
    }

}
@end
