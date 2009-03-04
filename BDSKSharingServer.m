//
//  BDSKSharingServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/02/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKSharingServer.h"
#import "BDSKSharedGroup.h"
#import "BDSKSharingBrowser.h"
#import "BDSKPasswordController.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "NSArray_BDSKExtensions.h"
#import "NSData_BDSKExtensions.h"
#import "BibItem.h"
#import "BibDocument.h"
#import <libkern/OSAtomic.h>
#import "BDSKSharedGroup.h"
#import "BDSKAsynchronousDOServer.h"
#import "BDSKThreadSafeMutableDictionary.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

#define MAX_TRY_COUNT 20

static id sharedInstance = nil;

// TXT record keys
NSString *BDSKTXTAuthenticateKey = @"authenticate";
NSString *BDSKTXTVersionKey = @"txtvers";

NSString *BDSKSharedArchivedDataKey = @"publications_v1";
NSString *BDSKSharedArchivedMacroDataKey = @"macros_v1";

NSString *BDSKComputerNameChangedNotification = nil;
NSString *BDSKHostNameChangedNotification = nil;

NSString *BDSKServiceNameForKeychain = @"BibDesk Sharing";

static SCDynamicStoreRef dynamicStore = NULL;
static const void *retainCallBack(const void *info) { return [(id)info retain]; }
static void releaseCallBack(const void *info) { [(id)info release]; }
static CFStringRef copyDescriptionCallBack(const void *info) { return (CFStringRef)[[(id)info description] copy]; }
// convert this to an NSNotification
static void SCDynamicStoreChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    CFIndex cnt = CFArrayGetCount(changedKeys);
    NSString *key;
    while(cnt--){
        key = (id)CFArrayGetValueAtIndex(changedKeys, cnt);
        [[NSNotificationCenter defaultCenter] postNotificationName:key object:nil];
    }
    
    // update the text field in prefs if necessary (or that could listen for computer name changes...)
    if([NSString isEmptyString:[[NSUserDefaults standardUserDefaults] objectForKey:BDSKSharingNameKey]])
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingNameChangedNotification object:nil];
    [pool release];
}

#pragma mark -

// private protocol for inter-thread messaging
@protocol BDSKSharingServerLocalThread <BDSKAsyncDOServerThread>

- (oneway void)notifyClientsOfChange;
- (oneway void)mainThreadServerDidSetup:(BOOL)success;

@end

#pragma mark -

@interface BDSKSharingDOServer : BDSKAsynchronousDOServer <BDSKSharingServerLocalThread> {
    BDSKSharingServer *sharingServer;
    NSString *sharingName;
    NSConnection *connection;
    BDSKThreadSafeMutableDictionary *remoteClients;
}

+ (NSString *)requiredProtocolVersion;

- (id)initForSharingServer:(BDSKSharingServer *)aSharingServer;

- (unsigned int)numberOfConnections;
- (void)notifyClientConnectionsChanged;
- (NSArray *)copyPublicationsFromOpenDocuments;
- (NSDictionary *)copyMacrosFromOpenDocuments;

@end

#pragma mark -

@implementation BDSKSharingServer

+ (void)initialize;
{
    BDSKINITIALIZE;
    
    // Ensure that computer name changes are propagated as future clients connect to a document.  Also, note that the OS will change the computer name to avoid conflicts by appending "(2)" or similar to the previous name, which is likely the most common scenario.
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    CFRetain(alloc); // make sure this is maintained for the life of the program
    SCDynamicStoreContext SCNSObjectContext = {
        0,                         // version
        (id)nil,                   // any NSCF type
        &retainCallBack,
        &releaseCallBack,
        &copyDescriptionCallBack
    };
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    if (NULL == mainBundle) {
        fprintf(stderr, "Unable to get main bundle; this should never happen\n");
    }
    else {
        CFStringRef bundleID = CFBundleGetIdentifier(mainBundle);
        dynamicStore = SCDynamicStoreCreate(alloc, bundleID, &SCDynamicStoreChanged, &SCNSObjectContext);
        CFRunLoopSourceRef rlSource = SCDynamicStoreCreateRunLoopSource(alloc, dynamicStore, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rlSource, kCFRunLoopCommonModes);
        CFRelease(rlSource);
        
        CFMutableArrayRef keys = CFArrayCreateMutable(alloc, 0, &kCFTypeArrayCallBacks);
        
        // use SCDynamicStore keys as NSNotification names; don't release them
        CFStringRef key = SCDynamicStoreKeyCreateComputerName(alloc);
        CFArrayAppendValue(keys, key);
        BDSKComputerNameChangedNotification = (NSString *)key;
        
        key = SCDynamicStoreKeyCreateHostNames(alloc);
        CFArrayAppendValue(keys, key);
        BDSKHostNameChangedNotification = (NSString *)key;
        
        BDSKASSERT(BDSKComputerNameChangedNotification);
        BDSKASSERT(BDSKHostNameChangedNotification);
            
        if(SCDynamicStoreSetNotificationKeys(dynamicStore, keys, NULL) == FALSE)
            fprintf(stderr, "unable to register for dynamic store notifications.\n");
        CFRelease(keys);
    }
}

