
#import <Cocoa/Cocoa.h>

@interface HackUtils : NSObject

+ (NSArray *)findElementsByClass:(NSString *)className inView:(NSView *)view;
+ (void)printViews:(NSView *)containerView;
@end

