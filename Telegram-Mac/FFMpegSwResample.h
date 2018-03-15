#import <Foundation/Foundation.h>

#import "ffmpeg/include/libavutil/avutil.h"
#import "ffmpeg/include/libavutil/channel_layout.h"
#import "ffmpeg/include/libswresample/swresample.h"

@interface FFMpegSwResample : NSObject

- (instancetype)initWithSourceChannelCount:(NSInteger)sourceChannelCount sourceSampleRate:(NSInteger)sourceSampleRate sourceSampleFormat:(enum AVSampleFormat)sourceSampleFormat destinationChannelCount:(NSInteger)destinationChannelCount destinationSampleRate:(NSInteger)destinationSampleRate destinationSampleFormat:(enum AVSampleFormat)destinationSampleFormat;
- (NSData *)resample:(AVFrame *)frame;

@end
