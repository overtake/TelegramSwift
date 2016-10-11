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
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        prepare()
        
    }
    
    public override init() {
        super.init()
        prepare()
    }
    
    func prepare() -> Void {
        
        
        
    }
    
    override func apply(state:ControlState) -> Void {
        self.setNeedsDisplayLayer()
    }
    
    override func apply(style:ControlStyle) -> Void {
        super.apply(style:style)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) {
        
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
