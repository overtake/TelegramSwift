//
//  Window.swift
//  TGUIKit
//
//  Created by keepcoder on 16/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import KeyboardKey

public class AppWindow : Window {
    
    public enum ButtonPoint {
        case app
        case system
        
        var point: NSPoint {
            switch self {
            case .app:
                return NSMakePoint(20, 5)
            case .system:
                return NSMakePoint(9, 15)
            }
        }
    }
    
    
    
    public var initialButtonPoint: ButtonPoint = .app {
        didSet {
            updateButtons()
        }
    }
    private func updateButtons() {
//        if !isFullScreen {
//            var point: NSPoint = initialButtonPoint.point
//            self.standardWindowButton(.closeButton)?.setFrameOrigin(point)
//            point.x += 20
//            self.standardWindowButton(.miniaturizeButton)?.setFrameOrigin(point)
//            point.x += 20
//            self.standardWindowButton(.zoomButton)?.setFrameOrigin(point)
//        }
    }
    
    public override func layoutIfNeeded() {
        super.layoutIfNeeded()
      //  toolbar?.isVisible = !isFullScreen
        //updateButtons()
    }
}

public class ObervableView: NSView {
    private var listeners:[WeakReference<NSObject>] = []

    func add(listener: NSObject) {
        listeners.append(WeakReference(value: listener))
    }
    
    func remove(listener: NSObject) {
        let index = listeners.firstIndex(where: { (weakValue) -> Bool in
            return listener == weakValue.value
        })
        if let index = index {
            listeners.remove(at: index)
        }
    }
    override public func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        for listener in listeners {
            if let listener = listener.value as? ObservableViewDelegate {
                listener.observableView(self, didAddSubview: subview)
            }
        }
    }
    
    override public func willRemoveSubview(_ subview: NSView) {
        super.willRemoveSubview(subview)
        for listener in listeners {
            if let listener = listener.value as? ObservableViewDelegate {
                listener.observableview(self, willRemoveSubview: subview)
            }
        }
    }
    
}

protocol ObservableViewDelegate : class {
    func observableView(_ view: NSView, didAddSubview: NSView)
    func observableview(_ view: NSView, willRemoveSubview: NSView)
}

public enum HandlerPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case modal = 3
    case supreme = 4
}

public func <(lhs: HandlerPriority, rhs: HandlerPriority) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

class KeyHandler : Comparable {
    let handler:(NSEvent)->KeyHandlerResult
    let object:WeakReference<NSObject>
    let priority:HandlerPriority
    let modifierFlags:NSEvent.ModifierFlags?
    let date: TimeInterval
    init(_ handler:@escaping(NSEvent)->KeyHandlerResult, _ object:NSObject?, _ priority:HandlerPriority, _ flags:NSEvent.ModifierFlags?) {
        self.handler = handler
        self.object = WeakReference(value: object)
        self.priority = priority
        self.modifierFlags = flags
        self.date = Date().timeIntervalSince1970
    }
}
func ==(lhs: KeyHandler, rhs: KeyHandler) -> Bool {
    return lhs.priority == rhs.priority
}
func <(lhs: KeyHandler, rhs: KeyHandler) -> Bool {
    if lhs.priority == rhs.priority {
        return lhs.date < rhs.date
    }
    return lhs.priority < rhs.priority
}

public enum SwipeType{
    case left,right,none
}

public enum SwipeState {
    case start(controller: ViewController)
    case swiping(delta: CGFloat, controller: ViewController)
    case success(delta: CGFloat, controller: ViewController)
    case failed(delta: CGFloat, controller: ViewController)
    
