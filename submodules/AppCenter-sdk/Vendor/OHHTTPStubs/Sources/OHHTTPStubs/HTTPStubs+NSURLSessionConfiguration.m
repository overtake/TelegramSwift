/***********************************************************************************
 *
 * Copyright (c) 2012 Olivier Halligon
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/

#import <Foundation/Foundation.h>

#if defined(__IPHONE_7_0) || defined(__MAC_10_9)
#import "HTTPStubs.h"
#import "HTTPStubsMethodSwizzling.h"

//////////////////////////////////////////////////////////////////////////////////////////////////

/**
 *  This helper is used to swizzle NSURLSessionConfiguration constructor methods
 *  defaultSessionConfiguration and ephemeralSessionConfiguration to insert the private
 *  HTTPStubsProtocol into their protocolClasses array so that OHHTTPStubs is automagically
 *  supported when you create a new NSURLSession based on one of there configurations.
 */

typedef NSURLSessionConfiguration*(*SessionConfigConstructor)(id,SEL);
static SessionConfigConstructor orig_defaultSessionConfiguration;
static SessionConfigConstructor orig_ephemeralSessionConfiguration;

static NSURLSessionConfiguration* HTTPStubs_defaultSessionConfiguration(id self, SEL _cmd)
{
    NSURLSessionConfiguration* config = orig_defaultSessionConfiguration(self,_cmd); // call original method
    [HTTPStubs setEnabled:YES forSessionConfiguration:config]; //OHHTTPStubsAddProtocolClassToNSURLSessionConfiguration(config);
    return config;
}

static NSURLSessionConfiguration* HTTPStubs_ephemeralSessionConfiguration(id self, SEL _cmd)
{
    NSURLSessionConfiguration* config = orig_ephemeralSessionConfiguration(self,_cmd); // call original method
    [HTTPStubs setEnabled:YES forSessionConfiguration:config]; //OHHTTPStubsAddProtocolClassToNSURLSessionConfiguration(config);
    return config;
}

@interface NSURLSessionConfiguration(HTTPStubsSupport) @end

@implementation NSURLSessionConfiguration(HTTPStubsSupport)

+(void)load
{
    orig_defaultSessionConfiguration = (SessionConfigConstructor)HTTPStubsReplaceMethod(@selector(defaultSessionConfiguration),
                                                                                          (IMP)HTTPStubs_defaultSessionConfiguration,
                                                                                          [NSURLSessionConfiguration class],
                                                                                          YES);
    orig_ephemeralSessionConfiguration = (SessionConfigConstructor)HTTPStubsReplaceMethod(@selector(ephemeralSessionConfiguration),
                                                                                            (IMP)HTTPStubs_ephemeralSessionConfiguration,
                                                                                            [NSURLSessionConfiguration class],
                                                                                            YES);
}

@end

#endif /* __IPHONE_7_0 || __MAC_10_9 */


