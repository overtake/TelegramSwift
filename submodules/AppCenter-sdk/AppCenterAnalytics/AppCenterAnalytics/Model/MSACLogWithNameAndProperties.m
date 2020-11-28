// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACLogWithNameAndProperties.h"
#import "AppCenter+Internal.h"

static NSString *const kMSName = @"name";

@implementation MSACLogWithNameAndProperties

- (NSMutableDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [super serializeToDictionary];

  if (self.name) {
    dict[kMSName] = self.name;
  }
  return dict;
}

- (BOOL)isValid {
  return [super isValid] && MSACLOG_VALIDATE_NOT_NIL(name);
}

- (BOOL)isEqual:(id)object {
  if (![(NSObject *)object isKindOfClass:[MSACLogWithNameAndProperties class]] || ![super isEqual:object]) {
    return NO;
  }
  MSACLogWithNameAndProperties *analyticsLog = (MSACLogWithNameAndProperties *)object;
  return ((!self.name && !analyticsLog.name) || [self.name isEqualToString:analyticsLog.name]);
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    _name = [coder decodeObjectForKey:kMSName];
  }

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.name forKey:kMSName];
}

@end
