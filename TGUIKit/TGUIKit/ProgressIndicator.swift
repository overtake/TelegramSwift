//
//  ProgressIndicator.swift
//  TGUIKit
//
//  Created by keepcoder on 06/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

fileprivate let kITSpinAnimationKey: String = "spinAnimation"
fileprivate let kITProgressPropertyKey: String = "progress"


extension NSBezierPath {
    func it_rotatedBezierPath(_ angle: Float) -> NSBezierPath {
        return it_rotatedBezierPath(angle, aboutPoint: NSMakePoint(NSMidX(bounds), NSMidY(bounds)))
    }
    
    func it_rotatedBezierPath(_ angle: Float, aboutPoint point: NSPoint) -> NSBezierPath {
        if angle == 0.0 {
            return self
        } else {
            let copy: NSBezierPath = self
            let xfm: NSAffineTransform = it_rotationTransform(withAngle: angle, aboutPoint: point)
            copy.transform(using: xfm as AffineTransform)
            return copy
        }
    }
    
    func it_rotationTransform(withAngle angle: Float, aboutPoint: NSPoint) -> NSAffineTransform {
        let xfm = NSAffineTransform()
        xfm.translateX(by: aboutPoint.x, yBy: aboutPoint.y)
        xfm.rotate(byRadians: CGFloat(angle))
        xfm.translateX(by: -aboutPoint.x, yBy: -aboutPoint.y)
        return xfm
    }
}

public class ProgressIndicator: View {
    public var isIndeterminate: Bool = false {
        didSet {
            if (!isIndeterminate) {
                self.animates = false;
            }
        }
    }
    public var progress:CGFloat = 0 {
        didSet {
            if (isIndeterminate) {
                reloadIndicatorContent()
            }
        }
    }
    public override var animates: Bool {
        didSet {
            reloadIndicatorContent()
            reloadAnimation()
            reloadVisibility()
        }
    }
    public var hideWhenStopped:Bool {
        didSet {
            reloadVisibility()
        }
    }
    public var lengthOfLine:CGFloat {
        didSet {
            reloadIndicatorContent()
        }
    }
    public var widthOfLine:CGFloat {
        didSet {
            reloadIndicatorContent()
        }
    }
    public var numberOfLines:Int32 {
        didSet {
            reloadAnimation()
            reloadIndicatorContent()
        }
    }
    public var innerMargin:CGFloat {
        didSet {
            reloadIndicatorContent()
        }
    }
    public var animationDuration:CGFloat {
        didSet {
            reloadAnimation()
        }
    }
    public var steppedAnimation:Bool {
        didSet {
            reloadAnimation()
        }
    }
    public var color:NSColor {
        didSet {
            reloadIndicatorContent()
        }
    }
    
    private let progressIndicatorLayer: CALayer = CALayer()
   
