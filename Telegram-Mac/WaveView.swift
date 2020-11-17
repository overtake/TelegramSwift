//
//  WaveView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13.11.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

private struct Constants {
    static let sineWaveSpeed: CGFloat = 0.81
    static let smallWaveRadius: CGFloat = 0.55
    static let smallWaveScale: CGFloat = 0.40
    static let smallWaveScaleSpeed: CGFloat = 0.6
    static let flingDistance: CGFloat = 0.5
    
    static let circleRadius: CGFloat = 56.0
    
    static let animationSpeed: CGFloat = 0.35 * 0.1
    static let animationSpeedSmall: CGFloat = 0.55 * 0.1
    
    static let rotationSpeed: CGFloat = 0.36 * 0.1
    static let waveAngle: CGFloat = 0.03
    static let randomRadiusSize: CGFloat = 0.3
    
    static let idleWaveAngle: CGFloat = 0.5
    static let idleScaleSpeed: CGFloat = 0.3
    static let idleRotationSpeed: CGFloat = 0.2
    static let idleRadiusValue: CGFloat = 0.56
    static let idleRotationDiff: CGFloat = 0.1 * idleRotationSpeed
}

class CombinedWaveView: View {
    private let bigWaveView: WaveView
    private let smallWaveView: WaveView
    
    private var level: CGFloat = 0.0
    
