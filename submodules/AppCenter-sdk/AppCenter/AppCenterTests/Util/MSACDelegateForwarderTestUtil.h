// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@interface MSACDelegateForwarderTestUtil : NSObject

/**
 * Generate a random class name.
 *
 * @return a class name.
 */
+ (NSString *)generateClassName;

/**
 * Create an instance of an object conforming to the given protocol.
 *
 * @param protocol Protocol to conform to.
 *
 * @return An instance of an object conforming to the given protocol.
 */
+ (id)createInstanceConformingToProtocol:(Protocol *)protocol;

/**
 * Create an instance of an object inheriting from the given base class and conforming to the given protocol.
 *
 * @param class Base class to inherit from.
 * @param protocol Protocol to conform to.
 *
 * @return An instance of an object inheriting from the given base class and conforming to the given protocol.
 */
+ (id)createInstanceWithBaseClass:(Class)class andConformItToProtocol:(Protocol *)protocol;

/**
 * Add a selector with implementation to an instance.
 *
 * @param selector Selector.
 * @param block Implementation.
 * @param instance Instance to extend.
 */
+ (void)addSelector:(SEL)selector implementation:(id)block toInstance:(id)instance;

/**
 * Add a selector with implementation to a class.
 *
 * @param selector Selector.
 * @param block Implementation.
 * @param class Class to extend.
 */
+ (void)addSelector:(SEL)selector implementation:(id)block toClass:(id)class;

@end
