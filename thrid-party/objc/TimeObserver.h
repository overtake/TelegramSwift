//
//  TimeObserver.h
//  Telegram
//
//  Created by keepcoder on 21.07.14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TimeObserver : NSObject

void test_start_group(NSString * timeGroup);
void test_step_group(NSString *group);
void test_release_group(NSString *group);

@end
