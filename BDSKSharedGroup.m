//
//  BDSKSharedGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/03/06.
/*
 This software is Copyright (c) 2006
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

#import "BDSKSharedGroup.h"
#import "BDSKSharingServer.h"
#import "BDSKPasswordController.h"
#import "NSArray_BDSKExtensions.h"
#import "NSImage+Toolbox.h"
#import <libkern/OSAtomic.h>

// private methods for inter-thread messaging
@protocol BDSKSharedGroupServerThread

- (void)_cleanupBDSKSharedGroupDOServer;
- (void)_retrievePublicationsBDSKSharedGroupDOServer;
- (int)runPasswordPrompt;
- (int)runAuthenticationFailedAlert;

@end

@implementation BDSKSharedGroup

/* @@ Warning: retain cycle, since the NSThread retains us (and we keep running it).  Best option may be to convert this server to a separate object, and each shared group will "own" one, and then stop it when the group is deallocated.  For now, we have the owner call stopDOServer when the app terminates or a host goes away, which ensures that shared groups are dealloced properly. */

- (id)initWithService:(NSNetService *)aService;
{
    NSParameterAssert(aService != nil);
    if(self = [super initWithName:@"" key:@"" count:0]){
        service = [aService retain];

        publications = nil;
        needsUpdate = YES;
        
        static int connectionIdx = 0;
        // this needs to be unique on the network and among our shared groups
        serverSharingName = [[NSString alloc] initWithFormat:@"%@%@%d", [[NSHost currentHost] name], [[self class] description], connectionIdx++];
        // this just needs to be unique on localhost
        localConnectionName = [[NSString alloc] initWithFormat:@"%@%d", [[self class] description], connectionIdx++];

        mainThreadConnection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
        [mainThreadConnection setRootObject:self];
        [mainThreadConnection enableMultipleThreads];
        
        // set up flags
        memset(&flags, 0, sizeof(flags));
        flags.shouldKeepRunning = 1;
        connection = nil;

        // if we detach in -publications, connection setup doesn't happen in time
        [NSThread detachNewThreadSelector:@selector(runDOServer) toTarget:self withObject:nil];

    }
    
    return self;
}

- (void)dealloc
{
    [service release];
    [publications release];
    [serverSharingName release];
    [localConnectionName release];
    [super dealloc];
}

- (oneway void)setNeedsUpdate:(BOOL)flag
{
    // this is only called from the DO thread
    needsUpdate = flag;
}

- (void)stopDOServer;
{
    // we're in the main thread, so set the stop flag
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.shouldKeepRunning);
    NSConnection *conn = [NSConnection connectionWithRegisteredName:localConnectionName host:nil];
    if(conn == nil)
        NSLog(@"-[%@ %@]: unable to get thread connection", [self class], NSStringFromSelector(_cmd));
    id proxy = [conn rootProxy];
    [proxy setProtocolForProxy:@protocol(BDSKSharedGroupServerThread)];
    [proxy _cleanupBDSKSharedGroupDOServer];
        
    [mainThreadConnection invalidate];
    [mainThreadConnection setRootObject:nil];
    [mainThreadConnection release];
    mainThreadConnection = nil;
}

- (void)retrievePublications;
{
    NSConnection *conn = [NSConnection connectionWithRegisteredName:localConnectionName host:nil];
    if(conn == nil)
        NSLog(@"-[%@ %@]: unable to get thread connection", [self class], NSStringFromSelector(_cmd));
    id proxy = [conn rootProxy];
    [proxy setProtocolForProxy:@protocol(BDSKSharedGroupServerThread)];
    [proxy _retrievePublicationsBDSKSharedGroupDOServer]; 
}

- (NSString *)name { return [[[service name] retain] autorelease]; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tneeds update: %@\n\tname: %@\nservice: %@\n }", [self class], self, (needsUpdate ? @"yes" : @"no"), [self name], service];
}

- (NSArray *)publications
{
    if(flags.isRetrieving == 0 && (needsUpdate == YES || publications == nil)){
        [self retrievePublications];
    }
    // this will likely be nil the first time; retain since our server thread could release it at any time
    return [[publications retain] autorelease];
}

- (BOOL)containsItem:(BibItem *)item {
    // calling [self publications] will repeatedly reschedule a retrieval, which is undesirable if the user cancels; containsItem is called very frequently
    NSArray *pubs = [publications retain];
    BOOL rv = [pubs containsObject:item];
    [pubs release];
    return rv;
}

- (NSNetService *)service { return service; }

