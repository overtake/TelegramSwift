//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCRunloopRunner.h"


@implementation HCRunloopRunner
{
    CFRunLoopObserverRef _observer;
}

- (instancetype)initWithFulfillmentBlock:(BOOL (^)(void))fulfillmentBlock
{
    self = [super init];
    if (self)
    {
        _observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            if (fulfillmentBlock())
                CFRunLoopStop(CFRunLoopGetCurrent());
            else
                CFRunLoopWakeUp(CFRunLoopGetCurrent());
        });
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), _observer, kCFRunLoopDefaultMode);
    }
    return self;
}

- (void)dealloc
{
    CFRunLoopRemoveObserver(CFRunLoopGetCurrent(), _observer, kCFRunLoopDefaultMode);
    CFRelease(_observer);
}

- (void)runUntilFulfilledOrTimeout:(CFTimeInterval)timeout
{
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout, false);
}

@end
