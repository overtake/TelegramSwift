//
//  Telegram-Mac-Bridging-Header.h
//  Telegram-Mac
//
//  Created by keepcoder on 19/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//



#ifndef Telegram_Mac_Bridging_Header_h
#define Telegram_Mac_Bridging_Header_h

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenGL/gl.h>
#import "DFRPrivateHeader.h"
#import "MP4Atom.h"
#import "HackUtils.h"

#ifndef SHARE
#import "ffmpeg/include/libavcodec/avcodec.h"
#import "ffmpeg/include/libavformat/avformat.h"
#import "FFMpegSwResample.h"
#endif
#import "RingBuffer.h"
#import "ocr.h"
#import "TGPassportMRZ.h"






//#import <ChromiumTabs/ChromiumTabs.h>
//#include <Cocoa/Cocoa.h>
//#import <IOKit/hidsystem/ev_keymap.h>
//#import <Carbon/Carbon.h>





#if !__has_feature(nullability)
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#endif



void telegramFastBlur(int imageWidth, int imageHeight, int imageStride, void * __nullable pixels);
NSArray<NSString *> * __nonnull cut_long_message(NSString * __nonnull message, int max_length);
int64_t SystemIdleTime(void);
NSDictionary<NSString * , NSString *> * __nonnull audioTags(AVURLAsset * __nonnull asset);
NSImage * __nonnull TGIdenticonImage(NSData * __nonnull data, NSData * __nonnull additionalData, CGSize size);

CGImageRef __nullable convertFromWebP(NSData *__nonnull data);

@interface OpenWithObject : NSObject
@property (nonatomic, strong,readonly) NSString *fullname;
@property (nonatomic, strong,readonly) NSURL *app;
@property (nonatomic, strong,readonly) NSImage *icon;


-(id)initWithFullname:(NSString *)fullname app:(NSURL *)app icon:(NSImage *)icon;

@end

@interface ObjcUtils : NSObject
+ (NSData *)dataFromHexString:(NSString *)string;
+ (NSArray *)textCheckingResultsForText:(NSString *)text highlightMentionsAndTags:(bool)highlightMentionsAndTags highlightCommands:(bool)highlightCommands dotInMention:(bool)dotInMention;
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

int colorIndexForGroupId(int64_t groupId);
int64_t TGPeerIdFromChannelId(int32_t channelId);
int colorIndexForUid(int32_t uid, int32_t myUserId);

@interface NSData (TG)
- (NSString *__nonnull)stringByEncodingInHex;
@end


@interface NSFileManager (Extension)
+ (NSString * __nonnull)xattrStringValueForKey:(NSString *__nonnull)key atURL:(NSURL *__nonnull)URL;
+ (BOOL)setXAttrStringValue:(NSString *__nonnull)value forKey:(NSString *__nonnull)key atURL:(NSURL *__nonnull)URL;
@end

@interface NSMutableAttributedString(Extension)
-(void)detectBoldColorInStringWithFont:(NSFont *__nonnull)font;
@end

@interface CalendarUtils : NSObject

+ (BOOL) isSameDate:(NSDate*__nonnull)d1 date:(NSDate* __nonnull)d2 checkDay:(BOOL)checkDay;
+ (NSString*__nonnull) dd:(NSDate*__nonnull)d;
+ (NSInteger) colForDay:(NSInteger)day;
+ (NSInteger) lastDayOfTheMonth:(NSDate *__nonnull)date;
+ (NSDate*__nonnull) toUTC:(NSDate*__nonnull)d;
+ (NSDate*__nonnull) monthDay:(NSInteger)day date:(NSDate *__nonnull)date;
+ (NSInteger)weekDay:(NSDate *__nonnull)date;
+ (NSDate *__nonnull) stepMonth:(NSInteger)dm date:(NSDate *__nonnull)date;

@end

extern NSString *__nonnull const TGCustomLinkAttributeName;


@interface TGInputTextAttribute : NSObject
@property (nonatomic,strong,readonly) NSString * __nonnull name;
@property (nonatomic,strong,readonly) id __nonnull  value;
-(id __nonnull )initWithName:(NSString * __nonnull)name value:(id __nonnull)value;
@end

