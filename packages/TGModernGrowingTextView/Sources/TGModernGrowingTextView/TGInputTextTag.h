#import <AppKit/AppKit.h>

@interface TGInputTextAttribute : NSObject
@property (nonatomic,strong,readonly) NSString *name;
@property (nonatomic,strong,readonly) id value;
-(id)initWithName:(NSString *)name value:(id)value;
@end

@interface TGInputTextTag : NSTextAttachment

@property (nonatomic, readonly) int64_t uniqueId;
@property (nonatomic, strong, readonly) id attachment;

@property (nonatomic,strong, readonly) TGInputTextAttribute *attribute;

-(instancetype)initWithUniqueId:(int64_t)uniqueId attachment:(id)attachment attribute:(TGInputTextAttribute *)attribute;

@end

@interface TGInputTextTagAndRange : NSObject

@property (nonatomic, strong, readonly) TGInputTextTag *tag;
@property (nonatomic) NSRange range;

- (instancetype)initWithTag:(TGInputTextTag *)tag range:(NSRange)range;

@end
