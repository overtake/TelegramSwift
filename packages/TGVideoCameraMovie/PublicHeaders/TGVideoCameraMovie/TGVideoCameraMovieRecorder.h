#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>


typedef enum
{
    TGMediaVideoConversionPresetCompressedDefault,
    TGMediaVideoConversionPresetCompressedVeryLow,
    TGMediaVideoConversionPresetCompressedLow,
    TGMediaVideoConversionPresetCompressedMedium,
    TGMediaVideoConversionPresetCompressedHigh,
    TGMediaVideoConversionPresetCompressedVeryHigh,
    TGMediaVideoConversionPresetAnimation,
    TGMediaVideoConversionPresetVideoMessage
} TGMediaVideoConversionPreset;



@interface TGMediaVideoConversionPresetSettings : NSObject

+ (CGSize)maximumSizeForPreset:(TGMediaVideoConversionPreset)preset;
+ (NSDictionary *)videoSettingsForPreset:(TGMediaVideoConversionPreset)preset dimensions:(CGSize)dimensions bitrate:(int)bitrate;
+ (NSDictionary *)audioSettingsForPreset:(TGMediaVideoConversionPreset)preset bitrate:(int)bitrate;

@end

@protocol TGVideoCameraMovieRecorderDelegate;

@interface TGVideoCameraMovieRecorder : NSObject

@property (nonatomic, assign) bool paused;

- (instancetype)initWithURL:(NSURL *)URL delegate:(id<TGVideoCameraMovieRecorderDelegate>)delegate callbackQueue:(dispatch_queue_t)queue;

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings;
- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings;


- (void)prepareToRecord;

- (void)appendVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)finishRecording;

- (NSTimeInterval)videoDuration;

@end

@protocol TGVideoCameraMovieRecorderDelegate <NSObject>
@required
- (void)movieRecorderDidFinishPreparing:(TGVideoCameraMovieRecorder *)recorder;
- (void)movieRecorder:(TGVideoCameraMovieRecorder *)recorder didFailWithError:(NSError *)error;
- (void)movieRecorderDidFinishRecording:(TGVideoCameraMovieRecorder *)recorder;
@end
