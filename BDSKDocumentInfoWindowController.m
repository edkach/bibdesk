//
//  BDSKDocumentInfoWindowController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/31/06.
/*
 This software is Copyright (c) 2006-2012
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

#import "BDSKDocumentInfoWindowController.h"
#import "NSDictionary_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"


@implementation BDSKDocumentInfoWindowController

- (id)init {
    self = [super initWithWindowNibName:@"DocumentInfoWindow"];
    if (self) {
        info = [[NSMutableDictionary alloc] initForCaseInsensitiveKeys];
        keys = nil;
        ignoreEdit = NO;
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(info);
    BDSKDESTROY(keys);
    [super dealloc];
}

#pragma mark Resetting

- (void)refreshKeys{
    if (keys == nil)
        keys = [[NSMutableArray alloc] init];
    [keys setArray:[info allKeys]];
    [keys sortUsingSelector:@selector(compare:)];
}

- (void)updateButtons{
	[addRemoveButton setEnabled:[tableView numberOfSelectedRows] > 0 forSegment:1];
}

- (void)awakeFromNib{
    [tableView reloadData];
    [self updateButtons];
}

- (void)finalizeChangesIgnoringEdit:(BOOL)flag {
	ignoreEdit = flag;
	if ([[self window] makeFirstResponder:nil] == NO)
        [[self window] endEditingFor:nil];
	ignoreEdit = NO;
}

- (void)windowWillClose:(NSNotification *)notification{
    [self finalizeChangesIgnoringEdit:YES];
}

- (void)setInfo:(NSDictionary *)newInfo {
    [info setDictionary:newInfo];
    [self refreshKeys];
}

- (NSDictionary *)info {
    return info;
}

#pragma mark Button actions

- (IBAction)dismiss:(id)sender{
    [self finalizeChangesIgnoringEdit:[sender tag] == NSCancelButton]; // commit edit before reloading
    
    if ([sender tag] == NSOKButton && [tableView editedRow] != -1)
        NSBeep();
    else
        [super dismiss:sender];
}

- (IBAction)addRemoveKey:(id)sender{
    if ([sender selectedSegment] == 0) { // add
        
        // find a unique new key
        NSInteger i = 0;
        NSString *newKey = @"key";
        while([info objectForKey:newKey] != nil)
            newKey = [NSString stringWithFormat:@"key%ld", (long)++i];
        
        [info setObject:@"" forKey:newKey];
        [self refreshKeys];
        [tableView reloadData];
        
        NSInteger row = [keys indexOfObject:newKey];
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [tableView editColumn:0 row:row withEvent:nil select:YES];
        
    } else { // remove
        
        // in case we're editing the selected field we need to end editing.
        // we don't give it a chance to modify state.
        [[self window] endEditingFor:[tableView selectedCell]];

        [info removeObjectsForKeys:[keys objectsAtIndexes:[tableView selectedRowIndexes]]];
        [self refreshKeys];
        [tableView reloadData];
        
    }
}

#pragma mark TableView DataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv{
    return [keys count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    NSString *key = [keys objectAtIndex:row];
    
    if([[tableColumn identifier] isEqualToString:@"key"]){
         return key;
    }else{
         return [info objectForKey:key];
    }
    
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    if (ignoreEdit) return;
    
    NSString *key = [keys objectAtIndex:row];
    NSString *value = [[[info objectForKey:key] retain] autorelease];
    
    if([[tableColumn identifier] isEqualToString:@"key"]){
		
		if([object isEqualToString:@""]){
			[tv reloadData];
            [tv selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [tableView editColumn:0 row:row withEvent:nil select:YES];
    		
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Empty Key", @"Message in alert dialog when trying to set an empty string for a key")
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The key can not be empty.", @"Informative text in alert dialog when trying to set an empty string for a key")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			return;
		}
        
        if([info objectForKey:object]){
            if([key isCaseInsensitiveEqual:object] == NO){			
                [tv reloadData];
                [tv selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                [tableView editColumn:0 row:row withEvent:nil select:YES];
                
                NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Key", @"Message in alert dialog when trying to add a duplicate key")
                                                 defaultButton:NSLocalizedString(@"OK", @"Button title")
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:NSLocalizedString(@"The key must be unique.", @"Informative text in alert dialog when trying to add a duplicate key")];
                [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			}
            return;
		}
        
        [info removeObjectForKey:key];
        [info setObject:value forKey:object];
        [self refreshKeys];
        
    }else{
        
        if([value isEqualToString:object]) return;
        
        if([value isStringTeXQuotingBalancedWithBraces:YES connected:NO] == NO){
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unbalanced Braces", @"Message in alert dialog when trying to set a value with unbalanced braces")
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"Braces must be balanced within the value.", @"Informative text in alert dialog")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
            
            [tv reloadData];
            [tv selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [tableView editColumn:0 row:row withEvent:nil select:YES];
            return;
		}
        
        [info setObject:object forKey:key];
    }
}

#pragma mark TableView Delegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)notification{
    [self updateButtons];
}

@end
