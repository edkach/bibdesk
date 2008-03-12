//
//  BDSKLinkedFile.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/12/07.
/*
 This software is Copyright (c) 2007-2008
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

#import "BDSKLinkedFile.h"
#import <CoreServices/CoreServices.h>
#import <OmniFoundation/NSData-OFExtensions.h>

static void BDSKDisposeAliasHandle(AliasHandle inAlias)
{
    if (inAlias != NULL)
        DisposeHandle((Handle)inAlias);
}

static AliasHandle BDSKDataToAliasHandle(CFDataRef inData)
{
    CFIndex len;
    Handle handle = NULL;
    
    if (inData != NULL) {
        len = CFDataGetLength(inData);
        handle = NewHandle(len);
        
        if ((handle != NULL) && (len > 0)) {
            HLock(handle);
            BlockMoveData(CFDataGetBytePtr(inData), *handle, len);
            HUnlock(handle);
        }
    }
    return (AliasHandle)handle;
}

static CFDataRef BDSKCopyAliasHandleToData(AliasHandle inAlias)
{
    Handle inHandle = (Handle)inAlias;
    CFDataRef data = NULL;
    CFIndex len;
    SInt8 handleState;
    
    if (inHandle != NULL) {
        len = GetHandleSize(inHandle);
        handleState = HGetState(inHandle);
        
        HLock(inHandle);
        
        data = CFDataCreate(kCFAllocatorDefault, (const UInt8 *) *inHandle, len);
        
        HSetState(inHandle, handleState);
    }
    return data;
}

static Boolean BDSKAliasHandleToFSRef(const AliasHandle inAlias, const FSRef *inBaseRef, FSRef *outRef, Boolean *shouldUpdate)
{
    OSStatus err = noErr;
    short aliasCount = 1;
    
    // it would be preferable to search the (relative) path before the fileID, but than links to symlinks will always be resolved to the target
    err = FSMatchAliasNoUI(inBaseRef, kARMNoUI | kARMSearch | kARMSearchRelFirst | kARMTryFileIDFirst, inAlias, &aliasCount, outRef, shouldUpdate, NULL, NULL);
    
    return noErr == err;
}

static AliasHandle BDSKFSRefToAliasHandle(const FSRef *inRef, const FSRef *inBaseRef)
{
    OSStatus err = noErr;
    AliasHandle	alias = NULL;
    
    err = FSNewAlias(inBaseRef, inRef, &alias);
    
    if (err != noErr) {
        BDSKDisposeAliasHandle(alias);
        alias = NULL;
    }
    
    return alias;
}

static Boolean BDSKPathToFSRef(CFStringRef inPath, FSRef *outRef)
{
    OSStatus err = noErr;
    
    if (inPath == NULL)
        err = fnfErr;
    else
        err = FSPathMakeRefWithOptions((UInt8 *)[(NSString *)inPath fileSystemRepresentation], kFSPathMakeRefDoNotFollowLeafSymlink, outRef, NULL); 
    
    return noErr == err;
}

static AliasHandle BDSKPathToAliasHandle(CFStringRef inPath, CFStringRef inBasePath)
{
    FSRef ref, baseRef;
    AliasHandle alias = NULL;
    
    if (BDSKPathToFSRef(inPath, &ref)) {
        if (inBasePath != NULL) {
            if (BDSKPathToFSRef(inBasePath, &baseRef))
                alias = BDSKFSRefToAliasHandle(&ref, &baseRef);
        } else {
            alias = BDSKFSRefToAliasHandle(&ref, NULL);
        }
    }
    
    return alias;
}

// Private concrete subclasses

@interface BDSKLinkedAliasFile : BDSKLinkedFile
{
    AliasHandle alias;
    const FSRef *fileRef;
    NSString *relativePath;
    id delegate;
}

- (id)initWithPath:(NSString *)aPath delegate:(id)aDelegate;

- (const FSRef *)fileRef;

- (NSData *)aliasDataRelativeToPath:(NSString *)newBasePath;

- (void)updateWithPath:(NSString *)path basePath:(NSString *)basePath baseRef:(const FSRef *)baseRef;

@end

#pragma mark -

@interface BDSKLinkedURL : BDSKLinkedFile {
    NSURL *URL;
}
@end

#pragma mark -

// Abstract superclass

@implementation BDSKLinkedFile

static BDSKLinkedFile *defaultPlaceholderLinkedObject = nil;
static Class BDSKLinkedObjectClass = Nil;

+ (void)initialize
{
    OBINITIALIZE;
    if(self == [BDSKLinkedFile class]){
        BDSKLinkedObjectClass = self;
        defaultPlaceholderLinkedObject = (BDSKLinkedFile *)NSAllocateObject(BDSKLinkedObjectClass, 0, NSDefaultMallocZone());
    }
}

+ (id)allocWithZone:(NSZone *)aZone
{
    return BDSKLinkedObjectClass == self ? defaultPlaceholderLinkedObject : NSAllocateObject(self, 0, aZone);
}

- (id)initWithURL:(NSURL *)aURL delegate:(id)aDelegate;
{
    OBASSERT(self == defaultPlaceholderLinkedObject);
    if([aURL isFileURL]){
        self = [[BDSKLinkedAliasFile alloc] initWithURL:aURL delegate:aDelegate];
    } else if (aURL){
        self = [[BDSKLinkedURL alloc] initWithURL:aURL delegate:aDelegate];
    } else {
        self = nil;
    }
    return self;
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id)aDelegate;
{
    OBASSERT(self == defaultPlaceholderLinkedObject);
    return [[BDSKLinkedAliasFile alloc] initWithBase64String:base64String delegate:aDelegate];
}

- (id)initWithURLString:(NSString *)aString;
{
    OBASSERT(self == defaultPlaceholderLinkedObject);
    return [[BDSKLinkedURL alloc] initWithURLString:aString];
}

- (id)copyWithZone:(NSZone *)aZone
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initWithCoder:(NSCoder *)coder
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    OBRequestConcreteImplementation(self, _cmd);
}

- (void)dealloc
{
    if ([self class] != BDSKLinkedObjectClass)
        [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: URL=%@>", [self class], [self URL]];
}

- (NSURL *)URL
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSURL *)displayURL;
{
    return [self URL];
}

- (NSString *)path;
{
    return [[self URL] path];
}

- (NSString *)stringRelativeToPath:(NSString *)newBasePath;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (BOOL)isFile { return NO; }

- (void)update { [self updateWithPath:nil]; }
- (void)updateWithPath:(NSString *)aPath {}

- (NSString *)relativePath { return nil; }

- (void)setDelegate:(id)aDelegate {}
- (id)delegate { return nil; }

// for templating
- (id)valueForUndefinedKey:(NSString *)key {
    return [[self URL] valueForKey:key];
}

@end

#pragma mark -

// Alias- and FSRef-based concrete subclass for local files

@implementation BDSKLinkedAliasFile

// takes possession of anAlias, even if it fails
- (id)initWithAlias:(AliasHandle)anAlias relativePath:(NSString *)relPath delegate:(id)aDelegate;
{
    OBASSERT(nil == aDelegate || [aDelegate respondsToSelector:@selector(basePathForLinkedFile:)]);
    
    if (anAlias == NULL) {
        [[super init] release];
        self = nil;
    } else if (self = [super init]) {
        fileRef = NULL; // this is updated lazily, as we don't know the base path at this point
        alias = anAlias;
        relativePath = [relPath copy];
        delegate = aDelegate;
    } else {
        BDSKDisposeAliasHandle(anAlias);
    }
    return self;    
}

- (id)initWithAliasData:(NSData *)data relativePath:(NSString *)relPath delegate:(id)aDelegate;
{
    OBASSERT(nil != data);
    
    AliasHandle anAlias = BDSKDataToAliasHandle((CFDataRef)data);
    return [self initWithAlias:anAlias relativePath:relPath delegate:aDelegate];
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id)aDelegate;
{
    OBASSERT(nil != base64String);
    
    NSData *data = nil;
    NSDictionary *dictionary = nil;
    @try {
        data = [[NSData alloc] initWithBase64String:base64String];
    }
    @catch(id exception) {
        [data release];
        data = nil;
        NSLog(@"Ignoring exception \"%@\" while getting data from base 64 string.", exception);
    }
    @try {
        dictionary = data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
    }
    @catch(id exception) {
        NSLog(@"Ignoring exception \"%@\" while unarchiving data from base 64 string.", exception);
    }
    [data release];
    return [self initWithAliasData:[dictionary objectForKey:@"aliasData"] relativePath:[dictionary objectForKey:@"relativePath"] delegate:aDelegate];
}

- (id)initWithPath:(NSString *)aPath delegate:(id)aDelegate;
{
    OBASSERT(nil != aPath);
    OBASSERT(nil == aDelegate || [aDelegate respondsToSelector:@selector(basePathForLinkedFile:)]);
    
    NSString *basePath = [aDelegate basePathForLinkedFile:self];
    NSString *relPath = [basePath relativePathToFilename:aPath];
    AliasHandle anAlias = BDSKPathToAliasHandle((CFStringRef)aPath, (CFStringRef)basePath);
    
    if (self = [self initWithAlias:anAlias relativePath:relPath delegate:aDelegate]) {
        if (basePath)
            // this initalizes the FSRef and update the alias
            [self fileRef];
    }
    return self;
}

- (id)initWithURL:(NSURL *)aURL delegate:(id)aDelegate;
{
    OBASSERT([aURL isFileURL]);
    
    return [self initWithPath:[aURL path] delegate:aDelegate];
}

- (id)initWithURLString:(NSString *)aString;
{
    OBASSERT_NOT_REACHED("Attempt to initialize BDSKLinkedAliasFile with a URL string");
    return nil;
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSData *data = nil;
    NSString *relPath = nil;
    if ([coder allowsKeyedCoding]) {
        data = [coder decodeObjectForKey:@"aliasData"];
        relPath = [coder decodeObjectForKey:@"relativePath"];
    } else {
        data = [coder decodeObject];
        relPath = [coder decodeObject];
    }
    return [self initWithAliasData:data relativePath:relPath delegate:nil];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        [coder encodeObject:[self aliasDataRelativeToPath:[delegate basePathForLinkedFile:self]] forKey:@"aliasData"];
        [coder encodeObject:relativePath forKey:@"relativePath"];
    } else {
        [coder encodeObject:[self aliasDataRelativeToPath:[delegate basePathForLinkedFile:self]]];
        [coder encodeObject:relativePath];
    }
}

- (void)dealloc
{
    NSZoneFree([self zone], (void *)fileRef);
    BDSKDisposeAliasHandle(alias);
    [relativePath release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [[[self class] allocWithZone:aZone] initWithAliasData:[self aliasDataRelativeToPath:[delegate basePathForLinkedFile:self]] relativePath:relativePath delegate:delegate];
}

// Should we implement -isEqual: and -hash?

- (NSString *)stringDescription {
    return [self path];
}

- (BOOL)isFile
{
    return YES;
}

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    OBASSERT(nil == newDelegate || [newDelegate respondsToSelector:@selector(basePathForLinkedFile:)]);
    
    delegate = newDelegate;
}

- (NSString *)relativePath {
    return relativePath;
}

- (void)setRelativePath:(NSString *)newRelativePath {
    if (relativePath != newRelativePath) {
        [relativePath release];
        relativePath = [newRelativePath retain];
    }
}

- (void)setFileRef:(const FSRef *)newFileRef;
{
    if (fileRef != NULL) {
        NSZoneFree([self zone], (void *)fileRef);
        fileRef = NULL;
    }
    if (newFileRef != NULL) {
        FSRef *newRef = (FSRef *)NSZoneMalloc([self zone], sizeof(FSRef));
        if (newRef) {
            bcopy(newFileRef, newRef, sizeof(FSRef));
            fileRef = newRef;
        }
    }
}

- (const FSRef *)fileRef;
{
    NSString *basePath = [delegate basePathForLinkedFile:self];
    FSRef baseRef;
    Boolean hasBaseRef = basePath && BDSKPathToFSRef((CFStringRef)basePath, &baseRef);
    Boolean shouldUpdate = false;
    
    if (fileRef == NULL) {
        FSRef aRef;
        Boolean hasRef = false;
        
        if (hasBaseRef && relativePath) {
            NSString *path = [basePath stringByAppendingPathComponent:relativePath];
            shouldUpdate = hasRef = BDSKPathToFSRef((CFStringRef)path, &aRef);
        }
        
        if (hasRef == false && alias != NULL) {
            hasRef = BDSKAliasHandleToFSRef(alias, hasBaseRef ? &baseRef : NULL, &aRef, &shouldUpdate);
            shouldUpdate = shouldUpdate && hasBaseRef && hasRef;
        }
        
        if (hasRef)
            [self setFileRef:&aRef];
    } else if (relativePath == nil) {
        shouldUpdate = hasBaseRef;
    }
    
    if (shouldUpdate) {
        CFURLRef aURL = CFURLCreateFromFSRef(NULL, fileRef);
        if (aURL != NULL) {
            [self updateWithPath:[(NSURL *)aURL path] basePath:basePath baseRef:&baseRef];
            CFRelease(aURL);
        }
    }
    
    return fileRef;
}

- (NSURL *)URL;
{
    BOOL hadFileRef = fileRef != NULL;
    CFURLRef aURL = (hadFileRef || [self fileRef]) ? CFURLCreateFromFSRef(NULL, fileRef) : NULL;
    
    if (aURL == NULL && hadFileRef) {
        // fileRef was invalid, try to update it
        [self setFileRef:NULL];
        if ([self fileRef] != NULL)
            aURL = CFURLCreateFromFSRef(NULL, fileRef);
    }
    return [(NSURL *)aURL autorelease];
}

- (NSURL *)displayURL;
{
    NSURL *displayURL = [self URL];
    if (displayURL == nil && relativePath)
        displayURL = [NSURL fileURLWithPath:relativePath];
    return displayURL;
}

- (NSData *)aliasDataRelativeToPath:(NSString *)basePath;
{
    // make sure the fileRef is valid
    [self URL];
    
    FSRef *fsRef = (FSRef *)[self fileRef];
    FSRef baseRef;
    AliasHandle anAlias = NULL;
    CFDataRef data = NULL;
    
    if (fsRef) {
        BOOL hasBaseRef = (basePath && BDSKPathToFSRef((CFStringRef)basePath, &baseRef));
        anAlias = BDSKFSRefToAliasHandle(fsRef, hasBaseRef ? &baseRef : NULL);
    } else if (relativePath && basePath) {
        anAlias = BDSKPathToAliasHandle((CFStringRef)[basePath stringByAppendingPathComponent:relativePath], (CFStringRef)basePath);
    }
    if (anAlias != NULL) {
        data = BDSKCopyAliasHandleToData(anAlias);
        BDSKDisposeAliasHandle(anAlias);
    } else if (alias != NULL) {
        data = BDSKCopyAliasHandleToData(alias);
    }
    
    return [(NSData *)data autorelease];
}

- (NSString *)stringRelativeToPath:(NSString *)newBasePath;
{
    NSData *data = [self aliasDataRelativeToPath:newBasePath];
    NSString *path = [self path];
    path = path && newBasePath ? [newBasePath relativePathToFilename:path] : relativePath;
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:data, @"aliasData", path, @"relativePath", nil];
    return [[NSKeyedArchiver archivedDataWithRootObject:dictionary] base64String];
}

// this could be called when the document fileURL changes
- (void)updateWithPath:(NSString *)aPath {
    NSString *basePath = [delegate basePathForLinkedFile:self];
    
    if (fileRef == NULL) {
        // this does the updating if possible
        [self fileRef];
    } else {
        CFURLRef aURL = CFURLCreateFromFSRef(NULL, fileRef);
        if (aURL != NULL) {
            FSRef baseRef;
            if (basePath && BDSKPathToFSRef((CFStringRef)basePath, &baseRef))
                [self updateWithPath:[(NSURL *)aURL path] basePath:basePath baseRef:&baseRef];
            CFRelease(aURL);
        } else {
            // the fileRef was invalid, reset it and update
            [self setFileRef:NULL];
            [self fileRef];
            if (fileRef == NULL) {
                // this can happen after an auto file to a volume, as the file is actually not moved but copied
                AliasHandle anAlias = BDSKPathToAliasHandle((CFStringRef)aPath, (CFStringRef)basePath);
                if (anAlias != NULL) {
                    AliasHandle saveAlias = alias;
                    alias = anAlias;
                    [self fileRef];
                    if (fileRef == NULL) {
                        alias = saveAlias;
                        [self fileRef];
                    } else {
                        BDSKDisposeAliasHandle(saveAlias);
                    }
                }
            }
        }
    }
}

- (void)updateWithPath:(NSString *)path basePath:(NSString *)basePath baseRef:(const FSRef *)baseRef {
    OBASSERT(path != nil);
    OBASSERT(basePath != nil);
    OBASSERT(baseRef != NULL);
    OBASSERT(fileRef != NULL);
    
    Boolean didUpdate;
    
    // update the alias
    if (alias != NULL)
        FSUpdateAlias(baseRef, fileRef, alias, &didUpdate);
    else
        alias = BDSKFSRefToAliasHandle(fileRef, baseRef);
    
    // update the relative path
    [relativePath autorelease];
    relativePath = [[basePath relativePathToFilename:path] retain];
}

@end

#pragma mark -

// URL based concrete subclass for remote URLs

@implementation BDSKLinkedURL

- (id)initWithURL:(NSURL *)aURL delegate:(id)aDelegate;
{
    if (self = [super init]) {
        if (aURL) {
            URL = [aURL copy];
        } else {
            [self release];
            self = nil;
        }
            
    }
    return self;
}

- (id)initWithURLString:(NSString *)aString;
{
    return [self initWithURL:[NSURL URLWithString:aString] delegate:nil];
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id)aDelegate;
{
    OBASSERT_NOT_REACHED("Attempt to initialize BDSKLinkedURL with a base 64 string");
    return nil;
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [[[self class] allocWithZone:aZone] initWithURL:URL delegate:nil];
}

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super init]) {
        if ([coder allowsKeyedCoding]) {
            URL = [[coder decodeObjectForKey:@"URL"] retain];
        } else {
            URL = [[coder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        [coder encodeObject:URL forKey:@"URL"];
    } else {
        [coder encodeObject:URL];
    }
}

- (void)dealloc
{
    [URL release];
    [super dealloc];
}

- (NSString *)stringDescription {
    return [[self URL] absoluteString];
}

- (NSURL *)URL
{
    return URL;
}

- (NSString *)stringRelativeToPath:(NSString *)newBasePath;
{
    return [URL absoluteString];
}

@end
