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

#if ! __has_feature(objc_arc)
#error This file is expected to be compiled with ARC turned ON
#endif

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Imports

#import "HTTPStubs.h"

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Types & Constants

@interface HTTPStubsProtocol : NSURLProtocol @end

static NSTimeInterval const kSlotTime = 0.25; // Must be >0. We will send a chunk of the data from the stream each 'slotTime' seconds

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Interfaces

@interface HTTPStubs()
+ (instancetype)sharedInstance;
@property(atomic, copy) NSMutableArray* stubDescriptors;
@property(atomic, assign) BOOL enabledState;
@property(atomic, copy, nullable) void (^onStubActivationBlock)(NSURLRequest*, id<HTTPStubsDescriptor>, HTTPStubsResponse*);
@property(atomic, copy, nullable) void (^onStubRedirectBlock)(NSURLRequest*, NSURLRequest*, id<HTTPStubsDescriptor>, HTTPStubsResponse*);
@property(atomic, copy, nullable) void (^afterStubFinishBlock)(NSURLRequest*, id<HTTPStubsDescriptor>, HTTPStubsResponse*, NSError*);
@property(atomic, copy, nullable) void (^onStubMissingBlock)(NSURLRequest*);
@end

@interface HTTPStubsDescriptor : NSObject <HTTPStubsDescriptor>
@property(atomic, copy) HTTPStubsTestBlock testBlock;
@property(atomic, copy) HTTPStubsResponseBlock responseBlock;
@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark - HTTPStubsDescriptor Implementation

@implementation HTTPStubsDescriptor

@synthesize name = _name;

+(instancetype)stubDescriptorWithTestBlock:(HTTPStubsTestBlock)testBlock
                             responseBlock:(HTTPStubsResponseBlock)responseBlock
{
    HTTPStubsDescriptor* stub = [HTTPStubsDescriptor new];
    stub.testBlock = testBlock;
    stub.responseBlock = responseBlock;
    return stub;
}

-(NSString*)description
{
    return [NSString stringWithFormat:@"<%@ %p : %@>", self.class, self, self.name];
}

@end




////////////////////////////////////////////////////////////////////////////////
#pragma mark - HTTPStubs Implementation

@implementation HTTPStubs

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Singleton methods

+ (instancetype)sharedInstance
{
    static HTTPStubs *sharedInstance = nil;

    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Setup & Teardown

+ (void)initialize
{
    if (self == [HTTPStubs class])
    {
        [self _setEnable:YES];
    }
}
- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _stubDescriptors = [NSMutableArray array];
        _enabledState = YES; // assume initialize has already been run
    }
    return self;
}

