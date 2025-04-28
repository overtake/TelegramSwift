#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DetectSpeechStatusChangedBlock)(BOOL isSpeaking);

@interface DetectSpeech : NSObject

@property (nonatomic, copy, nullable) DetectSpeechStatusChangedBlock onStatusChanged;

+ (instancetype)sharedInstance;

- (void)startWithStatusChanged:(DetectSpeechStatusChangedBlock)statusChangedBlock;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
