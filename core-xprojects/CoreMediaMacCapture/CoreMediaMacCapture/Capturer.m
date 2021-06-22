//
//  Capturer.m
//  CoreMediaMacCapture
//
//  Created by Mikhail Filimonov on 21.06.2021.
//

#import "Capturer.h"
#import "CoreMediaVideoHAL.h"

@interface CoreMediaCapturer ()

@end

@implementation CoreMediaCapturer
{
    NSString * _deviceId;
    Device * _device;
}
-(id)initWithDeviceId:(NSString *)deviceId {
    if (self = [super init]) {
        _deviceId = deviceId;
        
    }
    return self;
}

-(void)start:(renderBlock)renderBlock {
    _device = [Device FindDeviceByUniqueId:_deviceId];
   
    [_device run:^(CMSampleBufferRef sampleBuffer) {
        renderBlock(sampleBuffer);
    }];
    
    
}
-(void)stop {
    [_device stop];
}

-(void)dealloc {
    
}

@end
