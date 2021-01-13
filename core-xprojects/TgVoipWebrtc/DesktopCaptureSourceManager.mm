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

-(id)initWithSource:(webrtc::DesktopCapturer::Source)source isWindow:(BOOL)isWindow;
@end

@interface DesktopCaptureSourceManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, DesktopCaptureSourceHelper *> *cached;
@end

@implementation DesktopCaptureSourceManager
{
    std::unique_ptr<webrtc::DesktopCapturer> _capturer;
    BOOL _isWindow;
}
-(instancetype)init_w {
    if (self = [super init]) {
        auto options = webrtc::DesktopCaptureOptions::CreateDefault();
        options.set_allow_iosurface(false);
        options.set_detect_updated_region(true);
        _capturer = webrtc::DesktopCapturer::CreateWindowCapturer(webrtc::DesktopCaptureOptions::CreateDefault());
        _cached = [[NSMutableDictionary alloc] init];
        _isWindow = YES;
    }
    return self;
}
-(instancetype)init_s {
    if (self = [super init]) {
        auto options = webrtc::DesktopCaptureOptions::CreateDefault();
        options.set_allow_iosurface(true);
        options.set_detect_updated_region(true);
        _capturer = webrtc::DesktopCapturer::CreateScreenCapturer(webrtc::DesktopCaptureOptions::CreateDefault());
        _cached = [[NSMutableDictionary alloc] init];
        _isWindow = NO;
    }
    return self;
}

-(NSArray<DesktopCaptureSource *> *)list {
    NSMutableArray<DesktopCaptureSource *> *list = [[NSMutableArray alloc] init];
    webrtc::DesktopCapturer::SourceList sources;
    _capturer->GetSourceList(&sources);
    for (const auto& source : sources) {
        [list addObject:[[DesktopCaptureSource alloc] initWithSource:source isWindow: _isWindow]];
    }
    return list;
}

-(NSView *)createForScope:(DesktopCaptureSourceScope *)scope {
    DesktopCaptureSourceHelper *helper = _cached[scope.cachedKey];
    
    if (helper == nil) {
        helper = [[DesktopCaptureSourceHelper alloc] initWithWindow:scope.source data:scope.data];
        _cached[scope.cachedKey] = helper;
    }
    return [[DesktopCaptureSourceView alloc] initWithHelper:helper];
}

-(void)start:(DesktopCaptureSourceScope *)scope {
    [_cached[scope.cachedKey] start];
}
-(void)stop:(DesktopCaptureSourceScope *)scope {
    [_cached[scope.cachedKey] stop];
}

-(void)dealloc {
    NSArray<DesktopCaptureSourceHelper *> *allValues = _cached.allValues;
    for (int i = 0; i< allValues.count; i++) {
        [allValues[i] stop];
    }
}

@end