- (NSImage *)icon {
	return [NSImage smallImageNamed:@"sharedFolderIcon"];
}

- (BOOL)isShared { return YES; }

- (BOOL)hasEditableName { return NO; }

#pragma mark -
#pragma mark Authentication

- (int)runPasswordPrompt
{
    NSAssert([NSThread inMainThread] == 1, @"password controller must be run from the main thread");
    BDSKPasswordController *pwc = [[BDSKPasswordController alloc] init];
    int rv = [pwc runModalForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[self name]] message:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Enter password for", @""), [self name]]];
    [pwc close];
    [pwc release];
    return rv;
}

- (int)runAuthenticationFailedAlert
{
    NSAssert([NSThread inMainThread] == 1, @"runAuthenticationFailedAlert must be run from the main thread");
    return NSRunAlertPanel(NSLocalizedString(@"Authentication Failed", @""), [NSString stringWithFormat:NSLocalizedString(@"Incorrect password for BibDesk Sharing on server %@.  Reselect to try again.", @""), [service name]], nil, nil, nil);
}

- (BOOL)connection:(NSConnection *)parentConnection shouldMakeNewConnection:(NSConnection *)newConnection
{
    // set the child connection's delegate so we get authentication messages
    [newConnection setDelegate:self];
    return YES;
}

// this can be called from any thread
- (NSData *)authenticationDataForComponents:(NSArray *)components;
{
    NSData *password = nil;
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.canceledAuthentication);
    
    int rv = 1;
    if(flags.authenticationFailed == 0)
        password = [BDSKPasswordController passwordHashedForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[self name]]];
    
    if(password == nil){   
        
        // run the prompt on the main thread
        id proxy = nil;
        @try {
            // we have to create our own connection to the mainThreadConnection's ports
            NSConnection *conn = [NSConnection connectionWithReceivePort:nil sendPort:[mainThreadConnection receivePort]];
            proxy = [conn rootProxy];
            [proxy setProtocolForProxy:@protocol(BDSKSharedGroupServerThread)];
            rv = [proxy runPasswordPrompt];
        }
        @catch(id exception) {
            NSLog(@"Unable to connect to main thread and run password prompt.");
            proxy = nil;
        }
        
        // retry from the keychain
        if (rv == BDSKPasswordReturn){
            password = [BDSKPasswordController passwordHashedForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[self name]]];
            // assume we succeeded; the exception handler for the connection will change it back if we fail again
            OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.authenticationFailed);
        }else{
            OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.canceledAuthentication);
        }
    }
    
    // doc says we're required to return empty NSData instead of nil
    return password ? password : [NSData data];
}

#pragma mark ServerThread

- (void)notifyOnMainThreadWhenDone
{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupFinishedNotification object:self];
}

