//
//  BDSKSmartGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/21/06.
/*
 This software is Copyright (c) 2005-2012
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

#import "BDSKSmartGroup.h"
#import "BDSKFilter.h"
#import "NSImage_BDSKExtensions.h"
#import "BibItem.h"


@implementation BDSKSmartGroup

// super's designated initializer
- (id)initWithName:(id)aName {
    BDSKFilter *aFilter = [[BDSKFilter alloc] init];
	self = [self initWithName:aName filter:aFilter];
	[aFilter release];
    return self;
}

// designated initializer
- (id)initWithName:(id)aName filter:(BDSKFilter *)aFilter {
    self = [super initWithName:aName];
    if (self) {
        filter = [aFilter copy];
        [filter setGroup:self];
    }
    return self;
}

- (id)initWithFilter:(BDSKFilter *)aFilter {
	NSString *aName = nil;
	if ([[aFilter conditions] count] > 0)
		aName = [[[aFilter conditions] objectAtIndex:0] value];
	if ([NSString isEmptyString:aName])
		aName = NSLocalizedString(@"Smart Group", @"Default name for smart group");
	self = [self initWithName:aName filter:aFilter];
	return self;
}

- (id)initWithDictionary:(NSDictionary *)groupDict {
    NSString *aName = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
    BDSKFilter *aFilter = [[BDSKFilter alloc] initWithDictionary:groupDict];
    self = [self initWithName:aName filter:aFilter];
    [aFilter release];
    return self;
}

- (NSDictionary *)dictionaryValue {
    NSMutableDictionary *groupDict = [[filter dictionaryValue] mutableCopy];
    NSString *aName = [[self stringValue] stringByEscapingGroupPlistEntities];
    [groupDict setObject:aName forKey:@"group name"];
    return [groupDict autorelease];
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        filter = [[decoder decodeObjectForKey:@"filter"] retain];
        [filter setGroup:self];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:filter forKey:@"filter"];
}

- (id)copyWithZone:(NSZone *)aZone {
	return [[[self class] allocWithZone:aZone] initWithName:name filter:filter];
}

- (void)dealloc {
    [filter setGroup:nil];
    BDSKDESTROY(filter);
    [super dealloc];
}

- (NSUInteger)hash {
    return [[self name] hash];
}

- (BOOL)isEqual:(id)other {
	if (self == other)
		return YES;
	if (NO == [other isMemberOfClass:[self class]]) 
		return NO;
	return [[self name] isEqual:[(BDSKGroup *)other name]] && [[self filter] isEqual:[(BDSKSmartGroup *)other filter]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, filter={ %@ }", [super description], filter];
}

// "static" properties

- (BOOL)isSmart { return YES; }

- (BOOL)isEditable { return YES; }

- (NSImage *)icon {
	return [NSImage imageNamed:NSImageNameFolderSmart];
}

// accessors

- (BDSKFilter *)filter {
    return [[filter retain] autorelease];
}

- (void)setFilter:(BDSKFilter *)newFilter {
    if (filter != newFilter) {
		[[[self undoManager] prepareWithInvocationTarget:self] setFilter:filter];
        [filter setGroup:nil];
        [filter release];
        filter = [newFilter copy];
        [filter setGroup:self];
    }
}

- (BOOL)containsItem:(BibItem *)item {
	return [filter testItem:item];
}

- (NSArray *)filterItems:(NSArray *)items {
	NSArray *filteredItems = [filter filterItems:items];
	[self setCount:[filteredItems count]];
	return filteredItems;
}

@end
