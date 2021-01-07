//
//  DesktopCaptureSource.h
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface DesktopCaptureSourceData : NSObject
@property CGSize aspectSize;
@property int fps;
-(id)initWithSize:(CGSize)size fps:(int)fps;

-(NSString *)cachedKey;
@end

@interface DesktopCaptureSource : NSObject
-(NSString *)title;
-(long)uniqueId;
-(BOOL)isWindow;
-(NSString *)uniqueKey;
@end


@interface DesktopCaptureSourceScope : NSObject
@property(nonatomic, strong, readonly) DesktopCaptureSourceData *data;
@property(nonatomic, strong, readonly) DesktopCaptureSource *source;
-(id)initWithSource:(DesktopCaptureSource *)source data:(DesktopCaptureSourceData *)data;

-(NSString *)cachedKey;

@end

NS_ASSUME_NONNULL_END
