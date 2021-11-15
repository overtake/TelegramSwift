//
//  TGGifConverter.h
//  Telegram
//
//  Created by keepcoder on 15/12/15.
//  Copyright © 2015 keepcoder. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TGGifConverter : NSObject
+ (void)convertGifToMp4:(NSData *)data exportPath:(NSString *)exportPath completionHandler:(void (^)(NSString *path))completionHandler errorHandler:(dispatch_block_t)errorHandler cancelHandler:(BOOL (^)())cancelHandler;

+(NSSize)gifDimensionSize:(NSString *)path;
@end
