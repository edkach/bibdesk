//
//  BDSKSearchResult.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/12/05.
/*
 This software is Copyright (c) 2005,2006,2007
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

#import "BDSKSearchResult.h"
#import "NSAttributedString_BDSKExtensions.h"
#import "BDSKSearchIndex.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFile.h"

@implementation BDSKSearchResult

- (id)initWithIndex:(BDSKSearchIndex *)anIndex documentRef:(SKDocumentRef)skDocument score:(float)theScore;
{
    
    NSParameterAssert(nil != anIndex);
    NSParameterAssert(NULL != skDocument);
        
    if ((self = [super init])) {
        
        NSURL *theURL = (NSURL *)SKDocumentCopyURL(skDocument);
        file = [[BDSKFile alloc] initWithURL:theURL];

        image = [[NSImage imageForURL:theURL] retain];
        NSDictionary *theItem = [anIndex itemInfoForURL:theURL];
        NSString *theTitle = [theItem valueForKey:@"title"];
        
        if (nil == theTitle)
            theTitle = [theURL path];

        string = [theTitle copy];
        [theURL release];

        attributedString = [[NSAttributedString alloc] initWithTeXString:string attributes:nil collapseWhitespace:NO];
        
        identifierURL = [[theItem valueForKey:@"identifierURL"] copy];
        
        score = theScore;
    }
    
    return self;
}

- (void)dealloc
{
    [file release];
    [attributedString release];
    [string release];
    [identifierURL release];
    [image release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    BDSKSearchResult *copy = [[[self class] allocWithZone:zone] init];
    copy->file = [file copy];
    copy->string = [string copy];
    copy->attributedString = [attributedString copy];
    copy->identifierURL = [identifierURL copy];
    copy->image = [image retain];
    copy->score = score;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"File: %@ \n\t string = \"%@\"", file, string];
}

- (unsigned int)hash
{
    return [file hash];
}

- (BOOL)isEqual:(id)anObject
{
    return [anObject isKindOfClass:[self class]] ? [((BDSKSearchResult *)anObject)->file isEqual:file] : NO;
}

- (NSImage *)image { return image; }
- (NSString *)string { return string; }
- (NSAttributedString *)attributedString { return attributedString; }
- (NSURL *)identifierURL { return identifierURL; }
- (NSURL *)URL { return [file fileURL]; }
- (void)setScore:(double)newScore { score = newScore; }
- (double)score { return score; }

@end

