// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACTestFrameworks.h"
#import "MSAC_Reachability.h"

@interface MSACReachabilityTests : XCTestCase
@end

@implementation MSACReachabilityTests

- (void)testRaceConditionOnDealloc {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Reachability deallocated."];

  // When
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    MSAC_Reachability *reachability = [MSAC_Reachability reachabilityForInternetConnection];
    reachability = nil;
  });
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    // Arbitrary wait for reachability dealocation so if a EXC_BAD_ACCESS happens it has a chance to happen in this test.
    [NSThread sleepForTimeInterval:0.1];
    [expectation fulfill];
  });

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

@end
