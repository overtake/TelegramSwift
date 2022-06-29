#import <AppKit/AppKit.h>

@interface TGTextAttachment : NSTextAttachment
@property (nonatomic,strong,readonly) NSString * _Nonnull identifier;
@property (nonatomic,strong,readonly) NSString * _Nonnull text;
@property (nonatomic,strong,readonly) id _Nonnull reference;
@property (nonatomic,strong,readonly) id _Nonnull fileId;
-(id _Nonnull)initWithIdentifier:(NSString * _Nonnull)identifier reference:(id _Nonnull)reference fileId:(id _Nonnull)fileId text:(NSString * _Nonnull)text;
-(id _Nonnull)unique;
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

@interface TGInputTextTagAndRange : NSObject

@property (nonatomic, strong, readonly) TGInputTextTag * _Nonnull tag;
@property (nonatomic) NSRange range;

- (instancetype _Nonnull)initWithTag:(TGInputTextTag * _Nonnull)tag range:(NSRange)range;

@end