    public var delta: CGFloat {
        switch self {
        case let .swiping(delta, _), let .success(delta, _), let .failed(delta, _):
            return delta
        default:
            return 0
        }
    }
    public func withAlwaysSuccess() -> SwipeState {
        switch self {
        case let .failed(delta, controller):
            return .success(delta: delta, controller: controller)
        default:
            return self
        }
    }
    public func withAlwaysFailed() -> SwipeState {
        switch self {
        case let .success(delta, controller):
            return .failed(delta: delta, controller: controller)
        default:
            return self
        }
    }
    var controller: ViewController {
        switch self {
        case let .start(controller):
            return controller
        case let .success(_, controller), let .failed(_, controller), let .swiping(_, controller):
            return controller
        }
    }
}

public enum SwipeDirection {
    case left(SwipeState)
    case right(SwipeState)
    case none
    
    func withAdditionalDelta(_ deltaX: CGFloat, _ force: Bool = false) -> SwipeDirection {
        switch self {
        case let .left(state):
            switch state {
            case let .swiping(delta, controller):
                return .left(.swiping(delta: force ? deltaX : delta + deltaX, controller: controller))
            case let .start(controller):
                return .left(.swiping(delta: 0, controller: controller))
            default:
                return self
            }
        case let .right(state):
            switch state {
            case let .swiping(delta, controller):
                return .right(.swiping(delta: force ? deltaX : delta - deltaX, controller: controller))
            case let .start(controller):
                return .right(.swiping(delta: 0, controller: controller))
            default:
                return self
            }
        default:
            return self
        }
    }
    
    public var delta: CGFloat {
        switch self {
        case let .left(state), let .right(state):
            return state.delta
        case .none:
            return 0
        }
    }
    
    func withUpdatedSuccessOrFail(_ width: CGFloat) -> SwipeDirection {
        switch self {
        case let .left(state):
            return .left(abs(state.delta) > width / 4 ? .success(delta: state.delta, controller: state.controller) : .failed(delta: state.delta, controller: state.controller))
        case let .right(state):
            return .right(abs(state.delta) > width / 4 ? .success(delta: state.delta, controller: state.controller) : .failed(delta: state.delta, controller: state.controller))
        default:
            return self
        }
    }
}

public enum SwipeHandlerResult {
    case success(ViewController)
    case failed
    case nothing
    case deltaUpdated(available: CGFloat)
}

class SwipeHandler : Comparable {
    let handler:(SwipeDirection, Bool)->SwipeHandlerResult
    let object:WeakReference<NSView>
    let priority:HandlerPriority
    
    init(_ handler:@escaping(SwipeDirection, Bool)->SwipeHandlerResult, _ object:NSView, _ priority:HandlerPriority) {
        self.handler = handler
        self.object = WeakReference(value: object)
        self.priority = priority
    }
}
func ==(lhs: SwipeHandler, rhs: SwipeHandler) -> Bool {
    return lhs.priority == rhs.priority
}
func <(lhs: SwipeHandler, rhs: SwipeHandler) -> Bool {
    return lhs.priority < rhs.priority
}


class ResponderObserver : Comparable {
    let handler:()->NSResponder?
    let ignoreKeys:[KeyboardKey]
    let object:WeakReference<NSObject>
    let priority:HandlerPriority
    let date: TimeInterval
    init(_ handler:@escaping()->NSResponder?, _ object:NSObject?, _ priority:HandlerPriority, _ ignoreKeys: [KeyboardKey]) {
        self.handler = handler
        self.ignoreKeys = ignoreKeys
        self.object = WeakReference(value: object)
        self.priority = priority
        self.date = Date().timeIntervalSince1970
    }
}
func ==(lhs: ResponderObserver, rhs: ResponderObserver) -> Bool {
    return lhs.priority == rhs.priority
}
func <(lhs: ResponderObserver, rhs: ResponderObserver) -> Bool {
    if lhs.priority == rhs.priority {
        return lhs.date < rhs.date
    }
    return lhs.priority < rhs.priority
}