// base name for sharing (also used for storing remote host names in keychain)
+ (NSString *)defaultSharingName;
{
    // docs say to use computer name instead of host name http://developer.apple.com/qa/qa2001/qa1228.html
    NSString *sharingName = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKSharingNameKey];
    BDSKASSERT(dynamicStore);
    // default to the computer name as set in sys prefs (sharing)
    if([NSString isEmptyString:sharingName])
        sharingName = [(id)SCDynamicStoreCopyComputerName(dynamicStore, NULL) autorelease];
    BDSKPOSTCONDITION(sharingName);
    return sharingName;
}

// If we introduce incompatible changes in future, bump this to avoid sharing breakage
+ (NSString *)supportedProtocolVersion { return @"0"; }

+ (id)defaultServer;
{
    if(sharedInstance == nil)
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

- (NSString *)sharingName {
    return [[sharingName retain] autorelease];
}

- (void)setSharingName:(NSString *)newName {
    if (sharingName != newName) {
        [sharingName release];
        sharingName = [newName retain];
    }
}

- (BOOL)isSharing {
    return isSharing;
}

- (unsigned int)numberOfConnections { 
    // minor thread-safety issue here; this may be off by one
    return [server numberOfConnections]; 
}

- (void)handleQueuedDataChanged;
{
    // not the default connection here; we want to call our background thread, but only if it's running
    // add a hidden pref in case this traffic turns us into a bad network citizen; manual updates will still work
    if([server shouldKeepRunning] && [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableRemoteChangeNotifications"] == 0){
        [[server serverOnServerThread] notifyClientsOfChange];
    }    
}

// we'll get these notifications on the main thread, and pass off to our secondary thread to handle; they're queued to reduce network traffic
- (void)queueDataChangedNotification:(NSNotification *)note;
{
    SEL theSEL = @selector(handleQueuedDataChanged);
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:theSEL object:nil];
    [self performSelector:theSEL withObject:nil afterDelay:5.0];
}

//  handle changes from the OS
- (void)handleComputerNameChangedNotification:(NSNotification *)note;
{
    // if we're using the computer name, restart sharing so the name propagates correctly; avoid conflicts with other users' share names
    if([NSString isEmptyString:[[NSUserDefaults standardUserDefaults] objectForKey:BDSKSharingNameKey]])
        [self restartSharingIfNeeded];
}

// handle changes from prefs
- (void)handleSharingNameChangedNotification:(NSNotification *)note;
{
    [self restartSharingIfNeeded];
}

- (void)handlePasswordChangedNotification:(NSNotification *)note;
{
    [self restartSharingIfNeeded];
}

- (NSNetService *)newNetServiceWithSharingName:(NSString *)aSharingName {
    uint16_t chosenPort = 0;
    
    // Here, create the socket from traditional BSD socket calls
    int fdForListening;
    struct sockaddr_in serverAddress;
    socklen_t namelen = sizeof(serverAddress);
    
    if((fdForListening = socket(AF_INET, SOCK_STREAM, 0)) > 0) {
        memset(&serverAddress, 0, sizeof(serverAddress));
        serverAddress.sin_family = AF_INET;
        serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
        serverAddress.sin_port = 0; // allows the kernel to choose the port for us.
        
        if(bind(fdForListening, (struct sockaddr *)&serverAddress, sizeof(serverAddress)) < 0) {
            close(fdForListening);
            return nil;
        }
        
        // Find out what port number was chosen for us.
        if(getsockname(fdForListening, (struct sockaddr *)&serverAddress, &namelen) < 0) {
            close(fdForListening);
            return nil;
        }
        
        chosenPort = ntohs(serverAddress.sin_port);
    }
    
    NSNetService *aNetService = [[NSNetService alloc] initWithDomain:@"" type:BDSKNetServiceDomain name:aSharingName port:chosenPort];
    [aNetService setDelegate:self];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    [dictionary setObject:[BDSKSharingServer supportedProtocolVersion] forKey:BDSKTXTVersionKey];
    [dictionary setObject:[[NSUserDefaults standardUserDefaults] stringForKey:BDSKSharingRequiresPasswordKey] forKey:BDSKTXTAuthenticateKey];
    [aNetService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:dictionary]];
    
    return aNetService;
}

