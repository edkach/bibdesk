//
//  BDSKVersionNumber.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/28/08.
//  Copyright 2008 Christiaan Hofman. All rights reserved.
//

// Much of this code is copied and modified from OmniFoundation/OFVersionNumber and subject to the following copyright.

// Copyright 2004-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header$

#import <Cocoa/Cocoa.h>

enum {
    BDSKReleaseVersionType,
    BDSKReleaseCandidateVersionType,
    BDSKBetaVersionType,
    BDSKAlphaVersionType,
};

@interface BDSKVersionNumber : NSObject <NSCopying>
{
    NSString *originalVersionString;
    NSString *cleanVersionString;
    
    unsigned int componentCount;
    int *components;
    int releaseType;
}

- (id)initWithVersionString:(NSString *)versionString;

- (NSString *)originalVersionString;
- (NSString *)cleanVersionString;

- (unsigned int)componentCount;
- (int)componentAtIndex:(unsigned int)componentIndex;

- (int)releaseType;
- (BOOL)isRelease;
- (BOOL)isReleaseCandidate;
- (BOOL)isBeta;
- (BOOL)isAlpha;

- (NSComparisonResult)compareToVersionNumber:(BDSKVersionNumber *)otherVersion;

@end
