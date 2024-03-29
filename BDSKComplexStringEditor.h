// BDSKComplexStringEditor.h
// Created by Michael McCracken, January 2005

// Inspired by and somewhat copied from Calendar, whose author I've
// lost record of.

/*
 This software is Copyright (c) 2005-2012
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

#import <AppKit/AppKit.h>

@class BDSKBackgroundView, BDSKMacroResolver;

@interface BDSKComplexStringEditor : NSWindowController {
    IBOutlet NSTextField *expandedValueTextField;
    IBOutlet BDSKBackgroundView *backgroundView;
    BDSKMacroResolver *macroResolver;
	NSTableView *tableView;
	NSInteger row;
	NSInteger column;
    BOOL enabled;
}

- (id)initWithMacroResolver:(BDSKMacroResolver *)aMacroResolver enabled:(BOOL)isEnabled;

- (BOOL)attachToTableView:(NSTableView *)aTableView atRow:(NSInteger)aRow column:(NSInteger)aColumn withValue:(NSString *)aString;

- (BOOL)isAttached;

@end
