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
    
    public var minWidth:CGFloat = 20
    public private(set) weak var controller: ViewController?
    
    
    override open func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    
    var isFitted: Bool {
        return true
    }
    
    func fit(to maxWidth: CGFloat) -> CGFloat {
        return frame.width
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.setNeedsDisplay()
    }
    
    public init(_ width:CGFloat = 20, controller: ViewController) {
        self.minWidth = width
        self.controller = controller
        super.init()
        animates = false
        frame = NSMakeRect(0, 0, minWidth, 50)
        overlayInitEvent()
    }
    
    override open func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        set(background: presentation.colors.background, for: .Normal)
        backgroundColor = presentation.colors.background
    }
    

    func overlayInitEvent() -> Void {
        set(handler: { [weak self] control in
            self?.clickHandler()
        }, for: .Click)
        updateLocalizationAndTheme()
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        overlayInitEvent()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
