#import "ScreenCapturer.h"

#include "modules/desktop_capture/mac/screen_capturer_mac.h"
#include "modules/desktop_capture/desktop_and_cursor_composer.h"
#include "third_party/libyuv/include/libyuv.h"
#include "api/video/i420_buffer.h"


#include "common_video/libyuv/include/webrtc_libyuv.h"
#include "rtc_base/checks.h"
#include "rtc_base/logging.h"
#include "third_party/libyuv/include/libyuv.h"
#import "helpers/RTCDispatcher+Private.h"
#import <QuartzCore/QuartzCore.h>

static RTCVideoFrame *customToObjCVideoFrame(const webrtc::VideoFrame &frame, RTCVideoRotation &rotation) {
    rotation = RTCVideoRotation(frame.rotation());
    RTCVideoFrame *videoFrame =
    [[RTCVideoFrame alloc] initWithBuffer:webrtc::ToObjCVideoFrameBuffer(frame.video_frame_buffer())
                                 rotation:rotation
                              timeStampNs:frame.timestamp_us() * rtc::kNumNanosecsPerMicrosec];
    videoFrame.timeStamp = frame.timestamp();
    
    return videoFrame;
}

static webrtc::ObjCVideoTrackSource *getObjCVideoSource(const rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> nativeSource) {
    webrtc::VideoTrackSourceProxy *proxy_source =
    static_cast<webrtc::VideoTrackSourceProxy *>(nativeSource.get());
    return static_cast<webrtc::ObjCVideoTrackSource *>(proxy_source->internal());
}

class DesktopFrameCallbackImpl : public webrtc::DesktopCapturer::Callback {
private:
    int64_t next_timestamp_;
public:
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _sink;
    DesktopFrameCallbackImpl(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source) {
        _source = source;
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
        RTCVideoRotation rotation = RTCVideoRotation_0;
        RTCVideoFrame* videoFrame = customToObjCVideoFrame(nativeVideoFrame, rotation);
        getObjCVideoSource(_source)->OnCapturedFrame(videoFrame);
        
        next_timestamp_ += rtc::kNumNanosecsPerSec / 30;
    }
private:
    rtc::scoped_refptr<webrtc::I420Buffer> i420_buffer_;
    rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> _source;
};

@implementation AppScreenCapturer {
    std::unique_ptr<webrtc::DesktopCapturer> _capturer;
    std::shared_ptr<DesktopFrameCallbackImpl> _callback;
    dispatch_queue_t _frameQueue;

}
- (instancetype)initWithSource:(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface>)source {
    self = [super init];
    if (self != nil) {
        
        _callback.reset(new DesktopFrameCallbackImpl(source));
        
        auto options = webrtc::DesktopCaptureOptions::CreateDefault();
        options.set_disable_effects(false);
        options.set_allow_iosurface(true);
        options.set_detect_updated_region(true);
        
        _capturer.reset(new webrtc::DesktopAndCursorComposer(webrtc::DesktopCapturer::CreateWindowCapturer(options), options));
        
        webrtc::DesktopCapturer::SourceList sources;
        _capturer->GetSourceList(&sources);
       
        
        
        _capturer->SelectSource(sources[0].id);
                
        _capturer->Start(_callback.get());
        
        
        
        [self captureFrame];
    }
    return self;
}

-(void)start {
    
}
-(void)stop {
    
}

-(void)captureFrame {
    __weak id value = self;
    @autoreleasepool {
        self->_capturer->CaptureFrame();
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (1 / 30) * NSEC_PER_SEC), self.frameQueue, ^{
        [value captureFrame];
    });
}

-(void)setSink:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink {
    dispatch_async(self.frameQueue, ^{
        self->_callback->_sink = sink;
    });
}

- (dispatch_queue_t)frameQueue {
    if (!_frameQueue) {
        _frameQueue =
        dispatch_queue_create("org.webrtc.desktopcapturer.video", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_frameQueue,
                                  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    }
    return _frameQueue;
}

-(void)dealloc {
    _capturer.reset();
    _callback.reset();
}

@end
