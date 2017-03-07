#import "TGVTVideoView.h"

#import <AVFoundation/AVFoundation.h>
#import <libkern/OSAtomic.h>
#import <pthread.h>
#import <VideoToolbox/VideoToolbox.h>
#import "ATQueue.h"

@interface WeakReference : NSObject {
    __weak id nonretainedObjectValue;
    __unsafe_unretained id originalObjectValue;
}
@end


@implementation WeakReference


- (id) initWithObject:(id) object {
    if (self = [super init]) {
        nonretainedObjectValue = originalObjectValue = object;
    }
    return self;
}

+ (WeakReference *) weakReferenceWithObject:(id) object {
    return [[self alloc] initWithObject:object];
}

- (id) nonretainedObjectValue { return nonretainedObjectValue; }
- (void *) originalObjectValue { return (__bridge void *) originalObjectValue; }

// To work appropriately with NSSet
- (BOOL) isEqual:(WeakReference *) object {
    if (![object isKindOfClass:[WeakReference class]]) return NO;
    return object.originalObjectValue == self.originalObjectValue;
}

@end

@interface STimer : NSObject

@end

@interface STimer ()
{
    dispatch_source_t _timer;
    NSTimeInterval _timeout;
    NSTimeInterval _timeoutDate;
    bool _repeat;
    dispatch_block_t _completion;
    ATQueue *_queue;
}

@end

@implementation STimer

- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion queue:(ATQueue *)queue
{
    self = [super init];
    if (self != nil)
    {
        _timeoutDate = INT_MAX;
        
        _timeout = timeout;
        _repeat = repeat;
        _completion = [completion copy];
        _queue = queue;
    }
    return self;
}

- (void)dealloc
{
    if (_timer != nil)
    {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

- (void)start
{
    _timeoutDate = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + _timeout;
    
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [_queue nativeQueue]);
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_timeout * NSEC_PER_SEC)), _repeat ? (int64_t)(_timeout * NSEC_PER_SEC) : DISPATCH_TIME_FOREVER, 0);
    
    dispatch_source_set_event_handler(_timer, ^
                                      {
                                          if (_completion)
                                              _completion();
                                          if (!_repeat)
                                              [self invalidate];
                                      });
    dispatch_resume(_timer);
}

- (void)fireAndInvalidate
{
    if (_completion)
        _completion();
    
    [self invalidate];
}

- (void)invalidate
{
    _timeoutDate = 0;
    
    if (_timer != nil)
    {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

@end


static NSMutableDictionary *sessions() {
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

static OSSpinLock sessionsLock = 0;
static int32_t nextSessionId = 0;


@interface TGVTAcceleratedVideoFrame : NSObject

@property (nonatomic, readonly) CVImageBufferRef buffer;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic,readonly) CMTime outputTime;
@property (nonatomic,strong) NSImage *image;

@end

@implementation TGVTAcceleratedVideoFrame

- (instancetype)initWithBuffer:(CVImageBufferRef)buffer timestamp:(NSTimeInterval)timestamp outputTime:(CMTime)outputTime {
    self = [super init];
    if (self != nil) {
        if (buffer) {
            CFRetain(buffer);
        }
        _timestamp = timestamp;
        _buffer = buffer;
        _outputTime = outputTime;
    }
    return self;
}

- (void)dealloc {
    if (_buffer) {
        CFRelease(_buffer);
    }
}

@end

@class TGVTAcceleratedVideoFrameQueue;
@class TGVTAcceleratedVideoFrameQueueGuard;

@interface TGVTAcceleratedVideoFrameQueueItem : NSObject

@property (nonatomic, strong) TGVTAcceleratedVideoFrameQueue *queue;
@property (nonatomic, strong) NSMutableArray *guards;

@end

@implementation TGVTAcceleratedVideoFrameQueueItem

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _guards = [[NSMutableArray alloc] init];
    }
    return self;
}

@end

@interface TGVTAcceleratedVideoFrameQueueGuardItem : NSObject

@property (nonatomic, weak) TGVTAcceleratedVideoFrameQueueGuard *guard;
@property (nonatomic, strong) NSObject *key;

@end

@implementation TGVTAcceleratedVideoFrameQueueGuardItem

- (instancetype)initWithGuard:(TGVTAcceleratedVideoFrameQueueGuard *)guard key:(NSObject *)key {
    self = [super init];
    if (self != nil) {
        self.guard = guard;
        self.key = key;
    }
    return self;
}

