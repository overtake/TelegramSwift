//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCTestFailureReporterChain.h>

#import <OCHamcrest/HCTestFailureReporter.h>

@import XCTest;


@interface HCTestFailureReporterChainTests : XCTestCase
@end

@implementation HCTestFailureReporterChainTests

- (void)tearDown
{
    [HCTestFailureReporterChain reset];
    [super tearDown];
}

- (void)test_defaultChain_shouldPointToXCTestHandlerAsHeadOfChain
{
    HCTestFailureReporter *chain = [HCTestFailureReporterChain reporterChain];

    XCTAssertEqualObjects(NSStringFromClass([chain class]), @"HCXCTestFailureReporter");
    XCTAssertNotNil(chain.successor);
}

- (void)test_addReporter_shouldSetHeadOfChainToGivenHandler
{
    HCTestFailureReporter *reporter = [[HCTestFailureReporter alloc] init];

    [HCTestFailureReporterChain addReporter:reporter];

    XCTAssertEqual([HCTestFailureReporterChain reporterChain], reporter);
}

- (void)test_addReporter_shouldSetHandlerSuccessorToPreviousHeadOfChain
{
    HCTestFailureReporter *reporter = [[HCTestFailureReporter alloc] init];
    HCTestFailureReporter *oldHead = [HCTestFailureReporterChain reporterChain];
    
    [HCTestFailureReporterChain addReporter:reporter];
    
    XCTAssertEqual(reporter.successor, oldHead);
}

- (void)test_addReporter_shouldSetHandlerSuccessorEvenIfHeadOfChainHasNotBeenReferenced
{
    HCTestFailureReporter *reporter = [[HCTestFailureReporter alloc] init];

    [HCTestFailureReporterChain addReporter:reporter];

    XCTAssertNotNil(reporter.successor);
}

@end
