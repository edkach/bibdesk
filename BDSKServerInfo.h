//
//  BDSKServerInfo.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/30/06.
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

enum {
    BDSKServerTypeEntrez,
    BDSKServerTypeZoom,
    BDSKServerTypeISI,
    BDSKServerTypeDBLP
};
typedef NSInteger BDSKServerType;

@interface BDSKServerInfo : NSObject <NSCopying, NSMutableCopying, NSCoding> {
    NSString *type;
    NSString *name;
    NSString *database;
    NSString *host;
    NSString *port;
    NSMutableDictionary *options;
}

+ (id)defaultServerInfoWithType:(NSString *)aType;

- (id)initWithType:(NSString *)aType name:(NSString *)aName database:(NSString *)aDbase host:(NSString *)aHost port:(NSString *)aPort options:(NSDictionary *)options;

- (id)initWithDictionary:(NSDictionary *)info;

- (NSDictionary *)dictionaryValue;

- (NSString *)type;
- (NSString *)name;
- (NSString *)database;
- (NSString *)host;
- (NSString *)port;
- (NSString *)password;
- (NSString *)username;
- (NSString *)recordSyntax;
- (NSString *)resultEncoding;
- (BOOL)removeDiacritics;
- (NSDictionary *)options;

- (BOOL)isEntrez;
- (BOOL)isZoom;
- (BOOL)isISI;
- (BOOL)isDBLP;

- (BDSKServerType)serverType;

@end

@interface BDSKMutableServerInfo : BDSKServerInfo

- (void)setType:(NSString *)newType;
- (void)setName:(NSString *)newName;
- (void)setDatabase:(NSString *)newDbase;
- (void)setPort:(NSString *)newPort;
- (void)setHost:(NSString *)newHost;
- (void)setPassword:(NSString *)newPassword;
- (void)setUsername:(NSString *)newUser;
- (void)setRecordSyntax:(NSString *)newSyntax;
- (void)setResultEncoding:(NSString *)newEncoding;
- (void)setRemoveDiacritics:(BOOL)flag;
- (void)setOptions:(NSDictionary *)newOptions;

@end
