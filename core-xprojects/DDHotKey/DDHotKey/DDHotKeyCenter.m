/*
 DDHotKey -- DDHotKeyCenter.m
 
 Copyright (c) Dave DeLong <http://www.davedelong.com>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the author(s) or copyright holder(s) be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.
 */

#import <Carbon/Carbon.h>
#import <objc/runtime.h>

#import "DDHotKeyCenter.h"
#import "DDHotKeyUtilities.h"

#pragma mark Private Global Declarations

OSStatus dd_hotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData);

#pragma mark DDHotKey

@interface DDHotKey ()

@property (nonatomic, retain) NSValue *hotKeyRef;
@property (nonatomic) UInt32 hotKeyID;


@property (nonatomic, assign, setter = _setTarget:) id target;
@property (nonatomic, setter = _setAction:) SEL action;
@property (nonatomic, strong, setter = _setObject:) id object;
@property (nonatomic, copy, setter = _setTask:) DDHotKeyTask task;

@property (nonatomic, setter = _setKeyCode:) unsigned short keyCode;
@property (nonatomic, setter = _setModifierFlags:) NSUInteger modifierFlags;

@end

@implementation DDHotKey

+ (instancetype)hotKeyWithKeyCode:(unsigned short)keyCode modifierFlags:(NSUInteger)flags task:(DDHotKeyTask)task {
    DDHotKey *newHotKey = [[self alloc] init];
    [newHotKey _setTask:task];
    [newHotKey _setKeyCode:keyCode];
    [newHotKey _setModifierFlags:flags];
    return newHotKey;
}

- (void) dealloc {
    [[DDHotKeyCenter sharedHotKeyCenter] unregisterHotKey:self];
}

- (NSUInteger)hash {
    return [self keyCode] ^ [self modifierFlags];
}

- (BOOL)isEqual:(id)object {
    BOOL equal = NO;
    if ([object isKindOfClass:[DDHotKey class]]) {
        equal = ([object keyCode] == [self keyCode]);
        equal &= ([object modifierFlags] == [self modifierFlags]);
    }
    return equal;
}

- (NSString *)description {
    NSMutableArray *bits = [NSMutableArray array];
    if ((_modifierFlags & NSControlKeyMask) > 0) { [bits addObject:@"NSControlKeyMask"]; }
    if ((_modifierFlags & NSCommandKeyMask) > 0) { [bits addObject:@"NSCommandKeyMask"]; }
    if ((_modifierFlags & NSShiftKeyMask) > 0) { [bits addObject:@"NSShiftKeyMask"]; }
    if ((_modifierFlags & NSAlternateKeyMask) > 0) { [bits addObject:@"NSAlternateKeyMask"]; }
    
    NSString *flags = [NSString stringWithFormat:@"(%@)", [bits componentsJoinedByString:@" | "]];
    NSString *invokes = @"(block)";
    if ([self target] != nil && [self action] != nil) {
        invokes = [NSString stringWithFormat:@"[%@ %@]", [self target], NSStringFromSelector([self action])];
    }
    return [NSString stringWithFormat:@"%@\n\t(key: %hu\n\tflags: %@\n\tinvokes: %@)", [super description], [self keyCode], flags, invokes];
}

- (void)invokeWithEvent:(NSEvent *)event {
    if (_target != nil && _action != nil && [_target respondsToSelector:_action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_target performSelector:_action withObject:event withObject:_object];
#pragma clang diagnostic pop
    } else if (_task != nil) {
        _task(event);
    }
}

@end

#pragma mark DDHotKeyCenter

static DDHotKeyCenter *sharedHotKeyCenter = nil;

@implementation DDHotKeyCenter {
    NSMutableSet *_registeredHotKeys;
    UInt32 _nextHotKeyID;
}

+ (instancetype)sharedHotKeyCenter {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHotKeyCenter = [super allocWithZone:nil];
        sharedHotKeyCenter = [sharedHotKeyCenter init];
        
		EventTypeSpec eventSpec;
		eventSpec.eventClass = kEventClassKeyboard;
		eventSpec.eventKind = kEventHotKeyReleased;
		InstallApplicationEventHandler(&dd_hotKeyHandler, 1, &eventSpec, NULL, NULL);
    });
    return sharedHotKeyCenter;
}

+ (id)allocWithZone:(NSZone *)zone {
    return sharedHotKeyCenter;
}

- (id)init {
    if (self != sharedHotKeyCenter) { return sharedHotKeyCenter; }
    
    self = [super init];
    if (self) {
        _registeredHotKeys = [[NSMutableSet alloc] init];
        _nextHotKeyID = 1;
    }
    return self;
}

- (NSSet *)hotKeysMatching:(BOOL(^)(DDHotKey *hotkey))matcher {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return matcher(evaluatedObject);
    }];
    return [_registeredHotKeys filteredSetUsingPredicate:predicate];
}

- (BOOL)hasRegisteredHotKeyWithKeyCode:(unsigned short)keyCode modifierFlags:(NSUInteger)flags {
    return [self hotKeysMatching:^BOOL(DDHotKey *hotkey) {
        return hotkey.keyCode == keyCode && hotkey.modifierFlags == flags;
    }].count > 0;
}

