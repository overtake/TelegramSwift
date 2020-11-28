//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt
//  Contribution by Justin Shacklette

#import <OCHamcrest/HCHasProperty.h>

#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCIsNil.h>

#import "MatcherTestCase.h"


@interface Person : NSObject
@property (nonatomic, copy) NSString *name;
- (NSNumber *)shoeSize;
@end

@implementation Person
{
    NSNumber *_shoeSize;
}

- (instancetype)initWithName:(NSString *)name shoeSize:(int)shoeSize
{
    self = [super init];
    if (self)
    {
        _name = name;
        _shoeSize = [[NSNumber alloc] initWithInt:shoeSize];
    }
    return self;
}

- (NSNumber *)shoeSize
{
    return _shoeSize;
}

- (NSString *)description
{
    return @"Person";
}

@end


@interface NotAPerson : NSObject
@end

@implementation NotAPerson

- (NSString *)description
{
    return @"NotAPerson";
}

@end


@interface HasPropertyTests : MatcherTestCase
@end

@implementation HasPropertyTests
{
    Person *joe;
    Person *nobody;
}

- (void)setUp
{
    [super setUp];
    joe = [[Person alloc] initWithName:@"Joe" shoeSize:13];
    nobody = [[Person alloc] initWithName:nil shoeSize:0];
}

- (void)tearDown
{
    joe = nil;
    nobody = nil;
    [super tearDown];
}

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasProperty(@"irrelevant", @"irrelevant");

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_canMatchStringPropertyValues
{
    assertMatches(@"equal string property values", hasProperty(@"name", @"Joe"), joe);
    assertDoesNotMatch(@"unequal string property values", hasProperty(@"name", @"Bob"), joe);
    assertDoesNotMatch(@"unequal string property values", hasProperty(@"name", nil), joe);
}

- (void)test_canMatchStringPropertyValuesWithMatchers
{
    assertMatches(@"equal string property values", hasProperty(@"name", equalTo(@"Joe")), joe);
    assertDoesNotMatch(@"unequal string property values", hasProperty(@"name", equalTo(@"Bob")), joe);
    assertDoesNotMatch(@"unequal string property values", hasProperty(@"name", nilValue()), joe);
}

- (void)test_canMatchNumberPropertyValues
{
    assertMatches(@"equal int property values", hasProperty(@"shoeSize", equalTo(@13)), joe);
    assertDoesNotMatch(@"unequal int property values", hasProperty(@"shoeSize", equalTo(@3)), joe);
    assertDoesNotMatch(@"unequal int property values", hasProperty(@"shoeSize", equalTo(@-3)), joe);
}

- (void)test_nilPropertyValues
{
    assertMatches(@"equal nil property values", hasProperty(@"name", nilValue()), nobody);
    assertDoesNotMatch(@"unequal nil property values", hasProperty(@"name", @"Bob"), nobody);
}

- (void)test_matcherCreation_requiresNonNilPropertyName
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(hasProperty(nil, nil), @"Should require non-nil property name");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"an object with name \"Joe\"", hasProperty(@"name", @"Joe"));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(hasProperty(@"name", @"Joe"), joe);
}

- (void)test_mismatchDescription_onObjectWithoutProperty_shouldSayNoProperty
{
    id matcher = hasProperty(@"name", @"Joe");
    NotAPerson *noProperty = [[NotAPerson alloc] init];

    assertMismatchDescription(@"no name on <NotAPerson>", matcher, noProperty);
}

- (void)test_mismatchDescription_onObjectWithProperty_shouldShowActualValue
{
    id matcher = hasProperty(@"name", @"Bob");

    assertMismatchDescription(@"name was \"Joe\" on <Person>", matcher, joe);
}

- (void)test_describeMismatch
{
    id matcher = hasProperty(@"name", @"Bob");

    assertDescribeMismatch(@"name was \"Joe\" on <Person>", matcher, joe);
}

@end


@interface ValueHolder : NSObject

@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, assign) char charValue;
@property (nonatomic, assign) int intValue;
@property (nonatomic, assign) short shortValue;
@property (nonatomic, assign) long longValue;
@property (nonatomic, assign) long long longLongValue;
@property (nonatomic, assign) unsigned char unsignedCharValue;
@property (nonatomic, assign) unsigned int unsignedIntValue;
@property (nonatomic, assign) unsigned short unsignedShortValue;
@property (nonatomic, assign) unsigned long unsignedLongValue;
@property (nonatomic, assign) unsigned long long unsignedLongLongValue;
@property (nonatomic, assign) float floatValue;
@property (nonatomic, assign) double doubleValue;

@end

@implementation ValueHolder
@end


@interface HasPropertyPrimitiveTests : MatcherTestCase
@end

@implementation HasPropertyPrimitiveTests
{
    ValueHolder *foo;
}

- (void)setUp
{
    [super setUp];
    foo = [[ValueHolder alloc] init];
}

- (void)tearDown
{
    foo = nil;
    [super tearDown];
}

