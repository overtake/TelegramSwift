//
//  Control.swift
//  TGUIKit
//
//  Created by keepcoder on 25/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

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
    case SingleClick
    case RightClick
    case MouseDragging
    case LongMouseDown
    case LongMouseUp
}

open class Control: View {
    
    open var isEnabled:Bool = true {
        didSet {
            if isEnabled != oldValue {
                apply(state: controlState)
            }
        }
    }
    open var hideAnimated:Bool = false
    
    private let longHandleDisposable = MetaDisposable()
    
    public var isSelected:Bool {
        didSet {
            if isSelected != oldValue {
                apply(state: isSelected ? .Highlight : self.controlState)
            }
        }
    }
    
    open var animationStyle:AnimationStyle = AnimationStyle(duration:0.3, function:kCAMediaTimingFunctionSpring)
    
    var trackingArea:NSTrackingArea?

    public var interactionStateForRestore:Bool? = nil
    
    public var userInteractionEnabled:Bool = true
    
    private var handlers:[(ControlEvent,(Control) -> Void)] = []
    private var stateHandlers:[(ControlState,(Control) -> Void)] = []

    private var backgroundState:[ControlState:NSColor] = [:]

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
    
    public private(set) var controlState:ControlState = .Normal {
        didSet {
            if oldValue != controlState {
                apply(state: isSelected ? .Highlight : controlState)
                
                for (state,handler) in stateHandlers {
                    if state == controlState {
                        handler(self)
                    }
                }
                
            }
        }
    }
    
    public func apply(state:ControlState) -> Void {
        let state:ControlState = self.isSelected ? .Highlight : state
        if let color = backgroundState[state] {
            self.layer?.backgroundColor = color.cgColor
        } else {
            self.layer?.backgroundColor = self.backgroundColor.cgColor
        }
        if animates {
            self.layer?.animateBackground()
        }
    }
    
    private var mouseIsDown:Bool = false
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        let options:NSTrackingAreaOptions = [NSTrackingAreaOptions.cursorUpdate, NSTrackingAreaOptions.mouseEnteredAndExited, NSTrackingAreaOptions.mouseMoved, NSTrackingAreaOptions.activeInKeyWindow,NSTrackingAreaOptions.inVisibleRect]
        self.trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        
        self.addTrackingArea(self.trackingArea!)
    }
    

    
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
                    self.layer?.animateAlpha(from: newValue ? 1.0 : 0.0, to: newValue ? 0.0 : 1.0, duration: 0.2, completion:{[weak self](completed) in
                        self?.updateHiddenState(newValue)
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
   
    

    
    public func set(handler:@escaping (Control) -> Void, for event:ControlEvent) -> Void {
        handlers.append((event,handler))
    }
    
    public func set(handler:@escaping (Control) -> Void, for event:ControlState) -> Void {
        stateHandlers.append((event,handler))
    }
    
    public func set(background:NSColor, for state:ControlState) -> Void {
        backgroundState[state] = background
    }
    
    public func removeLastHandler() -> Void {
        if !handlers.isEmpty {
            handlers.removeLast()
        }
    }
    
    public func removeLastStateHandler() -> Void {
        if !stateHandlers.isEmpty {
            stateHandlers.removeLast()
        }
    }
    
    public func removeAllHandlers() ->Void {
        handlers.removeAll()
    }
    
    override open func mouseDown(with event: NSEvent) {
        mouseIsDown = true
        
        if userInteractionEnabled {
            send(event: .Down)
            updateState()
            
            let disposable = (Signal<Void,Void>.single() |> delay(0.3, queue: Queue.mainQueue())).start(next: { [weak self] in
                self?.send(event: .LongMouseDown)
            })
            
            longHandleDisposable.set(disposable)
            
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override open func mouseUp(with event: NSEvent) {
        
        longHandleDisposable.set(nil)
        
        mouseIsDown = false
        
        if userInteractionEnabled {
            if isEnabled {
                send(event: .Up)
                
                if mouseInside() {
                    if event.clickCount == 1  {
                        send(event: .SingleClick)
                    }
                    send(event: .Click)
                }
            }
            
            updateState()
            
        } else {
            super.mouseUp(with: event)
        }
    }
    
    func send(event:ControlEvent) -> Void {
        for (e,handler) in handlers {
            if e == event {
                handler(self)
            }
        }
    }
    
    override open func mouseMoved(with event: NSEvent) {
        if userInteractionEnabled {
           updateState()
        } else {
            super.mouseMoved(with: event)
        }
    }
    
    public func updateState() -> Void {
        if mouseInside() {
            if mouseIsDown {
                self.controlState = .Highlight
            } else {
                self.controlState = .Hover
            }
        } else {
            self.controlState = .Normal
        }
    }
    
    override open func mouseEntered(with event: NSEvent) {
        if userInteractionEnabled {
            
            updateState()
        } else {
            super.mouseEntered(with: event)
        }
    }
    
    override open func mouseExited(with event: NSEvent) {
        if userInteractionEnabled {
            
             updateState()
        } else {
            super.mouseExited(with: event)
        }
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
        self.setNeedsDisplayLayer()

    }
    
    deinit {
        longHandleDisposable.dispose()
    }
    
    required public init(frame frameRect: NSRect) {
        self.isSelected = false
        super.init(frame: frameRect)
        animates = true
        guard #available(OSX 10.12, *) else {
            layer?.opacity = 0.99
            return
        }
        //self.wantsLayer = true
        //self.layer?.isOpaque = true
    }
    
    public override init() {
        self.isSelected = false
        super.init(frame: NSZeroRect)
        animates = true
        
        guard #available(OSX 10.12, *) else {
            layer?.opacity = 0.99
            return
        }
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
    
}
