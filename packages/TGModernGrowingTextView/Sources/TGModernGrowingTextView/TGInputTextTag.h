#import <AppKit/AppKit.h>

@interface TGTextAttachment : NSTextAttachment
@property (nonatomic,strong,readonly) NSString * _Nonnull type;
@property (nonatomic,strong,readonly) NSString * _Nonnull identifier;
@property (nonatomic,strong,readonly) NSString * _Nonnull text;
@property (nonatomic,strong,readonly) id _Nonnull fileId;
@property (nonatomic,strong,readonly) id _Nullable file;
@property (nonatomic,strong,readonly) id _Nullable info;
@property (nonatomic,assign,readonly) CGRect fromRect;
-(id _Nonnull)initWithIdentifier:(NSString * _Nonnull)identifier fileId:(id _Nonnull)fileId file:(id _Nullable)file text:(NSString * _Nonnull)text info:(id _Nullable)info fromRect: (CGRect)fromRect type: (NSString * _Nonnull)type;
-(id _Nonnull)initWithIdentifier:(NSString * _Nonnull)identifier fileId:(id _Nonnull)fileId file:(id _Nullable)file text:(NSString * _Nonnull)text info:(id _Nullable)info type: (NSString * _Nonnull)type;
-(id _Nonnull)unique;

-(NSSize)makeSizeFor:(NSView * _Nonnull)view textViewSize: (NSSize)textSize range: (NSRange)range;

@end

@interface TGInputTextAttribute : NSObject
@property (nonatomic,strong,readonly) NSString * _Nonnull name;
@property (nonatomic,strong,readonly) id _Nonnull value;
-(id _Nonnull)initWithName:(NSString * _Nonnull)name value:(id _Nonnull)value;
@end

@interface TGInputTextTag : NSTextAttachment

@property (nonatomic, readonly) int64_t uniqueId;
@property (nonatomic, strong, readonly) id _Nonnull attachment;

@property (nonatomic,strong, readonly) TGInputTextAttribute * _Nonnull attribute;

-(instancetype _Nonnull)initWithUniqueId:(int64_t)uniqueId attachment:(id _Nonnull)attachment attribute:(TGInputTextAttribute * _Nonnull)attribute;

@end

@interface TGInputTextEmojiHolder : NSTextAttachment

@property (nonatomic, readonly) int64_t uniqueId;
@property (nonatomic, strong, readonly) NSString * _Nonnull emoji;
@property (nonatomic, assign, readonly) NSRect rect;

@property (nonatomic,strong, readonly) TGInputTextAttribute * _Nonnull attribute;

-(instancetype _Nonnull)initWithUniqueId:(int64_t)uniqueId emoji:(NSString * _Nonnull)emoji rect:(NSRect)rect attribute:(TGInputTextAttribute * _Nonnull)attribute;
@end

@interface TGInputTextTagAndRange : NSObject

@property (nonatomic, strong, readonly) TGInputTextTag * _Nonnull tag;
@property (nonatomic) NSRange range;

- (instancetype _Nonnull)initWithTag:(TGInputTextTag * _Nonnull)tag range:(NSRange)range;

@end
