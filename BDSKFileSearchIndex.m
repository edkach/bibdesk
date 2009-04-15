//
//  BDSKFileSearchIndex.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/11/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKFileSearchIndex.h"
#import "BibDocument.h"
#import "BibItem.h"
#import <libkern/OSAtomic.h>
#import "BDSKManyToManyDictionary.h"
#import "NSObject_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSData_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "UKDirectoryEnumerator.h"
#import "BDSKReadWriteLock.h"

@interface BDSKFileSearchIndex (Private)

+ (NSString *)indexCacheFolder;
- (void)runIndexThreadWithInfo:(NSDictionary *)info;
- (void)processNotification:(NSNotification *)note;
- (void)writeIndexToDiskForDocumentURL:(NSURL *)documentURL;

@end

#pragma mark -

@implementation BDSKFileSearchIndex

#define INDEX_STARTUP 1
#define INDEX_STARTUP_COMPLETE 2
#define INDEX_THREAD_WORKING 3
#define INDEX_THREAD_DONE 4

// increment if incompatible changes are introduced
#define CACHE_VERSION @"1"

#pragma mark API

- (id)initForDocument:(BibDocument *)aDocument
{
    BDSKASSERT([NSThread isMainThread]);

    self = [super init];
        
    if(nil != self){
        // maintain dictionaries mapping URL -> signature, so we can check if a URL is outdated
        signatures = [[NSMutableDictionary alloc] initWithCapacity:128];
        
        index = NULL;
        
        // new document won't have a URL, so we'll have to wait for the controller to set it
        NSURL *documentURL = [aDocument fileURL];
        NSArray *items = [[aDocument publications] arrayByPerformingSelector:@selector(searchIndexInfo)];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:items, @"items", documentURL, @"documentURL", nil];
        
        // setting up the cache folder is not thread safe, so make sure it's done on the main thread
        [[self class] indexCacheFolder];
        
        delegate = nil;
        lastUpdateTime = CFAbsoluteTimeGetCurrent();
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        SEL handler = @selector(processNotification:);
        [nc addObserver:self selector:handler name:BDSKFileSearchIndexInfoChangedNotification object:aDocument];
        [nc addObserver:self selector:handler name:BDSKDocAddItemNotification object:aDocument];
        [nc addObserver:self selector:handler name:BDSKDocDelItemNotification object:aDocument];
        
        flags.finishedInitialIndexing = 0;
        flags.updateScheduled = 1;
        
        // maintain dictionaries mapping URL -> identifierURL, since SKIndex properties are slow; this should be accessed with the rwlock
        identifierURLs = [[BDSKManyToManyDictionary alloc] init];
		rwLock = [[BDSKReadWriteLock alloc] init];
        
        progressValue = 0.0;
        
        setupLock = [[NSConditionLock alloc] initWithCondition:INDEX_STARTUP];
        
        // this will create a retain cycle, so we'll have to tickle the thread to exit properly in -cancel
        [NSThread detachNewThreadSelector:@selector(runIndexThreadWithInfo:) toTarget:self withObject:info];
        
        // block until the NSMachPort is set up to receive messages
        [setupLock lockWhenCondition:INDEX_STARTUP_COMPLETE];
        [setupLock unlockWithCondition:INDEX_THREAD_WORKING];

    }
    
    return self;
}

- (void)dealloc
{
    [rwLock lockForWriting];
	[identifierURLs release];
    identifierURLs = nil;
    [rwLock unlock];
    [rwLock release];
    [notificationPort release];
    [notificationQueue release];
    [noteLock release];
    [signatures release];
    if(index) CFRelease(index);
    if(indexData) CFRelease(indexData);
    [setupLock release];
    [super dealloc];
}

// cancel is always sent from the main thread
- (void)cancelForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert([NSThread isMainThread]);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    OSAtomicCompareAndSwap32Barrier(flags.shouldKeepRunning, 0, (int32_t *)&flags.shouldKeepRunning);
    
    // wake the thread up so the runloop will exit; shouldKeepRunning may have already done that, so don't send if the port is already dead
    if ([notificationPort isValid])
        [notificationPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];
    
    // wait until the thread exits, so we have exclusive access to the ivars
    [setupLock lockWhenCondition:INDEX_THREAD_DONE];
    [self writeIndexToDiskForDocumentURL:documentURL];
    [setupLock unlock];
}

- (SKIndexRef)index
{
    return index;
}

