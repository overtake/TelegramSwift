/*
 *  Copyright (c) 2015-2020 Erik Doernenburg and contributors
 *
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may
 *  not use these files except in compliance with the License. You may obtain
 *  a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */

#import <libkern/OSAtomic.h>
#import "TestClassWithCustomReferenceCounting.h"


@implementation TestClassWithCustomReferenceCounting
{
#if __LP64__
    int64_t retainCount;
#else
    int32_t retainCount;
#endif
}

- (NSUInteger)retainCount
{
    return retainCount + 1;
}

- (instancetype)retain
{
#if __LP64__
    OSAtomicIncrement64(&retainCount);
#else
    OSAtomicIncrement32(&retainCount);
#endif
    return self;
}

- (oneway void)release
{
#if __LP64__
    int64_t newRetainCount = OSAtomicDecrement64(&retainCount);
#else
    int32_t newRetainCount = OSAtomicDecrement32(&retainCount);
#endif
    if (newRetainCount == -1)
        [self dealloc];
}

@end