@end

@interface TGVTAcceleratedVideoFrameQueueGuard : NSObject {
    void (^_draw)(TGVTAcceleratedVideoFrame *);
    NSString *_path;
}

@property (nonatomic, strong) NSObject *key;

- (void)draw:(TGVTAcceleratedVideoFrame *)frame;

- (instancetype)initWithDraw:(void (^)(TGVTAcceleratedVideoFrame *))draw path:(NSString *)path;

@end

@interface TGVTAcceleratedVideoFrameQueue : NSObject
{
    int32_t _sessionId;
    ATQueue *_queue;
    void (^_frameReady)(TGVTAcceleratedVideoFrame *);
    
    NSUInteger _maxFrames;
    NSUInteger _fillFrames;
    NSTimeInterval _previousFrameTimestamp;
    
    NSMutableArray *_frames;
    
    STimer *_timer;
    
    NSString *_path;
    AVAssetReader *_reader;
    AVAssetReaderTrackOutput *_output;
    CMTimeRange _timeRange;
    bool _failed;
    
    VTDecompressionSessionRef _decompressionSession;
    
    bool _useVT;
    
}

@property (nonatomic, strong) NSMutableArray *pendingFrames;

@end

@implementation TGVTAcceleratedVideoFrameQueue

- (instancetype)initWithPath:(NSString *)path frameReady:(void (^)(TGVTAcceleratedVideoFrame *))frameReady {
    self = [super init];
    if (self != nil) {

        _useVT = NO;
        
        _sessionId = nextSessionId++;
        OSSpinLockLock(&sessionsLock);
        sessions()[@(_sessionId)] = [WeakReference weakReferenceWithObject:self];
        OSSpinLockUnlock(&sessionsLock);
        
        static ATQueue *queue = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            queue = [[ATQueue alloc] init];
        });
        
        _queue = queue;
        
        _path = path;
        _frameReady = [frameReady copy];
        
        _maxFrames = 5;
        _fillFrames = 1;
        
        _frames = [[NSMutableArray alloc] init];
        _pendingFrames = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    OSSpinLockLock(&sessionsLock);
    [sessions() removeObjectForKey:@(_sessionId)];
    OSSpinLockUnlock(&sessionsLock);
    
    
    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = nil;
    }
}

- (void)dispatch:(void (^)())block {
    [_queue dispatch:block];
}

- (void)beginRequests {
    [_queue dispatch:^{
        [_timer invalidate];
        _timer = nil;
        
        [self checkQueue];
    }];
}

- (void)pauseRequests {
    [_queue dispatch:^{
        [_timer invalidate];
        _timer = nil;
        _previousFrameTimestamp = 0.0;
        [_frames removeAllObjects];
        [_reader cancelReading];
        _output = nil;
        _reader = nil;
        
        if (_decompressionSession) {
            VTDecompressionSessionInvalidate(_decompressionSession);
            CFRelease(_decompressionSession);
            _decompressionSession = nil;
        }
    }];
}

- (void)checkQueue {
    [_timer invalidate];
    _timer = nil;
    
    NSTimeInterval nextDelay = 0.0;
    bool initializedNextDelay = false;
    
    if (_frames.count != 0) {
        nextDelay = 1.0;
        initializedNextDelay = true;
        
        TGVTAcceleratedVideoFrame *firstFrame = _frames[0];
        [_frames removeObjectAtIndex:0];
        
        if (firstFrame.timestamp <= _previousFrameTimestamp) {
            nextDelay = 0.05;
        } else {
            nextDelay = MIN(5.0, firstFrame.timestamp - _previousFrameTimestamp);
        }
        
        _previousFrameTimestamp = firstFrame.timestamp;
        
        if (firstFrame.timestamp <= DBL_EPSILON) {
            nextDelay = 0.0;
        }
        
        if (_frameReady) {
            _frameReady(firstFrame);
        }
    }
    
    if (_frames.count <= _fillFrames) {
        while (_frames.count < _maxFrames) {
            TGVTAcceleratedVideoFrame *frame = [self requestFrame];
            
            if (frame == nil) {
                if (_failed) {
                    nextDelay = 1.0;
                } else {
                    nextDelay = 0.0;
                }
                break;
            } else {
                [_frames addObject:frame];
            }
        }
    }
    
    __weak TGVTAcceleratedVideoFrameQueue *weakSelf = self;
    _timer = [[STimer alloc] initWithTimeout:nextDelay repeat:false completion:^{
        __strong TGVTAcceleratedVideoFrameQueue *strongSelf = weakSelf;
        if (strongSelf != nil) {
            [strongSelf checkQueue];
        }
    } queue:_queue];
    [_timer start];
}

