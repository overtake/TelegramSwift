//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCAssertThat.h>

#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCTestFailure.h>
#import <objc/runtime.h>

@import XCTest;


@interface NSException (OCHamcrest_SenTestFailure)

- (NSString *)filename;
- (NSNumber *)lineNumber;
- (NSString *)description;

+ (NSException *)failureInFile:(NSString *)filename atLine:(int)lineNumber withDescription:(NSString *)formatString, ...;

@end

@implementation NSException (OCHamcrest_SenTestFailure)

- (NSString *)filename
{
    return self.userInfo[@"filename"];
}

- (NSNumber *)lineNumber
{
    return self.userInfo[@"lineNumber"];
}

- (NSString *)description
{
    return self.userInfo[@"description"];
}

+ (NSException *)failureInFile:(NSString *)filename atLine:(int)lineNumber withDescription:(NSString *)formatString, ...
{
    return [self exceptionWithName:@"OCHamcrest_SenTestFailure" reason:nil userInfo:@{
            @"filename" : filename,
            @"lineNumber" : @(lineNumber),
            @"description" : [formatString stringByReplacingOccurrencesOfString:@"%%" withString:@"%"]
    }];
}

@end


// Used to swizzle HCXCTestFailureReporter to not handle failure, so it will fall through to HCSenTestFailureReporter.
static BOOL doNotHandleFailure(id self, SEL _cmd, HCTestFailure *failure)
{
    return NO;
}

@interface MockSenTestCase : XCTestCase
@property (nonatomic, copy) NSString *failureDescription;
@property (nonatomic, copy) NSString *failureFile;
@property (nonatomic, assign) NSUInteger failureLine;
@end

@implementation MockSenTestCase
{
    Class XCTestFailureReporterClass;
    SEL doNotHandleFailureSelector;
}

- (void)setUp
{
    [super setUp];
    XCTestFailureReporterClass = NSClassFromString(@"HCXCTestFailureReporter");
    doNotHandleFailureSelector = NSSelectorFromString(@"doNotHandleFailure:");
    [self addDoNotHandleFailureMethodToXCTestFailureReporter];
    [self swizzleXCTestFailureReporter];
}

- (void)tearDown
{
    [self swizzleXCTestFailureReporter];
    [super tearDown];
}

- (void)addDoNotHandleFailureMethodToXCTestFailureReporter
{
    if (![XCTestFailureReporterClass instancesRespondToSelector:doNotHandleFailureSelector])
    {
        BOOL success = class_addMethod(
                XCTestFailureReporterClass,
                doNotHandleFailureSelector,
                (IMP)doNotHandleFailure,
                "c@:@");
        XCTAssertTrue(success);
    }
}

