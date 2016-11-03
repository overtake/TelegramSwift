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
    case modal = 3
    
}

public func <(lhs: HandlerPriority, rhs: HandlerPriority) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

class KeyHandler : Comparable {
    let handler:()->KeyHandlerResult
    let object:WeakReference<NSObject>
    let priority:HandlerPriority
    let modifierFlags:NSEventModifierFlags?
    
    init(_ handler:@escaping()->KeyHandlerResult, _ object:NSObject?, _ priority:HandlerPriority, _ flags:NSEventModifierFlags?) {
        self.handler = handler
        self.object = WeakReference(value: object)
        self.priority = priority
        self.modifierFlags = flags
    }
}
func ==(lhs: KeyHandler, rhs: KeyHandler) -> Bool {
    return lhs.priority == rhs.priority
}
func <(lhs: KeyHandler, rhs: KeyHandler) -> Bool {
    return lhs.priority < rhs.priority
}


class ResponderObserver : Comparable {
    let handler:()->NSResponder?
    let object:WeakReference<NSObject>
    let priority:HandlerPriority
    
    init(_ handler:@escaping()->NSResponder?, _ object:NSObject?, _ priority:HandlerPriority) {
        self.handler = handler
        self.object = WeakReference(value: object)
        self.priority = priority
    }
}
func ==(lhs: ResponderObserver, rhs: ResponderObserver) -> Bool {
    return lhs.priority == rhs.priority
}
func <(lhs: ResponderObserver, rhs: ResponderObserver) -> Bool {
    return lhs.priority < rhs.priority
}

public enum KeyHandlerResult {
    case invoked // invoke and return
    case rejected // can invoke next priprity event
    case invokeNext // invoke and send global event
}

public class Window: NSWindow {
    private var keyHandlers:[KeyboardKey:[KeyHandler]] = [:]
    private var responsders:[ResponderObserver] = []
    
    public func set(responder:@escaping() -> NSResponder?, with object:NSObject?, priority:HandlerPriority) {
        responsders.append(ResponderObserver(responder, object, priority))
    }
    
    public func removeObserver(for object:NSObject) {
        var copy:[ResponderObserver] = []
        for observer in responsders {
            copy.append(observer)
        }
        for i in stride(from: copy.count - 1, to: -1, by: -1) {
            if copy[i].object.value == object || copy[i].object.value == nil  {
                responsders.remove(at: i)
            }
        }
    }
    
    public func set(handler:@escaping() -> KeyHandlerResult, with object:NSObject, for key:KeyboardKey, priority:HandlerPriority = .low, modifierFlags:NSEventModifierFlags? = nil) -> Void {
        var handlers:[KeyHandler]? = keyHandlers[key]
        if handlers == nil {
            handlers = []
            keyHandlers[key] = handlers
        }
        keyHandlers[key]?.append(KeyHandler(handler, object, priority, modifierFlags))

    }
    
    public func remove(object:NSObject, for key:KeyboardKey) {
        var handlers = keyHandlers[key]
        if let handlers = handlers {
            var copy:[KeyHandler] = []
            for handle in handlers {
                copy.append(handle)
            }
            for i in stride(from: copy.count - 1, to: -1, by: -1) {
                if copy[i].object.value == object || copy[i].object.value == nil  {
                    keyHandlers[key]?.remove(at: i)
                }
            }
        }
    }
    
    public func applyResponderIfNeeded() ->Void {
        let sorted = responsders.sorted(by: >)
        
        for observer in sorted {
            if let responder = observer.handler() {
                if self.firstResponder != responder {
                    let _ = self.resignFirstResponder()
                    self.makeFirstResponder(responder)
                }
                break
            }
        }
    }
    
    
    
    @objc public func pasteToFirstResponder(_ sender: Any) {
        
        applyResponderIfNeeded()
        
        if firstResponder.responds(to: NSSelectorFromString("paste:")) {
            firstResponder.performSelector(onMainThread: NSSelectorFromString("paste:"), with: sender, waitUntilDone: false)
        }
        
    }
    
    public override func sendEvent(_ event: NSEvent) {
        
        if event.type == .keyDown {
            
           applyResponderIfNeeded()
            
            
            
//            if let responderHandler = keyboardResponderHandler {
//                let responder = responderHandler()
//                if self.firstResponder != responder {
//                    self.makeFirstResponder(responder)
//                }
//            }
            
            if let keyCode = KeyboardKey(rawValue:event.keyCode), let handlers = keyHandlers[keyCode] {
                var sorted = handlers.sorted(by: >)
                loop: for handle in sorted {
                    if (handle.modifierFlags == nil || event.modifierFlags.contains(handle.modifierFlags!))  {
                        
                        switch handle.handler() {
                        case .invoked:
                            return
                        case .rejected:
                            continue
                        case .invokeNext:
                            break loop
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
    
    public func set(escape handler:@escaping() -> KeyHandlerResult, with object:NSObject, priority:HandlerPriority = .low, modifierFlags:NSEventModifierFlags? = nil) -> Void {
        set(handler: handler, with: object, for: .Escape, priority:priority, modifierFlags:modifierFlags)
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override init(contentRect: NSRect, styleMask style: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        self.acceptsMouseMovedEvents = true
        self.contentView?.wantsLayer = true
      //  self.contentView?.canDrawSubviewsIntoLayer = true
    }
}