static void TGVTPlayerDecompressionOutputCallback(void *decompressionOutputRefCon, __unused void *sourceFrameRefCon, OSStatus status, __unused VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimestamp, __unused CMTime presentationDuration) {
    @autoreleasepool {
        if (status != noErr) {
            //Console.WriteLine ("Error decompresssing frame at time: {0:#.###} error: {1} infoFlags: {2}", (float)presentationTimeStamp.Value / presentationTimeStamp.TimeScale, (int)status, flags);
            MTLog(@"TGVTPlayerDecompressionOutputCallback error %d", (int)status);
            return;
        }
        
        if (imageBuffer == nil) {
            return;
        }
        
        if (CMTIME_IS_INVALID(presentationTimestamp)) {
            MTLog(@"TGVTPlayerDecompressionOutputCallback invalid timestamp");
            return;
        }
        
        CFAbsoluteTime presentationSeconds = CMTimeGetSeconds(presentationTimestamp);
        
        //TGLog(@"out %f (%d)", presentationSeconds, (int)sourceFrameRefCon);
        
        OSSpinLockLock(&sessionsLock);
        WeakReference *sessionReference = sessions()[@((int32_t)((intptr_t)decompressionOutputRefCon))];
        OSSpinLockUnlock(&sessionsLock);
        
        TGVTAcceleratedVideoFrame *frame = [[TGVTAcceleratedVideoFrame alloc] initWithBuffer:imageBuffer timestamp:presentationSeconds outputTime:presentationTimestamp];
        
        TGVTAcceleratedVideoFrameQueue *queue = sessionReference.nonretainedObjectValue;
        //[queue dispatch:^{
        [queue.pendingFrames addObject:frame];
        //}];
    }
}

