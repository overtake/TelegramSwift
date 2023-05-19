//
//  WebPImageCoder.m
//  WebPImage <https://github.com/ibireme/WebPImage>
//
//  Created by ibireme on 15/5/13.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "WebPImageCoder.h"
#import <CoreFoundation/CoreFoundation.h>
#import <ImageIO/ImageIO.h>
#import <Accelerate/Accelerate.h>
#import <objc/runtime.h>
#import <pthread.h>

#import "decode.h"
#import "encode.h"
#import "demux.h"
#import "mux.h"



static void WebPCGDataProviderReleaseDataCallback(void *info, const void *data, size_t size) {
    if (info) free(info);
}
static inline size_t WebPImageByteAlign(size_t size, size_t alignment) {
    return ((size + (alignment - 1)) / alignment) * alignment;
}

CGColorSpaceRef WebPCGColorSpaceGetDeviceRGB() {
    static CGColorSpaceRef space;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        space = CGColorSpaceCreateDeviceRGB();
    });
    return space;
}

CGColorSpaceRef WebPCGColorSpaceGetDeviceGray() {
    static CGColorSpaceRef space;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        space = CGColorSpaceCreateDeviceGray();
    });
    return space;
}

BOOL WebPCGColorSpaceIsDeviceRGB(CGColorSpaceRef space) {
    return space && CFEqual(space, WebPCGColorSpaceGetDeviceRGB());
}

