//
//  FFMpegAVFrame.m
//  Telegram
//
//  Created by Mikhail Filimonov on 05/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

#import "FFMpegAVFrame.h"

#import "libavformat/avformat.h"

@interface FFMpegAVFrame () {
    AVFrame *_impl;
}

@end

@implementation FFMpegAVFrame

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _impl = av_frame_alloc();
    }
    return self;
}

- (void)dealloc {
    if (_impl) {
        av_frame_unref(_impl);
    }
}

- (int32_t)width {
    return _impl->width;
}

- (int32_t)height {
    return _impl->height;
}

- (uint8_t **)data {
    return _impl->data;
}

- (int *)lineSize {
    return _impl->linesize;
}

- (int64_t)pts {
    return _impl->pts;
}

- (void *)impl {
    return _impl;
}

- (FFMpegAVFrameColorRange)colorRange {
    switch (_impl->color_range) {
        case AVCOL_RANGE_MPEG:
        case AVCOL_RANGE_UNSPECIFIED:
            return FFMpegAVFrameColorRangeRestricted;
        default:
            return FFMpegAVFrameColorRangeFull;
    }
}


@end
