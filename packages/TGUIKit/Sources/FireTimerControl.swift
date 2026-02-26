//
//  FireTimerControl.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa


private enum ContentState: Equatable {
    case clock(NSColor)
    case timeout(NSColor, CGFloat)
}

private struct ContentParticle {
    var position: CGPoint
    var direction: CGPoint
    var velocity: CGFloat
    var alpha: CGFloat
    var lifetime: Double
    var beginTime: Double
    
    init(position: CGPoint, direction: CGPoint, velocity: CGFloat, alpha: CGFloat, lifetime: Double, beginTime: Double) {
        self.position = position
        self.direction = direction
        self.velocity = velocity
        self.alpha = alpha
        self.lifetime = lifetime
        self.beginTime = beginTime
    }
}

public class FireTimerControl: Control {
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(self.contentView)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private struct Params: Equatable {
        var color: NSColor
        var timeout: Double
        var deadlineTimestamp: Double?
        var lineWidth: CGFloat
    }
    
    private var animator: ConstantDisplayLinkAnimator?
    private let contentView: ImageView = ImageView()
    private var currentContentState: ContentState?
    private var particles: [ContentParticle] = []

    
    private var pauseStartTimestamp: CFAbsoluteTime?
    private var accumulatedPauseDuration: CFAbsoluteTime = 0

    
    public var isPaused: Bool = false {
        didSet {
            self.animator?.isPaused = false // Keep animation running even if paused

            let now = CFAbsoluteTimeGetCurrent()

            if isPaused {
                pauseStartTimestamp = now
            } else if let pauseStart = pauseStartTimestamp {
                accumulatedPauseDuration += now - pauseStart
                pauseStartTimestamp = nil
            }
        }
    }

    
    
    private var currentParams: Params?
    
    public var reachedTimeout: (() -> Void)?
    public var reachedHalf: (() -> Void)?
    public var updateValue: ((CGFloat) -> Void)?

    private var reachedHalfNotified: Bool = false
    
    deinit {
        self.animator?.invalidate()
    }

    public func updateColor(_ color: NSColor) {
        if let params = self.currentParams {
            self.currentParams = Params(
                color: color,
                timeout: params.timeout,
                deadlineTimestamp: params.deadlineTimestamp,
                lineWidth: params.lineWidth
            )
        }
    }
    
