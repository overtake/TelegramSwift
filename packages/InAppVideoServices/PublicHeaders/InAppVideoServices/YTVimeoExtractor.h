//
//  YTVimeoExtractor.h
//  YTVimeoExtractor
//
//  Created by Louis Larpin on 18/02/13.
//

#if !__has_feature(nullability)
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#endif

#import <Foundation/Foundation.h>
#import "YTVimeoError.h"
#import "YTVimeoExtractorOperation.h"
#import "YTVimeoError.h"
#import "YTVimeoURLParser.h"
#import "YTVimeoVideo.h"
/**
 *  The `YTVimeoExtractor` is the main class and its sole purpose is to fetch information about Vimeo videos. Use the two main methods `<-fetchVideoWithIdentifier:withReferer:completionHandler:>` or `<-fetchVideoWithVimeoURL:withReferer:completionHandler:>` to obtain video information.
 */
@interface YTVimeoExtractor : NSObject
NS_ASSUME_NONNULL_BEGIN
/**
 *  ------------------
 *  @name Initializing
 *  ------------------
 */

/**
 *  Returns the shared extractor.
 *
 *  @return The shared extractor.
 */
+(instancetype)sharedExtractor;

/**
 *  --------------------------------
 *  @name Fetching Video Information
 *  --------------------------------
 */

/**
 *   Starts an asynchronous operation for the specified video identifier, and referer, then calls a handler upon completion.
 *
 *  @param videoIdentifier   A Vimeo video identifier. If the video identifier is `nil` then an exception will be thrown. Also, if it is an empty string the completion handler will be called with the `YTVimeoVideoErrorDomain` domain and `YTVimeoErrorInvalidVideoIdentifier` code.
 *  @param referer           The referer, if the Vimeo video has domain-level restrictions. If this value is `nil` then a default one will be used.
 *  @param completionHandler A block to execute when the extraction process is finished, which is executed on the main thread. If the completion handler is nil, this method throws an exception. The block has, two parameters a `YTVimeoVideo` object if, the operation was completed successfully and a `NSError` object describing the network or parsing error that may have occurred.
 */
-(void)fetchVideoWithIdentifier:(NSString *)videoIdentifier withReferer:(NSString *__nullable)referer completionHandler:(void (^)(YTVimeoVideo * __nullable video, NSError * __nullable error))completionHandler;

/**
 *  Starts an asynchronous operation for the specified video URL, and referer, then calls a handler upon completion.
 *
 *  @param videoURL           A Vimeo video URL. If the video URL is `nil` then an exception will be thrown. Also, if it is an empty string the completion handler will be called with the  `YTVimeoVideoErrorDomain` domain and `YTVimeoErrorInvalidVideoIdentifier` code.
 *  @param referer           The referer, if the Vimeo video has domain-level restrictions. If this value is `nil` then a default one will be used.
 *  @param completionHandler A block to execute when the extraction process is finished, which is executed on the main thread. If the completion handler is nil, this method throws an exception. The block has, two parameters a `YTVimeoVideo` object if, the operation was completed successfully and a `NSError` object describing the network or parsing error that may have occurred.
 */
-(void)fetchVideoWithVimeoURL:(NSString *)videoURL withReferer:(NSString *__nullable)referer completionHandler:(void (^)(YTVimeoVideo * __nullable video, NSError * __nullable error))completionHandler;

@end
NS_ASSUME_NONNULL_END

