
#import <Foundation/Foundation.h>

@class TGDataItem;
@class TGAudioWaveform;

@interface TGOpusAudioRecorder : NSObject

@property (nonatomic, copy) void (^pauseRecording)();
@property (nonatomic, copy) void (^micLevel)(CGFloat);

- (instancetype)initWithFileEncryption:(bool)fileEncryption;

- (void)_beginAudioSession:(bool)speaker;
- (void)prepareRecord:(bool)playTone completion:(void (^)())completion;
- (void)record;
- (TGDataItem *)stopRecording:(NSTimeInterval *)recordedDuration waveform:(__autoreleasing TGAudioWaveform **)waveform;
- (NSTimeInterval)currentDuration;

@end
