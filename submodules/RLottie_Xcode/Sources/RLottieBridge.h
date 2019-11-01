//
//  RLottie.h
//  Telegram
//
//  Created by Mikhail Filimonov on 15/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface RLottieBridge : NSObject
-(id __nullable)initWithJson:(NSString *)string key:(NSString *)cachedKey;
-(CGImageRef)renderFrame:(int)frame width:(size_t)w height:(size_t)h;
-(CMSampleBufferRef)renderSampleBufferFrame:(int)frame timebase:(CMTimebaseRef)timebase  width:(size_t)w height:(size_t)h fps:(size_t)fps;
-(CVPixelBufferRef)renderPixelBufferFrame:(int)frame  width:(size_t)w height:(size_t)h;
-(NSData *)renderDataFrame:(int)frame  width:(size_t)w height:(size_t)h ;
-(void)renderFrameWithIndex:(int32_t)index into:(uint8_t * _Nonnull)buffer width:(int32_t)width height:(int32_t)height;
-(int)startFrame;
-(int)endFrame;
-(int)fps;
@end

NS_ASSUME_NONNULL_END
