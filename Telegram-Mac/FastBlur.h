//
//  FastBlur.h
//  Telegram-Mac
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

#ifndef Telegram_FastBlur_h
#define Telegram_FastBlur_h

#import <Foundation/Foundation.h>

void telegramFastBlur(int imageWidth, int imageHeight, int imageStride, void *pixels);

#endif
