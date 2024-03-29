//
//  NSAttributedString+Scripting.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/27/11.
/*
 This software is Copyright (c) 2008-2012
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

#import "NSAttributedString+Scripting.h"
#import "NSData_BDSKExtensions.h"


@implementation NSAttributedString (BDSKScripting)

- (NSString *)scriptingName {
    return [[self RTFFromRange:NSMakeRange(0, [self length]) documentAttributes:nil] hexString];
}

- (NSTextStorage *)scriptingRichText {
    return [[[NSTextStorage alloc] initWithAttributedString:self] autorelease];
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptClassDescription *containerClassDescription = [NSScriptClassDescription classDescriptionForClass:[NSApp class]];
    return [[[NSNameSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:containerClassDescription containerSpecifier:nil key:@"richTextFormat" name:[self scriptingName]] autorelease];
}

- (NSScriptObjectSpecifier *)richTextSpecifier {
    NSScriptObjectSpecifier *rtfSpecifier = [self objectSpecifier];
    return [[[NSPropertySpecifier alloc] initWithContainerClassDescription:[rtfSpecifier keyClassDescription] containerSpecifier:rtfSpecifier key:@"scriptingRichText"] autorelease];
}

@end

#pragma mark -

@implementation NSTextStorage (BDSKScripting)

- (id)scriptingRTF {
    return [self RTFFromRange:NSMakeRange(0, [self length]) documentAttributes:nil];
}

- (void)setScriptingRTF:(id)data {
    if (data) {
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithData:data options:[NSDictionary dictionary] documentAttributes:NULL error:NULL];
        if (attrString)
            [self setAttributedString:attrString];
        [attrString release];
    }
}

@end

#pragma mark -

@implementation NSApplication (BDSKRichTextFormat)

- (NSAttributedString *)valueInRichTextFormatWithName:(NSString *)name {
    NSData *data = [[[NSData alloc] initWithHexString:name] autorelease];
    return data ? [[[NSAttributedString alloc] initWithData:data options:[NSDictionary dictionary] documentAttributes:NULL error:NULL] autorelease] : nil;
}

@end
