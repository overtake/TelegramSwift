//
//  Capturer.h
//  CoreMediaMacCapture
//
//  Created by Mikhail Filimonov on 21.06.2021.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
NS_ASSUME_NONNULL_BEGIN


typedef void(^renderBlock)(CMSampleBufferRef);


@interface CoreMediaCapturer : NSObject


-(id)initWithDeviceId:(NSString *)deviceId;

-(void)start:(renderBlock)renderBlock;
-(void)stop;



@end

NS_ASSUME_NONNULL_END
