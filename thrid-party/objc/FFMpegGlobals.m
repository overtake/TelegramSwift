//
//  NSObject+FFMpegGlobals.m
//  Telegram
//
//  Created by Mikhail Filimonov on 17/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

#import "FFMpegGlobals.h"
#import "libavformat/avformat.h"



@implementation FFMpegGlobals
    
+ (void)initializeGlobals {
    av_register_all();
}
    
@end
