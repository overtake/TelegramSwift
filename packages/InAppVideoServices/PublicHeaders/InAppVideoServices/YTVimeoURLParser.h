//
//  YTVimeoURLParser.h
//  YTVimeoExtractor
//
//  Created by Soneé Delano John on 12/2/15.
//  Copyright © 2015 Louis Larpin. All rights reserved.
//

#import <Foundation/Foundation.h>
/**
 *  YTVimeoURLParser is used to validate and parse put Vimeo URLs. The sole purpose of the class is to check if a given URL can be handled by the `YTVimeoExtractor` class.
 */
@interface YTVimeoURLParser : NSObject
/**
 *  ------------------
 *  @name Validating URLs
 *  ------------------
 */

/**
 *  Checks to see if a given URL is a valid Vimeo URL. In additonal, this will determine if it can be handled by the `YTVimeoExtractorOperation` class.
 *
 *  @param vimeoURL The Vimeo URL that will be validated.
 *
 *  @return `YES` if URL is valid. Otherwise `NO`
 */
- (BOOL)validateVimeoURL:(NSString *)vimeoURL;
/**
 *  Will extract the Vimeo video identifier from a given URL.
 *
 *  @param vimeoURL The Vimeo URL to be parsed.
 *
 *  @return Will return a identifier if the URL is valid. Otherwise will return a empty string.
 */
- (NSString *)extractVideoIdentifier:(NSString *)vimeoURL;
@end