BOOL WebPCGColorSpaceIsDeviceGray(CGColorSpaceRef space) {
    return space && CFEqual(space, WebPCGColorSpaceGetDeviceGray());
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Decoder

@implementation WebPImageFrame

- (id)copyWithZone:(NSZone *)zone {
    WebPImageFrame *frame = [self.class new];
    frame.index = _index;
    frame.width = _width;
    frame.height = _height;
    frame.offsetX = _offsetX;
    frame.offsetY = _offsetY;
    frame.duration = _duration;
    frame.dispose = _dispose;
    frame.blend = _blend;
    frame.image = _image.copy;
    return frame;
}
@end

// Internal frame object.
@interface _WebPImageDecoderFrame : WebPImageFrame
@property (nonatomic, assign) BOOL hasAlpha;                ///< Whether frame has alpha.
@property (nonatomic, assign) BOOL isFullSize;              ///< Whether frame fill the canvas.
@property (nonatomic, assign) NSUInteger blendFromIndex;    ///< Blend from frame index to current frame.
@end

@implementation _WebPImageDecoderFrame
- (id)copyWithZone:(NSZone *)zone {
    _WebPImageDecoderFrame *frame = [super copyWithZone:zone];
    frame.hasAlpha = _hasAlpha;
    frame.isFullSize = _isFullSize;
    frame.blendFromIndex = _blendFromIndex;
    return frame;
}
@end


@implementation WebPImageDecoder {
    pthread_mutex_t _lock; // recursive lock
    
    BOOL _sourceTypeDetected;
    WebPDemuxer *_webpSource;
    
    dispatch_semaphore_t _framesLock;
    NSArray *_frames;
    BOOL _needBlend;
    NSUInteger _blendFrameIndex;
    CGContextRef _blendCanvas;
}

- (void)dealloc {
    if (_webpSource) WebPDemuxDelete(_webpSource);
    if (_blendCanvas) CFRelease(_blendCanvas);
    pthread_mutex_destroy(&_lock);
}

+ (instancetype)decoderWithData:(NSData *)data scale:(CGFloat)scale {
    if (!data) return nil;
    WebPImageDecoder *decoder = [[WebPImageDecoder alloc] initWithScale:scale];
    [decoder updateData:data final:YES];
    if (decoder.frameCount == 0) return nil;
    return decoder;
}

- (instancetype)init {
    return [self initWithScale:[NSScreen mainScreen].backingScaleFactor];
}

- (instancetype)initWithScale:(CGFloat)scale {
    self = [super init];
    if (scale <= 0) scale = 1;
    _scale = scale;
    _framesLock = dispatch_semaphore_create(1);
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init (&attr);
    pthread_mutexattr_settype (&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init (&_lock, &attr);
    pthread_mutexattr_destroy (&attr);
    
    return self;
}

- (BOOL)updateData:(NSData *)data final:(BOOL)final {
    BOOL result = NO;
    pthread_mutex_lock(&_lock);
    result = [self _updateData:data final:final];
    pthread_mutex_unlock(&_lock);
    return result;
}

- (WebPImageFrame *)frameAtIndex:(NSUInteger)index decodeForDisplay:(BOOL)decodeForDisplay {
    WebPImageFrame *result = nil;
    pthread_mutex_lock(&_lock);
    result = [self _frameAtIndex:index decodeForDisplay:decodeForDisplay];
    pthread_mutex_unlock(&_lock);
    return result;
}

- (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index {
    NSTimeInterval result = 0;
    dispatch_semaphore_wait(_framesLock, DISPATCH_TIME_FOREVER);
    if (index < _frames.count) {
        result = ((_WebPImageDecoderFrame *)_frames[index]).duration;
    }
    dispatch_semaphore_signal(_framesLock);
    return result;
}
- (BOOL)_updateData:(NSData *)data final:(BOOL)final {
    if (_finalized) return NO;
    if (data.length < _data.length) return NO;
    _finalized = final;
    _data = data;
    
    _type = WebPImageTypeWebP;
    [self _updateSource];
    _sourceTypeDetected = YES;
    return YES;
}

- (WebPImageFrame *)_frameAtIndex:(NSUInteger)index decodeForDisplay:(BOOL)decodeForDisplay {
    if (index >= _frames.count) return 0;
    _WebPImageDecoderFrame *frame = [(_WebPImageDecoderFrame *)_frames[index] copy];
    BOOL decoded = NO;
    BOOL extendToCanvas = NO;
    if (decodeForDisplay) { // ICO contains multi-size frame and should not extend to canvas.
        extendToCanvas = YES;
    }
    
    if (!_needBlend) {
        CGImageRef imageRef = [self _newUnblendedImageAtIndex:index extendToCanvas:extendToCanvas decoded:&decoded];
        if (!imageRef) return nil;
        if (decodeForDisplay && !decoded) {
            CGImageRef imageRefDecoded = WebPCGImageCreateDecodedCopy(imageRef, YES);
            if (imageRefDecoded) {
                CFRelease(imageRef);
                imageRef = imageRefDecoded;
                decoded = YES;
            }
        }
        
        NSImage *image = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef))];
        CFRelease(imageRef);
        if (!image) return nil;
        frame.image = image;
        return frame;
    }
    
    // blend
    if (![self _createBlendContextIfNeeded]) return nil;
    CGImageRef imageRef = NULL;
    
    if (_blendFrameIndex + 1 == frame.index) {
        imageRef = [self _newBlendedImageWithFrame:frame];
        _blendFrameIndex = index;
    } else { // should draw canvas from previous frame
        _blendFrameIndex = NSNotFound;
        CGContextClearRect(_blendCanvas, CGRectMake(0, 0, _width, _height));
        
        if (frame.blendFromIndex == frame.index) {
            CGImageRef unblendedImage = [self _newUnblendedImageAtIndex:index extendToCanvas:NO decoded:NULL];
            if (unblendedImage) {
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendedImage);
                CFRelease(unblendedImage);
            }
            imageRef = CGBitmapContextCreateImage(_blendCanvas);
            if (frame.dispose == WebPImageDisposeBackground) {
                CGContextClearRect(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height));
            }
            _blendFrameIndex = index;
        } else { // canvas is not ready
            for (uint32_t i = (uint32_t)frame.blendFromIndex; i <= (uint32_t)frame.index; i++) {
                if (i == frame.index) {
                    if (!imageRef) imageRef = [self _newBlendedImageWithFrame:frame];
                } else {
                    [self _blendImageWithFrame:_frames[i]];
                }
            }
            _blendFrameIndex = index;
        }
    }
    
    if (!imageRef) return nil;
    NSImage *image = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef))];
    CFRelease(imageRef);
    if (!image) return nil;
    
    frame.image = image;
    if (extendToCanvas) {
        frame.width = _width;
        frame.height = _height;
        frame.offsetX = 0;
        frame.offsetY = 0;
        frame.dispose = WebPImageDisposeNone;
        frame.blend = WebPImageBlendNone;
    }
    return frame;
}


#pragma private

- (void)_updateSource {
    [self _updateSourceWebP];
}

