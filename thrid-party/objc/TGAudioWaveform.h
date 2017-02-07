#import <Foundation/Foundation.h>

@interface TGAudioWaveform : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData *samples;
@property (nonatomic, readonly) int32_t peak;

- (instancetype)initWithSamples:(NSData *)samples peak:(int32_t)peak;
- (instancetype)initWithBitstream:(NSData *)bitstream bitsPerSample:(NSUInteger)bitsPerSample;

- (NSData *)bitstream;
- (uint16_t *)sampleList;

@end