@interface TGInputTextTag : NSTextAttachment

@property (nonatomic, readonly) int64_t uniqueId;
@property (nonatomic, strong, readonly) id __nonnull  attachment;

@property (nonatomic,strong, readonly) TGInputTextAttribute * __nonnull attribute;

-(instancetype __nonnull )initWithUniqueId:(int64_t)uniqueId attachment:(id __nonnull )attachment attribute:(TGInputTextAttribute * __nonnull )attribute;

@end

@interface TGInputTextTagAndRange : NSObject

@property (nonatomic, strong, readonly) TGInputTextTag *__nonnull tag;
@property (nonatomic) NSRange range;

- (instancetype __nonnull )initWithTag:(TGInputTextTag * __nonnull )tag range:(NSRange)range;

@end

@class TGModernGrowingTextView;

@protocol TGModernGrowingDelegate <NSObject>

-(void) textViewHeightChanged:(CGFloat)height animated:(BOOL)animated;
-(BOOL) textViewEnterPressed:(NSEvent * __nonnull)event;
-(void) textViewTextDidChange:(NSString * __nonnull)string;
-(void) textViewTextDidChangeSelectedRange:(NSRange)range;
-(BOOL)textViewDidPaste:(NSPasteboard * __nonnull)pasteboard;
-(NSSize)textViewSize:(TGModernGrowingTextView *)textView;
-(BOOL)textViewIsTypingEnabled;
-(int)maxCharactersLimit:(TGModernGrowingTextView *)textView;

@optional
- (void) textViewNeedClose:(id __nonnull)textView;
- (BOOL) canTransformInputText;
- (void)textViewDidReachedLimit:(id __nonnull)textView;
- (void)makeUrlOfRange: (NSRange)range;
@end


void setInputLocalizationFunc(NSString* _Nonnull (^ _Nonnull localizationF)(NSString * _Nonnull key));
void setTextViewEnableTouchBar(BOOL enableTouchBar);

@interface TGGrowingTextView : NSTextView
@property (nonatomic,weak) id <TGModernGrowingDelegate> __nullable weakd;
@end

@interface TGModernGrowingTextView : NSView

@property (nonatomic,assign) BOOL animates;
@property (nonatomic,assign) int min_height;
@property (nonatomic,assign) int max_height;

@property (nonatomic,assign) BOOL isSingleLine;
@property (nonatomic,assign) BOOL isWhitespaceDisabled;
@property (nonatomic,strong) NSColor * __nonnull cursorColor;
@property (nonatomic,strong) NSColor * __nonnull textColor;
@property (nonatomic,strong) NSColor * __nonnull linkColor;
@property (nonatomic,strong) NSFont * __nonnull textFont;
@property (nonatomic,strong,readonly) TGGrowingTextView * __nonnull inputView;
@property (nonatomic,strong) NSString * __nonnull defaultText;

@property (nonatomic,strong, nullable) NSAttributedString *placeholderAttributedString;

-(void)setPlaceholderAttributedString:(NSAttributedString * __nonnull)placeholderAttributedString update:(BOOL)update;

@property (nonatomic,weak) id <TGModernGrowingDelegate> __nullable delegate;

-(int)height;


-(void)update:(BOOL)notify;

-(NSAttributedString * __nonnull)attributedString;
-(void)setAttributedString:(NSAttributedString * __nonnull)attributedString animated:(BOOL)animated;
-(NSString * __nonnull)string;
-(void)setString:(NSString * __nonnull)string animated:(BOOL)animated;
-(void)setString:(NSString * __nonnull)string;
-(NSRange)selectedRange;
-(void)appendText:(id __nonnull)aString;
-(void)insertText:(id __nonnull)aString replacementRange:(NSRange)replacementRange;
-(void)addInputTextTag:(TGInputTextTag * __nonnull)tag range:(NSRange)range;
-(void)scrollToCursor;
-(void)replaceMention:(NSString * __nonnull)mention username:(bool)username userId:(int32_t)userId;

-(void)paste:(id __nonnull)sender;

