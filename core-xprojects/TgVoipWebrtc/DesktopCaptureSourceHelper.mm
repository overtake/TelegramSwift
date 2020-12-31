//
//  DesktopCaptureSourceHelper.m
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 28.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import "DesktopCaptureSourceHelper.h"
#include "modules/desktop_capture/mac/screen_capturer_mac.h"
#include "modules/desktop_capture/desktop_and_cursor_composer.h"
#include "modules/desktop_capture/desktop_capturer_differ_wrapper.h"
#include "third_party/libyuv/include/libyuv.h"
#include "api/video/i420_buffer.h"


#include "common_video/libyuv/include/webrtc_libyuv.h"
#include "rtc_base/checks.h"
#include "rtc_base/logging.h"
#include "third_party/libyuv/include/libyuv.h"
#import "helpers/RTCDispatcher+Private.h"
#import <QuartzCore/QuartzCore.h>
#import <SSignalKit/STimer.h>
#import <SSignalKit/SQueue.h>


class SourceFrameCallbackImpl : public webrtc::DesktopCapturer::Callback {
private:
    int64_t next_timestamp_;
public:
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _sink;
    SourceFrameCallbackImpl() {
        next_timestamp_ = 0;
    }
    virtual void OnCaptureResult(webrtc::DesktopCapturer::Result result,
                                 std::unique_ptr<webrtc::DesktopFrame> frame) {
        if (result != webrtc::DesktopCapturer::Result::SUCCESS) {
            return;
        }
        
        int width = frame->size().width();
        while (((width) / 2) % 16 != 0) {
            width += 1;
        }
        int height = frame->size().height();
        int stride_y = width;
        int stride_uv = (width + 1) / 2;
                
        if (!i420_buffer_.get() || i420_buffer_->width() != frame->size().width() || i420_buffer_->height() != height) {
            i420_buffer_ = webrtc::I420Buffer::Create(frame->size().width(), height, stride_y, stride_uv, stride_uv);
        }
                
        int i420Result = libyuv::ConvertToI420(frame->data(), width * height,
                                               i420_buffer_->MutableDataY(), i420_buffer_->StrideY(),
                                               i420_buffer_->MutableDataU(), i420_buffer_->StrideU(),
                                               i420_buffer_->MutableDataV(), i420_buffer_->StrideV(),
                                               0, 0,
                                               width, height,
                                               frame->size().width(), height,
                                               libyuv::kRotate0,
                                               libyuv::FOURCC_ARGB);
        
        
        assert(i420Result == 0);
        webrtc::VideoFrame nativeVideoFrame = webrtc::VideoFrame(i420_buffer_, webrtc::kVideoRotation_0, next_timestamp_ / rtc::kNumNanosecsPerMicrosec);

        if (_sink != NULL) {
            _sink->OnFrame(nativeVideoFrame);
        }
        next_timestamp_ += rtc::kNumNanosecsPerSec / 15;
    }
private:
    rtc::scoped_refptr<webrtc::I420Buffer> i420_buffer_;
};


@interface DesktopCaptureSource ()
- (webrtc::DesktopCapturer::Source)getSource;
@end

@interface DesktopCaptureSourceHelper ()
@end

@implementation DesktopCaptureSourceHelper
{
    std::unique_ptr<webrtc::DesktopCapturer> _capturer;
    std::shared_ptr<SourceFrameCallbackImpl> _callback;
    NSTimer *_timer;
}

-(instancetype)initWithWindow:(DesktopCaptureSource *)window {
    if (self = [super init]) {
        
        
        _callback.reset(new SourceFrameCallbackImpl());
        
        auto options = webrtc::DesktopCaptureOptions::CreateDefault();
        options.set_disable_effects(false);
        options.set_allow_iosurface(true);
        options.set_detect_updated_region(true);
        _capturer.reset(new webrtc::DesktopAndCursorComposer(webrtc::DesktopCapturer::CreateWindowCapturer(options), options));
        
        _capturer->SelectSource([window getSource].id);
        _capturer->Start(_callback.get());
        
    }
    return self;
}

-(void)setOutput:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink {
    _callback.get()->_sink = sink;
    [self captureFrame];
}

-(void)start {
    if (self->_timer == nil) {
        __weak id weakSelf = self;
//        _timer = [[STimer alloc] initWithTimeout:1000/30/1000 repeat:true completion:^{
//            @autoreleasepool {
//                [weakSelf captureFrame];
//            }
//        } nativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)];
//
//        [_timer start];
        self->_timer = [NSTimer scheduledTimerWithTimeInterval:1000/15/1000
            target:weakSelf
            selector:@selector(captureFrame)
            userInfo:nil
            repeats:YES];
    }
}

-(void)captureFrame {
    @autoreleasepool {
        _capturer->CaptureFrame();
    }
}

- (void)dealloc
{
    [self->_timer invalidate];
    self->_timer = nil;
}

-(void)stop {
    [self->_timer invalidate];
    self->_timer = nil;
}

@end
