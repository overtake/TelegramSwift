/*
 *  Copyright (c) 2014-2020 Erik Doernenburg and contributors
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

#import <XCTest/XCTest.h>
#import "OCMock.h"


#pragma mark   Helper classes

@interface TestClassWithTypeQualifierMethod : NSObject

- (void)aSpecialMethod:(byref in void *)someArg;

@end

@implementation TestClassWithTypeQualifierMethod

- (void)aSpecialMethod:(byref in __unused void *)someArg
{
}

@end


typedef NSString TypedefString;

@interface TestClassWithTypedefObjectArgument : NSObject

- (NSString *)stringForTypedef:(TypedefString *)string;

@end

@implementation TestClassWithTypedefObjectArgument

- (NSString *)stringForTypedef:(TypedefString *)string
{
    return @"Whatever. Doesn't matter.";
}
@end


@interface TestDelegate : NSObject

- (void)go;

@end

@implementation TestDelegate

- (void)go
{
}

@end

@interface TestClassWithDelegate : NSObject

@property (nonatomic, weak) TestDelegate *delegate;

@end

@implementation TestClassWithDelegate

- (void)run
{
    TestDelegate *delegate = self.delegate;
    [delegate go];
}

@end


@interface NSValueSubclassForTesting : NSValue

@end

@implementation NSValueSubclassForTesting

@end


@interface TestClassWithInitMethod : NSObject
@end

@implementation TestClassWithInitMethod

- (id)initMethodNotCalledJustInit
{
	return [super init];
}

- (id)initMethodWithNestedInit
{
	return [self initMethodNotCalledJustInit];
}

@end


@interface TestClassWithResolveMethods : NSObject
@end

@implementation TestClassWithResolveMethods

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    return [super resolveInstanceMethod:sel];
}

+ (void)classMethod {
}

+ (BOOL)resolveClassMethod:(SEL)sel
{
    return [super resolveClassMethod:sel];
}

- (void)instanceMethod __used
{
}

@end

// This class imitates a bit how CALayer functions internally;
// see https://github.com/erikdoe/ocmock/issues/411
@interface TestClassWithResolveMethodsLikeCALayer : TestClassWithResolveMethods
@end

@implementation TestClassWithResolveMethodsLikeCALayer

+ (void)aMethodWithClass:(Class)cls __used
{
}

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    // resolve must call a class method with self as an argument.
    [self aMethodWithClass:self];
    return NO;
}

@end




#pragma mark   Tests for interaction with runtime and foundation conventions

@interface OCMockObjectRuntimeTests : XCTestCase

@end

@implementation OCMockObjectRuntimeTests

- (void)testRespondsToValidSelector
{
    id mock = [OCMockObject mockForClass:[NSString class]];
    XCTAssertTrue([mock respondsToSelector:@selector(lowercaseString)]);
}


- (void)testDoesNotRespondToInvalidSelector
{
    id mock = [OCMockObject mockForClass:[NSString class]];
    // We use a selector that's not implemented by the mock
    XCTAssertFalse([mock respondsToSelector:@selector(arrayWithArray:)]);
}


- (void)testCanStubValueForKeyMethod
{
    id mock = [OCMockObject mockForClass:[NSObject class]];
    [[[mock stub] andReturn:@"SomeValue"] valueForKey:@"SomeKey"];

    id returnValue = [mock valueForKey:@"SomeKey"];

    XCTAssertEqualObjects(@"SomeValue", returnValue, @"Should have returned value that was set up.");
}


- (void)testMockConformsToProtocolImplementedInSuperclass
{
    id mock = [OCMockObject mockForClass:[NSValueSubclassForTesting class]];
    XCTAssertTrue([mock conformsToProtocol:@protocol(NSCopying)]);

}

- (void)testCanMockNSMutableArray
{
    id mock = [OCMockObject niceMockForClass:[NSMutableArray class]];
    id anArray = [[NSMutableArray alloc] init];
#pragma unused(mock, anArray)
}


- (void)testForwardsIsKindOfClass
{
    id mock = [OCMockObject mockForClass:[NSString class]];
    XCTAssertTrue([mock isKindOfClass:[NSString class]], @"Should have pretended to be the mocked class.");
}


- (void)testWorksWithTypeQualifiers
{
    id myMock = [OCMockObject mockForClass:[TestClassWithTypeQualifierMethod class]];

    XCTAssertNoThrow([[myMock expect] aSpecialMethod:"foo"], @"Should not complain about method with type qualifiers.");
    XCTAssertNoThrow([myMock aSpecialMethod:"foo"], @"Should not complain about method with type qualifiers.");
}

- (void)testWorksWithTypedefsToObjects
{
    id myMock = [OCMockObject mockForClass:[TestClassWithTypedefObjectArgument class]];
    [[[myMock stub] andReturn:@"stubbed"] stringForTypedef:[OCMArg any]];
     id actualReturn = [myMock stringForTypedef:@"Some arg that shouldn't matter"];
     XCTAssertEqualObjects(actualReturn, @"stubbed", @"Should have matched invocation.");
}


#if 0 // can't test this with ARC
- (void)testAdjustsRetainCountWhenStubbingMethodsThatCreateObjects
{
    id mock = [OCMockObject mockForClass:[NSString class]];
    NSString *objectToReturn = [NSString stringWithFormat:@"This is not a %@.", @"string constant"];
#pragma clang diagnostic push
#pragma ide diagnostic ignored "NotReleasedValue"
    [[[mock stub] andReturn:objectToReturn] mutableCopy];
#pragma clang diagnostic pop

    NSUInteger retainCountBefore = [objectToReturn retainCount];
    id returnedObject = [mock mutableCopy];
    [returnedObject release]; // the expectation is that we have to call release after a copy
    NSUInteger retainCountAfter = [objectToReturn retainCount];

    XCTAssertEqualObjects(objectToReturn, returnedObject, @"Should have stubbed copy method");
    XCTAssertEqual(retainCountBefore, retainCountAfter, @"Should have incremented retain count in copy stub.");
}
#endif

- (void)testComplainsWhenUnimplementedMethodIsCalled
{
    id mock = [OCMockObject mockForClass:[NSString class]];
    XCTAssertThrowsSpecificNamed([mock performSelector:@selector(sortedArrayHint)], NSException, NSInvalidArgumentException);
}

- (void)testComplainsWhenAttemptIsMadeToStubInitMethod
{
    id mock = [OCMockObject mockForClass:[NSString class]];
    XCTAssertThrows([[[mock stub] init] andReturn:nil]);
}

- (void)testComplainsWhenAttemptIsMadeToStubInitMethodViaMacro
{
    id mock = [OCMockObject mockForClass:[NSString class]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"
    XCTAssertThrows(OCMStub([mock init]));
#pragma clang diagnostic pop
}


- (void)testMockShouldNotRaiseWhenDescribing
{
    id mock = [OCMockObject mockForClass:[NSObject class]];

    XCTAssertNoThrow(NSLog(@"Testing description handling dummy methods... %@ %@ %@ %@ %@",
            @{@"foo": mock},
            @[mock],
            [NSSet setWithObject:mock],
            [mock description],
            mock),
                    @"asking for the description of a mock shouldn't cause a test to fail.");
}


- (void)testPartialMockShouldNotRaiseWhenDescribing
{
    id mock = [OCMockObject partialMockForObject:[[NSObject alloc] init]];

    XCTAssertNoThrow(NSLog(@"Testing description handling dummy methods... %@ %@ %@ %@ %@",
            @{@"bar": mock},
            @[mock],
            [NSSet setWithObject:mock],
            [mock description],
            mock),
                    @"asking for the description of a mock shouldn't cause a test to fail.");
    [mock stopMocking];
}


- (void)testWeakReferencesShouldStayAround
{
    TestClassWithDelegate *object = [TestClassWithDelegate new];

    TestDelegate *delegate = [TestDelegate new];
    object.delegate = delegate;
    XCTAssertNotNil(object.delegate, @"Should have delegate");

    id mockDelegate = OCMPartialMock(delegate);
    XCTAssertNotNil(object.delegate, @"Should still have delegate");

    [object run];

    OCMVerify([mockDelegate go]);
    XCTAssertNotNil(object.delegate, @"Should still have delegate");
}


- (void)testDynamicSubclassesShouldBeDisposed
{
    int numClassesBefore = objc_getClassList(NULL, 0);

    id mock = [OCMockObject mockForClass:[TestDelegate class]];
    [mock stopMocking];

    int numClassesAfter = objc_getClassList(NULL, 0);
    XCTAssertEqual(numClassesBefore, numClassesAfter, @"Should have disposed dynamically generated classes.");
}


- (void)testClassesWithResolveMethodsCanBeMocked
{
    // If this test fails it will crash due to recursion.
    __unused id mock = OCMClassMock([TestClassWithResolveMethods class]);
}

- (void)testWithClassesWithResolveMethodSimilarToCALayer
{
    // If this test fails it will crash.
    TestClassWithResolveMethodsLikeCALayer *object = [[TestClassWithResolveMethodsLikeCALayer alloc] init];
    __unused id mock = OCMPartialMock(object);
}


#pragma mark    verify mocks work properly when mocking init

- (void)testPartialMockNestedInitReturnsCorrectSelfAndDoesntLeak
{
	__weak id controlRefForMock;
	__weak id controlRefForRealObject;
	@autoreleasepool
	{
		TestClassWithInitMethod *realObject = [TestClassWithInitMethod alloc];
		controlRefForRealObject = realObject;
		id mock = [OCMockObject partialMockForObject:realObject];
		controlRefForMock = mock;

		// Intentionally comparing pointers in all assertions below.

		XCTAssertEqual(mock, [mock initMethodNotCalledJustInit]);
		XCTAssertEqual(realObject, [realObject initMethodNotCalledJustInit], @"No Stub, so realObject should be returned");

		__unused id value = [[[mock stub] andReturn:mock] initMethodNotCalledJustInit];

		XCTAssertEqual(mock, [mock initMethodWithNestedInit]);
		XCTAssertEqual(mock, [realObject initMethodWithNestedInit], @"Stubbed, so mock should be returned");
	}
	XCTAssertNil(controlRefForMock, @"Mock should not be leaked.");
	XCTAssertNil(controlRefForRealObject, @"Real object should not be leaked.");
}

- (void)testPartialMockNestedInitReturnsCorrectSelfAndDoesntLeakWithMacro
{
	__weak id controlRefForMock;
	__weak id controlRefForRealObject;
	@autoreleasepool
	{
		TestClassWithInitMethod *realObject = [TestClassWithInitMethod alloc];
		controlRefForRealObject = realObject;
		id mock = [OCMockObject partialMockForObject:realObject];
		controlRefForMock = mock;

		// Intentionally comparing pointers in all assertions below.

		XCTAssertEqual(mock, [mock initMethodNotCalledJustInit]);
		XCTAssertEqual(realObject, [realObject initMethodNotCalledJustInit], @"No Stub, so realObject should be returned");

		OCMStub([mock initMethodNotCalledJustInit]).andReturn(mock);

		XCTAssertEqual(mock, [mock initMethodWithNestedInit]);
		XCTAssertEqual(mock, [realObject initMethodWithNestedInit], @"Stubbed, so mock should be returned");
	}
	XCTAssertNil(controlRefForMock, @"Mock should not be leaked.");
	XCTAssertNil(controlRefForRealObject, @"Real object should not be leaked.");
}

- (void)testInitStubReturningDifferentObjectDoesntLeak {
	__weak id controlRefForMock;
	__weak id controlRefForRealObject;
	@autoreleasepool
	{
		TestClassWithInitMethod *realObject = [[TestClassWithInitMethod alloc] init];
		controlRefForRealObject = realObject;
		id mock = OCMClassMock([TestClassWithInitMethod class]);
		controlRefForMock = mock;
		__unused id value = [[[mock stub] andReturn:realObject] initMethodNotCalledJustInit];
		XCTAssertEqualObjects(realObject, [mock initMethodNotCalledJustInit], @"Mock should return stubbed object.");
	}
	XCTAssertNil(controlRefForMock, @"Mock should not be leaked.");
	XCTAssertNil(controlRefForRealObject, @"Real object should not be leaked.");
}

- (void)testInitStubReturningDifferentObjectDoesntLeakWithMacro
{
	__weak id controlRefForMock;
	__weak id controlRefForRealObject;
	@autoreleasepool
	{
		TestClassWithInitMethod *realObject = [[TestClassWithInitMethod alloc] init];
		controlRefForRealObject = realObject;
		id mock = OCMClassMock([TestClassWithInitMethod class]);
		controlRefForMock = mock;
		OCMStub([mock initMethodNotCalledJustInit]).andReturn(realObject);
		XCTAssertEqualObjects(realObject, [mock initMethodNotCalledJustInit], @"Mock should return stubbed object.");
	}
	XCTAssertNil(controlRefForMock, @"Mock should not be leaked.");
	XCTAssertNil(controlRefForRealObject, @"Real object should not be leaked.");
}

- (void)testInitStubWithNoReturnValueSetDoesntLeak
{
	__weak id controlRef;
	@autoreleasepool
	{
		id mock = OCMClassMock([TestClassWithInitMethod class]);
		controlRef = mock;
		__unused id value = [[mock stub] initMethodNotCalledJustInit];
	}
	XCTAssertNil(controlRef, @"Mock should not be leaked.");
}

- (void)testInitStubWithNoReturnValueSetDoesntLeakWithMacro
{
	__weak id controlRef;
	@autoreleasepool
	{
		id mock = OCMClassMock([TestClassWithInitMethod class]);
		controlRef = mock;
		OCMStub([mock initMethodNotCalledJustInit]);
	}
	XCTAssertNil(controlRef, @"Mock should not be leaked.");
}

- (void)testInitStubWithNoReturnValueSetThrowsWhenCalled
{
	id mock = OCMClassMock([TestClassWithInitMethod class]);
	__unused id value = [[mock stub] initMethodNotCalledJustInit];
	XCTAssertThrowsSpecificNamed([mock initMethodNotCalledJustInit], NSException, NSInvalidArgumentException);
}

- (void)testInitStubWithNoReturnValueSetThrowsWhenCalledWithMacro
{
	id mock = OCMClassMock([TestClassWithInitMethod class]);
	OCMStub([mock initMethodNotCalledJustInit]);
	XCTAssertThrowsSpecificNamed([mock initMethodNotCalledJustInit], NSException, NSInvalidArgumentException);
}

// TODO: Verify intent of this test added in #391
//- (void)testInitStubWithRejectMacro {
//  id mock = OCMClassMock([TestClassWithInitMethod class]);
//  OCMReject([mock initMethodNotCalledJustInit]);
//}

@end