class MouseObserver : Comparable {
    let handler:(NSEvent)->KeyHandlerResult
    let object:WeakReference<NSObject>
    let priority:HandlerPriority
    let type:NSEvent.EventType?
    let date: TimeInterval
    init(_ handler:@escaping(NSEvent)->KeyHandlerResult, _ object:NSObject?, _ priority:HandlerPriority, _ type:NSEvent.EventType) {
        self.handler = handler
        self.object = WeakReference(value: object)
        self.priority = priority
        self.type = type
        self.date = Date().timeIntervalSince1970
    }
}
func ==(lhs: MouseObserver, rhs: MouseObserver) -> Bool {
    return lhs.priority == rhs.priority
}
func <(lhs: MouseObserver, rhs: MouseObserver) -> Bool {
    if lhs.priority == rhs.priority {
        return lhs.date < rhs.date
    }
    return lhs.priority < rhs.priority
}

public typealias SwipeIdentifier = String

public enum KeyHandlerResult {
    case invoked // invoke and return
    case rejected // can invoke next priority event
    case invokeNext // invoke and send global event
}


open class Window: NSWindow {
    public var name: String = "TGUIKit.Window"
    private var keyHandlers:[KeyboardKey:[KeyHandler]] = [:]
    private var swipeHandlers:[SwipeIdentifier: SwipeHandler] = [:]
    private var swipeState:[SwipeIdentifier: SwipeDirection] = [:]
    public var keyUpHandler:((NSEvent)->Void)?
    private var responsders:[ResponderObserver] = []
    private var mouseHandlers:[UInt:[MouseObserver]] = [:]
    private var swipePoints:[NSPoint] = []
    private var saver:WindowSaver?
    public  var initFromSaver:Bool = false
    public  var copyhandler:(()->Void)? = nil
    public  var pastehandler:(()->Void)? = nil

    public  var masterCopyhandler:(()->Void)? = nil

    public var closeInterceptor:(()->Bool)? = nil
    public var orderOutHandler:(()->Void)? = nil
    public weak var rootViewController: ViewController?
    public var firstResponderFilter:(NSResponder?)->NSResponder? = { $0 }
    public var onToggleFullScreen:((Bool)->Void)? = nil
    
    public var isPushToTalkEquaivalent:((NSEvent)->Bool)?
    
    private let visibleObserver: ValuePromise<Bool> = ValuePromise(true, ignoreRepeated: true)

    public var acceptFirstMouse: Bool = true
    
    public static var controlsInset: CGFloat {
        return 70
    }

    private let isKeyWindowValue: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    public var keyWindowUpdater: Signal<Bool, NoError> {
        return self.isKeyWindowValue.get()
    }
    
    private let isFullScreenValue: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    public var fullScreen: Signal<Bool, NoError> {
        return self.isFullScreenValue.get()
    }

    private let occlusionStateValue: ValuePromise<NSWindow.OcclusionState> = ValuePromise(NSWindow.OcclusionState.visible, ignoreRepeated: true)

    public var takeOcclusionState: Signal<NSWindow.OcclusionState, NoError> {
        return occlusionStateValue.get()
    }

    public var visibility: Signal<Bool, NoError> {
        return visibleObserver.get()
    }
    
    open override func setIsVisible(_ flag: Bool) {
        super.setIsVisible(flag)
        self.visibleObserver.set(flag)
    }
    
