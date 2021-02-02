//
//  DesktopCaptureSourceHelper.m
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 28.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import "DesktopCaptureSourceHelper.h"
#include <iostream>
#include <memory>
#include <algorithm>
#include <chrono>
#include <iostream>
#include <vector>
#include "api/scoped_refptr.h"
#include "rtc_base/thread.h"

#include "modules/desktop_capture/mac/screen_capturer_mac.h"
#include "modules/desktop_capture/desktop_and_cursor_composer.h"
#include "modules/desktop_capture/desktop_capturer_differ_wrapper.h"
#include "third_party/libyuv/include/libyuv.h"
#include "api/video/i420_buffer.h"

#include "rtc_base/weak_ptr.h"

#include "common_video/libyuv/include/webrtc_libyuv.h"
#include "rtc_base/checks.h"
#include "rtc_base/logging.h"
#include "third_party/libyuv/include/libyuv.h"
#import "helpers/RTCDispatcher+Private.h"
#import <QuartzCore/QuartzCore.h>
#import <SSignalKit/STimer.h>
#import <SSignalKit/SQueue.h>
#import <SSignalKit/SQueueLocalObject.h>
#include "ThreadLocalObject.h"


rtc::Thread *makeDesktopThread() {
    static std::unique_ptr<rtc::Thread> value = rtc::Thread::Create();
    value->SetName("WebRTC-DesktopCapturer", nullptr);
    value->Start();
    return value.get();
}

rtc::Thread *getDesktopThread() {
    static rtc::Thread *value = makeDesktopThread();
    return value;
}


static CGSize aspectFitted(CGSize from, CGSize to) {
    CGFloat scale = MAX(from.width / MAX(1.0, to.width), from.height / MAX(1.0, to.height));
    return NSMakeSize(ceil(to.width * scale), ceil(to.height * scale));
}

static SQueue *queue = [[SQueue alloc] init];

class SourceFrameCallbackImpl : public webrtc::DesktopCapturer::Callback {
private:
    int64_t next_timestamp_;
    CGSize size_;
    int fps_;
public:
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _sink;
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _secondarySink;

    SourceFrameCallbackImpl(CGSize size,
                            int fps) {
        next_timestamp_ = 0;
        size_ = size;
        fps_ = fps;
    }
    virtual void OnCaptureResult(webrtc::DesktopCapturer::Result result,
                                 std::unique_ptr<webrtc::DesktopFrame> frame) {
        if (result != webrtc::DesktopCapturer::Result::SUCCESS) {
            return;
        }
        
       
        
        std::unique_ptr<webrtc::DesktopFrame> output_frame_;
        
        CGSize fittedSize = aspectFitted(size_, CGSizeMake(frame->size().width(), frame->size().height()));
        while ((int(fittedSize.width) / 2) % 16 != 0) {
            fittedSize.width -= 1;
        }
        
        
        webrtc::DesktopSize output_size(fittedSize.width,
                                        fittedSize.height);

        
        output_frame_.reset(new webrtc::BasicDesktopFrame(output_size));
        
        webrtc::DesktopRect output_rect_ = webrtc::DesktopRect::MakeSize(output_size);

        uint8_t* output_rect_data = output_frame_->data() +
            output_frame_->stride() * output_rect_.top() +
            webrtc::DesktopFrame::kBytesPerPixel * output_rect_.left();

        
        libyuv::ARGBScale(frame->data(), frame->stride(), frame->size().width(),
                             frame->size().height(), output_rect_data,
                           output_frame_->stride(), output_size.width(),
                          output_size.height(), libyuv::kFilterBilinear);

        int width = output_frame_->size().width();
        int height = output_frame_->size().height();
        int stride_y = width;
        int stride_uv = (width + 1) / 2;

        if (!i420_buffer_.get() || i420_buffer_->width() != output_frame_->size().width() || i420_buffer_->height() != height) {
            i420_buffer_ = webrtc::I420Buffer::Create(output_frame_->size().width(), height, stride_y, stride_uv, stride_uv);
        }
        
        int i420Result = libyuv::ConvertToI420(output_frame_->data(), width * height,
                                               i420_buffer_->MutableDataY(), i420_buffer_->StrideY(),
                                               i420_buffer_->MutableDataU(), i420_buffer_->StrideU(),
                                               i420_buffer_->MutableDataV(), i420_buffer_->StrideV(),
                                               0, 0,
                                               width, height,
                                               output_frame_->size().width(), height,
                                               libyuv::kRotate0,
                                               libyuv::FOURCC_ARGB);


        assert(i420Result == 0);
        webrtc::VideoFrame nativeVideoFrame = webrtc::VideoFrame(i420_buffer_, webrtc::kVideoRotation_0, next_timestamp_ / rtc::kNumNanosecsPerMicrosec);
        if (_sink != NULL) {
            _sink->OnFrame(nativeVideoFrame);
        }
        if (_secondarySink != NULL) {
            _secondarySink->OnFrame(nativeVideoFrame);
        }
        next_timestamp_ += rtc::kNumNanosecsPerSec / double(fps_);
    }
private:
    rtc::scoped_refptr<webrtc::I420Buffer> i420_buffer_;
};

