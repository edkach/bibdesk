//
//  BDSKCompatibility.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/18/09.
/*
 This software is Copyright (c) 2007-2012
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

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5

@protocol NSApplicationDelegate <NSObject> @end
@protocol NSControlTextEditingDelegate <NSObject> @end
@protocol NSTextFieldDelegate <NSControlTextEditingDelegate> @end
@protocol NSTokenFieldDelegate <NSTextFieldDelegate> @end
@protocol NSTableViewDelegate <NSControlTextEditingDelegate> @end
@protocol NSTableViewDataSource <NSObject> @end
@protocol NSOutlineViewDelegate <NSControlTextEditingDelegate> @end
@protocol NSOutlineViewDataSource <NSObject> @end
@protocol NSToolbarDelegate <NSObject> @end
@protocol NSToolbarItemValidation <NSObject> @end
@protocol NSMenuDelegate <NSObject> @end
@protocol NSDrawerDelegate <NSObject> @end
@protocol NSWindowDelegate <NSObject> @end
@protocol NSAnimationDelegate <NSObject> @end
@protocol NSTextDelegate <NSObject> @end
@protocol NSTextViewDelegate <NSTextDelegate> @end
@protocol NSTextStorageDelegate <NSObject> @end
@protocol NSTabViewDelegate <NSObject> @end
@protocol NSSplitViewDelegate <NSObject> @end
@protocol NSNetServiceDelegate <NSObject> @end
@protocol NSNetServiceBrowserDelegate <NSObject> @end
@protocol NSConnectionDelegate <NSObject> @end
@protocol NSOpenSavePanelDelegate <NSObject> @end
@protocol NSAlertDelegate <NSObject> @end
@protocol NSXMLParserDelegate <NSObject> @end

#endif

#ifndef NSAppKitVersionNumber10_5
    #define NSAppKitVersionNumber10_5 949
#endif

#ifndef NSAppKitVersionNumber10_6
    #define NSAppKitVersionNumber10_6 1038
#endif
