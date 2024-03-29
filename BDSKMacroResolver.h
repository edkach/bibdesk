//
//  BDSKMacroResolver.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/20/06.
/*
 This software is Copyright (c) 2006-2012
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

#import <Cocoa/Cocoa.h>

extern NSString *BDSKMacroResolverTypeKey;
extern NSString *BDSKMacroResolverMacroKey;
extern NSString *BDSKMacroResolverOldMacroKey;
extern NSString *BDSKMacroResolverNewMacroKey;

extern NSString *BDSKMacroResolverAddType;
extern NSString *BDSKMacroResolverRemoveType;
extern NSString *BDSKMacroResolverChangeType;
extern NSString *BDSKMacroResolverRenameType;
extern NSString *BDSKMacroResolverSetType;

@class BibDocument;
@protocol BDSKOwner;

@interface BDSKMacroResolver : NSObject {
    NSMutableDictionary *macroDefinitions;
    id<BDSKOwner>owner;
    unsigned long long modification;
}

+ (id)defaultMacroResolver;

- (id)initWithOwner:(id<BDSKOwner>)anOwner;

- (id<BDSKOwner>)owner;

- (NSUndoManager *)undoManager;

- (NSString *)bibTeXString;

- (NSDictionary *)macroDefinitions;
- (void)setMacroDefinitions:(NSDictionary *)dictionary;
// returns global definitions + local overrides
- (NSDictionary *)allMacroDefinitions;

- (NSString *)valueOfMacro:(NSString *)macro;
// these use undo
- (void)setMacro:(NSString *)macro toValue:(NSString *)value;
- (void)changeMacro:(NSString *)oldMacro to:(NSString *)newMacro;

- (BOOL)string:(NSString *)string dependsOnMacro:(NSString *)macro;
- (BOOL)string:(NSString *)string dependsOnMacro:(NSString *)macro inMacroDefinitions:(NSDictionary *)dictionary;

- (unsigned long long)modification;

@end
