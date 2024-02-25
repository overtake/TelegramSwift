//
//  Control.swift
//  TGUIKit
//
//  Created by keepcoder on 25/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import AppKit

public enum ControlState {
    case Normal
    case Hover
    case Highlight
    case Other
}

public enum ControlEvent {
    case Down
    case Up
    case Click
    case DoubleClick
    case SingleClick
    case RightClick
    case RightDown
    case RightUp
    case MouseDragging
    case LongMouseDown
    case LongMouseUp
    case LongOver
}

private let longHandleDisposable = MetaDisposable()
private let longOverHandleDisposable = MetaDisposable()


internal struct ControlEventHandler : Hashable {
    static func == (lhs: ControlEventHandler, rhs: ControlEventHandler) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    let identifier: UInt32
    let handler:(Control)->Void
    let event:ControlEvent
    let `internal`: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
internal struct ControlStateHandler : Hashable {
    static func == (lhs: ControlStateHandler, rhs: ControlStateHandler) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    let identifier: UInt32
    let handler:(Control)->Void
    let state:ControlState
    let `internal`: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

open class Control: View {
    
    public var contextObject: Any?
    
    
    public internal(set) weak var popover: Popover?
    
    open var isEnabled:Bool = true {
        didSet {
            if isEnabled != oldValue {
                apply(state: controlState)
            }
        }
    }
    open var hideAnimated:Bool = false
    
    
    public var appTooltip: String? {
        didSet {
            if let tp = appTooltip, controlState == .Hover {
                tooltip(for: self, text: tp)
            }
        }
    }

    open var isSelected:Bool {
        didSet {
            updateState()
            if isSelected != oldValue {
                apply(state: isSelected ? .Highlight : self.controlState)
            }
            
            updateSelected(isSelected)
        }
    }
    
    open func updateSelected(_ isSelected: Bool) {
        
    }
    
    open var animationStyle:AnimationStyle = AnimationStyle(duration:0.3, function:CAMediaTimingFunctionName.spring)
    
    var trackingArea:NSTrackingArea?
    
    
    
    private var handlers:[ControlEventHandler] = []
    private var stateHandlers:[ControlStateHandler] = []
    
    private(set) internal var backgroundState:[ControlState:NSColor] = [:]
    
    private(set) internal var cursorState:[ControlState:NSCursor] = [:]
    
    private var mouseMovedInside: Bool = true
    private var longInvoked: Bool = false
    public var handleLongEvent: Bool = true
    
    public var scaleOnClick: Bool = false
    
    open override var backgroundColor: NSColor {
        get{
            return self.style.backgroundColor
        }
        set {
            if self.style.backgroundColor != newValue {
                self.style.backgroundColor = newValue
                self.setNeedsDisplayLayer()
            }
        }
    }
    
    public var style:ControlStyle = ControlStyle() {
        didSet {
            if style != oldValue {
                apply(style:style)
            }
        }
    }
    
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            self.controlState = .Normal
        }
        updateTrackingAreas()
    }
    
    public var controlState:ControlState = .Normal {
        didSet {
            stateDidUpdate(controlState)
            for value in stateHandlers {
                if value.state == .Other {
                    value.handler(self)
                }
            }
            if oldValue != controlState {
                
                for value in stateHandlers {
                    if value.state == controlState {
                        value.handler(self)
                    }
                }

                if let tp = appTooltip, controlState == .Hover {
                    tooltip(for: self, text: tp)
                }
            }
            apply(state: isSelected ? .Highlight : controlState)
        }
    }
    
    public func apply(state:ControlState) -> Void {
        let state:ControlState = self.isSelected ? .Highlight : state
        if isEnabled {
            if let color = backgroundState[state] {
                self.layer?.backgroundColor = color.cgColor
            } else {
                self.layer?.backgroundColor = backgroundState[.Normal]?.cgColor ?? self.backgroundColor.cgColor
            }
        } else {
            self.layer?.backgroundColor = backgroundState[.Normal]?.cgColor ?? self.backgroundColor.cgColor
        }
        if animates {
            self.layer?.animateBackground()
        }
        
        let cursor: NSCursor? = cursorState[state]
        if let cursor = cursor {
            cursor.set()
        } else if !cursorState.isEmpty {
            NSCursor.arrow.set()
        }
    }
    private var previousState: ControlState?
    open func stateDidUpdate(_ state: ControlState) {
        if self.scaleOnClick {
            if state != previousState, isEnabled {
                if state == .Highlight {
                    self.layer?.animateScaleSpring(from: 1, to: 0.97, duration: 0.3, removeOnCompletion: false)
                } else if self.layer?.animation(forKey: "transform") != nil, previousState == ControlState.Highlight {
                    self.layer?.animateScaleSpring(from: 0.97, to: 1.0, duration: 0.3)
                }
            }
        }
        previousState = state
    }
    
