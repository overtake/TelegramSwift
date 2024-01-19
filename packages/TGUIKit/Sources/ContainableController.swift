//
//  ContainableController.swift
//  TGUIKit
//
//  Created by keepcoder on 23/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum ContainedViewLayoutTransitionCurve {
    case linear
    case easeInOut
    case easeOut
    case spring
    case legacy
}

public let listViewAnimationCurveSystem: (CGFloat) -> CGFloat = { t in
    return bezierPoint(0.23, 1.0, 0.32, 1.0, t)
}
public let listViewAnimationCurveEaseInOut: (CGFloat) -> CGFloat = { t in
    return bezierPoint(0.42, 0.0, 0.58, 1.0, t)
}

public let listViewAnimationCurveLinear: (CGFloat) -> CGFloat = { t in
    return t
}

public extension ContainedViewLayoutTransitionCurve {
    var timingFunction: CAMediaTimingFunctionName {
        switch self {
        case .easeInOut:
            return CAMediaTimingFunctionName.easeInEaseOut
        case .spring:
            return CAMediaTimingFunctionName.spring
        case .legacy:
            return CAMediaTimingFunctionName.easeInEaseOut
        case .linear:
            return CAMediaTimingFunctionName.linear
        case .easeOut:
            return CAMediaTimingFunctionName.easeOut
        }
    }
    func solve(at offset: CGFloat) -> CGFloat {
        switch self {
        case .easeInOut:
            return listViewAnimationCurveEaseInOut(offset)
        case .spring:
            return listViewAnimationCurveSystem(offset)
        case .legacy:
             return listViewAnimationCurveEaseInOut(offset)
        case .easeOut:
            return listViewAnimationCurveEaseInOut(offset)
        case .linear:
            return listViewAnimationCurveLinear(offset)
        }
    }
}







public enum ContainedViewLayoutTransition {
    case immediate
    case animated(duration: Double, curve: ContainedViewLayoutTransitionCurve)
    
    public var isAnimated: Bool {
        switch self {
        case .immediate:
            return false
        case .animated:
            return true
        }
    }
    public var duration: Double {
        switch self {
        case .immediate:
            return 0
        case let .animated(duration, _):
            return duration
        }
    }
    public var timingFunction:CAMediaTimingFunctionName  {
        switch self {
        case .immediate:
            return .linear
        case let .animated(_, curve):
            return curve.timingFunction
        }
    }
}

public extension ContainedViewLayoutTransition {
    func updateFrame(view: NSView, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            view.frame = frame
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):

            var curve = curve
            