- (void)_enableSharing
{
    if(server == nil){
        // we're not yet sharing
        
        server = [[BDSKSharingDOServer alloc] initForSharingServer:self];
        // the netService is created in the callback
    }
}

- (void)enableSharing
{
    // only restart when there's something to share, the next document that's opened will otherwise call again if necessary
    if(server == nil && [[NSApp orderedDocuments] count] > 0){
        // we're not yet sharing and we've got something to share
        
        tryCount = 0;
        [self setSharingName:[BDSKSharingServer defaultSharingName]];
        
        [self _enableSharing];
    }
}

- (void)disableSharing
{
    // CMH: is the check for shouldKeepRunning correct?
    if(server != nil && [server shouldKeepRunning]){
        [netService setDelegate:nil];
        [netService stop];
        [netService release];
        netService = nil;
        
        [server stopDOServer];
        [server release];
        server = nil;
        
        // unregister for notifications
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        [nc removeObserver:self name:BDSKComputerNameChangedNotification object:nil];
        [nc removeObserver:self name:BDSKSharingPasswordChangedNotification object:nil];
        [nc removeObserver:self name:BDSKDocumentControllerAddDocumentNotification object:nil];
        [nc removeObserver:self name:BDSKDocumentControllerRemoveDocumentNotification object:nil];                                                       
        [nc removeObserver:self name:BDSKDocAddItemNotification object:nil];
        [nc removeObserver:self name:BDSKDocDelItemNotification object:nil];
        [nc removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
    }
    
    [self setSharingName:nil];
    isSharing = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingStatusChangedNotification object:nil];
}

- (void)restartSharingIfNeeded;
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldShareFilesKey]){
        [self disableSharing];
        [self performSelector:@selector(enableSharing) withObject:nil afterDelay:3.0];
    }
}

- (void)server:(BDSKSharingDOServer *)aServer didSetup:(BOOL)success {
    BDSKASSERT(aServer == server || server == nil);
    if (success) {
        // the service was able to register the port
        
        BDSKPRECONDITION(netService == nil);
        
        // lazily instantiate the NSNetService object that will advertise on our behalf
        netService = [self newNetServiceWithSharingName:[self sharingName]];
        
        BDSKPOSTCONDITION(netService != nil);
        
        if (netService) {
            // our DO server will also use Bonjour, but this gives us a browseable name
            [netService publish];
            
            // register for notifications
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            
            BDSKASSERT(BDSKComputerNameChangedNotification);
            
            [nc addObserver:self
                   selector:@selector(handleComputerNameChangedNotification:)
                       name:BDSKComputerNameChangedNotification
                     object:nil];
            
            [nc addObserver:self
                   selector:@selector(handlePasswordChangedNotification:)
                       name:BDSKSharingPasswordChangedNotification
                     object:nil];
            
            [nc addObserver:self
                   selector:@selector(queueDataChangedNotification:)
                       name:BDSKDocumentControllerAddDocumentNotification
                     object:nil];

            [nc addObserver:self
                   selector:@selector(queueDataChangedNotification:)
                       name:BDSKDocumentControllerRemoveDocumentNotification
                     object:nil];                     
                         
            [nc addObserver:self
                   selector:@selector(queueDataChangedNotification:)
                       name:BDSKDocAddItemNotification
                     object:nil];

            [nc addObserver:self
                   selector:@selector(queueDataChangedNotification:)
                       name:BDSKDocDelItemNotification
                     object:nil];
            
            [nc addObserver:self
                   selector:@selector(handleApplicationWillTerminate:)
                       name:NSApplicationWillTerminateNotification
                     object:nil];
        } else {
            [self disableSharing];
        }
        
    } else {
        // the service was not able to register the port
        
        // shouldn't happen
        if (server != aServer)
            [aServer stopDOServer];
        
        [server stopDOServer];
        [server release];
        server = nil;
        
        // try again with a different name
        if (tryCount < MAX_TRY_COUNT) {
            [self setSharingName:[NSString stringWithFormat:@"%@-%i", [BDSKSharingServer defaultSharingName], ++tryCount]];
            [self _enableSharing];
        }
    }
}