- (void)_updateSourceWebP {
    _width = 0;
    _height = 0;
    _loopCount = 0;
    if (_webpSource) WebPDemuxDelete(_webpSource);
    _webpSource = NULL;
    dispatch_semaphore_wait(_framesLock, DISPATCH_TIME_FOREVER);
    _frames = nil;
    dispatch_semaphore_signal(_framesLock);
    
    WebPData webPData = {0};
    webPData.bytes = _data.bytes;
    webPData.size = _data.length;
    WebPDemuxer *demuxer = WebPDemux(&webPData);
    if (!demuxer) return;
    
    uint32_t webpFrameCount = WebPDemuxGetI(demuxer, WEBP_FF_FRAME_COUNT);
    uint32_t webpLoopCount =  WebPDemuxGetI(demuxer, WEBP_FF_LOOP_COUNT);
    uint32_t canvasWidth = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_WIDTH);
    uint32_t canvasHeight = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_HEIGHT);
    if (webpFrameCount == 0 || canvasWidth < 1 || canvasHeight < 1) {
        WebPDemuxDelete(demuxer);
        return;
    }
    
    NSMutableArray *frames = [NSMutableArray new];
    BOOL needBlend = NO;
    uint32_t iterIndex = 0;
    uint32_t lastBlendIndex = 0;
    WebPIterator iter = {0};
    if (WebPDemuxGetFrame(demuxer, 1, &iter)) { // one-based index...
        do {
            _WebPImageDecoderFrame *frame = [_WebPImageDecoderFrame new];
            [frames addObject:frame];
            if (iter.dispose_method == WEBP_MUX_DISPOSE_BACKGROUND) {
                frame.dispose = WebPImageDisposeBackground;
            }
            if (iter.blend_method == WEBP_MUX_BLEND) {
                frame.blend = WebPImageBlendOver;
            }
            
            int canvasWidth = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_WIDTH);
            int canvasHeight = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_HEIGHT);
            frame.index = iterIndex;
            frame.duration = iter.duration / 1000.0;
            frame.width = iter.width;
            frame.height = iter.height;
            frame.hasAlpha = iter.has_alpha;
            frame.blend = iter.blend_method == WEBP_MUX_BLEND;
            frame.offsetX = iter.x_offset;
            frame.offsetY = canvasHeight - iter.y_offset - iter.height;
            
            BOOL sizeEqualsToCanvas = (iter.width == canvasWidth && iter.height == canvasHeight);
            BOOL offsetIsZero = (iter.x_offset == 0 && iter.y_offset == 0);
            frame.isFullSize = (sizeEqualsToCanvas && offsetIsZero);
            
            if ((!frame.blend || !frame.hasAlpha) && frame.isFullSize) {
                frame.blendFromIndex = lastBlendIndex = iterIndex;
            } else {
                if (frame.dispose && frame.isFullSize) {
                    frame.blendFromIndex = lastBlendIndex;
                    lastBlendIndex = iterIndex + 1;
                } else {
                    frame.blendFromIndex = lastBlendIndex;
                }
            }
            if (frame.index != frame.blendFromIndex) needBlend = YES;
            iterIndex++;
        } while (WebPDemuxNextFrame(&iter));
        WebPDemuxReleaseIterator(&iter);
    }
    if (frames.count != webpFrameCount) {
        WebPDemuxDelete(demuxer);
        return;
    }
    
    _width = canvasWidth;
    _height = canvasHeight;
    _frameCount = frames.count;
    _loopCount = webpLoopCount;
    _needBlend = needBlend;
    _webpSource = demuxer;
    dispatch_semaphore_wait(_framesLock, DISPATCH_TIME_FOREVER);
    _frames = frames;
    dispatch_semaphore_signal(_framesLock);
}

