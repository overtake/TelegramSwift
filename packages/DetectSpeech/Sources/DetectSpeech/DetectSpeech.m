
#import "DetectSpeech.h"

@interface DetectSpeech ()
{
    AudioUnit _audioUnit;
    dispatch_queue_t _queue;
    AUVoiceIOMutedSpeechActivityEventListener _eventListener;
}
@end

@implementation DetectSpeech

+ (instancetype)sharedInstance {
    static DetectSpeech *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DetectSpeech alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("detect-speech-monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)startWithStatusChanged:(DetectSpeechStatusChangedBlock)statusChangedBlock {
    self.onStatusChanged = statusChangedBlock;
    
    dispatch_async(_queue, ^{
        [self setupAudioUnit];
    });
}

- (void)stop {
    dispatch_async(_queue, ^{
        if (self->_audioUnit != NULL) {
            AudioOutputUnitStop(self->_audioUnit);
            AudioUnitUninitialize(self->_audioUnit);
            AudioComponentInstanceDispose(self->_audioUnit);
            self->_audioUnit = NULL;
        }
    });
}

- (void)setupAudioUnit {
    AudioComponentDescription desc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_VoiceProcessingIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };

    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    if (!component) {
        NSLog(@"DetectSpeech: Failed to find AudioComponent");
        return;
    }
    
    
    UInt32 muteUplinkOutput = 1;
    OSStatus result = AudioUnitSetProperty(_audioUnit, kAUVoiceIOProperty_MuteOutput, kAudioUnitScope_Global, 1, &muteUplinkOutput, sizeof(muteUplinkOutput));


    OSStatus status = AudioComponentInstanceNew(component, &_audioUnit);
    if (status != noErr || !_audioUnit) {
        NSLog(@"DetectSpeech: Failed to create AudioUnit");
        return;
    }

    // Set up Speech Activity Event Listener
    __weak typeof(self) weakSelf = self;
    _eventListener = ^(AUVoiceIOSpeechActivityEvent event) {
        switch (event) {
            case kAUVoiceIOSpeechActivityHasStarted:
                if (weakSelf.onStatusChanged) {
                    weakSelf.onStatusChanged(YES);
                }
                break;
            case kAUVoiceIOSpeechActivityHasEnded:
                if (weakSelf.onStatusChanged) {
                    weakSelf.onStatusChanged(NO);
                }
                break;
            default:
                break;
        }
    };

    AUVoiceIOMutedSpeechActivityEventListener listener = _eventListener;
    if (@available(macOS 14.0, *)) {
        status = AudioUnitSetProperty(_audioUnit,
                                      kAUVoiceIOProperty_MutedSpeechActivityEventListener,
                                      kAudioUnitScope_Global,
                                      1,
                                      &listener,
                                      sizeof(listener));
    } 
    if (status != noErr) {
        NSLog(@"DetectSpeech: Failed to set event listener: %d", (int)status);
        _eventListener = nil;
        return;
    }

    status = AudioUnitInitialize(_audioUnit);
    if (status != noErr) {
        NSLog(@"DetectSpeech: Failed to initialize AudioUnit");
        return;
    }

    status = AudioOutputUnitStart(_audioUnit);
    if (status != noErr) {
        NSLog(@"DetectSpeech: Failed to start AudioUnit");
        return;
    }

    NSLog(@"DetectSpeech: Monitoring started");
}

@end
