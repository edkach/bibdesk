//
//  BDSKPasswordController.m
//  BibDesk
//
//  Created by Adam Maxwell on Sat Apr 1 2006.
//  Copyright (c) 2006 Adam R. Maxwell. All rights reserved.
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


#import "BDSKPasswordController.h"
#import <Security/Security.h>
#import "BDSKSharingBrowser.h"
#import "BDSKSharingServer.h"

NSString *BDSKServiceNameForKeychain = @"BibDesk Sharing";

@implementation BDSKPasswordController

- (void)awakeFromNib
{
    [self setStatus:@""];
}

- (void)dealloc
{
    [self setService:nil];
    [super dealloc];
}

- (void)setService:(id)aService;
{
    if(service != aService){
        [service release];
        service = [aService retain];
    }
}

- (int)runModalForService:(id)aService;
{
    [self setService:aService];    
    [NSApp runModalForWindow:[self window]];    
    [self setService:nil];
    
    return returnValue;
}

- (void)setStatus:(NSString *)status { [statusField setStringValue:status]; }

- (NSString *)windowNibName { return @"BDSKPasswordController"; }

- (IBAction)changePassword:(id)sender
{
    NSAssert(service != nil, @"net service is nil");
    NSAssert([service name] != nil, @"tried to set password for unresolved service");
        
    NSData *TXTData = [service TXTRecordData];
    NSDictionary *dictionary = nil;
    if(TXTData)
        dictionary = [NSNetService dictionaryFromTXTRecordData:TXTData];
    TXTData = [dictionary objectForKey:BDSKTXTComputerNameKey];
    NSAssert([TXTData length], @"no computer name in TXT record");
    
    NSString *password = [passwordField stringValue];
    NSParameterAssert(password != nil);
    
    // append our service name to the server name for remote services
    NSString *serverName = [NSString stringWithData:TXTData encoding:NSUTF8StringEncoding];
    serverName = [serverName stringByAppendingFormat:@" - %@", BDSKServiceNameForKeychain];
    
    [BDSKPasswordController addOrModifyPassword:password serverName:serverName userName:nil];
}

- (IBAction)buttonAction:(id)sender
{    
    int tag = [sender tag];
    if(tag == 0)
        returnValue = 1;

    if(tag == 1)
        returnValue = 0;
    
    // this is the only way out of the modal session
    [NSApp stopModal];
}

// convenience method for keychain
+ (NSData *)sharingPasswordForCurrentUserUnhashed;
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

+ (void)addOrModifyPassword:(NSString *)password serverName:(NSString *)serverName userName:(NSString *)userName;
{
    // default is to use current user's username
    const char *userNameCString = userName == nil ? [NSUserName() UTF8String] : [userName UTF8String];
    
    NSParameterAssert(serverName != nil);
    const char *serverNameCString = [serverName UTF8String];
    
    OSStatus err;
    SecKeychainItemRef itemRef = NULL;    
    const void *passwordData = NULL;
    UInt32 passwordLength = 0;
    
    // first see if the password exists in the keychain
    err = SecKeychainFindGenericPassword(NULL, strlen(serverNameCString), serverNameCString, strlen(userNameCString), userNameCString, &passwordLength, (void **)&passwordData, &itemRef);
    
    if(err == noErr){
        // password was on keychain, so flush the buffer and then modify the keychain
        SecKeychainItemFreeContent(NULL, (void *)passwordData);
        passwordData = NULL;
        
        passwordData = [password UTF8String];
        SecKeychainAttribute attrs[] = {
        { kSecAccountItemAttr, strlen(userNameCString), (char *)userNameCString },
        { kSecServiceItemAttr, strlen(serverNameCString), (char *)serverNameCString } };
        const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]), attrs };
        
        err = SecKeychainItemModifyAttributesAndData(itemRef, &attributes, strlen(passwordData), passwordData);
    } else if(err == errSecItemNotFound){
        // password not on keychain, so add it
        passwordData = [password UTF8String];
        err = SecKeychainAddGenericPassword(NULL, strlen(serverNameCString), serverNameCString, strlen(userNameCString), userNameCString, strlen(passwordData), passwordData, &itemRef);    
    } else 
        NSLog(@"Error %d occurred setting password", err);
}

@end
