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
}

public enum ControlEvent {
    case Down
    case Click
    case RightClick
}

open class Control: View {
    
    open var isEnabled:Bool = true
    open var hideAnimated:Bool = false
    
    public var isSelected:Bool {
        didSet {
            if isSelected != oldValue {
                self.updateState()
            }
        }
    }
    
    open var animationStyle:AnimationStyle = AnimationStyle(duration:0.3, function:kCAMediaTimingFunctionSpring)
    
    var trackingArea:NSTrackingArea?

    public var userInteractionEnabled:Bool = true
    
    private var handlers:[(ControlEvent,() -> Void)] = []
    private var stateHandlers:[(ControlState,() -> Void)] = []

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
                apply(state:controlState)
                
                for (state,handler) in stateHandlers {
                    if state == controlState {
                        handler()
                    }
                }
                
            }
        }
    }
    
    func apply(state:ControlState) -> Void {
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
        self.trackingArea = NSTrackingArea.init(rect: self.bounds, options: options, owner: self, userInfo: nil)
        
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
   
    

    
    public func set(handler:@escaping () -> Void, for event:ControlEvent) -> Void {
        handlers.append((event,handler))
    }
    
    public func set(handler:@escaping () -> Void, for event:ControlState) -> Void {
        stateHandlers.append((event,handler))
    }
    
    public func set(background:NSColor, for state:ControlState) -> Void {
        backgroundState[state] = background
    }
    
    public func removeLastHandler() -> Void {
        handlers.removeLast()
    }
    
    public func removeLastStateHandler() -> Void {
        stateHandlers.removeLast()
    }
    
    public func removeAllHandlers() ->Void {
        handlers.removeAll()
    }
    
    override open func mouseDown(with event: NSEvent) {
        
        mouseIsDown = true
        
        if userInteractionEnabled {
            send(event: .Down)
            updateState()
            
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override open func mouseUp(with event: NSEvent) {
        
        mouseIsDown = false
        
        if userInteractionEnabled {
            if mouseInside()  {
                send(event: .Click)
            }
            
            updateState()
            
        } else {
            super.mouseUp(with: event)
        }
    }
    
    func send(event:ControlEvent) -> Void {
        for (e,handler) in handlers {
            if e == event {
                handler()
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
    
    func updateState() -> Void {
        
        if isSelected {
            self.controlState = .Highlight
            return
        }
        
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
            
             updateState()
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    func apply(style:ControlStyle) -> Void {
        self.setNeedsDisplayLayer()

    }
    
    required public init(frame frameRect: NSRect) {
        self.isSelected = false
        super.init(frame: frameRect)
        animates = true
        //self.wantsLayer = true
        //self.layer?.isOpaque = true
    }
    
    public override init() {
        self.isSelected = false
        super.init(frame: NSZeroRect)
        animates = true
        //self.wantsLayer = true
        //self.layer?.isOpaque = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
