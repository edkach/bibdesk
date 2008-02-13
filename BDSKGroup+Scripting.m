//
//  BDSKGroup+Scripting.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/5/08.
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

#import "BDSKGroup+Scripting.h"
#import "BibDocument.h"
#import "BibDocument+Scripting.h"
#import "BibDocument_Groups.h"
#import "BDSKGroupsArray.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacro.h"
#import "BDSKMacroResolver.h"
#import "BDSKMacroResolver+Scripting.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BibAuthor+Scripting.h"
#import "NSObject_BDSKExtensions.h"
#import "BDSKServerInfo.h"


@implementation BDSKGroup (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
	unsigned idx = [[doc groups] indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"groups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (NSArray *)publicationsInGroup {
    if ([self respondsToSelector:@selector(publications)]) {
        return [(id)self publications];
    } else {
        NSEnumerator *pubEnum = [[document publications] objectEnumerator];
        BibItem *pub;
        NSMutableArray *filteredArray = [NSMutableArray array];
        
        while (pub = [pubEnum nextObject]) {
            if ([self containsItem:pub])
                [filteredArray addObject:pub];
        }
        
        return filteredArray;
    }
}

- (unsigned int)countOfPublications {
    return [[self publicationsInGroup] count];
}

- (BibItem *)objectInPublicationsAtIndex:(unsigned int)idx {
    return [[self publicationsInGroup] objectAtIndex:idx];
}

- (BibItem *)valueInPublicationsAtIndex:(unsigned int)idx {
    return [[self publicationsInGroup] objectAtIndex:idx];
}

- (NSArray *)authors {
    return [BibAuthor authorsInPublications:[self publicationsInGroup]];
}

- (BibAuthor *)valueInAuthorsWithName:(NSString *)aName {
    return [BibAuthor authorWithName:aName inPublications:[self publicationsInGroup]];
}

- (NSArray *)editors {
    return [BibAuthor editorsInPublications:[self publicationsInGroup]];
}

- (BibAuthor *)valueInEditorsWithName:(NSString *)aName {
    return [BibAuthor editorWithName:aName inPublications:[self publicationsInGroup]];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSString *)scriptingName {
    return [self stringValue];
}

@end

#pragma mark -

@implementation BDSKLibraryGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"libraryGroups" index:0] autorelease];
}

- (NSArray *)publicationsInGroup {
    return [[self document] publications];
}

- (unsigned int)countOfPublications {
    return [[self document] countOfPublications];
}

- (BibItem *)valueInPublicationsAtIndex:(unsigned int)idx {
    return [[self document] valueInPublicationsAtIndex:idx];
}

- (BibItem *)objectInPublicationsAtIndex:(unsigned int)idx {
    return [[self document] objectInPublicationsAtIndex:idx];
}

- (void)insertInPublications:(BibItem *)pub atIndex:(unsigned int)idx {
    [[self document] insertInPublications:pub atIndex:idx];
}

- (void)insertInPublications:(BibItem *)pub {
    if ([pub owner] == nil)
        [[self document] insertInPublications:pub];
}

- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx {
    if ([pub owner] == nil)
        [[self document] insertObject:pub inPublicationsAtIndex:idx];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
    [[self document] removeFromPublicationsAtIndex:idx];
}

- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx {
    [[self document] removeObjectFromPublicationsAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKMutableGroup (Scripting)

- (void)setScriptingName:(NSString *)newName {
    if ([self hasEditableName]) {
        [self setName:newName];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of group.",@"Error description")];
    }
}

@end

#pragma mark -

@implementation BDSKStaticGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] staticGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"staticGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (void)insertInPublications:(BibItem *)pub {
    if ([pub owner] == nil)
        [[self document] addPublication:pub];
	if ([[pub owner] isEqual:[self document]] == NO) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add publication from another document or external group, use duplicate.",@"Error description")];
    } else if ([self containsItem:pub] == NO) {
        [self addPublication:pub];
        [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx {
    [self insertInPublications:pub];
}

- (void)insertInPublications:(BibItem *)pub  atIndex:(unsigned int)idx {
	[self insertInPublications:pub];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
    [self removePublication:[publications objectAtIndex:idx]];
    [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx {
	[self removeFromPublicationsAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKLastImportGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"lastImportGroups" index:0] autorelease];
}

- (void)setAsName:(NSString *)newName {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of last import group.",@"Error description")];
}

- (void)insertInPublications:(BibItem *)pub {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot modify publications of last import group.",@"Error description")];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot modify publications of last import group.",@"Error description")];
}

@end

#pragma mark -

@implementation BDSKSmartGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] smartGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"smartGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

@end

#pragma mark -