@interface DesktopCaptureSource ()
- (webrtc::DesktopCapturer::Source)getSource;
@end

@interface DesktopSourceRenderer : NSObject
-(id)initWithSource:(DesktopCaptureSource *)source data: (DesktopCaptureSourceData *)data;
-(void)Stop;
-(void)Start;
-(void)SetOutput:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink;
-(void)SetSecondaryOutput:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink;
@end

@implementation DesktopSourceRenderer
{
    std::unique_ptr<webrtc::DesktopCapturer> _capturer;
    std::shared_ptr<SourceFrameCallbackImpl> _callback;
    bool isRunning;
    double delayMs;
    STimer *timer;
}
-(id)initWithSource:(DesktopCaptureSource *)source data: (DesktopCaptureSourceData *)data {
    if (self = [super init]) {
        delayMs = 1000 / double(data.fps);
        SourceFrameCallbackImpl *callback = new SourceFrameCallbackImpl(data.aspectSize, data.fps);
        isRunning = false;
        _callback.reset(callback);
        
        auto options = webrtc::DesktopCaptureOptions::CreateDefault();
        options.set_disable_effects(true);
        options.set_detect_updated_region(true);
        options.set_allow_iosurface(true);
        
        if (data.captureMouse) {
            if (source.isWindow) {
                _capturer.reset(new webrtc::DesktopAndCursorComposer(webrtc::DesktopCapturer::CreateWindowCapturer(options), options));
            } else {
                _capturer.reset(new webrtc::DesktopAndCursorComposer(webrtc::DesktopCapturer::CreateScreenCapturer(options), options));
            }
        } else {
            if (source.isWindow) {
                std::unique_ptr<webrtc::DesktopCapturer> capturer = webrtc::DesktopCapturer::CreateWindowCapturer(options);
                _capturer = std::move(capturer);
            } else {
                std::unique_ptr<webrtc::DesktopCapturer> capturer = webrtc::DesktopCapturer::CreateScreenCapturer(options);
                _capturer = std::move(capturer);
            }
        }
        
        _capturer->SelectSource([source getSource].id);
        _capturer->Start(callback);
    }
    return self;
}

-(void)Start {
    if (isRunning) {
        return;
    }
    isRunning = true;
    [self Loop];
}
-(void)Stop {
    isRunning = false;
    [timer invalidate];
}

-(void)Loop {
    if(!isRunning) {
        return;
    }

    _capturer->CaptureFrame();
    __weak id weakSelf = self;

    timer = [[STimer alloc] initWithTimeout:delayMs / 1000 repeat:false completion:^{
        [weakSelf Loop];
    } queue:[SQueue mainQueue]];
    
    [timer start];
}

-(void)SetOutput:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink {
    _callback->_sink = sink;
}
-(void)SetSecondaryOutput:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink {
    _callback->_secondarySink = sink;
}

-(void)dealloc {
    int bp = 0;
    bp += 1;
}

@end


@interface DesktopCaptureSourceHelper ()
@end

@implementation DesktopCaptureSourceHelper
{
    SQueueLocalObject * _manager;
    STimer *_timer;
    DesktopCaptureSourceData *_data;
}

-(instancetype)initWithWindow:(DesktopCaptureSource *)source data: (DesktopCaptureSourceData *)data  {
    if (self = [super init]) {
        _data = data;
        _manager = [[SQueueLocalObject alloc] initWithQueue:[SQueue mainQueue] generate:^id {
            return [[DesktopSourceRenderer alloc] initWithSource:source data:data];
        }];
    }
    return self;
}

-(void)setOutput:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink {
    [_manager with:^(id  _Nonnull object) {
        [((DesktopSourceRenderer *)object) SetOutput:sink];
    }];
}

-(void)setSecondaryOutput:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink {
    [_manager with:^(id  _Nonnull object) {
        [((DesktopSourceRenderer *)object) SetSecondaryOutput:sink];
    }];
}
-(void)start {
    [_manager with:^(id  _Nonnull object) {
        [((DesktopSourceRenderer *)object) Start];
    }];
}


-(void)stop {
    [_manager with:^(id  _Nonnull object) {
        [((DesktopSourceRenderer *)object) Stop];
    }];
}

@end
