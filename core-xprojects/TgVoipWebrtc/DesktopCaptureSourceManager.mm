//
//  DesktopCaptureSourceManager.m
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 28.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import "DesktopCaptureSourceManager.h"
#import "DesktopCaptureSourceView.h"

#include "modules/desktop_capture/mac/screen_capturer_mac.h"
#include "modules/desktop_capture/desktop_and_cursor_composer.h"
#include "modules/desktop_capture/desktop_capturer_differ_wrapper.h"
#include "third_party/libyuv/include/libyuv.h"
#include "api/video/i420_buffer.h"
#import "DesktopCaptureSourceHelper.h"



@interface DesktopCaptureSource ()

-(id)initWithSource:(webrtc::DesktopCapturer::Source)source;
@end

@interface DesktopCaptureSourceManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, DesktopCaptureSourceHelper *> *cached;
@end

@implementation DesktopCaptureSourceManager
{
    std::unique_ptr<webrtc::DesktopCapturer> _capturer;
}
-(instancetype)init_w {
    if (self = [super init]) {
        auto options = webrtc::DesktopCaptureOptions::CreateDefault();
        _capturer = webrtc::ScreenCapturerMac::CreateWindowCapturer(webrtc::DesktopCaptureOptions::CreateDefault());
        _cached = [[NSMutableDictionary alloc] init];
    }
    return self;
}
-(instancetype)init_s {
    if (self = [super init]) {
        auto options = webrtc::DesktopCaptureOptions::CreateDefault();
        _capturer = webrtc::ScreenCapturerMac::CreateScreenCapturer(webrtc::DesktopCaptureOptions::CreateDefault());
        _cached = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(NSArray<DesktopCaptureSource *> *)list {
    NSMutableArray<DesktopCaptureSource *> *list = [[NSMutableArray alloc] init];
    webrtc::DesktopCapturer::SourceList sources;
    _capturer->GetSourceList(&sources);
    for (const auto& source : sources) {
        [list addObject:[[DesktopCaptureSource alloc] initWithSource:source]];
    }
    return list;
}

-(NSView *)createForSource:(DesktopCaptureSource *)source {
    DesktopCaptureSourceHelper *helper = _cached[source.uniqueKey];
    
    if (helper == nil) {
        helper = [[DesktopCaptureSourceHelper alloc] initWithWindow:source];
        _cached[source.uniqueKey] = helper;
    }
    return [[DesktopCaptureSourceView alloc] initWithHelper:helper];
}

-(void)start:(DesktopCaptureSource *)source {
    [_cached[source.uniqueKey] start];
}
-(void)stop:(DesktopCaptureSource *)source {
    [_cached[source.uniqueKey] stop];
}

-(void)dealloc {
    NSArray<DesktopCaptureSourceHelper *> *allValues = _cached.allValues;
    for (int i = 0; i< allValues.count; i++) {
        [allValues[i] stop];
    }
}

@end