- (DDHotKey *)_registerHotKey:(DDHotKey *)hotKey {
    if ([_registeredHotKeys containsObject:hotKey]) {
        return hotKey;
    }
    
    EventHotKeyID keyID;
    keyID.signature = 'htk1';
    keyID.id = _nextHotKeyID;
    
    EventHotKeyRef carbonHotKey;
    UInt32 flags = DDCarbonModifierFlagsFromCocoaModifiers([hotKey modifierFlags]);
    OSStatus err = RegisterEventHotKey([hotKey keyCode], flags, keyID, GetEventDispatcherTarget(), 0, &carbonHotKey);
    
    //error registering hot key
    if (err != 0) { return nil; }
    
    NSValue *refValue = [NSValue valueWithPointer:carbonHotKey];
    [hotKey setHotKeyRef:refValue];
    [hotKey setHotKeyID:_nextHotKeyID];
    
    _nextHotKeyID++;
    [_registeredHotKeys addObject:hotKey];
    
    return hotKey;
}

- (DDHotKey *)registerHotKey:(DDHotKey *)hotKey {
    return [self _registerHotKey:hotKey];
}

- (void)unregisterHotKey:(DDHotKey *)hotKey {
    NSValue *hotKeyRef = [hotKey hotKeyRef];
    if (hotKeyRef) {
        EventHotKeyRef carbonHotKey = (EventHotKeyRef)[hotKeyRef pointerValue];
        UnregisterEventHotKey(carbonHotKey);
        [hotKey setHotKeyRef:nil];
    }
    
    [_registeredHotKeys removeObject:hotKey];
}

- (DDHotKey *)registerHotKeyWithKeyCode:(unsigned short)keyCode modifierFlags:(NSUInteger)flags task:(DDHotKeyTask)task {
    //we can't add a new hotkey if something already has this combo
    if ([self hasRegisteredHotKeyWithKeyCode:keyCode modifierFlags:flags]) { return NO; }
    
    DDHotKey *newHotKey = [[DDHotKey alloc] init];
    [newHotKey _setTask:task];
    [newHotKey _setKeyCode:keyCode];
    [newHotKey _setModifierFlags:flags];
    
    return [self _registerHotKey:newHotKey];
}

- (DDHotKey *)registerHotKeyWithKeyCode:(unsigned short)keyCode modifierFlags:(NSUInteger)flags target:(id)target action:(SEL)action object:(id)object {
    //we can't add a new hotkey if something already has this combo
    if ([self hasRegisteredHotKeyWithKeyCode:keyCode modifierFlags:flags]) { return NO; }
    
    //build the hotkey object:
    DDHotKey *newHotKey = [[DDHotKey alloc] init];
    [newHotKey _setTarget:target];
    [newHotKey _setAction:action];
    [newHotKey _setObject:object];
    [newHotKey _setKeyCode:keyCode];
    [newHotKey _setModifierFlags:flags];
    return [self _registerHotKey:newHotKey];
}

- (void)unregisterHotKeysMatching:(BOOL(^)(DDHotKey *hotkey))matcher {
    //explicitly unregister the hotkey, since relying on the unregistration in -dealloc can be problematic
    @autoreleasepool {
        NSSet *matches = [self hotKeysMatching:matcher];
        for (DDHotKey *hotKey in matches) {
            [self unregisterHotKey:hotKey];
        }
    }
}

- (void)unregisterHotKeysWithTarget:(id)target {
    [self unregisterHotKeysMatching:^BOOL(DDHotKey *hotkey) {
        return hotkey.target == target;
    }];
}

- (void)unregisterHotKeysWithTarget:(id)target action:(SEL)action {
    [self unregisterHotKeysMatching:^BOOL(DDHotKey *hotkey) {
        return hotkey.target == target && sel_isEqual(hotkey.action, action);
    }];
}

- (void)unregisterHotKeyWithKeyCode:(unsigned short)keyCode modifierFlags:(NSUInteger)flags {
    [self unregisterHotKeysMatching:^BOOL(DDHotKey *hotkey) {
        return hotkey.keyCode == keyCode && hotkey.modifierFlags == flags;
    }];
}

- (void)unregisterAllHotKeys {
    NSSet *keys = [_registeredHotKeys copy];
    for (DDHotKey *key in keys) {
        [self unregisterHotKey:key];
    }
}

- (NSSet *)registeredHotKeys {
    return [self hotKeysMatching:^BOOL(DDHotKey *hotkey) {
        return hotkey.hotKeyRef != NULL;
    }];
}

@end

OSStatus dd_hotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
    @autoreleasepool {
        EventHotKeyID hotKeyID;
        GetEventParameter(theEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hotKeyID), NULL, &hotKeyID);
        
        UInt32 keyID = hotKeyID.id;
        
        NSSet *matchingHotKeys = [[DDHotKeyCenter sharedHotKeyCenter] hotKeysMatching:^BOOL(DDHotKey *hotkey) {
            return hotkey.hotKeyID == keyID;
        }];
        if ([matchingHotKeys count] > 1) { NSLog(@"ERROR!"); }
        DDHotKey *matchingHotKey = [matchingHotKeys anyObject];
        
        NSEvent *event = [NSEvent eventWithEventRef:theEvent];
        NSEvent *keyEvent = [NSEvent keyEventWithType:NSKeyUp
                                             location:[event locationInWindow]
                                        modifierFlags:[event modifierFlags]
                                            timestamp:[event timestamp]
                                         windowNumber:-1
                                              context:nil
                                           characters:@""
                          charactersIgnoringModifiers:@""
                                            isARepeat:NO
                                              keyCode:[matchingHotKey keyCode]];
        
        [matchingHotKey invokeWithEvent:keyEvent];
    }
    
    return noErr;
}
