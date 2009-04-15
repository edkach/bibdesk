//
//  BDSKQueueProcessor.m
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
/*
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BDSKQueueProcessor.h"
#import "BDSKMessageQueue.h"


@implementation BDSKQueueProcessor

static NSConditionLock *detachThreadLock;
static BDSKQueueProcessor *detachingQueueProcessor;

+ (void)initialize {
    BDSKINITIALIZE;
    detachThreadLock = [[NSConditionLock alloc] init];
    detachingQueueProcessor = nil;
    // This will trigger +[NSPort initialize], which registers for the NSBecomingMultiThreaded notification and avoids a race condition between NSThread and NSPort.
    [NSPort class];
}

- (id)initForQueue:(BDSKMessageQueue *)aQueue {
    if (self = [super init]) {
        messageQueue = [aQueue retain];
    }
    return self;
}

- (void)dealloc {
    [messageQueue release];
    [super dealloc];
}

- (void)continueProcessingQueue {}

- (BOOL)shouldProcessQueueEnd { return NO; }

- (void)processQueue {
    NSInvocation *invocation;
    NSAutoreleasePool *pool;
    NSTimeInterval startingInterval, endTime;
    NSTimeInterval maximumTime = 0.25; // TJW -- Bug #332 about why this time check is here by default
    
    startingInterval = [NSDate timeIntervalSinceReferenceDate];
    endTime = ( maximumTime >= 0 ) ? startingInterval + maximumTime : startingInterval;
    pool = [[NSAutoreleasePool alloc] init];
    
    if (detachingQueueProcessor == self) {
        detachingQueueProcessor = nil;
        [detachThreadLock lock];
        [detachThreadLock unlockWithCondition:0];
    }

    while (invocation = [messageQueue newInvocation]) {
        @try { [invocation invoke]; }
        @catch (NSException *e) { NSLog(@"%@: %@", invocation, [e reason]); }
        @catch (id e) { NSLog(@"%@: %@", invocation, e); }

        [invocation release];

        if (maximumTime >= 0) {
            // TJW -- Bug #332 about why this time check is here
            if (endTime < [NSDate timeIntervalSinceReferenceDate])
                break;
        }
        
        if ([self shouldProcessQueueEnd]) {
            break;
        }
        
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
    }
    
    [pool release];
}

- (void)processQueueInThread {
    detachingQueueProcessor = self;
    while (YES) {
        @try { [self processQueue]; }
        @catch (NSException *e) { NSLog(@"%@", [e reason]); }
        @catch (id e) { NSLog(@"%@", e); }
    }
}

- (void)startProcessingQueue {
    [detachThreadLock lockWhenCondition:0];
    [detachThreadLock unlockWithCondition:1];
    [NSThread detachNewThreadSelector:@selector(processQueueInThread) toTarget:self withObject:nil];
}

@end
