//
//  ContainableController.swift
//  TGUIKit
//
//  Created by keepcoder on 23/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum ContainedViewLayoutTransitionCurve {
    case easeInOut
    case spring
}

public extension ContainedViewLayoutTransitionCurve {
    var timingFunction: CAMediaTimingFunctionName {
        switch self {
        case .easeInOut:
            return CAMediaTimingFunctionName.easeInEaseOut
        case .spring:
            return CAMediaTimingFunctionName.spring
        }
    }
    
}

public enum ContainedViewLayoutTransition {
    case immediate
    case animated(duration: Double, curve: ContainedViewLayoutTransitionCurve)
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
            let previousFrame = view.frame
            
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = .init(name: curve.timingFunction)
                view.animator().frame = frame
            }, completionHandler: {
                completion?(true)
            })
            view.animator().frame = frame
            
//
//
//            view.layer?.animateFrame(from: previousFrame, to: frame, duration: duration, timingFunction: curve.timingFunction, completion: { result in
//                if let completion = completion {
//                    completion(result)
//                }
//            })
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


    

    func updateAlpha(view: View, alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            view.alphaValue = alpha
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousAlpha = view.alphaValue
            view.alphaValue = alpha
            view.layer?.animateAlpha(from: previousAlpha, to: alpha, duration: duration, timingFunction: curve.timingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
}

public protocol ContainableController: class {
    var view: View! { get }
    
    func containerLayoutUpdated(transition: ContainedViewLayoutTransition)
}
