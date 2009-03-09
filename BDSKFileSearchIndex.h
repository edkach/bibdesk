//
//  BDSKFileSearchIndex.h
//  Bibdesk
//
//  Created by Adam Maxwell on 10/11/05.
/*
 This software is Copyright (c) 2005-2009
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

@class BDSKFileSearchIndex, BDSKManyToManyDictionary, BDSKReadWriteLock, BibDocument;

@protocol BDSKFileSearchIndexDelegate <NSObject>

// Sent on the main thread at periodic intervals to inform the delegate that new files have been added to the index, and that any searches in progress need to be updated.
- (void)searchIndexDidUpdate:(BDSKFileSearchIndex *)index;

// Sent on the main thread after the initial indexing phase has finished.  This allows the delegate to update its search for the last time.
- (void)searchIndexDidFinish:(BDSKFileSearchIndex *)index;
@end

typedef struct _BDSKSearchIndexFlags
{
    volatile int32_t shouldKeepRunning;
    volatile int32_t finishedInitialIndexing;
} BDSKSearchIndexFlags;

@interface BDSKFileSearchIndex : NSObject {
    SKIndexRef index;
    CFMutableDataRef indexData;
    BDSKManyToManyDictionary *identifierURLs;
    NSMutableDictionary *signatures;
    id delegate;
    
    BDSKReadWriteLock *rwLock;
    
    NSMutableArray *notificationQueue;
    NSLock *noteLock;
    NSMachPort *notificationPort;
    NSThread *notificationThread;
    NSConditionLock *setupLock;
    BDSKSearchIndexFlags flags;
    double progressValue;
    CFAbsoluteTime lastUpdateTime;
}

// aDocument must respond to -publications; this should generally be called on the main thread
- (id)initForDocument:(BibDocument *)aDocument;

// Warning:  it is /not/ safe to write to this SKIndexRef directly; use it only for reading.
- (SKIndexRef)index;

// Required before disposing of the index.  After calling cancel, the index is no longer viable.
- (void)cancelForDocumentURL:(NSURL *)documentURL;
- (BOOL)finishedInitialIndexing;
- (void)setDelegate:(id <BDSKFileSearchIndexDelegate>)anObject;
- (NSURL *)identifierURLForURL:(NSURL *)theURL;
- (NSSet *)allIdentifierURLsForURL:(NSURL *)theURL;

// Poll this for progress bar updates during indexing
- (double)progressValue;

@end
