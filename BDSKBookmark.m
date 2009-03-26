//
//  BDSKBookmark.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/25/08.
/*
 This software is Copyright (c) 2008-2009
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

#import "BDSKBookmark.h"

#define CHILDREN_KEY    @"Children"
#define TITLE_KEY       @"Title"
#define URL_KEY         @"URLString"
#define TYPE_KEY        @"Type"

#define BOOKMARK_STRING  @"bookmark"
#define FOLDER_STRING    @"folder"
#define SEPARATOR_STRING @"separator"


@interface BDSKPlaceholderBookmark : BDSKBookmark
@end

@interface BDSKURLBookmark : BDSKBookmark {
    NSString *name;
    NSString *urlString;
}
@end

@interface BDSKFolderBookmark : BDSKBookmark {
    NSString *name;
    NSMutableArray *children;
}
@end

@interface BDSKSeparatorBookmark : BDSKBookmark
@end

#pragma mark -

@implementation BDSKBookmark

static BDSKPlaceholderBookmark *defaultPlaceholderBookmark = nil;
static Class BDSKBookmarkClass = Nil;

+ (void)initialize {
    BDSKINITIALIZE;
    BDSKBookmarkClass = self;
    defaultPlaceholderBookmark = (BDSKPlaceholderBookmark *)NSAllocateObject([BDSKPlaceholderBookmark class], 0, NSDefaultMallocZone());
}

+ (id)allocWithZone:(NSZone *)aZone {
    return BDSKBookmarkClass == self ? defaultPlaceholderBookmark : [super allocWithZone:aZone];
}

+ (id)bookmarkWithUrlString:(NSString *)aUrlString name:(NSString *)aName {
    return [[[self alloc] initWithUrlString:aUrlString name:aName] autorelease];
}

+ (id)bookmarkFolderWithChildren:(NSArray *)aChildren name:(NSString *)aName {
    return [[[self alloc] initFolderWithChildren:aChildren name:aName] autorelease];
}

+ (id)bookmarkFolderWithName:(NSString *)aName {
    return [[[self alloc] initFolderWithName:aName] autorelease];
}

+ (id)bookmarkSeparator {
    return [[[self alloc] initSeparator] autorelease];
}

+ (id)bookmarkWithDictionary:(NSDictionary *)dictionary {
    return [[[self alloc] initWithDictionary:dictionary] autorelease];
}

- (id)initWithUrlString:(NSString *)aUrlString name:(NSString *)aName {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initFolderWithChildren:(NSArray *)aChildren name:(NSString *)aName {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initFolderWithName:(NSString *)aName {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initSeparator {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)copyWithZone:(NSZone *)aZone {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSDictionary *)dictionaryValue { return nil; }

- (int)bookmarkType { return 0; }

- (NSString *)name { return nil; }
- (void)setName:(NSString *)newName {}

- (NSImage *)icon { return nil; }

- (NSURL *)URL { return nil; }
- (NSString *)urlString { return nil; }
- (void)setUrlString:(NSString *)newUrlString {}

- (NSArray *)children { return nil; }
- (unsigned int)countOfChildren { return 0; }
- (BDSKBookmark *)objectInChildrenAtIndex:(unsigned int)idx { return nil; }
- (void)insertObject:(BDSKBookmark *)child inChildrenAtIndex:(unsigned int)idx {}
- (void)removeObjectFromChildrenAtIndex:(unsigned int)idx {}

- (BDSKBookmark *)parent {
    return parent;
}

- (void)setParent:(BDSKBookmark *)newParent {
    parent = newParent;
}

- (BOOL)isDescendantOf:(BDSKBookmark *)bookmark {
    if (self == bookmark)
        return YES;
    NSEnumerator *childEnum = [[bookmark children] objectEnumerator];
    BDSKBookmark *child;
    while (child = [childEnum nextObject]) {
        if ([self isDescendantOf:child])
            return YES;
    }
    return NO;
}

- (BOOL)isDescendantOfArray:(NSArray *)bookmarks {
    NSEnumerator *bmEnum = [bookmarks objectEnumerator];
    BDSKBookmark *bm = nil;
    while (bm = [bmEnum nextObject]) {
        if ([self isDescendantOf:bm]) return YES;
    }
    return NO;
}

@end

#pragma mark -

@implementation BDSKPlaceholderBookmark

- (id)init {
    return [self initWithUrlString:@"http://" name:nil];
}

- (id)initWithUrlString:(NSString *)aUrlString name:(NSString *)aName {
    return [[BDSKURLBookmark alloc] initWithUrlString:aUrlString name:aName ?: NSLocalizedString(@"New Boookmark", @"Default name for boookmark")];
}

- (id)initFolderWithChildren:(NSArray *)aChildren name:(NSString *)aName {
    return [[BDSKFolderBookmark alloc] initFolderWithChildren:aChildren name:aName];
}

- (id)initFolderWithName:(NSString *)aName {
    return [self initFolderWithChildren:[NSArray array] name:aName];
}

- (id)initSeparator {
    return [[BDSKSeparatorBookmark alloc] init];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if ([[dictionary objectForKey:TYPE_KEY] isEqualToString:FOLDER_STRING]) {
        NSEnumerator *dictEnum = [[dictionary objectForKey:CHILDREN_KEY] objectEnumerator];
        NSDictionary *dict;
        NSMutableArray *newChildren = [NSMutableArray array];
        while (dict = [dictEnum nextObject])
            [newChildren addObject:[[[[self class] alloc] initWithDictionary:dict] autorelease]];
        return [self initFolderWithChildren:newChildren name:[dictionary objectForKey:TITLE_KEY]];
    } else if ([[dictionary objectForKey:TYPE_KEY] isEqualToString:SEPARATOR_STRING]) {
        return [self initSeparator];
    } else {
        return [self initWithUrlString:[dictionary objectForKey:URL_KEY] name:[dictionary objectForKey:TITLE_KEY]];
    }
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (unsigned)retainCount { return UINT_MAX; }

@end

#pragma mark -

@implementation BDSKURLBookmark

- (id)initWithUrlString:(NSString *)aUrlString name:(NSString *)aName {
    if (self = [super init]) {
        urlString = [aUrlString copy];
        name = [aName copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)aZone {
    return [[[self class] allocWithZone:aZone] initWithUrlString:urlString name:name];
}

- (void)dealloc {
    [name release];
    [urlString release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: name=%@, URL=%@>", [self class], name, urlString];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:BOOKMARK_STRING, TYPE_KEY, urlString, URL_KEY, name, TITLE_KEY, nil];
}

- (int)bookmarkType {
    return BDSKBookmarkTypeBookmark;
}

- (NSString *)name {
    return [[name retain] autorelease];
}

- (void)setName:(NSString *)newName {
    if (name != newName) {
        [name release];
        name = [newName retain];
    }
}

- (BOOL)validateName:(id *)value error:(NSError **)error {
    NSString *string = *value;
    if ([NSString isEmptyString:string]) {
        if (error) {
            NSString *description = NSLocalizedString(@"Invalid name.", @"Error description");
            NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"Cannot set empty name for bookmark.", @"Error reason"), string];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:userInfo];
        }
        return NO;
    }
    return YES;
}

- (NSURL *)URL {
    return [NSURL URLWithString:[self urlString]];
}

- (NSString *)urlString {
    return [[urlString retain] autorelease];
}

- (void)setUrlString:(NSString *)newUrlString {
    if (urlString != newUrlString) {
        [urlString release];
        urlString = [newUrlString retain];
    }
}

- (BOOL)validateUrlString:(id *)value error:(NSError **)error {
    NSString *string = *value;
    if (string == nil || [NSURL URLWithString:string] == nil) {
        if (error) {
            NSString *description = NSLocalizedString(@"Invalid URL.", @"Error description");
            NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" is not a valid URL.", @"Error reason"), string];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:userInfo];
        }
        return NO;
    }
    return YES;
}

- (NSImage *)icon {
    return [NSImage imageNamed:@"TinyBookmark"];
}

@end

#pragma mark -

@implementation BDSKFolderBookmark

- (id)initFolderWithChildren:(NSArray *)aChildren name:(NSString *)aName {
    if (self = [super init]) {
        name = [aName copy];
        children = [aChildren mutableCopy];
        [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)aZone {
    return [[[self class] allocWithZone:aZone] initFolderWithChildren:[[[NSArray alloc] initWithArray:children copyItems:YES] autorelease] name:name];
}

- (void)dealloc {
    [name release];
    [children release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: name=%@, children=%@>", [self class], name, children];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:FOLDER_STRING, TYPE_KEY, [children valueForKey:@"dictionaryValue"], CHILDREN_KEY, name, TITLE_KEY, nil];
}

- (int)bookmarkType {
    return BDSKBookmarkTypeFolder;
}

- (NSImage *)icon {
    return [NSImage imageNamed:@"TinyFolder"];
}

- (NSString *)name {
    return [[name retain] autorelease];
}

- (void)setName:(NSString *)newName {
    if (name != newName) {
        [name release];
        name = [newName retain];
    }
}

- (BOOL)validateName:(id *)value error:(NSError **)error {
    NSString *string = *value;
    if ([NSString isEmptyString:string]) {
        if (error) {
            NSString *description = NSLocalizedString(@"Invalid name.", @"Error description");
            NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"cannot set empty name for bookmark.", @"Error reason"), string];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:userInfo];
        }
        return NO;
    }
    return YES;
}

- (NSArray *)children {
    return [[children copy] autorelease];
}

- (unsigned int)countOfChildren {
    return [children count];
}

- (BDSKBookmark *)objectInChildrenAtIndex:(unsigned int)idx {
    return [children objectAtIndex:idx];
}

- (void)insertObject:(BDSKBookmark *)child inChildrenAtIndex:(unsigned int)idx {
    [children insertObject:child atIndex:idx];
    [child setParent:self];
}

- (void)removeObjectFromChildrenAtIndex:(unsigned int)idx {
    [[children objectAtIndex:idx] setParent:nil];
    [children removeObjectAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKSeparatorBookmark

- (id)copyWithZone:(NSZone *)aZone {
    return [[[self class] allocWithZone:aZone] init];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: separator>", [self class]];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:SEPARATOR_STRING, TYPE_KEY, nil];
}

- (int)bookmarkType {
    return BDSKBookmarkTypeSeparator;
}

@end
