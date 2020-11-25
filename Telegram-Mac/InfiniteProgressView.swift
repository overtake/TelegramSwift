//
//  InfiniteProgressView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

private final class InfiniteProgressViewParameters: NSObject {
    let color: NSColor
    let progress: CGFloat
    let lineWidth: CGFloat?
    
    init(color: NSColor, progress: CGFloat, lineWidth: CGFloat?) {
        self.color = color
        self.progress = progress
        self.lineWidth = lineWidth
    }
}

private final class InfiniteLayer : CALayer {
    
    
    var parameters: InfiniteProgressViewParameters? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    override func draw(in context: CGContext) {
        if let parameters = parameters {
            context.setStrokeColor(parameters.color.cgColor)
            let factor = bounds.size.width / 50.0
            
            var progress = parameters.progress
            if progress > 1.0 {
                progress = progress - 1.0
            }
            
            let startAngle = -CGFloat.pi / 2.0
            let endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
            
            progress = min(1.0, progress)
                        
            let lineWidth: CGFloat = parameters.lineWidth ?? max(1.6, 2.25 * factor)
            
            let pathDiameter: CGFloat
            if parameters.lineWidth != nil {
                pathDiameter = bounds.size.width - lineWidth
            } else {
                pathDiameter = bounds.size.width - lineWidth - 2.5 * 2.0
            }
            
            let path = CGMutablePath()
            
            path.addArc(center: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: parameters.progress >= 1)
            
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.addPath(path)
            context.strokePath()
        }
    }
}


final class InfiniteProgressView: View {
    var progressAnimationCompleted: (() -> Void)?
    
    private var progress_Animation: DisplayLinkAnimator?
    private var indefiniteProgress_Animation: DisplayLinkAnimator?

    private let pLayer = InfiniteLayer()
    
    var color: NSColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
            pLayer.parameters = self.parameters
        }
    }
    
    var progress: CGFloat? {
        didSet {
            self.progress_Animation = nil
            if let progress = self.progress {
                indefiniteProgress_Animation = nil
                var duration = 0.2
                let delta = max(0.0, progress - self.effectiveProgress)
                if delta > 0.25 {
                    duration += Double(min(0.45, 0.45 * ((delta - 0.25) * 5)))
                }
                self.progress_Animation = DisplayLinkAnimator.init(duration: duration, from: self.effectiveProgress, to: progress, update: { [weak self] value in
                    self?.effectiveProgress = value
                }, completion: {
                    
                })
            } else if indefiniteProgress_Animation == nil {
                self.progress_Animation = DisplayLinkAnimator(duration: 2.5, from: 0, to: 2, update: { [weak self] value in
                    self?.effectiveProgress = value
                }, completion: { [weak self] in
                    self?.indefiniteProgress_Animation = nil
                    self?.progress = nil
                })
            }
        }
    }
    
    var isAnimatingProgress: Bool {
        return self.progress_Animation != nil
    }
    
    let lineWidth: CGFloat?
    
    init(color: NSColor, lineWidth: CGFloat?) {
        self.color = color
        self.lineWidth = lineWidth
        
        super.init()
        layer?.addSublayer(pLayer)
    }
    
    override func layout() {
        super.layout()
        pLayer.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    private var parameters: InfiniteProgressViewParameters {
        return InfiniteProgressViewParameters(color: self.color, progress: self.effectiveProgress, lineWidth: self.lineWidth)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if window != nil {
            let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            basicAnimation.duration = 1.5
            var fromValue = Float.pi + 0.58
            if let presentation = self.pLayer.presentation(), let value = (presentation.value(forKeyPath: "transform.rotation.z") as? NSNumber)?.floatValue {
                fromValue = value
            }
            basicAnimation.fromValue = NSNumber(value: fromValue)
            basicAnimation.toValue = NSNumber(value: fromValue + Float.pi * 2.0)
            basicAnimation.repeatCount = Float.infinity
            basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            basicAnimation.beginTime = 0.0
            
            self.pLayer.add(basicAnimation, forKey: "progressRotation")
        } else {
            self.pLayer.removeAllAnimations()
        }

    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
    
    }
}
