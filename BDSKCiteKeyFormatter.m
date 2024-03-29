//  BDSKCiteStringFormatter.m
//  Created by Michael McCracken on Sat Jul 06 2002.
/*
 This software is Copyright (c) 2002-2012
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKCiteKeyFormatter.h"


@implementation BDSKCiteKeyFormatter 

- (BOOL)allowsEmptyString {
    return allowsEmptyString;
}

- (void)setAllowsEmptyString:(BOOL)flag {
    allowsEmptyString = flag;
}

- (NSString *)stringForObjectValue:(id)obj{
    return obj;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs{
    return [[[NSAttributedString alloc] initWithString:[self stringForObjectValue:obj] attributes:attrs] autorelease];
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    if(allowsEmptyString == NO && [NSString isEmptyString:string]){
        if(error) *error = NSLocalizedString(@"Empty cite keys are not allowed.", @"Error description");
        return NO;
    }
    NSCharacterSet *invalidSet = [[BDSKTypeManager sharedManager] invalidCharactersForField:BDSKCiteKeyString];
    NSRange r = [string rangeOfCharacterFromSet:invalidSet];
    if (r.length) {
        if(error) *error = [NSString stringWithFormat:NSLocalizedString(@"The character \"%@\" is not allowed in a BibTeX cite key.", @"Error description"), [string substringWithRange:r]];
        return NO;
    }
    *obj = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error {
    NSString *partialString = *partialStringPtr;
	NSCharacterSet *invalidSet = [[BDSKTypeManager sharedManager] invalidCharactersForField:BDSKCiteKeyString];
    NSRange r = [partialString rangeOfCharacterFromSet:invalidSet];
    if ( r.location != NSNotFound) {
        NSMutableString *new = [[partialString mutableCopy] autorelease];
        [new replaceOccurrencesOfCharactersInSet:invalidSet withString:@""];
        if ([new length]) {
            *partialStringPtr = new;
            if (NSMaxRange(*proposedSelRangePtr) > [new length])
                *proposedSelRangePtr = NSMakeRange(r.location, 0);
        } else {
            *partialStringPtr = origString;
            *proposedSelRangePtr = origSelRange;
        }
        if(error) *error = [NSString stringWithFormat:NSLocalizedString(@"The character \"%@\" is not allowed in a BibTeX cite key.", @"Error description"), [partialString substringWithRange:r]];
        return NO;
    }else
        return YES;
}

@end
