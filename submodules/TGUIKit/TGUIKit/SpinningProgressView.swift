//
//  SpinningProgressView.swift
//  TGUIKit
//

import Cocoa
import SwiftSignalKit

private let alphaWhenStopped: CGFloat = 0.15
private let fadeMultiplier: CGFloat = 0.85
private let numberOfFins: Int = 12
private let fadeOutTime: TimeInterval = 0.7

public class SpinningProgressView: View {

    
    public var color: NSColor = presentation.colors.text
    public var currentValue: CGFloat = 0.0
    public var maxValue: CGFloat = 0.0
    
    
    private var currentPosition: Int
    private var finColors: [NSColor] = Array<NSColor>(repeating: presentation.colors.text, count: numberOfFins)
    private var isAnimating:Bool
    private var animationTimer: SwiftSignalKit.Timer? = nil
    private var isFadingOut: Bool
    private var fadeOutStartTime: Date = Date()
    
    
    public required init(frame frameRect: NSRect) {
        currentPosition = 0
        isAnimating = false
        isFadingOut = false
        color = presentation.colors.text
        currentValue = 0.0
        maxValue = 100.0
        super.init(frame: frameRect)
    }
    
    public func setColor(_ value: NSColor) {
        if color != value {
            color = value
            for i in 0 ..< numberOfFins {
                let alpha = alphaValue(forPosition: i)
                finColors[i] = color.withAlphaComponent(alpha)
            }
            needsDisplay = true
        }
    }
    
    func alphaValue(forPosition position: Int) -> CGFloat {
        var normalValue = pow(fadeMultiplier, CGFloat((position + currentPosition) % numberOfFins))
        if isFadingOut {
            let timeSinceStop = -fadeOutStartTime.timeIntervalSinceNow
            normalValue *= CGFloat(fadeOutTime - timeSinceStop)
        }
        return normalValue
    }
    
    public func stopAnimation() {
        isFadingOut = true
        fadeOutStartTime = Date()
    }
    public func startAnimation() {
        self.actuallyStartAnimation()
    }

    private func actuallyStopAnimation() {
        isAnimating = false
        isFadingOut = false
        
        self.animationTimer?.invalidate()
        self.animationTimer = nil
        
        self.needsDisplay = true
    }
    
    private func actuallyStartAnimation() {
        self.actuallyStopAnimation()
        
        isAnimating = true
        isFadingOut = false
        
        currentPosition = 0
        
        animationTimer = SwiftSignalKit.Timer(timeout: 0.04, repeat: true, completion: { [weak self] in
            self?.updateTimer()
        }, queue: .mainQueue())
        
        animationTimer?.start()
        
        self.updateTimer()
    }
    
    private func updateTimer() {
        
        let minAlpha = alphaWhenStopped
        
        for i in 0 ..< numberOfFins {
            let newAlpha = max(alphaValue(forPosition: numberOfFins - i), minAlpha)
            self.finColors[i] = color.withAlphaComponent(newAlpha)
        }
        
        if isFadingOut {
            if fadeOutStartTime.timeIntervalSinceNow < -fadeOutTime {
                self.actuallyStopAnimation()
            }
        }
        
        self.needsDisplay = true

        if !isFadingOut {
            self.currentPosition = currentPosition + 1 % numberOfFins
        }
    }
    

    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        let size = bounds.size
        let length = min(size.height, size.width)


        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        let path = CGMutablePath()
        let lineWidth = 0.0859375 * length
        let lineStart = 0.234375 * length
        let lineEnd = 0.421875 * length
        path.move(to: NSPoint(x: 0, y: lineStart))
        path.addLine(to: NSPoint(x: 0, y: lineEnd))
        for i in 0 ..< numberOfFins {
            let c = isAnimating ? finColors[i] : color.withAlphaComponent(alphaWhenStopped)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setStrokeColor(c.cgColor)
            ctx.addPath(path)
            ctx.closePath()
            ctx.strokePath()
            ctx.rotate(by: 2 * .pi / CGFloat(numberOfFins))
        }
    }
    
}
