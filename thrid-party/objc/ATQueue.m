#import "ATQueue.h"

//#import <ReactiveCocoa/ReactiveCocoa.h>

static const char *AMQueueSpecific = "AMQueueSpecific";

@interface ATQueue ()
{
    dispatch_queue_t _nativeQueue;
    bool _isMainQueue;
    
    int32_t _noop;
}

@end

@implementation ATQueue

+ (NSString *)applicationPrefix
{
    static NSString *prefix = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        prefix = [[NSBundle mainBundle] bundleIdentifier];
    });
    
    return prefix;
}

+ (ATQueue *)mainQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] init];
        queue->_nativeQueue = dispatch_get_main_queue();
        queue->_isMainQueue = true;
    });
    
    return queue;
}

+ (ATQueue *)concurrentDefaultQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    });
    
    return queue;
}

+ (ATQueue *)concurrentBackgroundQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
    });
    
    return queue;
}

- (instancetype)init
{
    return [self initWithName:[[ATQueue applicationPrefix] stringByAppendingFormat:@".%ld", lrand48()]];
}

static int32_t numQueues = 0;

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self != nil)
    {
        _nativeQueue = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_nativeQueue, AMQueueSpecific, (__bridge void *)self, NULL);
        
        numQueues++;
    }
    return self;
}

- (instancetype)initWithPriority:(ATQueuePriority)priority
{
    self = [super init];
    if (self != nil)
    {
        _nativeQueue = dispatch_queue_create([[[ATQueue applicationPrefix] stringByAppendingFormat:@".%ld", lrand48()] UTF8String], DISPATCH_QUEUE_SERIAL);
        long targetQueueIdentifier = DISPATCH_QUEUE_PRIORITY_DEFAULT;
        switch (priority)
        {
            case ATQueuePriorityLow:
                targetQueueIdentifier = DISPATCH_QUEUE_PRIORITY_LOW;
                break;
            case ATQueuePriorityDefault:
                targetQueueIdentifier = DISPATCH_QUEUE_PRIORITY_DEFAULT;
                break;
            case ATQueuePriorityHigh:
                targetQueueIdentifier = DISPATCH_QUEUE_PRIORITY_HIGH;
                break;
        }
        dispatch_set_target_queue(_nativeQueue, dispatch_get_global_queue(targetQueueIdentifier, 0));
        dispatch_queue_set_specific(_nativeQueue, AMQueueSpecific, (__bridge void *)self, NULL);
    }
    return self;
}

- (instancetype)initWithNativeQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self != nil)
    {
#if !OS_OBJECT_USE_OBJC
        _nativeQueue = dispatch_retain(queue);
#else
        _nativeQueue = queue;
#endif
    }
    return self;
}

- (void)dealloc
{
    if (_nativeQueue != nil)
    {
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_nativeQueue);
#endif
        _nativeQueue = nil;
    }
}

- (void)dispatch:(dispatch_block_t)block
{
    [self dispatch:block synchronous:false];
}

- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous
{
    __block ATQueue *strongSelf = self;
    dispatch_block_t blockWithSelf = ^
    {
        block();
        [strongSelf noop];
        strongSelf = nil;
    };
    
    if (_isMainQueue)
    {
        if ([NSThread isMainThread])
            blockWithSelf();
        else if (synchronous)
            dispatch_sync(_nativeQueue, blockWithSelf);
        else
            dispatch_async(_nativeQueue, blockWithSelf);
    }
    else
    {
        if (dispatch_get_specific(AMQueueSpecific) == (__bridge void *)self)
            block();
        else if (synchronous)
            dispatch_sync(_nativeQueue, blockWithSelf);
        else
            dispatch_async(_nativeQueue, blockWithSelf);
    }
}

- (void)dispatchAfter:(NSTimeInterval)seconds block:(dispatch_block_t)block
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), _nativeQueue, block);
}

- (dispatch_queue_t)nativeQueue
{
    return _nativeQueue;
}

- (void)noop
{
}

@end
