//
//  BDSKTypeInfoEditor.m
//  BibDesk
//
//  Created by Christiaan Hofman on 5/4/05.
/*
 This software is Copyright (c) 2005-2012
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

#import "BDSKTypeInfoEditor.h"
#import "BDSKFieldNameFormatter.h"
#import "BDSKTypeNameFormatter.h"
#import "BDSKTypeManager.h"
#import "NSWindowController_BDSKExtensions.h"

#define REQUIRED_KEY @"required"
#define OPTIONAL_KEY @"optional"

#define BDSKTypeInfoRowsPboardType @"BDSKTypeInfoRowsPboardType"
#define BDSKTypeInfoPboardType     @"BDSKTypeInfoPboardType"

static BDSKTypeInfoEditor *sharedTypeInfoEditor;

@implementation BDSKTypeInfoEditor

+ (BDSKTypeInfoEditor *)sharedTypeInfoEditor{
    if (sharedTypeInfoEditor == nil) 
        sharedTypeInfoEditor = [[BDSKTypeInfoEditor alloc] init];
    return sharedTypeInfoEditor;
}

- (id)init
{
    BDSKPRECONDITION(sharedTypeInfoEditor == nil);
    self = [super initWithWindowNibName:@"BDSKTypeInfoEditor"];
    if (self) {
        canEditDefaultTypes = NO;
        
		fieldsForTypesDict = [[NSMutableDictionary alloc] init];
		types = [[NSMutableArray alloc] init];
		[self revertTypes]; // this loads the current typeInfo from BDSKTypeManager
    }
    return self;
}

- (void)awakeFromNib
{
    // we want to be able to reorder the items
	[typeTableView registerForDraggedTypes:[NSArray arrayWithObject:BDSKTypeInfoRowsPboardType]];
    [requiredTableView registerForDraggedTypes:[NSArray arrayWithObject:BDSKTypeInfoRowsPboardType]];
    [optionalTableView registerForDraggedTypes:[NSArray arrayWithObject:BDSKTypeInfoRowsPboardType]];
	
    BDSKFieldNameFormatter *fieldNameFormatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
    BDSKTypeNameFormatter *typeNameFormatter = [[[BDSKTypeNameFormatter alloc] init] autorelease];
    NSTableColumn *tc = [typeTableView tableColumnWithIdentifier:@"type"];
    [[tc dataCell] setFormatter:typeNameFormatter];
	tc = [requiredTableView tableColumnWithIdentifier:@"required"];
    [[tc dataCell] setFormatter:fieldNameFormatter];
	tc = [optionalTableView tableColumnWithIdentifier:@"optional"];
    [[tc dataCell] setFormatter:fieldNameFormatter];
	
    [canEditDefaultTypesButton setState:canEditDefaultTypes ? NSOnState : NSOffState];
    
	[typeTableView reloadData];
	[requiredTableView reloadData];
	[optionalTableView reloadData];
	
	[self updateButtons];
}

- (void)revertTypes {
	BDSKTypeManager *btm = [BDSKTypeManager sharedManager];
	NSMutableDictionary *fieldsDict = [NSMutableDictionary dictionaryWithCapacity:2];
	
	[types removeAllObjects];
	[fieldsForTypesDict removeAllObjects];
	for (NSString *type in [btm types]) {
		[fieldsDict setObject:[btm requiredFieldsForType:type] forKey:REQUIRED_KEY];
		[fieldsDict setObject:[btm optionalFieldsForType:type] forKey:OPTIONAL_KEY];
		[self addType:type withFields:fieldsDict];
	}
	[types sortUsingSelector:@selector(compare:)];
	
	[typeTableView reloadData];
	[self setCurrentType:nil];
	
	[self setDocumentEdited:NO];
}

# pragma mark Accessors

- (void)insertType:(NSString *)newType withFields:(NSDictionary *)fieldsDict atIndex:(NSUInteger)idx {
	[types insertObject:newType atIndex:idx];
	
	// create mutable containers for the fields
	NSMutableArray *requiredFields;
	NSMutableArray *optionalFields;
	
	if (fieldsDict) {
		requiredFields = [NSMutableArray arrayWithArray:[fieldsDict objectForKey:REQUIRED_KEY]];
		optionalFields = [NSMutableArray arrayWithArray:[fieldsDict objectForKey:OPTIONAL_KEY]];
	} else {
		requiredFields = [NSMutableArray arrayWithCapacity:1];
		optionalFields = [NSMutableArray arrayWithCapacity:1];
	}
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithObjectsAndKeys: requiredFields, REQUIRED_KEY, optionalFields, OPTIONAL_KEY, nil];
	[fieldsForTypesDict setObject:newDict forKey:newType];
}

- (void)addType:(NSString *)newType withFields:(NSDictionary *)fieldsDict {
    [self insertType:newType withFields:fieldsDict atIndex:[types count]];
}

- (void)setCurrentType:(NSString *)newCurrentType {
    if (currentType == nil || ![currentType isEqualToString:newCurrentType]) {
        [currentType release];
        currentType = [newCurrentType copy];
		
		if (currentType) {
            NSDictionary *defaultFieldsDict = [[[BDSKTypeManager sharedManager] defaultFieldsForTypes] objectForKey:currentType];
			currentRequiredFields = [[fieldsForTypesDict objectForKey:currentType] objectForKey:REQUIRED_KEY];
			currentOptionalFields = [[fieldsForTypesDict objectForKey:currentType] objectForKey:OPTIONAL_KEY]; 
			currentDefaultRequiredFields = [defaultFieldsDict objectForKey:REQUIRED_KEY];
			currentDefaultOptionalFields = [defaultFieldsDict objectForKey:OPTIONAL_KEY];
		} else {
			currentRequiredFields = nil;
			currentOptionalFields = nil;
			currentDefaultRequiredFields = nil;
			currentDefaultOptionalFields = nil;
		}
		
		[requiredTableView reloadData];
		[optionalTableView reloadData];
		
		[self updateButtons];
    }
}

#pragma mark Actions

- (IBAction)dismiss:(id)sender {
    [[self window] makeFirstResponder:nil]; // commit edit before saving
	
    if ([sender tag] == NSOKButton) {
        [[BDSKTypeManager sharedManager] updateUserTypes:types andFields:fieldsForTypesDict];
        [self setDocumentEdited:NO];
    } else {
        [self revertTypes];
    }
	
    [super dismiss:sender];
}

- (IBAction)addRemoveType:(id)sender {
    if ([sender selectedSegment] == 0) { // add
        
        NSString *newType = @"new-type";
        NSInteger i = 0;
        while ([types containsObject:newType]) {
            newType = [NSString stringWithFormat:@"new-type-%ld", (long)++i];
        }
        [self addType:newType withFields:nil];
        
        [typeTableView reloadData];
        
        NSInteger row = [types indexOfObject:newType];
        [typeTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [[[typeTableView tableColumnWithIdentifier:@"type"] dataCell] setEnabled:YES];
        [typeTableView editColumn:0 row:row withEvent:nil select:YES];
        
    } else { // remove
        
        NSIndexSet *indexesToRemove = [typeTableView selectedRowIndexes];
        NSArray *typesToRemove = [types objectsAtIndexes:indexesToRemove];
        
        // make sure we stop editing
        [[self window] makeFirstResponder:typeTableView];
        
        [types removeObjectsAtIndexes:indexesToRemove];
        [fieldsForTypesDict removeObjectsForKeys:typesToRemove];
        
        [typeTableView reloadData];
        [typeTableView deselectAll:nil];
        
    }
    
    [self setDocumentEdited:YES];
}

- (IBAction)addRemoveRequired:(id)sender {
    if ([sender selectedSegment] == 0) { // add
        
        NSString *newField = @"New-Field";
        NSInteger i = 0;
        while ([currentRequiredFields containsObject:newField]) {
            newField = [NSString stringWithFormat:@"New-Field-%ld", (long)++i];
        }
        [currentRequiredFields addObject:newField];
        
        [requiredTableView reloadData];
        
        NSInteger row = [currentRequiredFields indexOfObject:newField];
        [requiredTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [[[requiredTableView tableColumnWithIdentifier:@"required"] dataCell] setEnabled:YES];
        [requiredTableView editColumn:0 row:row withEvent:nil select:YES];
        
    } else { // remove
        
        NSIndexSet *indexesToRemove = [requiredTableView selectedRowIndexes];
        
        // make sure we stop editing
        [[self window] makeFirstResponder:requiredTableView];
        
        [currentRequiredFields removeObjectsAtIndexes:indexesToRemove];
        
        [requiredTableView reloadData];
        [requiredTableView deselectAll:nil];
        
    }
    
    [self setDocumentEdited:YES];
}

- (IBAction)addRemoveOptional:(id)sender {
    if ([sender selectedSegment] == 0) { // add
        
        NSString *newField = @"New-Field";
        NSInteger i = 0;
        while ([currentOptionalFields containsObject:newField]) {
            newField = [NSString stringWithFormat:@"New-Field-%ld", (long)++i];
        }
        [currentOptionalFields addObject:newField];
        
        [optionalTableView reloadData];
        
        NSInteger row = [currentOptionalFields indexOfObject:newField];
        [optionalTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [[[optionalTableView tableColumnWithIdentifier:@"optional"] dataCell] setEnabled:YES];
        [optionalTableView editColumn:0 row:row withEvent:nil select:YES];
        
    } else { // remove
        
        NSIndexSet *indexesToRemove = [optionalTableView selectedRowIndexes];
        
        // make sure we stop editing
        [[self window] makeFirstResponder:optionalTableView];

        [currentOptionalFields removeObjectsAtIndexes:indexesToRemove];
        
        [optionalTableView reloadData];
        [optionalTableView deselectAll:nil];
        
    }
    
    [self setDocumentEdited:YES];
}

- (IBAction)revertCurrentToDefault:(id)sender {
	if (currentType == nil) 
		return;
	
	// make sure we stop editing
	[[self window] makeFirstResponder:nil];
	
	[currentRequiredFields removeAllObjects];
	[currentRequiredFields addObjectsFromArray:currentDefaultRequiredFields];
	[currentOptionalFields removeAllObjects];
	[currentOptionalFields addObjectsFromArray:currentDefaultOptionalFields];
	
	[requiredTableView reloadData];
	[optionalTableView reloadData];
	
	[self setDocumentEdited:YES];
}

- (IBAction)revertAllToDefault:(id)sender {
	// make sure we stop editing
	[[self window] makeFirstResponder:nil];
	
	[fieldsForTypesDict removeAllObjects];
	[types removeAllObjects];
    NSDictionary *defaultFieldsForTypesDict = [[BDSKTypeManager sharedManager] defaultFieldsForTypes];
    NSArray *defaultTypes = [[BDSKTypeManager sharedManager] defaultTypes];
	for (NSString *type in defaultTypes)
		[self addType:type withFields:[defaultFieldsForTypesDict objectForKey:type]];
	[types sortUsingSelector:@selector(compare:)];
	[typeTableView reloadData];
	[self setCurrentType:nil];
	
	[self setDocumentEdited:YES];
}

- (void)warningSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    canEditDefaultTypes = returnCode == NSOKButton;
    [canEditDefaultTypesButton setState:canEditDefaultTypes ? NSOnState : NSOffState];
    
    [typeTableView reloadData];
	[requiredTableView reloadData];
	[optionalTableView reloadData];
	[self updateButtons];
}

- (IBAction)changeCanEditDefaultTypes:(id)sender {
    if ([sender state] == NSOnState) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Are you sure you want to edit default types?", @"Message in alert dialog")
                                         defaultButton:NSLocalizedString(@"OK", @"Button title")
                                       alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Changing the default bibtex types and fields can give misleading information.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(warningSheetDidEnd:returnCode:contextInfo:)
                            contextInfo:NULL];
	} else {
        [self warningSheetDidEnd:nil returnCode:NSCancelButton contextInfo:NULL];
    }
}

#pragma mark validation methods

- (BOOL)canEditType:(NSString *)type {
	return (canEditDefaultTypes || NO == [[BDSKTypeManager sharedManager] isStandardType:type]);
}

- (BOOL)canEditField:(NSString *)field{
	if (currentType == nil) // there is nothing to edit
		return NO;
	if ([self canEditType:currentType]) // we allow any edits for non-default types
		return YES;
	if ([currentDefaultRequiredFields containsObject:field] ||
		[currentDefaultOptionalFields containsObject:field]) // we don't allow edits of default fields for default types
		return NO;
	return YES; // any other fields of default types can be removed
}

- (BOOL)canEditTableView:(NSTableView *)tv row:(NSInteger)row{
	if (tv == typeTableView)
		return [self canEditType:[types objectAtIndex:row]];
	if ([self canEditType:currentType])
		return YES; // if we can edit the type, we can edit all the fields
	if (tv == requiredTableView)
		return [self canEditField:[currentRequiredFields objectAtIndex:row]];
	if (tv == optionalTableView)
		return [self canEditField:[currentOptionalFields objectAtIndex:row]];
    return NO;
}

- (void)updateButtons {
	NSIndexSet *rowIndexes;
	NSInteger row;
	BOOL canRemove;
	NSString *value;
	
	[addRemoveTypeButton setEnabled:YES forSegment:0];
	
	if ([typeTableView numberOfSelectedRows] == 0) {
		[addRemoveTypeButton setEnabled:NO forSegment:1];
	} else {
		rowIndexes = [typeTableView selectedRowIndexes];
		row = [rowIndexes firstIndex];
		canRemove = YES;
		while (row != NSNotFound) {
			value = [types objectAtIndex:row];
			if (![self canEditType:value]) {
				canRemove = NO;
				break;
			}
			row = [rowIndexes indexGreaterThanIndex:row];
		}
		[addRemoveTypeButton setEnabled:canRemove forSegment:1];
	}
	
	[addRemoveRequiredButton setEnabled:currentType != nil forSegment:0];
	
	if ([requiredTableView numberOfSelectedRows] == 0) {
		[addRemoveRequiredButton setEnabled:NO forSegment:1];
	} else {
		rowIndexes = [requiredTableView selectedRowIndexes];
		row = [rowIndexes firstIndex];
		canRemove = YES;
		while (row != NSNotFound) {
			value = [currentRequiredFields objectAtIndex:row];
			if (![self canEditField:value]) {
				canRemove = NO;
				break;
			}
			row = [rowIndexes indexGreaterThanIndex:row];
		}
		[addRemoveRequiredButton setEnabled:canRemove forSegment:1];
	}
	
	[addRemoveOptionalButton setEnabled:currentType != nil forSegment:0];
	
	if ([optionalTableView numberOfSelectedRows] == 0) {
		[addRemoveOptionalButton setEnabled:NO forSegment:1];
	} else {
		rowIndexes = [optionalTableView selectedRowIndexes];
		row = [rowIndexes firstIndex];
		canRemove = YES;
		while (row != NSNotFound) {
			value = [currentOptionalFields objectAtIndex:row];
			if (![self canEditField:value]) {
				canRemove = NO;
				break;
			}
			row = [rowIndexes indexGreaterThanIndex:row];
		}
		[addRemoveOptionalButton setEnabled:canRemove forSegment:1];
	}
	
	[revertCurrentToDefaultButton setEnabled:(currentType && [[[BDSKTypeManager sharedManager] defaultFieldsForTypes] objectForKey:currentType])];
}

#pragma mark NSTableview datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
	if (tv == typeTableView) {
		return [types count];
	}
	
	if (currentType == nil) return 0;
	
	if (tv == requiredTableView) {
		return [currentRequiredFields count];
	}
	else if (tv == optionalTableView) {
		return [currentOptionalFields count];
	}
    // not reached
    return 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	if (tv == typeTableView) {
		return [types objectAtIndex:row];
	}
	else if (tv == requiredTableView) {
		return [currentRequiredFields objectAtIndex:row];
	}
	else if (tv == optionalTableView) {
		return [currentOptionalFields objectAtIndex:row];
	}
    // not reached
    return nil;
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString *oldValue;
	NSString *newValue;
	
	if (tv == typeTableView) {
        // NSDictionary copies its keys, so types may be the only thing retaining oldValue (see bug #1596532)
		oldValue = [[[types objectAtIndex:row] retain] autorelease];
		newValue = [(NSString *)object entryType];
		if (![newValue isEqualToString:oldValue] && 
			![types containsObject:newValue]) {
			
			[types replaceObjectAtIndex:row withObject:newValue];
			[fieldsForTypesDict setObject:[fieldsForTypesDict objectForKey:oldValue] forKey:newValue];
			[fieldsForTypesDict removeObjectForKey:oldValue];
			[self setCurrentType:newValue];
			
			[self setDocumentEdited:YES];
		}
	}
	else if (tv == requiredTableView) {
		oldValue = [currentRequiredFields objectAtIndex:row];
		newValue = [(NSString *)object fieldName];
		if (![newValue isEqualToString:oldValue] && 
			![currentRequiredFields containsObject:newValue] && 
			![currentOptionalFields containsObject:newValue]) {
			
			[currentRequiredFields replaceObjectAtIndex:row withObject:newValue];
			
			[self setDocumentEdited:YES];
		}
	}
	else if (tv == optionalTableView) {
		oldValue = [currentOptionalFields objectAtIndex:row];
		newValue = [(NSString *)object fieldName];
		if (![newValue isEqualToString:oldValue] && 
			![currentRequiredFields containsObject:newValue] && 
			![currentOptionalFields containsObject:newValue]) {
			
			[currentOptionalFields replaceObjectAtIndex:row withObject:newValue];
			
			[self setDocumentEdited:YES];
		}
	}
}

#pragma mark NSTableview delegate

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	return [self canEditTableView:tv row:row];
}

- (void)tableView:(NSTableView *)tv willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if ([self canEditTableView:tv row:row]) {
		[cell setTextColor:[NSColor controlTextColor]]; // when selected, this is automatically changed to white
	} else if ([[self window] isKeyWindow] && [[[self window] firstResponder] isEqual:tv] && [tv isRowSelected:row]) {
		[cell setTextColor:[NSColor lightGrayColor]]; // selected disabled
	} else {
		[cell setTextColor:[NSColor darkGrayColor]]; // unselected disabled
	}
}

#pragma mark Paste/Duplicate support

// used by OmniAppKit category methods
- (void)tableView:(NSTableView *)tv pasteFromPasteboard:(NSPasteboard *)pboard {
    NSArray *pbtypes = [pboard types];
    if ([tv isEqual:typeTableView] && [pbtypes containsObject:BDSKTypeInfoPboardType]) {
        NSArray *newTypes = [pboard propertyListForType:BDSKTypeInfoPboardType];
        NSString *newType = nil;
        
        for (NSDictionary *aType in [pboard propertyListForType:BDSKTypeInfoPboardType]) {
            // append "copy" here instead of in the loop
            NSString *name = [[aType objectForKey:@"name"] stringByAppendingString:@"-copy"];
            newType = name;
            NSInteger i = 0;
            while ([types containsObject:newType])
                newType = [NSString stringWithFormat:@"%@-%ld", name, (long)++i];
            [self addType:newType withFields:[aType objectForKey:@"fields"]];
            
        }
        [typeTableView reloadData];
        
        // select and edit the first item we added
        NSInteger row = [types count] - [newTypes count];

        [typeTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [[[typeTableView tableColumnWithIdentifier:@"type"] dataCell] setEnabled:YES];
        [typeTableView editColumn:0 row:row withEvent:nil select:YES];
        
        [self setDocumentEdited:YES];
    }
}

- (BOOL)tableViewCanPasteFromPasteboard:(NSTableView *)tv {
    return [tv isEqual:typeTableView];
}

#pragma mark NSTableView dragging

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
	// we only drag our own rows
	[pboard declareTypes: [NSArray arrayWithObjects:BDSKTypeInfoRowsPboardType, BDSKTypeInfoPboardType, nil] owner:nil];
	// write the rows to the pasteboard
	[pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:BDSKTypeInfoRowsPboardType];
    if ([tv isEqual:typeTableView] && [rowIndexes count]) {
        NSMutableArray *newTypes = [NSMutableArray array];
        NSUInteger row = [rowIndexes firstIndex];
        while (row != NSNotFound) {
            NSMutableDictionary *aType = [NSMutableDictionary dictionary];
            NSString *name = [types objectAtIndex:row];
            [aType setObject:name forKey:@"name"];
            [aType setObject:[fieldsForTypesDict objectForKey:name] forKey:@"fields"];
            [newTypes addObject:aType];
            row = [rowIndexes indexGreaterThanIndex:row];
        }
        [pboard setPropertyList:newTypes forType:BDSKTypeInfoPboardType];
    }
	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op {
	if ([info draggingSource] != tv) {// we don't allow dragging between tables, as we want to keep default types in the same place
		if ([info draggingSource] == typeTableView || tv == typeTableView || [self canEditType:currentType] == NO)
            return NSDragOperationNone;
	}
    
	if (row == -1) // redirect drops on the table to the first item
		[tv setDropRow:0 dropOperation:NSTableViewDropAbove];
	if (op == NSTableViewDropOn) // redirect drops on an item
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
	
    if (tv == typeTableView && [info draggingSourceOperationMask] == NSDragOperationCopy)
        return NSDragOperationCopy;
	else
        return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo> )info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op {
	NSPasteboard *pboard = [info draggingPasteboard];
	NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:BDSKTypeInfoRowsPboardType]];
    NSIndexSet *insertIndexes;
    NSTableView *sourceTv = [info draggingSource];
	
    if (tv == typeTableView && [info draggingSourceOperationMask] == NSDragOperationCopy) {
        
        NSString *newType;
        NSInteger i;
        
        insertIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [rowIndexes count])];
        
        for (NSString *type in [types objectsAtIndexes:rowIndexes]) {
            newType = [NSString stringWithFormat:@"%@-copy", type];
            i = 0;
            while ([types containsObject:newType]) {
                newType = [NSString stringWithFormat:@"%@-copy-%ld", type, (long)++i];
            }
            [self insertType:newType withFields:[fieldsForTypesDict objectForKey:type] atIndex:row];
        }
        
    } else {
        
        NSInteger i = [rowIndexes firstIndex];
        NSInteger insertRow = row;
        NSMutableArray *sourceFields = nil;
        NSMutableArray *targetFields = nil;
        NSArray *draggedFields;
        NSMutableIndexSet *removeIndexes = [NSMutableIndexSet indexSet];
        
        // find the array of fields
        if (sourceTv == typeTableView) {
            sourceFields = types;
        } else if (sourceTv == requiredTableView) {
            sourceFields = currentRequiredFields;
        } else if (sourceTv == optionalTableView) {
            sourceFields = currentOptionalFields;
        }
        if (tv == typeTableView) {
            targetFields = types;
        } else if (tv == requiredTableView) {
            targetFields = currentRequiredFields;
        } else if (tv == optionalTableView) {
            targetFields = currentOptionalFields;
        }
        
        NSAssert(sourceFields != nil && targetFields != nil, @"An error occurred:  fields must not be nil when dragging");
        
        while (i != NSNotFound) {
            if (sourceTv == tv && i < row) insertRow--;
            [removeIndexes addIndex:i];
            i = [rowIndexes indexGreaterThanIndex:i];
        }
        
        draggedFields = [sourceFields objectsAtIndexes:removeIndexes];
        insertIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertRow, [rowIndexes count])];
        [sourceFields removeObjectsAtIndexes:removeIndexes];
        [targetFields insertObjects:draggedFields atIndexes:insertIndexes];
        
    }
    
    // select the moved rows
    if(![tv allowsMultipleSelection])
        insertIndexes = [NSIndexSet indexSetWithIndex:[insertIndexes firstIndex]];
    [tv selectRowIndexes:insertIndexes byExtendingSelection:NO];
    [tv reloadData];
    if (sourceTv != tv)
        [sourceTv reloadData];
    
    [self setDocumentEdited:YES];
    
    return YES;
}

#pragma mark NSTableView notifications

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	NSTableView *tv = [aNotification object];
	
	if (tv == typeTableView) {
		if ([typeTableView numberOfSelectedRows] == 1) {
			[self setCurrentType:[types objectAtIndex:[typeTableView selectedRow]]];
		} else {
			[self setCurrentType:nil];
		}
		// the fields changed, so update their tableViews
		[requiredTableView reloadData];
		[optionalTableView reloadData];
	}
	[self updateButtons];
}

#pragma mark Splitview delegate methods

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset{
	return proposedMin + 50.0;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset{
	return proposedMax - 50.0;
}

@end
