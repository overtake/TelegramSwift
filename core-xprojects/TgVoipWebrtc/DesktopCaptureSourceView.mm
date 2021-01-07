//
//  DesktopCaptureSourceView.m
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 28.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import "DesktopCaptureSourceView.h"
#import "platform/darwin/VideoMetalViewMac.h"

@interface DesktopCaptureSourceView ()
@property (nonatomic, strong) DesktopCaptureSourceHelper *helper;
@end

@implementation DesktopCaptureSourceView

-(id)initWithHelper:(DesktopCaptureSourceHelper *)helper {
    if (self = [super initWithFrame:CGRectZero]) {
        _helper = helper;
        std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [self getSink];
        [helper setOutput:sink];
        [self setVideoContentMode:kCAGravityResizeAspectFill];
    }
    return self;
}

@end
