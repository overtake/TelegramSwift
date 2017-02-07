
#import "TGOpusAudioRecorder.h"

#import "ATQueue.h"


#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

#import "opus.h"
#import "opusenc.h"

#import "TGDataItem.h"
#import "TGAudioWaveform.h"

#define kOutputBus 0
#define kInputBus 1

static const int TGOpusAudioRecorderSampleRate = 48000;

typedef struct
{
    AudioComponentInstance audioUnit;
    bool audioUnitStarted;
    bool audioUnitInitialized;
    
    AudioComponentInstance playbackUnit;
    bool playbackUnitStarted;
    bool playbackUnitInitialized;
    
    int globalAudioRecorderId;
} TGOpusAudioRecorderContext;

static NSData *toneAudioBuffer;
static int64_t toneAudioOffset;

static TGOpusAudioRecorderContext globalRecorderContext = { .audioUnit = NULL, .audioUnitStarted = false, .audioUnitInitialized = false, .playbackUnit = NULL, .playbackUnitStarted = false, .playbackUnitInitialized = false, .globalAudioRecorderId = -1};
static __weak TGOpusAudioRecorder *globalRecorder = nil;

static dispatch_semaphore_t playSoundSemaphore = nil;

@interface TGOpusAudioRecorder ()
{
    TGDataItem *_tempFileItem;
    
    TGOggOpusWriter *_oggWriter;
    
    NSMutableData *_audioBuffer;
    
    NSString *_liveUploadPath;
    
    
    bool _recording;
    bool _waitForTone;
    NSTimeInterval _waitForToneStart;
    bool _stopped;
    
    NSMutableData *_waveformSamples;
    int16_t _waveformPeak;
    int _waveformPeakCount;
    
    int16_t _micLevelPeak;
    int _micLevelPeakCount;
    
    AudioDeviceID _defaultInputDeviceID;
}

@property (nonatomic) int recorderId;

@end

@implementation TGOpusAudioRecorder

- (instancetype)initWithFileEncryption:(bool)fileEncryption
{
    self = [super init];
    if (self != nil)
    {
        _defaultInputDeviceID = kAudioDeviceUnknown;
        _tempFileItem = [[TGDataItem alloc] initWithTempFile];
        
        _waveformSamples = [[NSMutableData alloc] init];
        
        [[TGOpusAudioRecorder processingQueue] dispatch:^
        {
            static int nextRecorderId = 1;
            _recorderId = nextRecorderId++;
            globalRecorderContext.globalAudioRecorderId = _recorderId;
            
            globalRecorder = self;
            
            static int nextActionId = 0;
            int actionId = nextActionId++;
            _liveUploadPath = [[NSString alloc] initWithFormat:@"/tg/liveUpload/(%d)", actionId];
            
        }];
    }
    return self;
}

- (void)dealloc
{
    
    [self cleanup];
}

+ (ATQueue *)processingQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] initWithName:@"org.telegram.opusAudioRecorderQueue"];
    });
    
    return queue;
}