- (void)swizzleXCTestFailureReporter
{
    Method originalMethod = class_getInstanceMethod(XCTestFailureReporterClass, NSSelectorFromString(@"willHandleFailure:"));
    Method swizzledMethod = class_getInstanceMethod(XCTestFailureReporterClass, doNotHandleFailureSelector);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (void)failWithException:(NSException *)exception
{
    XCTAssertEqualObjects(exception.name, @"OCHamcrest_SenTestFailure");
    self.failureDescription = exception.userInfo[@"description"];
    self.failureFile = exception.userInfo[@"filename"];
    self.failureLine = [exception.userInfo[@"lineNumber"] unsignedIntegerValue];
}

- (void)testSuccessfulMatch_ShouldBeSilent
{
    assertThat(@"foo", equalTo(@"foo"));

    XCTAssertNil(self.failureDescription);
}

- (void)testOCUnitAssertionError_ShouldDescribeExpectedAndActual
{
    NSString *expected = @"EXPECTED";
    NSString *actual = @"ACTUAL";
    NSString *expectedMessage = @"Expected \"EXPECTED\", but was \"ACTUAL\"";

    assertThat(actual, equalTo(expected));

    XCTAssertEqualObjects(self.failureDescription, expectedMessage);
}

- (void)testOCUnitAssertionError_ShouldCorrectlyDescribeStringsWithPercentSymbols
{
    NSString *expected = @"%s";
    NSString *actual = @"%d";
    NSString *expectedMessage = @"Expected \"%s\", but was \"%d\"";

    assertThat(actual, equalTo(expected));
    
    XCTAssertEqualObjects(self.failureDescription, expectedMessage);
}

@end


@interface MockXCTestCase : XCTestCase
@property (nonatomic, assign) BOOL interceptFailure;
@property (nonatomic, assign) NSUInteger failureCount;
@property (nonatomic, copy) NSString *failureDescription;
@property (nonatomic, copy) NSString *failureFile;
@property (nonatomic, assign) NSUInteger failureLine;
@property (nonatomic, assign) BOOL failureExpected;
@end

@implementation MockXCTestCase

- (void)recordFailureWithDescription:(NSString *)description
                              inFile:(NSString *)filePath
                              atLine:(NSUInteger)lineNumber
                            expected:(BOOL)expected
{
    if (!self.interceptFailure)
        [super recordFailureWithDescription:description inFile:filePath atLine:lineNumber expected:expected];
    else
    {
        self.failureCount += 1;
        self.failureDescription = description;
        self.failureFile = filePath;
        self.failureLine = lineNumber;
        self.failureExpected = expected;
    }
}

- (void)testXCTestCase_WithMatch_ShouldNotRecordFailure
{
    self.interceptFailure = YES;
    assertThat(@0, equalTo(@0));
    self.interceptFailure = NO;
    
    XCTAssertEqual(self.failureCount, 0U);
}

- (void)testXCTestCase_WithMismatch_ShouldRecordFailure
{
    self.interceptFailure = YES;
    assertThat(@1, equalTo(@0));
    self.interceptFailure = NO;
    
    XCTAssertEqual(self.failureCount, 1U);
}

- (void)testXCTestCase_WithMismatch_ShouldRecordFailureWithMismatchDescription
{
    NSString *expected = @"EXPECTED";
    NSString *actual = @"ACTUAL";
    NSString *expectedMessage = @"Expected \"EXPECTED\", but was \"ACTUAL\"";
    
    self.interceptFailure = YES;
    assertThat(actual, equalTo(expected));
    self.interceptFailure = NO;
    
    XCTAssertEqualObjects(expectedMessage, self.failureDescription);
}

- (void)testXCTestCase_WithMismatch_ShouldRecordFailureWithCurrentFileName
{
    self.interceptFailure = YES;
    assertThat(@1, equalTo(@0));
    self.interceptFailure = NO;
    
    XCTAssertEqualObjects(
            [NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding],
            self.failureFile);
}

- (void)testXCTestCase_WithMismatch_ShouldRecordFailureWithCurrentLineNumber
{
    self.interceptFailure = YES;
    NSUInteger assertLine = __LINE__ + 1;
    assertThat(@1, equalTo(@0));
    self.interceptFailure = NO;

    XCTAssertEqual(self.failureLine, assertLine);
}

- (void)testXCTestCase_WithMismatch_ShouldRecordFailureAsExpectedMeaningAnAssertionFailure
{
    self.interceptFailure = YES;
    assertThat(@1, equalTo(@0));
    self.interceptFailure = NO;

    XCTAssertTrue(self.failureExpected);
}

@end


@interface GenericTestCase : NSObject
@end

@implementation GenericTestCase
@end

@interface GenericTestCaseTest : XCTestCase
@end

@implementation GenericTestCaseTest
{
    GenericTestCase *testCase;
}

- (void)setUp
{
    [super setUp];
    testCase = [[GenericTestCase alloc] init];
}

- (void)assertThatResultString:(NSString *)resultString containsExpectedString:(NSString *)expectedString
{
    XCTAssertNotNil(resultString);
    XCTAssertTrue([resultString rangeOfString:expectedString].location != NSNotFound);
}

- (void)testGenericTestCase_ShouldRaiseExceptionWithReasonContainingMismatchDescription
{
    NSString *expected = @"EXPECTED";
    NSString *actual = @"ACTUAL";
    NSString *expectedMessage = @"Expected \"EXPECTED\", but was \"ACTUAL\"";

    @try
    {
        HC_assertThatWithLocation(testCase, actual, equalTo(expected), "", 0);
    }
    @catch (NSException* exception)
    {
        [self assertThatResultString:[exception reason] containsExpectedString:expectedMessage];
        return;
    }
    XCTFail(@"Expected exception");
}

- (void)testGenericTestCase_ShouldRaiseExceptionWithReasonContainingLocation
{
    @try
    {
        HC_assertThatWithLocation(testCase, @1, equalTo(@0), "FILENAME", 123);
    }
    @catch (NSException* exception)
    {
        [self assertThatResultString:[exception reason] containsExpectedString:@"FILENAME:123"];
        return;
    }
    XCTFail(@"Expected exception");
}

@end
