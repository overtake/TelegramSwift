#import "TGInputTextTag.h"

#import <CoreText/CoreText.h>

@implementation TGTextAttachment
-(id _Nonnull)initWithIdentifier:(NSString * _Nonnull)identifier fileId:(id _Nonnull)fileId file:(id _Nullable)file text:(NSString * _Nonnull)text info:(id _Nullable)info fromRect: (CGRect)fromRect {
    if (self = [super init]) {
        
        NSRect rect = NSMakeRect(0, 0, 18, 16);
        NSImage *image = [[NSImage alloc] initWithSize:rect.size];

        [super setImage:image];
        _identifier = identifier;
        _fileId = fileId;
        _text = text;
        _file = file;
        _info = info;
        _fromRect = fromRect;
    }
    [self setBounds:NSMakeRect(0, -3, 18, 16)];
    return self;
}
-(id _Nonnull)initWithIdentifier:(NSString * _Nonnull)identifier fileId:(id _Nonnull)fileId file:(id _Nullable)file text:(NSString * _Nonnull)text info:(id _Nullable)info {
    return [self initWithIdentifier:identifier fileId:fileId file:file text:text info:info fromRect:NSZeroRect];
}


-(id)unique {
    return [[TGTextAttachment alloc] initWithIdentifier:[NSString stringWithFormat:@"%d", arc4random()] fileId:_fileId file: _file text:_text info:_info];
}

@end

@implementation TGInputTextAttribute

-(id)initWithName:(NSString *)name value:(id)value {
    if (self = [super init]) {
        _name = name;
        _value = value;
    }
    return self;
}
@end

@implementation TGInputTextTag

- (instancetype)initWithUniqueId:(int64_t)uniqueId attachment:(id)attachment attribute:(TGInputTextAttribute *)attribute {
    
    static NSData *imageData = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSRect rect = NSMakeRect(0, 0, 1, 1);
        NSImage *image = [[NSImage alloc] initWithSize:rect.size];
        [image lockFocus];
        
        [image unlockFocus];
        
        imageData = [image TIFFRepresentation];
    });
    
    self = [super initWithData:imageData ofType:@"public.image"];
    if (self != nil) {
        _attribute = attribute;
        _uniqueId = uniqueId;
        _attachment = attachment;
    }
    return self;
}


- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)__unused textContainer proposedLineFragment:(CGRect)__unused lineFrag glyphPosition:(CGPoint)__unused position characterIndex:(NSUInteger)__unused charIndex {
    return CGRectZero;
}

@end


@implementation TGInputTextEmojiHolder

- (instancetype)initWithUniqueId:(int64_t)uniqueId emoji:(NSString *)emoji rect:(NSRect)rect attribute:(TGInputTextAttribute *)attribute {
    
    self = [super init];
    
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
    [super setImage:image];
    
    if (self != nil) {
        _attribute = attribute;
        _uniqueId = uniqueId;
        _emoji = emoji;
        _rect = rect;
    }
    return self;
}

@end

@implementation TGInputTextTagAndRange

- (instancetype)initWithTag:(TGInputTextTag *)tag range:(NSRange)range {
    self = [super init];
    if (self != nil) {
        _tag = tag;
        _range = range;
    }
    return self;
}

@end
