//
//  Button.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa



open class Button: Control {
    
    public var autohighlight:Bool = true
    public var highlightHovered:Bool = false
    private(set) var _thatFit: Bool = false

    private var stateBackground:[ControlState:NSColor] = [:]
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        prepare()
        
    }
    
//    public func set(backgroundColor:NSColor, for state:ControlState) -> Void {
//        stateBackground[state] = backgroundColor
//        apply(state: self.controlState)
//    }
    
    public override init() {
        super.init()
        prepare()
    }
    
    func prepare() -> Void {
        layer?.removeAllAnimations()
    }
    
    override public func apply(state:ControlState) -> Void {
        let state:ControlState = self.isSelected ? .Highlight : state
        super.apply(state: state)
        
//        if let backgroundColor = stateBackground[state] {
//            self.layer?.backgroundColor = backgroundColor.cgColor
//            if animates {
//                self.layer?.animateBackground()
//            }
//        } else {
//            self.layer?.backgroundColor = self.backgroundColor.cgColor
//        }
    }
    
    override func apply(style:ControlStyle) -> Void {
        super.apply(style:style)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) -> Bool {
        self._thatFit = thatFit
        return true
    }
    
    open override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateLayout()
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateLayout()
    }
    
    public func updateLayout() -> Void {
        
    }
    
}
