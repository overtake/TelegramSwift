//
//  RLottie.m
//  Telegram
//
//  Created by Mikhail Filimonov on 15/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "RLottieBridge.h"
#import <Accelerate/Accelerate.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>
//#include <unistd.h>
#include "rlottie.h"
#import <AppKit/AppKit.h>

@interface RLottieBridge ()
{
    std::unique_ptr<rlottie::Animation> player;
}
@end

@implementation RLottieBridge

-(id __nullable)initWithJson:(NSString *)string key:(NSString *)cachedKey {
    if (self = [super init]) {
        std::string json = std::string([string UTF8String]);
        std::string key = std::string([cachedKey UTF8String]);
        self->player = rlottie::Animation::loadFromData(json, key);
        
        if (self->player == nullptr) {
            return nil;
        }

        
       // self->animationBuffer = std::unique_ptr<uint32_t[]>(new uint32_t[w * h]);
       // self->surface =
        
        //self->surface = rlottie::Surface
    }
    return self;
}

-(void)dealloc {
    player.reset();
}

-(int)startFrame {
    return 0;
}
-(int)endFrame {
    return self->player->totalFrame();
}
-(int)fps {
    return self->player->frameRate();
}

-(CGImageRef)renderFrame:(int)frame width:(size_t)w height:(size_t)h {
    
    auto animationBuffer = std::unique_ptr<uint32_t[]>(new uint32_t[w * h]);
    rlottie::Surface surface(animationBuffer.get(), w, h, w * 4);
    player->renderSync(frame, surface);

    NSMutableData *data = [[NSMutableData alloc] initWithLength:w * h * 4];
    memset((uint8_t *)data.bytes + w * h * 4, 255, w * h);

    vImage_Buffer inputBuffer;
    inputBuffer.width = w;
    inputBuffer.height = h;
    inputBuffer.rowBytes = w * 4;
    inputBuffer.data = (uint8_t *)data.bytes;
    memcpy(inputBuffer.data, (void *)animationBuffer.get(), w * h * 4);

    const uint8_t map[4] = { 3, 2, 1, 0 };
   // vImagePermuteChannels_ARGB8888(&inputBuffer, &inputBuffer, map, kvImageNoFlags);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_11_2)
        colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);

    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef image = CGImageCreate(w, h, 8, 32, w * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, dataProvider, NULL, false, kCGRenderingIntentDefault);
    CFRelease(dataProvider);
    CFRelease(colorSpace);
    animationBuffer.reset();
    return image;
    
}


-(CMSampleBufferRef)renderSampleBufferFrame:(int)frame timebase:(CMTimebaseRef)timebase  width:(size_t)w height:(size_t)h fps:(size_t)fps {
    
//    NSMutableDictionary *ioSurfaceProperties = [NSMutableDictionary dictionary];
//    [ioSurfaceProperties setValue:@(YES) forKey:@"IOSurfaceIsGlobal"];
//
//    NSMutableDictionary *options = [NSMutableDictionary dictionary];
//
//    [options setValue:ioSurfaceProperties forKey:(NSString *)kCVPixelBufferIOSurfacePropertiesKey];
////(__bridge CFDictionaryRef)options
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32ARGB, NULL, &pixelBuffer);


    auto animationBuffer = std::unique_ptr<uint32_t[]>(new uint32_t[w * h]);
    rlottie::Surface surface(animationBuffer.get(), w, h, w * 4);
    player->renderSync(frame, surface);
    
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    void *base = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    vImage_Buffer inputBuffer;
    inputBuffer.width = w;
    inputBuffer.height = h;
    inputBuffer.rowBytes = w * 4;
    inputBuffer.data = (void *)animationBuffer.get();
    
    const uint8_t map[4] = { 3, 2, 1, 0 };
    vImagePermuteChannels_ARGB8888(&inputBuffer, &inputBuffer, map, kvImageNoFlags);
    
    memcpy(base, inputBuffer.data, w * h * 4);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    
    CMTime currentTime = CMTimebaseGetTime(timebase);
    
    CMSampleTimingInfo info = CMSampleTimingInfo();
    info.duration = CMTimeMake(1 / fps, currentTime.timescale);
    info.presentationTimeStamp = CMTimeAdd(CMTimeMake((1 / fps) * frame, currentTime.timescale), currentTime); //CMTimeMake((1 / 30) * frame, currentTime.timescale);
    
    CMFormatDescriptionRef formatDesc;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &formatDesc);
    
    
    CMSampleBufferRef sampleBuffer;
    CMSampleBufferCreateReadyWithImageBuffer(NULL, pixelBuffer, formatDesc, &info, &sampleBuffer);
    
    
    CFRelease(formatDesc);
    CFRelease(pixelBuffer);
    animationBuffer.reset();
    return sampleBuffer;
}