- (BOOL)finishedInitialIndexing
{
    OSMemoryBarrier();
    return flags.finishedInitialIndexing == 1;
}

- (void)setDelegate:(id <BDSKFileSearchIndexDelegate>)anObject
{
    if(anObject)
        NSAssert1([(id)anObject conformsToProtocol:@protocol(BDSKFileSearchIndexDelegate)], @"%@ does not conform to BDSKFileSearchIndexDelegate protocol", [anObject class]);

    delegate = anObject;
}

- (NSSet *)allIdentifierURLsForURL:(NSURL *)theURL
{
    [rwLock lockForReading];
    NSSet *set = [[[identifierURLs allObjectsForKey:theURL] copy] autorelease];
    [rwLock unlock];
    return set;
}

- (double)progressValue
{
    double theValue;
    @synchronized(self) {
        theValue = progressValue;
    }
    return theValue;
}

#pragma mark Private methods

#pragma mark Caching

// this can return any object conforming to NSCoding
static inline id signatureForURL(NSURL *aURL) {
    // Use the SHA1 signature if we can get it
    id signature = [NSData sha1SignatureForFile:[aURL path]];
    if (signature == nil) {
        // this could happen for packages, use a timestamp instead
        FSRef fileRef;
        FSCatalogInfo info;
        CFAbsoluteTime absoluteTime;
        
        if (CFURLGetFSRef((CFURLRef)aURL, &fileRef) &&
            noErr == FSGetCatalogInfo(&fileRef, kFSCatInfoContentMod, &info, NULL, NULL, NULL) &&
            noErr == UCConvertUTCDateTimeToCFAbsoluteTime(&info.contentModDate, &absoluteTime)) {
            signature = [NSDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)absoluteTime];
        }
    }
    return signature ? signature : [NSData data];
}

