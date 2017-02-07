#import <Foundation/Foundation.h>

typedef enum {
    ATQueuePriorityLow,
    ATQueuePriorityDefault,
    ATQueuePriorityHigh
} ATQueuePriority;

@interface ATQueue : NSObject

+ (ATQueue *)mainQueue;
+ (ATQueue *)concurrentDefaultQueue;
+ (ATQueue *)concurrentBackgroundQueue;

- (instancetype)init;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithPriority:(ATQueuePriority)priority;

- (void)dispatch:(dispatch_block_t)block;
- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous;
- (void)dispatchAfter:(NSTimeInterval)seconds block:(dispatch_block_t)block;

- (dispatch_queue_t)nativeQueue;

@end
