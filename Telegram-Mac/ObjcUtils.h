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
+ (NSArray *)textCheckingResultsForText:(NSString *)text highlightMentions:(bool)highlightMentions highlightTags:(bool)highlightTags highlightCommands:(bool)highlightCommands dotInMention:(bool)dotInMention;
+(NSString * __nonnull) md5:(NSString *__nonnull)string;
+(NSArray<NSView *> *__nonnull)findElementsByClass:(NSString *__nonnull)className inView:(NSView *__nonnull)view;
+(NSString * __nonnull)stringForEmojiHashOfData:(NSData *__nonnull)data count:(NSInteger)count positionExtractor:(int32_t (^__nonnull)(uint8_t *__nonnull, int32_t, int32_t))positionExtractor;
+(NSArray<NSNumber *> *)bufferList:(CMSampleBufferRef)sampleBuffer;
+(NSString * __nonnull)callEmojies:(NSData *__nonnull)keySha256;
+ (NSArray<NSString *> * __nonnull)getEmojiFromString:(NSString * __nonnull)string;
+(NSOpenPanel * __nonnull)openPanel;
+(NSSavePanel * __nonnull)savePanel;
+(NSEvent * __nonnull)scrollEvent:(NSEvent *__nonnull)from;
+(NSSize)gifDimensionSize:(NSString * __nonnull)path;
+(int)colorMask:(int)idValue mainId:(int)mainId;
+(NSArray<NSString *> * __nonnull)notificationTones:(NSString * __nonnull)def;
+(NSString * __nullable)youtubeIdentifier:(NSString * __nonnull)url;;
+ (NSString * __nullable)_youtubeVideoIdFromText:(NSString * __nullable)text originalUrl:(NSString * __nullable)originalUrl startTime:(NSTimeInterval *)startTime;
+(NSArray<OpenWithObject *> *)appsForFileUrl:(NSString *)fileUrl;

@end




@interface NSMutableAttributedString(Extension)
-(void)detectBoldColorInStringWithFont:(NSFont *)font;
@end

NSArray<NSString *> *  __nonnull cut_long_message(NSString *message, int max_length);
int64_t SystemIdleTime(void);
NSDictionary<NSString *, NSString *> * __nonnull audioTags(AVURLAsset *asset);
NSImage *  __nonnull TGIdenticonImage(NSData *data, NSData *additionalData, CGSize size);

@interface NSData (TG)
- (NSString *  __nonnull)stringByEncodingInHex;
@end

BOOL isEnterAccessObjc(NSEvent *theEvent, BOOL byCmdEnter);
BOOL isEnterEventObjc(NSEvent *theEvent);

int colorIndexForGroupId(int64_t groupId);
int64_t TGPeerIdFromChannelId(int32_t channelId);
int colorIndexForUid(int32_t uid, int32_t myUserId);


NSArray<NSString *> * __nonnull currentAppInputSource();
NSEvent * __nullable createScrollWheelEvent();