-(void)setSelectedRange:(NSRange)range;

-(Class __nonnull)_textViewClass;
-(int)_startXPlaceholder;
-(BOOL)_needShowPlaceholder;

-(void)codeWord;
-(void)italicWord;
-(void)boldWord;
-(void)addLink:(NSString *)link;
-(void)textDidChange:( NSNotification * _Nullable )notification;
@end


@interface NSWeakReference : NSObject

@property (nonatomic, weak) id __nullable value;

- (instancetype __nonnull)initWithValue:(id __nonnull)value;

@end

@interface OpusObjcBridge : NSObject

@end

@protocol OpusBridgeDelegate <NSObject>
- (void)audioPlayerDidFinishPlaying:(OpusObjcBridge * __nonnull)audioPlayer;
- (void)audioPlayerDidStartPlaying:(OpusObjcBridge * __nonnull)audioPlayer;
- (void)audioPlayerDidPause:(OpusObjcBridge * __nonnull)audioPlayer;
@end

@interface OpusObjcBridge ()

@property (nonatomic, weak) id<OpusBridgeDelegate> __nullable delegate;

+ (bool)canPlayFile:(NSString * __nonnull)path;
+ (NSTimeInterval)durationFile:(NSString * __nonnull)path;
- (instancetype __nonnull)initWithPath:(NSString * __nonnull)path;
- (void)play;
- (void)playFromPosition:(NSTimeInterval)position;
- (void)pause;
- (void)stop;
- (void)reset;
- (NSTimeInterval)currentPositionSync:(bool)sync;
- (NSTimeInterval)duration;
-(void)setCurrentPosition:(NSTimeInterval)position;
- (BOOL)isPaused;
- (BOOL)isEqualToPath:(NSString * __nonnull)path;
@end


//BEGIN AUDIO HEADER


@interface TGDataItem : NSObject

- (instancetype __nonnull)initWithFilePath:(NSString * __nonnull)filePath;

- (void)moveToPath:(NSString * __nonnull)path;
- (void)remove;

- (void)appendData:(NSData * __nonnull)data;
- (NSData * __nonnull)readDataAtOffset:(NSUInteger)offset length:(NSUInteger)length;
- (NSUInteger)length;

- (NSString * __nonnull)path;

@end

@interface TGAudioWaveform : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData * __nonnull samples;
@property (nonatomic, readonly) int32_t peak;

- (instancetype __nonnull)initWithSamples:(NSData * __nonnull)samples peak:(int32_t)peak;
- (instancetype __nonnull)initWithBitstream:(NSData * __nonnull)bitstream bitsPerSample:(NSUInteger)bitsPerSample;

- (NSData * __nonnull)bitstream;
- (uint16_t * __nonnull)sampleList;
@end



double mappingRange(double x, double in_min, double in_max, double out_min, double out_max);


@interface TGOggOpusWriter : NSObject

- (bool)beginWithDataItem:(TGDataItem * __nonnull)dataItem;
- (bool)writeFrame:(uint8_t * __nullable)framePcmBytes frameByteCount:(NSUInteger)frameByteCount;
- (NSUInteger)encodedBytes;
- (NSTimeInterval)encodedDuration;

@end


@interface DateUtils : NSObject

+ (NSString * __nonnull)stringForShortTime:(int)time;
+ (NSString * __nonnull)stringForDialogTime:(int)time;
+ (NSString * __nonnull)stringForDayOfMonth:(int)date dayOfMonth:(int * __nonnull)dayOfMonth;
+ (NSString * __nonnull)stringForDayOfWeek:(int)date;
+ (NSString * __nonnull)stringForMessageListDate:(int)date;
+ (NSString * __nonnull)stringForLastSeen:(int)date;
+ (NSString * __nonnull)stringForLastSeenShort:(int)date;
+ (NSString * __nonnull)stringForRelativeLastSeen:(int)date;
+ (NSString * __nonnull)stringForUntil:(int)date;
+ (NSString * __nonnull)stringForDayOfMonthFull:(int)date dayOfMonth:(int * __nonnull)dayOfMonth;

