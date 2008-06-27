//
//  BibAuthorScripting.m
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
#import "BibAuthor+Scripting.h"
#import "BDSKPublicationsArray.h"
#import "BDSKOwnerProtocol.h"
#import "NSObject_BDSKExtensions.h"

@implementation BibAuthor (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

+ (NSArray *)authorsInPublications:(NSArray *)publications {
	NSMutableSet *auths = [NSMutableSet set];
    [auths performSelector:@selector(addObjectsFromArray:) withObjectsByMakingObjectsFromArray:publications performSelector:@selector(pubAuthors)];
	return [auths allObjects];
}

+ (BibAuthor *)authorWithName:(NSString *)aName inPublications:(NSArray *)publications {
    // create a new author so we can use BibAuthor's isEqual: method for comparison
    // instead of trying to do string comparisons
    BibAuthor *newAuth = [BibAuthor authorWithName:aName andPub:nil];
    
	NSEnumerator *pubEnum = [publications objectEnumerator];
	NSEnumerator *authEnum;
	BibItem *pub;
	BibAuthor *auth;
	BibAuthor *author = nil;

	while (author == nil && (pub = [pubEnum nextObject])) {
		authEnum = [[pub pubAuthors] objectEnumerator];
		while (auth = [authEnum nextObject]) {
			if ([auth isEqual:newAuth]) {
				author = auth;
                break;
            }
		}
	}
    
	return author;
}

+ (NSArray *)editorsInPublications:(NSArray *)publications {
	NSMutableSet *auths = [NSMutableSet set];
    [auths performSelector:@selector(addObjectsFromArray:) withObjectsByMakingObjectsFromArray:publications performSelector:@selector(pubEditors)];
	return [auths allObjects];
}

+ (BibAuthor *)editorWithName:(NSString *)aName inPublications:(NSArray *)publications {
    // create a new author so we can use BibAuthor's isEqual: method for comparison
    // instead of trying to do string comparisons
    BibAuthor *newAuth = [BibAuthor authorWithName:aName andPub:nil];
    
	NSEnumerator *pubEnum = [publications objectEnumerator];
	NSEnumerator *authEnum;
	BibItem *pub;
	BibAuthor *auth;
    BibAuthor *editor = nil;

	while (editor == nil && (pub = [pubEnum nextObject])) {
		authEnum = [[pub pubEditors] objectEnumerator];
		while (auth = [authEnum nextObject]) {
			if ([auth isEqual:newAuth]) {
				editor = auth;
                break;
            }
		}
	}
    
	return editor;
}

- (NSScriptObjectSpecifier *) objectSpecifier {
	NSScriptObjectSpecifier *containerRef = [[self publication] objectSpecifier];
    NSString *key = [field isEqualToString:BDSKEditorString] ? @"scriptingEditors" : @"scriptingAuthors";
		
	return [[[NSNameSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:key name:[self normalizedName]] autorelease];
}

- (NSArray *)scriptingPublications {
	id owner = [[self publication] owner];
	if (owner) {
        if ([field isEqualToString:BDSKEditorString])
            return [[owner publications] itemsForEditor:self];
        else
            return [[owner publications] itemsForAuthor:self];
	}
    return [NSArray array];
}

- (BOOL)isExternal {
    return [[[self publication] owner] isDocument] == NO;
}

@end
