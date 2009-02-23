//
//  BDSKCFCallBacks.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/19/09.
/*
 This software is Copyright (c) 2009
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

#import "BDSKCFCallBacks.h"
#import "CFString_BDSKExtensions.h"
    
const void *BDSKIntegerRetain(CFAllocatorRef allocator, const void *value) {
    int *intPtr = (int *)CFAllocatorAllocate(allocator, sizeof(int), 0);
    *intPtr = *(int *)value;
    return intPtr;
}

void BDSKIntegerRelease(CFAllocatorRef allocator, const void *value) {
    CFAllocatorDeallocate(allocator, (int *)value);
}

CFStringRef BDSKIntegerCopyDescription(const void *value) {
    return CFStringCreateWithFormat(NULL, NULL, CFSTR("%d"), *(int *)value);
}

Boolean	BDSKIntegerEqual(const void *value1, const void *value2) {
    return *(int *)value1 == *(int *)value2;
}

CFHashCode BDSKIntegerHash(const void *value) {
    return (CFHashCode)*(int *)value;
}

CFStringRef BDSKSELCopyDescription(const void *value) {
    return (CFStringRef)[NSStringFromSelector((SEL)value) retain];
}

const void *BDSKNSObjectRetain(CFAllocatorRef allocator, const void *value) {
    return [(id)value retain];
}

void BDSKNSObjectRelease(CFAllocatorRef allocator, const void *value) {
    [(id)value release];
}

CFStringRef BDSKNSObjectCopyDescription(const void *value) {
    return (CFStringRef)[[(id)value description] retain];
}

Boolean BDSKCaseInsensitiveStringEqual(const void *value1, const void *value2) {
    return (CFStringCompareWithOptions(value1, value2, CFRangeMake(0, CFStringGetLength(value1)), kCFCompareCaseInsensitive) == kCFCompareEqualTo);
}

CFHashCode BDSKCaseInsensitiveStringHash(const void *value) {
    return BDCaseInsensitiveStringHash(value);
}

const CFDictionaryKeyCallBacks kBDSKIntegerDictionaryKeyCallBacks = {
    0,   // version
    BDSKIntegerRetain,
    BDSKIntegerRelease,
    BDSKIntegerCopyDescription,
    BDSKIntegerEqual,
    BDSKIntegerHash
};

const CFDictionaryValueCallBacks kBDSKIntegerDictionaryValueCallBacks = {
    0,   // version
    BDSKIntegerRetain,
    BDSKIntegerRelease,
    BDSKIntegerCopyDescription,
    BDSKIntegerEqual
};

const CFDictionaryKeyCallBacks kBDSKNonOwnedObjectDictionaryKeyCallBacks = {
    0,    // version
    NULL, // retain
    NULL, // release
    BDSKNSObjectCopyDescription,
    NULL, // equal
    NULL  // hash
};

const CFDictionaryValueCallBacks kBDSKSELDictionaryValueCallBacks = {
    0,    // version
    NULL, // retain
    NULL, // release
    BDSKSELCopyDescription,
    NULL  // equal
};

const CFDictionaryKeyCallBacks kBDSKCaseInsensitiveStringDictionaryKeyCallBacks = {
    0,   // version
    BDSKNSObjectRetain,
    BDSKNSObjectRelease,
    BDSKNSObjectCopyDescription,
    BDSKCaseInsensitiveStringEqual,
    BDSKCaseInsensitiveStringHash
};

const CFArrayCallBacks kBDSKCaseInsensitiveStringArrayCallBacks = {
    0,   // version
    BDSKNSObjectRetain,
    BDSKNSObjectRelease,
    BDSKNSObjectCopyDescription,
    BDSKCaseInsensitiveStringEqual
};

const CFSetCallBacks kBDSKCaseInsensitiveStringSetCallBacks = {
    0,   // version
    BDSKNSObjectRetain,
    BDSKNSObjectRelease,
    BDSKNSObjectCopyDescription,
    BDSKCaseInsensitiveStringEqual,
    BDSKCaseInsensitiveStringHash
};

const CFBagCallBacks kBDSKCaseInsensitiveStringBagCallBacks = {
    0,   // version
    BDSKNSObjectRetain,
    BDSKNSObjectRelease,
    BDSKNSObjectCopyDescription,
    BDSKCaseInsensitiveStringEqual,
    BDSKCaseInsensitiveStringHash
};
