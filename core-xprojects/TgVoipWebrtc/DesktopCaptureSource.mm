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
-(id)initWithSize:(CGSize)size fps:(int)fps {
    if (self = [super init]) {
        self.aspectSize = size;
        self.fps = fps;
    }
    return self;
}

-(NSString *)cachedKey {
    return [[NSString alloc] initWithFormat:@"%@:%d", NSStringFromSize(self.aspectSize), self.fps];
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
        return [[NSString alloc] initWithFormat:@"Screen %@", self.uniqueKey];
}

-(long)uniqueId {
    return _source.id;
}
-(BOOL)isWindow {
    return _isWindow;
}
-(NSString *)uniqueKey {
    return [[NSString alloc] initWithFormat:@"%ld", self.uniqueId];
}

-(BOOL)isEqual:(id)object {
    return [((DesktopCaptureSource *)object) uniqueId] == [self uniqueId];
}
- (BOOL)isEqualTo:(id)object {
    return [((DesktopCaptureSource *)object) uniqueId] == [self uniqueId];
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