    public func set(responder:@escaping() -> NSResponder?, with object:NSObject?, priority:HandlerPriority, ignoreKeys: [KeyboardKey] = []) {
        responsders.append(ResponderObserver(responder, object, priority, ignoreKeys + [.Escape, .LeftArrow, .RightArrow, .Tab, .UpArrow, .DownArrow, .Space]))
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
    
    
    public func set(handler:@escaping(NSEvent) -> KeyHandlerResult, with object:NSObject, for key:KeyboardKey, priority:HandlerPriority = .low, modifierFlags:NSEvent.ModifierFlags? = nil) -> Void {
        var handlers:[KeyHandler]? = keyHandlers[key]
        if handlers == nil {
            handlers = []
            keyHandlers[key] = handlers
        }
       
        keyHandlers[key]?.append(KeyHandler(handler, object, priority, modifierFlags))
        
        if key == .Return {
            set(handler: handler, with: self, for: .KeypadEnter, priority: priority, modifierFlags: modifierFlags)
        }
        
    }
    
    public func add(swipe handler:@escaping(SwipeDirection, Bool) -> SwipeHandlerResult, with object:NSView, identifier: SwipeIdentifier, priority:HandlerPriority = .low) -> Void {
        swipeHandlers[identifier] = SwipeHandler(handler, object, priority)
    }
    
    
    public func removeAllHandlers(for object:NSObject) {
        
        var newKeyHandlers:[KeyboardKey:[KeyHandler]] = [:]
        for (key, handlers) in keyHandlers {
            newKeyHandlers[key] = handlers
        }
        
        for (key, handlers) in keyHandlers {
            var copy:[KeyHandler] = []
            for handle in handlers {
                copy.append(handle)
            }
            for i in stride(from: copy.count - 1, to: -1, by: -1) {
                if copy[i].object.value === object  {
                    newKeyHandlers[key]?.remove(at: i)
                }
            }
        }
        self.keyHandlers = newKeyHandlers
        
        var newMouseHandlers:[UInt:[MouseObserver]] = [:]
        for (key, handlers) in mouseHandlers {
            newMouseHandlers[key] = handlers
        }
        
        for (key, handlers) in mouseHandlers {
            var copy:[MouseObserver] = []
            for handle in handlers {
                copy.append(handle)
            }
            for i in stride(from: copy.count - 1, to: -1, by: -1) {
                if copy[i].object.value === object  {
                    newMouseHandlers[key]?.remove(at: i)
                }
            }
        }
        self.mouseHandlers = newMouseHandlers
        
        self.swipeHandlers = self.swipeHandlers.filter { key, value in
            return value.object.value !== object && value.object.value != nil
        }
        self.responsders = responsders.filter {
            $0.object.value !== object
        }
    }
    
    public func remove(object:NSObject, for key:KeyboardKey, modifierFlags: NSEvent.ModifierFlags? = nil, forceCheckFlags: Bool = false) {
        let handlers = keyHandlers[key]
        if let handlers = handlers {
            var copy:[KeyHandler] = []
            for handle in handlers {
                copy.append(handle)
            }
            for i in stride(from: copy.count - 1, to: -1, by: -1) {
                if (copy[i].object.value == object || copy[i].object.value == nil) && ((forceCheckFlags || modifierFlags == nil) && modifierFlags == copy[i].modifierFlags) {
                    keyHandlers[key]?.remove(at: i)
                }
            }
        }
        if key == .Return {
            self.remove(object: object, for: .KeypadEnter, modifierFlags: modifierFlags, forceCheckFlags: forceCheckFlags)
        }
    }
    
    private func cleanUndefinedHandlers() {
        var newKeyHandlers:[KeyboardKey:[KeyHandler]] = [:]
        for (key, handlers) in keyHandlers {
            newKeyHandlers[key] = handlers
        }
        
        for (key, handlers) in keyHandlers {
            var copy:[KeyHandler] = []
            for handle in handlers {
                copy.append(handle)
            }
            for i in stride(from: copy.count - 1, to: -1, by: -1) {
                if copy[i].object.value == nil  {
                    newKeyHandlers[key]?.remove(at: i)
                }
            }
        }
        self.keyHandlers = newKeyHandlers
        
        var newMouseHandlers:[UInt:[MouseObserver]] = [:]
        for (key, handlers) in mouseHandlers {
            newMouseHandlers[key] = handlers
        }
        
        for (key, handlers) in mouseHandlers {
            var copy:[MouseObserver] = []
            for handle in handlers {
                copy.append(handle)
            }
            for i in stride(from: copy.count - 1, to: -1, by: -1) {
                if copy[i].object.value == nil  {
                    newMouseHandlers[key]?.remove(at: i)
                }
            }
        }
        self.mouseHandlers = newMouseHandlers
        
        self.swipeHandlers = self.swipeHandlers.filter { key, value in
            return value.object.value != nil
        }
        
    }
    
    public func set(mouseHandler:@escaping(NSEvent) -> KeyHandlerResult, with object:NSObject, for type:NSEvent.EventType, priority:HandlerPriority = .low) -> Void {
        var handlers:[MouseObserver]? = mouseHandlers[type.rawValue]
        if handlers == nil {
            handlers = []
            mouseHandlers[type.rawValue] = handlers
        }
        mouseHandlers[type.rawValue]?.append(MouseObserver(mouseHandler, object, priority, type))
    }
    
    public func remove(object:NSObject, for type:NSEvent.EventType) {
        let handlers = mouseHandlers[type.rawValue]
        if let handlers = handlers {
            var copy:[MouseObserver] = []
            for handle in handlers {
                copy.append(handle)
            }
            for i in stride(from: copy.count - 1, to: -1, by: -1) {
                if copy[i].object.value == object || copy[i].object.value == nil  {
                    mouseHandlers[type.rawValue]?.remove(at: i)
                }
            }
        }
    }
    
    
    public func applyResponderIfNeeded(_ event: NSEvent? = nil) ->Void {
        let sorted = responsders.sorted(by: >)
        
        if let event = event, event.modifierFlags.contains(.option) || event.modifierFlags.contains(.command)
         || event.modifierFlags.contains(.control) {
            return
        }
        for observer in sorted {
            if let event = event, let code = KeyboardKey(rawValue: event.keyCode), observer.ignoreKeys.contains(code) {
                continue
            }
            if let responder = observer.handler() {
                if self.firstResponder != responder {
                    let _ = self.resignFirstResponder()
                    if responder.responds(to: NSSelectorFromString("window")) {
                        let window:NSWindow? = responder.value(forKey: "window") as? NSWindow
                        if window != self {
                            continue
                        }
                    }
                    _ = self.makeFirstResponder(responder)
                    if let responder = responder as? NSTextField {
                        responder.setCursorToEnd()
                    }
                }
                break
            }
        }
    }

    open override func keyDown(with event: NSEvent) {

    }
    open override func keyUp(with event: NSEvent) {

    }
    open override func flagsChanged(with event: NSEvent) {

    }

    
    open override func performKeyEquivalent(with event: NSEvent) -> Bool {
        return self.isPushToTalkEquaivalent?(event) ?? super.performKeyEquivalent(with: event)
    }
    
    open override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        if let responder = responder, responder.responds(to: NSSelectorFromString("window")) {
            let window:NSWindow? = responder.value(forKey: "window") as? NSWindow
            if window != self {
                return false
            }
        }
        return super.makeFirstResponder(self.firstResponderFilter(responder))
    }
    
