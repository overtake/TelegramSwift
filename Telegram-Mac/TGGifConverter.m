//
//  TGGifConverter.m
//  Telegram
//
//  Created by keepcoder on 15/12/15.
//  Copyright © 2015 keepcoder. All rights reserved.
//

#import "TGGifConverter.h"

#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>

static const int32_t FPS = 600;

@implementation TGGifConverter

+(void)convertGifToMp4:(NSData *)data exportPath:(NSString *)exportPath completionHandler:(void (^)(NSString *path))completionHandler errorHandler:(dispatch_block_t)errorHandler cancelHandler:(BOOL (^)())cancelHandler {
    
    
    [NSFileManager.defaultManager removeItemAtPath:exportPath error:nil];
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    unsigned char *bytes = (unsigned char *)data.bytes;
    NSError* error = nil;
    
    if (!(CGImageSourceGetStatus(source) == kCGImageStatusComplete)) {
        CFRelease(source);
        if(errorHandler != nil) {
            errorHandler();
        }
        return;
    }
    
    size_t sourceWidth = bytes[6] + (bytes[7]<<8), sourceHeight = bytes[8] + (bytes[9]<<8);
    //size_t sourceFrameCount = CGImageSourceGetCount(source);
    __block size_t currentFrameNumber = 0;
    __block Float64 totalFrameDelay = 0.f;
    
    if (sourceWidth <= 0 || sourceHeight <= 0) {
        if(errorHandler != nil) {
            errorHandler();
        }
        return;
    }
    
    NSURL *outFilePath = [NSURL fileURLWithPath:exportPath];
    
    AVAssetWriter* videoWriter = [[AVAssetWriter alloc] initWithURL: outFilePath
                                                           fileType: AVFileTypeMPEG4
                                                              error: &error];
    
    videoWriter.shouldOptimizeForNetworkUse = YES;
    
    if (error) {
        CFRelease(source);
        if(errorHandler != nil) {
            errorHandler();
        }
        return;
    }
    
    
    size_t totalFrameCount = CGImageSourceGetCount(source);
    
    if (totalFrameCount <= 0) {
        CFRelease(source);
        if(errorHandler != nil) {
            errorHandler();
        }
        return;
    }
    
    NSDictionary *videoSettings = @{AVVideoCodecKey : AVVideoCodecH264,
                                    AVVideoWidthKey : @(sourceWidth),
                                    AVVideoHeightKey : @(sourceHeight),
                                    AVVideoCompressionPropertiesKey:@
                                        {
                                        AVVideoAverageBitRateKey: @512000,
                                        AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
                                        }
                                    };
    
    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType: AVMediaTypeVideo
                                                                              outputSettings: videoSettings];
    videoWriterInput.expectsMediaDataInRealTime = YES;
    
    if (![videoWriter canAddInput: videoWriterInput]) {
        
    }
    [videoWriter addInput: videoWriterInput];
    
    NSDictionary* attributes = @{
                                 (NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32ARGB),
                                 (NSString*)kCVPixelBufferWidthKey : @(sourceWidth),
                                 (NSString*)kCVPixelBufferHeightKey : @(sourceHeight),
                                 (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
                                 (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES
                                 };
    
    AVAssetWriterInputPixelBufferAdaptor* adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput: videoWriterInput sourcePixelBufferAttributes: attributes];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime: CMTimeMakeWithSeconds(totalFrameDelay, FPS)];
    
    BOOL addedLastFrame = NO;
    BOOL needAddSecondaryLastFrame = NO;
    
    while (!cancelHandler()) {
        if(videoWriterInput.isReadyForMoreMediaData) {
            NSDictionary* options = @{(NSString*)kCGImageSourceTypeIdentifierHint : (id)kUTTypeGIF};
            CGImageRef imgRef = CGImageSourceCreateImageAtIndex(source, currentFrameNumber, (__bridge CFDictionaryRef)options);
            
            if (imgRef) {
                CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, currentFrameNumber, NULL);
                CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
                
                if( gifProperties ) {
                    CVPixelBufferRef pxBuffer = [self newBufferFrom: imgRef
                                                withPixelBufferPool: adaptor.pixelBufferPool
                                                      andAttributes: adaptor.sourcePixelBufferAttributes];
                    if( pxBuffer) {
                        
                        float delayTime = [self frameDurationAtIndex:currentFrameNumber source:source];
                       
                        CMTime time = CMTimeMakeWithSeconds(totalFrameDelay, FPS);
                        

                       if( ![adaptor appendPixelBuffer: pxBuffer withPresentationTime: time] ) {
                            CFRelease(properties);
                            CGImageRelease(imgRef);
                            CVBufferRelease(pxBuffer);
                            break;
                        }
                        
                        
                        
                        if(currentFrameNumber == totalFrameCount-1 && delayTime > 0.33) {
                            needAddSecondaryLastFrame = YES;
                        }
                        
                       
                        
                        totalFrameDelay += delayTime;
                                               
                        
                        CVBufferRelease(pxBuffer);
                    }
                }
                
                if( properties ) CFRelease(properties);
                CGImageRelease(imgRef);
                
                currentFrameNumber++;
                
                if(needAddSecondaryLastFrame && !addedLastFrame && currentFrameNumber == totalFrameCount) {
                    currentFrameNumber--;
                    addedLastFrame = YES;
                }
                
                
            }
            else {
                [videoWriterInput markAsFinished];
                
                void (^videoSaveFinished)(void) = ^{
                    if(completionHandler != nil) {
                        completionHandler([outFilePath path]);
                    }
                };
                
                [videoWriter finishWritingWithCompletionHandler:videoSaveFinished];
                break;
            }
        }
        else {
            [NSThread sleepForTimeInterval:0.1];
        }
    };
    
    CFRelease(source);

};

