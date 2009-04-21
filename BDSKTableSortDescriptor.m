//
//  BDSKTableSortDescriptor.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/11/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKTableSortDescriptor.h"
#import "BDSKTypeManager.h"
#import "NSColor_BDSKExtensions.h"

@interface NSArray (BibAuthorMultipleCompare)
@end

@implementation NSArray (BibAuthorMultipleCompare)

/* Added at request of a user who wants to sort in a journal-style order of author/year.  Since our table subsort is only 2 deep, this is the most reasonable place to do the comparison for an arbitrary number of authors.  

There are some issues with BibAuthor's sortCompare:, though, which we may revisit at some point.  "K. Been and G. C. Sills" sorts before "Kenneth Been", although "K. Been" and "Kenneth Been" are the same person.  This is more obvious when you only display abbreviated author names, in which case it appears to be a bug.
*/
- (NSComparisonResult)sortCompareToAuthorArray:(NSArray *)other;
{
    NSUInteger myCount = [self count], otherCount = [other count];
    
    // hack for our non-standard sort order, which looks weirder than usual in this case...
    if (myCount == 0)
        return otherCount == 0 ? NSOrderedSame : NSOrderedDescending;
    else if (otherCount == 0)
        return NSOrderedAscending;

    NSUInteger i, iMax = MIN(myCount, otherCount);    
    NSComparisonResult order = NSOrderedSame;
    
    // compare up to the maximum number of elements, but break early if not ordered same
    for (i = 0; i < iMax && NSOrderedSame == order; i++) {
        order = [[self objectAtIndex:i] sortCompare:[other objectAtIndex:i]];
    }
    
    // if weakly ordered same, item with fewer authors comes first (in ascending order)
    if (NSOrderedSame == order && myCount != otherCount)
        order = myCount > otherCount ? NSOrderedDescending : NSOrderedAscending;
    
    return order;
}

@end

@implementation BDSKTableSortDescriptor

+ (BDSKTableSortDescriptor *)tableSortDescriptorForIdentifier:(NSString *)tcID ascending:(BOOL)ascend{
    return [self tableSortDescriptorForIdentifier:tcID ascending:ascend userInfo:nil];
}

