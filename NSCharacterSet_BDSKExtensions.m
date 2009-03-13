//
//  NSCharacterSet_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 01/02/06.
/*
 This software is Copyright (c) 2006-2009
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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
#import "NSCharacterSet_BDSKExtensions.h"
#import "BDSKRuntime.h"


@implementation NSCharacterSet (BDSKExtensions)

+ (id)curlyBraceCharacterSet;
{  
    static NSCharacterSet *curlyBraceCharacterSet = nil;
    if (curlyBraceCharacterSet == nil)
        curlyBraceCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"{}"] copy];
    return curlyBraceCharacterSet; 
}    

+ (id)commaCharacterSet;
{
    static NSCharacterSet *commaCharacterSet = nil;
    if (commaCharacterSet == nil)
        commaCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@","] copy];
    return commaCharacterSet;
}

+ (id)searchStringSeparatorCharacterSet;
{
    static NSCharacterSet *searchStringSeparatorCharacterSet = nil;
    if (searchStringSeparatorCharacterSet == nil)
        searchStringSeparatorCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"+| "] copy];
    return searchStringSeparatorCharacterSet;
}

+ (id)upAndDownArrowCharacterSet;
{
    static NSCharacterSet *upAndDownArrowCharacterSet = nil;
    if (upAndDownArrowCharacterSet == nil) {
        unichar upAndDownArrowCharacters[2] = {NSUpArrowFunctionKey, NSDownArrowFunctionKey};
        NSString *upAndDownArrowString = [NSString stringWithCharacters: upAndDownArrowCharacters length:2];
        upAndDownArrowCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:upAndDownArrowString] copy];
    }
    return upAndDownArrowCharacterSet;
}

+ (id)nonWhitespaceCharacterSet;
{
    static NSCharacterSet *nonWhitespaceCharacterSet = nil;
    if (nonWhitespaceCharacterSet == nil)
        nonWhitespaceCharacterSet = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] copy];
    return nonWhitespaceCharacterSet;
}

+ (id)nonLetterCharacterSet;
{
    static NSCharacterSet *nonLetterCharacterSet = nil;
    if (nonLetterCharacterSet == nil)
        nonLetterCharacterSet = [[[NSCharacterSet letterCharacterSet] invertedSet] copy];
    return nonLetterCharacterSet;
}

+ (id)nonDecimalDigitCharacterSet;
{
    static NSCharacterSet *nonDecimalDigitCharacterSet = nil;
    if (nonDecimalDigitCharacterSet == nil)
        nonDecimalDigitCharacterSet = [[[NSCharacterSet decimalDigitCharacterSet] invertedSet] copy];
    return nonDecimalDigitCharacterSet;
}

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
+ (id)Tiger_newlineCharacterSet;
{
    static NSCharacterSet *newlineCharacterSet = nil;
    if (newlineCharacterSet == nil) {
        // This will be a character set with all newline characters (including the weird Unicode ones)
        CFMutableCharacterSetRef newlineCFCharacterSet = NULL;
        // get all whitespace characters (does not include newlines)
        newlineCFCharacterSet = CFCharacterSetCreateMutableCopy(CFAllocatorGetDefault(), CFCharacterSetGetPredefined(kCFCharacterSetWhitespace));
        // invert the whitespace-only set to get all non-whitespace chars (the inverted set will include newlines)
        CFCharacterSetInvert(newlineCFCharacterSet);
        // now get only the characters that are common to kCFCharacterSetWhitespaceAndNewline and our non-whitespace set
        CFCharacterSetIntersect(newlineCFCharacterSet, CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline));
        newlineCharacterSet = [(id)newlineCFCharacterSet copy];
        CFRelease(newlineCFCharacterSet);
    }
    return newlineCharacterSet;
}

+ (void)load {
    // this does nothing when the method is already defined, i.e. on Leopard
    BDSKAddClassMethodImplementationFromSelector(self, @selector(newlineCharacterSet), @selector(Tiger_newlineCharacterSet));
}
#else
#warning fixme: remove NSCharacterSet category implementation
#endif

@end
