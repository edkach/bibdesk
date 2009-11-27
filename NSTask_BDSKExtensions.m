//
//  BDSKShellTask.m
//  BibDesk
//
//  Created by Michael McCracken on Sat Dec 14 2002.
/*
 This software is Copyright (c) 2002-2009
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

#import "NSTask_BDSKExtensions.h"
#import "BDSKAppController.h"
#import "NSFileManager_BDSKExtensions.h"
#import <sys/stat.h>

#define BDSKSpecialPipeServiceRunLoopMode @"BDSKSpecialPipeServiceRunLoopMode"

@interface BDSKShellTask : NSObject {
    NSTask *task;
    // data used to store stdOut from the filter
    NSData *stdoutData;
}
- (id)initWithTask:(NSTask *)aTask;
- (NSData *)outputDataFromShellCommand:(NSString *)cmd inputData:(NSData *)input;
- (void)stdoutNowAvailable:(NSNotification *)notification;
@end


@implementation NSTask (BDSKExtensions)

+ (NSString *)outputStringFromShellCommand:(NSString *)cmd inputString:(NSString *)input{
    NSData *outputData = [self outputDataFromShellCommand:cmd inputString:input];
    NSString *output = nil;
    if(outputData){
        output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        if(!output)
            output = [[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding];
        if(!output)
            output = [[NSString alloc] initWithData:outputData encoding:[NSString defaultCStringEncoding]];
    }
    return [output autorelease];
}

+ (NSData *)outputDataFromShellCommand:(NSString *)cmd inputString:(NSString *)input{
    return [self outputDataFromShellCommand:cmd inputData:[input dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (NSData *)outputDataFromShellCommand:(NSString *)cmd inputData:(NSData *)input{
    BDSKShellTask *shellTask = [[BDSKShellTask alloc] initWithTask:[[[self alloc] init] autorelease]];
    NSData *output = [[shellTask outputDataFromShellCommand:cmd inputData:input] retain];
    [shellTask release];
    return [output autorelease];
}

@end


@implementation BDSKShellTask

- (id)init{
    return [self initWithTask:nil];
}

- (id)initWithTask:(NSTask *)aTask{
    if (self = [super init]) {
        task = [aTask retain] ?: [[NSTask alloc] init];
    }
    return self;
}

- (void)dealloc{
    [task release];
    [stdoutData release];
    [super dealloc];
}

//
// The following three methods are borrowed from Mike Ferris' TextExtras.
// For the real versions of them, check out http://www.lorax.com/FreeStuff/TextExtras.html
// - mmcc

// was runWithInputString in TextExtras' TEPipeCommand class.
- (NSData *)outputDataFromShellCommand:(NSString *)cmd inputData:(NSData *)input{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *shellPath = @"/bin/sh";
    NSString *tmpDir;
    NSString *script;
    NSData *scriptData;
    NSMutableDictionary *currentAttributes;
    NSUInteger currentMode;
    NSPipe *inputPipe;
    NSPipe *outputPipe;
    NSFileHandle *inputFileHandle;
    NSFileHandle *outputFileHandle;
    
    // ---------- Check the shell and create the script ----------
    if (![fm isExecutableFileAtPath:shellPath]) {
        NSLog(@"Filter Pipes: Shell path for Pipe panel does not exist or is not executable. (%@)", shellPath);
        return nil;
    }
    if (!cmd){
        return nil;
    }
    
    // ---------- Execute the script ----------
    [task setLaunchPath:shellPath];
    [task setArguments:[NSArray arrayWithObject:cmd]];
    
    // MF:!!! The current working dir isn't too appropriate
    tmpDir = [[NSFileManager defaultManager] makeTemporaryDirectoryWithBasename:nil];
    [task setCurrentDirectoryPath:tmpDir];

    [task setStandardError:[NSFileHandle fileHandleWithStandardError]];
    inputPipe = [NSPipe pipe];
    inputFileHandle = [inputPipe fileHandleForWriting];
    [task setStandardInput:inputPipe];
    outputPipe = [NSPipe pipe];
    outputFileHandle = [outputPipe fileHandleForReading];
    [task setStandardOutput:outputPipe];
    
    // ignore SIGPIPE, as it causes a crash (seems to happen if the binaries don't exist and you try writing to the pipe)
    sig_t previousSignalMask = signal(SIGPIPE, SIG_IGN);
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(stdoutNowAvailable:) name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
    [outputFileHandle readToEndOfFileInBackgroundAndNotifyForModes:[NSArray arrayWithObject:BDSKSpecialPipeServiceRunLoopMode]];
    
    @try{

        [task launch];

        if ([task isRunning]) {
            
            if (input)
                [inputFileHandle writeData:input];
            [inputFileHandle closeFile];
            
            // run the runloop and pick up our notifications
            while (nil == stdoutData && ([task isRunning] || [task terminationStatus] == 0))
                [[NSRunLoop currentRunLoop] runMode:BDSKSpecialPipeServiceRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            [task waitUntilExit];
            
            [nc removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
            
        } else {
            NSLog(@"Failed to launch task for \"%@\" or it exited without accepting input.  Termination status was %d", cmd, [task terminationStatus]);
        }
    }
    @catch(id exception){
        // if the pipe failed, we catch an exception here and ignore it
        NSLog(@"exception %@ encountered while trying to run task %@", exception, cmd);
        [nc removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
    }
    
    // reset signal handling to default behavior
    signal(SIGPIPE, previousSignalMask);

    // ---------- Remove the script file ----------
    if (![fm removeItemAtPath:tmpDir error:NULL]) {
        NSLog(@"Filter Pipes: Failed to delete temporary directory. (%@)", tmpDir);
    }

    return [task terminationStatus] == 0 ? [[stdoutData retain] autorelease] : nil;
}

- (void)stdoutNowAvailable:(NSNotification *)notification {
    NSData *outputData = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([outputData length])
        stdoutData = [outputData retain];
}

@end