+ (BDSKTableSortDescriptor *)tableSortDescriptorForIdentifier:(NSString *)tcID ascending:(BOOL)ascend userInfo:(id)userInfo{

    NSParameterAssert([NSString isEmptyString:tcID] == NO);
    
    BDSKTableSortDescriptor *sortDescriptor = nil;
    
	if([tcID isEqualToString:BDSKCiteKeyString]){
		sortDescriptor = [[self alloc] initWithKey:@"citeKey" ascending:ascend selector:@selector(localizedCaseInsensitiveNumericCompare:)];
        
	}else if([tcID isEqualToString:BDSKTitleString]){
		
		sortDescriptor = [[self alloc] initWithKey:@"title.stringByRemovingTeXAndStopWords" ascending:ascend selector:@selector(localizedCaseInsensitiveCompare:)];
		
	}else if([tcID isEqualToString:BDSKContainerString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"container.stringByRemovingTeXAndStopWords" ascending:ascend selector:@selector(localizedCaseInsensitiveCompare:)];
        
	}else if([tcID isEqualToString:BDSKPubDateString]){
		
		sortDescriptor = [[self alloc] initWithKey:@"date" ascending:ascend selector:@selector(compare:)];		
        
	}else if([tcID isEqualToString:BDSKDateAddedString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"dateAdded" ascending:ascend selector:@selector(compare:)];
        
	}else if([tcID isEqualToString:BDSKDateModifiedString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"dateModified" ascending:ascend selector:@selector(compare:)];
        
	}else if([tcID isEqualToString:BDSKAuthorString]){
        
        sortDescriptor = [[self alloc] initWithKey:@"pubAuthors" ascending:ascend selector:@selector(sortCompareToAuthorArray:)];
        
	}else if([tcID isEqualToString:BDSKFirstAuthorString]){
        
        sortDescriptor = [[self alloc] initWithKey:@"firstAuthor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKSecondAuthorString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"secondAuthor" ascending:ascend selector:@selector(sortCompare:)];
		
	}else if([tcID isEqualToString:BDSKThirdAuthorString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"thirdAuthor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKLastAuthorString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"lastAuthor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKFirstAuthorEditorString] ||
             [tcID isEqualToString:BDSKAuthorEditorString]){
        
        sortDescriptor = [[self alloc] initWithKey:@"firstAuthorOrEditor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKSecondAuthorEditorString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"secondAuthorOrEditor" ascending:ascend selector:@selector(sortCompare:)];
		
	}else if([tcID isEqualToString:BDSKThirdAuthorEditorString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"thirdAuthorOrEditor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKLastAuthorEditorString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"lastAuthorOrEditor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKEditorString]){
		
        sortDescriptor = [[self alloc] initWithKey:@"pubEditors.@firstObject" ascending:ascend selector:@selector(sortCompare:)];

	}else if([tcID isEqualToString:BDSKPubTypeString]){

        sortDescriptor = [[self alloc] initWithKey:@"pubType" ascending:ascend selector:@selector(localizedCaseInsensitiveCompare:)];
        
    }else if([tcID isEqualToString:BDSKItemNumberString] || [tcID isEqualToString:BDSKImportOrderString]){
        
        sortDescriptor = [[self alloc] initWithKey:@"fileOrder" ascending:ascend selector:@selector(compare:)];		
        
    }else if([tcID isEqualToString:BDSKBooktitleString]){
        
        sortDescriptor = [[self alloc] initWithKey:@"Booktitle.stringByRemovingTeXAndStopWords" ascending:ascend selector:@selector(localizedCaseInsensitiveCompare:)];
        
    }else if([tcID isBooleanField] || [tcID isTriStateField]){
        
        sortDescriptor = [[self alloc] initWithKey:tcID ascending:ascend selector:@selector(triStateCompare:)];
        
    }else if([tcID isRatingField] || [tcID isEqualToString:BDSKRelevanceString] || [tcID isNumericField]){
        
        sortDescriptor = [[self alloc] initWithKey:tcID ascending:ascend selector:@selector(numericCompare:)];
        
    }else if([tcID isRemoteURLField]){
        
        // compare pathExtension for URL fields so the subsort is more useful
        sortDescriptor = [[self alloc] initWithKey:tcID ascending:ascend selector:@selector(extensionCompare:)];

    }else if([tcID isLocalFileField]){
        
        // compare UTI for file fields so the subsort is more useful
        if ([userInfo respondsToSelector:@selector(stringByStandardizingPath)])
            userInfo = [userInfo stringByStandardizingPath];
        else
            userInfo = nil;
        BOOL isDir = NO;
        if (userInfo && [[NSFileManager defaultManager] fileExistsAtPath:userInfo isDirectory:&isDir] && isDir)
            sortDescriptor = [[self alloc] initWithKey:tcID ascending:ascend selector:@selector(UTICompare:basePath:) userInfo:userInfo];
        else
            sortDescriptor = [[self alloc] initWithKey:tcID ascending:ascend selector:@selector(UTICompare:)];
        
    }else if([tcID isEqualToString:BDSKLocalFileString]){
        
        sortDescriptor = [[self alloc] initWithKey:@"countOfLocalFilesAsNumber" ascending:ascend selector:@selector(compare:)];
        
    }else if([tcID isEqualToString:BDSKRemoteURLString]){
        
        sortDescriptor = [[self alloc] initWithKey:@"countOfRemoteURLsAsNumber" ascending:ascend selector:@selector(compare:)];
        
    }else if([tcID isEqualToString:BDSKColorString] || [tcID isEqualToString:BDSKColorLabelString]){
        
        sortDescriptor = [[self alloc] initWithKey:@"color" ascending:ascend selector:@selector(colorCompare:)];
        
    }else {
        
        // this assumes that all other columns must be NSString objects
        sortDescriptor = [[self alloc] initWithKey:tcID ascending:ascend selector:@selector(localizedCaseInsensitiveNumericCompare:)];
        
	}
 
    BDSKASSERT(sortDescriptor);
    return [sortDescriptor autorelease];
}

- (void)cacheKeys;
{
    // cache the components of the keypath and their count
    keys = CFArrayCreateCopy(CFAllocatorGetDefault(), (CFArrayRef)[[self key] componentsSeparatedByString:@"."]);
    keyCount = CFArrayGetCount(keys);
}

- (id)initWithKey:(NSString *)key ascending:(BOOL)flag selector:(SEL)theSel;
{
    return [self initWithKey:key ascending:flag selector:theSel userInfo:nil];
}

- (id)initWithKey:(NSString *)key ascending:(BOOL)flag selector:(SEL)theSel userInfo:(id)info;
{
    if(self = [super initWithKey:key ascending:flag selector:theSel]){
        [self cacheKeys];
        
        // since NSSortDescriptor ivars are declared @private, we have to use @defs to access them directly; use our own instead, since this won't be subclassed
        selector = theSel;
        ascending = flag;
        userInfo = [info retain];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aCoder
{
    if (self = [super initWithCoder:aCoder]) {
        [self cacheKeys];
        selector = [self selector];
        ascending = [self ascending];
        userInfo = [aCoder allowsKeyedCoding] ? [aCoder decodeObjectForKey:@"userInfo"] : [aCoder decodeObject];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder allowsKeyedCoding] ? [aCoder encodeObject:userInfo forKey:@"userInfo"] : [aCoder encodeObject:userInfo];
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [[[self class] allocWithZone:aZone] initWithKey:[self key] ascending:[self ascending] selector:[self selector]];
}

- (void)dealloc
{
    CFRelease(keys);
    [userInfo release];
    [super dealloc];
}

static inline void __GetValuesUsingCache(BDSKTableSortDescriptor *sort, id object1, id object2, id *value1, id *value2)
{
    CFIndex i;
    *value1 = object1;
    *value2 = object2;
    NSString *key;
    
    // storing the array as an NSString ** buffer really didn't help with performance, but using CFArray functions does help cut down on the objc overhead
    for(i = 0; i < sort->keyCount; i++){
        key = (NSString *)CFArrayGetValueAtIndex(sort->keys, i);
        *value1 = [*value1 valueForKey:key];
        *value2 = [*value2 valueForKey:key];
    }
}

- (NSComparisonResult)compareEndObject:(id)value1 toEndObject:(id)value2;
{
    // check to see if one of the values is nil
    if(value1 == nil){
        if(value2 == nil)
            return NSOrderedSame;
        else
            return (ascending ? NSOrderedDescending : NSOrderedAscending);
    } else if(value2 == nil){
        return (ascending ? NSOrderedAscending : NSOrderedDescending);
        // this check only applies to NSString objects
    } else if([value1 isKindOfClass:[NSString class]] && [value2 isKindOfClass:[NSString class]]){
        if ([value1 isEqualToString:@""]) {
            if ([value2 isEqualToString:@""]) {
                return NSOrderedSame;
            } else {
                return (ascending ? NSOrderedDescending : NSOrderedAscending);
            }
        } else if ([value2 isEqualToString:@""]) {
            return (ascending ? NSOrderedAscending : NSOrderedDescending);
        }
    } 	
    
    NSComparisonResult result;
    
    if (userInfo) {
        // we use the IMP directly since performSelector: returns an id
        typedef NSComparisonResult (*comparatorIMP)(id, SEL, id, id);
        comparatorIMP comparator = (comparatorIMP)[value1 methodForSelector:selector];
        result = comparator(value1, selector, value2, userInfo);
    } else {
        // we use the IMP directly since performSelector: returns an id
        typedef NSComparisonResult (*comparatorIMP)(id, SEL, id);
        comparatorIMP comparator = (comparatorIMP)[value1 methodForSelector:selector];
        result = comparator(value1, selector, value2);
    }
    
    
    return ascending ? result : (result *= -1);
}

- (NSComparisonResult)compareObject:(id)object1 toObject:(id)object2 {

    id value1, value2;
    BDSKASSERT_NOT_REACHED("Inefficient code path; use -[NSArray sortedArrayUsingMergesortWithDescriptors:] instead");
    // get the values in bulk; since the same keypath is used for both objects, why compute it twice?
    __GetValuesUsingCache(self, object1, object2, &value1, &value2);
    return [self compareEndObject:value1 toEndObject:value2];
}

@end
