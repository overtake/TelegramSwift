#import <Foundation/Foundation.h>

extern NSString *StringFromKeyCode(unsigned short keyCode, NSUInteger modifiers);



@interface PermissionsManager : NSObject

+ (void)openInputMonitoringPrefs;

+ (BOOL)checkInputMonitoringWithPrompt:(BOOL)prompt;
+ (BOOL)checkAccessibilityWithPrompt:(BOOL)prompt;
@end