- (void)dealloc
{
    [self.class _setEnable:NO];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public class methods

#pragma mark > Adding & Removing stubs

+(id<HTTPStubsDescriptor>)stubRequestsPassingTest:(HTTPStubsTestBlock)testBlock
                                   withStubResponse:(HTTPStubsResponseBlock)responseBlock
{
    HTTPStubsDescriptor* stub = [HTTPStubsDescriptor stubDescriptorWithTestBlock:testBlock
                                                                     responseBlock:responseBlock];
    [HTTPStubs.sharedInstance addStub:stub];
    return stub;
}

+(BOOL)removeStub:(id<HTTPStubsDescriptor>)stubDesc
{
    return [HTTPStubs.sharedInstance removeStub:stubDesc];
}

+(void)removeAllStubs
{
    [HTTPStubs.sharedInstance removeAllStubs];
}

#pragma mark > Disabling & Re-Enabling stubs

+(void)_setEnable:(BOOL)enable
{
    if (enable)
    {
        [NSURLProtocol registerClass:HTTPStubsProtocol.class];
    }
    else
    {
        [NSURLProtocol unregisterClass:HTTPStubsProtocol.class];
    }
}

+(void)setEnabled:(BOOL)enabled
{
    [HTTPStubs.sharedInstance setEnabled:enabled];
}

+(BOOL)isEnabled
{
    return HTTPStubs.sharedInstance.isEnabled;
}

#if defined(__IPHONE_7_0) || defined(__MAC_10_9)
+ (void)setEnabled:(BOOL)enable forSessionConfiguration:(NSURLSessionConfiguration*)sessionConfig
{
    // Runtime check to make sure the API is available on this version
    if (   [sessionConfig respondsToSelector:@selector(protocolClasses)]
        && [sessionConfig respondsToSelector:@selector(setProtocolClasses:)])
    {
        NSMutableArray * urlProtocolClasses = [NSMutableArray arrayWithArray:sessionConfig.protocolClasses];
        Class protoCls = HTTPStubsProtocol.class;
        if (enable && ![urlProtocolClasses containsObject:protoCls])
        {
            [urlProtocolClasses insertObject:protoCls atIndex:0];
        }
        else if (!enable && [urlProtocolClasses containsObject:protoCls])
        {
            [urlProtocolClasses removeObject:protoCls];
        }
        sessionConfig.protocolClasses = urlProtocolClasses;
    }
    else
    {
        NSLog(@"[OHHTTPStubs] %@ is only available when running on iOS7+/OSX9+. "
              @"Use conditions like 'if ([NSURLSessionConfiguration class])' to only call "
              @"this method if the user is running iOS7+/OSX9+.", NSStringFromSelector(_cmd));
    }
}

+ (BOOL)isEnabledForSessionConfiguration:(NSURLSessionConfiguration *)sessionConfig
{
    // Runtime check to make sure the API is available on this version
    if (   [sessionConfig respondsToSelector:@selector(protocolClasses)]
        && [sessionConfig respondsToSelector:@selector(setProtocolClasses:)])
    {
        NSMutableArray * urlProtocolClasses = [NSMutableArray arrayWithArray:sessionConfig.protocolClasses];
        Class protoCls = HTTPStubsProtocol.class;
        return [urlProtocolClasses containsObject:protoCls];
    }
    else
    {
        NSLog(@"[OHHTTPStubs] %@ is only available when running on iOS7+/OSX9+. "
              @"Use conditions like 'if ([NSURLSessionConfiguration class])' to only call "
              @"this method if the user is running iOS7+/OSX9+.", NSStringFromSelector(_cmd));
        return NO;
    }
}
#endif

#pragma mark > Debug Methods

+(NSArray*)allStubs
{
    return [HTTPStubs.sharedInstance stubDescriptors];
}

+(void)onStubActivation:( nullable void(^)(NSURLRequest* request, id<HTTPStubsDescriptor> stub, HTTPStubsResponse* responseStub) )block
{
    [HTTPStubs.sharedInstance setOnStubActivationBlock:block];
}

+(void)onStubRedirectResponse:( nullable void(^)(NSURLRequest* request, NSURLRequest* redirectRequest, id<HTTPStubsDescriptor> stub, HTTPStubsResponse* responseStub) )block
{
    [HTTPStubs.sharedInstance setOnStubRedirectBlock:block];
}

+(void)afterStubFinish:( nullable void(^)(NSURLRequest* request, id<HTTPStubsDescriptor> stub, HTTPStubsResponse* responseStub, NSError* error) )block
{
    [HTTPStubs.sharedInstance setAfterStubFinishBlock:block];
}

+(void)onStubMissing:( nullable void(^)(NSURLRequest* request) )block
{
    [HTTPStubs.sharedInstance setOnStubMissingBlock:block];
}



////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private instance methods

-(BOOL)isEnabled
{
    BOOL enabled = NO;
    @synchronized(self)
    {
        enabled = _enabledState;
    }
    return enabled;
}

-(void)setEnabled:(BOOL)enable
{
    @synchronized(self)
    {
        _enabledState = enable;
        [self.class _setEnable:_enabledState];
    }
}

-(void)addStub:(HTTPStubsDescriptor*)stubDesc
{
    @synchronized(_stubDescriptors)
    {
        [_stubDescriptors addObject:stubDesc];
    }
}

-(BOOL)removeStub:(id<HTTPStubsDescriptor>)stubDesc
{
    BOOL handlerFound = NO;
    @synchronized(_stubDescriptors)
    {
        handlerFound = [_stubDescriptors containsObject:stubDesc];
        [_stubDescriptors removeObject:stubDesc];
    }
    return handlerFound;
}

-(void)removeAllStubs
{
    @synchronized(_stubDescriptors)
    {
        [_stubDescriptors removeAllObjects];
    }
}

- (HTTPStubsDescriptor*)firstStubPassingTestForRequest:(NSURLRequest*)request
{
    HTTPStubsDescriptor* foundStub = nil;
    @synchronized(_stubDescriptors)
    {
        for(HTTPStubsDescriptor* stub in _stubDescriptors.reverseObjectEnumerator)
        {
            if (stub.testBlock(request))
            {
                foundStub = stub;
                break;
            }
        }
    }
    return foundStub;
}

@end










////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Protocol Class

@interface HTTPStubsProtocol()
@property(assign) BOOL stopped;
@property(strong) HTTPStubsDescriptor* stub;
@property(assign) CFRunLoopRef clientRunLoop;
- (void)executeOnClientRunLoopAfterDelay:(NSTimeInterval)delayInSeconds block:(dispatch_block_t)block;
@end

@implementation HTTPStubsProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    BOOL found = ([HTTPStubs.sharedInstance firstStubPassingTestForRequest:request] != nil);
    if (!found && HTTPStubs.sharedInstance.onStubMissingBlock) {
        HTTPStubs.sharedInstance.onStubMissingBlock(request);
    }
    return found;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)response client:(id<NSURLProtocolClient>)client
{
    // Make super sure that we never use a cached response.
    HTTPStubsProtocol* proto = [super initWithRequest:request cachedResponse:nil client:client];
    proto.stub = [HTTPStubs.sharedInstance firstStubPassingTestForRequest:request];
    return proto;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (NSCachedURLResponse *)cachedResponse
{
    return nil;
}

/** Drop certain headers in accordance with
 * https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1411532-httpadditionalheaders
 */
- (NSMutableURLRequest *)clearAuthHeadersForRequest:(NSMutableURLRequest *)request {
    NSArray* authHeadersToRemove = @[
                                     @"Authorization",
                                     @"Connection",
                                     @"Host",
                                     @"Proxy-Authenticate",
                                     @"Proxy-Authorization",
                                     @"WWW-Authenticate"
                                     ];
    for (NSString* header in authHeadersToRemove) {
        [request setValue:nil forHTTPHeaderField:header];
    }
    return request;
}

- (void)startLoading
{
    self.clientRunLoop = CFRunLoopGetCurrent();
    NSURLRequest* request = self.request;
    id<NSURLProtocolClient> client = self.client;

    if (!self.stub)
    {
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"It seems like the stub has been removed BEFORE the response had time to be sent.",
                                  NSLocalizedFailureReasonErrorKey,
                                  @"For more info, see https://github.com/AliSoftware/OHHTTPStubs/wiki/OHHTTPStubs-and-asynchronous-tests",
                                  NSLocalizedRecoverySuggestionErrorKey,
                                  request.URL, // Stop right here if request.URL is nil
                                  NSURLErrorFailingURLErrorKey,
                                  nil];
        NSError* error = [NSError errorWithDomain:@"OHHTTPStubs" code:500 userInfo:userInfo];
        [client URLProtocol:self didFailWithError:error];
        if (HTTPStubs.sharedInstance.afterStubFinishBlock)
        {
            HTTPStubs.sharedInstance.afterStubFinishBlock(request, self.stub, nil, error);
        }
        return;
    }

    HTTPStubsResponse* responseStub = self.stub.responseBlock(request);

    if (HTTPStubs.sharedInstance.onStubActivationBlock)
    {
        HTTPStubs.sharedInstance.onStubActivationBlock(request, self.stub, responseStub);
    }

    if (responseStub.error == nil)
    {
        NSHTTPURLResponse* urlResponse = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                     statusCode:responseStub.statusCode
                                                                    HTTPVersion:@"HTTP/1.1"
                                                                   headerFields:responseStub.httpHeaders];

        // Cookies handling
        if (request.HTTPShouldHandleCookies && request.URL)
        {
            NSArray* cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:responseStub.httpHeaders forURL:request.URL];
            if (cookies)
            {
                [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookies:cookies forURL:request.URL mainDocumentURL:request.mainDocumentURL];
            }
        }


        NSString* redirectLocation = (responseStub.httpHeaders)[@"Location"];
        NSURL* redirectLocationURL;
        if (redirectLocation)
        {
            redirectLocationURL = [NSURL URLWithString:redirectLocation];
        }
        else
        {
            redirectLocationURL = nil;
        }
        [self executeOnClientRunLoopAfterDelay:responseStub.requestTime block:^{
            if (!self.stopped)
            {
                // Notify if a redirection occurred
                if (((responseStub.statusCode > 300) && (responseStub.statusCode < 400)) && redirectLocationURL)
                {
                    NSURLRequest *redirectRequest;
                    NSMutableURLRequest *mReq;

                    switch (responseStub.statusCode)
                    {
                        case 301:
                        case 302:
                        case 307:
                        case 308: {
                            //Preserve the original request method and body, and set the new location URL
                            mReq = [self.request mutableCopy];
                            [mReq setURL:redirectLocationURL];
                            
                            mReq = [self clearAuthHeadersForRequest:mReq];
                            
                            redirectRequest = (NSURLRequest*)[mReq copy];
                            break;
                        }
                        default:
                            redirectRequest = [NSURLRequest requestWithURL:redirectLocationURL];
                            break;
                    }

                    [client URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:urlResponse];
                    if (HTTPStubs.sharedInstance.onStubRedirectBlock)
                    {
                        HTTPStubs.sharedInstance.onStubRedirectBlock(request, redirectRequest, self.stub, responseStub);
                    }
                }

                // Send the response (even for redirections)
                [client URLProtocol:self didReceiveResponse:urlResponse cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                if(responseStub.inputStream.streamStatus == NSStreamStatusNotOpen)
                {
                    [responseStub.inputStream open];
                }
                [self streamDataForClient:client
                         withStubResponse:responseStub
                               completion:^(NSError * error)
                 {
                     [responseStub.inputStream close];
                     NSError *blockError = nil;
                     if (error==nil)
                     {
                         [client URLProtocolDidFinishLoading:self];
                     }
                     else
                     {
                         [client URLProtocol:self didFailWithError:responseStub.error];
                         blockError = responseStub.error;
                     }
                     if (HTTPStubs.sharedInstance.afterStubFinishBlock)
                     {
                         HTTPStubs.sharedInstance.afterStubFinishBlock(request, self.stub, responseStub, blockError);
                     }
                 }];
            }
        }];
    } else {
        // Send the canned error
        [self executeOnClientRunLoopAfterDelay:responseStub.responseTime block:^{
            if (!self.stopped)
            {
                [client URLProtocol:self didFailWithError:responseStub.error];
                if (HTTPStubs.sharedInstance.afterStubFinishBlock)
                {
                    HTTPStubs.sharedInstance.afterStubFinishBlock(request, self.stub, responseStub, responseStub.error);
                }
            }
        }];
    }
}

