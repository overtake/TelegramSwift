//
//  FFMpegAVCodec.h
//  Telegram
//
//  Created by Mikhail Filimonov on 05/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFMpegAVCodec : NSObject

+ (FFMpegAVCodec * _Nullable)findForId:(int)codecId;

- (void *)impl;

@end

NS_ASSUME_NONNULL_END