- (void)test_canMatchPrimitiveBoolValues
{
    foo.boolValue = YES;
    assertMatches(@"BOOL should match", hasProperty(@"boolValue", equalTo(@YES)), foo);
    assertDoesNotMatch(@"BOOL should not match", hasProperty(@"boolValue", equalTo(@NO)), foo);
}

- (void)test_canMatchPrimitiveCharValues
{
    foo.charValue = 'a';
    assertMatches(@"char should match", hasProperty(@"charValue", equalTo(@'a')), foo);
    assertDoesNotMatch(@"char should not match", hasProperty(@"charValue", equalTo(@'b')), foo);
}

- (void)test_canMatchPrimitiveIntValues
{
    foo.intValue = INT_MIN;
    assertMatches(@"int should match", hasProperty(@"intValue", equalTo(@INT_MIN)), foo);
    assertDoesNotMatch(@"int should not match", hasProperty(@"intValue", equalTo(@-2)), foo);
}

- (void)test_canMatchPrimitiveShortValues
{
    foo.shortValue = -2;
    assertMatches(@"short should match", hasProperty(@"shortValue", equalTo(@-2)), foo);
    assertDoesNotMatch(@"short should not match", hasProperty(@"shortValue", equalTo(@-1)), foo);
}

- (void)test_canMatchPrimitiveLongValues
{
    foo.longValue = LONG_MIN;
    assertMatches(@"long should match", hasProperty(@"longValue", equalTo(@LONG_MIN)), foo);
    assertDoesNotMatch(@"long should not match",
                       hasProperty(@"longValue", equalTo(@(LONG_MIN + 1))),
                       foo);
}

- (void)test_canMatchPrimitiveLongLongValues
{
    foo.longLongValue = LLONG_MIN;
    assertMatches(@"long long should match",
                  hasProperty(@"longLongValue", equalTo(@(LLONG_MIN))),
                  foo);
    assertDoesNotMatch(@"long long should not match",
                       hasProperty(@"longLongValue", equalTo(@(LLONG_MIN + 1))),
                       foo);
}

- (void)test_canMatchPrimitiveUnsignedCharValues
{
    foo.unsignedCharValue = 'b';
    assertMatches(@"unsigned char should match",
                  hasProperty(@"unsignedCharValue", equalTo(@'b')),
                  foo);
    assertDoesNotMatch(@"unsigned char should not match",
                       hasProperty(@"unsignedCharValue", equalTo(@'c')),
                       foo);
}

- (void)test_canMatchPrimitiveUnsignedIntValues
{
    foo.unsignedIntValue = UINT_MAX;
    assertMatches(@"unsigned int should match",
                  hasProperty(@"unsignedIntValue", equalTo(@UINT_MAX)),
                  foo);
    assertDoesNotMatch(@"unsigned int should not match",
                       hasProperty(@"unsignedIntValue", equalTo(@(UINT_MAX - 1))),
                       foo);
}

- (void)test_canMatchPrimitiveUnsignedShortValues
{
    foo.unsignedShortValue = 2;
    assertMatches(@"unsigned short should match",
                  hasProperty(@"unsignedShortValue", equalTo(@2)),
                  foo);
    assertDoesNotMatch(@"unsigned short should not match",
                       hasProperty(@"unsignedShortValue", equalTo(@3)),
                       foo);
}

- (void)test_canMatchPrimitiveUnsignedLongValues
{
    foo.unsignedLongValue = ULONG_MAX;
    assertMatches(@"unsigned long should match",
                  hasProperty(@"unsignedLongValue", equalTo(@ULONG_MAX)),
                  foo);
    assertDoesNotMatch(@"unsigned long should not match",
                       hasProperty(@"unsignedLongValue", equalTo(@(ULONG_MAX - 1))),
                       foo);
}

- (void)test_canMatchPrimitiveUnsignedLongLongValues
{
    foo.unsignedLongLongValue = ULLONG_MAX;
    assertMatches(@"unsigned long long should match",
                  hasProperty(@"unsignedLongLongValue", equalTo(@ULLONG_MAX)),
                  foo);
    assertDoesNotMatch(@"unsigned long long should not match",
                       hasProperty(@"unsignedLongLongValue", equalTo(@(ULLONG_MAX - 1))),
                       foo);
}

- (void)test_canMatchPrimitiveFloatValues
{
    foo.floatValue = 1.2f;
    assertMatches(@"float should match", hasProperty(@"floatValue", equalTo(@1.2f)), foo);
    assertDoesNotMatch(@"float should not match", hasProperty(@"floatValue", equalTo(@1.3f)), foo);
}

- (void)test_canMatchPrimitiveDoubleValues
{
    foo.doubleValue = DBL_MAX;
    assertMatches(@"double should match", hasProperty(@"doubleValue", equalTo(@DBL_MAX)), foo);
    assertDoesNotMatch(@"double should not match",
                       hasProperty(@"doubleValue", equalTo(@3.14)),
                       foo);
}

@end
