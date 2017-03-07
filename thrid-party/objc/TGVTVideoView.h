#import <Cocoa/Cocoa.h>

@interface TGVTVideoView : NSView

@property (nonatomic) CGSize videoSize;

- (void)setPath:(NSString * __nullable)path;


@end