- (void)netServiceWillPublish:(NSNetService *)sender
{
    isSharing = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingStatusChangedNotification object:nil];
}

- (void)netServiceDidPublish:(NSNetService *)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingStatusChangedNotification object:nil];
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    int err = [[errorDict objectForKey:NSNetServicesErrorCode] intValue];
    
    [self disableSharing];
    
    if (err == NSNetServicesCollisionError && tryCount < MAX_TRY_COUNT) {
        
        [self setSharingName:[NSString stringWithFormat:@"%@-%i", [BDSKSharingServer defaultSharingName], ++tryCount]];
        [self _enableSharing];
        
    } else {
        
        NSString *errorMessage = nil;
        switch(err){
            case NSNetServicesUnknownError:
                errorMessage = NSLocalizedString(@"Unknown net services error", @"Error description");
                break;
            case NSNetServicesCollisionError:
                errorMessage = NSLocalizedString(@"Net services collision error", @"Error description");
                break;
            case NSNetServicesNotFoundError:
                errorMessage = NSLocalizedString(@"Net services not found error", @"Error description");
                break;
            case NSNetServicesActivityInProgress:
                errorMessage = NSLocalizedString(@"Net services reports activity in progress", @"Error description");
                break;
            case NSNetServicesBadArgumentError:
                errorMessage = NSLocalizedString(@"Net services bad argument error", @"Error description");
                break;
            case NSNetServicesCancelledError:
                errorMessage = NSLocalizedString(@"Cancelled net service", @"Error description");
                break;
            case NSNetServicesInvalidError:
                errorMessage = NSLocalizedString(@"Net services invalid error", @"Error description");
                break;
            case NSNetServicesTimeoutError:
                errorMessage = NSLocalizedString(@"Net services timeout error", @"Error description");
                break;
            default:
                errorMessage = NSLocalizedString(@"Unrecognized error code from net services", @"Error description");
                break;
        }
        
        NSLog(@"-[%@ %@] reports \"%@\"", [self class], NSStringFromSelector(_cmd), errorMessage);
        
        NSString *errorDescription = NSLocalizedString(@"Unable to Share Bibliographies Using Bonjour", @"Error description");
        NSString *recoverySuggestion = NSLocalizedString(@"You may wish to disable and re-enable sharing in BibDesk's preferences to see if the error persists.", @"Error informative text");
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:err userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorDescription, NSLocalizedDescriptionKey, errorMessage, NSLocalizedFailureReasonErrorKey, recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey, nil]];
        
        // show the error in a modal dialog
        [NSApp presentError:error];
    }
}

- (void)netServiceDidStop:(NSNetService *)sender
{
    // We'll need to release the NSNetService sending this, since we want to recreate it in sync with the socket at the other end. Since there's only the one NSNetService in this server, we can just release it.
    [netService setDelegate:nil];
    [netService release];
    netService = nil;
}

- (void)handleApplicationWillTerminate:(NSNotification *)note;
{
    [self disableSharing];
}

@end

#pragma mark -

@implementation BDSKSharingDOServer

// This is the minimal version for the client that we require
// If we introduce incompatible changes in future, bump this to avoid sharing breakage
+ (NSString *)requiredProtocolVersion { return @"0"; }

- (id)initForSharingServer:(BDSKSharingServer *)aSharingServer
{
    self = [super init];
    if (self) {
        sharingServer = aSharingServer;
        sharingName = [[sharingServer sharingName] retain];
        remoteClients = [[BDSKThreadSafeMutableDictionary alloc] init];
        [self startDOServerAsync];
    }   
    return self;
}

- (void)dealloc
{
    sharingServer = nil;
    [sharingName release];
    [remoteClients release];
    remoteClients = nil;
    [super dealloc];
}

#pragma mark Thread Safe

- (unsigned int)numberOfConnections { 
    return [remoteClients count]; 
}

#pragma mark Main Thread

- (void)stopDOServer {
    // make sure we don't message our sharingServer
    sharingServer = nil;
    [super stopDOServer];
}

- (void)notifyClientConnectionsChanged;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKClientConnectionsChangedNotification object:nil];
}

