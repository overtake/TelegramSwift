//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCInvocationMatcher.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface Match : HCIsEqual
@end

@implementation Match

+ (instancetype)matches:(id)arg
{
    return [[Match alloc] initEqualTo:arg];
}

- (void)describeMismatchOf:(id)item to:(id <HCDescription>)description
{
    [description appendText:@"MISMATCH"];
}

@end


@interface Thingy : NSObject
@end

@implementation Thingy
{
    NSString *result;
}

+ (instancetype) thingyWithResult:(NSString *)result
{
    return [[Thingy alloc] initWithResult:result];
}

- (instancetype)initWithResult:(NSString *)aResult
{
    self = [super init];
    if (self)
        result = aResult;
    return self;
}

- (NSString *)description
{
    return @"Thingy";
}

- (NSString *)result
{
    return result;
}

@end


@interface ShouldNotMatch : NSObject
@end

@implementation ShouldNotMatch

- (NSString *)description
{
    return @"ShouldNotMatch";
}

@end


@interface HCInvocationMatcherTests : MatcherTestCase
@end

@implementation HCInvocationMatcherTests
{
    HCInvocationMatcher *resultMatcher;
}

- (void)setUp
{
    [super setUp];
    Class aClass = [Thingy class];
    NSMethodSignature *signature = [aClass instanceMethodSignatureForSelector:@selector(result)];
    NSInvocation *invocation = [[[NSInvocation class] class] invocationWithMethodSignature:signature];
    [invocation setSelector:@selector(result)];

    resultMatcher = [[HCInvocationMatcher alloc] initWithInvocation:invocation
                                                           matching:[Match matches:@"bar"]];
}

- (void)tearDown
{
    resultMatcher = nil;
    [super tearDown];
}

- (void)test_matches_feature
{
    assertMatches(@"invoke on Thingy", resultMatcher, [Thingy thingyWithResult:@"bar"]);
    assertDescription(@"an object with result \"bar\"", resultMatcher);
}

- (void)test_mismatch_withDefaultLongDescription
{
    assertMismatchDescription(@"<Thingy> result MISMATCH", resultMatcher,
                              [Thingy thingyWithResult:@"foo"]);
}

- (void)test_mismatch_withShortDescription
{
    [resultMatcher setShortMismatchDescription:YES];
    assertMismatchDescription(@"MISMATCH", resultMatcher,
                              [Thingy thingyWithResult:@"foo"]);
}

- (void)test_doesNotMatch_nil
{
    assertMismatchDescription(@"was nil", resultMatcher, nil);
}

- (void)test_doesNotMatch_objectWithoutMethod
{
    assertDoesNotMatch(@"was <ShouldNotMatch>", resultMatcher, [[ShouldNotMatch alloc] init]);
}

- (void)test_objectWithoutMethodShortDescription_isSameAsLongForm
{
    [resultMatcher setShortMismatchDescription:YES];
    assertDoesNotMatch(@"was <ShouldNotMatch>", resultMatcher, [[ShouldNotMatch alloc] init]);
}

@end
