//  NSTextView_BDSKExtensions.m

//  Created by Michael McCracken on Thu Jul 18 2002.
/*
 This software is Copyright (c) 2002-2012
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

#import "NSTextView_BDSKExtensions.h"
#import "BDSKStringConstants.h"

@implementation NSTextView (BDSKExtensions)

// flag changes during a drag are not forwarded to the application, so we fix that at the end of the drag
- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation{
    // there is not original implementation
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

- (void)selectLineNumber:(NSInteger) line;
{
    NSInteger i;
    NSString *string;
    NSUInteger start;
    NSUInteger end;
    NSRange myRange;

    string = [self string];
    
    myRange.location = 0;
    myRange.length = 0; // use zero length range so getLineStart: doesn't raise an exception if we're looking for the last line
    for (i = 1; i <= line; i++) {
        [string getLineStart:&start
                       end:&end
               contentsEnd:NULL
                  forRange:myRange];
        myRange.location = end;
    }
    myRange.location = start;
    myRange.length = (end - start);
    [self setSelectedRange:myRange];
    [self scrollRangeToVisible:myRange];
}

// allows persistent spell checking in text views

- (void)toggleContinuousSpellChecking:(id)sender{
    BOOL state = ![[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditorShouldCheckSpellingContinuouslyKey];
    [sender setState:state];
    [[NSUserDefaults standardUserDefaults] setBool:state forKey:BDSKEditorShouldCheckSpellingContinuouslyKey];
}

- (BOOL)isContinuousSpellCheckingEnabled{
    return [[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditorShouldCheckSpellingContinuouslyKey];
}

- (void)highlightComponentsOfSearchString:(NSString *)searchString;
{
    NSParameterAssert(searchString != nil);
    static NSCharacterSet *charactersToRemove = nil;
    if (nil == charactersToRemove) {
        // SearchKit ignores punctuation, so results can be surprising.  In bug #1779548 the user was trying to search for a literal "ic.8" with the default wildcard expansion.  This translated into a large number of matches, but nothing was highlighted in the textview because we only removed SearchKit special characters.
        NSMutableCharacterSet *ms = (id)[NSMutableCharacterSet characterSetWithCharactersInString:@"\"!*()|&"];
        [ms formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        charactersToRemove = [ms copy];
    }
    
    NSMutableString *mutableString = [searchString mutableCopy];
    
    // @@ Presently limited; if we enable the phrase searching features, we'll need to be smarter about quotes.  This should be reliable enough for common usage without implementing a full SKSearch expression parser, though.
    
    // replace single-character operators with a single space
    NSRange range = [mutableString rangeOfCharacterFromSet:charactersToRemove options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];
    while (range.length) {
        [mutableString replaceCharactersInRange:range withString:@" "];
        range = [mutableString rangeOfCharacterFromSet:charactersToRemove options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];
    }
    
    // case-sensitive replacement of text operators; we don't want to look for these
    [mutableString replaceOccurrencesOfString:@" AND " withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];
    [mutableString replaceOccurrencesOfString:@" OR " withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];
    
    // NOT strings won't appear, of course, but it's easier just to add the NOT components versus parsing it (NOT is likely not common, anyway)
    [mutableString replaceOccurrencesOfString:@" NOT " withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];
    
    NSArray *allComponents = [mutableString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet] trimWhitespace:YES];
    [mutableString release];

    if ([allComponents count]) {
        for (NSString *string in allComponents)
            [self highlightOccurrencesOfString:string];
    }
}

- (void)highlightOccurrencesOfString:(NSString *)substring;
{
    NSParameterAssert(substring != nil);
    NSString *string = [self string];
    NSRange range = [string rangeOfString:substring options:NSCaseInsensitiveSearch];
    NSUInteger maxRangeLoc;
    NSUInteger length = [string length];
    
    // Mail.app appears to use a light gray highlight, which is rather ugly, but we don't want to use the selected text highlight
    NSDictionary *highlightAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor lightGrayColor], NSBackgroundColorAttributeName, nil];
    
    // use the layout manager to add temporary attributes; the advantage for our purpose is that temporary attributes don't print
    NSLayoutManager *layoutManager = [self layoutManager];
    BDSKPRECONDITION(layoutManager);
    if(layoutManager == nil)
        return;
    
    /*
     Using beginEditing/endEditing here can result in the following exception:
     
     -[NSLayoutManager _fillGlyphHoleForCharacterRange:startGlyphIndex:desiredNumberOfCharacters:] *** attempted glyph generation while textStorage is editing.  It is not valid to cause the layoutManager to do glyph generation while the textStorage is editing (ie the textStorage has been sent a beginEditing message without a matching endEditing.
     
     That's supposed to be a legitimate call before changes to attributes, and temporary attributes aren't supposed to affect layout...so it's odd that glyph generation is happening.  Maybe background layout is happening at the same time?
     
     */
    while(range.location != NSNotFound){
        
        [layoutManager addTemporaryAttributes:highlightAttributes forCharacterRange:range];        
        maxRangeLoc = NSMaxRange(range);
        range = [string rangeOfString:substring options:NSCaseInsensitiveSearch range:NSMakeRange(maxRangeLoc, length - maxRangeLoc)];
    }
}

