//
//  DisplayLinkAnimator.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 30/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import AppKit

class DisplayLink
{
   let timer  : CVDisplayLink
   let source : DispatchSourceUserDataAdd
   
   var callback : Optional<() -> ()> = nil
   
   var running : Bool { return CVDisplayLinkIsRunning(timer) }
   
   init?(onQueue queue: DispatchQueue = DispatchQueue.main)
   {
       source = DispatchSource.makeUserDataAddSource(queue: queue)
       
       var timerRef : CVDisplayLink? = nil
       
       var successLink = CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &timerRef)
       
       if let timer = timerRef
       {
           
           successLink = CVDisplayLinkSetOutputCallback(timer, { (timer : CVDisplayLink, currentTime : UnsafePointer<CVTimeStamp>, outputTime : UnsafePointer<CVTimeStamp>, _ : CVOptionFlags, _ : UnsafeMutablePointer<CVOptionFlags>, sourceUnsafeRaw : UnsafeMutableRawPointer?) -> CVReturn in
                                                           
                if let sourceUnsafeRaw = sourceUnsafeRaw {
                   let sourceUnmanaged = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(sourceUnsafeRaw)
                   sourceUnmanaged.takeUnretainedValue().add(data: 1)
                }
               return kCVReturnSuccess
           }, Unmanaged.passUnretained(source).toOpaque())
           
           guard successLink == kCVReturnSuccess else
           {
               NSLog("Failed to create timer with active display")
               return nil
           }
           
           successLink = CVDisplayLinkSetCurrentCGDisplay(timer, CGMainDisplayID())
           
           guard successLink == kCVReturnSuccess else
           {
               return nil
           }
           
           self.timer = timer
       } else {
           return nil
       }
       source.setEventHandler(handler: { [weak self] in
           self?.callback?()
       })
   }
    
    var timestamp: TimeInterval {
        return CVDisplayLinkGetActualOutputVideoRefreshPeriod(self.timer)
    }
   
   func start() {
       guard !running else { return }
       
       CVDisplayLinkStart(timer)
       source.resume()
   }
   
   func cancel()
   {
       guard running else { return }
       
       CVDisplayLinkStop(timer)
       source.cancel()
   }
   
   deinit
   {
       if running
       {
           cancel()
       }
   }
}



public protocol SharedDisplayLinkDriverLink: AnyObject {
    var isPaused: Bool { get set }
    
    func invalidate()
}

public final class SharedDisplayLinkDriver {
    public enum FramesPerSecond: Comparable {
        case fps(Int)
        case max
        
        public static func <(lhs: FramesPerSecond, rhs: FramesPerSecond) -> Bool {
            switch lhs {
            case let .fps(lhsFps):
                switch rhs {
                case let .fps(rhsFps):
                    return lhsFps < rhsFps
                case .max:
                    return true
                }
            case .max:
                return false
            }
        }
    }
    
    public typealias Link = SharedDisplayLinkDriverLink
    
    public static let shared = SharedDisplayLinkDriver()
    
    public final class LinkImpl: Link {
        private let driver: SharedDisplayLinkDriver
        public let framesPerSecond: FramesPerSecond
        let update: (CGFloat) -> Void
        var isValid: Bool = true
        public var isPaused: Bool = false {
            didSet {
                if self.isPaused != oldValue {
                    self.driver.requestUpdate()
                }
            }
        }
        
        init(driver: SharedDisplayLinkDriver, framesPerSecond: FramesPerSecond, update: @escaping (CGFloat) -> Void) {
            self.driver = driver
            self.framesPerSecond = framesPerSecond
            self.update = update
        }
        
        public func invalidate() {
            self.isValid = false
        }
    }
    
    private final class RequestContext {
        weak var link: LinkImpl?
        let framesPerSecond: FramesPerSecond
        
        var lastDuration: Double = 0.0
        
        init(link: LinkImpl, framesPerSecond: FramesPerSecond) {
            self.link = link
            self.framesPerSecond = framesPerSecond
        }
    }
    
    private var displayLink: DisplayLink?
    private var requests: [RequestContext] = []
    
    private var isInForeground: Bool = false
    private var isProcessingEvent: Bool = false
    private var isUpdateRequested: Bool = false
    
    private init() {
        self.isInForeground = true

        
        self.update()
    }
    
    public func updateForegroundState(_ isActive: Bool) {
        if self.isInForeground != isActive {
            self.isInForeground = isActive
            self.update()
        }
    }
    
