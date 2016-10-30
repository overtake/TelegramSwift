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
    var timingFunction: String {
        switch self {
        case .easeInOut:
            return kCAMediaTimingFunctionEaseInEaseOut
        case .spring:
            return kCAMediaTimingFunctionSpring
        }
    }
}

public enum ContainedViewLayoutTransition {
    case immediate
    case animated(duration: Double, curve: ContainedViewLayoutTransitionCurve)
}

public extension ContainedViewLayoutTransition {
    func updateFrame(view: View, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            view.frame = frame
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousFrame = view.frame
            view.frame = frame
            view.layer?.animateFrame(from: previousFrame, to: frame, duration: duration, timingFunction: curve.timingFunction, completion: { result in
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