+ (void)setDateLocalizationFunc:(NSString*  __nonnull (^__nonnull)(NSString * __nonnull key))localizationF;
@end

NSString * NSLocalized(NSString * key, NSString *comment);



NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, YTVimeoVideoThumbnailQuality) {
    YTVimeoVideoThumbnailQualitySmall  = 640,
    YTVimeoVideoThumbnailQualityMedium = 960,
    YTVimeoVideoThumbnailQualityHD     = 1280,
};

typedef NS_ENUM(NSUInteger, YTVimeoVideoQuality) {
    YTVimeoVideoQualityLow270    = 270,
    YTVimeoVideoQualityMedium360 = 360,
    YTVimeoVideoQualityMedium480 = 480,
    YTVimeoVideoQualityMedium540 = 540,
    YTVimeoVideoQualityHD720     = 720,
    YTVimeoVideoQualityHD1080    = 1080,
};



@interface YTVimeoVideo : NSObject <NSCopying>

@property (nonatomic, readonly) NSString *identifier;

@property (nonatomic, readonly) NSString *title;

@property (nonatomic, readonly) NSTimeInterval duration;


#if __has_feature(objc_generics)
@property (nonatomic, readonly) NSDictionary<id, NSURL *> *streamURLs;
#else
@property (nonatomic, readonly) NSDictionary *streamURLs;
#endif


#if __has_feature(objc_generics)
@property (nonatomic, readonly) NSDictionary<id, NSURL *> *__nullable thumbnailURLs;
#else
@property (nonatomic, readonly) NSDictionary *thumbnailURLs;
#endif


@property (nonatomic, readonly) NSDictionary *metaData;

-(NSURL *)highestQualityStreamURL;

-(NSURL *)lowestQualityStreamURL;

@property (nonatomic, readonly, nullable) NSURL *HTTPLiveStreamURL;

@end

@interface YTVimeoExtractor : NSObject

+(instancetype)sharedExtractor;

-(void)fetchVideoWithIdentifier:(NSString *)videoIdentifier withReferer:(NSString *__nullable)referer completionHandler:(void (^)(YTVimeoVideo * __nullable video, NSError * __nullable error))completionHandler;

-(void)fetchVideoWithVimeoURL:(NSString *)videoURL withReferer:(NSString *__nullable)referer completionHandler:(void (^)(YTVimeoVideo * __nullable video, NSError * __nullable error))completionHandler;

@end

typedef NS_ENUM(NSUInteger, XCDYouTubeVideoQuality) {
    XCDYouTubeVideoQualitySmall240  = 36,
    XCDYouTubeVideoQualityMedium360 = 18,
    XCDYouTubeVideoQualityHD720     = 22,
    XCDYouTubeVideoQualityHD1080 DEPRECATED_MSG_ATTRIBUTE("YouTube has removed 1080p mp4 videos.") = 37,
};

extern NSString *const XCDYouTubeVideoQualityHTTPLiveStreaming;

@interface XCDYouTubeVideo : NSObject <NSCopying>


@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly, nullable) NSURL *smallThumbnailURL;
@property (nonatomic, readonly, nullable) NSURL *mediumThumbnailURL;
@property (nonatomic, readonly, nullable) NSURL *largeThumbnailURL;
@property (nonatomic, readonly) NSDictionary<id, NSURL *> *streamURLs;
@property (nonatomic, readonly, nullable) NSDate *expirationDate;

@end

@protocol XCDYouTubeOperation <NSObject>

- (void) cancel;

@end

@interface XCDYouTubeClient : NSObject
+ (instancetype) defaultClient;
- (instancetype) initWithLanguageIdentifier:(nullable NSString *)languageIdentifier;
@property (nonatomic, readonly) NSString *languageIdentifier;
- (id<XCDYouTubeOperation>) getVideoWithIdentifier:(nullable NSString *)videoIdentifier completionHandler:(void (^)(XCDYouTubeVideo * __nullable video, NSError * __nullable error))completionHandler;

@end