- (IBAction)invertSelection:(id)sender;
{
    // Note the guarantees in the header for -selectedRanges and requirements for setSelectedRanges:
    NSArray *ranges = [self selectedRanges];
    NSMutableArray *newRanges = [NSMutableArray array];
    NSUInteger i, iMax = [ranges count];
    
    // this represents the entire string
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[self string] length])];
    
    // remove current selections
    for (i = 0; i < iMax; i++) {
        [indexes removeIndexesInRange:[[ranges objectAtIndex:i] rangeValue]];
    }
    
    i = [indexes firstIndex];
    if (NSNotFound == i) {
        // nothing to select (select all, then choose to invert)
        [newRanges addObject:[NSValue valueWithRange:NSMakeRange(0, 0)]];
    } else {
        
        NSUInteger start, next;
        start = i;
        
        while (NSNotFound != i) {
            next = [indexes indexGreaterThanIndex:i];
            // a discontinuity in the sequence indicates the start of a new range
            if (NSNotFound == next || next != (i + 1)) {
                [newRanges addObject:[NSValue valueWithRange:NSMakeRange(start, i - start + 1)]];
                start = next;
            }
            i = next;
        }
    }
    
    [self setSelectedRanges:newRanges];
}

- (void)setSafeSelectedRanges:(NSArray *)ranges {
    NSUInteger length = [[self string] length];
    NSMutableArray *mutableRanges = [NSMutableArray array];
    for (NSValue *value in ranges) {
        NSRange range = [value rangeValue];
        if (NSMaxRange(range) > length) {
            if (range.location >= length)
                continue;
            value = [NSValue valueWithRange:NSMakeRange(range.location, length - range.location)];
        }
        [mutableRanges addObject:value];
    }
    if ([mutableRanges count] == 0)
        [mutableRanges addObject:[NSValue valueWithRange:NSMakeRange(length, 0)]];
    [self setSelectedRanges:mutableRanges];
}

- (NSPoint)locationForCompletionWindow;
{
    NSPoint point = NSZeroPoint;
    
    NSRange selRange = [self rangeForUserCompletion];

    // @@ hack: if there is no character at this point (it may be just an accent), our line fragment rect will not be accurate for what we really need, so returning NSZeroPoint indicates to the caller that this is invalid
    if(selRange.length == 0 || selRange.location == NSNotFound)
        return point;
    
    NSLayoutManager *layoutManager = [self layoutManager];
    
    // get the rect for the first glyph in our affected range
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:selRange actualCharacterRange:NULL];
    NSRect rect = NSZeroRect;

    // check length, or the layout manager will raise an exception
    if(glyphRange.length > 0){
        rect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphRange.location effectiveRange:NULL];
        point = rect.origin;

        // the above gives the rect for the full line
        NSPoint glyphLoc = [layoutManager locationForGlyphAtIndex:glyphRange.location];
        point.x += glyphLoc.x;
        // don't adjust based on glyphLoc.y; we'll use the lineFragmentRect for that
    }
        
    // adjust for the line height + border/focus ring
    point.y += NSHeight(rect) + 3;
    
    // adjust for the text container origin
    NSPoint tcOrigin = [self textContainerOrigin];
    point.x += tcOrigin.x;
    point.y += tcOrigin.y;
    
    // make sure we have integral coordinates
    point.x = ceil(point.x);
    point.y = ceil(point.y);
    
    // make sure we don't put the window before the textfield when the text is scrolled
    if (point.x < [self visibleRect].origin.x) 
        point.x = [self visibleRect].origin.x;
    
    // convert to screen coordinates
    point = [self convertPoint:point toView:nil];
    point = [[self window] convertBaseToScreen:point];  
    
    return point;
}

@end
