//
//  BDSKDocumentSearch.h
//  Bibdesk
//
//  Created by Adam Maxwell on 1/19/08.
/*
 This software is Copyright (c) 2008
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

#import <Cocoa/Cocoa.h>

@interface BDSKDocumentSearch : NSObject {
    @private;
    SKSearchRef search;                       // active search
    NSInvocation *callback;                   // encapsulates document target for callback messages
    float maxScore;                           // maximum score encountered
    NSMutableDictionary *originalScores;      // non-normalized scores, identifier URLs as keys
    volatile int32_t isSearching __attribute__ ((aligned (32)));

    // main thread access only
    SKIndexRef currentIndex;                  // nonretained
    NSString *currentSearchString;            // avoids duplicate searches
    NSArray *previouslySelectedPublications;  // convenience for the document
}

// following are all thread safe; document is only used as target for the callback
- (id)initWithDocument:(id)doc;
- (void)searchForString:(NSString *)searchString index:(SKIndexRef)index selectedPublications:(NSArray *)selPubs;
- (NSArray *)previouslySelectedPublications;

// call when closing the document window; kills the search and prevents further callbacks
- (void)terminate;

@end

// This will be sent on the main thread.  Each set only contains newly returned items (since the last time it was sent), but scores include properly normalized values for all previously returned items as well.
@interface NSObject (BDSKDocumentSearchCallback)
- (void)handleSearchCallbackWithIdentifiers:(NSSet *)identifierURLs normalizedScores:(NSDictionary *)scores;
@end