- (void)stopLoading
{
    self.stopped = YES;
}

typedef struct {
    NSTimeInterval slotTime;
    double chunkSizePerSlot;
    double cumulativeChunkSize;
} HTTPStubsStreamTimingInfo;

- (void)streamDataForClient:(id<NSURLProtocolClient>)client
           withStubResponse:(HTTPStubsResponse*)stubResponse
                 completion:(void(^)(NSError * error))completion
{
    if (!self.stopped)
    {
        if ((stubResponse.dataSize>0) && stubResponse.inputStream.hasBytesAvailable)
        {
            // Compute timing data once and for all for this stub

            HTTPStubsStreamTimingInfo timingInfo = {
                .slotTime = kSlotTime, // Must be >0. We will send a chunk of data from the stream each 'slotTime' seconds
                .cumulativeChunkSize = 0
            };

            if(stubResponse.responseTime < 0)
            {
                // Bytes send each 'slotTime' seconds = Speed in KB/s * 1000 * slotTime in seconds
                timingInfo.chunkSizePerSlot = (fabs(stubResponse.responseTime) * 1000) * timingInfo.slotTime;
            }
            else if (stubResponse.responseTime < kSlotTime) // includes case when responseTime == 0
            {
                // We want to send the whole data quicker than the slotTime, so send it all in one chunk.
                timingInfo.chunkSizePerSlot = stubResponse.dataSize;
                timingInfo.slotTime = stubResponse.responseTime;
            }
            else
            {
                // Bytes send each 'slotTime' seconds = (Whole size in bytes / response time) * slotTime = speed in bps * slotTime in seconds
                timingInfo.chunkSizePerSlot = ((stubResponse.dataSize/stubResponse.responseTime) * timingInfo.slotTime);
            }

            [self streamDataForClient:client
                           fromStream:stubResponse.inputStream
                           timingInfo:timingInfo
                           completion:completion];
        }
        else
        {
            [self executeOnClientRunLoopAfterDelay:stubResponse.responseTime block:^{
                if (completion && !self.stopped)
                {
                    completion(nil);
                }
            }];
        }
    }
}