//
//  SSKeychain.h
//  SSToolkit
//
//  Created by Sam Soffes on 5/19/10.
//  Copyright (c) 2009-2011 Sam Soffes. All rights reserved.
//


/** Error codes that can be returned in NSError objects. */
typedef enum {
    SSKeychainErrorNone = noErr,
    SSKeychainErrorBadArguments = -1001,
    SSKeychainErrorNoPassword = -1002,
    SSKeychainErrorInvalidParameter = errSecParam,
    SSKeychainErrorFailedToAllocated = errSecAllocate,
    SSKeychainErrorNotAvailable = errSecNotAvailable,
    SSKeychainErrorAuthorizationFailed = errSecAuthFailed,
    SSKeychainErrorDuplicatedItem = errSecDuplicateItem,
    SSKeychainErrorNotFound = errSecItemNotFound,
    SSKeychainErrorInteractionNotAllowed = errSecInteractionNotAllowed,
    SSKeychainErrorFailedToDecode = errSecDecode
} SSKeychainErrorCode;

extern NSString *const kSSKeychainErrorDomain;
extern NSString *const kSSKeychainAccountKey;
extern NSString *const kSSKeychainCreatedAtKey;
extern NSString *const kSSKeychainClassKey;
extern NSString *const kSSKeychainDescriptionKey;
extern NSString *const kSSKeychainLabelKey;
extern NSString *const kSSKeychainLastModifiedKey;
extern NSString *const kSSKeychainWhereKey;

@interface SSKeychain : NSObject

+ (NSArray *)allAccounts;
+ (NSArray *)allAccounts:(NSError **)error;
+ (NSArray *)accountsForService:(NSString *)serviceName;
+ (NSArray *)accountsForService:(NSString *)serviceName error:(NSError **)error;
+ (NSString *)passwordForService:(NSString *)serviceName account:(NSString *)account;
+ (NSString *)passwordForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;
+ (NSData *  __nullable)passwordDataForService:(NSString *)serviceName account:(NSString *)account;
+ (NSData *  __nullable)passwordDataForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;
+ (BOOL)deletePasswordForService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)deletePasswordForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;
+ (BOOL)setPassword:(NSString *)password forService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)setPassword:(NSString *)password forService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;
+ (BOOL)setPasswordData:(NSData *)password forService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)setPasswordData:(NSData *)password forService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;

@end


@interface SPMediaKeyTap : NSObject
+ (NSArray*)defaultMediaKeyUserBundleIdentifiers;

-(id)initWithDelegate:(id)delegate;

+(BOOL)usesGlobalMediaKeyTap;
-(void)startWatchingMediaKeys;
-(void)stopWatchingMediaKeys;
-(void)handleAndReleaseMediaKeyEvent:(NSEvent *)event;
@end

@interface NSObject (SPMediaKeyTapDelegate)
-(void)mediaKeyTap:(SPMediaKeyTap*)keyTap receivedMediaKeyEvent:(NSEvent*)event;
@end

@interface TimeObserver : NSObject

void test_start_group(NSString * timeGroup);
void test_step_group(NSString *group);
void test_release_group(NSString *group);

@end

BOOL isEnterAccessObjc(NSEvent *theEvent, BOOL byCmdEnter);
BOOL isEnterEventObjc(NSEvent *theEvent);


@interface TGGifConverter : NSObject
+ (void)convertGifToMp4:(NSData *)data exportPath:(NSString *)exportPath completionHandler:(void (^)(NSString *path))completionHandler errorHandler:(dispatch_block_t)errorHandler cancelHandler:(BOOL (^)())cancelHandler;

+(NSSize)gifDimensionSize:(NSString *)path;
@end



@interface TGCallConnectionDescription : NSObject
    
    @property (nonatomic, readonly) int64_t identifier;
    @property (nonatomic, strong, readonly) NSString *ipv4;
    @property (nonatomic, strong, readonly) NSString *ipv6;
    @property (nonatomic, readonly) int32_t port;
    @property (nonatomic, strong, readonly) NSData *peerTag;
    
- (instancetype)initWithIdentifier:(int64_t)identifier ipv4:(NSString *)ipv4 ipv6:(NSString *)ipv6 port:(int32_t)port peerTag:(NSData *)peerTag;
    
