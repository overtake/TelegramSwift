//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCSenTestFailureReporter.h"

#import "HCTestFailure.h"
#import "NSInvocation+OCHamcrest.h"

@interface NSObject (PretendMethodsExistOnNSObjectToAvoidLinkingSenTestingKit)

+ (NSException *)failureInFile:(NSString *)filename
                        atLine:(int)lineNumber
               withDescription:(NSString *)formatString, ...;

- (void)failWithException:(NSException *)exception;

@end


@interface NSInvocation (OCHamcrest_SenTestingKit)
@end

@implementation NSInvocation (OCHamcrest_SenTestingKit)

+ (NSInvocation *)och_SenTestFailureInFile:(NSString *)fileName
                                    atLine:(NSUInteger)lineNumber
                               description:(NSString *)description
{
    // SenTestingKit expects a format string, but NSInvocation does not support varargs.
    // Mask % symbols in the string so they aren't treated as placeholders.
    NSString *massagedDescription = [description stringByReplacingOccurrencesOfString:@"%"
                                                                           withString:@"%%"];

    NSInvocation *invocation = [NSInvocation och_invocationWithTarget:[NSException class]
                                                             selector:@selector(failureInFile:atLine:withDescription:)];
    [invocation setArgument:&fileName atIndex:2];
    [invocation setArgument:&lineNumber atIndex:3];
    [invocation setArgument:&massagedDescription atIndex:4];
    return invocation;
}

@end


@implementation HCSenTestFailureReporter

- (BOOL)willHandleFailure:(HCTestFailure *)failure
{
    return [failure.testCase respondsToSelector:@selector(failWithException:)];
}

- (void)executeHandlingOfFailure:(HCTestFailure *)failure
{
    NSException *exception = [self createExceptionForFailure:failure];
    [failure.testCase failWithException:exception];
}

- (NSException *)createExceptionForFailure:(HCTestFailure *)failure
{
    NSInvocation *invocation = [NSInvocation och_SenTestFailureInFile:failure.fileName
                                                               atLine:failure.lineNumber
                                                          description:failure.reason];
    [invocation invoke];
    __unsafe_unretained NSException *result = nil;
    [invocation getReturnValue:&result];
    return result;
}

@end
