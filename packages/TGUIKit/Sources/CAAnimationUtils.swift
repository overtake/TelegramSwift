//
//  CAAnimationUtils.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

@objc public class CALayerAnimationDelegate: NSObject, CAAnimationDelegate {
    var completion: ((Bool) -> Void)?
    
    public init(completion: ((Bool) -> Void)?) {
        self.completion = completion
        
        super.init()
    }
    
    @objc public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let completion = self.completion {
            completion(flag)
        }
    }
}
public extension NSView {
    static func animationDurationFactor() -> Double {
        return 1.0
    }
}

private let completionKey = "CAAnimationUtils_completion"

public extension CAMediaTimingFunctionName {
    static var spring: CAMediaTimingFunctionName {
        return CAMediaTimingFunctionName(rawValue: "CAAnimationUtilsSpringCurve")
    }
}

public extension CAAnimation {
    var completion: ((Bool) -> Void)? {
        get {
            if let delegate = self.delegate as? CALayerAnimationDelegate {
                return delegate.completion
            } else {
                return nil
            }
        } set(value) {
            if let delegate = self.delegate as? CALayerAnimationDelegate {
                delegate.completion = value
            } else {
                self.delegate = CALayerAnimationDelegate(completion: value)
            }
        }
    }
}

public func makeSpringAnimation(_ path:String) -> CABasicAnimation {
    let springAnimation:CASpringAnimation = CASpringAnimation(keyPath: path)
    springAnimation.mass = 3.0;
    springAnimation.stiffness = 1000.0;
    springAnimation.damping = 500.0;
    springAnimation.initialVelocity = 0.0;
    springAnimation.duration = 0.5;//springAnimation.settlingDuration;
    springAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
    return springAnimation;
}

public func makeSpringBounceAnimation(_ path:String, _ initialVelocity:CGFloat, _ damping: CGFloat = 88.0) -> CABasicAnimation {
    let springAnimation:CASpringAnimation = CASpringAnimation(keyPath: path)
    springAnimation.mass = 5.0
    springAnimation.stiffness = 900.0
    springAnimation.damping = damping
    springAnimation.initialVelocity = initialVelocity
    springAnimation.duration = springAnimation.settlingDuration
    springAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
    return springAnimation;
}


public extension CALayer {
    
    func makeAnimation(from: AnyObject, to: AnyObject, keyPath: String, timingFunction: CAMediaTimingFunctionName, duration: Double, delay: Double = 0.0, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) -> CAAnimation {
        if timingFunction == .spring {
                let animation = makeSpringAnimation(keyPath)
                animation.fromValue = from
                animation.toValue = to
                animation.isRemovedOnCompletion = removeOnCompletion
                animation.fillMode = .forwards
                if let completion = completion {
                    animation.delegate = CALayerAnimationDelegate(completion: completion)
                }
                
                let k = Float(NSView.animationDurationFactor())
                var speed: Float = 1.0
                if k != 0 && k != 1 {
                    speed = Float(1.0) / k
                }
                
                animation.speed = speed * Float(animation.duration / duration)
                animation.isAdditive = additive
                
                if !delay.isZero {
                    animation.beginTime = CACurrentMediaTime() + delay * NSView.animationDurationFactor()
                    animation.fillMode = .both
                }
                
                return animation
            } else {
                let k = Float(NSView.animationDurationFactor())
                var speed: Float = 1.0
                if k != 0 && k != 1 {
                    speed = Float(1.0) / k
                }
                
                let animation = CABasicAnimation(keyPath: keyPath)
                animation.fromValue = from
                animation.toValue = to
                animation.duration = duration
                if let mediaTimingFunction = mediaTimingFunction {
                    animation.timingFunction = mediaTimingFunction
                } else {
                    animation.timingFunction = CAMediaTimingFunction(name: timingFunction)
                }
                animation.isRemovedOnCompletion = removeOnCompletion
                animation.fillMode = .forwards
                animation.speed = speed
                animation.isAdditive = additive
                if let completion = completion {
                    animation.delegate = CALayerAnimationDelegate(completion: completion)
                }
                
                if !delay.isZero {
                    animation.beginTime = CACurrentMediaTime() + delay * NSView.animationDurationFactor()
                    animation.fillMode = .both
                }
                
                return animation
            }
        }

    
    func animate(from: AnyObject, to: AnyObject, keyPath: String, timingFunction: CAMediaTimingFunctionName, duration: Double, delay: Double = 0, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil, forKey: String? = nil) {
        if timingFunction == CAMediaTimingFunctionName.spring {
            let animation = makeSpringAnimation(keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.isRemovedOnCompletion = removeOnCompletion
            animation.fillMode = CAMediaTimingFillMode.forwards
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(completion: completion)
            }
            
            let k = Float(1.0)
            var speed: Float = 1.0
            if k != 0 && k != 1 {
                speed = Float(1.0) / k
            }
            
            animation.speed = speed * Float(animation.duration / duration)
            animation.isAdditive = additive
            if !delay.isZero {
                animation.beginTime = CACurrentMediaTime() + delay * NSView.animationDurationFactor()
                animation.fillMode = .both
            }
            self.add(animation, forKey: keyPath)
        } else {
            let k = Float(1.0)
            var speed: Float = 1.0
            if k != 0 && k != 1 {
                speed = Float(1.0) / k
            }
            
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: timingFunction)
            animation.isRemovedOnCompletion = removeOnCompletion
            animation.fillMode = .forwards
            animation.speed = speed
            animation.isAdditive = additive
            if !delay.isZero {
                animation.beginTime = CACurrentMediaTime() + delay * NSView.animationDurationFactor()
                animation.fillMode = .both
            }
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(completion: completion)
            }
            
