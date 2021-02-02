#import "DesktopSharingCapturer.h"

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
#import "DesktopCaptureSourceHelper.h"
#import "DesktopCaptureSource.h"
#import "DesktopCaptureSourceManager.h"

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



class RendererAdapterImpl : public rtc::VideoSinkInterface<webrtc::VideoFrame> {
public:
    RendererAdapterImpl(void (^frameReceived)(CGSize, RTCVideoFrame *, RTCVideoRotation)) {
        _frameReceived = [frameReceived copy];
    }
    
    void OnFrame(const webrtc::VideoFrame& nativeVideoFrame) override {
        RTCVideoRotation rotation = RTCVideoRotation_0;
        RTCVideoFrame* videoFrame = customToObjCVideoFrame(nativeVideoFrame, rotation);
        
        CGSize currentSize = (videoFrame.rotation % 180 == 0) ? CGSizeMake(videoFrame.width, videoFrame.height) : CGSizeMake(videoFrame.height, videoFrame.width);

        if (_frameReceived) {
            _frameReceived(currentSize, videoFrame, rotation);
        }
    }
    
private:
    void (^_frameReceived)(CGSize, RTCVideoFrame *, RTCVideoRotation);
};



@implementation DesktopSharingCapturer {
    DesktopCaptureSourceHelper *renderer;
    std::shared_ptr<RendererAdapterImpl> _sink;
    BOOL _isPaused;

}
- (instancetype)initWithSource:(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface>)trackSource capturerKey:(NSString *)capturerKey {
    self = [super init];
    if (self != nil) {
        
        
        BOOL isWindow = [capturerKey containsString:@"_window_"];
        DesktopCaptureSourceManager *manager;
        int keyId;
        if (isWindow) {
            manager = [[DesktopCaptureSourceManager alloc] init_w];
            keyId = [[capturerKey substringFromIndex:@"desktop_capturer_window_".length] intValue];
        } else {
            manager = [[DesktopCaptureSourceManager alloc] init_s];
            keyId = [[capturerKey substringFromIndex:@"desktop_capturer_screen_".length] intValue];
        }
        
        DesktopCaptureSource *source;
        NSArray<DesktopCaptureSource *> *list = [manager list];
        for (int i = 0; i < list.count; i++) {
            if ((int)list[i].uniqueId == keyId) {
                source = list[i];
                break;
            }
        }
        
        
        _sink.reset(new RendererAdapterImpl(^(CGSize size, RTCVideoFrame *videoFrame, RTCVideoRotation rotation) {
            getObjCVideoSource(trackSource)->OnCapturedFrame(videoFrame);
        }));
        
        if (source != nil) {
            renderer = [[DesktopCaptureSourceHelper alloc] initWithWindow:source data:[[DesktopCaptureSourceData alloc] initWithSize:CGSizeMake(1280, 720) fps:30 captureMouse: YES]];
            [renderer setOutput:_sink];
        }
        

    }
    return self;
}

-(void)start {
    [renderer start];
}
-(void)stop {
    [renderer stop];
}

- (void)setIsEnabled:(bool)isEnabled {
    BOOL updated = _isPaused != !isEnabled;
    _isPaused = !isEnabled;
    if (updated) {
        if (isEnabled) {
            [renderer start];
        } else {
            [renderer stop];
        }
    }
}


- (void)setPreferredCaptureAspectRatio:(float)aspectRatio {
    
}


- (void)setUncroppedSink:(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame> >)sink {
    [renderer setSecondaryOutput:sink];
}


@end








