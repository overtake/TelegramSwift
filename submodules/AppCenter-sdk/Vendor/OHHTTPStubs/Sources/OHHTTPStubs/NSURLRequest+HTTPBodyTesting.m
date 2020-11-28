/***********************************************************************************
*
* Copyright (c) 2016 Sebastian Hagedorn, Felix Lamouroux
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

#import "NSURLRequest+HTTPBodyTesting.h"

#if defined(__IPHONE_7_0) || defined(__MAC_10_9)

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Imports

#import "HTTPStubsMethodSwizzling.h"

////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSURLRequest+CustomHTTPBody

NSString * const OHHTTPStubs_HTTPBodyKey = @"HTTPBody";

@implementation NSURLRequest (HTTPBodyTesting)

- (NSData*)OHHTTPStubs_HTTPBody
{
    return [NSURLProtocol propertyForKey:OHHTTPStubs_HTTPBodyKey inRequest:self];
}

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSMutableURLRequest+HTTPBodyTesting

typedef void(*HTTPStubsSetterIMP)(id, SEL, id);
static HTTPStubsSetterIMP orig_setHTTPBody;

static void OHHTTPStubs_setHTTPBody(id self, SEL _cmd, NSData* HTTPBody)
{
    // store the http body via NSURLProtocol
    if (HTTPBody) {
        [NSURLProtocol setProperty:HTTPBody forKey:OHHTTPStubs_HTTPBodyKey inRequest:self];
    } else {
        // unfortunately resetting does not work properly as the NSURLSession also uses this to reset the property
    }

    orig_setHTTPBody(self, _cmd, HTTPBody);
}

/**
 *   Swizzles setHTTPBody: in order to maintain a copy of the http body for later
 *   reference and calls the original implementation.
 *
 *   @warning Should not be used in production, testing only.
 */
@interface NSMutableURLRequest (HTTPBodyTesting) @end

@implementation NSMutableURLRequest (HTTPBodyTesting)

+ (void)load
{
    orig_setHTTPBody = (HTTPStubsSetterIMP)HTTPStubsReplaceMethod(@selector(setHTTPBody:),
                                                                     (IMP)OHHTTPStubs_setHTTPBody,
                                                                     [NSMutableURLRequest class],
                                                                     NO);
}

@end

#endif /* __IPHONE_7_0 || __MAC_10_9 */