+ (NSString *)indexCacheFolder
{
    static NSString *cacheFolder = nil;
    if (nil == cacheFolder) {
        cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        cacheFolder = [cacheFolder stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        if (cacheFolder && [[NSFileManager defaultManager] fileExistsAtPath:cacheFolder] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheFolder attributes:nil];
        cacheFolder = [cacheFolder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-v%@", NSStringFromClass(self), CACHE_VERSION]];
        if (cacheFolder && [[NSFileManager defaultManager] fileExistsAtPath:cacheFolder] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheFolder attributes:nil];
        cacheFolder = [cacheFolder copy];
    }
    return cacheFolder;
}

static inline BOOL isIndexCacheForDocumentURL(NSString *path, NSURL *documentURL) {
    BOOL isIndexCache = NO;
    NSData *data = [NSData dataWithContentsOfMappedFile:path];
    if (data) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        isIndexCache = [[unarchiver decodeObjectForKey:@"documentURL"] isEqual:documentURL];
        [unarchiver finishDecoding];
        [unarchiver release];
    }
    return isIndexCache;
}

// Read each cache file and see which one has a matching documentURL.  If this gets too slow, we could save a plist mapping URL -> UUID and use that instead.
+ (NSString *)indexCachePathForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert(nil != documentURL);
    NSString *indexCachePath = nil;
    NSString *indexCacheFolder = [self indexCacheFolder];
    NSString *defaultPath = [[[[documentURL path] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bdskindex"];
    
    defaultPath = [indexCacheFolder stringByAppendingPathComponent:defaultPath];
    if (isIndexCacheForDocumentURL(defaultPath, documentURL)) {
        indexCachePath = defaultPath;
    } else {
        UKDirectoryEnumerator *indexEnum = [UKDirectoryEnumerator enumeratorWithPath:indexCacheFolder];
        NSString *path;
        
        while ((path = [indexEnum nextObjectFullPath]) && nil == indexCachePath) {
            if ([[path pathExtension] isEqualToString:@"bdskindex"] && 
                [path isEqualToString:defaultPath] == NO && 
                isIndexCacheForDocumentURL(path, documentURL))
                indexCachePath = path;
        }
    }
    return indexCachePath;
}

- (void)writeIndexToDiskForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert([NSThread isMainThread]);
    NSParameterAssert([setupLock condition] == INDEX_THREAD_DONE);
    
    // @@ temporary for testing
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableFileSearchIndexCacheKey"])
        return;
    
    if (index && documentURL) {
        // flush all pending updates and compact the index as needed before writing
        SKIndexCompact(index);
        CFRelease(index);
        index = NULL;
        
        NSString *indexCachePath = [[self class] indexCachePathForDocumentURL:documentURL];
        if (nil == indexCachePath) {
            indexCachePath = [[[[documentURL path] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bdskindex"];
            indexCachePath = [[NSFileManager defaultManager] uniqueFilePathWithName:indexCachePath atPath:[[self class] indexCacheFolder]];
        }
        
        NSMutableData *data = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
        [archiver encodeObject:documentURL forKey:@"documentURL"];
        [archiver encodeObject:(NSMutableData *)indexData forKey:@"indexData"];
        [archiver encodeObject:signatures forKey:@"signatures"];
        [archiver finishEncoding];
        [archiver release];
        [data writeToFile:indexCachePath atomically:YES];
    }
}

#pragma mark Update callbacks

- (void)notifyDelegate
{
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.updateScheduled);
    [delegate searchIndexDidUpdate:self];
}

- (void)searchIndexDidUpdate
{
    BDSKASSERT([NSThread isMainThread]);
    // Make sure we send frequently enough to update a progress bar, but not too frequently to avoid beachball on single-core systems; too many search updates slow down indexing due to repeated flushes. 
    if (0 == flags.updateScheduled) {
        [self performSelector:@selector(_notifyDelegate) withObject:nil afterDelay:0.5];
        OSAtomicCompareAndSwap32Barrier(0, 1, &flags.updateScheduled);
    }
}

// @@ only sent after the initial indexing so the controller knows to remove the progress bar; can possibly be removed entirely and delegate can check finishedInitialIndexing when it gets searchIndexDidUpdate:
- (void)searchIndexDidFinish
{
    BDSKASSERT([NSThread isMainThread]);
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1)
        [delegate searchIndexDidFinish:self];
}

#pragma mark Indexing

- (void)indexFileURL:(NSURL *)aURL{
    id signature = signatureForURL(aURL);
    
    if ([[signatures objectForKey:aURL] isEqual:signature] == NO) {
        // either the file was not indexed, or it has changed
        
        SKDocumentRef skDocument = SKDocumentCreateWithURL((CFURLRef)aURL);
        
        BDSKPOSTCONDITION(skDocument);
        
        if (skDocument != NULL) {
            
            BDSKASSERT(signature);
            [signatures setObject:signature forKey:aURL];
            
            SKIndexAddDocument(index, skDocument, NULL, TRUE);
            CFRelease(skDocument);
        }
    }
}

- (void)removeFileURL:(NSURL *)aURL{
    SKDocumentRef skDocument = SKDocumentCreateWithURL((CFURLRef)aURL);
    
    BDSKPOSTCONDITION(skDocument);
    
    if (skDocument != NULL) {
        [signatures removeObjectForKey:aURL];
        
        SKIndexRemoveDocument(index, skDocument);
        CFRelease(skDocument);
    }
}

- (void)indexFileURLs:(NSSet *)urlsToAdd forIdentifierURL:(NSURL *)identifierURL
{
    BDSKASSERT([[NSThread currentThread] isEqual:notificationThread]);
    
    BDSKASSERT(identifierURL);
    
    // SKIndexSetProperties is more generally useful, but is really slow when creating the index
    // SKIndexRenameDocument changes the URL, so it's not useful
    
    [rwLock lockForWriting];
    [identifierURLs addObject:identifierURL forKeys:urlsToAdd];
    [rwLock unlock];
    
    NSEnumerator *urlEnum = [urlsToAdd objectEnumerator];
    NSURL *url = nil;
    
    while(url = [urlEnum nextObject])
        [self indexFileURL:url];
    
    // the caller is responsible for updating the delegate, so we can throttle initial indexing
}

- (void)removeFileURLs:(NSSet *)urlsToRemove forIdentifierURL:(NSURL *)identifierURL
{
    BDSKASSERT([[NSThread currentThread] isEqual:notificationThread]);

    BDSKASSERT(identifierURL);
        
    NSEnumerator *urlEnum = nil;
    NSURL *url = nil;
    BOOL shouldBeRemoved;
    
    urlEnum = [urlsToRemove objectEnumerator];
    
    // loop through the array of URLs, create a new SKDocumentRef, and try to remove it
    while (url = [urlEnum nextObject]) {
        
        [rwLock lockForWriting];
        [identifierURLs removeObject:identifierURL forKey:url];
        shouldBeRemoved = (0 == [identifierURLs countForKey:url]);
        [rwLock unlock];
        
        if (shouldBeRemoved)
            [self removeFileURL:url];
	}
    
    // the caller is responsible for updating the delegate, so we can throttle initial indexing
}

- (void)indexFilesForItems:(NSArray *)items numberPreviouslyIndexed:(double)numberIndexed totalCount:(double)totalObjectCount
{
    NSAssert2([[NSThread currentThread] isEqual:notificationThread], @"-[%@ %@] must be called from the worker thread!", [self class], NSStringFromSelector(_cmd));
    
    NSEnumerator *enumerator = [items objectEnumerator];
    id anObject = nil;
        
    // Use a local pool since initial indexing can use a fair amount of memory, and it's not released until the thread's run loop starts
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
        
    OSMemoryBarrier();
    while(flags.shouldKeepRunning == 1 && (anObject = [enumerator nextObject])) {
        [self indexFileURLs:[NSSet setWithArray:[anObject objectForKey:@"urls"]] forIdentifierURL:[anObject objectForKey:@"identifierURL"]];
        numberIndexed++;
        @synchronized(self) {
            progressValue = (numberIndexed / totalObjectCount) * 100;
        }
        
        [pool release];
        pool = [NSAutoreleasePool new];
        
        if (0 == flags.updateScheduled)
            [self performSelectorOnMainThread:@selector(searchIndexDidUpdate) withObject:nil waitUntilDone:NO];
        OSMemoryBarrier();
    }
        
    // caller queues a final update
    
    [pool release];
}

#pragma mark Thread initialization

static void addItemFunction(const void *value, void *context) {
    BDSKManyToManyDictionary *dict = (BDSKManyToManyDictionary *)context;
    NSDictionary *item = (NSDictionary *)value;
    NSURL *identifierURL = [item objectForKey:@"identifierURL"];
    NSSet *keys = [[NSSet alloc] initWithArray:[item objectForKey:@"urls"]];
    [dict addObject:identifierURL forKeys:keys];
    [keys release];
}

- (void)buildIndexWithInfo:(NSDictionary *)info
{
    NSAssert2([[NSThread currentThread] isEqual:notificationThread], @"-[%@ %@] must be called from the worker thread!", [self class], NSStringFromSelector(_cmd));
    
    SKIndexRef tmpIndex = NULL;
    NSURL *documentURL = [info objectForKey:@"documentURL"];
    NSString *indexCachePath = documentURL ? [[self class] indexCachePathForDocumentURL:documentURL] : nil;
    NSArray *items = [info objectForKey:@"items"];
    
    double totalObjectCount = [items count];
    double numberIndexed = 0;
    
    BDSKPRECONDITION(items);
    
    [items retain];
    
    if (indexCachePath) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSData dataWithContentsOfFile:indexCachePath]];
        indexData = (CFMutableDataRef)[[unarchiver decodeObjectForKey:@"indexData"] mutableCopy];
        if (indexData != NULL) {
            tmpIndex = SKIndexOpenWithMutableData(indexData, NULL);
            if (tmpIndex) {
                [signatures setDictionary:[unarchiver decodeObjectForKey:@"signatures"]];
            } else {
                CFRelease(indexData);
                indexData = NULL;
            }
        }
        [unarchiver finishDecoding];
        [unarchiver release];
    }
    
    if (tmpIndex == NULL) {
        indexData = CFDataCreateMutable(CFAllocatorGetDefault(), 0);
        tmpIndex = SKIndexCreateWithMutableData(indexData, NULL, kSKIndexInverted, NULL);
    }
    
    index = tmpIndex;
    
    if ([signatures count]) {
        // cached index, update identifierURLs and remove unlinked or invalid indexed URLs
        
        // set the identifierURLs map, so we can build search results immediately; no problem if it contains URLs that were not indexed or are replaced, we know these URLs should be added eventually
        OSMemoryBarrier();
        if (flags.shouldKeepRunning == 1) {
            [rwLock lockForWriting];
            CFArrayApplyFunction((CFArrayRef)items, CFRangeMake(0, totalObjectCount), addItemFunction, (void *)identifierURLs);
            [rwLock unlock];
        }
        
        if (0 == flags.updateScheduled)
            [self performSelectorOnMainThread:@selector(searchIndexDidUpdate) withObject:nil waitUntilDone:NO];
        
        NSMutableSet *URLsToRemove = [[NSMutableSet alloc] initWithArray:[signatures allKeys]];
        NSMutableArray *itemsToAdd = [[NSMutableArray alloc] init];
        NSEnumerator *itemEnum = [items objectEnumerator];
        id anItem = nil;
        
        // find URLs in the database that needs to be indexed, and URLs that were indexeed but are not in the database anymore
        OSMemoryBarrier();
        while(flags.shouldKeepRunning == 1 && (anItem = [itemEnum nextObject])) {
            
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            
            NSURL *identifierURL = [anItem objectForKey:@"identifierURL"];
            NSEnumerator *urlEnum = [[anItem objectForKey:@"urls"] objectEnumerator];
            NSURL *url;
            NSMutableArray *missingURLs = nil;
            id signature;
            
            while (url = [urlEnum nextObject]) {
                signature = [signatures objectForKey:url];
                if (signature && [signature isEqual:signatureForURL(url)]) {
                    [URLsToRemove removeObject:url];
                } else {
                    if (missingURLs == nil)
                        missingURLs = [NSMutableArray array];
                    [missingURLs addObject:url];
                }
            }
            
            if ([missingURLs count]) {
                [itemsToAdd addObject:[NSDictionary dictionaryWithObjectsAndKeys:identifierURL, @"identifierURL", missingURLs, @"urls", nil]];
            } else {
                numberIndexed++;
                @synchronized(self) {
                    progressValue = (numberIndexed / totalObjectCount) * 100;
                }
                
                if (0 == flags.updateScheduled)
                    [self performSelectorOnMainThread:@selector(searchIndexDidUpdate) withObject:nil waitUntilDone:NO];
            }
            
            [pool release];
            OSMemoryBarrier();
        }
            
        // remove URLs we could not find in the database
        OSMemoryBarrier();
        if (flags.shouldKeepRunning == 1 && [URLsToRemove count]) {
            NSEnumerator *urlEnum = [URLsToRemove objectEnumerator];
            NSURL *url;
            while (url = [urlEnum nextObject])
                [self removeFileURL:url];
        }
        [URLsToRemove release];
        
        if (0 == flags.updateScheduled)
            [self performSelectorOnMainThread:@selector(searchIndexDidUpdate) withObject:nil waitUntilDone:NO];
        
        [items release];
        items = itemsToAdd;
        
    }
    
    // add items that were not yet indexed
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1 && [items count]) {
        [self indexFilesForItems:items numberPreviouslyIndexed:numberIndexed totalCount:totalObjectCount];
    }
    
    [items release];

    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.finishedInitialIndexing);
    [self performSelectorOnMainThread:@selector(searchIndexDidFinish) withObject:nil waitUntilDone:NO];
}