- (TGVTAcceleratedVideoFrame *)requestFrame {
    _failed = false;
    for (int i = 0; i < 3; i++) {
        if (_reader == nil) {
            AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:_path] options:nil];
            AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
            if (track != nil) {
                _timeRange = track.timeRange;
                
                if (_useVT) {
                    NSArray *formatDescriptions = track.formatDescriptions;
                    CMVideoFormatDescriptionRef formatDescription = (__bridge CMVideoFormatDescriptionRef)formatDescriptions.firstObject;
                    VTDecompressionOutputCallbackRecord callbackRecord = {&TGVTPlayerDecompressionOutputCallback, (void *)(intptr_t)_sessionId};
                    
                    NSDictionary *imageOutputDescription = nil;
                    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault, formatDescription, NULL, (__bridge CFDictionaryRef)imageOutputDescription, &callbackRecord, &_decompressionSession);
                    if (_decompressionSession == NULL) {
                        if (status != -12983) {
                            MTLog(@"VTDecompressionSessionCreate failed with %d", (int)status);
                        }
                        _failed = true;
                        
                        _reader = nil;
                        _output = nil;
                        _failed = true;
                        return nil;
                    }
                    
                    _output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:nil];
                } else {
                    _output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:@{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
                }
                if (_output != nil) {
                    _output.alwaysCopiesSampleData = false;
                    
                    _reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
                    if ([_reader canAddOutput:_output]) {
                        [_reader addOutput:_output];
                        
                        if (![_reader startReading]) {
                            MTLog(@"Failed to begin reading video frames");
                            _reader = nil;
                            _output = nil;
                            _failed = true;
                            if (_decompressionSession) {
                                VTDecompressionSessionInvalidate(_decompressionSession);
                                CFRelease(_decompressionSession);
                                _decompressionSession = nil;
                            }
                            return nil;
                        }
                    } else {
                        MTLog(@"Failed to add output");
                        _reader = nil;
                        _output = nil;
                        _failed = true;
                        if (_decompressionSession) {
                            VTDecompressionSessionInvalidate(_decompressionSession);
                            CFRelease(_decompressionSession);
                            _decompressionSession = nil;
                        }
                        return nil;
                    }
                }
            }
        }
        
        if (_reader != nil) {
            CMSampleBufferRef sampleVideo = NULL;
            if (([_reader status] == AVAssetReaderStatusReading) && (sampleVideo = [_output copyNextSampleBuffer])) {
                TGVTAcceleratedVideoFrame *videoFrame = nil;
                if (_useVT) {
                    if (_decompressionSession != NULL) {
                        VTDecodeFrameFlags decodeFlags = kVTDecodeFrame_EnableTemporalProcessing;
                        VTDecodeInfoFlags outFlags = 0;
                        VTDecompressionSessionDecodeFrame(_decompressionSession, sampleVideo, decodeFlags, NULL, &outFlags);
                        if (outFlags & kVTDecodeInfo_Asynchronous) {
                            VTDecompressionSessionFinishDelayedFrames(_decompressionSession);
                            VTDecompressionSessionWaitForAsynchronousFrames(_decompressionSession);
                        }
                    }
                    
                    if (_pendingFrames.count >= 3) {
                        TGVTAcceleratedVideoFrame *earliestFrame = nil;
                        for (TGVTAcceleratedVideoFrame *frame in _pendingFrames) {
                            if (earliestFrame == nil || earliestFrame.timestamp > frame.timestamp) {
                                earliestFrame = frame;
                            }
                        }
                        if (earliestFrame != nil) {
                            [_pendingFrames removeObject:earliestFrame];
                        }
                        
                        videoFrame = earliestFrame;
                    } else {
                        if (sampleVideo != NULL) {
                            CFRelease(sampleVideo);
                        }
                        continue;
                    }
                } else {
                    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleVideo);
                    NSTimeInterval presentationSeconds = CMTimeGetSeconds(presentationTime);
                    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleVideo);
                    videoFrame = [[TGVTAcceleratedVideoFrame alloc] initWithBuffer:imageBuffer timestamp:presentationSeconds outputTime:presentationTime];
                    videoFrame.image = [self imageFromSampleBuffer:imageBuffer];
                }
                
                CFRelease(sampleVideo);
                
                return videoFrame;
            } else {
                TGVTAcceleratedVideoFrame *earliestFrame = nil;
                for (TGVTAcceleratedVideoFrame *frame in _pendingFrames) {
                    if (earliestFrame == nil || earliestFrame.timestamp > frame.timestamp) {
                        earliestFrame = frame;
                    }
                }
                if (earliestFrame != nil) {
                    [_pendingFrames removeObject:earliestFrame];
                }
                
                if (earliestFrame != nil){
                    return earliestFrame;
                } else {
                    [_reader cancelReading];
                    _reader = nil;
                    _output = nil;
                    if (_decompressionSession) {
                        VTDecompressionSessionInvalidate(_decompressionSession);
                        CFRelease(_decompressionSession);
                        _decompressionSession = nil;
                    }
                }
            }
        }
    }
    
    return nil;
}


- (NSImage *)imageFromSampleBuffer:(CVImageBufferRef)imageBuffer {
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    NSImage *image = [[NSImage alloc] initWithCGImage:quartzImage size:NSMakeSize(width, height)];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return image;
}

@end

@implementation TGVTAcceleratedVideoFrameQueueGuard

+ (ATQueue *)controlQueue {
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ATQueue alloc] init];
    });
    return queue;
}

