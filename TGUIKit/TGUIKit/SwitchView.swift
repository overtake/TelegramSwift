//
//  SwitchView.swift
//  TGUIKit
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
public class SwitchView: Control {
    
    public func setIsOn(_ isOn:Bool, animated:Bool = true) {
        self.animates = animated
        self.isOn = isOn
    }
    
    private var isOn:Bool = false {
        didSet {
            if isOn != oldValue {
                afterChanged()
            }
        }
    }
    
    public var stateChanged:(()->Void)?

    private var buble:CALayer = CALayer()
    private var backBuble:CALayer = CALayer()
    private var backgroundLayer:CALayer = CALayer()
    
    override convenience init() {
        self.init(frame:NSMakeRect(0, 0, 38, 20))
    }
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.disableActions()
      //  layer?.isOpaque = true
        
        resize();
        
        backgroundLayer.backgroundColor = NSColor.white.cgColor
        buble.backgroundColor = NSColor.white.cgColor
        
        backgroundLayer.disableActions()
        buble.disableActions()
        backBuble.disableActions()
        
        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(backBuble)
        layer?.addSublayer(buble)
        
        self.set(handler: { [weak self] control in
            let control = control as! SwitchView
            let animates = control.animates
            control.animates = true
            control.isOn = !control.isOn
            control.animates = animates
            if let stateChanged = self?.stateChanged {
                stateChanged()
            }
        }, for: .Click)
        
        let animates = self.animates
        self.animates = false
        afterChanged()
        self.animates = animates
    }
    
    func afterChanged() -> Void {
        if animates {
            buble.animateFrame(from: buble.frame, to: bubleRect, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
        }
        backgroundLayer.backgroundColor = isOn ? NSColor.blueUI.cgColor : NSColor.white.cgColor
        backgroundLayer.borderWidth = isOn ? 0.0 : 1.0
        buble.borderWidth = isOn ? 0.0 : 1.0
        //  buble.backgroundColor = !isOn ? .border.cgColor : .white.cgColor
        
        //            buble.shadowColor = .blueUI.cgColor
        //            buble.shadowOpacity = 1.0
        //            buble.shadowRadius = 2.0
        //            buble.shadowOffset = NSMakeSize(0, 3.0)
        
        if animates {
            backgroundLayer.animateBackground()
            backgroundLayer.animateBorder()
            
            buble.animateBackground()
            buble.animateBorder()
        }
        backgroundLayer.setNeedsDisplay()
        buble.setNeedsDisplay()
        self.buble.frame = bubleRect
    }
    

    
    var bubleRect:NSRect {
        let w = frame.height - (isOn ? 2.0 : 0.0)
        return NSMakeRect(isOn ? frame.width - w - (isOn ? 1 : 0): 0, isOn ? 1.0 : 0.0, w, w)
    }
    
    
    
    func resize() -> Void {
        // standart 36:20
        
        backgroundLayer.frame = NSMakeRect(0, 0, frame.width, frame.height)
        backgroundLayer.cornerRadius = frame.height / 2.0
        backgroundLayer.borderWidth = 1.0
        backgroundLayer.borderColor = NSColor.border.cgColor
        
        buble.frame = bubleRect
        buble.cornerRadius = bubleRect.height/2.0
        buble.borderWidth = 1.0
        buble.borderColor = NSColor.border.cgColor

    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
//        super.draw(layer, in: ctx)
//        ctx.setFillColor(NSColor.grayBackground.cgColor)
//        ctx.round(frame.size, frame.height/2.0)
//        ctx.fill(layer.bounds)
    }
    
}