    public func update(color: NSColor, timeout: Double, deadlineTimestamp: Double?, lineWidth: CGFloat = 2.0) {
        let params = Params(
            color: color,
            timeout: timeout,
            deadlineTimestamp: deadlineTimestamp,
            lineWidth: lineWidth
        )
        self.currentParams = params
        self.reachedHalfNotified = false
        self.accumulatedPauseDuration = 0
        self.pauseStartTimestamp = nil
        self.updateValues()
    }
    
    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        self.animator?.isPaused = newWindow == nil
    }
    
    private func updateValues() {
        guard let params = self.currentParams else {
            return
        }
        
        let fractionalTimeout: Double
        
        if let deadlineTimestamp = params.deadlineTimestamp {
            let fractionalTimestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            let pauseDuration = isPaused ? CFAbsoluteTimeGetCurrent() - (pauseStartTimestamp ?? CFAbsoluteTimeGetCurrent()) : 0
            let effectivePauseDuration = accumulatedPauseDuration + pauseDuration

            fractionalTimeout = min(
                Double(params.timeout),
                max(0.0, Double(deadlineTimestamp) - fractionalTimestamp + effectivePauseDuration)
            )
        } else {
            fractionalTimeout = Double(params.timeout)
        }
                
        let isTimer = true
        let color = params.color
        
        let contentState: ContentState
        if isTimer {
            var fraction: CGFloat = 1.0
            fraction = CGFloat(fractionalTimeout) / CGFloat(params.timeout)
            fraction = max(0.0, min(0.99, fraction))
            contentState = .timeout(color, 1.0 - fraction)
            self.updateValue?(fraction)
        } else {
            contentState = .clock(color)
        }
        
        if let deadlineTimestamp = params.deadlineTimestamp, deadlineTimestamp - (CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) < params.timeout / 2 {
            if let reachedHalf = self.reachedHalf, !reachedHalfNotified {
                reachedHalf()
                reachedHalfNotified = true
            }
        }
        
        if self.currentContentState != contentState {
            self.currentContentState = contentState
            let image: CGImage?
            
            let diameter: CGFloat = frame.width - 8
            let inset: CGFloat = 7
            let lineWidth: CGFloat = params.lineWidth
            
            switch contentState {
            case let .clock(color):
                image = generateImage(CGSize(width: diameter + inset, height: diameter + inset), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(lineWidth)
                    context.setLineCap(.round)
                    
                    let clockFrame = CGRect(origin: CGPoint(x: (size.width - diameter) / 2.0, y: (size.height - diameter) / 2.0), size: CGSize(width: diameter, height: diameter))
                    context.strokeEllipse(in: clockFrame.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
                    
                    context.move(to: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
                    context.addLine(to: CGPoint(x: size.width / 2.0, y: clockFrame.minY + 4.0))
                    context.strokePath()
                    
                    let topWidth: CGFloat = 4.0
                    context.move(to: CGPoint(x: size.width / 2.0 - topWidth / 2.0, y: clockFrame.minY - 2.0))
                    context.addLine(to: CGPoint(x: size.width / 2.0 + topWidth / 2.0, y: clockFrame.minY - 2.0))
                    context.strokePath()
                })
            case let .timeout(color, fraction):
                
                let timestamp = CACurrentMediaTime()
                
                let center = CGPoint(x: (diameter + inset) / 2.0, y: (diameter + inset) / 2.0)
                let radius: CGFloat = (diameter - lineWidth / 2.0) / 2.0
                
                let startAngle: CGFloat = -CGFloat.pi / 2.0
                let endAngle: CGFloat = -CGFloat.pi / 2.0 + 2.0 * CGFloat.pi * fraction
                
                let v = CGPoint(x: sin(endAngle), y: -cos(endAngle))
                let c = CGPoint(x: -v.y * radius + center.x, y: v.x * radius + center.y)
                
                let dt: CGFloat = 1.0 / 60.0
                var removeIndices: [Int] = []
                for i in 0 ..< self.particles.count {
                    let currentTime = timestamp - self.particles[i].beginTime
                    if currentTime > self.particles[i].lifetime {
                        removeIndices.append(i)
                    } else {
                        let input: CGFloat = CGFloat(currentTime / self.particles[i].lifetime)
                        let decelerated: CGFloat = (1.0 - (1.0 - input) * (1.0 - input))
                        self.particles[i].alpha = 1.0 - decelerated
                        
                        var p = self.particles[i].position
                        let d = self.particles[i].direction
                        let v = self.particles[i].velocity
                        p = CGPoint(x: p.x + d.x * v * dt, y: p.y + d.y * v * dt)
                        self.particles[i].position = p
                    }
                }
                
                for i in removeIndices.reversed() {
                    self.particles.remove(at: i)
                }
                
                let newParticleCount = 1
                for _ in 0 ..< newParticleCount {
                    let degrees: CGFloat = CGFloat(arc4random_uniform(140)) - 40.0
                    let angle: CGFloat = degrees * CGFloat.pi / 180.0
                    
                    let direction = CGPoint(x: v.x * cos(angle) - v.y * sin(angle), y: v.x * sin(angle) + v.y * cos(angle))
                    let velocity = (20.0 + (CGFloat(arc4random()) / CGFloat(UINT32_MAX)) * 4.0) * 0.3
                    
                    let lifetime = Double(0.4 + CGFloat(arc4random_uniform(100)) * 0.01)
                    
                    let particle = ContentParticle(position: c, direction: direction, velocity: velocity, alpha: 1.0, lifetime: lifetime, beginTime: timestamp)
                    self.particles.append(particle)
                }
                
                image = generateImage(CGSize(width: diameter + inset, height: diameter + inset), rotatedContext: { size, context in
                    let rect = CGRect(origin: CGPoint(), size: size)
                    context.clear(rect)
                    context.setStrokeColor(color.cgColor)
                    context.setFillColor(color.cgColor)
                    context.setLineWidth(lineWidth)
                    context.setLineCap(.round)
                    
                    let path = CGMutablePath()
                    path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                    context.addPath(path)
                    context.strokePath()
                    
                    for particle in self.particles {
                        let size: CGFloat = lineWidth / 2 + 0.15
                        context.setAlpha(particle.alpha)
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: particle.position.x - size / 2.0, y: particle.position.y - size / 2.0), size: CGSize(width: size, height: size)))
                    }
                })
            }
            
            self.contentView.image = image
            self.contentView.sizeToFit()
            self.contentView.centerY(x: frame.width - contentView.frame.width)
                        
        }
        
        if let reachedTimeout = self.reachedTimeout, fractionalTimeout <= .ulpOfOne {
            reachedTimeout()
        }
      
        if fractionalTimeout <= .ulpOfOne {
            self.animator?.invalidate()
            self.animator = nil
        } else {
            if self.animator == nil {
                let animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateValues()
                })
                animator.isPaused = self.window == nil
                self.animator = animator
            }
        }
    }
    
}