- (void)runIndexThreadWithInfo:(NSDictionary *)info
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [setupLock lockWhenCondition:INDEX_STARTUP];
    
    // release at the end of this method, just before the thread exits
    notificationThread = [[NSThread currentThread] retain];
    
    notificationPort = [[NSMachPort alloc] init];
    [notificationPort setDelegate:self];
    [[NSRunLoop currentRunLoop] addPort:notificationPort forMode:NSDefaultRunLoopMode];
    
    notificationQueue = [[NSMutableArray alloc] initWithCapacity:5];
    noteLock = [[NSLock alloc] init];
    
    [setupLock unlockWithCondition:INDEX_STARTUP_COMPLETE];
    
    [setupLock lockWhenCondition:INDEX_THREAD_WORKING];
    
    // an exception here can probably be ignored safely
    @try{
        [self buildIndexWithInfo:info];
    }
    @catch(id localException){
        NSLog(@"Ignoring exception %@ raised while rebuilding index", localException);
    }
        
    // run the current run loop until we get a cancel message, or else the current thread/run loop will just go away when this function returns    
    @try{
        
        NSRunLoop *rl = [NSRunLoop currentRunLoop];
        BOOL keepRunning;
        NSDate *distantFuture = [NSDate distantFuture];
        
        do {
            [pool release];
            pool = [[NSAutoreleasePool alloc] init];
            // Running with beforeDate: distantFuture causes the runloop to block indefinitely if shouldKeepRunning was set to 0 during the initial indexing phase; invalidating and removing the port manually doesn't change this.  Hence, we need to check that flag before running the runloop, or use a short limit date.
            OSMemoryBarrier();
            keepRunning = (flags.shouldKeepRunning == 1) && [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
        } while(keepRunning);
    }
    @catch(id localException){
        NSLog(@"Exception %@ raised in search index; exiting thread run loop.", localException);
        
        // clean these up to make sure we have no chance of saving it to disk
        if (index) CFRelease(index);
        index = NULL;
        if (indexData) CFRelease(indexData);
        indexData = NULL;
        @throw;
    }
    @finally{
        // allow the top-level pool to catch this autorelease pool
        
        [notificationThread release];
        notificationThread = nil;
        [notificationPort invalidate];
        [setupLock unlockWithCondition:INDEX_THREAD_DONE];
    }
}

