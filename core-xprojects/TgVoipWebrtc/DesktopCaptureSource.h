//
//  DesktopCaptureSource.h
//  TgVoipWebrtc
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DesktopCaptureSource : NSObject
-(NSString *)title;
-(long)uniqueId;
-(NSString *)uniqueKey;
@end

NS_ASSUME_NONNULL_END
