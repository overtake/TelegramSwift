//
//  DesktopCaptureSource.m
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import "DesktopCaptureSource.h"
#include "modules/desktop_capture/mac/screen_capturer_mac.h"


@implementation DesktopCaptureSourceData
-(id)initWithSize:(CGSize)size fps:(double)fps captureMouse:(bool)captureMouse {
    if (self = [super init]) {
        self.aspectSize = size;
        self.fps = fps;
        self.captureMouse = captureMouse;
    }
    return self;
}

-(NSString *)cachedKey {
    return [[NSString alloc] initWithFormat:@"%@:%f:%d", NSStringFromSize(self.aspectSize), self.fps, self.captureMouse];
}
@end

@interface DesktopCaptureSource ()
{
    webrtc::DesktopCapturer::Source _source;
    BOOL _isWindow;
}
- (webrtc::DesktopCapturer::Source)getSource;

@end


@implementation DesktopCaptureSource

-(webrtc::DesktopCapturer::Source)getSource {
    return _source;
}

-(NSString *)title {
    if (_isWindow)
        return [[NSString alloc] initWithCString:_source.title.c_str() encoding:NSUTF8StringEncoding];
    else
        return [[NSString alloc] initWithFormat:@"Screen"];
}

-(long)uniqueId {
    return _source.id;
}
-(BOOL)isWindow {
    return _isWindow;
}
-(NSString *)uniqueKey {
    return [[NSString alloc] initWithFormat:@"%ld:%@", self.uniqueId, _isWindow ? @"Window" : @"Screen"];
}

-(NSString *)deviceIdKey {
    return [[NSString alloc] initWithFormat:@"desktop_capturer_%@_%ld", _isWindow ? @"window" : @"screen", self.uniqueId];
}

-(BOOL)isEqual:(id)object {
    return [[((DesktopCaptureSource *)object) uniqueKey] isEqualToString:[self uniqueKey]];
}
- (BOOL)isEqualTo:(id)object {
    return [[((DesktopCaptureSource *)object) uniqueKey] isEqualToString:[self uniqueKey]];
}

-(id)initWithSource:(webrtc::DesktopCapturer::Source)source isWindow:(BOOL)isWindow {
    if (self = [super init]) {
        _source = source;
        _isWindow = isWindow;
    }
    return self;
}

@end


@implementation DesktopCaptureSourceScope

-(id)initWithSource:(DesktopCaptureSource *)source data:(DesktopCaptureSourceData *)data {
    if (self = [super init]) {
        _data = data;
        _source = source;
    }
    return self;
}

-(NSString *)cachedKey {
    return [[NSString alloc] initWithFormat:@"%@:%@", self.source.uniqueKey, self.data.cachedKey];
}


@end
