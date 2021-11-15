//
//  DisplayLinkAnimator.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 30/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit

private final class DisplayLinkTarget: NSObject {
    private let f: () -> Void
    
    init(_ f: @escaping () -> Void) {
        self.f = f
    }
    
    @objc func event() {
        self.f()
    }
}


private struct UnitBezier {
    private let ax: Float;
    private let bx: Float;
    private let cx: Float;
    
    private let ay: Float;
    private let by: Float;
    private let cy: Float;
    
    init(_ p1x: Float, _ p1y: Float, _ p2x: Float, _ p2y: Float) {
        self.cx = 3.0 * p1x;
        self.bx = 3.0 * (p2x - p1x) - cx;
        self.ax = 1.0 - cx - bx;
        
        self.cy = 3.0 * p1y;
        self.by = 3.0 * (p2y - p1y) - cy;
        self.ay = 1.0 - cy - by;
    }

    func sampleCurveX(_ t: Float) -> Float {
        return ((ax * t + bx) * t + cx) * t;
    }

    func sampleCurveY(_ t: Float) -> Float {
        return ((ay * t + by) * t + cy) * t;
    }
  
    func sampleCurveDerivativeX(_ t: Float) -> Float {
        return (3.0 * ax * t + 2.0 * bx) * t + cx;
    }
  
    func solveCurveX(_ x: Float, _ epsilon: Float) -> Float{
        var t0:Float = 0;
        var t1:Float = 0;
        var t2:Float = 0;
        var x2:Float = 0;
        var d2:Float = 0;
    
        for _ in 0 ..< 8 {
            t2 = x;
            x2 = sampleCurveX(t2) - x;
            if (abs (x2) < epsilon) {
                return t2;
            }
            d2 = sampleCurveDerivativeX(t2);
            if (abs(d2) < 1e-6) {
                break;
            }
            t2 = t2 - x2 / d2;
        }
        t0 = 0.0;
        t1 = 1.0;
        t2 = x;
    
        if (t2 < t0) {
            return t0;

        }
        if (t2 > t1) {
            return t1;
        }
    
        while (t0 < t1) {
            x2 = sampleCurveX(t2);
            if (abs(x2 - x) < epsilon) {
                return t2;
            }
            if (x > x2) {
                t0 = t2;
            } else {
                t1 = t2;
            }
            t2 = (t1 - t0) * 0.5 + t0;
        }
        return t2;
    }
  
    func solve(_ x: Float, _ epsilon: Float) -> Float {
        return sampleCurveY(solveCurveX(x, epsilon));
    }
}

private func TimingFunctionSolve(_ vec: [Float], _ t: Float, _ eps: Float) -> Float {
    let bezier = UnitBezier(vec[0], vec[1], vec[2], vec[3]);
    return bezier.solve(t, eps);
}
private func solveEps(_ duration: Float) -> Float {
    return (1.0 / (1000.0 * (duration)))
}

public final class DisplayLinkAnimator {
    private var displayLink: SwiftSignalKit.Timer!
    private let duration: Double
    private let fromValue: CGFloat
    private let toValue: CGFloat
    private let startTime: Double
    private let update: (CGFloat) -> Void
    private let completion: () -> Void
    private var completed = false
    private var timingControlPoints:[Float] = [0, 0, 0, 0];

    public init(duration: Double, from fromValue: CGFloat, to toValue: CGFloat, timingFunction: CAMediaTimingFunction = .init(name: .easeInEaseOut), update: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
        self.duration = duration
        self.fromValue = fromValue
        self.toValue = toValue
        self.update = update
        self.completion = completion
        
        var firstTwo:[Float] = [0, 0]
        var lastTwo:[Float] = [0, 0]

        timingFunction.getControlPoint(at: 1, values: &firstTwo)
        timingFunction.getControlPoint(at: 2, values: &lastTwo)

        for i in 0 ..< firstTwo.count {
            timingControlPoints[i] = firstTwo[i]
        }
        for i in 0 ..< lastTwo.count {
            timingControlPoints[i + firstTwo.count] = lastTwo[i]
        }
        self.startTime = CACurrentMediaTime()
        
        self.displayLink = SwiftSignalKit.Timer.init(timeout: 0.016, repeat: true, completion: { [weak self] in
            self?.tick(false)
        }, queue: .mainQueue())
        
        self.displayLink.start()

        self.tick(true)
    }
    
    deinit {
        self.displayLink.invalidate()
    }
    
    public func invalidate() {
        self.displayLink.invalidate()
    }
    
    @objc private func tick(_ isFirst: Bool) {
        if self.completed {
            return
        }
        let timestamp = CACurrentMediaTime()
        var t = min(timestamp - self.startTime, self.duration) / self.duration
        t = max(0.0, t)
        t = min(1.0, t)
        
        let solved: Float
        if isFirst {
            solved = 0
        } else {
            solved = TimingFunctionSolve(timingControlPoints, Float(t), solveEps(Float(duration)));
        }
        
        self.update(self.fromValue * CGFloat(1 - solved) + self.toValue * CGFloat(solved))
        if abs(t - 1.0) < Double.ulpOfOne {
            self.completed = true
            self.displayLink.invalidate()
            self.completion()
        }
    }
}

public final class ConstantDisplayLinkAnimator {
    private var displayLink: SwiftSignalKit.Timer?
    private let update: () -> Void
    private var completed = false
    private let fps: TimeInterval

    
    public var isPaused: Bool = true {
        didSet {
            if self.isPaused != oldValue {
                if self.isPaused {
                    self.displayLink?.invalidate()
                } else {
                    
                    self.displayLink = SwiftSignalKit.Timer(timeout: 1 / fps, repeat: true, completion: { [weak self] in
                        self?.tick()
                    }, queue: .mainQueue())
                    
                    self.displayLink?.start()
                }
            }
        }
    }
    
    public init(update: @escaping () -> Void, fps: TimeInterval = 60) {
        self.update = update
        self.fps = fps
    }
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    public func invalidate() {
        self.displayLink?.invalidate()
    }
    
    @objc private func tick() {
        if self.completed {
            return
        }
        self.update()
    }
}