@implementation BDSKCategoryGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] categoryGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"fieldGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (void)insertInPublications:(BibItem *)pub {
    if ([pub owner] == nil)
        [[self document] addPublication:pub];
	if ([[pub owner] isEqual:[self document]] == NO) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add publication from another document or external group, use duplicate.",@"Error description")];
    } else if ([self containsItem:pub] == NO) {
        [[self document] addPublications:[NSArray arrayWithObject:pub] toGroup:self];
        [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx {
    [self insertInPublications:pub];
}

- (void)insertInPublications:(BibItem *)pub  atIndex:(unsigned int)idx {
	[self insertInPublications:pub];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
    [[self document] removePublications:[[self publicationsInGroup] subarrayWithRange:NSMakeRange(idx, 1)] fromGroups:[NSArray arrayWithObject:self]];
    [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx {
	[self removeFromPublicationsAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKURLGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] URLGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"externalFileGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (NSString *)URLString {
    return [[self URL] absoluteString];
}

- (void)setURLString:(NSString *)newURLString {
    [self setURL:[NSURL URLWithString:newURLString]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (NSURL *)fileURL {
    NSURL *fileURL = [self URL];
    return [fileURL isFileURL] ? fileURL : (id)[NSNull null];
}

- (void)setFileURL:(NSURL *)newURL {
    [self setURL:newURL];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKScriptGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] scriptGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"scriptGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (NSURL *)scriptURL {
    return [NSURL fileURLWithPath:[self scriptPath]];
}

- (void)setScriptURL:(NSURL *)newScriptURL {
    [self setScriptPath:[newScriptURL path]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (NSString *)scriptingScriptArguments {
    NSString *arguments = [self scriptArguments];
    return arguments ? arguments : @"";
}

- (void)setScriptingScriptArguments:(NSString *)newArguments {
    [self setScriptArguments:newArguments];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKSearchGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] searchGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"searchGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (NSString *)scriptingSearchTerm {
    return [self searchTerm];
}

- (void)setScriptingSearchTerm:(NSString *)newSerachTerm {
    [self setSearchTerm:newSerachTerm];
}

- (NSDictionary *)scriptingServerInfo {
    BDSKServerInfo *serverInfo = [self serverInfo];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    int serverType = 0;
    
    if ([serverInfo isEntrez])
        serverType = 'Entr';
    else if ([serverInfo isZoom])
        serverType = 'Zoom';
    else if ([serverInfo isISI])
        serverType = 'ISI ';
    else
        return nil;
    
    [info setValue:[NSNumber numberWithInt:serverType] forKey:@"type"];
    [info setValue:[serverInfo name] forKey:@"name"];
    [info setValue:[serverInfo database] forKey:@"database"];
    if ([serverInfo isZoom]) {
        [info setValue:[serverInfo host] forKey:@"host"];
        [info setValue:[serverInfo port] forKey:@"port"];
        [info setValue:[serverInfo username] forKey:@"username"];
        [info setValue:[serverInfo password] forKey:@"password"];
        [info setValue:[serverInfo recordSyntax] forKey:@"recordSyntax"];
        [info setValue:[serverInfo resultEncoding] forKey:@"resultEncoding"];
        [info setValue:[NSNumber numberWithBool:[serverInfo removeDiacritics]] forKey:@"removeDiacritics"];
    }
    
    return info;
}

- (void)setScriptingServerInfo:(NSDictionary *)info {
    NSString *serverType = nil;
     
    switch ([[info objectForKey:@"type"] intValue]) {
        case 'Entr':
            serverType = BDSKSearchGroupEntrez;
            break;
        case 'Zoom':
            serverType = BDSKSearchGroupZoom;
            break;
        case 'ISI ':
            serverType = BDSKSearchGroupISI;
            break;
        default:
            serverType = [[self serverInfo] type];
    }
    
    BDSKMutableServerInfo *serverInfo = [[self serverInfo] mutableCopy];
    NSString *serverName = [info valueForKey:@"name"];
    NSString *database = [info valueForKey:@"database"];
    NSString *host = [info valueForKey:@"host"];
    NSString *port = [info valueForKey:@"port"];
    NSString *resultEncoding = [info valueForKey:@"resultEncoding"];
    
    if ([[serverInfo type] isEqualToString:type]) {
        serverInfo = [[self serverInfo] mutableCopy];
        
        NSString *value;
        NSNumber *number;
        
        if (serverName)
            [serverInfo setName:serverName];
        if (database)
            [serverInfo setDatabase:database];
        if ([serverType isEqualToString:BDSKSearchGroupZoom]) {
            if (host)
                [serverInfo setHost:host];
            if (port)
                [serverInfo setPort:port];
            if (value = [info valueForKey:@"username"])
                [serverInfo setUsername:value];
            if (value = [info valueForKey:@"password"])
                [serverInfo setPassword:value];
            if (value = [info valueForKey:@"recordSyntax"])
                [serverInfo setRecordSyntax:value];
            if (value = [info valueForKey:@"resultEncoding"])
                [serverInfo setResultEncoding:value];
            if (number = [info valueForKey:@"removeDiacritics"])
                [serverInfo setRemoveDiacritics:[number boolValue]];
        }
    } else {
        NSMutableDictionary *options = nil;
        
         if ([serverType isEqualToString:BDSKSearchGroupZoom]) {
            options = [NSMutableDictionary dictionary];
            [options setValue:[info valueForKey:@"username"] forKey:@"username"];
            [options setValue:[info valueForKey:@"password"] forKey:@"password"];
            [options setValue:[info valueForKey:@"resultEncoding"] forKey:@"resultEncoding"];
            [options setValue:[info valueForKey:@"removeDiacritics"] forKey:@"removeDiacritics"];
        }
        
        serverInfo = [[BDSKMutableServerInfo alloc] initWithType:serverType name:serverName host:host port:port database:database options:options];
    }
    
    BOOL isValid = YES;
    NSEnumerator *keyEnum = [info keyEnumerator];
    NSString *key;
    id value, validatedValue;
    
    if ([NSString isEmptyString:[serverInfo name]] || [NSString isEmptyString:[serverInfo database]])
        isValid = NO;
    else if ([serverInfo isZoom] && ([NSString isEmptyString:[serverInfo host]] || [[serverInfo port] intValue] == 0))
        isValid = NO;
    while (isValid && (key = [keyEnum nextObject])) {
        value = validatedValue = [info valueForKey:key];
        if ((isValid = [serverInfo validateValue:&validatedValue forKey:key error:NULL]) && 
            [validatedValue isEqual:value] == NO)
            [serverInfo setValue:validatedValue forKey:key];
    }
    
    if (isValid) {
        [self setServerInfo:serverInfo];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid server info.",@"Error description")];
    }
    [serverInfo release];
}

@end

#pragma mark -

@implementation BDSKSharedGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] sharedGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"sharedGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

@end

#pragma mark -

@implementation BDSKWebGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"webGroups" index:0] autorelease];
}

@end
