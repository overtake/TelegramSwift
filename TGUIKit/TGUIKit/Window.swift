//
//  Window.swift
//  TGUIKit
//
//  Created by keepcoder on 16/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum HandlerPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
}

public func <(lhs: HandlerPriority, rhs: HandlerPriority) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

class KeyHandler : Comparable {
    let handler:()->Bool
    let object:WeakReference<NSObject>
    let priority:HandlerPriority
    let modifierFlags:NSEventModifierFlags?
    
    init(_ handler:@escaping()->Bool, _ object:NSObject?, _ priority:HandlerPriority, _ flags:NSEventModifierFlags?) {
        self.handler = handler
        self.object = WeakReference(value: object)
        self.priority = priority
        self.modifierFlags = flags
    }
}
func ==(lhs: KeyHandler, rhs: KeyHandler) -> Bool {
    return lhs.priority < rhs.priority
}
func <(lhs: KeyHandler, rhs: KeyHandler) -> Bool {
    return lhs.priority < rhs.priority
}

public class Window: NSWindow {
    private var keyHandlers:[KeyboardKey:[KeyHandler]] = [:]
    private var keyboardResponderHandler:(()->NSResponder?)?
    
    public func set(handler:@escaping() -> Bool, with object:NSObject, for key:KeyboardKey, priority:HandlerPriority = .low, modifierFlags:NSEventModifierFlags? = nil) -> Void {
        var handlers:[KeyHandler]? = keyHandlers[key]
        if handlers == nil {
            handlers = []
            keyHandlers[key] = handlers
        }
        keyHandlers[key]?.append(KeyHandler(handler, object, priority, modifierFlags))
        
        var bp:Int = 0
        bp += 1
    }
    
    public func remove(object:NSObject, for key:KeyboardKey) {
        var handlers = keyHandlers[key]
        if let handlers = handlers {
            var copy:[KeyHandler] = []
            for handle in handlers {
                copy.append(handle)
            }
            for i in 0 ..< copy.count {
                if copy[i].object.value == object  {
                    keyHandlers[key]?.remove(at: i)
                }
            }
        }
    }
    
    public func setKeyboardResponder(force handler:@escaping()->NSResponder?) {
        keyboardResponderHandler = handler
    }
    
    public override func sendEvent(_ event: NSEvent) {
        
        if event.type == .keyDown {
            if let responderHandler = keyboardResponderHandler {
                let responder = responderHandler()
                if self.firstResponder != responder {
                    self.makeFirstResponder(responder)
                }
            }
            
            if let keyCode = KeyboardKey(rawValue:event.keyCode), let handlers = keyHandlers[keyCode] {
                var sorted = handlers.sorted(by: >)
                for handle in sorted {
                    if let modifier = handle.modifierFlags {
                        if event.modifierFlags.contains(modifier) {
                            if handle.handler() {
                                return
                            }
                        }
                    } else {
                        if handle.handler() {
                             return
                        }
                        
                        
                    }
                }
            }
        }
        
        super.sendEvent(event)
    }
    
//    public func set(copy handler:@escaping()->Void) -> (()-> Void,NSEventModifierFlags?)? {
//        return self.set(handler: handler, for: .C, priority:.low, modifierFlags: [.command])
//    }
//    
//    public func set(paste handler:@escaping()->Void) -> (()-> Void,NSEventModifierFlags?)? {
//        return self.set(handler: handler, for: .V, modifierFlags: [.command])
//    }
    
    public func set(escape handler:@escaping() -> Bool, with object:NSObject, priority:HandlerPriority = .low, modifierFlags:NSEventModifierFlags? = nil) -> Void {
        set(handler: handler, with: object, for: .Escape, priority:priority, modifierFlags:modifierFlags)
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override init(contentRect: NSRect, styleMask style: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        self.acceptsMouseMovedEvents = true
    }
}
