//
//  YTVimeoExtractor.m
//  YTVimeoExtractor
//
//  Created by Louis Larpin on 18/02/13.
//

#import "YTVimeoExtractor.h"


@interface YTVimeoExtractor ()
@property (nonatomic, strong) NSOperationQueue *extractorOperationQueue;

@end

@implementation YTVimeoExtractor

#pragma mark - Initialize
+(instancetype)sharedExtractor{
    
    static YTVimeoExtractor *sharedExtractor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExtractor = [[self alloc] init];
    });
    return sharedExtractor;
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        _extractorOperationQueue = [[NSOperationQueue alloc]init];
        if ([_extractorOperationQueue respondsToSelector:@selector(qualityOfService)]) {
            _extractorOperationQueue.qualityOfService = NSQualityOfServiceUtility;
        }
        _extractorOperationQueue.name = @"YTVimeoExtractor Queue";
        _extractorOperationQueue.maxConcurrentOperationCount = 4;
    }
    return self;
}

#pragma mark -
-(void)fetchVideoWithIdentifier:(NSString *)videoIdentifier withReferer:(NSString *)referer completionHandler:(void (^)(YTVimeoVideo * __nullable video, NSError * __nullable error))completionHandler{
    
    NSParameterAssert(videoIdentifier);
    if (!completionHandler)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"The `completionHandler` must not be nil." userInfo:nil];
    
    if (videoIdentifier.length == 0) {
        
        NSError *invalidIDError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorInvalidVideoIdentifier userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey: @"The video identifier is invalid."}];

        completionHandler(nil, invalidIDError);

        return;
    }

    YTVimeoExtractorOperation *operation = [[YTVimeoExtractorOperation alloc]initWithVideoIdentifier:videoIdentifier referer:referer];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    operation.completionBlock = ^{
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            if (operation.operationVideo || operation.error)
            {
                NSAssert(!(operation.operationVideo && operation.error), @"Two of these objects cannot be nil");
                completionHandler(operation.operationVideo, operation.error);
            }
           
                        operation.completionBlock = nil;
            
        }];
    };
    
    #pragma clang diagnostic pop
    
    [self.extractorOperationQueue addOperation:operation];
    
}

-(void)fetchVideoWithVimeoURL:(NSString *)videoURL withReferer:(NSString *)referer completionHandler:(void (^)(YTVimeoVideo * __nullable video, NSError * __nullable error))completionHandler{
    
    NSParameterAssert(videoURL);
    if (!completionHandler)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"The `completionHandler` must not be nil." userInfo:nil];
    
    if (videoURL.length == 0) {
        
        NSError *invalidIDError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorInvalidVideoIdentifier userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey: @"The video identifier is invalid."}];
        
        completionHandler(nil, invalidIDError);
        
        return;
    }
    YTVimeoURLParser *parser = [[YTVimeoURLParser alloc]init];
   
    BOOL isValidURL = [parser validateVimeoURL:videoURL];
   
    if (isValidURL == NO) {
        
        NSError *invalidIDError = [NSError errorWithDomain:YTVimeoVideoErrorDomain code:YTVimeoErrorInvalidVideoIdentifier userInfo:@{NSLocalizedDescriptionKey:@"The operation was unable to finish successfully.", NSLocalizedFailureReasonErrorKey: @"The video identifier is invalid."}];
        
        completionHandler(nil, invalidIDError);

        return;
    
    }else{
    
    YTVimeoExtractorOperation *operation = [[YTVimeoExtractorOperation alloc]initWithURL:videoURL referer:referer];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    operation.completionBlock = ^{
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            if (operation.operationVideo || operation.error)
            {
                NSAssert(!(operation.operationVideo && operation.error), @"Either the `operationVideo` or `error` must be nil. Both of the objects cannot be nil.");
                completionHandler(operation.operationVideo, operation.error);
            }
            
            operation.completionBlock = nil;
            
        }];
    };
    
#pragma clang diagnostic pop
    
    [self.extractorOperationQueue addOperation:operation];
  }
}

@end