//
//  YTVimeoError.h
//  YTVimeoExtractor
//
//  Created by Soneé Delano John on 11/28/15.
//  Copyright © 2015 Louis Larpin. All rights reserved.
//
#import <Foundation/Foundation.h>

// Predefined domain for errors in the Library.
extern NSString *const YTVimeoVideoErrorDomain;

typedef NS_ENUM(NSInteger, YTVimeoErrorCode) {
    
    /**
     *  Returned when the given video identifier string is invalid.
     */
    YTVimeoErrorInvalidVideoIdentifier = -100,
    /**
     * Returned when a network error occurs.
     */
    YTVimeoErrorNetwork = -101,
    /**
     *  Returned when no suitable video stream is available.
     */
    YTVimeoErrorNoSuitableStreamAvailable = -102,
    
    /**
     *  Returned when the video was removed or when the video did not exist.
     */
    YTVimeoErrorRemovedVideo  = -103,
    
    /**
     *  Returned when the video is private.
     */
    YTVimeoErrorRestrictedPlayback = -104,
    
  
    YTVimeoErrorUnknown = -105,

};