#pragma mark Change notification handling

- (void)processNotification:(NSNotification *)note
{    
    BDSKASSERT([NSThread isMainThread]);
    // get the search index info, don't use the note because we don't want to retain the pubs
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[note name], @"name", 
                                [[note userInfo] valueForKeyPath:@"pubs.searchIndexInfo"], @"searchIndexInfo", nil];
    [noteLock lock];
    [notificationQueue addObject:info]; // Forward the notification to the correct thread
    [noteLock unlock];
    [notificationPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];
}

- (void)handleDocAddItem:(NSArray *)searchIndexInfo
{
    BDSKASSERT([[NSThread currentThread] isEqual:notificationThread]);

    BDSKPRECONDITION(searchIndexInfo);
            
    // this will update the delegate when all is complete
    [self indexFilesForItems:searchIndexInfo numberPreviouslyIndexed:0 totalCount:[searchIndexInfo count]];        
}

- (void)handleDocDelItem:(NSArray *)searchIndexInfo
{
    BDSKASSERT([[NSThread currentThread] isEqual:notificationThread]);

	NSEnumerator *itemEnumerator = [searchIndexInfo objectEnumerator];
    id anItem;
        
    NSURL *identifierURL = nil;
    NSSet *urlsToRemove;
    	
    while (anItem = [itemEnumerator nextObject]) {
        identifierURL = [anItem valueForKey:@"identifierURL"];
        
        [rwLock lockForReading];
        urlsToRemove = [[[identifierURLs allKeysForObject:identifierURL] copy] autorelease];
        [rwLock unlock];
       
        [self removeFileURLs:urlsToRemove forIdentifierURL:identifierURL];
	}
	
    if (0 == flags.updateScheduled)
        [self performSelectorOnMainThread:@selector(searchIndexDidUpdate) withObject:nil waitUntilDone:NO];
}

