//
//  FFMpegAVFrame.h
//  Telegram
//
//  Created by Mikhail Filimonov on 05/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//
#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FFMpegAVFrameColorRange) {
    FFMpegAVFrameColorRangeRestricted,
    FFMpegAVFrameColorRangeFull
};


@interface FFMpegAVFrame : NSObject

@property (nonatomic, readonly) int32_t width;
@property (nonatomic, readonly) int32_t height;
@property (nonatomic, readonly) uint8_t **data;
@property (nonatomic, readonly) int *lineSize;
@property (nonatomic, readonly) int64_t pts;
@property (nonatomic, readonly) FFMpegAVFrameColorRange colorRange;

- (instancetype)init;

- (void *)impl;

@end

NS_ASSUME_NONNULL_END
