//
//  YTVimeoVideo+Private.h
//  YTVimeoExtractor
//
//  Created by Soneé John on 3/15/16.
//  Copyright © 2016 Louis Larpin. All rights reserved.
//
#if !__has_feature(nullability)
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#endif

#import "YTVimeoVideo.h"
NS_ASSUME_NONNULL_BEGIN
@interface YTVimeoVideo ()

/**
 *  Initializes a `YTVimeoVideo` video object with the specified identifier and info.
 *
 *  @param identifier A Vimeo video identifier. This parameter should not be `nil`
 *  @param info The dictionary that the class will use to parse out the data. This parameter should not be `nil`
 *
 *  @return A newly initialized `YTVimeoVideo` object.
 */
- (instancetype) initWithIdentifier:(NSString *)identifier info:(NSDictionary *)info;
/**
 *  Starts extracting information about the Vimeo video.
 *
 *  @param completionHandler A block to execute when the extraction process is finished. The completion handler is executed on the main thread. If the completion handler is nil, this method throws an exception.
 */
- (void)extractVideoInfoWithCompletionHandler:(void (^)(NSError *error))completionHandler;

NS_ASSUME_NONNULL_END
@end