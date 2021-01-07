//
//  DesktopCaptureSourceView.h
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 28.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DesktopCaptureSourceHelper.h"
#import "platform/darwin/VideoMetalViewMac.h"
#import "platform/darwin/GLVideoViewMac.h"
NS_ASSUME_NONNULL_BEGIN

@interface DesktopCaptureSourceView : GLVideoView

-(id)initWithHelper:(DesktopCaptureSourceHelper *)helper;

@end

NS_ASSUME_NONNULL_END
