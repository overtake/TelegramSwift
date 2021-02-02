//
//  DesktopCaptureSource.h
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol VideoSource
-(NSString *)deviceIdKey;
-(NSString *)title;
-(NSString *)uniqueKey;
-(BOOL)isEqual:(id)another;
@end

@interface DesktopCaptureSourceData : NSObject
@property CGSize aspectSize;
@property double fps;
@property bool captureMouse;
-(id)initWithSize:(CGSize)size fps:(double)fps captureMouse:(bool)captureMouse;

-(NSString *)cachedKey;
@end

@interface DesktopCaptureSource : NSObject<VideoSource>
-(long)uniqueId;
-(BOOL)isWindow;
@end


@interface DesktopCaptureSourceScope : NSObject
@property(nonatomic, strong, readonly) DesktopCaptureSourceData *data;
@property(nonatomic, strong, readonly) DesktopCaptureSource *source;
-(id)initWithSource:(DesktopCaptureSource *)source data:(DesktopCaptureSourceData *)data;

-(NSString *)cachedKey;

@end

NS_ASSUME_NONNULL_END
