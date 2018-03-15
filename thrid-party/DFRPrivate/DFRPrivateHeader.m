
#import <Foundation/Foundation.h>
#import "DFRPrivateHeader.h"

@implementation NSTouchBarItem (DFRAccess)

- (void)addToControlStrip {
    [NSTouchBarItem addSystemTrayItem:self];
    
    [self toggleControlStripPresence:true];
}

- (void)toggleControlStripPresence:(BOOL)present {
#ifndef APP_STORE
    DFRElementSetControlStripPresenceForIdentifier(self.identifier,
                                                   present);
#endif
}

@end

@implementation NSTouchBar (DFRAccess)

- (void)presentAsSystemModalForItem:(NSTouchBarItem *)item {
    [NSTouchBar presentSystemModalFunctionBar:self
                     systemTrayItemIdentifier:item.identifier];
}

- (void)dismissSystemModal {
    [NSTouchBar dismissSystemModalFunctionBar:self];
}

- (void)minimizeSystemModal {
    [NSTouchBar minimizeSystemModalFunctionBar:self];
}

@end

@implementation NSControlStripTouchBarItem

- (void)setIsPresentInControlStrip:(BOOL)present {
    _isPresentInControlStrip = present;
    
    if (present) {
        [super addToControlStrip];
    } else {
        [super toggleControlStripPresence:false];
    }
}

-(void)dealloc {
    int bp = 0;
    bp += 1;
}

@end