- (void) streamDataForClient:(id<NSURLProtocolClient>)client
                  fromStream:(NSInputStream*)inputStream
                  timingInfo:(HTTPStubsStreamTimingInfo)timingInfo
                  completion:(void(^)(NSError * error))completion
{
    NSParameterAssert(timingInfo.chunkSizePerSlot > 0);

    if (inputStream.hasBytesAvailable && (!self.stopped))
    {
        // This is needed in case we computed a non-integer chunkSizePerSlot, to avoid cumulative errors
        double cumulativeChunkSizeAfterRead = timingInfo.cumulativeChunkSize + timingInfo.chunkSizePerSlot;
        NSUInteger chunkSizeToRead = floor(cumulativeChunkSizeAfterRead) - floor(timingInfo.cumulativeChunkSize);
        timingInfo.cumulativeChunkSize = cumulativeChunkSizeAfterRead;

        if (chunkSizeToRead == 0)
        {
            // Nothing to read at this pass, but probably later
            [self executeOnClientRunLoopAfterDelay:timingInfo.slotTime block:^{
                [self streamDataForClient:client fromStream:inputStream
                               timingInfo:timingInfo completion:completion];
            }];
        } else {
            uint8_t* buffer = (uint8_t*)malloc(sizeof(uint8_t)*chunkSizeToRead);
            NSInteger bytesRead = [inputStream read:buffer maxLength:chunkSizeToRead];
            if (bytesRead > 0)
            {
                NSData * data = [NSData dataWithBytes:buffer length:bytesRead];
                // Wait for 'slotTime' seconds before sending the chunk.
                // If bytesRead < chunkSizePerSlot (because we are near the EOF), adjust slotTime proportionally to the bytes remaining
                [self executeOnClientRunLoopAfterDelay:((double)bytesRead / (double)chunkSizeToRead) * timingInfo.slotTime block:^{
                    [client URLProtocol:self didLoadData:data];
                    [self streamDataForClient:client fromStream:inputStream
                                   timingInfo:timingInfo completion:completion];
                }];
            }
            else
            {
                if (completion)
                {
                    // Note: We may also arrive here with no error if we were just at the end of the stream (EOF)
                    // In that case, hasBytesAvailable did return YES (because at the limit of OEF) but nothing were read (because EOF)
                    // But then in that case inputStream.streamError will be nil so that's cool, we won't return an error anyway
                    completion(inputStream.streamError);
                }
            }
            free(buffer);
        }
    }
    else
    {
        if (completion)
        {
            completion(nil);
        }
    }
}

/////////////////////////////////////////////
// Delayed execution utility methods
/////////////////////////////////////////////

- (void)executeOnClientRunLoopAfterDelay:(NSTimeInterval)delayInSeconds block:(dispatch_block_t)block
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CFRunLoopPerformBlock(self.clientRunLoop, kCFRunLoopDefaultMode, block);
        CFRunLoopWakeUp(self.clientRunLoop);
    });
}

@end