- (void)mainThreadServerDidSetup:(BOOL)success
{
    [sharingServer server:(BDSKSharingDOServer *)self didSetup:success];
}

#pragma mark Server Thread

#pragma mark | DO Server

- (Protocol *)protocolForServerThread { return @protocol(BDSKSharingServerLocalThread); }

- (void)serverDidSetup
{
    // setup our DO server that will handle requests for publications and passwords
    BOOL success = YES;
    @try {
        NSPort *receivePort = [NSSocketPort port];
        if([[NSSocketPortNameServer sharedInstance] registerPort:receivePort name:sharingName] == NO)
            @throw [NSString stringWithFormat:@"Unable to register port %@ and name %@", receivePort, sharingName];
        connection = [[NSConnection alloc] initWithReceivePort:receivePort sendPort:nil];
        NSProtocolChecker *checker = [NSProtocolChecker protocolCheckerWithTarget:self protocol:@protocol(BDSKSharingProtocol)];
        [connection setRootObject:checker];
        
        // so we get connection:shouldMakeNewConnection: messages
        [connection setDelegate:self];
    }
    @catch(id exception) {
        NSLog(@"%@", exception);
        success = NO;
        // Use performSelectorOnMainThread: in case we don't have a main thread proxy.
        // Pass NO for waitUntilDone: since this thread will get a callback from stopDOServer
        // so we can't block the runloop.
        //[self performSelectorOnMainThread:@selector(stopDOServer) withObject:nil waitUntilDone:NO];
    }
    @finally {
        [[self serverOnMainThread] mainThreadServerDidSetup:success];
    }
}

- (void)serverDidFinish
{
    if (connection == nil)
        return;
    
    NSEnumerator *e = [remoteClients keyEnumerator];
    id proxyObject;
    NSString *key;
    
    while(key = [e nextObject]){
        proxyObject = [[remoteClients objectForKey:key] objectForKey:@"object"];
        @try {
            [proxyObject invalidate];
        }
        @catch (id exception) {
            NSLog(@"%@: ignoring exception \"%@\" raised while invalidating client %@", [self class], exception, proxyObject);
        }
        [[proxyObject connectionForProxy] invalidate];
    }
    [remoteClients removeAllObjects];
    [self performSelectorOnMainThread:@selector(notifyClientConnectionsChanged) withObject:nil waitUntilDone:NO];
    
    NSPort *port = [[NSSocketPortNameServer sharedInstance] portForName:sharingName];
    [[NSSocketPortNameServer sharedInstance] removePortForName:sharingName];
    [port invalidate];
    [connection setDelegate:nil];
    [connection setRootObject:nil];
    [connection invalidate];
    [connection release];
    connection = nil;
}

#pragma mark | NSConnection delegate

- (BOOL)connection:(NSConnection *)parentConnection shouldMakeNewConnection:(NSConnection *)newConnection
{
    // set the child connection's delegate so we get authentication messages
    // this hidden pref will be zero by default, but we'll add a limit here just in case it's needed
    static unsigned int maxConnections = 0;
    if(maxConnections == 0)
        maxConnections = MAX(20, [[NSUserDefaults standardUserDefaults] integerForKey:@"BDSKSharingServerMaxConnections"]);
    
    BOOL allowConnection = [remoteClients count] < maxConnections;
    if(allowConnection){
        [newConnection setDelegate:self];
    } else {
        NSLog(@"*** WARNING *** Maximum number of sharing clients (%d) exceeded.", maxConnections);
        NSLog(@"Use `defaults write %@ BDSKSharingServerMaxConnections N` to change the limit to N.", [[NSBundle mainBundle] bundleIdentifier]);
    }
    return allowConnection;
}

- (BOOL)authenticateComponents:(NSArray *)components withData:(NSData *)authenticationData
{
    BOOL status = YES;
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKSharingRequiresPasswordKey]){
        NSData *myPasswordHashed = [BDSKPasswordController passwordHashedForKeychainServiceName:BDSKServiceNameForKeychain];
        status = [authenticationData isEqual:myPasswordHashed];
    }
    return status;
}