- (void)handleSearchIndexInfoChanged:(NSArray *)searchIndexInfo
{
    BDSKASSERT([[NSThread currentThread] isEqual:notificationThread]);
    
    NSDictionary *item = [searchIndexInfo lastObject];
    NSURL *identifierURL = [item objectForKey:@"identifierURL"];
    
    NSSet *newURLs = [[NSSet alloc] initWithArray:[item valueForKey:@"urls"]];
    NSMutableSet *removedURLs;
    
    [rwLock lockForReading];
    removedURLs = [[identifierURLs allKeysForObject:identifierURL] mutableCopy];
    [rwLock unlock];
    [removedURLs minusSet:newURLs];
    
    if ([removedURLs count])
        [self removeFileURLs:removedURLs forIdentifierURL:identifierURL];
    
    if ([newURLs count])
        [self indexFileURLs:newURLs forIdentifierURL:identifierURL];
        
    [removedURLs release];
    [newURLs release];
    
    if (0 == flags.updateScheduled)
        [self performSelectorOnMainThread:@selector(searchIndexDidUpdate) withObject:nil waitUntilDone:NO];
}    

- (NSDictionary *)newNotification {
    NSDictionary *note = nil;
    [noteLock lock];
    if ([notificationQueue count]) {
        note = [[notificationQueue objectAtIndex:0] retain];
        [notificationQueue removeObjectAtIndex:0];
    }
    [noteLock unlock];
    return note;
}

- (void)handleMachMessage:(void *)msg
{
    BDSKASSERT([NSThread isMainThread] == NO);
    NSDictionary *note;
    
    while (note = [self newNotification]) {
        NSString *name = [note valueForKey:@"name"];
        NSArray *searchIndexInfo = [note valueForKey:@"searchIndexInfo"];
        // this is a background thread that can handle these notifications
        if([name isEqualToString:BDSKFileSearchIndexInfoChangedNotification])
            [self handleSearchIndexInfoChanged:searchIndexInfo];
        else if([name isEqualToString:BDSKDocAddItemNotification])
            [self handleDocAddItem:searchIndexInfo];
        else if([name isEqualToString:BDSKDocDelItemNotification])
            [self handleDocDelItem:searchIndexInfo];
        else
            [NSException raise:NSInvalidArgumentException format:@"notification %@ is not handled by %@", note, self];
        [note release];
    }
}

@end
