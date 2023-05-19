//
//  WebPImageCoder.h
//  WebPImage <https://github.com/ibireme/WebPImage>
//
//  Created by ibireme on 15/5/13.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSUInteger, WebPImageType) {
    WebPImageTypeUnknown = 0, ///< unknown
    WebPImageTypeWebP
};

typedef NS_ENUM(NSUInteger, WebPImageDisposeMethod) {
    WebPImageDisposeNone = 0,
    WebPImageDisposeBackground,
    WebPImageDisposePrevious,
};

typedef NS_ENUM(NSUInteger, WebPImageBlendOperation) {
    WebPImageBlendNone = 0,
    WebPImageBlendOver,
};

@interface WebPImageFrame : NSObject <NSCopying>
@property (nonatomic) NSUInteger index;    ///< Frame index (zero based)
@property (nonatomic) NSUInteger width;    ///< Frame width
@property (nonatomic) NSUInteger height;   ///< Frame height
@property (nonatomic) NSUInteger offsetX;  ///< Frame origin.x in canvas (left-bottom based)
@property (nonatomic) NSUInteger offsetY;  ///< Frame origin.y in canvas (left-bottom based)
@property (nonatomic) NSTimeInterval duration;          ///< Frame duration in seconds
@property (nonatomic) WebPImageDisposeMethod dispose;     ///< Frame dispose method.
@property (nonatomic) WebPImageBlendOperation blend;      ///< Frame blend operation.
@property (nullable, nonatomic, strong) NSImage *image; ///< The image.
@end


@interface WebPImageDecoder : NSObject

@property (nullable, nonatomic, readonly) NSData *data;    ///< Image data.
@property (nonatomic, readonly) WebPImageType type;          ///< Image data type.
@property (nonatomic, readonly) CGFloat scale;             ///< Image scale.
@property (nonatomic, readonly) NSUInteger frameCount;     ///< Image frame count.
@property (nonatomic, readonly) NSUInteger loopCount;      ///< Image loop count, 0 means infinite.
@property (nonatomic, readonly) NSUInteger width;          ///< Image canvas width.
@property (nonatomic, readonly) NSUInteger height;         ///< Image canvas height.
@property (nonatomic, readonly, getter=isFinalized) BOOL finalized;
- (instancetype)initWithScale:(CGFloat)scale NS_DESIGNATED_INITIALIZER;
- (BOOL)updateData:(nullable NSData *)data final:(BOOL)final;
+ (nullable instancetype)decoderWithData:(NSData *)data scale:(CGFloat)scale;
- (nullable WebPImageFrame *)frameAtIndex:(NSUInteger)index decodeForDisplay:(BOOL)decodeForDisplay;
- (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index;

@end



CG_EXTERN CGImageRef _Nullable WebPCGImageCreateDecodedCopy(CGImageRef imageRef, BOOL decodeForDisplay);

NS_ASSUME_NONNULL_END