- (CGImageRef)_newUnblendedImageAtIndex:(NSUInteger)index
                         extendToCanvas:(BOOL)extendToCanvas
                                decoded:(BOOL *)decoded CF_RETURNS_RETAINED {
    
    if (!_finalized && index > 0) return NULL;
    if (_frames.count <= index) return NULL;
    
    if (_webpSource) {
        WebPIterator iter;
        if (!WebPDemuxGetFrame(_webpSource, (int)(index + 1), &iter)) return NULL; // demux webp frame data
        // frame numbers are one-based in webp -----------^
        
        int frameWidth = iter.width;
        int frameHeight = iter.height;
        if (frameWidth < 1 || frameHeight < 1) return NULL;
        
        int width = extendToCanvas ? (int)_width : frameWidth;
        int height = extendToCanvas ? (int)_height : frameHeight;
        if (width > _width || height > _height) return NULL;
        
        const uint8_t *payload = iter.fragment.bytes;
        size_t payloadSize = iter.fragment.size;
        
        WebPDecoderConfig config;
        if (!WebPInitDecoderConfig(&config)) {
            WebPDemuxReleaseIterator(&iter);
            return NULL;
        }
        if (WebPGetFeatures(payload , payloadSize, &config.input) != VP8_STATUS_OK) {
            WebPDemuxReleaseIterator(&iter);
            return NULL;
        }
        
        size_t bitsPerComponent = 8;
        size_t bitsPerPixel = 32;
        size_t bytesPerRow = WebPImageByteAlign(bitsPerPixel / 8 * width, 32);
        size_t length = bytesPerRow * height;
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst; //bgrA
        
        void *pixels = calloc(1, length);
        if (!pixels) {
            WebPDemuxReleaseIterator(&iter);
            return NULL;
        }
        
        config.output.colorspace = MODE_bgrA;
        config.output.is_external_memory = 1;
        config.output.u.RGBA.rgba = pixels;
        config.output.u.RGBA.stride = (int)bytesPerRow;
        config.output.u.RGBA.size = length;
        VP8StatusCode result = WebPDecode(payload, payloadSize, &config); // decode
        if ((result != VP8_STATUS_OK) && (result != VP8_STATUS_NOT_ENOUGH_DATA)) {
            WebPDemuxReleaseIterator(&iter);
            free(pixels);
            return NULL;
        }
        WebPDemuxReleaseIterator(&iter);
        
        if (extendToCanvas && (iter.x_offset != 0 || iter.y_offset != 0)) {
            void *tmp = calloc(1, length);
            if (tmp) {
                vImage_Buffer src = {pixels, height, width, bytesPerRow};
                vImage_Buffer dest = {tmp, height, width, bytesPerRow};
                vImage_CGAffineTransform transform = {1, 0, 0, 1, iter.x_offset, -iter.y_offset};
                uint8_t backColor[4] = {0};
                vImage_Error error = vImageAffineWarpCG_ARGB8888(&src, &dest, NULL, &transform, backColor, kvImageBackgroundColorFill);
                if (error == kvImageNoError) {
                    memcpy(pixels, tmp, length);
                }
                free(tmp);
            }
        }
        
        CGDataProviderRef provider = CGDataProviderCreateWithData(pixels, pixels, length, WebPCGDataProviderReleaseDataCallback);
        if (!provider) {
            free(pixels);
            return NULL;
        }
        pixels = NULL; // hold by provider
        
        CGImageRef image = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, WebPCGColorSpaceGetDeviceRGB(), bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);
        CFRelease(provider);
        if (decoded) *decoded = YES;
        return image;
    }
    
    return NULL;
}

- (BOOL)_createBlendContextIfNeeded {
    if (!_blendCanvas) {
        _blendFrameIndex = NSNotFound;
        _blendCanvas = CGBitmapContextCreate(NULL, _width, _height, 8, 0, WebPCGColorSpaceGetDeviceRGB(), kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
    }
    BOOL suc = _blendCanvas != NULL;
    return suc;
}

- (void)_blendImageWithFrame:(_WebPImageDecoderFrame *)frame {
    if (frame.dispose == WebPImageDisposePrevious) {
        // nothing
    } else if (frame.dispose == WebPImageDisposeBackground) {
        CGContextClearRect(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height));
    } else { // no dispose
        if (frame.blend == WebPImageBlendOver) {
            CGImageRef unblendImage = [self _newUnblendedImageAtIndex:frame.index extendToCanvas:NO decoded:NULL];
            if (unblendImage) {
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendImage);
                CFRelease(unblendImage);
            }
        } else {
            CGContextClearRect(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height));
            CGImageRef unblendImage = [self _newUnblendedImageAtIndex:frame.index extendToCanvas:NO decoded:NULL];
            if (unblendImage) {
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendImage);
                CFRelease(unblendImage);
            }
        }
    }
}

