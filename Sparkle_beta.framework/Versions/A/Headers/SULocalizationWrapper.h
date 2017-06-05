//
//  SULocalizationWrapper.h
//  Sparkle
//
//  Created by keepcoder on 31.05.17.
//  Copyright © 2017 Sparkle Project. All rights reserved.
//

#ifndef LOCALICATIONWRAPPER_H
#define LOCALICATIONWRAPPER_H

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif


@interface SULocalizationWrapper : NSObject
+(NSBundle *)localizationBundle;
+(void)setLanguageCode:(NSString *)code;
@end

#endif
