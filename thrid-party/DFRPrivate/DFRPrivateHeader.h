

#import <AppKit/AppKit.h>
#ifndef APP_STORE
extern void DFRElementSetControlStripPresenceForIdentifier(NSString *, BOOL);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL);
#endif

@interface NSTouchBarItem ()

+ (void)addSystemTrayItem:(NSTouchBarItem *)item;

@end

@interface NSTouchBarItem (DFRAccess)

- (void)addToControlStrip;

- (void)toggleControlStripPresence:(BOOL)present;

@end

@interface NSTouchBar ()

+ (void)presentSystemModalFunctionBar:(NSTouchBar *)touchBar
             systemTrayItemIdentifier:(NSString *)identifier;

+ (void)dismissSystemModalFunctionBar:(NSTouchBar *)touchBar;

+ (void)minimizeSystemModalFunctionBar:(NSTouchBar *)touchBar;

@end

@interface NSTouchBar (DFRAccess)

- (void)presentAsSystemModalForItem:(NSTouchBarItem *)item;

- (void)dismissSystemModal;

- (void)minimizeSystemModal;

@end

@interface NSControlStripTouchBarItem: NSCustomTouchBarItem

@property (nonatomic) BOOL isPresentInControlStrip;

@end

