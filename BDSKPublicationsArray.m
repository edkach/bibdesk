//
//  BDSKPublicationsArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/25/06.
/*
 This software is Copyright (c) 2006,2007
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKPublicationsArray.h"
#import "BDSKCountedSet.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import <OmniFoundation/OFMultiValueDictionary.h>
#import <OmniFoundation/NSString-OFExtensions.h>
#import "NSObject_BDSKExtensions.h"


@interface BDSKPublicationsArray (Private)
- (void)addToItemsForCiteKeys:(BibItem *)item;
- (void)removeFromItemsForCiteKeys:(BibItem *)item;
- (void)updateFileOrder;
@end


@implementation BDSKPublicationsArray

#pragma mark Init, dealloc overrides

- (id)init;
{
    if (self = [super init]) {
        NSZone *zone = [self zone];
        publications = [[NSMutableArray allocWithZone:zone] init];
        itemsForCiteKeys = [[OFMultiValueDictionary allocWithZone:zone] initWithKeyCallBacks:&BDSKCaseInsensitiveStringKeyDictionaryCallBacks];
        itemsForIdentifierURLs = [[NSMutableDictionary allocWithZone:zone] init];
    }
    return self;
}

// this is called from initWithArray:
- (id)initWithObjects:(id *)objects count:(unsigned)count;
{
    if (self = [super init]) {
        NSZone *zone = [self zone];
        publications = [[NSMutableArray allocWithZone:zone] initWithObjects:objects count:count];
        itemsForCiteKeys = [[OFMultiValueDictionary allocWithZone:zone] initWithKeyCallBacks:&BDSKCaseInsensitiveStringKeyDictionaryCallBacks];
        itemsForIdentifierURLs = [[NSMutableDictionary allocWithZone:zone] init];
        [self performSelector:@selector(addToItemsForCiteKeys:) withObjectsFromArray:publications];
        [self updateFileOrder];
    }
    return self;
}

- (id)initWithCapacity:(unsigned)numItems;
{
    if (self = [super init]) {
        NSZone *zone = [self zone];
        publications = [[NSMutableArray allocWithZone:zone] initWithCapacity:numItems];
        itemsForCiteKeys = [[OFMultiValueDictionary allocWithZone:zone] initWithKeyCallBacks:&BDSKCaseInsensitiveStringKeyDictionaryCallBacks];
        itemsForIdentifierURLs = [[NSMutableDictionary allocWithZone:zone] initWithCapacity:numItems];
    }
    return self;
}

- (void)dealloc{
    [publications release];
    [itemsForCiteKeys release];
    [itemsForIdentifierURLs release];
    [super dealloc];
}

#pragma mark NSMutableArray primitive methods

- (unsigned)count;
{
    return [publications count];
}

- (id)objectAtIndex:(unsigned)idx;
{
    return [publications objectAtIndex:idx];
}

- (void)addObject:(id)anObject;
{
    [publications addObject:anObject];
    [self addToItemsForCiteKeys:anObject];
    [anObject setFileOrder:[NSNumber numberWithInt:[publications count]]];
}

- (void)insertObject:(id)anObject atIndex:(unsigned)idx;
{
    [publications insertObject:anObject atIndex:idx];
    [self addToItemsForCiteKeys:anObject];
    [self updateFileOrder];
}

- (void)removeLastObject;
{
    id lastObject = [publications lastObject];
    if(lastObject){
        [self removeFromItemsForCiteKeys:lastObject];
        [publications removeLastObject];
    }
}

- (void)removeObjectAtIndex:(unsigned)idx;
{
    [self removeFromItemsForCiteKeys:[publications objectAtIndex:idx]];
    [publications removeObjectAtIndex:idx];
    [self updateFileOrder];
}

- (void)replaceObjectAtIndex:(unsigned)idx withObject:(id)anObject;
{
    BibItem *oldObject = [publications objectAtIndex:idx];
    [anObject setFileOrder:[oldObject fileOrder]];
    [self removeFromItemsForCiteKeys:oldObject];
    [publications replaceObjectAtIndex:idx withObject:anObject];
    [self addToItemsForCiteKeys:anObject];
}

#pragma mark Convenience overrides

- (void)getObjects:(id *)aBuffer range:(NSRange)aRange;
{
    [publications getObjects:aBuffer range:aRange];
}

- (void)removeAllObjects{
    [itemsForCiteKeys removeAllObjects];
    [publications removeAllObjects];
    [itemsForIdentifierURLs removeAllObjects];
}

- (void)addObjectsFromArray:(NSArray *)otherArray{
    [publications addObjectsFromArray:otherArray];
    [self performSelector:@selector(addToItemsForCiteKeys:) withObjectsFromArray:publications];
    [self updateFileOrder];
}

- (void)insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexes{
    [publications insertObjects:objects atIndexes:indexes];
    [self performSelector:@selector(addToItemsForCiteKeys:) withObjectsFromArray:[publications objectsAtIndexes:indexes]];
    [self updateFileOrder];
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes{
    [self performSelector:@selector(removeFromItemsForCiteKeys:) withObjectsFromArray:[publications objectsAtIndexes:indexes]];
    [publications removeObjectsAtIndexes:indexes];
    [self updateFileOrder];
}

- (void)setArray:(NSArray *)otherArray{
    [self removeAllObjects];
    [self addObjectsFromArray:otherArray];
}

- (NSEnumerator *)objectEnumerator;
{
    return [publications objectEnumerator];
}

#pragma mark Items for cite keys

- (void)changeCiteKey:(NSString *)oldKey toCiteKey:(NSString *)newKey forItem:(BibItem *)anItem;
{
    [itemsForCiteKeys removeObject:anItem forKey:oldKey];
    [itemsForCiteKeys addObject:anItem forKey:newKey];
}

- (BibItem *)itemForCiteKey:(NSString *)key;
{
	if ([NSString isEmptyString:key]) 
		return nil;
    
	NSArray *items = [itemsForCiteKeys arrayForKey:key];
	
	if ([items count] == 0)
		return nil;
    // may have duplicate items for the same key, so just return the first one
    return [items objectAtIndex:0];
}

- (NSArray *)allItemsForCiteKey:(NSString *)key;
{
	NSArray *items = nil;
    if ([NSString isEmptyString:key] == NO) 
		items = [itemsForCiteKeys arrayForKey:key];
    return (items == nil) ? [NSArray array] : items;
}

- (BOOL)citeKeyIsUsed:(NSString *)key byItemOtherThan:(BibItem *)anItem;
{
    NSArray *items = [itemsForCiteKeys arrayForKey:key];
    
	if ([items count] > 1)
		return YES;
	if ([items count] == 1 && [items objectAtIndex:0] != anItem)	
		return YES;
	return NO;
}

#pragma mark Crossref support

- (BOOL)citeKeyIsCrossreffed:(NSString *)key;
{
	if ([NSString isEmptyString:key]) 
		return NO;
    
	NSEnumerator *pubEnum = [publications objectEnumerator];
	BibItem *pub;
	
	while (pub = [pubEnum nextObject]) {
		if ([key caseInsensitiveCompare:[pub valueOfField:BDSKCrossrefString inherit:NO]] == NSOrderedSame) {
			return YES;
        }
	}
	return NO;
}

- (id)itemForIdentifierURL:(NSURL *)aURL;
{
    return [itemsForIdentifierURLs objectForKey:aURL];   
}

#pragma mark Authors support

- (NSArray *)itemsForAuthor:(BibAuthor *)anAuthor;
{
    NSMutableSet *auths = BDSKCreateFuzzyAuthorCompareMutableSet();
    NSEnumerator *pubEnum = [publications objectEnumerator];
    BibItem *bi;
    NSMutableArray *anAuthorPubs = [NSMutableArray array];
    
    while(bi = [pubEnum nextObject]){
        [auths addObjectsFromArray:[bi pubAuthors]];
        if([auths containsObject:anAuthor]){
            [anAuthorPubs addObject:bi];
        }
        [auths removeAllObjects];
    }
    [auths release];
    return anAuthorPubs;
}

@end


@implementation BDSKPublicationsArray (Private)

- (void)addToItemsForCiteKeys:(BibItem *)item;
{
    [itemsForCiteKeys addObject:item forKey:[item citeKey]];
    [itemsForIdentifierURLs setObject:item forKey:[item identifierURL]];
}

- (void)removeFromItemsForCiteKeys:(BibItem *)item{
    [itemsForCiteKeys removeObject:item forKey:[item citeKey]];
    [itemsForIdentifierURLs removeObjectForKey:[item identifierURL]];
}

- (void)updateFileOrder{
    unsigned i, count = [publications count];
    int fileOrder = 1;
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    for(i = 0; i < count; i++, fileOrder++) {
        CFNumberRef n = CFNumberCreate(alloc, kCFNumberIntType, &fileOrder);
        [[publications objectAtIndex:i] setFileOrder:(NSNumber *)n];
        CFRelease(n);
    }
}

@end