- (void)_retrievePublicationsBDSKSharedGroupDOServer;
{
    
    // set so we don't try calling this multiple times
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.isRetrieving);
    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    @try {
        NSConnection *conn = nil;
        id proxyObject;
        
        NSData *TXTData = [service TXTRecordData];
        NSDictionary *dict = nil;
        if(TXTData)
            dict = [NSNetService dictionaryFromTXTRecordData:TXTData];
        
        // we need the port name from the TXTRecord
        NSString *portName = [NSString stringWithData:[dict objectForKey:BDSKTXTComputerNameKey] encoding:NSUTF8StringEncoding];
        NSPort *sendPort = [[NSSocketPortNameServer sharedInstance] portForName:portName host:[service hostName]];
        
        if(sendPort == nil)
            NSLog(@"client: unable to look up server %@", [service hostName]);
        @try {
            conn = [NSConnection connectionWithReceivePort:nil sendPort:sendPort];
            // ask for password
            [conn setDelegate:self];
            proxyObject = [conn rootProxy];
        }
        @catch (id exception) {
            // flag authentication failures so we get a prompt the next time around (in case our password was wrong)
            // we also get this if the user canceled, since an empty data will be returned
            if([exception respondsToSelector:@selector(name)] && [[exception name] isEqualToString:NSFailedAuthenticationException]){
                
                // if the user didn't cancel, set an auth failure flag and show an alert
                if(flags.canceledAuthentication == 0){
                    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.authenticationFailed);
                    
                    conn = [NSConnection connectionWithReceivePort:nil sendPort:[mainThreadConnection receivePort]];
                    proxyObject = [conn rootProxy];
                    [proxyObject setProtocolForProxy:@protocol(BDSKSharedGroupServerThread)];
                    [proxyObject runAuthenticationFailedAlert];
                }
                
            } else if(flags.canceledAuthentication == 0){
                // don't log auth failures
                NSLog(@"client: %@", exception);
            }
            conn = nil;
            proxyObject = nil;
        }
        
        [proxyObject setProtocolForProxy:@protocol(BDSKSharingProtocol)];
        
        // need hostname and portname for the NSSocketPort connection on the other end
        // use computer as the notification identifier for this host on the other end
        [proxyObject registerHostNameForNotifications:[NSDictionary dictionaryWithObjectsAndKeys:[[NSHost currentHost] name], @"hostname", serverSharingName, @"portname", [BDSKSharingServer sharingName], @"computer", nil]];
        
        [publications autorelease];
        publications = nil;
        
        NSData *proxyData = [proxyObject archivedSnapshotOfPublications];
        
        if([proxyData length] != 0){
            NSString *errorString = nil;
            NSDictionary *dictionary = [NSPropertyListSerialization propertyListFromData:proxyData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&errorString];
            if(errorString != nil){
                NSLog(@"Error reading shared data: %@", errorString);
                [errorString release];
            } else {
                NSData *archive = [dictionary objectForKey:BDSKSharedArchivedDataKey];
                if(archive != nil){
                    publications = [[NSKeyedUnarchiver unarchiveObjectWithData:archive] retain];
                }
            }
        }    
        [self setCount:[publications count]];
        if([publications count]){
            [self setNeedsUpdate:NO];
            
            // post the notification on the main thread; this ends up calling UI updates
            id proxy = nil;
            @try {
                conn = [NSConnection connectionWithReceivePort:nil sendPort:[mainThreadConnection receivePort]];
                proxy = [conn rootProxy];
                [proxy setProtocolForProxy:@protocol(BDSKSharedGroupServerThread)];
                [proxy notifyOnMainThreadWhenDone];
            }
            @catch(id exception) {
                NSLog(@"Unable to connect to main thread and notify.");
                proxy = nil;
            }            
        }
    }
    @catch(id exception){
        NSLog(@"%@: discarding exception %@ while retrieving publications", [self class], exception);
    }
    @finally{
        [pool release];
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
    }
}

- (void)_cleanupBDSKSharedGroupDOServer;
{
    // must be on the background thread, or the connection won't be removed from the correct run loop
    [[NSSocketPortNameServer sharedInstance] removePortForName:serverSharingName];
    [connection invalidate];
    [connection setRootObject:nil];
    [connection release];
    connection = nil;
    
    // defaultConnection is still retaining us...
    [[NSConnection defaultConnection] setRootObject:nil];
    [[NSConnection defaultConnection] registerName:nil];
    
    // this seems dirty, but we need to unblock and allow the thread to release us
    CFRunLoopStop( CFRunLoopGetCurrent() );
}

- (void)runDOServer;
{
    // detach a new thread to run this
    NSAssert([NSThread inMainThread] == NO, @"do not run the server in the main thread");
    NSAssert(connection == nil, @"server is already running");

    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.shouldKeepRunning);
    NSSocketPort *receivePort = [[[NSSocketPort alloc] init] autorelease];
    
    @try {
        if([[NSSocketPortNameServer sharedInstance] registerPort:receivePort name:serverSharingName] == NO)
            @throw [NSString stringWithFormat:@"Unable to register port %@ and name %@", receivePort, [BDSKSharingServer sharingName]];
        
        // this is our public server name for receiving change notifications from the remote server
        connection = [[NSConnection alloc] initWithReceivePort:receivePort sendPort:nil];
        
        // connection retains us also...
        [connection setRootObject:self];
        
        // don't set the delegate, as we don't authenticate connections here (this connection won't be used if we can't authenticate in the first place)
        
        // we'll use this to communicate between threads on the localhost
        // @@ does this succeed after a stop/restart with a new thread?
        NSConnection *threadConnection = [NSConnection defaultConnection];
        if(threadConnection == nil)
            @throw @"Unable to get default connection";
        [threadConnection setRootObject:self];
        if([threadConnection registerName:localConnectionName] == NO)
            @throw @"Unable to register local connection";        
        
        do {
            [pool release];
            pool = [NSAutoreleasePool new];
            CFRunLoopRun();
        } while (flags.shouldKeepRunning == 1);
    }
    @catch(id exception) {
        [connection release];
        connection = nil;
        NSLog(@"Discarding exception %@ raised in object %@", exception, self);
        // reset the flag so we can start over; shouldn't be necessary
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.shouldKeepRunning);
    }
    
    @finally {
        [pool release];
    }
}

@end