    private func requestUpdate() {
        if self.isProcessingEvent {
            self.isUpdateRequested = true
        } else {
            self.update()
        }
    }
    
    private func update() {
        var hasActiveItems = false
        var maxFramesPerSecond: FramesPerSecond = .fps(60)
        for request in self.requests {
            if let link = request.link {
                if link.framesPerSecond > maxFramesPerSecond {
                    maxFramesPerSecond = link.framesPerSecond
                }
                if link.isValid && !link.isPaused {
                    hasActiveItems = true
                    break
                }
            }
        }
        
        if self.isInForeground && hasActiveItems {
            let displayLink: DisplayLink?
            if let current = self.displayLink {
                displayLink = current
            } else {
                displayLink = DisplayLink()
                displayLink?.callback = { [weak displayLink, weak self] in
                    if let duration = displayLink?.timestamp {
                        self?.displayLinkEvent(duration: duration)
                    }
                }
                self.displayLink = displayLink
            }
            displayLink?.start()
        } else {
            if let displayLink = self.displayLink {
                self.displayLink = nil
                displayLink.cancel()
            }
        }
    }
    
    private func displayLinkEvent(duration: TimeInterval) {
        self.isProcessingEvent = true
        
        
        var removeIndices: [Int]?
        loop: for i in 0 ..< self.requests.count {
            let request = self.requests[i]
            if let link = request.link, link.isValid {
                if !link.isPaused {
                    var itemDuration = duration
                    
                    switch request.framesPerSecond {
                    case let .fps(value):
                        let secondsPerFrame = 1.0 / CGFloat(value)
                        itemDuration = secondsPerFrame
                        request.lastDuration += duration
                        if request.lastDuration >= secondsPerFrame * 0.95 {
                            //print("item \(link) accepting cycle: \(request.lastDuration - duration) + \(duration) = \(request.lastDuration) >= \(secondsPerFrame)")
                        } else {
                            //print("item \(link) skipping cycle: \(request.lastDuration - duration) + \(duration) < \(secondsPerFrame)")
                            continue loop
                        }
                    case .max:
                        break
                    }
                    
                    request.lastDuration = 0.0
                    link.update(itemDuration)
                }
            } else {
                if removeIndices == nil {
                    removeIndices = [i]
                } else {
                    removeIndices?.append(i)
                }
            }
        }
        if let removeIndices = removeIndices {
            for index in removeIndices.reversed() {
                self.requests.remove(at: index)
            }
            
            if self.requests.isEmpty {
                self.isUpdateRequested = true
            }
        }
        
        self.isProcessingEvent = false
        if self.isUpdateRequested {
            self.isUpdateRequested = false
            self.update()
        }
    }
    
    public func add(framesPerSecond: FramesPerSecond = .fps(60), _ update: @escaping (CGFloat) -> Void) -> Link {
        let link = LinkImpl(driver: self, framesPerSecond: framesPerSecond, update: update)
        self.requests.append(RequestContext(link: link, framesPerSecond: framesPerSecond))
        
        self.update()
        
        return link
    }
}




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
    private var displayLink: SharedDisplayLinkDriver.Link?
    private let duration: Double
    private let fromValue: CGFloat
    private let toValue: CGFloat
    private let startTime: Double
    private let update: (CGFloat) -> Void
    private let completion: () -> Void
    private var completed = false
    private var timingControlPoints:[Float] = [0, 0, 0, 0];

    public init(duration: Double, from fromValue: CGFloat, to toValue: CGFloat, timingFunction: CAMediaTimingFunction = .init(name: .easeOut), update: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
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
        
        self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] _ in
            self?.tick(false)
        })
        

        self.tick(true)
    }
    
    deinit {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
    
    public func invalidate() {
        self.displayLink?.invalidate()
        self.displayLink = nil
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
            self.displayLink?.invalidate()
            self.completion()
        }
    }
}

public final class ConstantDisplayLinkAnimator {
    private var displayLink: SharedDisplayLinkDriver.Link?
    private let update: () -> Void
    private var completed = false
    private let fps: TimeInterval

    
    public var isPaused: Bool = true {
        didSet {
            if self.isPaused != oldValue {
                if self.isPaused {
                    self.displayLink = nil
                } else {
                    self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(Int(fps)), { [weak self] _ in
                        self?.tick()
                    })
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

