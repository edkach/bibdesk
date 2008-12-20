//
//  NSWorkspace_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/27/05.
/*
 This software is Copyright (c) 2005-2008
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

#import "NSWorkspace_BDSKExtensions.h"
#import <OmniBase/OmniBase.h>
#import <Carbon/Carbon.h>
#import "NSURL_BDSKExtensions.h"

static NSString *BDSKDefaultBrowserKey = @"BDSKDefaultBrowserKey";

@implementation NSWorkspace (BDSKExtensions)

static OSErr
FindRunningAppBySignature( OSType sig, ProcessSerialNumber *psn, FSSpec *fileSpec )
{
    OSErr err;
    ProcessInfoRec info;
    
    psn->highLongOfPSN = 0;
    psn->lowLongOfPSN  = kNoProcess;
    do{
        err= GetNextProcess(psn);
        if( !err ) {
            info.processInfoLength = sizeof(info);
            info.processName = NULL;
            info.processAppSpec = fileSpec;
            err= GetProcessInformation(psn,&info);
        }
    } while( !err && info.processSignature != sig );
    
    if( !err )
        *psn = info.processNumber;
    return err;
}

- (BOOL)openURL:(NSURL *)fileURL withSearchString:(NSString *)searchString
{
    
    // Passing a nil argument is a misuse of this method, so don't do it.
    NSParameterAssert(fileURL != nil);
    NSParameterAssert(searchString != nil);
    NSParameterAssert([fileURL isFileURL]);
    
    /*
     Modified after Apple sample code for FinderLaunch http://developer.apple.com/samplecode/FinderLaunch/FinderLaunch.html
     Create an open documents event targeting the file's creator application; if that doesn't work, fall back on the Finder (which will discard the search text info).
     */
    
    OSStatus err = noErr;
    FSRef fileRef;
    
    // FSRefs are now valid across processes, so we can pass them directly
    fileURL = [fileURL fileURLByResolvingAliases]; 
    OBASSERT(fileURL != nil);
    if(fileURL == nil)
        err = fnfErr;
    else if(CFURLGetFSRef((CFURLRef)fileURL, &fileRef) == NO)
        err = coreFoundationUnknownErr;
    
    // Find the application that should open this file.  NB: we need to release this URL when we're done with it.
    OSType invalidCreator = '???\?';
	OSType appCreator = invalidCreator;
    CFURLRef appURL = NULL;
    FSSpec appSpec;
	if(noErr == err){
        NSString *extension = [[[fileURL path] pathExtension] lowercaseString];
        NSDictionary *defaultViewers = [[OFPreferenceWrapper sharedPreferenceWrapper] dictionaryForKey:BDSKDefaultViewersKey];
        NSString *bundleID = [defaultViewers objectForKey:extension];
		if (bundleID)
            err = LSFindApplicationForInfo(kLSUnknownCreator, (CFStringRef)bundleID, NULL, NULL, &appURL);
        if(appURL == NULL)
            err = LSGetApplicationForURL((CFURLRef)fileURL, kLSRolesAll, NULL, &appURL);
    }
    
    if(err == noErr) {
        // convert application location to FSSpec in case we need it
        FSRef appRef;
        if (CFURLGetFSRef(appURL, &appRef))
            FSGetCatalogInfo(&appRef, kFSCatInfoNone, NULL, NULL, &appSpec, NULL);
        else
            err = fnfErr;
        
        // Get the type info of the creator application from LS, so we know should receive the event
        LSItemInfoRecord lsRecord;
        memset(&lsRecord, 0, sizeof(LSItemInfoRecord));
        
        if(err == noErr)
            err = LSCopyItemInfoForURL(appURL, kLSRequestTypeCreator, &lsRecord);
        
        if (err == noErr){
            appCreator = lsRecord.creator;
            OBASSERT(appCreator != 0); 
            OBASSERT(appCreator != invalidCreator); 
            // if the app has an invalid creator, our AppleEvent stuff won't work
            if (appCreator == 0 || appCreator == invalidCreator)
                err = fnfErr;
        } 
    }
    
    if(appURL) CFRelease(appURL);
    
    NSAppleEventDescriptor *openEvent = nil;
    
    if (err == noErr) {
        NSAppleEventDescriptor *appDesc = nil;
        NSAppleEventDescriptor *fileListDesc = nil;
        NSAppleEventDescriptor *fileDesc = nil;
        
        appDesc = [NSAppleEventDescriptor descriptorWithDescriptorType:typeApplSignature bytes:&appCreator length:sizeof(OSType)];
        openEvent = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenDocuments targetDescriptor:appDesc returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
        fileDesc = [NSAppleEventDescriptor descriptorWithDescriptorType:typeFSRef bytes:&fileRef length:sizeof(FSRef)];
        fileListDesc = [NSAppleEventDescriptor listDescriptor];
        [fileListDesc insertDescriptor:fileDesc atIndex:1];
        [openEvent setParamDescriptor:fileListDesc forKeyword:keyDirectObject];
        if ([NSString isEmptyString:searchString] == NO)
            [openEvent setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:searchString] forKeyword:keyAESearchText];
    }
    
    if (openEvent) {
        
        ProcessSerialNumber psn;
        // don't overwrite our appSpec...
        FSSpec runningAppSpec;
        err = FindRunningAppBySignature(appCreator, &psn, &runningAppSpec);
        
        if (noErr == err) {
            
            // using this call, we end up with the newly opened doc in front; with 'misc'/'actv', window layering is messed up
            err = SetFrontProcessWithOptions(&psn, 0);

            // try to send the odoc event
            if (noErr == err)
                err = AESendMessage([openEvent aeDesc], NULL, kAENoReply, kAEDefaultTimeout);
            
        }
        
         // If the app wasn't running, we need to use LaunchApplication...which doesn't seem to work if the app (at least Skim) is already running, hence the initial call to AESendMessage.  Possibly this can be done with LaunchServices, but the documentation for this stuff isn't sufficient to say and I'm not in the mood for any more trial-and-error AppleEvent coding.
        if (procNotFound == err) {
            
            // This code was distilled from http://static.userland.com/Iowa/sourceListings/macbirdSource/Frontier%20SDK%204.1b1/Toolkits/Applet%20Toolkit/appletprocess.c.html
            LaunchParamBlockRec pb;
            memset(&pb, 0, sizeof(LaunchParamBlockRec));
            pb.launchAppSpec = &appSpec;
            pb.launchBlockID = extendedBlock;
            pb.launchEPBLength = extendedBlockLen;
            pb.launchControlFlags = launchContinue | launchNoFileFlags;
            
            typedef AppParameters **AppParametersHandle;
            
            AppParametersHandle params = NULL;
            // the coercion is apparently a key to making this work
            NSAppleEventDescriptor *launchEvent = [openEvent coerceToDescriptorType:typeAppParameters];
            params = (AppParametersHandle)([launchEvent aeDesc]->dataHandle);
            pb.launchAppParameters = *params;
            err = LaunchApplication (&pb);
        }
    }
    
    // handle the case of '????' creator and probably others
    if (noErr != err || openEvent == nil)
        err = (OSStatus)([self openURL:fileURL] == NO);
    
    return (err == noErr);
}

