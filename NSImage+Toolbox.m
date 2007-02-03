//
//  NSImage+Toolbox.m
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 29 2004.
/*
 This software is Copyright (c) 2004,2005,2006,2007
 Sven-S. Porst. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Sven-S. Porst nor the names of any
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

#import "NSImage+Toolbox.h"
#import <OmniFoundation/NSString-OFExtensions.h>
#import "NSBezierPath_BDSKExtensions.h"

@implementation NSImage (Toolbox)

+ (NSImage *)iconWithSize:(NSSize)iconSize forToolboxCode:(OSType) code {
	int width = iconSize.width;
	int height = iconSize.height;
	IconRef iconref;
	OSErr myErr = GetIconRef (kOnSystemDisk, kSystemIconsCreator, code, &iconref);
	
	NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(width,height)]; 
	[image lockFocus]; 
	
	CGRect rect =  CGRectMake(0,0,width,height);
	
	PlotIconRefInContext((CGContextRef)[[NSGraphicsContext currentContext] graphicsPort],
                         &rect,
						 kAlignAbsoluteCenter, //kAlignNone,
						 kTransformNone,
						 NULL /*inLabelColor*/,
						 kPlotIconRefNormalFlags,
						 iconref); 
	[image unlockFocus]; 
	
	myErr = ReleaseIconRef(iconref);
	
	[image autorelease];	
	return image;
}

+ (NSImage *)imageWithLargeIconForToolboxCode:(OSType) code {
    /* ssp: 30-07-2004 
    
	A category on NSImage that creates an NSImage containing an icon from the system specified by an OSType.
    LIMITATION: This always creates 32x32 images as are useful for toolbars.
    
	Code taken from http://cocoa.mamasam.com/MACOSXDEV/2002/01/2/22427.php
    */
    
    return [self iconWithSize:NSMakeSize(32,32) forToolboxCode:code];
}

