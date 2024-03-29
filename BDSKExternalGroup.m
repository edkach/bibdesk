//
//  BDSKExternalGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/28/09.
/*
 This software is Copyright (c) 2009-2012
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

#import "BDSKExternalGroup.h"
#import "BDSKOwnerProtocol.h"
#import "BibItem.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacroResolver.h"
#import "BDSKItemSearchIndexes.h"

NSString *BDSKExternalGroupSucceededKey = @"succeeded";

@implementation BDSKExternalGroup

// designated initializer
- (id)initWithName:(NSString *)aName {
    NSAssert(aName != nil, @"External group requires a name");

    self = [super initWithName:aName];
    if (self) {
        publications = nil;
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
        searchIndexes = [BDSKItemSearchIndexes new];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    BDSKASSERT_NOT_REACHED("External groups should never be decoded");
    self = [super initWithCoder:decoder];
    if (self) {
        publications = nil;
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
        searchIndexes = [BDSKItemSearchIndexes new];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    BDSKASSERT_NOT_REACHED("External groups should never be encoded");
    [super encodeWithCoder:coder];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [publications setValue:nil forKey:@"owner"];
    BDSKDESTROY(publications);
    BDSKDESTROY(macroResolver);
    BDSKDESTROY(searchIndexes);
    [super dealloc];
}

#pragma mark BDSKGroup overrides

- (BOOL)isExternal { return YES; }

- (BOOL)containsItem:(BibItem *)item { return [publications containsObject:item]; }

#pragma mark Publications

- (BDSKPublicationsArray *)publicationsWithoutUpdating { return publications; }
 
- (BDSKPublicationsArray *)publications {
    if ([self isRetrieving] == NO && [self shouldRetrievePublications]) {
        // get the publications asynchronously if remote, synchronously if local
        [self retrievePublications]; 
        // use this to notify the tableview to start the progress indicators
        [self notifyUpdateForSuccess:NO];
    }
    return publications;
}

- (void)setPublications:(NSArray *)newPublications {
    if ([self isRetrieving])
        [self stopRetrieving];
    
    if (newPublications != publications) {
        [publications setValue:nil forKey:@"owner"];
        [publications release];
        publications = newPublications == nil ? nil : [[BDSKPublicationsArray alloc] initWithArray:newPublications];
        [publications setValue:self forKey:@"owner"];
        [searchIndexes resetWithPublications:publications];
        if (publications == nil)
            [macroResolver setMacroDefinitions:nil];
    }
    
    [self setCount:[publications count]];
    
    [self notifyUpdateForSuccess:newPublications != nil];
}

- (void)addPublications:(NSArray *)newPublications {
    if (newPublications != publications && newPublications != nil) {
        if (publications == nil)
            publications = [[BDSKPublicationsArray alloc] initWithArray:newPublications];
        else 
            [publications addObjectsFromArray:newPublications];
        [newPublications setValue:self forKey:@"owner"];
        [searchIndexes addPublications:newPublications];
    }
    
    [self setCount:[publications count]];
    
    [self notifyUpdateForSuccess:newPublications != nil];
}

- (BOOL)shouldRetrievePublications { return publications == nil; }

- (void)retrievePublications {}

- (void)stopRetrieving {}

- (void)notifyUpdateForSuccess:(BOOL)succeeded {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKExternalGroupUpdatedNotification object:self
        userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:succeeded] forKey:BDSKExternalGroupSucceededKey]];
}

#pragma mark BDSKOwner protocol

- (BDSKMacroResolver *)macroResolver { return macroResolver; }

- (NSUndoManager *)undoManager { return nil; }

- (NSURL *)fileURL { return nil; }

- (NSString *)documentInfoForKey:(NSString *)key { return nil; }

- (BOOL)isDocument { return NO; }

- (BDSKItemSearchIndexes *)searchIndexes{ return searchIndexes; }

@end

#pragma mark -

@implementation BDSKMutableExternalGroup

- (void)dealloc {
    BDSKDESTROY(errorMessage);
    [super dealloc];
}

- (void)addPublications:(NSArray *)newPublications { [self doesNotRecognizeSelector:_cmd]; }

- (void)setName:(id)newName {
    if (name != newName) {
		[(BDSKMutableExternalGroup *)[[self undoManager] prepareWithInvocationTarget:self] setName:name];
        [name release];
        name = [newName retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupNameChangedNotification object:self];
    }
}

- (NSString *)errorMessage {
    return errorMessage;
}

- (void)setErrorMessage:(NSString *)newErrorMessage {
    if (errorMessage != newErrorMessage) {
        [errorMessage release];
        errorMessage = [newErrorMessage retain];
    }
}

- (NSUndoManager *)undoManager {
    return [document undoManager];
}

- (BOOL)isNameEditable { return YES; }

- (BOOL)isEditable { return YES; }

@end
