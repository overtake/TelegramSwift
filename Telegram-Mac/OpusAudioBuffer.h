#import <Foundation/Foundation.h>

struct OpusAudioBuffer
{
    NSUInteger capacity;
    uint8_t *data;
    NSUInteger size;
    int64_t pcmOffset;
};

inline OpusAudioBuffer *OpusAudioBufferWithCapacity(NSUInteger capacity)
{
    OpusAudioBuffer *audioBuffer = (OpusAudioBuffer *)malloc(sizeof(OpusAudioBuffer));
    audioBuffer->capacity = capacity;
    audioBuffer->data = (uint8_t *)malloc(capacity);
    audioBuffer->size = 0;
    audioBuffer->pcmOffset = 0;
    return audioBuffer;
}

inline void OpusAudioBufferDispose(OpusAudioBuffer *audioBuffer)
{
    if (audioBuffer != NULL)
    {
        free(audioBuffer->data);
        free(audioBuffer);
    }
}
