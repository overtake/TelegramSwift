#import <Foundation/Foundation.h>

extern NSString *StringFromKeyCode(unsigned short keyCode, NSUInteger modifiers);
extern UInt32 CarbonModifierFlagsFromCocoaModifiers(NSUInteger flags);



@interface PermissionsManager : NSObject

+ (void)requestInputMonitoringPermission;
+ (void)openInputMonitoringPrefs;

+ (BOOL)checkInputMonitoringWithPrompt:(BOOL)prompt;
+ (BOOL)checkAccessibilityWithPrompt:(BOOL)prompt;
@end
