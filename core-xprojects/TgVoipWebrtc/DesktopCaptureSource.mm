//
//  DesktopCaptureSource.m
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import "DesktopCaptureSource.h"
#include "modules/desktop_capture/mac/screen_capturer_mac.h"


@interface DesktopCaptureSource ()
{
    webrtc::DesktopCapturer::Source _source;
}
- (webrtc::DesktopCapturer::Source)getSource;

@end


@implementation DesktopCaptureSource

-(webrtc::DesktopCapturer::Source)getSource {
    return _source;
}

-(NSString *)title {
    return [[NSString alloc] initWithCString:_source.title.c_str() encoding:NSUTF8StringEncoding];
}

-(long)uniqueId {
    return _source.id;
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

-(id)initWithSource:(webrtc::DesktopCapturer::Source)source {
    if (self = [super init]) {
        _source = source;
    }
    return self;
}

@end