- (NSString *)UTIForURL:(NSURL *)fileURL resolveAliases:(BOOL)resolve error:(NSError **)error;
{
    NSParameterAssert([fileURL isFileURL]);
    
    NSURL *resolvedURL = resolve ? [fileURL fileURLByResolvingAliases] : fileURL;
    OSStatus err = noErr;
    
    if (nil == resolvedURL)
        err = fnfErr;
    
    FSRef fileRef;
    
    if (noErr == err && FALSE == CFURLGetFSRef((CFURLRef)resolvedURL, &fileRef))
        err = coreFoundationUnknownErr; /* should never happen unless fileURLByResolvingAliases returned nil */
    
    // kLSItemContentType returns a CFStringRef, according to the header
    CFTypeRef theUTI = NULL;
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, &theUTI);
    
    if (noErr != err && NULL != error) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:fileURL, NSURLErrorKey, NSLocalizedString(@"Unable to create UTI", @"Error description"), NSLocalizedDescriptionKey, nil];
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:userInfo];
    }
    
    return [(NSString *)theUTI autorelease];
}

- (BOOL)openLinkedFile:(NSString *)fullPath {
    NSString *extension = [[fullPath pathExtension] lowercaseString];
    NSDictionary *defaultViewers = [[OFPreferenceWrapper sharedPreferenceWrapper] dictionaryForKey:BDSKDefaultViewersKey];
    NSString *appID = [defaultViewers objectForKey:extension];
    NSString *appPath = appID ? [self absolutePathForAppBundleWithIdentifier:appID] : nil;
    BOOL rv = NO;
    
    if (appPath)
        rv = [self openFile:fullPath withApplication:appPath];
    if (rv == NO)
        rv = [self openFile:fullPath];
    return rv;
}

- (BOOL)openLinkedURL:(NSURL *)aURL {
    BOOL rv = NO;
    if ([aURL isFileURL]) {
        rv = [self openLinkedFile:[aURL path]];
    } else {
        NSString *appID = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKDefaultBrowserKey];
        if (appID)
            rv = [self openURLs:[NSArray arrayWithObjects:aURL, nil] withAppBundleIdentifier:appID options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:NULL];
        if (rv == NO)
            rv = [self openURL:aURL];
    }
    return rv;
}

- (BOOL)openURL:(NSURL *)aURL withApplicationURL:(NSURL *)applicationURL;
{
    OSStatus err = kLSUnknownErr;
    if(nil != aURL){
        LSLaunchURLSpec launchSpec;
        memset(&launchSpec, 0, sizeof(LSLaunchURLSpec));
        launchSpec.appURL = (CFURLRef)applicationURL;
        launchSpec.itemURLs = (CFArrayRef)[NSArray arrayWithObject:aURL];
        launchSpec.passThruParams = NULL;
        launchSpec.launchFlags = kLSLaunchDefaults;
        launchSpec.asyncRefCon = NULL;
        
        err = LSOpenFromURLSpec(&launchSpec, NULL);
    }
    return noErr == err ? YES : NO;
}