            if view is NSVisualEffectView {
                curve = .legacy
            }
            switch curve {
            case .legacy:
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = duration
                    ctx.timingFunction = .init(name: curve.timingFunction)
                    view.animator().frame = frame
                }, completionHandler: {
                    completion?(true)
                })
            default:
                
                var ignoreSize: Bool = false
                if let view = view as? TableView {
                    view.change(size: frame.size, animated: true, duration: duration, timingFunction: curve.timingFunction, completion: { completed in
                        completion?(completed)
                    })
                }
                
                var notifyOnOrigin: Bool = false
                var notifyOnSize: Bool = false
                if frame.size != view.frame.size {
                    notifyOnSize = true
                } else if frame.origin != view.frame.origin {
                    notifyOnOrigin = true
                } else {
                    completion?(true)
                }
                
                view._change(size: frame.size, animated: true, duration: duration, timingFunction: curve.timingFunction, completion: { completed in
                    if notifyOnSize {
                        completion?(completed)
                    }
                })
                view._change(pos: frame.origin, animated: true, duration: duration, timingFunction: curve.timingFunction, completion: { completed in
                    if notifyOnOrigin {
                        completion?(completed)
                    }
                })
            }
        }
    }
    func updateFrame(layer: CALayer, frame: CGRect, completion: ((Bool) -> Void)? = nil, save: Bool = true) {
        switch self {
        case .immediate:
            layer.frame = frame
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, _):

            
            func animateSize(_ layer: CALayer) -> Void {
                var presentBounds:NSRect = layer.bounds
                let presentation = layer.presentation()
                if let presentation = presentation, layer.animation(forKey:"bounds") != nil {
                    presentBounds.size.width = NSWidth(presentation.bounds)
                    presentBounds.size.height = NSHeight(presentation.bounds)
                }
                layer.animateBounds(from: presentBounds, to: frame.size.bounds, duration: duration, timingFunction: timingFunction, completion: completion)
            }
            func animatePos(_ layer: CALayer) -> Void {
                var presentRect:NSPoint = layer.position
                let presentation = layer.presentation()
                if let presentation = presentation, layer.animation(forKey:"position") != nil {
                    presentRect.x = presentation.position.x
                    presentRect.y = presentation.position.y
                }
                layer.animatePosition(from: presentRect, to: frame.origin, duration: duration, timingFunction: timingFunction, completion: completion)
            }
            if layer.frame.origin != frame.origin {
                animatePos(layer)
            }
            if layer.frame.size != frame.size {
                animateSize(layer)
            }
            if save {
                layer.frame = frame.size.bounds
                layer.position = frame.origin
            }
            
        }
    }
    
       func updateTransformScale(layer: CALayer, scale: CGFloat, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
           let t = layer.transform
           let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
           if currentScale.isEqual(to: scale) {
               if let completion = completion {
                   completion(true)
               }
               return
           }
           
           switch self {
           case .immediate:
               layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
               if let completion = completion {
                   completion(true)
               }
           case let .animated(duration, curve):
               let previousScale: CGFloat
               if beginWithCurrentState, let presentation = layer.presentation() {
                   let t = presentation.transform
                   previousScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
               } else {
                   previousScale = currentScale
               }
            layer.animateScaleSpring(from: previousScale, to: scale, duration: duration, bounce: false, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
           }
       }


    

    func updateAlpha(view: NSView, alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            view.layer?.opacity = Float(alpha)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousAlpha = view.layer?.presentation()?.opacity ?? view.layer?.opacity ?? 1
            view.layer?.opacity = Float(alpha)
            view.layer?.animateAlpha(from: CGFloat(previousAlpha), to: alpha, duration: duration, timingFunction: curve.timingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateAlpha(layer: CALayer, alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            layer.opacity = Float(alpha)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousAlpha = layer.presentation()?.opacity ?? layer.opacity
            layer.opacity = Float(alpha)
            layer.animateAlpha(from: CGFloat(previousAlpha), to: alpha, duration: duration, timingFunction: curve.timingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
//    func updatePosition(layer: CALayer, position: NSPoint, completion: ((Bool) -> Void)? = nil) {
//        switch self {
//        case .immediate:
//            layer.position = position
//            if let completion = completion {
//                completion(true)
//            }
//        case let .animated(duration, curve):
//            let previousAlpha = layer.presentation()?.opacity ?? layer.opacity
//            layer.position = position
//            layer.animateAlpha(from: CGFloat(previousAlpha), to: alpha, duration: duration, timingFunction: curve.timingFunction, completion: { result in
//                if let completion = completion {
//                    completion(result)
//                }
//            })
//        }
//    }

    
    func animatePositionWithKeyframes(layer: CALayer, keyframes: [CGPoint], removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
           switch self {
           case .immediate:
               completion?(true)
           case let .animated(duration, curve):
               layer.animateKeyframes(values: keyframes.map(NSValue.init(point:)), duration: duration, keyPath: "position", timingFunction: curve.timingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
           }
       }
    
    
    func setShapeLayerStrokeEnd(layer: CAShapeLayer, strokeEnd: CGFloat, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            layer.strokeEnd = strokeEnd
            completion?(true)
        case let .animated(duration, curve):
            let previousStrokeEnd = layer.strokeEnd
            layer.strokeEnd = strokeEnd
            
            layer.animate(
                from: previousStrokeEnd as NSNumber,
                to: strokeEnd as NSNumber,
                keyPath: "strokeEnd",
                timingFunction: curve.timingFunction,
                duration: duration,
                delay: 0.0,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }


}

public protocol ContainableController: class {
    var view: View! { get }
    
    func containerLayoutUpdated(transition: ContainedViewLayoutTransition)
}
