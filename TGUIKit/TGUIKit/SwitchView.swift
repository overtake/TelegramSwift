//
//  SwitchView.swift
//  TGUIKit
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
public class SwitchView: Control {
    
    public var isOn:Bool = false {
        didSet {
            if isOn != oldValue {
                afterChanged()
                if let stateChanged = stateChanged {
                    stateChanged()
                }
            }
        }
    }
    
    public var stateChanged:(()->Void)?

    private var buble:CALayer = CALayer()
    private var backBuble:CALayer = CALayer()
    private var background:CALayer = CALayer()
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.disableActions()
      //  layer?.isOpaque = true
        
        resize();
        
        background.backgroundColor = NSColor.white.cgColor
        buble.backgroundColor = NSColor.white.cgColor
        
        
        layer?.addSublayer(background)
        layer?.addSublayer(backBuble)
        layer?.addSublayer(buble)
        
        self.set(handler: { [weak self] in
            if let strongSelf = self {
                strongSelf.isOn = !strongSelf.isOn
            }
        }, for: .Click)
    }
    
    func afterChanged() -> Void {
        if animates {
            // self.isEnabled = false
            
            buble.animateFrame(from: buble.frame, to: bubleRect, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
            background.backgroundColor = isOn ? NSColor.greenUI.cgColor : NSColor.white.cgColor
            background.borderWidth = isOn ? 0.0 : 1.0
            buble.borderWidth = isOn ? 0.0 : 1.0
            //  buble.backgroundColor = !isOn ? .border.cgColor : .white.cgColor
            
            //            buble.shadowColor = .blueUI.cgColor
            //            buble.shadowOpacity = 1.0
            //            buble.shadowRadius = 2.0
            //            buble.shadowOffset = NSMakeSize(0, 3.0)
            
            background.animateBackground()
            background.animateBorder()
            
            buble.animateBackground()
            buble.animateBorder()
            
        }
        
        self.buble.frame = bubleRect
    }
    

    
    var bubleRect:NSRect {
        let w = frame.height - (isOn ? 2.0 : 0.0)
        return NSMakeRect(isOn ? frame.width - w - (isOn ? 1 : 0): 0, isOn ? 1.0 : 0.0, w, w)
    }
    
    
    
    func resize() -> Void {
        // standart 36:20
        
        background.frame = NSMakeRect(0, 0, frame.width, frame.height)
        background.cornerRadius = frame.height / 2.0
        background.borderWidth = 1.0
        background.borderColor = NSColor.border.cgColor
        
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
