//
//  BibPref_Files.m
//  Bibdesk
//
//  Created by Adam Maxwell on 01/02/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BibPref_Files.h"
#import "BibAppController.h"


@implementation BibPref_Files

- (void)awakeFromNib{
    [super awakeFromNib];
    
    encodingsArray = [[[(BibAppController *)[NSApp delegate] encodingDefinitionDictionary] objectForKey:@"StringEncodings"] retain];
    encodingNames = [[[(BibAppController *)[NSApp delegate] encodingDefinitionDictionary] objectForKey:@"DisplayNames"] retain];

    [encodingPopUp removeAllItems];
    [encodingPopUp addItemsWithTitles:encodingNames];
}

- (void)dealloc{
    [encodingsArray release];
    [encodingNames release];
    [super dealloc];
}

- (void)updateUI{
    OFPreferenceWrapper *prefs = [OFPreferenceWrapper sharedPreferenceWrapper];
    [encodingPopUp selectItemAtIndex:[self tagForEncoding:[prefs integerForKey:BDSKDefaultStringEncoding]]];
    [defaultParserRadio selectCellWithTag:( [prefs boolForKey:BDSKUseUnicodeBibTeXParser] ? 1 : 0 )];
    [encodingPopUp setEnabled:[prefs boolForKey:BDSKUseUnicodeBibTeXParser]]; // since btparse is not compatible with other encodings; it can still be used via the File->Open menu
}

- (IBAction)setDefaultStringEncoding:(id)sender{    
    NSStringEncoding encoding = [[encodingsArray objectAtIndex:[sender indexOfSelectedItem]] intValue];
    
    // NSLog(@"set encoding to %i for tag %i", [[encodingsArray objectAtIndex:[sender indexOfSelectedItem]] intValue], [sender indexOfSelectedItem]);    
    [[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:encoding forKey:BDSKDefaultStringEncoding];    
}

- (unsigned)tagForEncoding:(NSStringEncoding)encoding{
    return [encodingsArray indexOfObject:[NSNumber numberWithInt:encoding]];
}

- (IBAction)setDefaultBibTeXParser:(id)sender{
    BOOL yn = ( [[sender selectedCell] tag] == 0 ? NO : YES );
    [[OFPreferenceWrapper sharedPreferenceWrapper] setBool:yn forKey:BDSKUseUnicodeBibTeXParser];
    if(!yn)
        [[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:NSASCIIStringEncoding forKey:BDSKDefaultStringEncoding];
    [self updateUI];
    // NSLog(@"use unicode parser is %@", ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUseUnicodeBibTeXParser] ? @"YES" : @"NO" ) );
}
    

@end
