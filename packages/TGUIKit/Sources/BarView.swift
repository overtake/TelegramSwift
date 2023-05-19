//
//  BarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class BarView: Control {
    
    
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
        super.init(frame: NSMakeRect(0, 0, minWidth, 50))
        animates = false
        overlayInitEvent()
    }
    
    open override var isHidden: Bool {
        didSet {
            if !isHidden {
             //   layer?.opacity = 1
            }
        }
    }
    
    override open func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        set(background: .clear, for: .Normal)
        backgroundColor = .clear
    }
    

    func overlayInitEvent() -> Void {
        set(handler: { [weak self] control in
            self?.clickHandler()
        }, for: .Click)
        updateLocalizationAndTheme(theme: presentation)
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        overlayInitEvent()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
