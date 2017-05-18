//
//  BarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class BarView: OverlayControl {
    
    
    public var clickHandler:()->Void = {}
    
    public var minWidth:CGFloat = 80

    override open func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.setNeedsDisplay()
    }
    
    public init(_ width:CGFloat) {
        self.minWidth = width
        super.init()
        frame = NSMakeRect(0, 0, minWidth, 50)
        overlayInitEvent()
    }
    
    override init() {
        super.init()
        frame = NSMakeRect(0, 0, minWidth, 50)
        overlayInitEvent()
    }
    
    func overlayInitEvent() -> Void {
        set(handler: { [weak self] control in
            self?.clickHandler()
        }, for: .Click)
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        overlayInitEvent()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
