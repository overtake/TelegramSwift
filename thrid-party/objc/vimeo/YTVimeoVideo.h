//
//  YTVimeoVideo.h
//  YTVimeoExtractor
//
//  Created by Soneé Delano John on 11/28/15.
//  Copyright © 2015 Louis Larpin. All rights reserved.
//

#if !__has_feature(nullability)
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  The various thumbnails of Vimeo videos. These values are used as keys in the `<[YTVimeoVideo thumbnailURLs]>` property.
 */
typedef NS_ENUM(NSUInteger, YTVimeoVideoThumbnailQuality) {
    /**
     *  A thumbnail URL for an image of small size with a width of 640 pixels.
     */
    YTVimeoVideoThumbnailQualitySmall  = 640,
    /**
     *  A thumbnail URL for an image of medium size with a width of 960 pixels.
     */
    YTVimeoVideoThumbnailQualityMedium = 960,
    /**
     *  A thumbnail URL for an image of high definition quality with a width of 1280 pixels.
     */
     YTVimeoVideoThumbnailQualityHD     = 1280,
};
/**
 *  The various stream or download URLs of Vimeo videos. These values are used as keys in the `<[YTVimeoVideo streamURLs]>` property.
 */
typedef NS_ENUM(NSUInteger, YTVimeoVideoQuality) {
    /**
     *  A stream URL for a video of low quality with a height of 270 pixels.
     */
    YTVimeoVideoQualityLow270    = 270,
    /**
     *  A stream URL for a video of medium quality with a height of 360 pixels.
     */
    YTVimeoVideoQualityMedium360 = 360,
    /**
     *  A stream URL for a video of medium quality with a height of 480 pixels.
     */
    YTVimeoVideoQualityMedium480 = 480,
    /**
     *  A stream URL for a video of medium quality with a height of 540 pixels.
     */
    YTVimeoVideoQualityMedium540 = 540,
    /**
     *  A stream URL for a video of HD quality with a height of 720 pixels.
     */
    YTVimeoVideoQualityHD720     = 720,
    /**
     *  A stream URL for a video of HD quality with a height of 1080 pixels.
     */
    YTVimeoVideoQualityHD1080    = 1080,
};

/**
`YTVimeoVideo`represents a Vimeo video. Use this class to access information about a particular video.

@see `YTVimeoExtractor` to obtain a `YTVimeoVideo` object.

@warning Do not manually initialize a `YTVimeoVideo` object. Using the `-init` method will throw an exception.

## Subclassing Notes

It is very important that you do not create a subclass of `YTVimeoVideo`

## NSObject Notes

`YTVimeoVideo` uses the `identifier` to determine the equality between two `YTVimeoVideo` objects. Calling `-isEqual:` on two `YTVimeoVideo` objects that contain the same identifiers will return `YES`, otherwise `-isEqual:` will return `NO`.
*/
@interface YTVimeoVideo : NSObject <NSCopying>
/**
 *  ----------------------------
 *  @name Accessing Information
 *  ----------------------------
 */
/**
 *  The Vimeo video identifier.
 */
@property (nonatomic, readonly) NSString *identifier;
/**
 *  The title of the video.
 */
@property (nonatomic, readonly) NSString *title;
/**
 *  The duration of the video in seconds.
 */
@property (nonatomic, readonly) NSTimeInterval duration;

/**
 *  A `NSDictionary` object that contains the various stream URLs.
 * @see YTVimeoVideoQuality
 */
#if __has_feature(objc_generics)
@property (nonatomic, readonly) NSDictionary<id, NSURL *> *streamURLs;
#else
@property (nonatomic, readonly) NSDictionary *streamURLs;
#endif

/**
 *  A `NSDictionary` object that contains the various thumbnail URLs.
 *  @see YTVimeoVideoThumbnailQuality
 */
#if __has_feature(objc_generics)
@property (nonatomic, readonly) NSDictionary<id, NSURL *> *__nullable thumbnailURLs;
#else
@property (nonatomic, readonly) NSDictionary *thumbnailURLs;
#endif

/**
 *  A `NSDictionary` object that contains all the metadata about the video.
 */
@property (nonatomic, readonly) NSDictionary *metaData;
/**
 *  Extracts the highest quality stream URL.
 *
 *  @see YTVimeoVideoQuality
 *  @return The highest quality stream URL.
 */
-(NSURL *)highestQualityStreamURL;
/**
 *  Extracts the lowest quality stream URL.
 *
 *  @see YTVimeoVideoQuality
 *  @return The lowest quality stream URL.
 */
-(NSURL *)lowestQualityStreamURL;
/**
 *  The HTTP Live Stream URL for the video.
 */
@property (nonatomic, readonly, nullable) NSURL *HTTPLiveStreamURL;
NS_ASSUME_NONNULL_END

@end
