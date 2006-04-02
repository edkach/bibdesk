//
//  BDSKSharingBrowser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/2/06.
/*
 This software is Copyright (c) 2005,2006
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

#import "BDSKSharingBrowser.h"
#import "BibPrefController.h"
#import "BibDocument_Groups.h"
#import "BDSKGroup.h"
#import "NSArray_BDSKExtensions.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <Security/Security.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

// @@ register with http://www.dns-sd.org/ServiceTypes.html
NSString *BDSKNetServiceDomain = @"_bdsk._tcp.";

NSString *BDSKServiceNameForKeychain = @"BibDesk Sharing";

// TXT record keys
NSString *BDSKTXTPasswordKey = @"pass";
NSString *BDSKTXTUniqueIdentifierKey = @"hostid";
NSString *BDSKTXTComputerNameKey = @"name";
NSString *BDSKTXTVersionKey = @"txtvers";

NSString *BDSKSharedArchivedDataKey = @"publications_v1";

// This is used to determine if a service listed in the browser is from the local host and for display
static NSString *computerName = nil;

/* Much of this was borrowed from Apple's sample code and modified to fit our needs
    file://localhost/Developer/Examples/Foundation/PictureSharing/
    file://localhost/Developer/Examples/Foundation/PictureSharingBrowser/
*/

static SCDynamicStoreRef dynamicStore = NULL;
static const void *retainCallBack(const void *info) { return [(id)info retain]; }
static void releaseCallBack(const void *info) { [(id)info release]; }
static CFStringRef copyDescriptionCallBack(const void *info) { return (CFStringRef)[[(id)info description] copy]; }
// convert this to an NSNotification
static void SCDynamicStoreChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
    // clear this here, since the other handlers may depend on it
    [computerName release];
    computerName = nil;
        
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKComputerNameChangedNotification object:nil];
    
    // update the text field in prefs if necessary (or that could listen for computer name changes...)
    if([NSString isEmptyString:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSharingNameKey]])
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingNameChangedNotification object:nil];
}

NSString *BDSKComputerName() {
    if(computerName == nil){
        computerName = (NSString *)SCDynamicStoreCopyComputerName(dynamicStore, NULL);
        if(computerName == nil){
            NSLog(@"Unable to get computer name with SCDynamicStoreCopyComputerName");
            computerName = [[[[[NSProcessInfo processInfo] hostName] componentsSeparatedByString:@"."] firstObject] copy];
        }
    }
    return computerName;
}


@implementation BDSKSharingBrowser

static BDSKSharingBrowser *sharedBrowser = nil;

+ (void)didLoad;
{
    /* Ensure that computer name changes are propagated as future clients connect to a document.  Also, note that the OS will change the computer name to avoid conflicts by appending "(2)" or similar to the previous name, which is likely the most common scenario.
    */
    if(dynamicStore == NULL){
        CFAllocatorRef alloc = CFAllocatorGetDefault();
        SCDynamicStoreContext SCNSObjectContext = {
            0,                         // version
            (id)nil,                   // any NSCF type
            &retainCallBack,
            &releaseCallBack,
            &copyDescriptionCallBack
        };
        dynamicStore = SCDynamicStoreCreate(alloc, (CFStringRef)[[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey], &SCDynamicStoreChanged, &SCNSObjectContext);
        CFRunLoopSourceRef rlSource = SCDynamicStoreCreateRunLoopSource(alloc, dynamicStore, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rlSource, kCFRunLoopCommonModes);
        CFRelease(rlSource);
        CFStringRef key = SCDynamicStoreKeyCreateComputerName(alloc);
        CFArrayRef keys = CFArrayCreate(alloc, (const void **)&key, 1, &kCFTypeArrayCallBacks);
        CFRelease(key);
        
        if(SCDynamicStoreSetNotificationKeys(dynamicStore, keys, NULL) == FALSE)
            fprintf(stderr, "%s: unable to register for dynamic store notifications.\n", __PRETTY_FUNCTION__);
        CFRelease(keys);
    }
    
}

+ (id)sharedBrowser{
    if(sharedBrowser == nil)
        sharedBrowser = [[BDSKSharingBrowser alloc] init];
    return sharedBrowser;
}

- (id)init{
    if (self = [super init]){
        sharedGroups = nil;
        browser = nil;
        unresolvedNetServices = [[NSMutableArray alloc] initWithCapacity:10];
    }
    return self;
}

- (NSArray *)sharedGroups{
    return sharedGroups;
}

#pragma mark Convenience methods

// convenience method for keychain
- (NSData *)sharingPasswordForCurrentUserUnhashed;
{
    // find pw from keychain
    OSStatus err;
    
    void *passwordData = NULL;
    UInt32 passwordLength = 0;
    NSData *data = nil;
    
    const char *serviceName = [BDSKServiceNameForKeychain UTF8String];
    const char *userName = [NSUserName() UTF8String];
    
    err = SecKeychainFindGenericPassword(NULL, strlen(serviceName), serviceName, strlen(userName), userName, &passwordLength, &passwordData, NULL);
    data = [NSData dataWithBytes:passwordData length:passwordLength];
    SecKeychainItemFreeContent(NULL, passwordData);

    return data;
}

- (NSString *)uniqueIdentifier;
{
    // use to identify services sent from this machine
    static NSString *uniqueIdentifier = nil;
    if(uniqueIdentifier == nil){
        /* http://developer.apple.com/qa/qa2001/qa1306.html indicates that ASCII 1 is used to separate old style TXT records, so creating a TXT dictionary with a globallyUniqueString directly is almost guaranteed to fail since they contain alphanumeric characters and underscores; therefore, we'll replace it with something that doesn't seem to appear in globallyUniqueString objects.  An alternative might be to use address comparison, but the docs indicate that the stable identifier for a service is its name, since port number, IP address, and host name can be ephemeral.  Unfortunately, we can't use the service name to determine if a service should be ignored, since we want to ignore all shares from a particular process, not just a given document.
        */
        NSMutableString *pInfo = [[[NSProcessInfo processInfo] globallyUniqueString] mutableCopy];
        [pInfo replaceOccurrencesOfString:@"1" withString:@"~" options:0 range:NSMakeRange(0, [pInfo length])];
        uniqueIdentifier = [pInfo copy];
        [pInfo release];
    }
    return uniqueIdentifier;
}

// base name for sharing (also used for storing remote host names in keychain)
- (NSString *)sharingName;
{
    NSString *sharingName = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSharingNameKey];
    if([NSString isEmptyString:sharingName])
        sharingName = BDSKComputerName();
    return sharingName;
}