@end


@interface TGCallConnection : NSObject

@property (nonatomic, strong, readonly) NSData *key;
@property (nonatomic, strong, readonly) NSData *keyHash;
@property (nonatomic, strong, readonly) TGCallConnectionDescription *defaultConnection;
@property (nonatomic, strong, readonly) NSArray<TGCallConnectionDescription *> *alternativeConnections;
@property (nonatomic, readonly) int32_t maxLayer;
- (instancetype)initWithKey:(NSData *)key keyHash:(NSData *)keyHash defaultConnection:(TGCallConnectionDescription *)defaultConnection alternativeConnections:(NSArray<TGCallConnectionDescription *> *)alternativeConnections maxLayer:(int32_t)maxLayer;

@end

@interface AudioDevice : NSObject
@property(nonatomic, strong, readonly) NSString *deviceId;
@property(nonatomic, strong, readonly) NSString *deviceName;
-(id)initWithDeviceId:(NSString*)deviceId deviceName:(NSString *)deviceName;
@end

@interface CProxy : NSObject
@property(nonatomic, strong, readonly) NSString *host;
@property(nonatomic, assign, readonly) int32_t port;
@property(nonatomic, strong, readonly) NSString *_Nullable user;
@property(nonatomic, strong, readonly) NSString *_Nullable pass;
-(id)initWithHost:(NSString*)host port:(int32_t)port user:(NSString *_Nullable )user pass:(NSString * _Nullable)pass;
@end

@interface CallBridge : NSObject

-(id)initWithProxy:(CProxy * _Nullable)proxy;

-(void)startTransmissionIfNeeded:(bool)outgoing connection:(TGCallConnection *)connection;

-(void)mute;
-(void)unmute;
-(BOOL)isMuted;

-(NSString *)currentOutputDeviceId;
-(NSString *)currentInputDeviceId;
-(NSArray<AudioDevice *> *)outputDevices;
-(NSArray<AudioDevice *> *)inputDevices;
-(void)setCurrentOutputDeviceId:(NSString *)deviceId;
-(void)setCurrentInputDeviceId:(NSString *)deviceId;

@property (nonatomic, copy) void (^stateChangeHandler)(int);

@end

@interface TGCurrencyFormatterEntry : NSObject

@property (nonatomic, strong, readonly) NSString *symbol;
@property (nonatomic, strong, readonly) NSString *thousandsSeparator;
@property (nonatomic, strong, readonly) NSString *decimalSeparator;
@property (nonatomic, readonly) bool symbolOnLeft;
@property (nonatomic, readonly) bool spaceBetweenAmountAndSymbol;
@property (nonatomic, readonly) int decimalDigits;

@end

@interface TGCurrencyFormatter : NSObject

+ (TGCurrencyFormatter *)shared;

- (NSString *)formatAmount:(int64_t)amount currency:(NSString *)currency;

@end


typedef NS_ENUM(int32_t, NumberPluralizationForm) {
    NumberPluralizationFormZero,
    NumberPluralizationFormOne,
    NumberPluralizationFormTwo,
    NumberPluralizationFormFew,
    NumberPluralizationFormMany,
    NumberPluralizationFormOther
};

NumberPluralizationForm numberPluralizationForm(unsigned int lc, int n);
unsigned int languageCodehash(NSString *code);
NS_ASSUME_NONNULL_END


@interface CEmojiSuggestion : NSObject
@property(nonatomic, strong) NSString * __nonnull emoji;
@property(nonatomic, strong) NSString * __nonnull label;
@property(nonatomic, strong) NSString * __nonnull replacement;
@end

@interface EmojiSuggestionBridge : NSObject
+(NSArray<CEmojiSuggestion *> * __nonnull)getSuggestions:(NSString * __nonnull)q;
@end

typedef enum {
    MIHSliderTransitionFade,
    MIHSliderTransitionPushVertical,
    MIHSliderTransitionPushHorizontalFromLeft,
    MIHSliderTransitionPushHorizontalFromRight
} MIHSliderTransition;

