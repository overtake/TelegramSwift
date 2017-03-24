//
//  TimeObserver.m
//  Telegram
//
//  Created by keepcoder on 21.07.14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "TimeObserver.h"
#import "ATQueue.h"
@implementation TimeObserver

static NSMutableDictionary *groups;
static ATQueue *testQueue;

+(void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        groups = [[NSMutableDictionary alloc] init];
        testQueue = [[ATQueue alloc] initWithName:@"testUtilitesQueue"];
    });
}

void test_start_group(NSString * timeGroup) {
    
    
    [TimeObserver initialize];
    
    dispatch_queue_t dispatchedQueue = dispatch_get_current_queue();
    
    [testQueue dispatch:^{
        NSMutableArray *steps = groups[timeGroup];
        
        if(!steps) {
            steps = [[NSMutableArray alloc] init];
            groups[timeGroup] = steps;
        } else {
            [steps removeAllObjects];
            return;
        }
        
        [steps addObject:[NSDate date]];
        
        test_log(@"inited",timeGroup,dispatchedQueue);
    } synchronous:YES];
    
}

void test_log(NSString *log,NSString *group,dispatch_queue_t dispatch_queue) {
    __unused const char *queueName = (dispatch_queue_get_label(dispatch_queue));
        
    NSLog(@"group[%@], %@",group,log);

    
}

void test_step_group(NSString *group) {
    
    [TimeObserver initialize];
    
    dispatch_queue_t dispatchedQueue = dispatch_get_current_queue();
    
    [testQueue dispatch:^{

        NSMutableArray *steps = groups[group];
        
        
        if(!steps)
            test_start_group(group);
        
        steps = groups[group];
        
        NSDate *lastTime = [steps lastObject];
        
        NSDate *current = [NSDate date];
        
        NSTimeInterval executionTime = [current timeIntervalSinceDate:lastTime];
        
        test_log([NSString stringWithFormat:@"operation take: %f, step: %lu",executionTime,steps.count],group,dispatchedQueue);
        
        [steps addObject:current];
   
    } synchronous:YES];

}

void test_release_group(NSString *group) {
    
    [TimeObserver initialize];
    
    dispatch_queue_t dispatchedQueue = dispatch_get_current_queue();
    
    [testQueue dispatch:^{
        NSMutableArray *steps = groups[group];
        
        if(!steps)
            test_log(@"not inited", group,dispatchedQueue);
        
        
        
        NSDate *first = steps[0];
        
        NSDate *last = [steps lastObject];
        
        NSTimeInterval totalTime = [last timeIntervalSinceDate:first];
        
        test_log([NSString stringWithFormat:@"total time taked: %f",totalTime], group,dispatchedQueue);
        
        
        [steps removeAllObjects];
        [groups removeObjectForKey:group];
        
    } synchronous:YES];
}



@end
