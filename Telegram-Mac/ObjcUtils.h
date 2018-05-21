//
//  ObjcUtils.h
//  Telegram-Mac
//
//  Created by keepcoder on 23/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>

@interface OpenWithObject : NSObject
@property (nonatomic, strong,readonly) NSString *fullname;
@property (nonatomic, strong,readonly) NSURL *app;
@property (nonatomic, strong,readonly) NSImage *icon;


-(id)initWithFullname:(NSString *)fullname app:(NSURL *)app icon:(NSImage *)icon;

@end

@interface ObjcUtils : NSObject
+ (NSData *)dataFromHexString:(NSString *)string;
+ (NSArray *)textCheckingResultsForText:(NSString *)text highlightMentionsAndTags:(bool)highlightMentionsAndTags highlightCommands:(bool)highlightCommands dotInMention:(bool)dotInMention;
+(NSString *) md5:(NSString *)string;
+ (NSArray<NSView *> *)findElementsByClass:(NSString *)className inView:(NSView *)view;
+ (NSString *)stringForEmojiHashOfData:(NSData *)data count:(NSInteger)count positionExtractor:(int32_t (^)(uint8_t *, int32_t, int32_t))positionExtractor;
+(NSArray<NSNumber *> *)bufferList:(CMSampleBufferRef)sampleBuffer;
+(NSString *)callEmojies:(NSData *)keySha256;
+ (NSArray<NSString *> *)getEmojiFromString:(NSString *)string;
+(NSOpenPanel *)openPanel;
+(NSSavePanel *)savePanel;
+(NSEvent *)scrollEvent:(NSEvent *)from;
+(NSSize)gifDimensionSize:(NSString *)path;
+(int)colorMask:(int)idValue mainId:(int)mainId;
+(NSArray<NSString *> *)notificationTones:(NSString *)def;
+(NSString *)youtubeIdentifier:(NSString *)url;
+ (NSString *)_youtubeVideoIdFromText:(NSString *)text originalUrl:(NSString *)originalUrl startTime:(NSTimeInterval *)startTime;
+(NSArray<OpenWithObject *> *)appsForFileUrl:(NSString *)fileUrl;
@end

@interface NSFileManager (Extension)
+ (NSString *)xattrStringValueForKey:(NSString *)key atURL:(NSURL *)URL;
+ (BOOL)setXAttrStringValue:(NSString *)value forKey:(NSString *)key atURL:(NSURL *)URL;
@end

@interface NSMutableAttributedString(Extension)
-(void)detectBoldColorInStringWithFont:(NSFont *)font;
@end

NSArray<NSString *> *cut_long_message(NSString *message, int max_length);
int64_t SystemIdleTime(void);
NSDictionary<NSString *, NSString *> *audioTags(AVURLAsset *asset);
NSImage *TGIdenticonImage(NSData *data, NSData *additionalData, CGSize size);

@interface NSData (TG)
- (NSString *)stringByEncodingInHex;
@end

BOOL isEnterAccessObjc(NSEvent *theEvent, BOOL byCmdEnter);
BOOL isEnterEventObjc(NSEvent *theEvent);

int colorIndexForGroupId(int64_t groupId);
int64_t TGPeerIdFromChannelId(int32_t channelId);
int colorIndexForUid(int32_t uid, int32_t myUserId);