    public required init(frame frameRect: NSRect) {
        self.color = presentation.colors.indicatorColor
        self.innerMargin = 4;
        self.widthOfLine = 3;
        self.lengthOfLine = 6;
        self.numberOfLines = 8;
        self.animationDuration = 0.6;
        self.isIndeterminate = true;
        self.steppedAnimation = true;
        self.hideWhenStopped = true;
        
      
        super.init(frame: frameRect)
        self.animates = true;
        self.wantsLayer = true
        self.backgroundColor = .clear
        self.progressIndicatorLayer.frame = bounds
        self.layer!.addSublayer(progressIndicatorLayer)
        self.flip = false
        reloadIndicatorContent()
        reloadAnimation()
    }
    
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let _ = window {
            animates = true
        } else {
            animates = false
        }
    }
    convenience override init() {
        self.init(frame: NSMakeRect(0, 0, 20, 20))
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.progressIndicatorLayer.frame = bounds
    }
    
    func reloadIndicatorContent() {
        progressIndicatorLayer.contents = progressImage
    }
    
    func reloadAnimation() {
        progressIndicatorLayer.removeAnimation(forKey: kITSpinAnimationKey)
        if animates {
            progressIndicatorLayer.add(keyFrameAnimationForCurrentPreferences(), forKey: kITSpinAnimationKey)
        }
    }

    
    var progressImage: NSImage {
        let progressImage = NSImage(size: bounds.size)
        progressImage.lockFocus()
        do {
            NSGraphicsContext.saveGraphicsState()
            do {
                color.set()
                let r: NSRect = bounds
                let numberOfLines:Float = Float(self.numberOfLines)
                let line = NSBezierPath(roundedRect: NSMakeRect((r.width / 2) - (widthOfLine / 2), (r.height / 2) - innerMargin - lengthOfLine, widthOfLine, lengthOfLine), xRadius: widthOfLine / 2, yRadius: widthOfLine / 2)
                
                let lineDrawingBlock: (_ line: Int32) -> Void = { (_ lineNumber: Int32) -> Void in
                    var lineInstance: NSBezierPath = line.copy() as! NSBezierPath
                    lineInstance = lineInstance.it_rotatedBezierPath(((2 * Float.pi) / numberOfLines * Float(lineNumber)) + Float.pi, aboutPoint: NSMakePoint(r.width / 2, r.height / 2))
                    
                    if self.isIndeterminate {
                        self.color.withAlphaComponent(CGFloat(1.0 - (1.0 / Float(self.numberOfLines) * Float(lineNumber)))).set()
                    }
                    lineInstance.fill()
                }
                
                if !isIndeterminate {
                    var i = self.numberOfLines

                    while i > Int32(round(numberOfLines - (numberOfLines * Float(progress)))) {
                        lineDrawingBlock(i)
                        i -= 1
                    }
                }
                else {
                    for i in 0 ..< self.numberOfLines {
                        lineDrawingBlock(i)
                    }
                }
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        progressImage.unlockFocus()
        return progressImage
    }
    
    func keyFrameAnimationForCurrentPreferences() -> CAKeyframeAnimation {
        var keyFrameValues:[NSNumber] = []
        var keyTimeValues:[NSNumber] = []
        if steppedAnimation {
            do {
                keyFrameValues.append(NSNumber(value: 0.0))
                for i in 0 ..< numberOfLines {
                    let i:Float = Float(i)
                    keyFrameValues.append(NSNumber(value: -Float.pi * (2.0 / Float(numberOfLines) * i)))
                    keyFrameValues.append(NSNumber(value: -Float.pi * (2.0 / Float(numberOfLines) * i)))
                }
                keyFrameValues.append(NSNumber(value: -Float.pi * 2.0))
            }
            do {
                keyTimeValues.append(NSNumber(value: 0.0))
                for i in 0 ..< (numberOfLines - 1) {
                    let i:Float = Float(i)
                    keyTimeValues.append(NSNumber(value: 1.0 / Float(numberOfLines) * i))
                    keyTimeValues.append(NSNumber(value: 1.0 / Float(numberOfLines) * (i + 1)))
                }
                keyTimeValues.append(NSNumber(value: 1.0 / Float(numberOfLines) * (Float(numberOfLines) - 1)))
            }
        }
        else {
            do {
                keyFrameValues.append(NSNumber(value: -Float.pi * 0.0))
                keyFrameValues.append(NSNumber(value: -Float.pi * 0.5))
                keyFrameValues.append(NSNumber(value: -Float.pi * 1.0))
                keyFrameValues.append(NSNumber(value: -Float.pi * 1.5))
                keyFrameValues.append(NSNumber(value: -Float.pi * 2.0))
            }
        }
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.repeatCount = .greatestFiniteMagnitude
        animation.values = keyFrameValues
        animation.keyTimes = keyTimeValues
        animation.valueFunction = CAValueFunction(name: kCAValueFunctionRotateZ)
        animation.duration = CFTimeInterval(animationDuration)
        animation.beginTime = 1
        return animation
    }

    func reloadVisibility() {
//        if hideWhenStopped && !animates && isIndeterminate {
//            isHidden = true
//        }
//        else {
//            isHidden = false
//        }
    }

    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


//public class ProgressIndicator1 : View {
//    public required init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//    }
//
//    public override func viewDidMoveToSuperview() {
//        updateWantsAnimation()
//    }
//
//    public override func viewDidHide() {
//        updateWantsAnimation()
//    }
//
//    public override func viewDidUnhide() {
//        updateWantsAnimation()
//    }
//
//    private func updateWantsAnimation() {
//
//    }
//
//    override public func draw(_ layer: CALayer, in ctx: CGContext) {
//        super.draw(layer, in: ctx)
//
//        ctx.setStrokeColor(parameters.theme.foregroundColor.cgColor)
//
//        let startAngle = 2.0 * (CGFloat.pi) * CGFloat(_progress) - CGFloat.pi / 2
//        let endAngle = -(CGFloat.pi / 2)
//
//        let pathDiameter = !twist ? parameters.diameter - parameters.theme.lineWidth : parameters.diameter - parameters.theme.lineWidth - parameters.theme.lineWidth * parameters.theme.lineWidth
//        ctx.addArc(center: NSMakePoint(parameters.diameter / 2.0, floorToScreenPixels(parameters.diameter / 2.0)), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
//
//        ctx.setLineWidth(parameters.theme.lineWidth);
//        ctx.setLineCap(.round);
//        ctx.strokePath()
//
//    }
//
//    required public init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//}

