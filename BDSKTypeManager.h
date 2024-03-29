//
//  BDSKTypeManager.h
//  BibDesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
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

#import <Foundation/Foundation.h>


@interface BDSKTypeManager : NSObject {
	NSDictionary *fieldsForTypesDict;
	NSArray *types;
	NSDictionary *fieldNameForPubMedTagDict;
	NSDictionary *pubMedTagForFieldNameDict;
	NSDictionary *bibTeXTypeForPubMedTypeDict;
	NSDictionary *fieldNameForRISTagDict;
	NSDictionary *RISTagForFieldNameDict;
	NSDictionary *bibTeXTypeForRISTypeDict;
	NSDictionary *fieldNamesForMARCTagDict;
	NSDictionary *fieldNamesForUNIMARCTagDict;
	NSDictionary *fieldNameForJSTORTagDict;
	NSDictionary *fieldDescriptionForJSTORTagDict;
    NSDictionary *fieldNameForWebOfScienceTagDict;
    NSDictionary *fieldDescriptionForWebOfScienceTagDict;
    NSDictionary *bibTeXTypeForWebOfScienceTypeDict;
    NSDictionary *bibTeXTypeForDublinCoreTypeDict;
    NSDictionary *fieldNameForDublinCoreTermDict;
    NSDictionary *fieldNameForReferTagDict;
    NSDictionary *bibTeXTypeForReferTypeDict;
    NSDictionary *bibTeXTypeForHCiteTypeDict;
	NSDictionary *MODSGenresForBibTeXTypeDict;
	NSDictionary *defaultFieldsForTypesDict;
	NSArray *defaultTypes;
	NSSet *standardTypes;
	NSSet *allFieldsSet;
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
    
    NSSet *localFileFieldsSet;
    NSSet *remoteURLFieldsSet;
    NSSet *allURLFieldsSet;
    NSSet *ratingFieldsSet;
    NSSet *triStateFieldsSet;
    NSSet *booleanFieldsSet;
    NSSet *citationFieldsSet;
    NSSet *personFieldsSet;
    NSSet *noteFieldsSet;
    NSSet *numericFieldsSet;
    NSSet *singleValuedGroupFieldsSet;
    NSSet *invalidGroupFieldsSet;
    
    NSArray *requiredFieldsForCiteKey;
    NSArray *requiredFieldsForLocalFile;
}

+ (BDSKTypeManager *)sharedManager;

// Updating
- (void)updateUserTypes:(NSArray *)newTypes andFields:(NSDictionary *)newFieldsForTypes;
- (void)updateCustomFields;

// BibTeX
- (NSArray *)requiredFieldsForType:(NSString *)type;
- (NSArray *)optionalFieldsForType:(NSString *)type;
- (NSArray *)userDefaultFieldsForType:(NSString *)type;
- (NSArray *)types;
- (NSDictionary *)defaultFieldsForTypes;
- (NSArray *)defaultTypes;
- (BOOL)isStandardType:(NSString *)type;

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
- (NSSet *)allFieldsSet;

- (NSArray *)allFieldNamesIncluding:(NSArray *)include excluding:(NSArray *)exclude;

// PubMed
- (NSString *)fieldNameForPubMedTag:(NSString *)tag;
- (NSString *)bibTeXTypeForPubMedType:(NSString *)type;

// RIS
- (NSString *)fieldNameForRISTag:(NSString *)tag;
- (NSString *)bibTeXTypeForRISType:(NSString *)type;
- (NSString *)RISTagForBibTeXFieldName:(NSString *)name;
- (NSString *)RISTypeForBibTeXType:(NSString *)type;

// Refer
- (NSString *)fieldNameForReferTag:(NSString *)tag;
- (NSString *)bibTeXTypeForReferType:(NSString *)type;

// MARC
- (NSDictionary *)fieldNamesForMARCTag:(NSString *)name;
- (NSDictionary *)fieldNamesForUNIMARCTag:(NSString *)name;

// JSTOR
- (NSString *)fieldNameForJSTORTag:(NSString *)tag;
- (NSString *)fieldNameForJSTORDescription:(NSString *)name;

// Web of Science
- (NSString *)bibTeXTypeForWebOfScienceType:(NSString *)type;
- (NSString *)fieldNameForWebOfScienceTag:(NSString *)tag;
- (NSString *)fieldNameForWebOfScienceDescription:(NSString *)name;

// Dublin Core
- (NSString *)fieldNameForDublinCoreTerm:(NSString *)term;
- (NSString *)bibTeXTypeForDublinCoreType:(NSString *)type;

// HCite
- (NSString *)bibTeXTypeForHCiteType:(NSString *)type;

// MODS
- (NSDictionary *)MODSGenresForBibTeXType:(NSString *)type;

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
- (BOOL)isURLField;
// the next 3 also match BDSKLinkedFileString and/or BDSKRemoteURLString
- (BOOL)isGeneralLocalFileField;
- (BOOL)isGeneralRemoteURLField;
- (BOOL)isGeneralURLField;
- (BOOL)isPersonField;
- (BOOL)isCitationField;
- (BOOL)isNoteField;
- (BOOL)isNumericField;
// isSingleValuedField checks invalid group fields and single valued group fields; single valuedGroupFields doesn't include the invalid ones, which are single valued as well
- (BOOL)isSingleValuedField;
- (BOOL)isInvalidGroupField;
- (BOOL)isSingleValuedGroupField;
@end
