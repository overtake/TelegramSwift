
#import <HotKey/HotKeyUtilities.h>
#import <Carbon/Carbon.h>
#import <Appkit/AppKit.h>

#import <IOKit/hidsystem/IOHIDLib.h>
extern UInt32 CarbonModifierFlagsFromCocoaModifiers(NSUInteger flags);


static NSDictionary *_KeyCodeToCharacterMap(void);
static NSDictionary *_KeyCodeToCharacterMap(void) {
    static NSDictionary *keyCodeMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyCodeMap = @{
                       @(kVK_Return) : @"↩",
                       @(kVK_Tab) : @"⇥",
                       @(kVK_Space) : @"⎵",
                       @(kVK_Delete) : @"⌫",
                       @(kVK_Escape) : @"⎋",
                       @(kVK_Command) : @"⌘",
                       @(kVK_Shift) : @"⇧",
                       @(kVK_CapsLock) : @"⇪",
                       @(kVK_Option) : @"⌥",
                       @(kVK_Control) : @"⌃",
                       @(kVK_RightShift) : @"⇧",
                       @(kVK_RightOption) : @"⌥",
                       @(kVK_RightControl) : @"⌃",
                       @(kVK_VolumeUp) : @"🔊",
                       @(kVK_VolumeDown) : @"🔈",
                       @(kVK_Mute) : @"🔇",
                       @(kVK_Function) : @"\u2318",
                       @(kVK_F1) : @"F1",
                       @(kVK_F2) : @"F2",
                       @(kVK_F3) : @"F3",
                       @(kVK_F4) : @"F4",
                       @(kVK_F5) : @"F5",
                       @(kVK_F6) : @"F6",
                       @(kVK_F7) : @"F7",
                       @(kVK_F8) : @"F8",
                       @(kVK_F9) : @"F9",
                       @(kVK_F10) : @"F10",
                       @(kVK_F11) : @"F11",
                       @(kVK_F12) : @"F12",
                       @(kVK_F13) : @"F13",
                       @(kVK_F14) : @"F14",
                       @(kVK_F15) : @"F15",
                       @(kVK_F16) : @"F16",
                       @(kVK_F17) : @"F17",
                       @(kVK_F18) : @"F18",
                       @(kVK_F19) : @"F19",
                       @(kVK_F20) : @"F20",
                       //                       @(kVK_Help) : @"",
                       @(kVK_ForwardDelete) : @"⌦",
                       @(kVK_Home) : @"↖",
                       @(kVK_End) : @"↘",
                       @(kVK_PageUp) : @"⇞",
                       @(kVK_PageDown) : @"⇟",
                       @(kVK_LeftArrow) : @"←",
                       @(kVK_RightArrow) : @"→",
                       @(kVK_DownArrow) : @"↓",
                       @(kVK_UpArrow) : @"↑",
                       };
    });
    return keyCodeMap;
}

NSString *StringFromKeyCode(unsigned short keyCode, NSUInteger modifiers) {
    NSMutableString *final = [NSMutableString stringWithString:@""];
    NSDictionary *characterMap = _KeyCodeToCharacterMap();
    
    if (modifiers & NSControlKeyMask) {
        [final appendString:[characterMap objectForKey:@(kVK_Control)]];
    }
    if (modifiers & NSAlternateKeyMask) {
        [final appendString:[characterMap objectForKey:@(kVK_Option)]];
    }
    if (modifiers & NSShiftKeyMask) {
        [final appendString:[characterMap objectForKey:@(kVK_Shift)]];
    }
    if (modifiers & NSCommandKeyMask) {
        [final appendString:[characterMap objectForKey:@(kVK_Command)]];
    }
    
    if (keyCode == kVK_Control || keyCode == kVK_Option || keyCode == kVK_Shift || keyCode == kVK_Command) {
        return final;
    }
    
    NSString *mapped = [characterMap objectForKey:@(keyCode)];
    if (mapped != nil) {
        [final appendString:mapped];
    } else {
        
        TISInputSourceRef currentKeyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
        CFDataRef uchr = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
        
        // Fix crash using non-unicode layouts, such as Chinese or Japanese.
        if (!uchr) {
            CFRelease(currentKeyboard);
            currentKeyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
            uchr = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
        }
        
        const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout*)CFDataGetBytePtr(uchr);
        
        if (keyboardLayout) {
            UInt32 deadKeyState = 0;
            UniCharCount maxStringLength = 255;
            UniCharCount actualStringLength = 0;
            UniChar unicodeString[maxStringLength];
            
            UInt32 keyModifiers = CarbonModifierFlagsFromCocoaModifiers(modifiers);
            
            OSStatus status = UCKeyTranslate(keyboardLayout,
                                             keyCode, kUCKeyActionDown, keyModifiers,
                                             LMGetKbdType(), 0,
                                             &deadKeyState,
                                             maxStringLength,
                                             &actualStringLength, unicodeString);
            
            if (actualStringLength > 0 && status == noErr) {
                NSString *characterString = [NSString stringWithCharacters:unicodeString length:(NSUInteger)actualStringLength];
                
                [final appendString:characterString];
            }
        }
    }
    
    return final;
}

UInt32 CarbonModifierFlagsFromCocoaModifiers(NSUInteger flags) {
    UInt32 newFlags = 0;
    if ((flags & NSControlKeyMask) > 0) { newFlags |= controlKey; }
    if ((flags & NSCommandKeyMask) > 0) { newFlags |= cmdKey; }
    if ((flags & NSShiftKeyMask) > 0) { newFlags |= shiftKey; }
    if ((flags & NSAlternateKeyMask) > 0) { newFlags |= optionKey; }
    if ((flags & NSAlphaShiftKeyMask) > 0) { newFlags |= alphaLock; }
    return newFlags;
}



@interface PermissionsManager ()
@end

@implementation PermissionsManager


+ (BOOL)checkAccessibilityWithPrompt:(BOOL)prompt
{
    // this is a 10.9 API but is only needed on 10.14.
    // with no prompt, this check is very fast. otherwise it blocks.
    NSDictionary *const options=@{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @(prompt)};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

+ (BOOL)checkInputMonitoringWithPrompt:(BOOL)prompt
{
    if (@available(macOS 10.15, *)) {
        static const IOHIDRequestType accessType=kIOHIDRequestTypeListenEvent;
        if (prompt) {
            // this will block
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                IOHIDRequestAccess(accessType);
            });
            return NO;
        }
        else {
            // this check is very fast
            return kIOHIDAccessTypeGranted==IOHIDCheckAccess(accessType);
        }
    }
    else {
        return [PermissionsManager checkAccessibilityWithPrompt:prompt];
    }
}

+ (NSURL *)securitySettingsUrlForKey:(NSString *)key
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"x-apple.systempreferences:com.apple.preference.security?%@", key]];
}

+ (void)openAccessibilityPrefs
{
    [[NSWorkspace sharedWorkspace] openURL:[PermissionsManager securitySettingsUrlForKey:@"Privacy_Accessibility"]];
}

+ (void)openInputMonitoringPrefs
{
    if (@available(macOS 10.15, *)) {
        [[NSWorkspace sharedWorkspace] openURL:[PermissionsManager securitySettingsUrlForKey:@"Privacy_ListenEvent"]];
    } else {
        [self openAccessibilityPrefs];
    }
}


@end