- (oneway void)registerClient:(byref id)clientObject forIdentifier:(bycopy NSString *)identifier version:(bycopy NSString *)version;
{
    NSParameterAssert(clientObject != nil && identifier != nil && version != nil);
    
    // we don't register clients that have a version we don't support
    if([version numericCompare:[BDSKSharingDOServer requiredProtocolVersion]] == NSOrderedAscending)
        return;
    
    [clientObject setProtocolForProxy:@protocol(BDSKClientProtocol)];
    NSDictionary *clientInfo = [NSDictionary dictionaryWithObjectsAndKeys:clientObject, @"object", version, @"version", nil];
    [remoteClients setObject:clientInfo forKey:identifier];
    [self performSelectorOnMainThread:@selector(notifyClientConnectionsChanged) withObject:nil waitUntilDone:NO];
}

#pragma mark | BDSKSharingProtocol

- (oneway void)removeClientForIdentifier:(bycopy NSString *)identifier;
{
    NSParameterAssert(identifier != nil);
    id proxyObject = [[remoteClients objectForKey:identifier] objectForKey:@"object"];
    [[proxyObject connectionForProxy] invalidate];
    [remoteClients removeObjectForKey:identifier];
    [self performSelectorOnMainThread:@selector(notifyClientConnectionsChanged) withObject:nil waitUntilDone:NO];
}

- (oneway void)notifyClientsOfChange;
{
    // here is where we notify other hosts that something changed
    NSEnumerator *e = [remoteClients keyEnumerator];
    id proxyObject;
    NSString *key;
    
    while(key = [e nextObject]){
        
        proxyObject = [[remoteClients objectForKey:key] objectForKey:@"object"];
        
        @try {
            [proxyObject setNeedsUpdate:YES];
        }
        @catch (id exception) {
            NSLog(@"server: \"%@\" trying to reach host %@", exception, proxyObject);
            // since it's not accessible, remove it from future notifications (we know it has this key)
            [self removeClientForIdentifier:key];
        }
    }
}

- (NSArray *)copyPublicationsFromOpenDocuments
{
    NSMutableSet *set = nil;
    NSMutableArray *pubs = [[NSMutableArray alloc] initWithCapacity:100];

    // this is only useful if everyone else uses the mutex, though...
    @synchronized([NSDocumentController sharedDocumentController]){
        NSEnumerator *docE = [[[[[NSDocumentController sharedDocumentController] documents] copy] autorelease] objectEnumerator];
        set = (NSMutableSet *)CFSetCreateMutable(CFAllocatorGetDefault(), 0, &kBDSKBibItemEqualitySetCallBacks);
        id document = nil;
        while(document = [docE nextObject]){
            [document getCopyOfPublicationsOnMainThread:pubs];
            [set addObjectsFromArray:pubs];
            [pubs removeAllObjects];
        }
        [pubs removeAllObjects];
    }
    [pubs addObjectsFromArray:[set allObjects]];
    [set release];
    return pubs;
}

- (NSDictionary *)copyMacrosFromOpenDocuments
{
    NSMutableDictionary *macros = [[NSMutableDictionary alloc] initWithCapacity:10];

    // this is only useful if everyone else uses the mutex, though...
    @synchronized([NSDocumentController sharedDocumentController]){
        NSArray *docs = [[[NSDocumentController sharedDocumentController] documents] copy];
        [docs makeObjectsPerformSelector:@selector(getCopyOfMacrosOnMainThread:) withObject:macros];
        [docs release];
    }
    return macros;
}

- (bycopy NSData *)archivedSnapshotOfPublications
{
    NSArray *pubs = [self copyPublicationsFromOpenDocuments];
    NSDictionary *macros = [self copyMacrosFromOpenDocuments];
    NSData *dataToSend = [NSKeyedArchiver archivedDataWithRootObject:pubs];
    NSData *macroDataToSend = [NSKeyedArchiver archivedDataWithRootObject:macros];
    [pubs release];
    [macros release];
    
    if(dataToSend != nil && macroDataToSend != nil){
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:dataToSend, BDSKSharedArchivedDataKey, macroDataToSend, BDSKSharedArchivedMacroDataKey, nil];
        NSString *errorString = nil;
        dataToSend = [NSPropertyListSerialization dataFromPropertyList:dictionary format:NSPropertyListBinaryFormat_v1_0 errorDescription:&errorString];
        if(errorString != nil){
            NSLog(@"Error serializing publications for sharing: %@", errorString);
            [errorString release];
        } else {
            // Omni's bzip2 method caused a hang when I tried it, but -compressedData produced a 50% size decrease
            @try{ dataToSend = [dataToSend compressedData]; }
            @catch(id exception){ NSLog(@"Ignoring exception %@ raised while compressing data to share.", exception); }
        }
    }
    return dataToSend;
}

@end