    open override func becomeFirstResponder() -> Bool {
        return false
    }
   

    public func sendKeyEvent(_ key: KeyboardKey, modifierFlags: NSEvent.ModifierFlags) {
        guard let event = NSEvent.keyEvent(with: .keyDown, location: mouseLocationOutsideOfEventStream, modifierFlags: modifierFlags, timestamp: Date().timeIntervalSince1970, windowNumber: windowNumber, context: graphicsContext, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: key.rawValue) else {return}
        
        sendEvent(event)
    }
    
    open override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        self.visibleObserver.set(self.isVisible)
    }
    open override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        orderOutHandler?()
        self.visibleObserver.set(self.isVisible)
    }
    
    public func enumerateAllSubviews(callback: (NSView) -> Void) {
        if let contentView = contentView {
            enumerateAllSubviews(callback: callback, superview: contentView)
        }
    }
    private func enumerateAllSubviews(callback: (NSView) -> Void, superview: NSView) {
        for view in superview.subviews {
            callback(view)
            if !view.subviews.isEmpty {
                enumerateAllSubviews(callback: callback, superview: view)
            }
        }
    }
    
    open override func close() {
        if let closeInterceptor = closeInterceptor, closeInterceptor() {
            return
        }
        if isReleasedWhenClosed {
            super.close()
        } else {
            super.close()
        }
        self.visibleObserver.set(self.isVisible)
    }
    
    private func scrollDeltaXAfterInvertion(_ value: CGFloat) -> CGFloat {
        var deltaX: CGFloat = 0
        let isInverted: Bool = System.isScrollInverted
        
        if !isInverted {
            deltaX = -value
        } else {
            deltaX = value
        }
        return deltaX
    }
    
    private func startSwiping(_ event: NSEvent) {
        if event.scrollingDeltaY == 0 && event.scrollingDeltaX != 0 {
            for (key, swipe) in swipeHandlers.sorted(by: { $0.value.priority > $1.value.priority }) {
                if let view = swipe.object.value, view._mouseInside() {
                    if scrollDeltaXAfterInvertion(event.scrollingDeltaX) > 0 {
                        let result = swipe.handler(.left(.start(controller: ViewController())), true)
                        switch result {
                        case let .success(controller):
                            swipeState[key] = .left(.start(controller: controller))
                            break
                        default:
                            break
                        }
                    } else {
                        let result = swipe.handler(.right(.start(controller: ViewController())), true)
                        switch result {
                        case let .success(controller):
                            swipeState[key] = .right(.start(controller: controller))
                            break
                        default:
                            break
                        }
                    }
                }
            }
        }
        
    }
    private func stopSwiping(_ event: NSEvent) {
        for (key, swipe) in swipeState {
            if let handler = swipeHandlers[key], let view = handler.object.value {
                _ = handler.handler(swipe.withUpdatedSuccessOrFail(view.frame.width), true)
            }
        }
        swipeState.removeAll()
    }
    
    
    private func proccessSwiping(_ event: NSEvent) -> Void {
        let copy = self.swipeState
        for (key, swipe) in copy {
            if let handler = swipeHandlers[key], let value = handler.object.value, value._mouseInside() {
                let deltaX: CGFloat = scrollDeltaXAfterInvertion(event.scrollingDeltaX)
                
                let newState = swipe.withAdditionalDelta(deltaX)
                let result = handler.handler(newState, true)
                switch result {
                case let .deltaUpdated(available):
                    swipeState[key] = swipe.withAdditionalDelta(available, true)
                default:
                    swipeState[key] = newState
                }
                break
            }
        }
    }
    
    public func abortSwiping() -> Void {
        let copy = self.swipeState
        for (key, swipe) in copy {
            switch swipe {
            case let .left(state):
                let swipe: SwipeDirection = .left(.failed(delta: state.delta, controller: state.controller))
                if let handler = swipeHandlers[key] {
                    _ = handler.handler(swipe, false)
                }
                self.swipeState.removeValue(forKey: key)
            case let .right(state):
                let swipe: SwipeDirection = .right(.failed(delta: state.delta, controller: state.controller))
                if let handler = swipeHandlers[key] {
                    _ = handler.handler(swipe, false)
                }
            default:
                break
            }
        }
        self.swipeState.removeAll()
    }
    
    public var inLiveSwiping: Bool {
        return !swipeState.isEmpty
    }
    
    @objc public func pasteToFirstResponder(_ sender: Any) {
        
        if let pastehandler = pastehandler {
            pastehandler()
        } else {
            applyResponderIfNeeded()
            if let firstResponder = firstResponder, firstResponder.responds(to: NSSelectorFromString("paste:")) {
                firstResponder.performSelector(onMainThread: NSSelectorFromString("paste:"), with: sender, waitUntilDone: false)
            }
        }
        
        
    }
    
    @objc public func copyFromFirstResponder(_ sender: Any) {
        if let copyhandler = copyhandler {
            copyhandler()
        } else {
            if let firstResponder = firstResponder, firstResponder.responds(to: NSSelectorFromString("copy:")) {
                firstResponder.performSelector(onMainThread: NSSelectorFromString("copy:"), with: sender, waitUntilDone: false)
            }
        }
        
    }
    
    
    open override func sendEvent(_ event: NSEvent) {
        
        //        let testEvent = NSEvent.EventType.init(rawValue: 36)!
        //
        
//        if event.type.rawValue == 29 {
//            NSLog("\(event.modifierFlags.rawValue)")
//            var bp:Int = 0
//            bp += 1
//        }
        
        if event.type == .keyUp {
            self.keyUpHandler?(event)
        }
        
        
        let eventType = event.type
        if sheets.isEmpty {
            if eventType == .keyDown {
                
                applyResponderIfNeeded(event)
                
                cleanUndefinedHandlers()
                
                if let globalHandlers = keyHandlers[.All]?.sorted(by: >), let keyCode = KeyboardKey(rawValue:event.keyCode) {
                    for globalHandler in globalHandlers {
                        let handle = keyHandlers[keyCode]?.sorted(by: >).first
                        if handle == nil || globalHandler.priority > handle!.priority {
                            if (handle?.modifierFlags == nil || !event.modifierFlags.contains(handle!.modifierFlags!)) || globalHandler.priority == .supreme {
                                switch globalHandler.handler(event) {
                                case .invoked:
                                    return
                                case .rejected:
                                    break
                                case .invokeNext:
                                    super.sendEvent(event)
                                    return
                                }
                            }
                        }
                    }
                }
                
                if let keyCode = KeyboardKey(rawValue:event.keyCode), let handlers = keyHandlers[keyCode]?.sorted(by: >) {
                    loop: for handle in handlers {
                        
                        if (handle.modifierFlags == nil || event.modifierFlags.contains(handle.modifierFlags!))  {
                            
                            switch handle.handler(event) {
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
            } else if eventType == .scrollWheel, !swipeHandlers.isEmpty  {
                
                
                if let handlers = mouseHandlers[eventType.rawValue] {
                    let sorted = handlers.sorted(by: >)
                    loop: for handle in sorted {
                        switch handle.handler(event) {
                        case .invoked:
                            return
                        case .rejected:
                            continue
                        case .invokeNext:
                            break loop
                        }
                    }
                }
                
                switch event.phase {
                case NSEvent.Phase.began:
                    startSwiping(event)
                case NSEvent.Phase.stationary:
                    break
                case NSEvent.Phase.changed:
                    proccessSwiping(event)
                case NSEvent.Phase.ended:
                    stopSwiping(event)
                case NSEvent.Phase.cancelled:
                    stopSwiping(event)
                case NSEvent.Phase.mayBegin:
                    break
                default:
                    break
                }
                
            } else if let handlers = mouseHandlers[eventType.rawValue] {
                let sorted = handlers.sorted(by: >)
                loop: for handle in sorted {
                    switch handle.handler(event) {
                    case .invoked:
                        return
                    case .rejected:
                        continue
                    case .invokeNext:
                        break loop
                    }
                }
            }
            if eventType == .rightMouseDown {
                if !swipeState.isEmpty {
                    stopSwiping(event)
                }
            }
            super.sendEvent(event)
        } else {
            //super.sendEvent(event)
        }
        
        
    }
    
    open override func swipe(with event: NSEvent) {
        super.swipe(with: event)
    }
    
    //    public func set(copy handler:@escaping()->Void) -> (()-> Void,NSEventModifierFlags?)? {
    //        return self.set(handler: handler, for: .C, priority:.low, modifierFlags: [.command])
    //    }
    //
    //    public func set(paste handler:@escaping()->Void) -> (()-> Void,NSEventModifierFlags?)? {
    //        return self.set(handler: handler, for: .V, modifierFlags: [.command])
    //    }
    
    public func set(escape handler:@escaping(NSEvent) -> KeyHandlerResult, with object:NSObject, priority:HandlerPriority = .low, modifierFlags:NSEvent.ModifierFlags? = nil) -> Void {
        set(handler: handler, with: object, for: .Escape, priority:priority, modifierFlags:modifierFlags)
    }
    
    open override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    public var _canBecomeKey = true
    open override var canBecomeKey: Bool {
        return _canBecomeKey
    }
    public var _canBecomeMain = true
    open override var canBecomeMain: Bool {
        return _canBecomeMain
    }
    
    open override func deminiaturize(_ sender: Any?) {
        super.deminiaturize(sender)
    }
    
    
    public var isFullScreen: Bool {
        return styleMask.contains(.fullScreen)
    }
    
    @discardableResult public func initSaver() -> Bool {
        self.initFromSaver = true
        self.saver = .find(for: self)
        if let saver = saver {
            self.setFrame(saver.rect, display: true)
            if saver.isFullScreen {
                toggleFullScreen(self)
            }
            return true
        }
        return false
    }
    
    public var processFullScreen:((Bool, @escaping(Bool)->Void)->Void)?
    
    private func invokeFullScreen(_ sender: Any?) {
        CATransaction.begin()
        super.toggleFullScreen(sender)
        CATransaction.commit()
        saver?.isFullScreen = isFullScreen
    }
    
    open override func toggleFullScreen(_ sender: Any?) {
        let newValue = !isFullScreen
        self.onToggleFullScreen?(newValue)
        
        if let process = processFullScreen {
            process(newValue, { [weak self] value in
                self?.invokeFullScreen(nil)
                self?.onToggleFullScreen?(newValue)
            })
        } else {
            invokeFullScreen(nil)
            DispatchQueue.main.async {
                self.isFullScreenValue.set(newValue)
            }
        }
    }
    
    public var _windowDidExitFullScreen:(()->Void)?
    @objc func windowDidExitFullScreen(_ notification: Notification) {
        _windowDidExitFullScreen?()
        _windowDidExitFullScreen = nil
    }
    
    @objc func windowDidNeedSaveState(_ notification: Notification) {
        guard let saver = saver, !saver.isFullScreen && !isFullScreen else {
            self.saver?.save()
            return
        }
        saver.rect = frame
        saver.save()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func windowImageShot() -> CGImage? {
        if windowNumber >= 0 {
            return CGWindowListCreateImage(CGRect.null, [.optionIncludingWindow], CGWindowID(windowNumber), [.boundsIgnoreFraming])
        } else {
            return nil
        }
    }



    @objc open func windowDidBecomeKey() {
        isKeyWindowValue.set(true)

    }

    @objc open func windowDidResignKey() {
        isKeyWindowValue.set(false)
    }

    /*
     - (void)windowDidChangeOcclusionState:(NSNotification *)notification
     {
         if ([[notification object] occlusionState]  &  NSWindowOcclusionStateVisible) {
             // visible
         } else {
             // occluded
         }
     }
     */

    @objc func windowDidChangeOcclusionState() {
        occlusionStateValue.set(self.occlusionState)
    }
    
    open override func updateConstraintsIfNeeded() {
        
    }
    

    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        
        
        
        self.acceptsMouseMovedEvents = true
        occlusionStateValue.set(self.occlusionState)
        isOpaque = true
        
        self.contentView?.allowedTouchTypes = [.direct]
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidNeedSaveState(_:)), name: NSWindow.didMoveNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidNeedSaveState(_:)), name: NSWindow.didResizeNotification, object: self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: self)


        NotificationCenter.default.addObserver(self, selector: #selector(windowDidExitFullScreen(_:)), name: NSWindow.didExitFullScreenNotification, object: self)

        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidChangeOcclusionState), name: NSWindow.didChangeOcclusionStateNotification, object: self)


    }
    
    public static var statusBarHeight: CGFloat {
        return 22
    }

}