+ (float)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source
{
    float frameDuration = 0.1f;
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source,index,nil);
    NSDictionary *frameProperties = (__bridge NSDictionary*)cfFrameProperties;
    NSDictionary *gifProperties = frameProperties[(NSString*)kCGImagePropertyGIFDictionary];
    
    NSNumber *delayTimeUnclampedProp = gifProperties[(NSString*)kCGImagePropertyGIFUnclampedDelayTime];
    if(delayTimeUnclampedProp) {
        frameDuration = [delayTimeUnclampedProp floatValue];
    } else {
        
        NSNumber *delayTimeProp = gifProperties[(NSString*)kCGImagePropertyGIFDelayTime];
        if(delayTimeProp) {
            frameDuration = [delayTimeProp floatValue];
        }
    }
    
    
    if (frameDuration < 0.011f)
        frameDuration = 0.100f;
    
    CFRelease(cfFrameProperties);
    return frameDuration;
}

+ (CVPixelBufferRef) newBufferFrom: (CGImageRef) frame
               withPixelBufferPool: (CVPixelBufferPoolRef) pixelBufferPool
                     andAttributes: (NSDictionary*) attributes {
    NSParameterAssert(frame);
    
    size_t width = CGImageGetWidth(frame);
    size_t height = CGImageGetHeight(frame);
    size_t bpc = 8;
    CGColorSpaceRef colorSpace =  CGColorSpaceCreateDeviceRGB();
    
    CVPixelBufferRef pxBuffer = NULL;
    CVReturn status = kCVReturnSuccess;
    
    if( pixelBufferPool )
        status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pxBuffer);
    else {
        status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)attributes, &pxBuffer);
    }
    
    NSAssert(status == kCVReturnSuccess, @"Could not create a pixel buffer");
    
    CVPixelBufferLockBaseAddress(pxBuffer, 0);
    void *pxData = CVPixelBufferGetBaseAddress(pxBuffer);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pxBuffer);
    
    
    CGContextRef context = CGBitmapContextCreate(pxData,
                                                 width,
                                                 height,
                                                 bpc,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSAssert(context, @"Could not create a context");
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), frame);
    
    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return pxBuffer;
}

+(NSSize)gifDimensionSize:(NSString *)path {
    
    NSSize size = NSMakeSize(0, 0);
    
    NSInputStream *stream = [[NSInputStream alloc] initWithURL:[NSURL fileURLWithPath:path]];
    
    [stream open];
    
    uint8_t *buffer = (uint8_t *)malloc(3);
    NSUInteger length = [stream read:buffer maxLength:3]; // header
    
    NSData *headerData = [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES];
    
    
    NSString *g = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
    
    if([g isEqualToString:@"GIF"]) {
        [stream read:buffer maxLength:3]; // skip gif version
        
        
        
        unsigned short width = 0;
        unsigned short height = 0;
        
        uint8_t wb[2];
        length = [stream read:wb maxLength:2];
        if(length > 0) {
            memcpy(&width, wb, 2);
        }
        
        uint8_t hb[2];
        length = [stream read:hb maxLength:2];
        if(length > 0) {
            memcpy(&height, hb, 2);
        }
        
        
        size = NSMakeSize(width, height);

    }
    
    [stream close];
    
    
    
    return size;
}

@end
