// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACCustomProperties.h"
#import "MSACCustomPropertiesInternal.h"
#import "MSACTestFrameworks.h"

@interface MSACCustomPropertiesTests : XCTestCase

@end

@implementation MSACCustomPropertiesTests

- (void)testKeyValidate {

  // If
  NSString *string = @"test";
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];
  NSNumber *number = @0;
  BOOL boolean = NO;

  // When
  MSACCustomProperties *customProperties = [MSACCustomProperties new];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Null key.
  // When
  NSString *nullKey = nil;
  [customProperties setString:string forKey:nullKey];
  [customProperties setDate:date forKey:nullKey];
  [customProperties setNumber:number forKey:nullKey];
  [customProperties setBool:boolean forKey:nullKey];
  [customProperties clearPropertyForKey:nullKey];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Invalid key.
  // When
  NSString *invalidKey = @"!";
  [customProperties setString:string forKey:invalidKey];
  [customProperties setDate:date forKey:invalidKey];
  [customProperties setNumber:number forKey:invalidKey];
  [customProperties setBool:boolean forKey:invalidKey];
  [customProperties clearPropertyForKey:invalidKey];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Too long key.
  // When
  NSString *tooLongKey = [@"" stringByPaddingToLength:129 withString:@"a" startingAtIndex:0];
  [customProperties setString:string forKey:tooLongKey];
  [customProperties setDate:date forKey:tooLongKey];
  [customProperties setNumber:number forKey:tooLongKey];
  [customProperties setBool:boolean forKey:tooLongKey];
  [customProperties clearPropertyForKey:tooLongKey];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Normal keys.
  // When
  NSString *maxLongKey = [@"" stringByPaddingToLength:128 withString:@"a" startingAtIndex:0];
  [customProperties setString:string forKey:@"t1"];
  [customProperties setDate:date forKey:@"t2"];
  [customProperties setNumber:number forKey:@"t3"];
  [customProperties setBool:boolean forKey:@"t4"];
  [customProperties clearPropertyForKey:@"t5"];
  [customProperties setString:string forKey:maxLongKey];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(6));

  // Already contains keys.
  // When
  [customProperties setString:string forKey:@"t1"];
  [customProperties setDate:date forKey:@"t2"];
  [customProperties setNumber:number forKey:@"t3"];
  [customProperties setBool:boolean forKey:@"t4"];
  [customProperties clearPropertyForKey:@"t5"];
  [customProperties setString:string forKey:maxLongKey];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(6));
}

- (void)testMaxPropertiesCount {

  // If
  const int maxPropertiesCount = 60;
  MSACCustomProperties *customProperties = [MSACCustomProperties new];

  // Maximum properties count.
  // When
  for (int i = 0; i < maxPropertiesCount; i++) {
    [customProperties setNumber:@(i) forKey:[NSString stringWithFormat:@"key%d", i]];
  }

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(maxPropertiesCount));

  // Exceeding maximum properties count.
  // When
  [customProperties setNumber:@(1) forKey:@"extra1"];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(maxPropertiesCount));

  // When
  [customProperties setNumber:@(1) forKey:@"extra2"];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(maxPropertiesCount));
}

- (void)testSetString {

  // If
  NSString *key = @"test";

  // When
  MSACCustomProperties *customProperties = [MSACCustomProperties new];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Null value.
  // When
  NSString *nullValue = nil;
  [customProperties setString:nullValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Too long value.
  // When
  NSString *tooLongValue = [@"" stringByPaddingToLength:129 withString:@"a" startingAtIndex:0];
  [customProperties setString:tooLongValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Empty value.
  // When
  NSString *emptyValue = @"";
  [customProperties setString:emptyValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(1));
  assertThat([customProperties propertiesImmutableCopy][key], is(emptyValue));

  // Normal value.
  // When
  NSString *normalValue = @"test";
  [customProperties setString:normalValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(1));
  assertThat([customProperties propertiesImmutableCopy][key], is(normalValue));

  // Normal value with maximum length.
  // When
  NSString *maxLongValue = [@"" stringByPaddingToLength:128 withString:@"a" startingAtIndex:0];
  [customProperties setString:maxLongValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(1));
  assertThat([customProperties propertiesImmutableCopy][key], is(maxLongValue));
}

- (void)testSetDate {

  // If
  NSString *key = @"test";

  // When
  MSACCustomProperties *customProperties = [MSACCustomProperties new];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Null value.
  // When
  NSDate *nullValue = nil;
  [customProperties setDate:nullValue forKey:key];
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Normal value.
  // When
  NSDate *normalValue = [NSDate dateWithTimeIntervalSince1970:0];
  [customProperties setDate:normalValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(1));
  assertThat([customProperties propertiesImmutableCopy][key], is(normalValue));
}

- (void)testSetNumber {

  // If
  NSString *key = @"test";

  // When
  MSACCustomProperties *customProperties = [MSACCustomProperties new];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Null value.
  // When
  NSNumber *nullValue = nil;
  [customProperties setNumber:nullValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Normal value.
  // When
  NSNumber *normalValue = @0;
  [customProperties setNumber:normalValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(1));
  assertThat([customProperties propertiesImmutableCopy][key], is(normalValue));
}

- (void)testSetInvalidNumber {

  // If
  NSString *key = @"test";

  // When
  MSACCustomProperties *customProperties = [MSACCustomProperties new];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // NaN value.
  // When
  NSNumber *nanValue = [NSNumber numberWithDouble:NAN];
  [customProperties setNumber:nanValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Positive infinite value.
  // When
  NSNumber *positiveInfiniteValue = [NSNumber numberWithDouble:INFINITY];
  [customProperties setNumber:positiveInfiniteValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Negative infinite value.
  // When
  NSNumber *negativeInfiniteValue = [NSNumber numberWithDouble:-INFINITY];
  [customProperties setNumber:negativeInfiniteValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));
}

- (void)testSetBool {

  // If
  NSString *key = @"test";

  // When
  MSACCustomProperties *customProperties = [MSACCustomProperties new];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // Normal value.
  // When
  BOOL normalValue = NO;
  [customProperties setBool:normalValue forKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(1));
  assertThat([customProperties propertiesImmutableCopy][key], is(@(normalValue)));
}

- (void)testClear {

  // If
  NSString *key = @"test";

  // When
  MSACCustomProperties *customProperties = [MSACCustomProperties new];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(0));

  // When
  [customProperties clearPropertyForKey:key];

  // Then
  assertThat([customProperties propertiesImmutableCopy], hasCountOf(1));
  assertThat([customProperties propertiesImmutableCopy][key], is([NSNull null]));
}

@end
