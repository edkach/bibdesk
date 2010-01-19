//
//  BDSKTypeManager.h
//  BibDesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
/*
 This software is Copyright (c) 2002-2010
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

#import <Foundation/Foundation.h>
#import "BDSKStringConstants.h"

// The filename and keys used in the plist
#define TYPE_INFO_FILENAME                    @"TypeInfo.plist"
#define FIELDS_FOR_TYPES_KEY                  @"FieldsForTypes"
#define REQUIRED_KEY                          @"required"
#define OPTIONAL_KEY                          @"optional"
#define TYPES_FOR_FILE_TYPE_KEY               @"TypesForFileType"
#define DEFAULT_TYPES_FOR_FILE_TYPE_KEY       @"DefaultTypesForFileType"
#define BIBTEX_FIELDS_FOR_PUBMED_TAGS_KEY     @"BibTeXFieldNamesForPubMedTags"
#define BIBTEX_TYPES_FOR_PUBMED_TYPES_KEY     @"BibTeXTypesForPubMedTypes"
#define BIBTEX_FIELDS_FOR_RIS_TAGS_KEY        @"BibTeXFieldNamesForRISTags"
#define RIS_TAGS_FOR_BIBTEX_FIELDS_KEY        @"RISTagsForBibTeXFieldNames"
#define BIBTEX_TYPES_FOR_RIS_TYPES_KEY        @"BibTeXTypesForRISTypes"
#define BIBTEX_FIELDS_FOR_MARC_TAGS_KEY       @"BibTeXFieldNamesForMARCTags"
#define BIBTEX_FIELDS_FOR_UNIMARC_TAGS_KEY    @"BibTeXFieldNamesForUNIMARCTags"
#define BIBTEX_FIELDS_FOR_JSTOR_TAGS_KEY      @"BibTeXFieldNamesForJSTORTags"
#define FIELD_DESCRIPTIONS_FOR_JSTOR_TAGS_KEY @"FieldDescriptionsForJSTORTags"
#define BIBTEX_FIELDS_FOR_WOS_TAGS_KEY        @"BibTeXFieldNamesForWebOfScienceTags"
#define FIELD_DESCRIPTIONS_FOR_WOS_TAGS_KEY   @"FieldDescriptionsForWebOfScienceTags"
#define BIBTEX_TYPES_FOR_WOS_TYPES_KEY        @"BibTeXTypesForWebOfScienceTypes"
#define MODS_GENRES_FOR_BIBTEX_TYPES_KEY      @"MODSGenresForBibTeXType"
#define BIBTEX_TYPES_FOR_DC_TYPES_KEY         @"BibTeXTypesForDublinCoreTypes"
#define BIBTEX_FIELDS_FOR_DC_TERMS_KEY        @"BibTeXFieldNamesForDublinCoreTerms"
#define BIBTEX_FIELDS_FOR_REFER_TAGS_KEY      @"BibTeXFieldNamesForReferTags"
#define BIBTEX_TYPES_FOR_REFER_TYPES_KEY      @"BibTeXTypesForReferTypes"
#define BIBTEX_TYPES_FOR_HCITE_TYPES_KEY      @"BibTeXTypesForHCiteTypes"


@interface BDSKTypeManager : NSObject {
	NSDictionary *fieldsForTypesDict;
	NSArray *types;
	NSDictionary *fieldNameForPubMedTagDict;
	NSDictionary *pubMedTagForFieldNameDict;
	NSDictionary *bibtexTypeForPubMedTypeDict;
	NSDictionary *fieldNameForRISTagDict;
	NSDictionary *RISTagForFieldNameDict;
	NSDictionary *bibtexTypeForRISTypeDict;
	NSDictionary *fieldNamesForMARCTagDict;
	NSDictionary *fieldNamesForUNIMARCTagDict;
	NSDictionary *fieldNameForJSTORTagDict;
	NSDictionary *fieldDescriptionForJSTORTagDict;
    NSDictionary *fieldNameForWebOfScienceTagDict;
    NSDictionary *fieldDescriptionForWebOfScienceTagDict;
    NSDictionary *bibtexTypeForWebOfScienceTypeDict;
    NSDictionary *bibtexTypeForDublinCoreTypeDict;
    NSDictionary *fieldNameForDublinCoreTermDict;
    NSDictionary *fieldNameForReferTagDict;
    NSDictionary *bibtexTypeForReferTypeDict;
    NSDictionary *bibtexTypeForHCiteTypeDict;
	NSDictionary *MODSGenresForBibTeXTypeDict;
	NSDictionary *defaultFieldsForTypesDict;
	NSSet *defaultTypes;
	NSSet *allFieldNames;
	NSCharacterSet *invalidCiteKeyCharSet;
	NSCharacterSet *fragileCiteKeyCharSet;
	NSCharacterSet *strictInvalidCiteKeyCharSet;
	NSCharacterSet *invalidLocalUrlCharSet;
	NSCharacterSet *strictInvalidLocalUrlCharSet;
	NSCharacterSet *veryStrictInvalidLocalUrlCharSet;
	NSCharacterSet *invalidRemoteUrlCharSet;
	NSCharacterSet *strictInvalidRemoteUrlCharSet;
	NSCharacterSet *invalidGeneralCharSet;
	NSCharacterSet *strictInvalidGeneralCharSet;
	NSCharacterSet *separatorCharSet;
    
    NSMutableSet *localFileFieldsSet;
    NSMutableSet *remoteURLFieldsSet;
    NSMutableSet *allURLFieldsSet;
    NSMutableSet *ratingFieldsSet;
    NSMutableSet *triStateFieldsSet;
    NSMutableSet *booleanFieldsSet;
    NSMutableSet *citationFieldsSet;
    NSMutableSet *personFieldsSet;
    NSMutableSet *singleValuedGroupFieldsSet;
    NSMutableSet *invalidGroupFieldsSet;
    
    NSArray *requiredFieldsForCiteKey;
    NSArray *requiredFieldsForLocalFile;
}

+ (BDSKTypeManager *)sharedManager;

// Updating
- (void)reloadTypesAndFields;

// BibTeX
- (NSArray *)requiredFieldsForType:(NSString *)type;
- (NSArray *)optionalFieldsForType:(NSString *)type;
- (NSArray *)userDefaultFieldsForType:(NSString *)type;
- (NSArray *)bibTypes;
- (NSSet *)allFieldNames;
- (NSArray *)allFieldNamesIncluding:(NSArray *)include excluding:(NSArray *)exclude;
- (NSDictionary *)defaultFieldsForTypes;
- (BOOL)isDefaultType:(NSString *)type;

// PubMed
- (NSString *)fieldNameForPubMedTag:(NSString *)tag;
- (NSString *)bibtexTypeForPubMedType:(NSString *)type;

// RIS
- (NSString *)fieldNameForRISTag:(NSString *)tag;
- (NSString *)bibtexTypeForRISType:(NSString *)type;
- (NSString *)RISTagForBibTeXFieldName:(NSString *)name;
- (NSString *)RISTypeForBibTeXType:(NSString *)type;

// Refer
- (NSString *)fieldNameForReferTag:(NSString *)tag;
- (NSString *)bibtexTypeForReferType:(NSString *)type;

// MARC
- (NSDictionary *)fieldNamesForMARCTag:(NSString *)name;
- (NSDictionary *)fieldNamesForUNIMARCTag:(NSString *)name;

// JSTOR
- (NSString *)fieldNameForJSTORTag:(NSString *)tag;
- (NSString *)fieldNameForJSTORDescription:(NSString *)name;

// Web of Science
- (NSString *)bibtexTypeForWebOfScienceType:(NSString *)type;
- (NSString *)fieldNameForWebOfScienceTag:(NSString *)tag;
- (NSString *)fieldNameForWebOfScienceDescription:(NSString *)name;

// Dublin Core
- (NSString *)fieldNameForDublinCoreTerm:(NSString *)term;
- (NSString *)bibtexTypeForDublinCoreType:(NSString *)type;

// HCite
- (NSString *)bibtexTypeForHCiteType:(NSString *)type;

// MODS
- (NSDictionary *)MODSGenresForBibTeXType:(NSString *)type;

// Field types sets
- (NSSet *)localFileFieldsSet;
- (NSSet *)remoteURLFieldsSet;
- (NSSet *)allURLFieldsSet;
- (NSSet *)noteFieldsSet;
- (NSSet *)personFieldsSet;
- (NSSet *)booleanFieldsSet;
- (NSSet *)triStateFieldsSet;
- (NSSet *)ratingFieldsSet;
- (NSSet *)citationFieldsSet;
- (NSSet *)numericFieldsSet;
- (NSSet *)invalidGroupFieldsSet;
- (NSSet *)singleValuedGroupFieldsSet;

// Character sets for format parsing and group splitting
- (NSCharacterSet *)invalidCharactersForField:(NSString *)fieldName;
- (NSCharacterSet *)strictInvalidCharactersForField:(NSString *)fieldName;
- (NSCharacterSet *)veryStrictInvalidCharactersForField:(NSString *)fieldName;
- (NSCharacterSet *)invalidFieldNameCharacterSet;
- (NSCharacterSet *)fragileCiteKeyCharacterSet;
- (NSCharacterSet *)separatorCharacterSetForField:(NSString *)fieldName;

// Fields for autogeneration formats
- (NSArray *)requiredFieldsForCiteKey;
- (void)setRequiredFieldsForCiteKey:(NSArray *)newFields;
- (NSArray *)requiredFieldsForLocalFile;
- (void)setRequiredFieldsForLocalFile:(NSArray *)newFields;

@end

#pragma mark -

@interface NSString (BDSKTypeExtensions)
- (BOOL)isBooleanField;
- (BOOL)isTriStateField;
- (BOOL)isRatingField;
- (BOOL)isIntegerField;
- (BOOL)isLocalFileField;
- (BOOL)isRemoteURLField;
- (BOOL)isPersonField;
- (BOOL)isURLField;
- (BOOL)isCitationField;
- (BOOL)isNoteField;
- (BOOL)isNumericField;
// isSingleValuedField checks invalid group fields and single valued group fields; single valuedGroupFields doesn't include the invalid ones, which are single valued as well
- (BOOL)isSingleValuedField;
- (BOOL)isInvalidGroupField;
- (BOOL)isSingleValuedGroupField;
@end