+ (NSImage *)missingFileImage {
    static NSImage *image = nil;
    if(image == nil){
        image = [[NSImage alloc] initWithSize:NSMakeSize(32, 32)];
        NSImage *genericDocImage = [self iconWithSize:NSMakeSize(32, 32) forToolboxCode:kGenericDocumentIcon];
        NSImage *questionMark = [self iconWithSize:NSMakeSize(20, 20) forToolboxCode:kQuestionMarkIcon];
        [image lockFocus];
        [genericDocImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
        [questionMark compositeToPoint:NSMakePoint(6, 4) operation:NSCompositeSourceOver fraction:0.7];
        [image unlockFocus];
    }
    return image;
}

+ (NSImage *)smallMissingFileImage {
    static NSImage *image = nil;
    if(image == nil){
        image = [[NSImage alloc] initWithSize:NSMakeSize(16, 16)];
        NSImage *genericDocImage = [self iconWithSize:NSMakeSize(16, 16) forToolboxCode:kGenericDocumentIcon];
        NSImage *questionMark = [self iconWithSize:NSMakeSize(10, 10) forToolboxCode:kQuestionMarkIcon];
        [image lockFocus];
        [genericDocImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
        [questionMark compositeToPoint:NSMakePoint(3, 3) operation:NSCompositeSourceOver];
        [image unlockFocus];
    }
    return image;
}

+ (NSImage *)smallGenericInternetLocationImage{
	static NSImage *image = nil;
	if (image == nil)
        image = [[NSImage iconWithSize:NSMakeSize(16,16) forToolboxCode:kInternetLocationGenericIcon] retain];
	return image;
}

+ (NSImage *)smallFTPInternetLocationImage{
	static NSImage *image = nil;
	if (image == nil) 
        image = [[NSImage iconWithSize:NSMakeSize(16,16) forToolboxCode:kInternetLocationFTPIcon] retain];
	return image;
}

+ (NSImage *)smallHTTPInternetLocationImage{
	static NSImage *image = nil;
	if (image == nil)
        image = [[NSImage iconWithSize:NSMakeSize(16,16) forToolboxCode:kInternetLocationHTTPIcon] retain];
	return image;
}

+ (NSImage *)imageForURL:(NSURL *)aURL{
    
    if(!aURL) return nil;

    if([aURL isFileURL])
        return [self imageForFile:[aURL path]];
    
    NSString *scheme = [aURL scheme];
    
    if([scheme isEqualToString:@"http"])
        return [self httpInternetLocationImage];
    else if([scheme isEqualToString:@"ftp"])
        return [self ftpInternetLocationImage];
    else return [self genericInternetLocationImage];
}

+ (NSImage *)smallImageForURL:(NSURL *)aURL{

    if(!aURL) return nil;
    
    if([aURL isFileURL])
        return [self smallImageForFile:[aURL path]];
    
    NSString *scheme = [aURL scheme];
    
    if([scheme isEqualToString:@"http"])
        return [self smallHTTPInternetLocationImage];
    else if([scheme isEqualToString:@"ftp"])
        return [self smallFTPInternetLocationImage];
    else return [self smallGenericInternetLocationImage];
}

+ (NSImage *)smallImageForFileType:(NSString *)fileType{
    // It turns out that -[NSWorkspace iconForFileType:] doesn't cache previously returned values, so we cache them here.
    // Mainly useful for tableview datasource methods.
    
    static NSMutableDictionary *imageDictionary = nil;
    id image = nil;
    
    if (!fileType)
        return nil;
    
    if (imageDictionary == nil)
        imageDictionary = [[NSMutableDictionary alloc] init];
    
    image = [imageDictionary objectForKey:fileType];
    if (image == nil) {
        
        NSImage *baseImage = [[NSWorkspace sharedWorkspace] iconForFileType:fileType];        
        NSRect srcRect = {NSZeroPoint, [baseImage size]};
        NSSize dstSize = NSMakeSize(16,16);
        NSRect dstRect = {NSZeroPoint, dstSize};
        
        image = [[NSImage alloc] initWithSize:dstSize];
        [image lockFocus];
        [NSGraphicsContext saveGraphicsState];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [baseImage drawInRect:dstRect fromRect:srcRect operation:NSCompositeCopy fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
        [image unlockFocus];
        [image autorelease];
        
        if (image == nil)
            image = [NSNull null];
        
        [imageDictionary setObject:image forKey:fileType];
    }
    return image != [NSNull null] ? image : nil;
}

+ (NSImage *)imageForFile:(NSString *)path{
    // It turns out that -[NSWorkspace iconForFileType:] doesn't cache previously returned values, so we cache them here.
    // Mainly useful for tableview datasource methods.
    
    static NSMutableDictionary *imageDictionary = nil;
    id image = nil;
    
    if (!path)
        return nil;
    
    NSString *pathExtension = [path pathExtension];
    if(![pathExtension isEqualToString:@""])
        return [NSImage imageForFileType:pathExtension]; // prefer this (more common case)
    
    // if no file type, we'll just cache the path and waste some memory
    if (imageDictionary == nil)
        imageDictionary = [[NSMutableDictionary alloc] init];
    
    image = [imageDictionary objectForKey:path];
    if (image == nil) {
        image = [[NSWorkspace sharedWorkspace] iconForFile:path];
        if (image == nil)
            image = [NSNull null];
        [imageDictionary setObject:image forKey:path];
    }
    return image != [NSNull null] ? image : nil;
}

+ (NSImage *)smallImageNamed:(NSString *)imageName{
    
    NSParameterAssert(imageName);
    
    static NSMutableDictionary *imageDictionary = nil;
    if (imageDictionary == nil)
        imageDictionary = [[NSMutableDictionary alloc] init];

    id image = [imageDictionary objectForKey:imageName];
    if (image == nil) {
        
        NSImage *baseImage = [self imageNamed:imageName];        
        NSRect srcRect = {NSZeroPoint, [baseImage size]};
        NSSize dstSize = NSMakeSize(16,16);
        NSRect dstRect = {NSZeroPoint, dstSize};
        
        image = [[NSImage alloc] initWithSize:dstSize];
        [image lockFocus];
        [NSGraphicsContext saveGraphicsState];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [baseImage drawInRect:dstRect fromRect:srcRect operation:NSCompositeCopy fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
        [image unlockFocus];
        [image autorelease];
        
        if (image == nil)
            image = [NSNull null];
        
        [imageDictionary setObject:image forKey:imageName];
    }
    return image != [NSNull null] ? image : nil;
 
}

+ (NSImage *)smallImageForFile:(NSString *)path{
    // It turns out that -[NSWorkspace iconForFileType:] doesn't cache previously returned values, so we cache them here.
    // Mainly useful for tableview datasource methods.
    
    static NSMutableDictionary *imageDictionary = nil;
    id image = nil;
    
    if (!path)
        return nil;
    
    NSString *pathExtension = [path pathExtension];
    if(![pathExtension isEqualToString:@""])
        return [NSImage smallImageForFileType:pathExtension]; // prefer this (more common case)
    
    // if no file type, we'll just cache the path and waste some memory
    if (imageDictionary == nil)
        imageDictionary = [[NSMutableDictionary alloc] init];
    
    image = [imageDictionary objectForKey:path];
    if (image == nil) {
        
        NSImage *baseImage = [[NSWorkspace sharedWorkspace] iconForFile:path];        
        NSRect srcRect = {NSZeroPoint, [baseImage size]};
        NSSize dstSize = NSMakeSize(16,16);
        NSRect dstRect = {NSZeroPoint, dstSize};
        
        image = [[NSImage alloc] initWithSize:dstSize];
        [image lockFocus];
        [NSGraphicsContext saveGraphicsState];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [baseImage drawInRect:dstRect fromRect:srcRect operation:NSCompositeCopy fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
        [image unlockFocus];
        [image autorelease];
        
        if (image == nil)
            image = [NSNull null];
        
        [imageDictionary setObject:image forKey:path];
    }
    return image != [NSNull null] ? image : nil;
}

- (NSImage *)imageFlippedHorizontally;
{
	NSImage *flippedImage;
	NSAffineTransform *transform = [NSAffineTransform transform];
	NSSize size = [self size];
    NSRect rect = {NSZeroPoint, size};
	NSAffineTransformStruct flip = {-1.0, 0.0, 0.0, 1.0, size.width, 0.0};	
	flippedImage = [[[NSImage alloc] initWithSize:size] autorelease];
	[flippedImage lockFocus];
    [NSGraphicsContext saveGraphicsState];
    [transform setTransformStruct:flip];
	[transform concat];
	[self drawAtPoint:NSZeroPoint fromRect:rect operation:NSCompositeCopy fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
	[flippedImage unlockFocus];
	return flippedImage;
}

- (NSImage *)highlightedImage;
{
    NSSize iconSize = [self size];
    NSRect iconRect = {NSZeroPoint, iconSize};
    NSImage *newImage = [[NSImage alloc] initWithSize:iconSize];
    
    [newImage lockFocus];
    // copy the original image (self)
    [self drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    
    // blend with black to create a highlighted appearance
    [NSGraphicsContext saveGraphicsState];
    [[[NSColor blackColor] colorWithAlphaComponent:0.3] set];
    NSRectFillUsingOperation(iconRect, NSCompositeSourceAtop);
    [NSGraphicsContext restoreGraphicsState];
    [newImage unlockFocus];
    
    return [newImage autorelease];
}

- (NSImage *)dragImageWithCount:(int)count;
{
    return [self dragImageWithCount:count inside:NO];
}

- (NSImage *)dragImageWithCount:(int)count inside:(BOOL)inside;
{
    NSImage *labeledImage;
    
    if (count > 1) {
        
        NSAttributedString *countString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%i", count]
                                            attributeName:NSForegroundColorAttributeName attributeValue:[NSColor whiteColor]] autorelease];
        NSSize size = [self size];
        NSRect rect = {NSZeroPoint, size};
        NSRect iconRect = rect;
        NSRect countRect = {NSZeroPoint, [countString size]};
        float countOffset;
        
        countOffset = floorf(0.5f * NSHeight(countRect)); // make sure the cap radius is integral
        countRect.size.height = 2.0 * countOffset;
        
        if (inside) {
            // large image, draw it inside the corner
            countRect.origin = NSMakePoint(NSMaxX(rect) - NSWidth(countRect) - countOffset - 2.0, 3.0);
        } else {
            // small image, draw it outside the corner
            countRect.origin = NSMakePoint(NSMaxX(rect), 0.0);
            size.width += NSWidth(countRect) + countOffset;
            size.height += countOffset;
            rect.origin.y += countOffset;
        }
        
        labeledImage = [[[NSImage alloc] initWithSize:size] autorelease];
        
        [labeledImage lockFocus];
        
        [self drawInRect:rect fromRect:iconRect operation:NSCompositeCopy fraction:1.0];
        
        [NSGraphicsContext saveGraphicsState];
        // draw a count of the rows being dragged, similar to Mail.app
        [[NSColor redColor] setFill];
        [NSBezierPath fillHorizontalOvalAroundRect:countRect];
        [countString drawInRect:countRect];
        [NSGraphicsContext restoreGraphicsState];
        
        [labeledImage unlockFocus];
        
    } else {
        
        labeledImage = self;
        
    }
	
    NSImage *dragImage = [[NSImage alloc] initWithSize:[labeledImage size]];
	
	[dragImage lockFocus];
	[labeledImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
	[dragImage unlockFocus];
	
	return [dragImage autorelease];
}

@end
