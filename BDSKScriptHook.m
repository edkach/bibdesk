//
//  BDSKScriptHook.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/10/05.
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

#import "BDSKScriptHook.h"
#import "BibDocument.h"
#import "CFString_BDSKExtensions.h"


@implementation BDSKScriptHook

// old designated initializer, shouldn't be used
- (id)init {
	return [self initWithName:nil script:nil];
}

// designated initializer
- (id)initWithName:(NSString *)aName script:(NSAppleScript *)aScript {
    self = [super init];
    if (self) {
        if (aScript == nil || aName == nil) {
            [self release];
            self = nil;
        } else {
            uniqueID = (id)BDCreateUniqueString();
            name = [aName retain];
            script = [aScript retain];
            field = nil;
            oldValues = nil;
            newValues = nil;
            document = nil;
        }
	}
	return self;
}

- (void)dealloc {
	BDSKDESTROY(name);
	BDSKDESTROY(uniqueID);
	BDSKDESTROY(script);
	BDSKDESTROY(field);
	BDSKDESTROY(oldValues);
	BDSKDESTROY(newValues);
	BDSKDESTROY(document);
	[super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: name=%@, uniqueID=%@>", [self class], name, uniqueID];
}

- (NSString *)name {
    return name;
}

- (NSString *)uniqueID {
    return uniqueID;
}

- (NSAppleScript *)script {
    return script;
}

- (NSString *)field {
    return field;
}

- (void)setField:(NSString *)newField {
    if (![field isEqualToString:newField]) {
        [field release];
        field = [newField retain];
    }
}

- (NSArray *)oldValues {
    return oldValues;
}

- (void)setOldValues:(NSArray *)values {
    if (oldValues != values) {
        [oldValues release];
        oldValues = [values retain];
    }
}

- (NSArray *)newValues {
    return newValues;
}

- (void)setNewValues:(NSArray *)values {
    if (newValues != values) {
        [newValues release];
        newValues = [values retain];
    }
}

- (BibDocument *)document {
    return document;
}

- (void)setDocument:(BibDocument *)newDocument {
    if (document != newDocument) {
        [document release];
        document = [newDocument retain];
    }
}

@end