            self.add(animation, forKey: forKey ?? keyPath)
        }
    }
    
    func animateAdditive(from: NSValue, to: NSValue, keyPath: String, key: String, timingFunction: CAMediaTimingFunctionName, duration: Double, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        let k = Float(1.0)
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        animation.speed = speed
        animation.isAdditive = true
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        self.add(animation, forKey: key)
    }
    
    func animateScaleSpring(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0, initialVelocity: CGFloat = 0.0, removeOnCompletion: Bool = true, additive: Bool = false, bounce: Bool = true, center: Bool = true, completion: ((Bool) -> Void)? = nil) {
        let animation = bounce ? makeSpringBounceAnimation("transform", initialVelocity) : makeSpringAnimation("transform")
        
        var fr = CATransform3DIdentity
        if center {
            fr = CATransform3DTranslate(fr, floorToScreenPixels(System.backingScale, frame.width / 2), floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        }
        fr = CATransform3DScale(fr, from, from, 1)
        if center {
            fr = CATransform3DTranslate(fr, -floorToScreenPixels(System.backingScale, frame.width / 2), -floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        }
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let speed: Float = 1.0
        
        if !delay.isZero {
            animation.beginTime = CACurrentMediaTime() + delay * NSView.animationDurationFactor()
            animation.fillMode = .both
        }
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        if center {
            tr = CATransform3DTranslate(tr, floorToScreenPixels(System.backingScale, frame.width / 2), floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        }
        tr = CATransform3DScale(tr, to, to, 1)
        if center {
            tr = CATransform3DTranslate(tr, -floorToScreenPixels(System.backingScale, frame.width / 2), -floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        }
        animation.toValue = NSValue(caTransform3D: tr)

        
        self.add(animation, forKey: "transform")
    }
    
    func animateScaleSpringFrom(anchor: NSPoint, from: CGFloat, to: CGFloat, duration: Double, initialVelocity: CGFloat = 0.0, removeOnCompletion: Bool = true, additive: Bool = false, bounce: Bool = true, completion: ((Bool) -> Void)? = nil) {
        let animation = bounce ? makeSpringBounceAnimation("transform", initialVelocity) : makeSpringAnimation("transform")
        
        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, anchor.x, anchor.y, 0)
        fr = CATransform3DScale(fr, from, from, 1)
        fr = CATransform3DTranslate(fr, -anchor.x, -anchor.y, 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let speed: Float = 1.0
        
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, anchor.x, anchor.y, 0)
        tr = CATransform3DScale(tr, to, to, 1)
        tr = CATransform3DTranslate(tr, -anchor.x, -anchor.y, 0)
        animation.toValue = NSValue(caTransform3D: tr)

        
        self.add(animation, forKey: "transform")
    }
    
    func animateScaleSpringFromX(anchor: NSPoint, from: CGFloat, to: CGFloat, duration: Double, initialVelocity: CGFloat = 0.0, removeOnCompletion: Bool = true, additive: Bool = false, bounce: Bool = true, completion: ((Bool) -> Void)? = nil) {
        let animation = bounce ? makeSpringBounceAnimation("transform.scale.x", initialVelocity) : makeSpringAnimation("transform.scale.x")
        
        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, anchor.x, anchor.y, 0)
        fr = CATransform3DScale(fr, from, 1, 1)
        fr = CATransform3DTranslate(fr, -anchor.x, -anchor.y, 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let speed: Float = 1.0
        
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, anchor.x, anchor.y, 0)
        tr = CATransform3DScale(tr, to, 1, 1)
        tr = CATransform3DTranslate(tr, -anchor.x, -anchor.y, 0)
        animation.toValue = NSValue(caTransform3D: tr)

        self.add(animation, forKey: "transform.scale.x")
    }

    func animateScaleSpringFromY(anchor: NSPoint, from: CGFloat, to: CGFloat, duration: Double, initialVelocity: CGFloat = 0.0, removeOnCompletion: Bool = true, additive: Bool = false, bounce: Bool = true, completion: ((Bool) -> Void)? = nil) {
        let animation = bounce ? makeSpringBounceAnimation("transform.scale.y", initialVelocity) : makeSpringAnimation("transform.scale.y")
        
        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, anchor.x, anchor.y, 0)
        fr = CATransform3DScale(fr, 1, from, 1)
        fr = CATransform3DTranslate(fr, -anchor.x, -anchor.y, 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let speed: Float = 1.0
        
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, anchor.x, anchor.y, 0)
        tr = CATransform3DScale(tr, 1, to, 1)
        tr = CATransform3DTranslate(tr, -anchor.x, -anchor.y, 0)
        animation.toValue = NSValue(caTransform3D: tr)

        
        self.add(animation, forKey: "transform.scale.y")
    }

    
    
    func animateScaleAnchor(anchor: NSPoint, from: CGFloat, to: CGFloat, duration: Double, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)

        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, anchor.x, anchor.y, 0)
        fr = CATransform3DScale(fr, from, from, 1)
        fr = CATransform3DTranslate(fr, -anchor.x, -anchor.y, 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let speed: Float = 1.0
        
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, anchor.x, anchor.y, 0)
        tr = CATransform3DScale(tr, to, to, 1)
        tr = CATransform3DTranslate(tr, -anchor.x, -anchor.y, 0)
        animation.toValue = NSValue(caTransform3D: tr)

        
        self.add(animation, forKey: "transform")
    }


    
    func animateScaleCenter(from: CGFloat, to: CGFloat, duration: Double, removeOnCompletion: Bool = true, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)

        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, floorToScreenPixels(System.backingScale, frame.width / 2), floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        fr = CATransform3DScale(fr, from, from, 1)
        fr = CATransform3DTranslate(fr, -floorToScreenPixels(System.backingScale, frame.width / 2), -floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        
        
        animation.duration = duration
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, floorToScreenPixels(System.backingScale, frame.width / 2), floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        tr = CATransform3DScale(tr, to, to, 1)
        tr = CATransform3DTranslate(tr, -floorToScreenPixels(System.backingScale, frame.width / 2), -floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        animation.toValue = NSValue(caTransform3D: tr)
        
        
        self.add(animation, forKey: "transform")
    }
    
    func animateScaleCenter(fromX: CGFloat, fromY: CGFloat, to: CGFloat, anchor: NSPoint, duration: Double, removeOnCompletion: Bool = true, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)

        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, anchor.x, anchor.y, 0)
        fr = CATransform3DScale(fr, fromX, fromY, 1)
        fr = CATransform3DTranslate(fr, -anchor.x, -anchor.y, 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        
        
        animation.duration = duration
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, anchor.x, anchor.y, 0)
        tr = CATransform3DScale(tr, to, to, 1)
        fr = CATransform3DTranslate(fr, -anchor.x, -anchor.y, 0)
        animation.toValue = NSValue(caTransform3D: tr)
        
        
        self.add(animation, forKey: "transform")
    }

    
    func animateScaleXCenter(from: CGFloat, to: CGFloat, duration: Double, removeOnCompletion: Bool = true, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)

        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, frame.width / 2, 0, 0)
        fr = CATransform3DScale(fr, from, from, 1)
        fr = CATransform3DTranslate(fr, -frame.width / 2, 0, 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        
        
        animation.duration = duration
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, frame.width / 2, 0, 0)
        tr = CATransform3DScale(tr, to, to, 1)
        tr = CATransform3DTranslate(tr, -frame.width / 2, 0, 0)
        animation.toValue = NSValue(caTransform3D: tr)
        
        
        self.add(animation, forKey: "transform")
    }
    
    func animateScaleYCenter(from: CGFloat, to: CGFloat, duration: Double, removeOnCompletion: Bool = true, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)

        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, 0, frame.height / 2, 0)
        fr = CATransform3DScale(fr, from, from, 1)
        fr = CATransform3DTranslate(fr, 0, -frame.height / 2, 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        
        
        animation.duration = duration
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, 0, frame.height / 2, 0)
        tr = CATransform3DScale(tr, to, to, 1)
        tr = CATransform3DTranslate(tr, 0, -frame.height / 2, 0)
        animation.toValue = NSValue(caTransform3D: tr)
        
        
        self.add(animation, forKey: "transform")
    }

    
    func animateRotateCenter(from: CGFloat, to: CGFloat, duration: Double, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        
        
        let animation = makeSpringAnimation("transform")
        
        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, floorToScreenPixels(System.backingScale, frame.width / 2), floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        fr = CATransform3DRotate(fr, from * CGFloat.pi / 180, 0, 0, 1.0)
        fr = CATransform3DTranslate(fr, -floorToScreenPixels(System.backingScale, frame.width / 2), -floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)

        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let speed: Float = 1.0
        
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, floorToScreenPixels(System.backingScale, frame.width / 2), floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        tr = CATransform3DRotate(fr, to * CGFloat.pi / 180, 0, 0, 1.0)
        tr = CATransform3DTranslate(tr, -floorToScreenPixels(System.backingScale, frame.width / 2), -floorToScreenPixels(System.backingScale, frame.height / 2), 0)
        animation.toValue = NSValue(caTransform3D: tr)
        
        
        self.add(animation, forKey: "transform")
        
//        let animation = CABasicAnimation(keyPath: "transform")
//        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
//        var fr = CATransform3DIdentity
//        fr = CATransform3DTranslate(fr, floorToScreenPixels(backingScaleFactor, frame.width / 2), floorToScreenPixels(backingScaleFactor, frame.height / 2), 0)
//        fr = CATransform3DRotate(fr, from * CGFloat.pi / 180, 0, 0, 1.0)
//        fr = CATransform3DTranslate(fr, -floorToScreenPixels(backingScaleFactor, frame.width / 2), -floorToScreenPixels(backingScaleFactor, frame.height / 2), 0)
//        
//        animation.fromValue = NSValue(caTransform3D: fr)
//        animation.isRemovedOnCompletion = removeOnCompletion
//       // animation.fillMode = kCAFillModeForwards
//        if let completion = completion {
//            animation.delegate = CALayerAnimationDelegate(completion: completion)
//        }
//        
//        let speed: Float = 1.0
//        
//        
//        animation.speed = speed * Float(animation.duration / duration)
//        animation.isAdditive = additive
//        
//        var tr = CATransform3DIdentity
//       // tr = CATransform3DTranslate(tr, floorToScreenPixels(backingScaleFactor, frame.width / 2), floorToScreenPixels(backingScaleFactor, frame.height / 2), 0)
//        tr = CATransform3DRotate(fr, to * CGFloat.pi / 180, 0, 0, 1.0)
//        //tr = CATransform3DTranslate(tr, -floorToScreenPixels(backingScaleFactor, frame.width / 2), -floorToScreenPixels(backingScaleFactor, frame.height / 2), 0)
//        animation.toValue = NSValue(caTransform3D: tr)
//        
//        
//        self.add(animation, forKey: "transform")
    }

    
    func animateAlpha(from: CGFloat, to: CGFloat, duration: Double, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "opacity", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animateSpring(from: AnyObject, to: AnyObject, keyPath: String, duration: Double, initialVelocity: CGFloat = 0.0, damping: CGFloat = 88.0, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let animation: CABasicAnimation
        if #available(iOS 9.0, *) {
            animation = makeSpringBounceAnimation(keyPath, initialVelocity, damping)
        } else {
            animation = makeSpringAnimation(keyPath)
        }
        animation.fromValue = from
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let k = Float(1)
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        self.add(animation, forKey: keyPath)
    }
    
    func animateScale(from: CGFloat, to: CGFloat, duration: Double, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeInEaseOut, delay: Double = 0, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "transform.scale", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animateScaleX(from: CGFloat, to: CGFloat, duration: Double, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeInEaseOut, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "transform.scale.x", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animateScaleY(from: CGFloat, to: CGFloat, duration: Double, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeInEaseOut, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "transform.scale.y", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animatePosition(from: NSPoint, to: NSPoint, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            if let completion = completion {
                completion(true)
            }
            return
        }
        self.animate(from: NSValue(point: from), to: NSValue(point: to), keyPath: "position", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
    }
    
    func animateBounds(from: NSRect, to: NSRect, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, removeOnCompletion: Bool = true, additive: Bool = false, forKey: String? = nil, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            if let completion = completion {
                completion(true)
            }
            return
        }
        self.animate(from: NSValue(rect: from), to: NSValue(rect: to), keyPath: "bounds", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion, forKey: forKey)
    }
    
    func animateBoundsOriginYAdditive(from: CGFloat, to: CGFloat, duration: Double, completion: ((Bool) -> Void)? = nil) {
        self.animateAdditive(from: from as NSNumber, to: to as NSNumber, keyPath: "bounds.origin.y", key: "boundsOriginYAdditive", timingFunction: CAMediaTimingFunctionName.easeOut, duration: duration, removeOnCompletion: true, completion: completion)
    }
    
    func animateFrame(from: CGRect, to: CGRect, duration: Double, timingFunction: CAMediaTimingFunctionName, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            if let completion = completion {
                completion(true)
            }
            return
        }
        self.animatePosition(from: CGPoint(x: from.midX, y: from.midY), to: CGPoint(x: to.midX, y: to.midY), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: nil)
        self.animateBounds(from: CGRect(origin: self.bounds.origin, size: from.size), to: CGRect(origin: self.bounds.origin, size: to.size), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
    }
    
    func shake(_ duration:CFTimeInterval, from:NSPoint, to:NSPoint) {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = duration;
        animation.repeatCount = 4
        animation.autoreverses = true
        animation.isRemovedOnCompletion = true
        
        animation.fromValue = NSValue(point: from)
        animation.toValue = NSValue(point: to)
        
        self.add(animation, forKey: "position")
    }
    
    func animateKeyframes(values: [AnyObject], duration: Double, keyPath: String, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let k = Float(1)
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        var keyTimes: [NSNumber] = []
        for i in 0 ..< values.count {
            if i == 0 {
                keyTimes.append(0.0)
            } else if i == values.count - 1 {
                keyTimes.append(1.0)
            } else {
                keyTimes.append((Double(i) / Double(values.count - 1)) as NSNumber)
            }
        }
        animation.keyTimes = keyTimes
        animation.speed = speed
        animation.duration = duration
        animation.isAdditive = additive
        if let mediaTimingFunction = mediaTimingFunction {
            animation.timingFunction = mediaTimingFunction
        } else {
            animation.timingFunction = CAMediaTimingFunction(name: timingFunction)
        }
        animation.isRemovedOnCompletion = removeOnCompletion
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
//        adjustFrameRate(animation: animation)
        
        self.add(animation, forKey: keyPath)
    }

    
    
    /*
     + (CAAnimation *)shakeWithDuration:(float)duration fromValue:(CGPoint)fromValue toValue:(CGPoint)toValue {
     CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
     animation.duration = duration;
     animation.repeatCount = 4;
     animation.autoreverses = YES;
     animation.removedOnCompletion = YES;
     NSValue *fromValueValue = [NSValue value:&fromValue withObjCType:@encode(CGPoint)];
     NSValue *toValueValue = [NSValue value:&toValue withObjCType:@encode(CGPoint)];
     
     animation.fromValue = fromValueValue;
     animation.toValue = toValueValue;
     return animation;
     }
 */
}


struct ViewportItemSpring {
    let stiffness: CGFloat
    let damping: CGFloat
    let mass: CGFloat
    var velocity: CGFloat = 0.0
    
    init(stiffness: CGFloat, damping: CGFloat, mass: CGFloat) {
        self.stiffness = stiffness
        self.damping = damping
        self.mass = mass
    }
}

private func a(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 1.0 - 3.0 * a2 + 3.0 * a1
}

private func b(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 3.0 * a2 - 6.0 * a1
}

private func c(_ a1: CGFloat) -> CGFloat
{
    return 3.0 * a1
}

private func calcBezier(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return ((a(a1, a2)*t + b(a1, a2))*t + c(a1)) * t
}

private func calcSlope(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 3.0 * a(a1, a2) * t * t + 2.0 * b(a1, a2) * t + c(a1)
}

private func getTForX(_ x: CGFloat, _ x1: CGFloat, _ x2: CGFloat) -> CGFloat {
    var t = x
    var i = 0
    while i < 4 {
        let currentSlope = calcSlope(t, x1, x2)
        if currentSlope == 0.0 {
            return t
        } else {
            let currentX = calcBezier(t, x1, x2) - x
            t -= currentX / currentSlope
        }
        
        i += 1
    }
    
    return t
}

public func bezierPoint(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat) -> CGFloat
{
    var value = calcBezier(getTForX(x, x1, x2), y1, y2)
    if value >= 0.997 {
        value = 1.0
    }
    return value
}