    init(frame: CGRect, color: NSColor) {
        let n = 12
        let bounds = CGRect(origin: CGPoint(), size: frame.size)
        self.bigWaveView = WaveView(frame: bounds, n: n, amplitudeRadius: 30.0, isBig: true, color: color.withAlphaComponent(0.3))
        self.smallWaveView = WaveView(frame: bounds, n: n, amplitudeRadius: 35.0, isBig: false, color: color.withAlphaComponent(0.15))
        
        super.init(frame: frame)
        
        self.bigWaveView.rotation = CGFloat.pi / 6.0
        self.bigWaveView.amplitudeWaveDif = 0.02 * Constants.sineWaveSpeed * CGFloat.pi / 180.0
        
        self.smallWaveView.amplitudeWaveDif = 0.026 * Constants.sineWaveSpeed
        self.smallWaveView.amplitudeRadius = 10.0 + 20.0 * Constants.smallWaveRadius
        self.smallWaveView.maxScale = 0.3 * Constants.smallWaveScale
        self.smallWaveView.scaleSpeed = 0.001 * Constants.smallWaveScaleSpeed
        self.smallWaveView.fling = Constants.flingDistance
        
        self.addSubview(self.bigWaveView)
        self.addSubview(self.smallWaveView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func updateLevel(_ level: CGFloat) {
        let level = level * 0.2
        self.level = level
        self.bigWaveView.setLevel(level)
        self.smallWaveView.setLevel(level)
    }
    
    func tick(_ level: CGFloat) {
        let radius = 56.0 + 30.0 * level * 0.2
        self.bigWaveView.tick(circleRadius: radius)
        self.smallWaveView.tick(circleRadius: radius)
    }
    
    func setColor(_ color: NSColor) {
    }
}

class WaveView : View {
    var fling: CGFloat = 0.0
    private var animateToAmplitude: CGFloat = 0.0
    private var amplitude: CGFloat = 0.0
    private var slowAmplitude: CGFloat = 0.0
    private var animateAmplitudeDiff: CGFloat = 0.0
    private var animateAmplitudeSlowDiff: CGFloat = 0.0
    
    private var lastRadius: CGFloat = 0.0
    private var radiusDiff: CGFloat = 0.0
    private var waveDiff: CGFloat = 0.0
    private var waveAngle: CGFloat = 0.0
    
    private var incRandomAdditionals = false
    
    var rotation: CGFloat = 0.0
    private var idleRotation: CGFloat = 0.0
    private var innerRotation: CGFloat = 0.0
    
    var amplitudeWaveDif: CGFloat = 0.0
    
    var amplitudeRadius: CGFloat
    private let isBig: Bool
    
    private var idleRadius: CGFloat = 0.0
    private var idleRadiusK: CGFloat = 0.15 * Constants.idleWaveAngle
    private var expandIdleRadius = false
    private var expandScale = false
    
    private var isIdle = true
    private var scale: CGFloat = 1.0
    private var scaleIdleDif: CGFloat = 0.0
    private var scaleDif: CGFloat = 0.0
    var scaleSpeed: CGFloat = 0.00008
    public var scaleSpeedIdle: CGFloat = 0.0002 * Constants.idleScaleSpeed
    var maxScale: CGFloat = 0.0
    
    private var flingRadius: CGFloat = 0.0
    
    private let randomAdditions: CGFloat = 8.0 * Constants.randomRadiusSize
    
    private var idleGlobalRadius: CGFloat = 10.0 * Constants.idleRadiusValue
    private var sineAngleMax: CGFloat = 0.0
    
    private let n: Int
    private let l: CGFloat
    private var additions: [CGFloat]
    
    var idleStateDiff: CGFloat = 0.0
    var radius: CGFloat = 60.0;
    var cubicBezierK: CGFloat = 1.0;
    
    var randomK: CGFloat = 0.0
    
    var color: NSColor
    
    init(frame: CGRect, n: Int, amplitudeRadius: CGFloat, isBig: Bool, color: NSColor) {
        self.n = n
        self.amplitudeRadius = amplitudeRadius
        self.isBig = isBig
        self.color = color
        
        self.expandIdleRadius = isBig
        self.radiusDiff = 34.0 * 0.0012
        
        self.l = 4.0 / 3.0 * tan(CGFloat.pi / (2.0 * CGFloat(self.n)))
        self.additions = Array(repeating: 0.0, count: self.n)
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        
        self.updateAdditions()
    }
    
    func setLevel(_ level: CGFloat) {
        self.animateToAmplitude = level
        
        let amplitudeDelta: CGFloat
        let amplitudeSlowDelta: CGFloat
        if self.isBig {
            if self.animateToAmplitude > self.amplitude {
                amplitudeDelta = 300.0 * Constants.animationSpeed
                amplitudeSlowDelta = 500.0 * Constants.animationSpeed
            } else {
                amplitudeDelta = 500.0 * Constants.animationSpeed
                amplitudeSlowDelta = 500.0 * Constants.animationSpeed
            }
        } else {
            if self.animateToAmplitude > self.amplitude {
                amplitudeDelta = 400.0 * Constants.animationSpeedSmall
                amplitudeSlowDelta = 500.0 * Constants.animationSpeedSmall
            } else {
                amplitudeDelta = 500.0 * Constants.animationSpeedSmall
                amplitudeSlowDelta = 500.0 * Constants.animationSpeedSmall
            }
        }
        
        self.animateAmplitudeDiff = (self.animateToAmplitude - self.amplitude) / (100.0 + amplitudeDelta)
        self.animateAmplitudeSlowDiff = (self.animateToAmplitude - self.slowAmplitude) / (100.0 + amplitudeSlowDelta)
        
        let isIdle = level < 0.1
        if self.isIdle != isIdle && isIdle && self.isBig {
            //
            //
            //
        }
        
        self.isIdle = isIdle
    }
    
    private var wasFling = false
    
    private var timer1: SwiftSignalKit.Timer? = nil
    private var timer2: SwiftSignalKit.Timer? = nil

    private func startFling(delta: CGFloat) {
        
        timer1?.invalidate()
        timer2?.invalidate()
        
        var runSecondAnimation:(()->Void)?
        
        let fling = self.fling * 2.0
        let flingDistance = delta * self.amplitudeRadius * (self.isBig ? 8.0 : 20.0) * 16.0 * fling
        
        let duration1 = CGFloat((self.isBig ? 0.2 : 0.35) * fling)
        let fromValue1 = self.flingRadius
        let toValue1 = flingDistance
        let tickCountValue1 = duration1 / 0.016
        let tickValue1 = (toValue1 - fromValue1) / tickCountValue1
        
        let toIsBigger = toValue1 >= fromValue1
        
        timer1 = SwiftSignalKit.Timer(timeout: 0.016, repeat: true, completion: { [weak self] in
            guard let `self` = self else {
                return
            }
            let completion:()->Void = { [weak self] in
                self?.timer1?.invalidate()
                runSecondAnimation?()
            }
            self.flingRadius += tickValue1
            if toIsBigger {
                if self.flingRadius >= toValue1 {
                    completion()
                }
            } else {
                if self.flingRadius <= toValue1 {
                    completion()
                }
            }
        }, queue: .mainQueue())
        
        timer1?.start()
        
        
        runSecondAnimation = { [weak self] in
            guard let `self` = self else {
                return
            }
            let duration2 = CGFloat((self.isBig ? 0.22 : 0.38) * fling)
            let fromValue2 = flingDistance
            let toValue2: CGFloat = 0
            let tickCountValue2 = duration2 / 0.016
            let tickValue2 = fromValue2 / tickCountValue2
            
            self.timer2 = SwiftSignalKit.Timer(timeout: 0.016, repeat: true, completion: { [weak self] in
                guard let `self` = self else {
                    return
                }
                let completion:()->Void = { [weak self] in
                    self?.timer2?.invalidate()
                }
                self.flingRadius -= tickValue2
                if self.flingRadius <= toValue2 {
                    completion()
                }
            }, queue: .mainQueue())
            
            self.timer2?.start()
        }
    }
    
    private var lastUpdateTime: CGFloat?
    func tick(circleRadius: CGFloat) {
        let dt: CGFloat
        let time = CGFloat(CACurrentMediaTime())
        if let lastUpdateTime = self.lastUpdateTime {
            dt = (time - lastUpdateTime) * 1000.0
        } else {
            dt = 0.0
        }
        self.lastUpdateTime = time
        
        if self.animateToAmplitude != self.amplitude {
            self.amplitude += self.animateAmplitudeDiff * dt
            if self.animateAmplitudeDiff > 0.0 {
                if self.amplitude > self.animateToAmplitude {
                    self.amplitude = self.animateToAmplitude
                }
            } else {
                if self.amplitude < self.animateToAmplitude {
                    self.amplitude = self.animateToAmplitude
                }
            }
            
            if abs(self.amplitude - self.animateToAmplitude) * self.amplitudeRadius < 4.0 {
                if !self.wasFling {
                    self.startFling(delta: self.animateAmplitudeDiff)
                    self.wasFling = true
                }
            } else {
                self.wasFling = false
            }
        }
        
        if self.animateToAmplitude != self.slowAmplitude {
            self.slowAmplitude += self.animateAmplitudeSlowDiff * dt
            if abs(self.slowAmplitude - self.amplitude) > 0.2 {
                self.slowAmplitude = self.amplitudeRadius + (self.slowAmplitude > self.amplitude ? 0.2 : -0.2)
            }
            if self.animateAmplitudeSlowDiff > 0.0 {
                if self.slowAmplitude > self.animateToAmplitude {
                    self.slowAmplitude = self.animateToAmplitude
                }
            } else {
                if self.slowAmplitude < self.animateToAmplitude {
                    self.slowAmplitude = self.animateToAmplitude
                }
            }
        }
        
        self.idleRadius = circleRadius * self.idleRadiusK
        if self.expandIdleRadius {
            self.scaleIdleDif += self.scaleSpeedIdle * dt
            if self.scaleIdleDif >= 0.05 {
                self.scaleIdleDif = 0.05
                self.expandIdleRadius = false
            }
        } else {
            self.scaleIdleDif -= self.scaleSpeedIdle * dt
            if self.scaleIdleDif < 0.0 {
                self.scaleIdleDif = 0.0
                self.expandIdleRadius = true
            }
        }
        
        if self.maxScale > 0.0 {
            if self.expandScale {
                self.scaleDif += self.scaleSpeed * dt
                if self.scaleDif >= self.maxScale {
                    self.scaleDif = self.maxScale
                    self.expandScale = false
                }
            } else {
                self.scaleDif -= self.scaleSpeed * dt
                if self.scaleDif < 0.0 {
                    self.scaleDif = 0.0
                    self.expandScale = true
                }
            }
        }
        
        if self.sineAngleMax > self.animateToAmplitude {
            self.sineAngleMax -= 0.25
            if self.sineAngleMax < self.animateToAmplitude {
                self.sineAngleMax = self.animateToAmplitude
            }
        } else if self.sineAngleMax < self.animateToAmplitude {
            self.sineAngleMax += 0.25
            if self.sineAngleMax > self.animateToAmplitude {
                self.sineAngleMax = self.animateToAmplitude
            }
        }
        
        if !self.isIdle {
            self.rotation += (Constants.rotationSpeed * 0.5 + Constants.rotationSpeed * 4.0 * (self.amplitude > 0.5 ? 1.0 : self.amplitude / 0.5) * dt) * CGFloat.pi / 180.0
            while self.rotation > CGFloat.pi * 2.0 {
                self.rotation -= CGFloat.pi * 2.0
            }
        } else {
            self.idleRotation += Constants.idleRotationDiff * dt * CGFloat.pi / 180.0
            while self.idleRotation > CGFloat.pi * 2.0 {
                self.idleRotation -= CGFloat.pi * 2.0
            }
        }
        
        if self.lastRadius < circleRadius {
            self.lastRadius = circleRadius
        } else {
            self.lastRadius -= self.radiusDiff * dt
            if self.lastRadius < circleRadius {
                self.lastRadius = circleRadius
            }
        }
        
        self.lastRadius = circleRadius
        
        if !self.isIdle {
            self.waveAngle += self.amplitudeWaveDif * self.sineAngleMax * dt
            if self.isBig {
                self.waveDiff = cos(self.waveAngle)
            } else {
                self.waveDiff = -cos(self.waveAngle)
            }
            
            if self.waveDiff > 0.0 && self.incRandomAdditionals {
                self.updateAdditions()
                self.incRandomAdditionals = false
            } else if self.waveDiff < 0.0 && !self.incRandomAdditionals {
                self.updateAdditions()
                self.incRandomAdditionals = true
            }
        }
        
        self.prepareDraw()
    }
    
    func updateAdditions() {
        self.additions = (0..<self.n).map { _ in CGFloat(arc4random() % 100) / 100.0 }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func prepareDraw() {
        let waveAmplitude = self.amplitude < 0.3 ? self.amplitude / 0.3 : 1.0
        let radiusDiff: CGFloat = 10.0 + 50.0 * Constants.waveAngle * self.animateToAmplitude
        
        self.idleStateDiff = self.idleRadius * (1.0 - waveAmplitude)
        
        let kDiff: CGFloat = 0.35 * waveAmplitude * self.waveDiff
        self.radiusDiff = radiusDiff * kDiff
        self.cubicBezierK = 1.0 + abs(kDiff) * waveAmplitude + (1.0 - waveAmplitude) * self.idleRadiusK
        
        self.radius = (self.lastRadius + self.amplitudeRadius * self.amplitude) + self.idleGlobalRadius + (self.flingRadius * waveAmplitude)
        
        if self.radius + self.radiusDiff < Constants.circleRadius {
            self.radiusDiff = Constants.circleRadius - self.radius
        }
        
        if self.isBig {
            self.innerRotation = self.rotation + self.idleRotation
        } else {
            self.innerRotation = -self.rotation + self.idleRotation
        }
        
        self.randomK = waveAmplitude * self.waveDiff * self.randomAdditions
        
        self.scale = 1.0 + self.scaleIdleDif * (1.0 - waveAmplitude) + self.scaleDif * waveAmplitude
        
        self.setNeedsDisplay()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        let rect = layer.bounds
        
        ctx.clear(rect)
        
        let r1 = self.radius - self.idleStateDiff / 2.0 - self.radiusDiff / 2.0
        let r2 = self.radius + self.radiusDiff / 2.0 + self.idleStateDiff / 2.0
        
        let l = self.l * max(r1, r2) * self.cubicBezierK
        
        let cx = rect.width / 2.0
        let cy = rect.height / 2.0
        
        let path = CGMutablePath()
        
        for i in 0..<self.n {
            var transform = CGAffineTransform.init(translationX: cx, y: cy)
            transform = transform.rotated(by: 2 * CGFloat.pi / CGFloat(self.n) * CGFloat(i))
            transform = transform.translatedBy(x: -cx, y: -cy)
            
            var r = ((i % 2 == 0) ? r1 : r2) + self.randomK * self.additions[i]
            
            var p1 = CGPoint(x: cx, y: cy - r)
            var p2 = CGPoint(x: cx + l + self.randomK * self.additions[i] * self.l, y: cy - r)
            
            p1 = p1.applying(transform)
            p2 = p2.applying(transform)
            
            var j = i + 1
            if j >= self.n {
                j = 0
            }
            
            r = ((j % 2 == 0) ? r1 : r2) + self.randomK * self.additions[j]
            
            var p3 = CGPoint(x: cx, y: cy - r)
            var p4 = CGPoint(x: cx - l + self.randomK * self.additions[j] * self.l, y: cy - r)
            
            transform = CGAffineTransform.init(translationX: cx, y: cy)
            transform = transform.rotated(by: 2 * CGFloat.pi / CGFloat(self.n) * CGFloat(j))
            transform = transform.translatedBy(x: -cx, y: -cy)
            
            p3 = p3.applying(transform)
            p4 = p4.applying(transform)
            
            if i == 0 {
                path.move(to: p1)
            }
            path.addCurve(to: p3, control1: p2, control2: p4)
        }
        
        ctx.setFillColor(self.color.cgColor)
        
        ctx.saveGState()
        ctx.translateBy(x: rect.width / 2.0, y: rect.height / 2.0)
        ctx.scaleBy(x: self.scale, y: self.scale)
        ctx.rotate(by: self.innerRotation)
        ctx.translateBy(x: -rect.width / 2.0, y: -rect.height / 2.0)
        
        ctx.addPath(path)
        ctx.drawPath(using: .fill)
        ctx.restoreGState()
    }
    
}
