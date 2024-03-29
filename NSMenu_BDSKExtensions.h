//
//  NSMenu_BDSKExtensions.h
//  Bibdesk
//
//  Created by Adam Maxwell on 07/09/06.
/*
 This software is Copyright (c) 2006-2012
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

@interface NSMenu (BDSKExtensions)

- (NSMenuItem *)itemWithAction:(SEL)action;

- (void)addItemsFromMenu:(NSMenu *)other;

- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu atIndex:(NSUInteger)index;
- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu;
- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle submenuTitle:(NSString *)submenuTitle submenuDelegate:(id)delegate atIndex:(NSUInteger)index;
- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle submenuTitle:(NSString *)submenuTitle submenuDelegate:(id)delegate;
- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle andSubmenuOfApplicationsForURL:(NSURL *)theURL atIndex:(NSUInteger)index;
- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle andSubmenuOfApplicationsForURL:(NSURL *)theURL;

@end

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@interface NSMenu (BDSKSnowLeopardExtensions)
- (void)removeAllItems;
@end
#endif

@interface NSMenuItem (BDSKImageExtensions)
- (void)setImageAndSize:(NSImage *)image;
@end
