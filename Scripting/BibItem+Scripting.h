//
//  BibItemClassDescription.h
//  Bibdesk
//
//  Created by Sven-S. Porst on Sat Jul 10 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BibItem.h"
#import "BibField.h"

#define BibItemBasicObjects @"citeKey", @"pubDate", @"title", @"type", @"date", @"pubFields", @"bibTeXStrings", @"RTFValue", @"RSSValue"

#define BibItemYearKey @"Year"
#define BibItemMonthKey @"Month"
#define BibItemRemoteURLKey @"Url"
#define BibItemLocalURLKey @"Local-Url"
#define BibItemAbstractKey @"Abstract"
#define BibItemAnnotationKey @"Annote"
#define BibItemRSSDescriptionKey @"Rss-Description"
#define BibItemKeywordsKey @"Keywords"

@interface BibItem (Scripting) 

- (BibField *)valueInBibFieldsWithName:(NSString *)name;
- (NSArray *)bibFields;

- (NSMutableDictionary *)fields;

- (void) setBibTeXString:(NSString*) btString;

// wrapping original methods 
- (NSDate*) ASDateCreated;
- (NSDate*) ASDateModified;

// more (pseudo) accessors for key-value coding
- (NSString*) remoteURL;
- (void) setRemoteURL:(NSString*) newURL;

- (NSString*) localURL;
- (void) setLocalURL:(NSString*) newURL;

- (NSString*) abstract;
- (void) setAbstract:(NSString*) newAbstract;

- (NSString*) annotation;
- (void) setAnnotation:(NSString*) newAnnotation;

- (NSString*) RSSDescription;
- (void) setRSSDescription:(NSString*) newDesc; 

- (NSString *)keywords;
- (void)setKeywords:(NSString *)keywords;

- (NSTextStorage*) attributedString;



- (NSScriptObjectSpecifier *) objectSpecifier;


@end