@class MIHSliderDotsControl;

@interface MIHSliderView : NSView

@property (retain, readonly) NSArray * __nonnull slides;

- (void)addSlide:(NSView * __nonnull)aSlide;
- (void)removeSlide:(NSView * __nonnull)aSlide;
@property (assign, readonly) NSUInteger indexOfDisplayedSlide;
@property (retain, readonly) NSView * __nonnull displayedSlide;
- (void)displaySlideAtIndex:(NSUInteger)aIndex;
@property (assign) MIHSliderTransition transitionStyle;
@property (assign) BOOL scheduledTransition;
@property (assign) BOOL repeatingScheduledTransition;
@property (assign) NSTimeInterval scheduledTransitionInterval;
@property (assign) NSTimeInterval transitionAnimationDuration;

@property (retain) MIHSliderDotsControl * __nonnull dotsControl;

@end

@interface MIHSliderDotsControl : NSView

@property (retain) NSImage * __nullable normalDotImage;

@property (retain) NSImage * __nullable highlightedDotImage;

@end

@interface TGVideoCameraGLRenderer : NSObject

@property (nonatomic, readonly) __attribute__((NSObject)) CMFormatDescriptionRef outputFormatDescription;
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
@property (nonatomic, assign) bool mirror;
@property (nonatomic, assign) CGFloat opacity;
@property (nonatomic, readonly) bool hasPreviousPixelbuffer;

- (void)prepareForInputWithFormatDescription:(CMFormatDescriptionRef)inputFormatDescription outputRetainedBufferCountHint:(size_t)outputRetainedBufferCountHint;
- (void)reset;

- (CVPixelBufferRef)copyRenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)setPreviousPixelBuffer:(CVPixelBufferRef)previousPixelBuffer;

@end

@interface TGPaintShader : NSObject

@property (nonatomic, readonly) GLuint program;
@property (nonatomic, readonly) NSDictionary *uniforms;

- (instancetype)initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader attributes:(NSArray *)attributes uniforms:(NSArray *)uniforms;

- (GLuint)uniformForKey:(NSString *)key;

- (void)cleanResources;

@end


@protocol TGVideoCameraMovieRecorderDelegate;

@interface TGVideoCameraMovieRecorder : NSObject

@property (nonatomic, assign) bool paused;

- (instancetype __nonnull)initWithURL:(NSURL *)URL delegate:(id<TGVideoCameraMovieRecorderDelegate>)delegate callbackQueue:(dispatch_queue_t)queue;

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings;
- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings;


- (void)prepareToRecord;

- (void)appendVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)finishRecording;

- (NSTimeInterval)videoDuration;

@end

@protocol TGVideoCameraMovieRecorderDelegate <NSObject>
@required
- (void)movieRecorderDidFinishPreparing:(TGVideoCameraMovieRecorder *)recorder;
- (void)movieRecorder:(TGVideoCameraMovieRecorder *)recorder didFailWithError:(NSError *)error;
- (void)movieRecorderDidFinishRecording:(TGVideoCameraMovieRecorder *)recorder;
@end

typedef enum
{
    TGMediaVideoConversionPresetCompressedDefault,
    TGMediaVideoConversionPresetCompressedVeryLow,
    TGMediaVideoConversionPresetCompressedLow,
    TGMediaVideoConversionPresetCompressedMedium,
    TGMediaVideoConversionPresetCompressedHigh,
    TGMediaVideoConversionPresetCompressedVeryHigh,
    TGMediaVideoConversionPresetAnimation,
    TGMediaVideoConversionPresetVideoMessage
} TGMediaVideoConversionPreset;



@interface TGMediaVideoConversionPresetSettings : NSObject

+ (CGSize)maximumSizeForPreset:(TGMediaVideoConversionPreset)preset;
+ (NSDictionary *)videoSettingsForPreset:(TGMediaVideoConversionPreset)preset dimensions:(CGSize)dimensions;
+ (NSDictionary *)audioSettingsForPreset:(TGMediaVideoConversionPreset)preset;

@end


@class RHResizableImage;