- (NSArray *)editorAndViewerURLsForURL:(NSURL *)aURL;
{
    NSParameterAssert(aURL);
    
    NSArray *applications = (NSArray *)LSCopyApplicationURLsForURL((CFURLRef)aURL, kLSRolesEditor | kLSRolesViewer);
    
    if(nil != applications){
        // LS seems to return duplicates (same full path), so we'll remove those to avoid confusion
        NSSet *uniqueApplications = [[NSSet alloc] initWithArray:applications];
        [applications release];
            
        // sort by application name
        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"path.lastPathComponent.stringByDeletingPathExtension" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        applications = [[uniqueApplications allObjects] sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
        [sort release];
        [uniqueApplications release];
    }
    
    return applications;
}

- (NSURL *)defaultEditorOrViewerURLForURL:(NSURL *)aURL;
{
    NSParameterAssert(aURL);
    CFURLRef defaultEditorURL = NULL;
    OSStatus err = LSGetApplicationForURL((CFURLRef)aURL, kLSRolesEditor | kLSRolesViewer, NULL, &defaultEditorURL);
    
    // make sure we return nil if there's no application for this URL
    if(noErr != err && NULL != defaultEditorURL){
        CFRelease(defaultEditorURL);
        defaultEditorURL = NULL;
    }
    
    return [(id)defaultEditorURL autorelease];
}

- (NSArray *)editorAndViewerNamesAndBundleIDsForPathExtension:(NSString *)extension;
{
    NSParameterAssert(extension);
    
    NSString *theUTI = [self UTIForPathExtension:extension];
    
    NSArray *bundleIDs = (NSArray *)LSCopyAllRoleHandlersForContentType((CFStringRef)theUTI, kLSRolesEditor | kLSRolesViewer);
    
    NSEnumerator *idEnum = [bundleIDs objectEnumerator];
    NSString *bundleID;
    NSMutableSet *set = [[NSMutableSet alloc] init];
    NSMutableArray *applications = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    while(bundleID = [idEnum nextObject]){
        if ([set containsObject:bundleID]) continue;
        NSString *name = [[fm displayNameAtPath:[self absolutePathForAppBundleWithIdentifier:bundleID]] stringByDeletingPathExtension];
        if (name == nil) continue;
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:bundleID, @"bundleID", name, @"name", nil];
        [applications addObject:dict];
        [dict release];
        [set addObject:bundleID];
    }
    [set release];
    if(bundleIDs)
        CFRelease(bundleIDs);
    
    // sort by application name
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    [applications sortUsingDescriptors:[NSArray arrayWithObject:sort]];
    [sort release];
    
    return applications;
}

- (NSImage *)iconForFileURL:(NSURL *)fileURL;
{
    NSImage *image = nil;
    if(nil != fileURL){
        NSString *filePath = (NSString *)CFURLCopyFileSystemPath((CFURLRef)fileURL, kCFURLPOSIXPathStyle);
        image = [self iconForFile:filePath];
        [filePath release];
    }
    return image;
}

- (NSString *)UTIForURL:(NSURL *)fileURL error:(NSError **)error;
{
    return [self UTIForURL:fileURL resolveAliases:YES error:error];
}

- (NSString *)UTIForURL:(NSURL *)fileURL;
{
    NSError *error;
    NSString *theUTI = [self UTIForURL:fileURL error:&error];
#if defined (OMNI_ASSERTIONS_ON)
    if (nil == theUTI)
        NSLog(@"%@", error);
#endif
    return theUTI;
}

- (NSString *)UTIForPathExtension:(NSString *)extension;
{
    return [(id)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)extension, NULL) autorelease];
}

- (BOOL)isAppleScriptFileAtPath:(NSString *)path {
    NSString *theUTI = [self UTIForURL:[NSURL fileURLWithPath:[path stringByStandardizingPath]]];
    return theUTI ? (UTTypeConformsTo((CFStringRef)theUTI, CFSTR("com.apple.applescript.script")) ||
                     UTTypeConformsTo((CFStringRef)theUTI, CFSTR("com.apple.applescript.text")) ||
                     UTTypeConformsTo((CFStringRef)theUTI, CFSTR("com.apple.applescript.script-bundle")) ) : NO;
}

- (BOOL)isApplicationAtPath:(NSString *)path {
    NSString *theUTI = [self UTIForURL:[NSURL fileURLWithPath:[path stringByStandardizingPath]]];
    return theUTI ? (UTTypeConformsTo((CFStringRef)theUTI, kUTTypeApplication)) : NO;
}

- (BOOL)isFolderAtPath:(NSString *)path {
    NSString *theUTI = [self UTIForURL:[NSURL fileURLWithPath:[path stringByStandardizingPath]]];
    return theUTI ? (UTTypeConformsTo((CFStringRef)theUTI, kUTTypeFolder)) : NO;
}

@end

@implementation NSString (UTIExtensions)

- (BOOL)isEqualToUTI:(NSString *)UTIString;
{
    return (UTIString == nil || UTTypeEqual((CFStringRef)self, (CFStringRef)UTIString) == FALSE) ? NO : YES;
}

@end
