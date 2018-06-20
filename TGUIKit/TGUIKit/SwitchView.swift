//
//  SwitchView.swift
//  TGUIKit
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

public struct SwitchViewAppearance {
    let backgroundColor: NSColor
    let disabledColor: NSColor
    let stateOnColor: NSColor
    let stateOffColor: NSColor
    let borderColor: NSColor
    public init(backgroundColor: NSColor, stateOnColor: NSColor, stateOffColor: NSColor, disabledColor: NSColor, borderColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.stateOnColor = stateOnColor
        self.stateOffColor = stateOffColor
        self.disabledColor = disabledColor
        self.borderColor = borderColor
        
    }
}


public class SwitchView: Control {
    private let disposable = MetaDisposable()
    public var autoswitch: Bool = true
    public var presentation: SwitchViewAppearance = switchViewAppearance {
        didSet {
            let animates = self.animates
            self.animates = false
            afterChanged()
            resize()
            self.animates = animates
        }
    }
    
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
        self.init(frame:NSMakeRect(0, 0, 30, 20))
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
            if let strongSelf = self {
                strongSelf.disposable.set((Signal<Void, Void>.single(Void()) |> delay(0.1, queue: Queue.mainQueue())).start(next: { [weak strongSelf] in
                    if let strongSelf = strongSelf, let stateChanged = strongSelf.stateChanged, strongSelf.isEnabled  {
                        stateChanged()
                    }
                }))
                
                let control = control as! SwitchView
                let animates = control.animates
                control.animates = true
                if strongSelf.autoswitch {
                    control.isOn = !control.isOn
                }
                control.animates = animates
            }
            
        }, for: .Click)
        
        let animates = self.animates
        self.animates = false
        afterChanged()
        self.animates = animates
    }
    
    public override func apply(state: ControlState) {
        super.apply(state: state)
        afterChanged()
    }
    
    func afterChanged() -> Void {
        
        CATransaction.begin()
        if animates {
            buble.animateFrame(from: buble.frame, to: bubleRect, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
        }
        backgroundLayer.backgroundColor = isEnabled ? ( isOn ? presentation.stateOnColor.cgColor : presentation.stateOffColor.cgColor ) : presentation.disabledColor.cgColor
        backgroundLayer.borderWidth = isOn ? 0.0 : 1.0
        buble.borderWidth = isOn ? 0.0 : 1.0
        buble.backgroundColor = presentation.backgroundColor.cgColor
        
        if animates {
            backgroundLayer.animateBackground()
            backgroundLayer.animateBorder()
            
            buble.animateBackground()
            buble.animateBorder()
        }
        backgroundLayer.setNeedsDisplay()
        buble.setNeedsDisplay()
        self.buble.frame = bubleRect
        CATransaction.commit()
        needsDisplay = true
    }
    

    
    var bubleRect:NSRect {
        let w = frame.height - (isOn ? 2.0 : 0.0)
        return NSMakeRect(isOn ? frame.width - w - (isOn ? 1 : 0): 0, isOn ? 1.0 : 0.0, w, w)
    }
    
    
    
    func resize() -> Void {
        // standart 36:20
        
        backgroundLayer.frame = NSMakeRect(0, 0, frame.width, frame.height)
        backgroundLayer.cornerRadius = frame.height / 2.0
        backgroundLayer.borderWidth = isOn ? 0.0 : 1.0
        backgroundLayer.borderColor = presentation.borderColor.cgColor
        
        buble.frame = bubleRect
        buble.cornerRadius = bubleRect.height/2.0
        buble.borderWidth = isOn ? 0.0 : 1.0
        buble.borderColor = presentation.borderColor.cgColor

    }
    
    
    deinit {
        disposable.dispose()
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
