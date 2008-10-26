//
//  BDSKTypeManager.m
//  BibDesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
/*
 This software is Copyright (c) 2002-2008
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

#import "BDSKTypeManager.h"
#import "BDSKAppController.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSCharacterSet_BDSKExtensions.h"
#import "OFCharacterSet_BDSKExtensions.h"

static BDSKTypeManager *sharedInstance = nil;

@implementation BDSKTypeManager

+ (void)initialize
{
    OBINITIALIZE;
    [self sharedManager];
}

+ (BDSKTypeManager *)sharedManager{
    if (sharedInstance == nil)
        [[self alloc] init];
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    return sharedInstance ?: [super allocWithZone:zone];
}

- (id)init{
    if ((sharedInstance == nil) && (sharedInstance = self = [super init])) {
        
        [self reloadTypeInfo];
        
        NSMutableCharacterSet *tmpSet;
        // this set is used for warning the user on manual entry of a citekey; allows ASCII characters and some math symbols
        // arm: up through 1.3.12 we allowed non-ASCII characters in here, but btparse chokes on them and so does BibTeX.  TLC 2nd ed. says that cite keys are TeX commands, and subject to the same restrictions as such [a-zA-Z0-9], but this is generally relaxed in the case of BibTeX to include some punctuation.
        tmpSet = [[NSCharacterSet characterSetWithRange:NSMakeRange(21, 126 - 21)] mutableCopy];
        [tmpSet removeCharactersInString:@" '\"@,\\#}{~%()"];
        [tmpSet invert];
        invalidCiteKeyCharSet = [tmpSet copy];
        [tmpSet release];
        
        fragileCiteKeyCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"&$^"] copy];
        
        tmpSet = [[NSCharacterSet characterSetWithRange:NSMakeRange( (unsigned int)'a', 26)] mutableCopy];
        [tmpSet addCharactersInRange:NSMakeRange( (unsigned int)'A', 26)];
        [tmpSet addCharactersInRange:NSMakeRange( (unsigned int)'-', 15)];  //  -./0123456789:;
        
        // this is used for generated cite keys, very strict!
        strictInvalidCiteKeyCharSet = [[tmpSet invertedSet] copy];  // don't release this
        [tmpSet release];

        // this set is used for warning the user on manual entry of a local-url; allows non-ASCII characters and some math symbols
        invalidLocalUrlCharSet = [[NSCharacterSet characterSetWithCharactersInString:@":"] copy];
        
        // this is used for generated local urls
        strictInvalidLocalUrlCharSet = [invalidLocalUrlCharSet copy];  // don't release this

        
        tmpSet = [[NSCharacterSet characterSetWithRange:NSMakeRange(1,31)] mutableCopy];
        [tmpSet addCharactersInString:@"/?<>\\:*|\""];
        
        // this is used for generated local urls, stricted for use of windoze-compatible file names
        veryStrictInvalidLocalUrlCharSet = [tmpSet copy];
        [tmpSet release];
        
        // see the URI specifications for the valid characters
        NSMutableCharacterSet *validSet = [[NSCharacterSet characterSetWithRange:NSMakeRange( (unsigned int)'a', 26)] mutableCopy];
        [validSet addCharactersInRange:NSMakeRange( (unsigned int)'A', 26)];
        [validSet addCharactersInString:@"-._~:/?#[]@!$&'()*+,;="];
        
        // this set is used for warning the user on manual entry of a remote url
        invalidRemoteUrlCharSet = [[validSet invertedSet] copy];
        [validSet release];
        
        // this is used for generated remote urls
        strictInvalidRemoteUrlCharSet = [invalidRemoteUrlCharSet copy];  // don't release this
        
        invalidGeneralCharSet = [[NSCharacterSet alloc] init];
        
        strictInvalidGeneralCharSet = [[NSCharacterSet alloc] init];
        
        separatorCharSet = [[NSCharacterSet characterSetWithCharactersInString:[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKGroupFieldSeparatorCharactersKey]] copy];
        separatorOFCharSet = [[OFCharacterSet alloc] initWithString:[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKGroupFieldSeparatorCharactersKey]];
        
        localFileFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
        remoteURLFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
        allURLFieldsSet = [[NSMutableSet alloc] initWithCapacity:10];
        [self reloadURLFields];
        
        ratingFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
        triStateFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
        booleanFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
        citationFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
        personFieldsSet = [[NSMutableSet alloc] initWithCapacity:2];
        [self reloadSpecialFields];
        
        singleValuedGroupFieldsSet = [[NSMutableSet alloc] initWithCapacity:10];
        invalidGroupFieldsSet = [[NSMutableSet alloc] initWithCapacity:10];
        [self reloadGroupFields];
        
        // observe the pref changes for custom fields
        NSEnumerator *prefKeyEnum = [[NSSet setWithObjects:BDSKDefaultFieldsKey, BDSKLocalFileFieldsKey, BDSKRemoteURLFieldsKey, BDSKRatingFieldsKey, BDSKBooleanFieldsKey, BDSKTriStateFieldsKey, BDSKCitationFieldsKey, BDSKPersonFieldsKey, nil] objectEnumerator];
        NSString *prefKey;
        while (prefKey = [prefKeyEnum nextObject])
            [OFPreference addObserver:self selector:@selector(customFieldsDidChange:) forPreference:[OFPreference preferenceForKey:prefKey]];
    }
	return sharedInstance;
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (unsigned)retainCount { return UINT_MAX; }

- (void)reloadTypeInfo{
    // Load the TypeInfo plists
    NSDictionary *typeInfoDict = [NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:TYPE_INFO_FILENAME]];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *userTypeInfoPath = [[fm currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:TYPE_INFO_FILENAME];
    NSDictionary *userTypeInfoDict;
    
    if ([fm fileExistsAtPath:userTypeInfoPath]) {
        userTypeInfoDict = [NSDictionary dictionaryWithContentsOfFile:userTypeInfoPath];
        // set all the lists we support in the user file
        [self setFieldsForTypesDict:[userTypeInfoDict objectForKey:FIELDS_FOR_TYPES_KEY]];
        [self setTypesForFileTypeDict:[NSDictionary dictionaryWithObjectsAndKeys: 
            [[userTypeInfoDict objectForKey:TYPES_FOR_FILE_TYPE_KEY] objectForKey:BDSKBibtexString], BDSKBibtexString, 
            [[typeInfoDict objectForKey:TYPES_FOR_FILE_TYPE_KEY] objectForKey:@"PubMed"], @"PubMed", nil]];
    } else {
        [self setFieldsForTypesDict:[typeInfoDict objectForKey:FIELDS_FOR_TYPES_KEY]];
        [self setTypesForFileTypeDict:[typeInfoDict objectForKey:TYPES_FOR_FILE_TYPE_KEY]];
    }

    [self setFileTypesDict:[typeInfoDict objectForKey:FILE_TYPES_KEY]];
    [self setFieldNameForPubMedTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_PUBMED_TAGS_KEY]];
    [self setPubMedTagForFieldNameDict:[typeInfoDict objectForKey:PUBMED_TAGS_FOR_BIBTEX_FIELDS_KEY]];
    [self setBibtexTypeForPubMedTypeDict:[typeInfoDict objectForKey:BIBTEX_TYPES_FOR_PUBMED_TYPES_KEY]];
    [self setFieldNamesForMARCTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_MARC_TAGS_KEY]];
    [self setFieldNamesForUNIMARCTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_UNIMARC_TAGS_KEY]];
    [self setMODSGenresForBibTeXTypeDict:[typeInfoDict objectForKey:MODS_GENRES_FOR_BIBTEX_TYPES_KEY]];
    [self setFieldNameForJSTORTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_JSTOR_TAGS_KEY]];
    [self setFieldDescriptionForJSTORTagDict:[typeInfoDict objectForKey:FIELD_DESCRIPTIONS_FOR_JSTOR_TAGS_KEY]];
    [self setFieldNameForWebOfScienceTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_WOS_TAGS_KEY]];
    [self setFieldDescriptionForWebOfScienceTagDict:[typeInfoDict objectForKey:FIELD_DESCRIPTIONS_FOR_WOS_TAGS_KEY]];
    [self setBibtexTypeForWebOfScienceTypeDict:[typeInfoDict objectForKey:BIBTEX_TYPES_FOR_WOS_TYPES_KEY]];
    [self setBibtexTypeForDublinCoreTypeDict:[typeInfoDict objectForKey:BIBTEX_TYPES_FOR_DC_TYPES_KEY]];        
    [self setFieldNameForDublinCoreTermDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_DC_TERMS_KEY]];
    [self setFieldNameForReferTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_REFER_TAGS_KEY]];
    [self setBibtexTypeForReferTypeDict:[typeInfoDict objectForKey:BIBTEX_TYPES_FOR_REFER_TYPES_KEY]];
    [self setBibtexTypeForHCiteTypeDict:[typeInfoDict objectForKey:BIBTEX_TYPES_FOR_HCITE_TYPES_KEY]];
	
	[self reloadAllFieldNames];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibTypeInfoChangedNotification
														object:self
													  userInfo:[NSDictionary dictionary]];
}

- (void)reloadAllFieldNames {
    NSMutableSet *allFields = [NSMutableSet setWithCapacity:30];
    NSEnumerator *typeEnum = [[self bibTypesForFileType:BDSKBibtexString] objectEnumerator];
    NSString *type;
    
    while (type = [typeEnum nextObject]) {
        [allFields addObjectsFromArray:[[fieldsForTypesDict objectForKey:type] objectForKey:REQUIRED_KEY]];
        [allFields addObjectsFromArray:[[fieldsForTypesDict objectForKey:type] objectForKey:OPTIONAL_KEY]];
    }
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKDefaultFieldsKey]];
    [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKLocalFileFieldsKey]];
    [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKRemoteURLFieldsKey]];
    [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKBooleanFieldsKey]];
    [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKRatingFieldsKey]];
    [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKTriStateFieldsKey]];
    [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKCitationFieldsKey]];
    [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKPersonFieldsKey]];
    
    [self setAllFieldNames:allFields];

}

- (void)reloadURLFields {
    [localFileFieldsSet removeAllObjects];
    [remoteURLFieldsSet removeAllObjects];
    [allURLFieldsSet removeAllObjects];
    
    [localFileFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey]];
    [remoteURLFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey]];
    [allURLFieldsSet unionSet:remoteURLFieldsSet];
    [allURLFieldsSet unionSet:localFileFieldsSet];
}

- (void)reloadSpecialFields{
    [ratingFieldsSet removeAllObjects];
    [triStateFieldsSet removeAllObjects];
    [booleanFieldsSet removeAllObjects];
    [citationFieldsSet removeAllObjects];
    [personFieldsSet removeAllObjects];
    
    [ratingFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRatingFieldsKey]];
    [triStateFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKTriStateFieldsKey]];
    [booleanFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey]];    
    [citationFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKCitationFieldsKey]];   
    [personFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKPersonFieldsKey]];
}

- (void)reloadGroupFields{
    [invalidGroupFieldsSet removeAllObjects];
    
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSMutableSet *invalidFields = [NSMutableSet setWithObjects:
		BDSKDateModifiedString, BDSKDateAddedString, BDSKDateString, 
		BDSKTitleString, BDSKBooktitleString, BDSKVolumetitleString, BDSKContainerString, BDSKChapterString, 
		BDSKVolumeString, BDSKNumberString, BDSKSeriesString, BDSKPagesString, BDSKItemNumberString, 
		BDSKAbstractString, BDSKAnnoteString, BDSKRssDescriptionString, nil];
	[invalidFields addObjectsFromArray:[pw stringArrayForKey:BDSKLocalFileFieldsKey]];
	[invalidFields addObjectsFromArray:[pw stringArrayForKey:BDSKRemoteURLFieldsKey]];
    [invalidGroupFieldsSet unionSet:invalidFields];
    
    [singleValuedGroupFieldsSet removeAllObjects];
    NSMutableSet *singleValuedFields = [NSMutableSet setWithObjects:BDSKPubTypeString, BDSKTypeString, BDSKCrossrefString, BDSKJournalString, BDSKYearString, BDSKMonthString, BDSKPublisherString, BDSKAddressString, nil];
	[singleValuedFields addObjectsFromArray:[pw stringArrayForKey:BDSKRatingFieldsKey]];
	[singleValuedFields addObjectsFromArray:[pw stringArrayForKey:BDSKBooleanFieldsKey]];
	[singleValuedFields addObjectsFromArray:[pw stringArrayForKey:BDSKTriStateFieldsKey]];  
    [singleValuedGroupFieldsSet unionSet:singleValuedFields];
}

- (void)customFieldsDidChange:(NSNotification *)notification {
	[self reloadAllFieldNames];
    [self reloadURLFields];
    [self reloadSpecialFields];
    [self reloadGroupFields];
    
    // coalesce notifications; this is received once each OFPreference value that's set in BibPref_Defaults, but observers of BDSKCustomFieldsChangedNotification should only receive it once
    NSNotification *note = [NSNotification notificationWithName:BDSKCustomFieldsChangedNotification object:self];
    [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName forModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

#pragma mark Setters

- (void)setAllFieldNames:(NSSet *)newNames{
    if(allFieldNames != newNames){
        [allFieldNames release];
        allFieldNames = [newNames copy];
    }
}

- (void)setMODSGenresForBibTeXTypeDict:(NSDictionary *)newNames{
    if(MODSGenresForBibTeXTypeDict != newNames){
        [MODSGenresForBibTeXTypeDict release];
        MODSGenresForBibTeXTypeDict = [newNames copy];
    }
}

- (void)setBibtexTypeForPubMedTypeDict:(NSDictionary *)newNames{
    if(bibtexTypeForPubMedTypeDict != newNames){
        [bibtexTypeForPubMedTypeDict release];
        bibtexTypeForPubMedTypeDict = [newNames copy];
    }
}

- (void)setFieldNameForPubMedTagDict:(NSDictionary *)newNames{
    if(fieldNameForPubMedTagDict != newNames){
        [fieldNameForPubMedTagDict release];
        fieldNameForPubMedTagDict = [newNames copy];
    }
}

- (void)setPubMedTagForFieldNameDict:(NSDictionary *)newNames{
    if(pubMedTagForFieldNameDict != newNames){
        [pubMedTagForFieldNameDict release];
        pubMedTagForFieldNameDict = [newNames copy];
    }
}

- (void)setFieldNamesForMARCTagDict:(NSDictionary *)newNames{
    if(fieldNamesForMARCTagDict != newNames){
        [fieldNamesForMARCTagDict release];
        fieldNamesForMARCTagDict = [newNames copy];
    }
}

- (void)setFieldNamesForUNIMARCTagDict:(NSDictionary *)newNames{
    if(fieldNamesForUNIMARCTagDict != newNames){
        [fieldNamesForUNIMARCTagDict release];
        fieldNamesForUNIMARCTagDict = [newNames copy];
    }
}

- (void)setFieldDescriptionForJSTORTagDict:(NSDictionary *)dict{
    if(fieldDescriptionForJSTORTagDict != dict){
        [fieldDescriptionForJSTORTagDict release];
        fieldDescriptionForJSTORTagDict = [dict copy];
    }
}

- (void)setFieldNameForJSTORTagDict:(NSDictionary *)dict{
    if(fieldNameForJSTORTagDict != dict){
        [fieldNameForJSTORTagDict release];
        fieldNameForJSTORTagDict = [dict copy];
    }
}

- (void)setBibtexTypeForWebOfScienceTypeDict:(NSDictionary *)dict{
    if(bibtexTypeForWebOfScienceTypeDict != dict){
        [bibtexTypeForWebOfScienceTypeDict release];
        bibtexTypeForWebOfScienceTypeDict = [dict copy];
    }
}

- (void)setFieldNameForWebOfScienceTagDict:(NSDictionary *)dict{
    if(fieldNameForWebOfScienceTagDict != dict){
        [fieldNameForWebOfScienceTagDict release];
        fieldNameForWebOfScienceTagDict = [dict copy];
    }
}

- (void)setFieldDescriptionForWebOfScienceTagDict:(NSDictionary *)dict{
    if(fieldDescriptionForWebOfScienceTagDict != dict){
        [fieldDescriptionForWebOfScienceTagDict release];
        fieldDescriptionForWebOfScienceTagDict = [dict copy];
    }
}

- (void)setBibtexTypeForDublinCoreTypeDict:(NSDictionary *)dict{
    if(bibtexTypeForDublinCoreTypeDict != dict){
        [bibtexTypeForDublinCoreTypeDict release];
        bibtexTypeForDublinCoreTypeDict = [dict copy];
    }
}

- (void)setFieldNameForDublinCoreTermDict:(NSDictionary *)dict{
    if(fieldNameForDublinCoreTermDict != dict){
        [fieldNameForDublinCoreTermDict release];
        fieldNameForDublinCoreTermDict = [dict copy];
    }
}


- (void)setFileTypesDict:(NSDictionary *)newTypes{
    if(fileTypesDict != newTypes){
        [fileTypesDict release];
        fileTypesDict = [newTypes copy];
    }
}

- (void)setFieldsForTypesDict:(NSDictionary *)newFields{
    if(fieldsForTypesDict != newFields){
        [fieldsForTypesDict release];
        fieldsForTypesDict = [newFields copy];
    }
}

- (void)setTypesForFileTypeDict:(NSDictionary *)newTypes{
    if(typesForFileTypeDict != newTypes){
        [typesForFileTypeDict release];
        typesForFileTypeDict = [newTypes copy];
    }
}

- (void)setFieldNameForReferTagDict:(NSDictionary *)newNames {
    if(fieldNameForReferTagDict != newNames) {
        [fieldNameForReferTagDict release];
        fieldNameForReferTagDict = [newNames copy];
    }
}

- (void)setBibtexTypeForReferTypeDict:(NSDictionary *)newNames {
    if(bibtexTypeForReferTypeDict != newNames) {
        [bibtexTypeForReferTypeDict release];
        bibtexTypeForReferTypeDict = [newNames copy];
    }
}

- (void)setBibtexTypeForHCiteTypeDict:(NSDictionary *)newBibtexTypeForHCiteTypeDict {
    if (bibtexTypeForHCiteTypeDict != newBibtexTypeForHCiteTypeDict) {
        [bibtexTypeForHCiteTypeDict release];
        bibtexTypeForHCiteTypeDict = [newBibtexTypeForHCiteTypeDict copy];
    }
}


#pragma mark Getters

- (NSString *)defaultTypeForFileFormat:(NSString *)fileFormat{
     return [[fileTypesDict objectForKey:fileFormat] objectForKey:@"DefaultType"];
}

- (NSSet *)allFieldNames{
    return allFieldNames;
}

- (NSArray *)allFieldNamesIncluding:(NSArray *)include excluding:(NSArray *)exclude{
    NSMutableArray *fieldNames = [[allFieldNames allObjects] mutableCopy];
    if ([include count])
        [fieldNames addObjectsFromArray:include];
    if([exclude count])
        [fieldNames removeObjectsInArray:exclude];
    [fieldNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
    return [fieldNames autorelease];
}

- (NSArray *)requiredFieldsForType:(NSString *)type{
    NSDictionary *fieldsForType = [fieldsForTypesDict objectForKey:type];
	if(fieldsForType){
        return [fieldsForType objectForKey:REQUIRED_KEY];
    }else{
        return [NSArray array];
    }
}

- (NSArray *)optionalFieldsForType:(NSString *)type{
    NSDictionary *fieldsForType = [fieldsForTypesDict objectForKey:type];
	if(fieldsForType){
        return [fieldsForType objectForKey:OPTIONAL_KEY];
    }else{
        return [NSArray array];
    }
}

- (NSArray *)userDefaultFieldsForType:(NSString *)type{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKDefaultFieldsKey];
}

- (NSSet *)invalidGroupFieldsSet{
	return invalidGroupFieldsSet;
}

- (NSSet *)singleValuedGroupFieldsSet{ 
	return singleValuedGroupFieldsSet;
}

- (NSArray *)bibTypesForFileType:(NSString *)fileType{
    return [typesForFileTypeDict objectForKey:fileType];
}

- (NSString *)fieldNameForPubMedTag:(NSString *)tag{
    return [fieldNameForPubMedTagDict objectForKey:tag];
}

- (NSString *)bibtexTypeForPubMedType:(NSString *)type{
    return [bibtexTypeForPubMedTypeDict objectForKey:type];
}

- (NSDictionary *)fieldNamesForMARCTag:(NSString *)tag{
    return [fieldNamesForMARCTagDict objectForKey:tag];
}

- (NSDictionary *)fieldNamesForUNIMARCTag:(NSString *)tag{
    return [fieldNamesForUNIMARCTagDict objectForKey:tag];
}

- (NSString *)fieldNameForDublinCoreTerm:(NSString *)term{
    return [fieldNameForDublinCoreTermDict objectForKey:term];
}

- (NSString *)bibtexTypeForDublinCoreType:(NSString *)type{
    return [bibtexTypeForDublinCoreTypeDict objectForKey:type];
}

- (NSDictionary *)MODSGenresForBibTeXType:(NSString *)type{
    return [MODSGenresForBibTeXTypeDict objectForKey:type];
}

- (NSString *)RISTagForBibTeXFieldName:(NSString *)name{
    NSString *tag = [pubMedTagForFieldNameDict objectForKey:name];
    if(tag)
        return tag;
    else
        return [[name stringByPaddingToLength:2 withString:@"1" startingAtIndex:0] uppercaseString]; // manufacture a guess
}

- (NSString *)RISTypeForBibTeXType:(NSString *)type{
    
    NSArray *types = [bibtexTypeForPubMedTypeDict allKeysForObject:type];
    NSString *newType = nil;
        
    if([types count]) {
        newType = [types objectAtIndex:0];
    } else {
        newType = [[type stringByPaddingToLength:4 withString:@"?" startingAtIndex:0] uppercaseString]; // manufacture a guess
    }
    // for some reason, the the type dictionary has "journal article" as well as "JOUR"
    if ([newType isEqualToString:@"Journal Article"])
        newType = @"JOUR";
    return newType;
}

- (NSString *)fieldNameForJSTORTag:(NSString *)tag{
    NSString *name = [fieldNameForJSTORTagDict objectForKey:tag];
	if(name == nil){
		name = [fieldDescriptionForJSTORTagDict objectForKey:tag];
		name = [[name fieldName] stringByReplacingAllOccurrencesOfString:@" " withString:@"-"];
	}
	return name;
}

- (NSString *)fieldNameForJSTORDescription:(NSString *)name{
    NSArray *tags = [fieldDescriptionForJSTORTagDict allKeysForObject:name];
    if([tags count])
		return [fieldNameForJSTORTagDict objectForKey:[tags objectAtIndex:0]];
	return [[name fieldName] stringByReplacingAllOccurrencesOfString:@" " withString:@"-"];
}

- (NSString *)bibtexTypeForWebOfScienceType:(NSString *)type{
    return [bibtexTypeForWebOfScienceTypeDict objectForKey:type];
}

- (NSString *)fieldNameForWebOfScienceTag:(NSString *)tag{
    NSString *name = [fieldNameForWebOfScienceTagDict objectForKey:tag];
	if(name == nil){
		name = [fieldDescriptionForWebOfScienceTagDict objectForKey:tag];
		name = [[name fieldName] stringByReplacingAllOccurrencesOfString:@" " withString:@"-"];
        if(name == nil)
            name = tag; // guard against a nil return; it turns out that not all WOS tags are documented
	}
    OBPOSTCONDITION(name);
    return name;
}

- (NSString *)fieldNameForWebOfScienceDescription:(NSString *)name{
    NSArray *tags = [fieldDescriptionForWebOfScienceTagDict allKeysForObject:name];
    if([tags count])
        return [fieldNameForWebOfScienceTagDict objectForKey:[tags objectAtIndex:0]];
    return [[name fieldName] stringByReplacingAllOccurrencesOfString:@" " withString:@"-"];
}    

- (NSString *)fieldNameForReferTag:(NSString *)tag {
    NSString *name = [fieldNameForReferTagDict objectForKey:tag];
    if (nil == name) {
        NSLog(@"Unknown Refer tag %@.  Please report this.", tag);
        // numeric tags don't work with BibTeX; we could have fieldName check this, but it's specific to Refer at this point
        if ([tag length] && [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[tag characterAtIndex:0]])
            name = [@"Refer" stringByAppendingString:tag];
        else
            name = [tag fieldName];
    }
    return name;
}

- (NSString *)bibtexTypeForReferType:(NSString *)type {
    return [bibtexTypeForReferTypeDict objectForKey:type] ?: BDSKMiscString;
}

- (NSString *)bibtexTypeForHCiteType:(NSString *)type {
    // first try to find 'type' in the list of regular types:
    
    if([[self bibTypesForFileType:BDSKBibtexString] containsObject:type])
        return type;
    
    // then try to find 'type' in the custom dict:, and if it's not there, give up and return "misc".
    return [bibtexTypeForHCiteTypeDict objectForKey:type] ?: BDSKMiscString;
}


- (NSSet *)booleanFieldsSet{
    return booleanFieldsSet;
}

- (NSSet *)triStateFieldsSet{
    return triStateFieldsSet;
}

- (NSSet *)ratingFieldsSet{
    return ratingFieldsSet;
}

- (NSSet *)allURLFieldsSet{
    return allURLFieldsSet;
}

- (NSSet *)localFileFieldsSet{
    return localFileFieldsSet;
}

- (NSSet *)remoteURLFieldsSet{
    return remoteURLFieldsSet;
}

- (NSSet *)citationFieldsSet{
    return citationFieldsSet;
}

- (NSSet *)noteFieldsSet{
    static NSSet *noteFieldsSet = nil;
    if(nil == noteFieldsSet)
        noteFieldsSet = [[NSSet alloc] initWithObjects:BDSKAnnoteString, BDSKAbstractString, BDSKRssDescriptionString, nil];
    return noteFieldsSet;
}

- (NSSet *)personFieldsSet{
    return personFieldsSet;
}

- (NSSet *)numericFieldsSet{
    static NSSet *numericFields = nil;
	if (numericFields == nil)
		numericFields = [[NSSet alloc] initWithObjects:BDSKYearString, BDSKVolumeString, BDSKNumberString, BDSKPagesString, nil];
    return numericFields;
}

- (NSCharacterSet *)invalidCharactersForField:(NSString *)fieldName inFileType:(NSString *)type{
	if( [fieldName isEqualToString:BDSKCiteKeyString]){
		return invalidCiteKeyCharSet;
	}
	if([localFileFieldsSet containsObject:fieldName]){
		return invalidLocalUrlCharSet;
	}
	if([remoteURLFieldsSet containsObject:fieldName]){
		return invalidRemoteUrlCharSet;
	}
	return invalidGeneralCharSet;
}

- (NSCharacterSet *)strictInvalidCharactersForField:(NSString *)fieldName inFileType:(NSString *)type{
	if( [fieldName isEqualToString:BDSKCiteKeyString]){
		return strictInvalidCiteKeyCharSet;
	}
	if([localFileFieldsSet containsObject:fieldName]){
		return strictInvalidLocalUrlCharSet;
	}
	if([remoteURLFieldsSet containsObject:fieldName]){
		return strictInvalidRemoteUrlCharSet;
	}
	return strictInvalidGeneralCharSet;
}

- (NSCharacterSet *)veryStrictInvalidCharactersForField:(NSString *)fieldName inFileType:(NSString *)type{
	if([localFileFieldsSet containsObject:fieldName]){
		return veryStrictInvalidLocalUrlCharSet;
	}
	return [self strictInvalidCharactersForField:fieldName inFileType:type];
}

- (NSCharacterSet *)invalidFieldNameCharacterSetForFileType:(NSString *)type{
    if([type isEqualToString:BDSKBibtexString])
        return invalidCiteKeyCharSet;
    else
        [NSException raise:BDSKUnimplementedException format:@"invalidFieldNameCharacterSetForFileType is only implemented for BibTeX"];
    // not reached
    return nil;
}

- (NSCharacterSet *)fragileCiteKeyCharacterSet{
	return fragileCiteKeyCharSet;
}

- (NSCharacterSet *)separatorCharacterSetForField:(NSString *)fieldName{
	return [fieldName isCitationField] ? [NSCharacterSet commaCharacterSet] : separatorCharSet;
}

- (OFCharacterSet *)separatorOFCharacterSetForField:(NSString *)fieldName{
	return [fieldName isCitationField] ? [OFCharacterSet commaCharacterSet] : separatorOFCharSet;
}

@end

@implementation NSString (BDSKTypeExtensions)

- (BOOL)isBooleanField { return [[[BDSKTypeManager sharedManager] booleanFieldsSet] containsObject:self]; }
- (BOOL)isTriStateField { return [[[BDSKTypeManager sharedManager] triStateFieldsSet] containsObject:self]; }
- (BOOL)isRatingField { return [[[BDSKTypeManager sharedManager] ratingFieldsSet] containsObject:self]; }
- (BOOL)isIntegerField { return [self isBooleanField] || [self isTriStateField] || [self isRatingField]; }
- (BOOL)isLocalFileField { return [[[BDSKTypeManager sharedManager] localFileFieldsSet] containsObject:self]; }
- (BOOL)isRemoteURLField { return [[[BDSKTypeManager sharedManager] remoteURLFieldsSet] containsObject:self]; }
- (BOOL)isCitationField { return [[[BDSKTypeManager sharedManager] citationFieldsSet] containsObject:self]; }
- (BOOL)isPersonField { return [[[BDSKTypeManager sharedManager] personFieldsSet] containsObject:self]; }
- (BOOL)isURLField { return [[[BDSKTypeManager sharedManager] allURLFieldsSet] containsObject:self]; }
- (BOOL)isNoteField { return [[[BDSKTypeManager sharedManager] noteFieldsSet] containsObject:self]; }
- (BOOL)isNumericField { return [[[BDSKTypeManager sharedManager] numericFieldsSet] containsObject:self]; }
- (BOOL)isSingleValuedGroupField { return [[[BDSKTypeManager sharedManager] singleValuedGroupFieldsSet] containsObject:self]; }
- (BOOL)isSingleValuedField { return [[[BDSKTypeManager sharedManager] singleValuedGroupFieldsSet] containsObject:self] || [self isInvalidGroupField]; }
- (BOOL)isInvalidGroupField { return [[[BDSKTypeManager sharedManager] invalidGroupFieldsSet] containsObject:self]; }

@end