#pragma mark Reading other data

- (void)netServiceDidResolveAddress:(NSNetService *)aNetService
{    
    NSData *TXTData = [aNetService TXTRecordData];
    
    // +[NSNetService dictionaryFromTXTRecordData:] will crash if you pass a nil data
    NSDictionary *TXTDictionary = TXTData ? [NSNetService dictionaryFromTXTRecordData:TXTData] : nil;
    NSString *serviceIdentifier = [[NSString alloc] initWithData:[TXTDictionary objectForKey:BDSKTXTUniqueIdentifierKey] encoding:NSUTF8StringEncoding];

    // In general, we want to ignore our own shared services, as the write/read occur on the same run loop, and our file handle blocks; hence, we listen here for the resolve and then check the TXT record to see where the service came from.

    // Ignore our own services; quit/relaunch opening the same doc  can give us a stale service (from the previous run).  Since SystemConfiguration guarantees that we have a unique computer name, this should be safe.
    if([[[[NSDocumentController sharedDocumentController] documents] valueForKeyPath:@"@distinctUnionOfObjects.netServiceName"] containsObject:[aNetService name]] == NO){

        // WARNING:  enabling sharing with self can lead to hangs if you use a large file; launching a separate BibDesk process should work around that
        
        // see if service is from this machine (case 1) or we are testing with a single machine (case 2)
        if([NSString isEmptyString:serviceIdentifier] == NO && [serviceIdentifier isEqualToString:[self uniqueIdentifier]] == NO){
            
            // we don't want it to message us again
            [aNetService setDelegate:nil];

            BDSKSharedGroup *group = [[BDSKSharedGroup alloc] initWithService:aNetService];
            [sharedGroups addObject:group];
            [group release];
            
            // remove from the list of unresolved services
            [unresolvedNetServices removeObject:aNetService];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupsChangedNotification object:self];
        }
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing 
{
    // set as delegate and resolve, so we can find out if this originated from the localhost or a remote machine
    // we can't access TXT records until the service is resolved (this is documented in CFNetService, not NSNetService)
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:5.0];
    [unresolvedNetServices addObject:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    NSEnumerator *e = [sharedGroups objectEnumerator];
    NSMutableArray *array = [NSMutableArray array];
    BDSKSharedGroup *group;
    
    // create an array of the groups we should keep by comparing services with the one that just went away
    while(group = [e nextObject])
        if([[group service] isEqual:aNetService] == NO)
            [array addObject:group];
    
    [sharedGroups setArray:array];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupsChangedNotification object:self];
}

- (void)enableSharedBrowsing;
{
    // lazily create the shared resources
    NSAssert(sharedGroups == nil, @"It is an error to enable browsing twice");
    
    sharedGroups = [[NSMutableArray alloc] initWithCapacity:5];
    browser = [[NSNetServiceBrowser alloc] init];
    [browser setDelegate:self];
    [browser searchForServicesOfType:BDSKNetServiceDomain inDomain:@""];    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupsChangedNotification object:self];
}

- (void)disableSharedBrowsing;
{
    [sharedGroups release];
    sharedGroups = nil;
    [browser release];
    browser = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupsChangedNotification object:self];
}

@end
