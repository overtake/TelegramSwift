//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCXCTestFailureReporter.h"

#import "HCTestFailure.h"

@interface NSObject (PretendMethodExistsOnNSObjectToAvoidLinkingXCTest)

- (void)recordFailureWithDescription:(NSString *)description
                              inFile:(NSString *)filename
                              atLine:(NSUInteger)lineNumber
                            expected:(BOOL)expected;

@end


@implementation HCXCTestFailureReporter

- (BOOL)willHandleFailure:(HCTestFailure *)failure
{
    return [failure.testCase respondsToSelector:@selector(recordFailureWithDescription:inFile:atLine:expected:)];
}

- (void)executeHandlingOfFailure:(HCTestFailure *)failure
{
    [failure.testCase recordFailureWithDescription:failure.reason
                                            inFile:failure.fileName
                                            atLine:failure.lineNumber
                                          expected:YES];
}

@end
