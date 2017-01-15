//
//  BarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class BarView: View {
    
    var overlay:OverlayControl = OverlayControl()
    
    public var clickHandler:()->Void = {}
    
    public var minWidth:CGFloat = 80

    override open func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.overlay.setFrameSize(newSize)
        self.setNeedsDisplay()
    }
    
    override init() {
        super.init()
        frame = NSMakeRect(0, 0, minWidth, 50)
        addSubview(overlay)
        overlayInitEvent()
    }
    
    func overlayInitEvent() -> Void {
        self.overlay.set(handler: { [weak self] control in
            self?.clickHandler()
        }, for: .Click)
    }
    
    override required public init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        self.addSubview(overlay)
        overlayInitEvent()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
