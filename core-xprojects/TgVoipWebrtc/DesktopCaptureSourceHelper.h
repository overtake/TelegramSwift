//
//  DesktopCaptureSourceHelper.h
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 28.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "api/video/video_sink_interface.h"
#import "api/media_stream_interface.h"
#import "rtc_base/time_utils.h"

#import "api/video/video_sink_interface.h"
#import "api/media_stream_interface.h"

#import "sdk/objc/native/src/objc_video_track_source.h"
#import "sdk/objc/native/src/objc_frame_buffer.h"
#import "api/video_track_source_proxy.h"
#import "DesktopCaptureSource.h"

NS_ASSUME_NONNULL_BEGIN




@interface DesktopCaptureSourceHelper : NSObject

-(instancetype)initWithWindow:(DesktopCaptureSource *)window;

-(void)setOutput:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink;

-(void)start;
-(void)stop;
@end

NS_ASSUME_NONNULL_END