- (void)cleanup
{
    intptr_t objectId = (intptr_t)self;
    int recorderId = _recorderId;
    
    globalRecorder = nil;
    
    _oggWriter = nil;
    
    [[TGOpusAudioRecorder processingQueue] dispatch:^
    {
        if (globalRecorderContext.globalAudioRecorderId == recorderId)
        {
            globalRecorderContext.globalAudioRecorderId++;
            
            if (globalRecorderContext.audioUnitStarted && globalRecorderContext.audioUnit != NULL)
            {
                OSStatus status = noErr;
                status = AudioOutputUnitStop(globalRecorderContext.audioUnit);
                if (status != noErr)
                    NSLog(@"[TGOpusAudioRecorder%ld AudioOutputUnitStop failed: %d]", objectId, (int)status);
                
                globalRecorderContext.audioUnitStarted = false;
            }
            
            if (globalRecorderContext.audioUnit != NULL)
            {
                OSStatus status = noErr;
                status = AudioComponentInstanceDispose(globalRecorderContext.audioUnit);
                if (status != noErr)
                    NSLog(@"[TGOpusAudioRecorder%ld AudioComponentInstanceDispose failed: %d]", objectId, (int)status);
                
                globalRecorderContext.audioUnit = NULL;
            }
            
            if (globalRecorderContext.playbackUnitStarted && globalRecorderContext.playbackUnit != NULL)
            {
                OSStatus status = noErr;
                status = AudioOutputUnitStop(globalRecorderContext.playbackUnit);
                if (status != noErr)
                    NSLog(@"[TGOpusAudioRecorder%ld playback AudioOutputUnitStop failed: %d]", objectId, (int)status);
                
                globalRecorderContext.playbackUnitStarted = false;
            }
            
            if (globalRecorderContext.playbackUnit != NULL)
            {
                OSStatus status = noErr;
                status = AudioComponentInstanceDispose(globalRecorderContext.playbackUnit);
                if (status != noErr)
                    NSLog(@"[TGOpusAudioRecorder%ld playback AudioComponentInstanceDispose failed: %d]", objectId, (int)status);
                
                globalRecorderContext.playbackUnit = NULL;
            }
        }
    }];
    
    [self _endAudioSession];
}

- (void)_beginAudioSession:(bool)speaker
{
    [[TGOpusAudioRecorder processingQueue] dispatch:^
    {
        NSLog(@"_beginAudioSession completed");
        if (self->_pauseRecording) {
            self->_pauseRecording();
        }
    } synchronous:true];
}

- (void)_endAudioSession
{
    
}

