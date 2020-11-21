/*
 *  Copyright (c) 2019-2020 Erik Doernenburg and contributors
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

#import "OCMNonRetainingObjectReturnValueProvider.h"
#import "OCMFunctions.h"
#import "NSInvocation+OCMAdditions.h"


@implementation OCMNonRetainingObjectReturnValueProvider

- (instancetype)initWithValue:(id)aValue
{
    if ((self = [super init]))
        returnValue = aValue;
    return self;
}

- (void)handleInvocation:(NSInvocation *)anInvocation
{
    if(!OCMIsObjectType([[anInvocation methodSignature] methodReturnType]))
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Expected invocation with object return type. Did you mean to use andReturnValue: instead?" userInfo:nil];
    }

    if([anInvocation methodIsInAllocFamily] || [anInvocation methodIsInNewFamily] ||
            [anInvocation methodIsInCopyFamily] || [anInvocation methodIsInMutableCopyFamily])
    {
        // methods that "create" an object return it with an extra retain count
        [returnValue retain];
    }
    else if([anInvocation methodIsInInitFamily])
    {
        // init family methods "consume" self and retain their return value. Do the retain first in case the return value and self are the same.
        [returnValue retain];
        [[anInvocation target] release];
    }
    else
    {
        // avoid potential problems with the return value being release too early
        returnValue = [[returnValue retain] autorelease];
    }
    [anInvocation setReturnValue:&returnValue];
}
@end

