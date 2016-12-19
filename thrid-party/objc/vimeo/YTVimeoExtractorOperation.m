//
//  YTVimeoExtractorOperation.m
//  YTVimeoExtractor
//
//  Created by Soneé Delano John on 11/28/15.
//  Copyright © 2015 Louis Larpin. All rights reserved.
//

#import "YTVimeoExtractorOperation.h"
#import "YTVimeoVideo.h"
#import "YTVimeoVideo+Private.h"
#import "YTVimeoError.h"

NSString *const YTVimeoURL = @"https://vimeo.com/%@";
NSString *const YTVimeoPlayerConfigURL = @"https://player.vimeo.com/video/%@/config";

@interface YTVimeoExtractorOperation ()<NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, readonly) NSURLSession *networkSession;

@property (strong, nonatomic) NSMutableData *buffer;
@property (nonatomic, readonly) NSString *videoIdentifier;


@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isFinished;

@property (nonatomic, readonly) NSString* referer;

@property (strong, nonatomic, readonly) NSURL *vimeoURL;

@end
@implementation YTVimeoExtractorOperation

- (instancetype) init
{
    @throw [NSException exceptionWithName:NSGenericException reason:@"Use the `initWithVideoIdentifier:referer`or `initWithURL:referer` method instead." userInfo:nil];
}
-(instancetype)initWithVideoIdentifier:(NSString *)videoIdentifier referer:(NSString *)videoReferer{
    
    NSParameterAssert(videoIdentifier);
    
    self = [super init];
    
    if (self) {
        
    _videoIdentifier = videoIdentifier;
    _vimeoURL = [NSURL URLWithString:[NSString stringWithFormat:YTVimeoPlayerConfigURL, videoIdentifier]];
    
    // use given referer or default to vimeo domain
    if (videoReferer) {
        _referer = videoReferer;
    } else {
        _referer = [NSString stringWithFormat:YTVimeoURL, videoIdentifier];
      }
   
    }

    return self;
}

- (instancetype)initWithURL:(NSString *)videoURL referer:(NSString *)videoReferer{
    
    return [self initWithVideoIdentifier:videoURL.lastPathComponent referer:videoReferer];
}


#pragma mark - NSOperation

-(BOOL)isAsynchronous{
    
    return YES;
}
- (void) cancel
{
    if (self.isCancelled || self.isFinished)
        return;
    
    [super cancel];
    
    [self.dataTask cancel];
    
    [self finish];
}
-(void)start{
    
    if (self.isCancelled) {
        return;
    }
    
    self.isExecuting = YES;
    
    // build request headers
    NSMutableDictionary *sessionHeaders = [NSMutableDictionary dictionaryWithDictionary:@{@"Content-Type" : @"application/json"}];
    if (self.referer) {
        [sessionHeaders setValue:self.referer forKey:@"Referer"];
    }
    
    // configure the session
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    sessionConfig.HTTPAdditionalHeaders = sessionHeaders;
    
    _networkSession = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
    // start the request
    self.dataTask = [self.networkSession dataTaskWithURL:self.vimeoURL];
    [self.dataTask resume];
    
}

+ (BOOL) automaticallyNotifiesObserversForKey:(NSString *)key
{
    SEL selector = NSSelectorFromString(key);
    return selector == @selector(isExecuting) || selector == @selector(isFinished) || [super automaticallyNotifiesObserversForKey:key];
}

-(void)finishOperationWithError:(NSError *)error{
    
    _error = error;
    [self finish];
    
}

-(void)finishOperationWithVideo:(YTVimeoVideo *)video{
    
    _operationVideo = video;
    _error = nil;
    [self finish];
}
- (void)finish
{
    self.isExecuting = NO;
    self.isFinished = YES;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
   
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    
    if (httpResponse.statusCode != 200) {
        
        if (httpResponse.statusCode == 404) {
           
            NSError *deletedError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorRemovedVideo userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey: @"The requested Vimeo video was deleted."}];
            [self finishOperationWithError:deletedError];
            
        }else if (httpResponse.statusCode == 403){
            
            NSError *privateError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorRestrictedPlayback userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey: @"The requested Vimeo video is private."}];
            [self finishOperationWithError:privateError];
            
        }else{
            NSString *response = [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode];

            NSError *unknownError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorUnknown userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"The requested Vimeo video out this reponse: %@",response]}];
            
          [self finishOperationWithError:unknownError];
        }
        
        // cancel the session
        completionHandler(NSURLSessionResponseCancel);
    }
    
    // initialise data buffer
    NSUInteger capacity = 0;
    if (response.expectedContentLength != NSURLResponseUnknownLength) {
        capacity = (uint)response.expectedContentLength;
    }
    self.buffer = [[NSMutableData alloc] initWithCapacity:capacity];
    
    // continue the task normally
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.buffer appendData:data];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    
    
    if (error) {
        
        if (error.code != -999){
        //Only do this if the task was not cancelled.
        //The following code should never have to execute due to cancelling a task once the response was not 200.
            //However, this is just here to be on the safe side.
        if ([error.domain isEqualToString:NSURLErrorDomain]) {
            
            NSError *networkError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorNetwork userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey:error.localizedDescription}];
            [self finishOperationWithError:networkError];
        
        }else{
            
            NSError *someOtherError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorUnknown userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey:error.localizedDescription}];
            
            [self finishOperationWithError:someOtherError];
        }
    }
    
    }else{
        
        // parse json from buffered data
        NSError *jsonError;
         NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:self.buffer options:NSJSONReadingAllowFragments error:&jsonError];
        if (!jsonData) {
            NSError *invalidIDError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorInvalidVideoIdentifier userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey: @"The video identifier is invalid"}];
            [self finishOperationWithError:invalidIDError];
            return;
        }
        _jsonDict = jsonData;
        YTVimeoVideo *video = [[YTVimeoVideo alloc]initWithIdentifier:self.videoIdentifier info:jsonData];
        [video extractVideoInfoWithCompletionHandler:^(NSError * _Nullable error) {
           
            if (error) {
                
                [self finishOperationWithError:error];
           
            }else{
                
                [self finishOperationWithVideo:video];

            }
            
        }];
    }
    
}
@end
