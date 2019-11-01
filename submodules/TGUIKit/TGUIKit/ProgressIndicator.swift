//
//  ProgressIndicator.swift
//  TGUIKit
//
//  Created by keepcoder on 06/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa


private class ProgressLayer : CALayer {
    fileprivate var progressColor: NSColor? = nil
    fileprivate func update(_ hasAnimation: Bool) {
        if hasAnimation {
            var fromValue: Float = 0
            
            if let layer = presentation(), let from = layer.value(forKeyPath: "transform.rotation.z") as? Float {
                fromValue = from
            }
            let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            basicAnimation.duration = 0.8
            basicAnimation.fromValue = fromValue
            basicAnimation.isRemovedOnCompletion = false
            basicAnimation.toValue = Double.pi * 2.0
            basicAnimation.repeatCount = Float.infinity
            basicAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            add(basicAnimation, forKey: "progressRotation")
        } else {
            removeAnimation(forKey: "progressRotation")
        }
    }
    
    fileprivate var lineWidth: CGFloat = 2 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(in ctx: CGContext) {

        ctx.setStrokeColor((progressColor ?? PresentationTheme.current.colors.indicatorColor).cgColor)
        
        let startAngle = 2.0 * (CGFloat.pi) * 0.8 - CGFloat.pi / 2
        let endAngle = -(CGFloat.pi / 2)
        
        let diameter = floorToScreenPixels(System.backingScale, frame.height)
        
        let pathDiameter = diameter - lineWidth - lineWidth * 2
        ctx.addArc(center: NSMakePoint(diameter / 2.0, floorToScreenPixels(System.backingScale, diameter / 2.0)), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        ctx.setLineWidth(lineWidth);
        ctx.setLineCap(.round);
        ctx.strokePath()
    }
}

public class ProgressIndicator : Control {
    
    public var alwaysAnimate: Bool = false
    
    public var progressColor: NSColor? = nil {
        didSet {
            indicator.color = progressColor ?? presentation.colors.text
            indicator.setNeedsDisplay()
        }
    }
    public var innerInset: CGFloat = 0 {
        didSet {
            needsLayout = true
           // indicator.lineWidth = lineWidth
        }
    }
    private let indicator: SpinningProgressView = SpinningProgressView(frame: NSZeroRect)
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        indicator.frame = bounds
        self.addSubview(indicator)
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        let prev = self.frame
        super.setFrameSize(newSize)
        if prev != self.frame {
            updateWantsAnimation()
        }
    }
    
    
    public override func layout() {
        super.layout()
        indicator.setFrameSize(NSMakeSize(frame.width - innerInset, frame.height - innerInset))
        indicator.center()
    }
    
    public override init() {
        super.init(frame: NSMakeRect(0, 0, 20, 20))
        indicator.frame = bounds
        self.addSubview(indicator)
    }

    public override func viewDidMoveToSuperview() {
        updateWantsAnimation()
    }
    
    public override func viewDidMoveToWindow() {
        updateWantsAnimation()
    }

    public override func viewDidHide() {
        updateWantsAnimation()
    }

    public override func viewDidUnhide() {
        updateWantsAnimation()
    }

    private func updateWantsAnimation() {
        if (window != nil && !isHidden) || alwaysAnimate {
            indicator.startAnimation()
        } else {
            indicator.stopAnimation()
        }
    }
    

    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)

    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

