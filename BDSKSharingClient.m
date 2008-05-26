//
//  BDSKSharingClient.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/4/08.
/*
 This software is Copyright (c) 2008
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

#import "BDSKSharingClient.h"
#import "BDSKAsynchronousDOServer.h"
#import "BDSKSharingServer.h"
#import "BDSKPasswordController.h"

typedef struct _BDSKSharingClientFlags {
    volatile int32_t isRetrieving __attribute__ ((aligned (32)));
    volatile int32_t authenticationFailed __attribute__ ((aligned (32)));
    volatile int32_t canceledAuthentication __attribute__ ((aligned (32)));
    volatile int32_t needsAuthentication __attribute__ ((aligned (32)));
    volatile int32_t failedDownload __attribute__ ((aligned (32)));
} BDSKSharingClientFlags;    

// private protocols for inter-thread messaging
@protocol BDSKSharingClientServerLocalThread <BDSKAsyncDOServerThread>

- (oneway void)retrievePublications;

@end

@protocol BDSKSharingClientServerMainThread <BDSKAsyncDOServerMainThread>

- (oneway void)setArchivedPublications:(bycopy NSData *)publicationsArchive archivedMacros:(bycopy NSData *)macrosArchive;
- (int)runPasswordPrompt;
- (int)runAuthenticationFailedAlert;

@end

#pragma mark -

// private class for DO server. We have it as a separate object so we don't get a retain loop, we remove it from the thread runloop in the client's dealloc
@interface BDSKSharingClientServer : BDSKAsynchronousDOServer <BDSKSharingClientServerLocalThread, BDSKSharingClientServerMainThread, BDSKClientProtocol> {
    NSNetService *service;              // service with information about the remote server (BDSKSharingServer)
    BDSKSharingClient *client;             // the owner of the local server (BDSKSharingClient)
    id remoteServer;
    BDSKSharingClientFlags flags;         // state variables
    NSString *uniqueIdentifier;         // used by the remote server
}

+ (NSString *)supportedProtocolVersion;

- (id)initWithClient:(BDSKSharingClient *)aClient andService:(NSNetService *)aService;

- (BOOL)isRetrieving;
- (BOOL)needsAuthentication;
- (BOOL)failedDownload;

// proxy object for messaging the remote server
- (id <BDSKSharingProtocol>)remoteServer;

- (void)retrievePublicationsInBackground;

@end

#pragma mark -

@implementation BDSKSharingClient

#pragma mark Init and dealloc

- (id)initWithService:(NSNetService *)aService {
    NSParameterAssert(aService != nil);
    if(self = [super init]){
        name = [[aService name] copy];
        archivedPublications = nil;
        archivedMacros = nil;
        needsUpdate = YES;
        server = [[BDSKSharingClientServer alloc] initWithClient:self andService:aService];
    }
    return self;
}

- (void)dealloc {
    [server stopDOServer];
    [server release];
    [archivedPublications release];
    [archivedMacros release];
    [name release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tneeds update: %@\n\tname: %@\n }", [self class], self, (needsUpdate ? @"yes" : @"no"), name];
}

- (void)retrievePublications {
    [server retrievePublicationsInBackground];
}

- (NSData *)archivedPublications {
    return archivedPublications;
}

- (void)setArchivedPublications:(NSData *)newArchivedPublications {
    if (archivedPublications != newArchivedPublications) {
        [archivedPublications release];
        archivedPublications = [newArchivedPublications retain];
        
        [self setNeedsUpdate:NO];
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"archivedPublications", @"key", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingClientUpdatedNotification object:self userInfo:userInfo];
    }
}

- (NSData *)archivedMacros {
    return archivedMacros;
}

- (void)setArchivedMacros:(NSData *)newArchivedMacros {
    if (archivedMacros != newArchivedMacros) {
        [archivedMacros release];
        archivedMacros = [newArchivedMacros retain];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"archivedMacros", @"key", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingClientUpdatedNotification object:self userInfo:userInfo];
    }
}

- (BOOL)needsUpdate {
    return needsUpdate;
}

- (void)setNeedsUpdate:(BOOL)flag {
    needsUpdate = flag;
}

- (BOOL)isRetrieving {
    return (BOOL)[server isRetrieving];
}

- (BOOL)failedDownload {
    return [server failedDownload];
}

- (BOOL)needsAuthentication {
    return [server needsAuthentication];
}

- (NSString *)name {
    return name;
}

@end

#pragma mark -

@implementation BDSKSharingClientServer

// If we introduce incompatible changes in future, bump this to avoid sharing breakage
+ (NSString *)supportedProtocolVersion { return @"0"; }

- (id)initWithClient:(BDSKSharingClient *)aClient andService:(NSNetService *)aService;
{
    self = [super init];
    if (self) {
        client = aClient; // don't retain since it retains us
        
        service = [aService retain];
        
        // monitor changes to the TXT data
        [service setDelegate:self];
        [service startMonitoring];
        
        // set up flags
        memset(&flags, 0, sizeof(flags));
        
        // set up the authentication flag
        NSData *TXTData = [service TXTRecordData];
        if(TXTData)
            [self netService:service didUpdateTXTRecordData:TXTData];
        
        // test this to see if we've registered with the remote host
        uniqueIdentifier = nil;
        
        [self startDOServerAsync];
    }
    return self;
}

- (void)dealloc;
{
    [service setDelegate:nil];
    [service release];
    service = nil;
    [uniqueIdentifier release];
    [super dealloc];
}

#pragma mark Accessors

// BDSKClientProtocol
- (oneway void)setNeedsUpdate:(BOOL)flag { 
    // don't message the client during cleanup
    if([self shouldKeepRunning])
        [client setNeedsUpdate:flag]; 
}

- (BOOL)isAlive{ return YES; }

- (BOOL)isRetrieving { 
    OSMemoryBarrier();
    return flags.isRetrieving == 1; 
}

- (BOOL)needsAuthentication { 
    OSMemoryBarrier();
    return flags.needsAuthentication == 1; 
}

- (BOOL)failedDownload { 
    OSMemoryBarrier();
    return flags.failedDownload == 1; 
}

#pragma mark Proxies

- (id <BDSKSharingProtocol>)remoteServer;
{
    if (remoteServer != nil)
        return remoteServer;
    
    NSConnection *conn = nil;
    id proxy = nil;
    
    NSPort *sendPort = [[NSSocketPortNameServer sharedInstance] portForName:[service name] host:[service hostName]];
    
    if(sendPort == nil)
        @throw [NSString stringWithFormat:@"%@: unable to look up server %@", NSStringFromSelector(_cmd), [service hostName]];
    @try {
        conn = [NSConnection connectionWithReceivePort:nil sendPort:sendPort];
        [conn setRequestTimeout:60];
        // ask for password
        [conn setDelegate:self];
        proxy = [conn rootProxy];
    }
    @catch (id exception) {
        
        [conn setDelegate:nil];
        [conn setRootObject:nil];
        [conn invalidate];
        conn = nil;
        proxy = nil;

        // flag authentication failures so we get a prompt the next time around (in case our password was wrong)
        // we also get this if the user canceled, since an empty data will be returned
        if([exception respondsToSelector:@selector(name)] && [[exception name] isEqual:NSFailedAuthenticationException]){
            
            // if the user didn't cancel, set an auth failure flag and show an alert
            OSMemoryBarrier();
            if(flags.canceledAuthentication == 0){
                OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.authenticationFailed);
                // don't show the alert when we couldn't authenticate when cleaning up
                if([self shouldKeepRunning]){
                    [[self serverOnMainThread] runAuthenticationFailedAlert];
                }
            }
            
        } else {
            @throw [NSString stringWithFormat:@"%@: exception \"%@\" while connecting to remote server %@", NSStringFromSelector(_cmd), exception, [service hostName]];
        }
    }

    if (proxy != nil) {
        [proxy setProtocolForProxy:@protocol(BDSKSharingProtocol)];
        
        if(uniqueIdentifier == nil){
            // use uniqueIdentifier as the notification identifier for this host on the other end
            CFUUIDRef uuid = CFUUIDCreate(NULL);
            uniqueIdentifier = (id)CFUUIDCreateString(NULL, uuid);
            CFRelease(uuid);
            @try {
                NSProtocolChecker *checker = [NSProtocolChecker protocolCheckerWithTarget:self protocol:@protocol(BDSKClientProtocol)];
                [proxy registerClient:checker forIdentifier:uniqueIdentifier version:[BDSKSharingClientServer supportedProtocolVersion]];
            }
            @catch(id exception) {
                [uniqueIdentifier release];
                uniqueIdentifier = nil;
                NSLog(@"%@: unable to register with remote server %@", [self class], [service hostName]);
                // don't throw; this isn't critical
            }
        }
    }
    
    remoteServer = [proxy retain];
    return remoteServer;
}

#pragma mark Authentication

- (int)runPasswordPrompt;
{
    NSAssert([NSThread inMainThread] == 1, @"password controller must be run from the main thread");
    BDSKPasswordController *pwc = [[BDSKPasswordController alloc] init];
    int rv = [pwc runModalForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[service name]] message:[NSString stringWithFormat:NSLocalizedString(@"Enter password for %@", @"Prompt for Password dialog"), [service name]]];
    [pwc close];
    [pwc release];
    return rv;
}

- (int)runAuthenticationFailedAlert;
{
    NSAssert([NSThread inMainThread] == 1, @"runAuthenticationFailedAlert must be run from the main thread");
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Authentication Failed", @"Message in alert dialog when authentication failed")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Incorrect password for BibDesk Sharing on server %@.  Reselect to try again.", @"Informative text in alert dialog"), [service name]];
    return [alert runModal];
}

// this can be called from any thread
- (NSData *)authenticationDataForComponents:(NSArray *)components;
{
    OSMemoryBarrier();
    if(flags.needsAuthentication == 0)
        return [[NSData data] sha1Signature];
    
    NSData *password = nil;
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.canceledAuthentication);
    
    int rv = 1;
    OSMemoryBarrier();
    if(flags.authenticationFailed == 0)
        password = [BDSKPasswordController passwordHashedForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[service name]]];
    
    if(password == nil && [self shouldKeepRunning]){   
        
        // run the prompt on the main thread
        rv = [[self serverOnMainThread] runPasswordPrompt];
        
        // retry from the keychain
        if (rv == BDSKPasswordReturn){
            password = [BDSKPasswordController passwordHashedForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[service name]]];
            // assume we succeeded; the exception handler for the connection will change it back if we fail again
            OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.authenticationFailed);
        }else{
            OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.canceledAuthentication);
        }
    }
    
    // doc says we're required to return empty NSData instead of nil
    return password ? password : [NSData data];
}

// monitor the TXT record in case the server changes password requirements
- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data;
{
    OBASSERT(sender == service);
    OBASSERT(data != nil);
    if(data){
        NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:data];
        int32_t val = [[NSString stringWithData:[dict objectForKey:BDSKTXTAuthenticateKey] encoding:NSUTF8StringEncoding] intValue];
        OSMemoryBarrier();
        int32_t oldVal = flags.needsAuthentication;
        OSAtomicCompareAndSwap32Barrier(oldVal, val, (int32_t *)&flags.needsAuthentication);
    }
}

#pragma mark ServerThread

- (Protocol *)protocolForServerThread { return @protocol(BDSKSharingClientServerLocalThread); }
- (Protocol *)protocolForMainThread { return @protocol(BDSKSharingClientServerMainThread); }

- (oneway void)setArchivedPublications:(bycopy NSData *)publicationsArchive archivedMacros:(bycopy NSData *)macrosArchive;
{
    if (macrosArchive)
        [client setArchivedMacros:macrosArchive];
    [client setArchivedPublications:publicationsArchive];
}

- (void)retrievePublicationsInBackground{ [[self serverOnServerThread] retrievePublications]; }

- (oneway void)retrievePublications;
{
    // set so we don't try calling this multiple times
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.isRetrieving);
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.failedDownload);
    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    @try {
        NSData *archive = nil;
        NSData *macroArchive = nil;
        NSData *proxyData = [[self remoteServer] archivedSnapshotOfPublications];
        
        if([proxyData length] != 0){
            if([proxyData mightBeCompressed])
                proxyData = [proxyData decompressedData];
            NSString *errorString = nil;
            NSDictionary *dictionary = [NSPropertyListSerialization propertyListFromData:proxyData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&errorString];
            if(errorString != nil){
                NSString *errorStr = [NSString stringWithFormat:@"Error reading shared data: %@", errorString];
                [errorString release];
                @throw errorStr;
            } else {
                archive = [dictionary objectForKey:BDSKSharedArchivedDataKey];
                macroArchive = [dictionary objectForKey:BDSKSharedArchivedMacroDataKey];
            }
        }
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
        // use the main thread; this avoids an extra (un)archiving between threads and it ends up posting notifications for UI updates
        [[self serverOnMainThread] setArchivedPublications:archive archivedMacros:macroArchive];
    }
    @catch(id exception){
        NSLog(@"%@: discarding exception \"%@\" while retrieving publications", [self class], exception);
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.failedDownload);
        
        // this posts a notification that the publications of the client changed, forcing a redisplay of the table cell
        [client performSelectorOnMainThread:@selector(setArchivedPublications:) withObject:nil waitUntilDone:NO];
    }
    @finally{
        [pool release];
    }
}

- (oneway void)cleanup;
{
    // clean up our remote end
    if (uniqueIdentifier != nil){
        @try {
            [remoteServer removeClientForIdentifier:uniqueIdentifier];
        }
        @catch(id exception) {
            NSLog(@"%@ ignoring exception \"%@\" raised during cleanup", [self class], exception);
        }
    }
    if (remoteServer != nil){
        NSConnection *conn = [remoteServer connectionForProxy];
        [conn setDelegate:nil];
        [conn setRootObject:nil];
        [[conn receivePort] invalidate];
        [conn invalidate];
        [remoteServer release];
        remoteServer = nil;
    }
    
    [super cleanup];
}

- (oneway void)invalidate
{
    // set this to nil so we won't try to get back to the remote server
    [uniqueIdentifier release];
    uniqueIdentifier = nil;
}

@end
