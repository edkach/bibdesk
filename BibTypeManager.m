//
//  BibTypeManager.m
//  Bibdesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "BibTypeManager.h"

static BibTypeManager *sharedInstance = nil;

@implementation BibTypeManager
+ (BibTypeManager *)sharedManager{
    if(!sharedInstance) sharedInstance = [[BibTypeManager alloc] init];
    return sharedInstance;
}

- (id)init{
    self = [super init];
    typeInfoDict = [[NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TypeInfo.plist"]] retain];

    // this set is used for warning the user on manual entry of a citekey; allows non-ASCII characters and some math symbols
    invalidCiteKeyCharSet = [[NSCharacterSet characterSetWithCharactersInString:@" '\"@,\\#}{~&%$^"] retain];
    
    return self;
}

- (NSString *)defaultTypeForFileFormat:(NSString *)fileFormat{
     return [[[typeInfoDict objectForKey:@"FileTypes"] objectForKey:fileFormat] objectForKey:@"DefaultType"];
}

- (NSArray *)allRemovableFieldNames{
    NSArray *names = [typeInfoDict objectForKey:@"AllRemovableFieldNames"];
    if (names == nil) [NSException raise:@"nilNames exception" format:@"allRemovableFieldNames returning nil."];
    return names;
}

- (NSArray *)requiredFieldsForType:(NSString *)type{
    NSDictionary *fieldsForType = [[typeInfoDict objectForKey:@"FieldsForTypes"] objectForKey:type];

    if(fieldsForType){
        return [fieldsForType objectForKey:@"required"];
    }else{
        return [NSArray array];
    }
}

- (NSArray *)optionalFieldsForType:(NSString *)type{
    NSDictionary *fieldsForType = [[typeInfoDict objectForKey:@"FieldsForTypes"] objectForKey:type];

    if(fieldsForType){
        return [fieldsForType objectForKey:@"optional"];
    }else{
        return [NSArray array];
    }
}

- (NSArray *)userDefaultFieldsForType:(NSString *)type{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKDefaultFieldsKey];
}

- (NSArray *)bibTypesForFileType:(NSString *)fileType{
    return [[typeInfoDict objectForKey:@"TypesForFileType"] objectForKey:fileType];
}

- (NSString *)fieldNameForPubMedTag:(NSString *)tag{
    return [[typeInfoDict objectForKey:@"BibTeXFieldNamesForPubMedTags"] objectForKey:tag];
}

- (NSString *)bibtexTypeForPubMedType:(NSString *)type{
    return [[typeInfoDict objectForKey:@"BibTeXTypesForPubMedTypes"] objectForKey:type];
}

- (NSCharacterSet *)invalidCharactersForField:(NSString *)fieldName inType:(NSString *)type{
	if( ! [type isEqualToString:@"BibTeX"] || ! [fieldName isEqualToString:@"Cite Key"]){
		[NSException raise:@"unimpl. feat. exc." format:@"invalidCharactersForField is partly implemented"];
	}
	return invalidCiteKeyCharSet;
}

@end
