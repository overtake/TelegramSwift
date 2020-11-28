// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACMockKeychainUtil.h"
#import "MSACTestFrameworks.h"

static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSString *> *> *stringsDictionary;
static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSMutableArray *> *> *arraysDictionary;
static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *statusCodes;
static NSString *kMSACDefaultServiceName = @"DefaultServiceName";

@interface MSACMockKeychainUtil ()

@property(nonatomic) id mockKeychainUtil;

@end

@implementation MSACMockKeychainUtil

+ (void)load {
  stringsDictionary = [NSMutableDictionary new];
  arraysDictionary = [NSMutableDictionary new];
  statusCodes = [NSMutableDictionary new];
}

- (instancetype)init {
  self = [super init];
  if (self) {

    // Mock MSACUserDefaults shared method to return this instance.
    _mockKeychainUtil = OCMClassMock([MSACKeychainUtil class]);
    OCMStub([_mockKeychainUtil storeString:[OCMArg any] forKey:[OCMArg any]]).andCall([self class], @selector(storeString:forKey:));
    OCMStub([_mockKeychainUtil storeString:[OCMArg any] forKey:[OCMArg any] withServiceName:[OCMArg any]])
        .andCall([self class], @selector(storeString:forKey:withServiceName:));
    OCMStub([_mockKeychainUtil deleteStringForKey:[OCMArg any]]).andCall([self class], @selector(deleteStringForKey:));
    OCMStub([_mockKeychainUtil deleteStringForKey:[OCMArg any] withServiceName:[OCMArg any]])
        .andCall([self class], @selector(deleteStringForKey:withServiceName:));
    OCMStub([_mockKeychainUtil stringForKey:[OCMArg any] statusCode:[OCMArg anyPointer]])
        .andCall([self class], @selector(stringForKey:statusCode:));
    OCMStub([_mockKeychainUtil stringForKey:[OCMArg any] withServiceName:[OCMArg any] statusCode:[OCMArg anyPointer]])
        .andCall([self class], @selector(stringForKey:withServiceName:statusCode:));
    OCMStub([_mockKeychainUtil clear]).andCall([self class], @selector(clear));
  }
  return self;
}

+ (BOOL)storeString:(NSString *)string forKey:(NSString *)key {
  return [self storeString:string forKey:key withServiceName:kMSACDefaultServiceName];
}

+ (BOOL)storeString:(NSString *)string forKey:(NSString *)key withServiceName:(NSString *)serviceName {

  // Don't store nil objects.
  if (!string) {
    return NO;
  }
  if (!stringsDictionary[serviceName]) {
    stringsDictionary[serviceName] = [NSMutableDictionary new];
  }
  stringsDictionary[serviceName][key] = string;
  return YES;
}

+ (NSString *_Nullable)deleteStringForKey:(NSString *)key {
  return [self deleteStringForKey:key withServiceName:kMSACDefaultServiceName];
}

+ (NSString *_Nullable)deleteStringForKey:(NSString *)key withServiceName:(NSString *)serviceName {
  NSString *value = stringsDictionary[serviceName][key];
  [stringsDictionary[serviceName] removeObjectForKey:key];
  return value;
}

+ (NSString *_Nullable)stringForKey:(NSString *)key statusCode:(OSStatus *)statusCode {
  return [self stringForKey:key withServiceName:kMSACDefaultServiceName statusCode:statusCode];
}

+ (NSString *_Nullable)stringForKey:(NSString *)key withServiceName:(NSString *)serviceName statusCode:(OSStatus *)statusCode {
  OSStatus placeholderStatus = noErr;
  if (statusCodes[serviceName] && statusCodes[serviceName][key]) {
    placeholderStatus = [statusCodes[serviceName][key] intValue];
  }
  if (statusCode) {
    *statusCode = placeholderStatus;
  }
  if (placeholderStatus != noErr) {
    return nil;
  }
  return stringsDictionary[serviceName][key];
}

+ (void)mockStatusCode:(OSStatus)statusCode forKey:(NSString *)key {
  if (!statusCodes[kMSACDefaultServiceName]) {
    statusCodes[kMSACDefaultServiceName] = [NSMutableDictionary new];
  }
  statusCodes[kMSACDefaultServiceName][key] = @(statusCode);
}

+ (BOOL)clear {
  [stringsDictionary[kMSACDefaultServiceName] removeAllObjects];
  [arraysDictionary removeAllObjects];
  return YES;
}

- (void)stopMocking {
  [stringsDictionary removeAllObjects];
  [arraysDictionary removeAllObjects];
  [statusCodes removeAllObjects];
  [self.mockKeychainUtil stopMocking];
}

@end
