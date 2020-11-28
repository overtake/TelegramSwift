// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACException.h"
#import "MSACStackFrame.h"

static NSString *const kMSACExceptionType = @"type";
static NSString *const kMSACMessage = @"message";
static NSString *const kMSACFrames = @"frames";
static NSString *const kMSACStackTrace = @"stackTrace";
static NSString *const kMSACInnerExceptions = @"innerExceptions";
static NSString *const kMSACWrapperSDKName = @"wrapperSdkName";

@implementation MSACException

- (NSMutableDictionary *)serializeToDictionary {

  NSMutableDictionary *dict = [NSMutableDictionary new];

  if (self.type) {
    dict[kMSACExceptionType] = self.type;
  }
  if (self.message) {
    dict[kMSACMessage] = self.message;
  }
  if (self.stackTrace) {
    dict[kMSACStackTrace] = self.stackTrace;
  }
  if (self.wrapperSdkName) {
    dict[kMSACWrapperSDKName] = self.wrapperSdkName;
  }
  if (self.frames) {
    NSMutableArray *framesArray = [NSMutableArray array];
    for (MSACStackFrame *frame in self.frames) {
      [framesArray addObject:[frame serializeToDictionary]];
    }
    dict[kMSACFrames] = framesArray;
  }
  if (self.innerExceptions) {
    NSMutableArray *exceptionsArray = [NSMutableArray array];
    for (MSACException *exception in self.innerExceptions) {
      [exceptionsArray addObject:[exception serializeToDictionary]];
    }
    dict[kMSACInnerExceptions] = exceptionsArray;
  }

  return dict;
}

- (BOOL)isValid {
  return MSACLOG_VALIDATE_NOT_NIL(type) && MSACLOG_VALIDATE(frames, [self.frames count] > 0);
}

- (BOOL)isEqual:(id)object {
  if (![(NSObject *)object isKindOfClass:[MSACException class]]) {
    return NO;
  }
  MSACException *exception = (MSACException *)object;
  return ((!self.type && !exception.type) || [self.type isEqualToString:exception.type]) &&
         ((!self.wrapperSdkName && !exception.wrapperSdkName) || [self.wrapperSdkName isEqualToString:exception.wrapperSdkName]) &&
         ((!self.message && !exception.message) || [self.message isEqualToString:exception.message]) &&
         ((!self.frames && !exception.frames) || [self.frames isEqualToArray:exception.frames]) &&
         ((!self.innerExceptions && !exception.innerExceptions) || [self.innerExceptions isEqualToArray:exception.innerExceptions]) &&
         ((!self.stackTrace && !exception.stackTrace) || [self.stackTrace isEqualToString:exception.stackTrace]);
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super init];
  if (self) {
    _type = [coder decodeObjectForKey:kMSACExceptionType];
    _message = [coder decodeObjectForKey:kMSACMessage];
    _stackTrace = [coder decodeObjectForKey:kMSACStackTrace];
    _frames = [coder decodeObjectForKey:kMSACFrames];
    _innerExceptions = [coder decodeObjectForKey:kMSACInnerExceptions];
    _wrapperSdkName = [coder decodeObjectForKey:kMSACWrapperSDKName];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:self.type forKey:kMSACExceptionType];
  [coder encodeObject:self.message forKey:kMSACMessage];
  [coder encodeObject:self.stackTrace forKey:kMSACStackTrace];
  [coder encodeObject:self.frames forKey:kMSACFrames];
  [coder encodeObject:self.innerExceptions forKey:kMSACInnerExceptions];
  [coder encodeObject:self.wrapperSdkName forKey:kMSACWrapperSDKName];
}

@end