    private var mouseIsDown:Bool {
        return (NSEvent.pressedMouseButtons & (1 << 0)) != 0
    }
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        trackingArea = nil
        
        if let _ = window, visibleRect != .zero {
            let options:NSTrackingArea.Options = [.cursorUpdate, .mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .assumeInside, .inVisibleRect]
            self.trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            
            self.addTrackingArea(self.trackingArea!)
        } 
        
    }
    
    open override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    open override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateTrackingAreas()
    }
    
    deinit {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        self.popover?.hide()
        
    //    longHandleDisposable.dispose()
     //   longOverHandleDisposable.dispose()
    }
    
    public var controlIsHidden: Bool {
        return super.isHidden || (layer!.opacity < Float(0.5) && !controlOpacityEventIgnored)
    }
    
    public var controlOpacityEventIgnored: Bool = false
    
    open override var isHidden: Bool {
        get {
            return super.isHidden
        }
        set {
            if newValue != super.isHidden {
                if hideAnimated {
                    if !newValue {
                        super.isHidden = newValue
                    }
                    self.layer?.opacity = newValue ? 0.0 : 1.0
                    self.layer?.animateAlpha(from: newValue ? 1.0 : 0.0, to: newValue ? 0.0 : 1.0, duration: 0.2, completion:{ [weak self] completed in
                        if completed {
                            self?.updateHiddenState(newValue)
                        }
                    })
                    
                } else {
                    updateHiddenState(newValue)
                }
            }
        }
    }
    
    public func forceHide() -> Void {
        super.isHidden = true
        self.layer?.removeAllAnimations()
    }
    
    private func updateHiddenState(_ value:Bool) -> Void {
        super.isHidden = value
    }
    
    
    public var canHighlight: Bool = true
    
    @discardableResult public func set(handler:@escaping (Control) -> Void, for event:ControlEvent) -> UInt32 {
        return set(handler: handler, for: event, internal: false)
    }
    
    @discardableResult public func set(handler:@escaping (Control) -> Void, for state:ControlState) -> UInt32 {
        return set(handler: handler, for: state, internal: false)
    }
    
    @discardableResult internal func set(handler:@escaping (Control) -> Void, for event:ControlEvent, internal: Bool) -> UInt32 {
        let new = ControlEventHandler(identifier: arc4random(), handler: handler, event: event, internal: `internal`)
        handlers.append(new)
        return new.identifier
    }
    
    @discardableResult internal func set(handler:@escaping (Control) -> Void, for state:ControlState, internal: Bool) -> UInt32 {
        let new = ControlStateHandler(identifier: arc4random(), handler: handler, state: state, internal: `internal`)
        stateHandlers.append(new)
        return new.identifier
    }
    
    open override func cursorUpdate(with event: NSEvent) {
      //  super.cursorUpdate(with: event)
        apply(state: self.controlState)
    }
    
    public func set(background:NSColor, for state:ControlState) -> Void {
        backgroundState[state] = background
        apply(state: self.controlState)
        self.setNeedsDisplayLayer()
    }
    
    public func set(cursor:NSCursor, for state:ControlState) -> Void {
        cursorState[state] = cursor
        apply(state: self.controlState)
        self.setNeedsDisplayLayer()
    }
    
    public func removeLastHandler() -> ((Control)->Void)? {
        var last: ControlEventHandler?
        for handler in handlers.reversed() {
            if !handler.internal {
                last = handler
                break
            }
        }
        if let last = last {
            self.handlers.removeAll(where: { last.identifier == $0.identifier })
            return last.handler
        }
        return nil
    }
    
    public func removeLastStateHandler() -> Void {
        
        var last: ControlStateHandler?
        for handler in stateHandlers.reversed() {
            if !handler.internal {
                last = handler
                break
            }
        }
        if let last = last {
            self.stateHandlers.removeAll(where: { last.identifier == $0.identifier })
        }
    }
    
    public func removeStateHandler(_ identifier: UInt32) -> Void {
        self.stateHandlers.removeAll(where: { identifier == $0.identifier })
    }
    
    public func removeHandler(_ identifier: UInt32) -> Void {
        self.handlers.removeAll(where: { identifier == $0.identifier })
    }
    
    public func removeAllStateHandlers() -> Void {
        self.stateHandlers.removeAll(where: { !$0.internal })

    }
    
    public func removeAllHandlers() ->Void {
        self.handlers.removeAll(where: { !$0.internal })
    }
    
    
    override open func mouseDown(with event: NSEvent) {
        longInvoked = false
        longOverHandleDisposable.set(nil)
                
        if event.modifierFlags.contains(.control) {
            
            if let menu = self.contextMenu?(), event.clickCount == 1 {
                AppMenu.show(menu: menu, event: event, for: self)
            }
            
            for handler in handlers {
                if handler.event == .RightDown {
                    handler.handler(self)
                }
            }
            if sendRightMouseAnyway {
                super.mouseDown(with: event)
            }
            return
        }
        
        if userInteractionEnabled {
            updateState()
            
        }
        if self.handlers.isEmpty, let menu = self.contextMenu?(), event.clickCount == 1 {
            AppMenu.show(menu: menu, event: event, for: self)
        }
        
        if userInteractionEnabled {
            updateState()
            send(event: .Down)
            if handleLongEvent {
                let point = event.locationInWindow
                let disposable = (Signal<Void,Void>.single(Void()) |> delay(0.35, queue: Queue.mainQueue())).start(next: { [weak self] in
                    self?.invokeLongDown(event, point: point)
                })
                
                longHandleDisposable.set(disposable)
            } else {
                longHandleDisposable.set(nil)
            }
           
            
        } else {
            super.mouseDown(with: event)
        }
    }
    
    private func invokeLongDown(_ event: NSEvent, point: NSPoint) {
        if self.mouseInside(), let wPoint = self.window?.mouseLocationOutsideOfEventStream, NSPointInRect(point, NSMakeRect(wPoint.x - 2, wPoint.y - 2, 4, 4)) {
            self.longInvoked = true
            if let menu = self.contextMenu?(), handlers.filter({ $0.event == .LongMouseDown }).isEmpty {
                AppMenu.show(menu: menu, event: event, for: self)
            }
            self.send(event: .LongMouseDown)
        }
    }
    
    public var moveNextEventDeep: Bool = false
    
    override open func mouseUp(with event: NSEvent) {
        longHandleDisposable.set(nil)
        longOverHandleDisposable.set(nil)
        
        if moveNextEventDeep {
            super.mouseUp(with: event)
            moveNextEventDeep = false
            return
        }
        
        if userInteractionEnabled && !event.modifierFlags.contains(.control) {
            if isEnabled && !controlIsHidden {
                send(event: .Up)
                
                if longInvoked {
                    send(event: .LongMouseUp)
                }
                if mouseInside() && !longInvoked {
                    if event.clickCount == 1  {
                        send(event: .SingleClick)
                    }
                    if event.clickCount == 2 {
                        send(event: .DoubleClick)
                    }
                    send(event: .Click)
                }
            } else {
                if mouseInside() && !longInvoked {
                    //NSSound.beep()
                }
            }
            updateState()
            
        } else {
            if userInteractionEnabled && event.modifierFlags.contains(.control) {
                send(event: .RightUp)
                return
            }
            super.mouseUp(with: event)
        }
    }
    
    func performSuperMouseUp(_ event: NSEvent) {
         super.mouseUp(with: event)
    }
    func performSuperMouseDown(_ event: NSEvent) {
        super.mouseDown(with: event)
    }
    public var contextMenu:(()->ContextMenu?)? = nil
   
    open func showContextMenu() {
        if let menu = self.contextMenu?(), let event = NSApp.currentEvent {
            AppMenu.show(menu: menu, event: event, for: self)
        }
    }
    
    public func send(event:ControlEvent) -> Void {
        for value in handlers {
            if value.event == event {
                value.handler(self)
            }
        }
       
    }
    
    override open func mouseMoved(with event: NSEvent) {
        updateState()
        if userInteractionEnabled {
            
        } else {
            super.mouseMoved(with: event)
        }
    }
    
    public var handleScrollEventOnInteractionEnabled: Bool = false
    
    open override func scrollWheel(with event: NSEvent) {
        if userInteractionEnabled, handleScrollEventOnInteractionEnabled {
            
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    open var sendRightMouseAnyway: Bool {
        return true
    }
    
    open override func rightMouseDown(with event: NSEvent) {
        if let menu = self.contextMenu?(), event.clickCount == 1, userInteractionEnabled {
            AppMenu.show(menu: menu, event: event, for: self)
            return
        }
        if userInteractionEnabled {
            updateState()
            send(event: .RightDown)
            if sendRightMouseAnyway {
                super.rightMouseDown(with: event)
            }
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
    open override func rightMouseUp(with event: NSEvent) {
        if userInteractionEnabled {
            updateState()
            send(event: .RightUp)
        } else {
            super.rightMouseUp(with: event)
        }
    }
    
    
    public func updateState() -> Void {
        if mouseInside(), !inLiveResize {
            if mouseIsDown && canHighlight {
                self.controlState = .Highlight
            } else if mouseMovedInside {
                self.controlState = .Hover
            } else {
                self.controlState = .Normal
            }
        } else {
            self.controlState = .Normal
        }
        
    }
    
    public var continuesAction: Bool = false
    
    override open func mouseEntered(with event: NSEvent) {
        updateState()
        if userInteractionEnabled {
            
            let disposable = (Signal<Void,Void>.single(Void()) |> delay(0.3, queue: Queue.mainQueue())).start(next: { [weak self] in
                if let strongSelf = self, strongSelf.mouseInside(), strongSelf.controlState == .Hover {
                    strongSelf.send(event: .LongOver)
                }
            })
            longOverHandleDisposable.set(disposable)
            
        } else {
            super.mouseEntered(with: event)
        }
    }
    
    
    override open func mouseExited(with event: NSEvent) {
        updateState()
        longOverHandleDisposable.set(nil)
        if userInteractionEnabled {
        } else {
            super.mouseExited(with: event)
        }
    }
    
    
    open override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.generic
    }
    
    
    
    override open func mouseDragged(with event: NSEvent) {
        if userInteractionEnabled {
            send(event: .MouseDragging)
            updateState()
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    func apply(style:ControlStyle) -> Void {
        set(background: style.backgroundColor, for: .Normal)
        self.backgroundColor = style.backgroundColor
        if self.animates {
            self.layer?.animateBackground()
        }
        self.setNeedsDisplayLayer()
    }
    
    
    
    required public init(frame frameRect: NSRect) {
        self.isSelected = false
        super.init(frame: frameRect)
        animates = false
//        layer?.disableActions()
      
        
        //self.wantsLayer = true
        //self.layer?.isOpaque = true
    }
    
    public override init() {
        self.isSelected = false
        super.init(frame: NSZeroRect)
        animates = false
        layer?.disableActions()

       
        
        //self.wantsLayer = true
        //self.layer?.isOpaque = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func becomeFirstResponder() -> Bool {
        if let window = kitWindow {
            return window.makeFirstResponder(self)
        }
        return false
    }
    
    public weak var redirectView: NSView?
    
    open override func smartMagnify(with event: NSEvent) {
        if let redirectView = self.redirectView {
            redirectView.smartMagnify(with: event)
        } else {
            super.smartMagnify(with: event)
        }
    }
    
    open override func magnify(with event: NSEvent) {
        if let redirectView = self.redirectView {
            redirectView.magnify(with: event)
        } else {
            super.magnify(with: event)
        }
    }
 
    public var forceMouseDownCanMoveWindow: Bool = false
    open override var mouseDownCanMoveWindow: Bool {
        return !self.userInteractionEnabled || forceMouseDownCanMoveWindow
    }
}