- (CGImageRef)_newBlendedImageWithFrame:(_WebPImageDecoderFrame *)frame CF_RETURNS_RETAINED{
    CGImageRef imageRef = NULL;
    if (frame.dispose == WebPImageDisposePrevious) {
        if (frame.blend == WebPImageBlendOver) {
            CGImageRef previousImage = CGBitmapContextCreateImage(_blendCanvas);
            CGImageRef unblendImage = [self _newUnblendedImageAtIndex:frame.index extendToCanvas:NO decoded:NULL];
            if (unblendImage) {
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendImage);
                CFRelease(unblendImage);
            }
            imageRef = CGBitmapContextCreateImage(_blendCanvas);
            CGContextClearRect(_blendCanvas, CGRectMake(0, 0, _width, _height));
            if (previousImage) {
                CGContextDrawImage(_blendCanvas, CGRectMake(0, 0, _width, _height), previousImage);
                CFRelease(previousImage);
            }
        } else {
            CGImageRef previousImage = CGBitmapContextCreateImage(_blendCanvas);
            CGImageRef unblendImage = [self _newUnblendedImageAtIndex:frame.index extendToCanvas:NO decoded:NULL];
            if (unblendImage) {
                CGContextClearRect(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height));
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendImage);
                CFRelease(unblendImage);
            }
            imageRef = CGBitmapContextCreateImage(_blendCanvas);
            CGContextClearRect(_blendCanvas, CGRectMake(0, 0, _width, _height));
            if (previousImage) {
                CGContextDrawImage(_blendCanvas, CGRectMake(0, 0, _width, _height), previousImage);
                CFRelease(previousImage);
            }
        }
    } else if (frame.dispose == WebPImageDisposeBackground) {
        if (frame.blend == WebPImageBlendOver) {
            CGImageRef unblendImage = [self _newUnblendedImageAtIndex:frame.index extendToCanvas:NO decoded:NULL];
            if (unblendImage) {
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendImage);
                CFRelease(unblendImage);
            }
            imageRef = CGBitmapContextCreateImage(_blendCanvas);
            CGContextClearRect(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height));
        } else {
            CGImageRef unblendImage = [self _newUnblendedImageAtIndex:frame.index extendToCanvas:NO decoded:NULL];
            if (unblendImage) {
                CGContextClearRect(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height));
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendImage);
                CFRelease(unblendImage);
            }
            imageRef = CGBitmapContextCreateImage(_blendCanvas);
            CGContextClearRect(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height));
        }
    } else { // no dispose
        if (frame.blend == WebPImageBlendOver) {
            CGImageRef unblendImage = [self _newUnblendedImageAtIndex:frame.index extendToCanvas:NO decoded:NULL];
            if (unblendImage) {
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendImage);
                CFRelease(unblendImage);
            }
            imageRef = CGBitmapContextCreateImage(_blendCanvas);
        } else {
            CGImageRef unblendImage = [self _newUnblendedImageAtIndex:frame.index extendToCanvas:NO decoded:NULL];
            if (unblendImage) {
                CGContextClearRect(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height));
                CGContextDrawImage(_blendCanvas, CGRectMake(frame.offsetX, frame.offsetY, frame.width, frame.height), unblendImage);
                CFRelease(unblendImage);
            }
            imageRef = CGBitmapContextCreateImage(_blendCanvas);
        }
    }
    return imageRef;
}

@end



CGImageRef WebPCGImageCreateDecodedCopy(CGImageRef imageRef, BOOL decodeForDisplay) {
    if (!imageRef) return NULL;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    if (width == 0 || height == 0) return NULL;
    
    if (decodeForDisplay) { //decode with redraw (may lose some precision)
        CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef) & kCGBitmapAlphaInfoMask;
        BOOL hasAlpha = NO;
        if (alphaInfo == kCGImageAlphaPremultipliedLast ||
            alphaInfo == kCGImageAlphaPremultipliedFirst ||
            alphaInfo == kCGImageAlphaLast ||
            alphaInfo == kCGImageAlphaFirst) {
            hasAlpha = YES;
        }
        // BGRA8888 (premultiplied) or BGRX8888
        // same as UIGraphicsBeginImageContext() and -[UIView drawRect:]
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
        bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
        CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, WebPCGColorSpaceGetDeviceRGB(), bitmapInfo);
        if (!context) return NULL;
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef); // decode
        CGImageRef newImage = CGBitmapContextCreateImage(context);
        CFRelease(context);
        return newImage;
        
    } else {
        CGColorSpaceRef space = CGImageGetColorSpace(imageRef);
        size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
        size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
        size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
        CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
        if (bytesPerRow == 0 || width == 0 || height == 0) return NULL;
        
        CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
        if (!dataProvider) return NULL;
        CFDataRef data = CGDataProviderCopyData(dataProvider); // decode
        if (!data) return NULL;
        
        CGDataProviderRef newProvider = CGDataProviderCreateWithCFData(data);
        CFRelease(data);
        if (!newProvider) return NULL;
        
        CGImageRef newImage = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, space, bitmapInfo, newProvider, NULL, false, kCGRenderingIntentDefault);
        CFRelease(newProvider);
        return newImage;
    }
}
