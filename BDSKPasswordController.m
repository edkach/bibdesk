//
//  BDSKPasswordController.m
//  BibDesk
//
//  Created by Adam Maxwell on Sat Apr 1 2006.
//  Copyright (c) 2006 Adam R. Maxwell. All rights reserved.
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


#import "BDSKPasswordController.h"
#import <Security/Security.h>
#import "NSData_BDSKExtensions.h"


@implementation BDSKPasswordController

+ (NSData *)passwordForKeychainServiceName:(NSString *)name {
    // use the service name to get password from keychain and hash it with sha1 for comparison purposes
    OSStatus err;
    
    const char *nameCString = [name UTF8String];
    void *password = NULL;
    UInt32 passwordLength = 0;
    NSData *pwData = nil;
    
    err = SecKeychainFindGenericPassword(NULL, strlen(nameCString), nameCString, 0, NULL, &passwordLength, &password, NULL);
    if(err == noErr){
        pwData = [NSData dataWithBytes:password length:passwordLength];
        SecKeychainItemFreeContent(NULL, password);
    }
    return pwData;
}

// hash it for comparison, since we hash before putting it in the TXT
+ (NSData *)passwordHashedForKeychainServiceName:(NSString *)name {
    return [[self passwordForKeychainServiceName:name] sha1Signature];
}

+ (BOOL)addOrModifyPassword:(NSString *)password name:(NSString *)name userName:(NSString *)userName {
    // default is to use current user's username
    const char *userNameCString = userName == nil ? [NSUserName() UTF8String] : [userName UTF8String];
    
    NSParameterAssert(name != nil);
    const char *nameCString = [name UTF8String];
    
    OSStatus err;
    SecKeychainItemRef itemRef = NULL;    
    const void *passwordData = [password UTF8String];
    const void *oldPasswordData = NULL;
    UInt32 passwordLength = 0;
    BOOL result = NO;
    
    // first see if the password exists in the keychain
    err = SecKeychainFindGenericPassword(NULL, strlen(nameCString), nameCString, strlen(userNameCString), userNameCString, &passwordLength, (void **)&oldPasswordData, &itemRef);
    
    if (err == noErr) {
        // password was on keychain, so flush the buffer and then modify the keychain if necessary
        if (passwordLength != strlen(passwordData) || strncmp(passwordData, oldPasswordData, passwordLength) != 0) {
            SecKeychainAttribute attrs[] = {
            { kSecAccountItemAttr, strlen(userNameCString), (char *)userNameCString },
            { kSecServiceItemAttr, strlen(nameCString), (char *)nameCString } };
            const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]), attrs };
            
            err = SecKeychainItemModifyAttributesAndData(itemRef, &attributes, strlen(passwordData), passwordData);
            result = (err == noErr);
        }
        SecKeychainItemFreeContent(NULL, (void *)oldPasswordData);
    } else if (err == errSecItemNotFound) {
        // password not on keychain, so add it
        err = SecKeychainAddGenericPassword(NULL, strlen(nameCString), nameCString, strlen(userNameCString), userNameCString, strlen(passwordData), passwordData, &itemRef);    
        result = (err == noErr);
    } else {
        NSLog(@"Error %d occurred setting password", err);
    }
    return result;
}

- (NSData *)runModalForKeychainServiceName:(NSString *)name message:(NSString *)status {
    NSString *password = nil;
    [self window]; // load window before seting the status
    [statusField setStringValue:status];
    if (NSOKButton == [NSApp runModalForWindow:[self window]]) {
        NSAssert(name != nil, @"name is nil");
        password = [[[passwordField stringValue] retain] autorelease];
        NSParameterAssert(password != nil);
        [[self class] addOrModifyPassword:password name:name userName:nil];
    }
    [[self window] orderOut:self];    
    
    if (password == nil)
        return nil;
    const void *passwordBytes = [password UTF8String];
    return [[NSData dataWithBytes:passwordBytes length:strlen(passwordBytes)] sha1Signature];
}

+ (NSData *)runModalPanelForKeychainServiceName:(NSString *)name message:(NSString *)status {
    BDSKPasswordController *pwc = [[[self alloc] initWithWindowNibName:@"BDSKPasswordController"] autorelease];
    return [pwc runModalForKeychainServiceName:name message:status];
}

- (IBAction)buttonAction:(id)sender {    
    [NSApp stopModalWithCode:[sender tag]];
}

@end
