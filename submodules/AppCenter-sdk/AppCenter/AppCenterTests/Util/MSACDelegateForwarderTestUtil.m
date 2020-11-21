// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <objc/runtime.h>

#import "MSACDelegateForwarderTestUtil.h"
#import "MSACUtility.h"

@implementation MSACDelegateForwarderTestUtil

+ (NSString *)generateClassName {
  return [@"C" stringByAppendingString:MSAC_UUID_STRING];
}

+ (id)createInstanceConformingToProtocol:(Protocol *)protocol {
  return [self createInstanceWithBaseClass:[NSObject class] andConformItToProtocol:protocol];
}

+ (id)createInstanceWithBaseClass:(Class)class andConformItToProtocol:(Protocol *)protocol {

  // Generate class name to prevent conflicts in runtime added classes.
  const char *name = [[self generateClassName] UTF8String];
  Class newClass = objc_allocateClassPair(class, name, 0);
  if (protocol) {
    class_addProtocol(newClass, protocol);
  }
  objc_registerClassPair(newClass);
  return [newClass new];
}

+ (void)addSelector:(SEL)selector implementation:(id)block toInstance:(id)instance {
  [self addSelector:selector implementation:block toClass:[instance class]];
}

+ (void)addSelector:(SEL)selector implementation:(id)block toClass:(id)class {
  Method method = class_getInstanceMethod(class, selector);
  const char *types = method_getTypeEncoding(method);
  IMP imp = imp_implementationWithBlock(block);
  class_addMethod(class, selector, imp, types);
}

@end
