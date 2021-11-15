#import "TGInputTextTag.h"

#import <CoreText/CoreText.h>

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
