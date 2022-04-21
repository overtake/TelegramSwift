//
//  Button.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import AppKit


open class Button: Control {
    
    
    public var autohighlight:Bool = true
    public var highlightHovered:Bool = false
    public var _thatFit: Bool = false
    
    private var visualEffect: VisualEffect?
    public var blurBackground: NSColor? = nil {
        didSet {
            updateBackgroundBlur()
        }
    }
    
    private func updateBackgroundBlur() {
        if let blurBackground = blurBackground {
            if self.visualEffect == nil {
                self.visualEffect = VisualEffect(frame: self.bounds)
                self.addSubview(self.visualEffect!, positioned: .below, relativeTo: self.subviews.first)
            }
            self.visualEffect?.bgColor = blurBackground
            
        } else {
            self.visualEffect?.removeFromSuperview()
            self.visualEffect = nil
        }
        needsLayout = true
    }
    
    open override func layout() {
        super.layout()
        visualEffect?.frame = bounds
    }


    private var stateBackground:[ControlState:NSColor] = [:]
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        prepare()
        
    }
    
    open override func cursorUpdate(with event: NSEvent) {
        //super.cursorUpdate(with: event)
        NSCursor.arrow.set()
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
    
    @discardableResult public func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) -> Bool {
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
