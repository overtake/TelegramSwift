// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@class MSACLogContainer;
@class MSACDevice;

NS_ASSUME_NONNULL_BEGIN

@interface MSACTestUtil : NSObject

+ (MSACLogContainer *)createLogContainerWithId:(NSString *)batchId device:(MSACDevice *)device;

@end

NS_ASSUME_NONNULL_END