typedef NSEdgeInsets RHEdgeInsets;


extern RHEdgeInsets RHEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right);
extern CGRect RHEdgeInsetsInsetRect(CGRect rect, RHEdgeInsets insets, BOOL flipped); // If flipped origin is top-left otherwise origin is bottom-left (OSX Default is NO)
extern BOOL RHEdgeInsetsEqualToEdgeInsets(RHEdgeInsets insets1, RHEdgeInsets insets2);
extern const RHEdgeInsets RHEdgeInsetsZero;

extern NSString *NSStringFromRHEdgeInsets(RHEdgeInsets insets);
extern RHEdgeInsets RHEdgeInsetsFromString(NSString* string);


typedef NSImageResizingMode RHResizableImageResizingMode;
enum {
    RHResizableImageResizingModeTile = NSImageResizingModeTile,
    RHResizableImageResizingModeStretch = NSImageResizingModeStretch,
};



@interface NSImage (RHResizableImageAdditions)

-(RHResizableImage *)resizableImageWithCapInsets:(RHEdgeInsets)capInsets; // Create a resizable version of this image. the interior is tiled when drawn.
-(RHResizableImage *)resizableImageWithCapInsets:(RHEdgeInsets)capInsets resizingMode:(RHResizableImageResizingMode)resizingMode; // The interior is resized according to the resizingMode

-(RHResizableImage *)stretchableImageWithLeftCapWidth:(CGFloat)leftCapWidth topCapHeight:(CGFloat)topCapHeight; // Right cap is calculated as width - leftCapWidth - 1; bottom cap is calculated as height - topCapWidth - 1;


-(void)drawTiledInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)delta;
-(void)drawStretchedInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)delta;

@end



@interface RHResizableImage : NSImage <NSCopying> {
    // ivars are private
    RHEdgeInsets _capInsets;
    RHResizableImageResizingMode _resizingMode;
    
    NSArray *_imagePieces;
    
    NSBitmapImageRep *_cachedImageRep;
    NSSize _cachedImageSize;
    CGFloat _cachedImageDeviceScale;
}

-(id)initWithImage:(NSImage *)image leftCapWidth:(CGFloat)leftCapWidth topCapHeight:(CGFloat)topCapHeight; // right cap is calculated as width - leftCapWidth - 1; bottom cap is calculated as height - topCapWidth - 1;

-(id)initWithImage:(NSImage *)image capInsets:(RHEdgeInsets)capInsets;
-(id)initWithImage:(NSImage *)image capInsets:(RHEdgeInsets)capInsets resizingMode:(RHResizableImageResizingMode)resizingMode; // designated initializer

@property RHEdgeInsets capInsets; // Default is RHEdgeInsetsZero
@property RHResizableImageResizingMode resizingMode; // Default is UIImageResizingModeTile

-(void)drawInRect:(NSRect)rect;
-(void)drawInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha;
-(void)drawInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints;
-(void)drawInRect:(NSRect)rect fromRect:(NSRect)fromRect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints;

-(void)originalDrawInRect:(NSRect)rect fromRect:(NSRect)fromRect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints; //super passthrough


@end

// utilities
extern NSImage* RHImageByReferencingRectOfExistingImage(NSImage *image, NSRect rect);
extern NSArray* RHNinePartPiecesFromImageWithInsets(NSImage *image, RHEdgeInsets capInsets);
extern CGFloat RHContextGetDeviceScale(CGContextRef context);

// nine part
extern void RHDrawNinePartImage(NSRect frame, NSImage *topLeftCorner, NSImage *topEdgeFill, NSImage *topRightCorner, NSImage *leftEdgeFill, NSImage *centerFill, NSImage *rightEdgeFill, NSImage *bottomLeftCorner, NSImage *bottomEdgeFill, NSImage *bottomRightCorner, NSCompositingOperation op, CGFloat alphaFraction, BOOL shouldTile);

extern void RHDrawImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction, BOOL tile);
extern void RHDrawTiledImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction);
extern void RHDrawStretchedImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction);



#endif /* Telegram_Mac_Bridging_Header_h */
