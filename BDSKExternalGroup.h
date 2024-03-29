//
//  BDSKExternalGroup.h
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

#import <Cocoa/Cocoa.h>
#import "BDSKGroup.h"
#import "BDSKOwnerProtocol.h"

extern NSString *BDSKExternalGroupSucceededKey;

@class BDSKPublicationsArray, BDSKMacroResolver, BDSKItemSearchIndexes;

@interface BDSKExternalGroup : BDSKGroup <BDSKOwner> {
    BDSKPublicationsArray *publications;
    BDSKMacroResolver *macroResolver;
    BDSKItemSearchIndexes *searchIndexes;
}

- (id)initWithName:(NSString *)aName;

- (BDSKPublicationsArray *)publicationsWithoutUpdating; 
- (BDSKPublicationsArray *)publications;
- (void)setPublications:(NSArray *)newPublications;
- (void)addPublications:(NSArray *)newPublications;

- (BOOL)shouldRetrievePublications;
- (void)retrievePublications;

- (void)stopRetrieving;

- (void)notifyUpdateForSuccess:(BOOL)succeeded;

@end

#pragma mark -

@interface BDSKMutableExternalGroup : BDSKExternalGroup <BDSKMutableGroup> {
    NSString *errorMessage;
}

- (NSString *)errorMessage;
- (void)setErrorMessage:(NSString *)newErrorMessage;

@end