static NSMutableDictionary *queueItemsByPath() {
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

+ (void)addGuardForPath:(NSString *)path guard:(TGVTAcceleratedVideoFrameQueueGuard *)guard {
    
    if (path.length == 0) {
        return;
    }
    
    TGVTAcceleratedVideoFrameQueueItem *item = queueItemsByPath()[path];
    if (item == nil) {
        item = [[TGVTAcceleratedVideoFrameQueueItem alloc] init];
        __weak TGVTAcceleratedVideoFrameQueueItem *weakItem = item;
        item.queue = [[TGVTAcceleratedVideoFrameQueue alloc] initWithPath:path frameReady:^(TGVTAcceleratedVideoFrame *frame) {
            [[self controlQueue] dispatch:^{
                __strong TGVTAcceleratedVideoFrameQueueItem *strongItem = weakItem;
                if (strongItem != nil) {
                    for (TGVTAcceleratedVideoFrameQueueGuardItem *guardItem in strongItem.guards) {
                        [guardItem.guard draw:frame];
                    }
                }
            }];
        }];
        queueItemsByPath()[path] = item;
        [item.queue beginRequests];
    }
    [item.guards addObject:[[TGVTAcceleratedVideoFrameQueueGuardItem alloc] initWithGuard:guard key:guard.key]];
}

+ (void)removeGuardFromPath:(NSString *)path key:(NSObject *)key {
    [[self controlQueue] dispatch:^{
        TGVTAcceleratedVideoFrameQueueItem *item = queueItemsByPath()[path];
        if (item != nil) {
            for (NSInteger i = 0; i < (NSInteger)item.guards.count; i++) {
                TGVTAcceleratedVideoFrameQueueGuardItem *guardItem = item.guards[i];
                if ([guardItem.key isEqual:key] || guardItem.guard == nil) {
                    [item.guards removeObjectAtIndex:i];
                    i--;
                }
            }
            
            if (item.guards.count == 0) {
                [queueItemsByPath() removeObjectForKey:path];
                [item.queue pauseRequests];
            }
        }
    }];
}

- (instancetype)initWithDraw:(void (^)(TGVTAcceleratedVideoFrame *))draw path:(NSString *)path {
    self = [super init];
    if (self != nil) {
        _draw = [draw copy];
        _key = [[NSObject alloc] init];
        _path = path;
    }
    return self;
}

- (void)dealloc {
    [TGVTAcceleratedVideoFrameQueueGuard removeGuardFromPath:_path key:_key];
}

- (void)draw:(TGVTAcceleratedVideoFrame *)frame {
    if (_draw) {
        _draw(frame);
    }
}

@end

@interface TGVTVideoView (){

    
    GLfloat *_preferredConversion;
    
    int _program;
    
    NSString *_path;
    
    TGVTAcceleratedVideoFrameQueueGuard *_frameQueueGuard;
    
    OSSpinLock _pendingFramesLock;
    NSMutableArray *_pendingFrames;
    
    CMVideoFormatDescriptionRef _videoInfo;
    
}

@end

@implementation TGVTVideoView



- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
       
        [self setWantsLayer:YES];
        
        _pendingFrames = [[NSMutableArray alloc] init];

    }
    return self;
}


-(void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
}


-(void)dealloc {
    int bp = 0;
    bp ++;
}

- (void)setPath:(NSString *)path {
    
    [[TGVTAcceleratedVideoFrameQueueGuard controlQueue] dispatch:^{
        NSString *realPath = path;
        if (path != nil && [path pathExtension].length == 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
            realPath = [path stringByAppendingPathExtension:@"mov"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:realPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:realPath error:nil];
                [[NSFileManager defaultManager] createSymbolicLinkAtPath:realPath withDestinationPath:[path pathComponents].lastObject error:nil];
            }
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:realPath]) {
            realPath = nil;
        }
        
    
        if (![realPath isEqualToString:_path]) {
            
            
            _path = realPath;
            _frameQueueGuard = nil;
            
            if (_path.length != 0) {
                __weak TGVTVideoView *weakSelf = self;
                _frameQueueGuard = [[TGVTAcceleratedVideoFrameQueueGuard alloc] initWithDraw:^(TGVTAcceleratedVideoFrame *frame) {
                    __strong TGVTVideoView *strongSelf = weakSelf;
                    if (strongSelf != nil) {
                        OSSpinLockLock(&strongSelf->_pendingFramesLock);
                        bool scheduleDisplay = false;
                        if (strongSelf->_pendingFrames.count < 3) {
                            [strongSelf->_pendingFrames addObject:frame];
                            scheduleDisplay = true;
                        }
                        OSSpinLockUnlock(&strongSelf->_pendingFramesLock);
                        
                        if (scheduleDisplay) {
                            TGVTAcceleratedVideoFrame *pendingFrame = nil;
                            OSSpinLockLock(&strongSelf->_pendingFramesLock);
                            if (strongSelf->_pendingFrames.count != 0) {
                                pendingFrame = strongSelf->_pendingFrames.firstObject;
                                [strongSelf->_pendingFrames removeObjectAtIndex:0];
                            }
                            OSSpinLockUnlock(&strongSelf->_pendingFramesLock);
                            
                            if (pendingFrame != nil) {
                                [strongSelf displayFrame:frame];
                            }
                        }
                    }
                } path:_path];
                
                [TGVTAcceleratedVideoFrameQueueGuard addGuardForPath:_path guard:_frameQueueGuard];
            }
    

        }
     
    }];
}

-(void)displayFrame:(TGVTAcceleratedVideoFrame *)frame {

    [[ATQueue mainQueue] dispatch:^{
        self.layer.contents = frame.image;
    }];
    
}




@end
