//
//  Telegram-Mac-Bridging-Header.h
//  Telegram-Mac
//
//  Created by keepcoder on 19/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//



#ifndef Telegram_Mac_Bridging_Header_h
#define Telegram_Mac_Bridging_Header_h

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenGL/gl.h>
#import "MP4Atom.h"
#import "HackUtils.h"
#import "BuildConfig.h"
#import "TGModernGrowingTextView.h"


#ifndef SHARE

#import "GZip.h"
#import "Svg.h"
#import "TGGifConverter.h"
#import "FastBlur.h"
#import "YTVimeoVideo.h"
#import "XCDYouTubeVideo.h"
#import "XCDYouTubeOperation.h"
#import "XCDYouTubeClient.h"
#import "YTVimeoExtractor.h"
#import "TGVideoCameraGLRenderer.h"
#import "TGVideoCameraMovieRecorder.h"
#import "EmojiSuggestionBridge.h"
#import "TGCurrencyFormatter.h"
#endif

#import "OngoingCallThreadLocalContext.h"


#import "CalendarUtils.h"
#import "RingBuffer.h"
#import "ocr.h"
#import "TGPassportMRZ.h"
#import "EDSunriseSet.h"
#import "ObjcUtils.h"
#import "DateUtils.h"
#import "NumberPluralizationForm.h"

#endif /* Telegram_Mac_Bridging_Header_h */
