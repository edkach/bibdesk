//
//  BDSKImportCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/5/08.
/*
 This software is Copyright (c) 2008-2009
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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
//  Created by Christiaan Hofman on 12/5/08.
/*
 This software is Copyright (c) 2008-2009
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKImportCommand.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKStringParser.h"


@implementation BDSKImportCommand

- (id)performDefaultImplementation {

	// figure out parameters first
	NSDictionary *params = [self evaluatedArguments];
	if (params == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
			return @"";
	}
	
	BibDocument *document = nil;
	id receiver = [self evaluatedReceivers];
    NSScriptObjectSpecifier *dP = [self directParameter];
	id dPO = [dP objectsByEvaluatingSpecifier];

	if ([receiver isKindOfClass:[BibDocument class]]) {
        document = receiver;
    } else if ([dPO isKindOfClass:[BibDocument class]]) {
        document = dPO;
    } else {
		// give up
		[self setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
		[self setScriptErrorString:NSLocalizedString(@"The import command can only be sent to the documents.", @"Error description")];
		return nil;
	}
	
	// the 'from' parameters gives the template name to use
	id string = [params objectForKey:@"from"];
    // make sure we get something
	if (string == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return nil;
	}
	// make sure we get the right thing
	if ([string isKindOfClass:[NSURL class]]) {
        string = [NSString stringWithContentsOfFile:[string path] encoding:0 guessEncoding:YES];
	}
    
    if ([string isKindOfClass:[NSString class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
        return nil;
	}
	
    NSArray *pubs = [document publicationsForString:string type:BDSKUnknownStringType verbose:NO error:NULL];
	if ([pubs count])
    	[document addPublications:pubs publicationsToAutoFile:nil temporaryCiteKey:nil selectLibrary:NO edit:NO];
	
    return pubs;
}

@end