-(CVPixelBufferRef)renderPixelBufferFrame:(int)frame  width:(size_t)w height:(size_t)h {
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    
  //  [options setValue:(NSString *)kCVImageBufferChromaSubsampling_420 forKey:(NSString *)kCVImageBufferChromaSubsamplingKey];

    size_t width = w;//MAX(320, w);
    size_t height = h;//MAX(320, h);

    CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pixelBuffer);
    
    auto animationBuffer = std::unique_ptr<uint32_t[]>(new uint32_t[width * height]);
    rlottie::Surface surface(animationBuffer.get(), width, height, width * 4);
    player->renderSync(frame, surface);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    void *base = CVPixelBufferGetBaseAddress(pixelBuffer);
    
//    NSMutableDictionary *ioSurfaceProperties = [NSMutableDictionary dictionary];
//    [ioSurfaceProperties setValue:@(YES) forKey:@"IOSurfaceIsGlobal"];
//
//
//    vImage_Buffer inputBuffer;
//    inputBuffer.width = width;
//    inputBuffer.height = height;
//    inputBuffer.rowBytes = width * 4;
//    inputBuffer.data = (void *)animationBuffer.get();
//
//
//    size_t scaledBytesPerRow = w * 4;
//    void *scaledData = malloc(w * scaledBytesPerRow);
//    vImage_Buffer scaledvImageBuffer = {
//        .data = scaledData,
//        .height = (vImagePixelCount)w,
//        .width = (vImagePixelCount)h,
//        .rowBytes = w * 4
//    };
//
//    vImageScale_ARGB8888(&inputBuffer, &scaledvImageBuffer, nil, 0);
//
    memcpy(base, animationBuffer.get(), w * h * 4);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
    animationBuffer.reset();
    return pixelBuffer;
}

//    //
//    const uint8_t map[4] = { 0, 1, 2, 3 };
//    vImagePermuteChannels_ARGB8888(&inputBuffer, &inputBuffer, map, kvImageNoFlags);
//vImagePremultiplyData_ARGB8888(&inputBuffer, &inputBuffer, kvImageNoFlags);
//func vImagePremultiplyData_ARGB8888(UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags)


-(NSData *)renderDataFrame:(int)frame  width:(size_t)w height:(size_t)h {
    auto animationBuffer = std::unique_ptr<uint32_t[]>(new uint32_t[w * h]);
    rlottie::Surface surface(animationBuffer.get(), w, h, w * 4);
    player->renderSync(frame, surface);
    NSData *data = [[NSData alloc] init];
    memcpy(animationBuffer.get(), data.bytes, w * h * 4);
    animationBuffer.reset();
    return data;
}

- (void)renderFrameWithIndex:(int32_t)index into:(uint8_t * _Nonnull)buffer width:(int32_t)width height:(int32_t)height {
    rlottie::Surface surface((uint32_t *)buffer, width, height, width * 4);
    player->renderSync(index, surface);
}

@end





//vImageUnpremultiplyData_ARGB8888(&inputBuffer, &inputBuffer, kvImageNoFlags);
// CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
//CVPixelBufferLockBaseAddress(pixelBuffer, 0);
//vImageBuffer_CopyToCVPixelBuffer(&inputBuffer, &format, pixelBuffer, NULL, NULL, kvImageNoFlags);
//    var timebase:CMTimebase? = nil
//    CMTimebaseCreateWithMasterClock( allocator: kCFAllocatorDefault, masterClock: CMClockGetHostTimeClock(), timebaseOut: &timebase )
//    CMTimebaseSetRate(timebase!, rate: 1.0)
