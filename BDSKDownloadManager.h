//
//  BDSKDownloadManager.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/14/10.
/*
 This software is Copyright (c) 2010-2012
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
    BDSKDownloadStatusDownloading,
    BDSKDownloadStatusFinished,
    BDSKDownloadStatusFailed
};
typedef NSUInteger BDSKDownloadStatus;

@interface BDSKDownloadManager : NSObject {
    NSMutableArray *downloads;
}

+ (id)sharedManager;

- (NSArray *)downloads;

- (BOOL)removeFinishedDownloads;
- (void)setRemoveFinishedDownloads:(BOOL)flag;
- (BOOL)removeFailedDownloads;
- (void)setRemoveFailedDownloads:(BOOL)flag;

- (void)clear;
- (void)cancel:(NSUInteger)uniqueID;
- (void)remove:(NSUInteger)uniqueID;

@end

#pragma mark -

@interface BDSKDownload : NSObject {
    NSUInteger uniqueID;
    NSURL *URL;
    NSURL *fileURL;
    BDSKDownloadStatus status;
    NSURLDownload *URLDownload;
}

- (id)initWithURLDownload:(NSURLDownload *)aDownload;

- (NSURLDownload *)URLDownload;
- (NSUInteger)uniqueID;
- (NSURL *)URL;
- (NSURL *)fileURL;
- (void)setFileURL:(NSURL *)newFileURL;
- (NSString *)fileName;
- (BDSKDownloadStatus)status;
- (void)setStatus:(BDSKDownloadStatus)newStatus;

@end