- (void)prepareRecord:(bool)playTone completion:(void (^)())completion
{
    [[TGOpusAudioRecorder processingQueue] dispatch:^
    {
        if (_stopped) {
            if (completion) {
                completion();
            }
            return;
        }
        
        
        OSStatus status = noErr;

        
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_HALOutput;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
        AudioComponentInstanceNew(inputComponent, &globalRecorderContext.audioUnit);
        
        UInt32 one = 1;
        status = AudioUnitSetProperty(globalRecorderContext.audioUnit,
                                         kAudioOutputUnitProperty_EnableIO,
                                         kAudioUnitScope_Input,
                                         kInputBus,
                                         &one,
                                      sizeof(one));
        
        if (status != noErr) {
            NSLog(@"[TGOpusAudioRecorder%@ AudioUnitSetProperty kAudioOutputUnitProperty_EnableIO failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }
        
        UInt32 zero = 0;
        status = AudioUnitSetProperty(globalRecorderContext.audioUnit,
                                         kAudioOutputUnitProperty_EnableIO,
                                         kAudioUnitScope_Output,
                                         kOutputBus,
                                         &zero,
                                         sizeof(UInt32));
        
        if (status != noErr) {
            NSLog(@"[TGOpusAudioRecorder%@ kAudioOutputUnitProperty_EnableIO kAudioUnitScope_Output failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }
        
        if(_defaultInputDeviceID == kAudioDeviceUnknown)
        {
            AudioObjectPropertyAddress propertyAddress;
            propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice;
            propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
            propertyAddress.mElement = kAudioObjectPropertyElementMaster;
            
            AudioDeviceID thisDeviceID;
            UInt32 propsize = sizeof(AudioDeviceID);
            status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &propsize, &thisDeviceID);
            if (status != noErr)
            {
                NSLog(@"[TGOpusAudioRecorder%@ AudioObjectGetPropertyData kAudioObjectSystemObject failed: %d]", self, (int)status);
                [self cleanup];
                return;
            }
            _defaultInputDeviceID = thisDeviceID;
        }
        
        status = AudioUnitSetProperty( globalRecorderContext.audioUnit,
                                         kAudioOutputUnitProperty_CurrentDevice,
                                         kAudioUnitScope_Global,
                                         kOutputBus,
                                         &_defaultInputDeviceID,
                                         sizeof(AudioDeviceID) );
        
        if (status != noErr)
        {
            NSLog(@"[TGOpusAudioRecorder%@ kAudioOutputUnitProperty_CurrentDevice kAudioUnitScope_Global failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }
        
        UInt32 propertySize = sizeof(AudioDeviceID) ;
        AudioObjectPropertyAddress defaultDeviceProperty;
        defaultDeviceProperty.mScope = kAudioObjectPropertyScopeGlobal;
        defaultDeviceProperty.mElement = kAudioObjectPropertyElementMaster;
        defaultDeviceProperty.mSelector = kAudioDevicePropertyAvailableNominalSampleRates;
        
        
        status = AudioObjectGetPropertyDataSize(_defaultInputDeviceID,
                                                        &defaultDeviceProperty,
                                                        0,
                                                        NULL,
                                                        &propertySize);
        
        if (status != noErr)
        {
            NSLog(@"[TGOpusAudioRecorder%@ AudioObjectGetPropertyDataSize _defaultInputDeviceID failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }
        
        int m_valueCount = propertySize / sizeof(AudioValueRange) ;
        
        AudioValueRange m_valueTabe[m_valueCount];
        
        status = AudioObjectGetPropertyData(_defaultInputDeviceID,
                                                  &defaultDeviceProperty,
                                                  0,
                                                  NULL,
                                                  &propertySize,
                                                  m_valueTabe);
        
        if (status != noErr)
        {
            NSLog(@"[TGOpusAudioRecorder%@ AudioObjectGetPropertyData _defaultInputDeviceID failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }
        
        
        Float64 sampleRate = 44100;
        
        for(UInt32 i = 0 ; i < m_valueCount ; ++i)
        {
            if ((int)m_valueTabe[i].mMinimum == TGOpusAudioRecorderSampleRate) {
                sampleRate = m_valueTabe[i].mMinimum;
                break;
            }
        }
        
        AudioValueRange inputSampleRate;
        inputSampleRate.mMinimum = sampleRate;
        inputSampleRate.mMaximum = sampleRate;
        defaultDeviceProperty.mSelector = kAudioDevicePropertyNominalSampleRate;
        status = AudioObjectSetPropertyData(_defaultInputDeviceID,
                                                  &defaultDeviceProperty,
                                                  0,
                                                  NULL,
                                                  sizeof(inputSampleRate),
                                                  &inputSampleRate);
        
        if (status != noErr)
        {
            NSLog(@"[TGOpusAudioRecorder%@ AudioObjectSetPropertyData kAudioDevicePropertyNominalSampleRate failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }

        AudioStreamBasicDescription inputAudioFormat;
        inputAudioFormat.mSampleRate = sampleRate;
        inputAudioFormat.mFormatID = kAudioFormatLinearPCM;
        inputAudioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        inputAudioFormat.mFramesPerPacket = 1;
        inputAudioFormat.mChannelsPerFrame = 1;
        inputAudioFormat.mBitsPerChannel = 16;
        inputAudioFormat.mBytesPerPacket = 2;
        inputAudioFormat.mBytesPerFrame = 2;
        status = AudioUnitSetProperty(globalRecorderContext.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &inputAudioFormat, sizeof(inputAudioFormat));
        
        if (status != noErr) {
            NSLog(@"[TGOpusAudioRecorder%@ AudioUnitSetProperty kAudioUnitProperty_StreamFormat failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }
        
        status = AudioUnitSetProperty(globalRecorderContext.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &inputAudioFormat, sizeof(inputAudioFormat));
        if (status != noErr) {
            NSLog(@"[TGOpusAudioRecorder%@ AudioUnitSetProperty kAudioUnitProperty_StreamFormat failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }
        
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = &TGOpusRecordingCallback;
        callbackStruct.inputProcRefCon = (void *)(intptr_t)_recorderId;
        if (AudioUnitSetProperty(globalRecorderContext.audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, sizeof(callbackStruct)) != noErr) {
            NSLog(@"[TGOpusAudioRecorder%@ AudioUnitSetProperty kAudioOutputUnitProperty_SetInputCallback failed]", self);
            [self cleanup];
            return;
        }
        
        if (AudioUnitSetProperty(globalRecorderContext.audioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, 0, &zero, sizeof(zero)) != noErr)
        {
            NSLog(@"[TGOpusAudioRecorder%@ AudioUnitSetProperty kAudioUnitProperty_ShouldAllocateBuffer failed]", self);
            [self cleanup];
            return;
        }
        
        _oggWriter = [[TGOggOpusWriter alloc] init];
        if (![_oggWriter beginWithDataItem:_tempFileItem])
        {
            NSLog(@"[TGOpusAudioRecorder%@ error initializing ogg opus writer]", self);
            [self cleanup];
            return;
        }
        
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        
        status = AudioUnitInitialize(globalRecorderContext.audioUnit);
        if (status == noErr)
            globalRecorderContext.audioUnitInitialized = true;
        else
        {
            NSLog(@"[TGOpusAudioRecorder%@ AudioUnitInitialize failed: %d]", self, (int)status);
            [self cleanup];
            
            return;
        }
        
        NSLog(@"[TGOpusAudioRecorder%@ setup time: %f ms]", self, (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
        
        status = AudioOutputUnitStart(globalRecorderContext.audioUnit);
        if (status == noErr)
        {
            NSLog(@"[TGOpusAudioRecorder%@ initialization time: %f ms]", self, (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
            NSLog(@"[TGOpusAudioRecorder%@ started]", self);
            globalRecorderContext.audioUnitStarted = true;
        }
        else
        {
            NSLog(@"[TGOpusAudioRecorder%@ AudioOutputUnitStart failed: %d]", self, (int)status);
            [self cleanup];
            return;
        }
        
        
        if (playTone) {
            [self loadToneBuffer];
            _waitForTone = true;
            toneAudioOffset = 0;
            
            AudioComponentDescription desc;
            desc.componentType = kAudioUnitType_Output;
            desc.componentSubType = kAudioUnitSubType_HALOutput;
            desc.componentFlags = 0;
            desc.componentFlagsMask = 0;
            desc.componentManufacturer = kAudioUnitManufacturer_Apple;
            AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
            AudioComponentInstanceNew(inputComponent, &globalRecorderContext.playbackUnit);
            
            OSStatus status = noErr;
            
            static const UInt32 one = 1;
            status = AudioUnitSetProperty(globalRecorderContext.playbackUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &one, sizeof(one));
            if (status != noErr)
            {
                NSLog(@"[TGOpusAudioPlayer#%@ AudioUnitSetProperty kAudioOutputUnitProperty_EnableIO failed: %d]", self, (int)status);
                [self cleanup];
                
                return;
            }
            
            AudioStreamBasicDescription outputAudioFormat;
            outputAudioFormat.mSampleRate = sampleRate;
            outputAudioFormat.mFormatID = kAudioFormatLinearPCM;
            outputAudioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
            outputAudioFormat.mFramesPerPacket = 1;
            outputAudioFormat.mChannelsPerFrame = 1;
            outputAudioFormat.mBitsPerChannel = 16;
            outputAudioFormat.mBytesPerPacket = 2;
            outputAudioFormat.mBytesPerFrame = 2;
            status = AudioUnitSetProperty(globalRecorderContext.playbackUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &outputAudioFormat, sizeof(outputAudioFormat));
            if (status != noErr)
            {
                NSLog(@"[TGOpusAudioPlayer#%@ playback AudioUnitSetProperty kAudioUnitProperty_StreamFormat failed: %d]", self, (int)status);
                [self cleanup];
                
                return;
            }
            
            AURenderCallbackStruct callbackStruct;
            callbackStruct.inputProc = &TGOpusAudioPlayerCallback;
            callbackStruct.inputProcRefCon = (void *)(intptr_t)_recorderId;
            if (AudioUnitSetProperty(globalRecorderContext.playbackUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus, &callbackStruct, sizeof(callbackStruct)) != noErr)
            {
                NSLog(@"[TGOpusAudioPlayer#%@ playback AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback failed]", self);
                [self cleanup];
                
                return;
            }
            
            status = AudioUnitInitialize(globalRecorderContext.playbackUnit);
            if (status == noErr)
            {
                status = AudioOutputUnitStart(globalRecorderContext.playbackUnit);
                if (status != noErr)
                {
                    NSLog(@"[TGOpusAudioRecorder#%@ playback AudioOutputUnitStart failed: %d]", self, (int)status);
                }
            } else {
                NSLog(@"[TGOpusAudioRecorder#%@ playback AudioUnitInitialize failed: %d]", self, (int)status);
                [self cleanup];
            }
            
            _waitForToneStart = CACurrentMediaTime();
        }
        
        if (completion) {
            completion();
        }
        
    }];
        
}

- (void)record {
    _recording = true;
}

static OSStatus TGOpusAudioPlayerCallback(void *inRefCon, __unused AudioUnitRenderActionFlags *ioActionFlags, __unused const AudioTimeStamp *inTimeStamp, __unused UInt32 inBusNumber, __unused UInt32 inNumberFrames, AudioBufferList *ioData)
{
    if (globalRecorderContext.globalAudioRecorderId != (int)inRefCon)
        return noErr;
    
    for (int i = 0; i < (int)ioData->mNumberBuffers; i++)
    {
        AudioBuffer *buffer = &ioData->mBuffers[i];
        buffer->mNumberChannels = 1;
        
        int audioBytesToCopy = MAX(0, MIN((int)buffer->mDataByteSize, ((int)toneAudioBuffer.length) - (int)toneAudioOffset));
        if (audioBytesToCopy != 0) {
            memcpy(buffer->mData, toneAudioBuffer.bytes + (int)toneAudioOffset, audioBytesToCopy);
            toneAudioOffset += audioBytesToCopy;
        }
        
        int remainingBytes = ((int)buffer->mDataByteSize) - audioBytesToCopy;
        if (remainingBytes > 0) {
            memset(buffer->mData + buffer->mDataByteSize - remainingBytes, 0, remainingBytes);
        }
    }
    
    return noErr;
}


static OSStatus TGOpusRecordingCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, __unused AudioBufferList *ioData)
{
    @autoreleasepool
    {
        if (globalRecorderContext.globalAudioRecorderId != (int)inRefCon)
            return noErr;
        
        AudioBuffer buffer;
        buffer.mNumberChannels = 1;
        buffer.mDataByteSize = inNumberFrames * 2;
        buffer.mData = malloc(inNumberFrames * 2);
        
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0] = buffer;
        OSStatus status = AudioUnitRender(globalRecorderContext.audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
        if (status == noErr)
        {
            [[TGOpusAudioRecorder processingQueue] dispatch:^
             {
                 TGOpusAudioRecorder *recorder = globalRecorder;
                 if (recorder != nil && recorder.recorderId == (int)(intptr_t)inRefCon && recorder->_recording) {
                     
                     if (recorder->_waitForTone) {
                         if (CACurrentMediaTime() - recorder->_waitForToneStart > 0.3) {
                             [recorder _processBuffer:&buffer];
                         }
                     } else {
                         [recorder _processBuffer:&buffer];
                     }
                 }
                 
                 free(buffer.mData);
             }];
        }
    }
    
    return noErr;
}

- (void)processWaveformPreview:(int16_t const *)samples count:(int)count {
    for (int i = 0; i < count; i++) {
        int16_t sample = samples[i];
        if (sample < 0) {
            sample = -sample;
        }
        
        if (_waveformPeak < sample) {
            _waveformPeak = sample;
        }
        _waveformPeakCount++;
        
        if (_waveformPeakCount >= 100) {
            [_waveformSamples appendBytes:&_waveformPeak length:2];
            _waveformPeak = 0;
            _waveformPeakCount = 0;
        }
        
        if (_micLevelPeak < sample) {
            _micLevelPeak = sample;
        }
        _micLevelPeakCount++;
        
        if (_micLevelPeakCount >= 1200) {
            if (_micLevel) {
                CGFloat level = (CGFloat)_micLevelPeak / 4000.0;
                _micLevel(level);
            }
            _micLevelPeak = 0;
            _micLevelPeakCount = 0;
        }
    }
}

- (void)_processBuffer:(AudioBuffer const *)buffer
{
    @autoreleasepool
    {
        if (_oggWriter == nil)
            return;
        
        static const int millisecondsPerPacket = 60;
        static const int encoderPacketSizeInBytes = 16000 / 1000 * millisecondsPerPacket * 2;
        
        unsigned char currentEncoderPacket[encoderPacketSizeInBytes];
        
        int bufferOffset = 0;
        
        while (true)
        {
            int currentEncoderPacketSize = 0;
            
            while (currentEncoderPacketSize < encoderPacketSizeInBytes)
            {
                if (_audioBuffer.length != 0)
                {
                    int takenBytes = MIN((int)_audioBuffer.length, encoderPacketSizeInBytes - currentEncoderPacketSize);
                    if (takenBytes != 0)
                    {
                        memcpy(currentEncoderPacket + currentEncoderPacketSize, _audioBuffer.bytes, takenBytes);
                        [_audioBuffer replaceBytesInRange:NSMakeRange(0, takenBytes) withBytes:NULL length:0];
                        currentEncoderPacketSize += takenBytes;
                    }
                }
                else if (bufferOffset < (int)buffer->mDataByteSize)
                {
                    int takenBytes = MIN((int)buffer->mDataByteSize - bufferOffset, encoderPacketSizeInBytes - currentEncoderPacketSize);
                    if (takenBytes != 0)
                    {
                        memcpy(currentEncoderPacket + currentEncoderPacketSize, ((const char *)buffer->mData) + bufferOffset, takenBytes);
                        bufferOffset += takenBytes;
                        currentEncoderPacketSize += takenBytes;
                    }
                }
                else
                    break;
            }
            
            if (currentEncoderPacketSize < encoderPacketSizeInBytes)
            {
                if (_audioBuffer == nil)
                    _audioBuffer = [[NSMutableData alloc] initWithCapacity:encoderPacketSizeInBytes];
                [_audioBuffer appendBytes:currentEncoderPacket length:currentEncoderPacketSize];
                
                break;
            }
            else
            {
                NSUInteger previousBytesWritten = [_oggWriter encodedBytes];
                [self processWaveformPreview:(int16_t const *)currentEncoderPacket count:currentEncoderPacketSize / 2];
                [_oggWriter writeFrame:currentEncoderPacket frameByteCount:(NSUInteger)currentEncoderPacketSize];
                NSUInteger currentBytesWritten = [_oggWriter encodedBytes];
                if (currentBytesWritten != previousBytesWritten)
                {
                    // update live data
                }
            }
        }
    }
}

- (TGDataItem *)stopRecording:(NSTimeInterval *)recordedDuration waveform:(__autoreleasing TGAudioWaveform **)waveform
{
    _stopped = true;
    __block TGDataItem *dataItemResult = nil;
    __block NSTimeInterval durationResult = 0.0;
    
    __block NSUInteger totalBytes = 0;
    
    [[TGOpusAudioRecorder processingQueue] dispatch:^
    {
        if (_oggWriter != nil && [_oggWriter writeFrame:NULL frameByteCount:0])
        {
            dataItemResult = _tempFileItem;
            durationResult = [_oggWriter encodedDuration];
            totalBytes = [_oggWriter encodedBytes];
        }
        
        [self cleanup];
    } synchronous:true];
    
    int16_t scaledSamples[100];
    memset(scaledSamples, 0, 100 * 2);
    int16_t *samples = _waveformSamples.mutableBytes;
    int count = (int)_waveformSamples.length / 2;
    for (int i = 0; i < count; i++) {
        int16_t sample = samples[i];
        int index = i * 100 / count;
        if (scaledSamples[index] < sample) {
            scaledSamples[index] = sample;
        }
    }
    
    int16_t peak = 0;
    int64_t sumSamples = 0;
    for (int i = 0; i < 100; i++) {
        int16_t sample = scaledSamples[i];
        if (peak < sample) {
            peak = sample;
        }
        sumSamples += peak;
    }
    uint16_t calculatedPeak = 0;
    calculatedPeak = (uint16_t)(sumSamples * 1.8f / 100);
    
    if (calculatedPeak < 2500) {
        calculatedPeak = 2500;
    }
    
    for (int i = 0; i < 100; i++) {
        uint16_t sample = (uint16_t)((int64_t)samples[i]);
        if (sample > calculatedPeak) {
            scaledSamples[i] = calculatedPeak;
        }
    }
    
    TGAudioWaveform *resultWaveform = [[TGAudioWaveform alloc] initWithSamples:[NSData dataWithBytes:scaledSamples length:100 * 2] peak:calculatedPeak];
    NSData *bitstream = [resultWaveform bitstream];
    resultWaveform = [[TGAudioWaveform alloc] initWithBitstream:bitstream bitsPerSample:5];
    
    if (recordedDuration != NULL)
        *recordedDuration = durationResult;
    
    if (waveform != NULL) {
        *waveform = resultWaveform;
    }
    
//    if (liveData != NULL)
//    {
//        dispatch_sync([ActionStageInstance() globalStageDispatchQueue], ^
//        {
//            TGLiveUploadActor *actor = (TGLiveUploadActor *)[ActionStageInstance() executingActorWithPath:_liveUploadPath];
//            *liveData = [actor finishRestOfFile:totalBytes];
//        });
//    }
    
    return dataItemResult;
}

- (NSTimeInterval)currentDuration
{
    return [_oggWriter encodedDuration];
}

- (void)loadToneBuffer {
    if (toneAudioBuffer != nil) {
        return;
    }
    
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:48000.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    nil];
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[[NSBundle mainBundle] URLForResource:@"begin_record" withExtension: @"caf"] options:nil];
    if (asset == nil) {
        NSLog(@"asset is not defined!");
        return;
    }
    
    NSError *assetError = nil;
    AVAssetReader *iPodAssetReader = [AVAssetReader assetReaderWithAsset:asset error:&assetError];
    if (assetError) {
        NSLog (@"error: %@", assetError);
        return;
    }
    
    AVAssetReaderOutput *readerOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings:outputSettings];
    
    if (! [iPodAssetReader canAddOutput: readerOutput]) {
        NSLog (@"can't add reader output... die!");
        return;
    }
    
    // add output reader to reader
    [iPodAssetReader addOutput: readerOutput];
    
    if (! [iPodAssetReader startReading]) {
        NSLog(@"Unable to start reading!");
        return;
    }
    
    NSMutableData *data = [[NSMutableData alloc] init];
    while (iPodAssetReader.status == AVAssetReaderStatusReading) {
        // Check if the available buffer space is enough to hold at least one cycle of the sample data
        CMSampleBufferRef nextBuffer = [readerOutput copyNextSampleBuffer];
        
        if (nextBuffer) {
            AudioBufferList abl;
            CMBlockBufferRef blockBuffer = NULL;
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, NULL, &abl, sizeof(abl), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
            UInt64 size = CMSampleBufferGetTotalSampleSize(nextBuffer);
            if (size != 0) {
                [data appendBytes:abl.mBuffers[0].mData length:size];
            }
            
            CFRelease(nextBuffer);
            if (blockBuffer) {
                CFRelease(blockBuffer);
            }
        }
        else {
            break;
        }
    }
    
    toneAudioBuffer = data;
}

@end
