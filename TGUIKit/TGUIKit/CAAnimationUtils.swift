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

private let completionKey = "CAAnimationUtils_completion"

public let kCAMediaTimingFunctionSpring = "CAAnimationUtilsSpringCurve"

public extension CAAnimation {
    public var completion: ((Bool) -> Void)? {
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
    if #available(OSX 10.11, *) {
        let springAnimation:CASpringAnimation = CASpringAnimation(keyPath: path)
        springAnimation.mass = 3.0;
        springAnimation.stiffness = 1000.0;
        springAnimation.damping = 500.0;
        springAnimation.initialVelocity = 0.0;
        springAnimation.duration = 0.5;//springAnimation.settlingDuration;
        springAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        return springAnimation;
    } else {
        let anim:CABasicAnimation = CABasicAnimation(keyPath: path)
        anim.duration = 0.2
        anim.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        
        return anim
    }
   
}

public func makeSpringBounceAnimation(_ path:String, _ initialVelocity:CGFloat, _ damping: CGFloat = 88.0) -> CABasicAnimation {
    if #available(OSX 10.11, *) {
        let springAnimation:CASpringAnimation = CASpringAnimation(keyPath: path)
        springAnimation.mass = 5.0
        springAnimation.stiffness = 900.0
        springAnimation.damping = damping
        springAnimation.initialVelocity = initialVelocity
        springAnimation.duration = springAnimation.settlingDuration
        springAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        return springAnimation;
    } else {
        let anim:CABasicAnimation = CABasicAnimation(keyPath: path)
        anim.duration = 0.2
        anim.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        
        return anim
    }
    
}


public extension CALayer {
    public func animate(from: AnyObject, to: AnyObject, keyPath: String, timingFunction: String, duration: Double, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if timingFunction == kCAMediaTimingFunctionSpring {
            let animation = makeSpringAnimation(keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.isRemovedOnCompletion = removeOnCompletion
            animation.fillMode = kCAFillModeForwards
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
            animation.fillMode = kCAFillModeForwards
            animation.speed = speed
            animation.isAdditive = additive
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(completion: completion)
            }
            
            self.add(animation, forKey: keyPath)
        }
    }
    
    public func animateAdditive(from: NSValue, to: NSValue, keyPath: String, key: String, timingFunction: String, duration: Double, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
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
        animation.fillMode = kCAFillModeForwards
        animation.speed = speed
        animation.isAdditive = true
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        self.add(animation, forKey: key)
    }
    
    public func animateScaleSpring(from: CGFloat, to: CGFloat, duration: Double, initialVelocity: CGFloat = 0.0, removeOnCompletion: Bool = true, additive: Bool = false, bounce: Bool = true, completion: ((Bool) -> Void)? = nil) {
        let animation = bounce ? makeSpringBounceAnimation("transform", initialVelocity) : makeSpringAnimation("transform")
        
        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        fr = CATransform3DScale(fr, from, from, 1)
        fr = CATransform3DTranslate(fr, -floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), -floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = kCAFillModeForwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let speed: Float = 1.0
        
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        tr = CATransform3DScale(tr, to, to, 1)
        tr = CATransform3DTranslate(tr, -floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), -floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        animation.toValue = NSValue(caTransform3D: tr)

        
        self.add(animation, forKey: "transform")
    }
    
    public func animateScaleCenter(from: CGFloat, to: CGFloat, duration: Double, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)

        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        fr = CATransform3DScale(fr, from, from, 1)
        fr = CATransform3DTranslate(fr, -floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), -floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = kCAFillModeForwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        
        
        animation.duration = duration
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        tr = CATransform3DScale(tr, to, to, 1)
        tr = CATransform3DTranslate(tr, -floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), -floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        animation.toValue = NSValue(caTransform3D: tr)
        
        
        self.add(animation, forKey: "transform")
    }
    
    public func animateRotateCenter(from: CGFloat, to: CGFloat, duration: Double, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        
        
        let animation = makeSpringAnimation("transform")
        
        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        fr = CATransform3DRotate(fr, from * CGFloat.pi / 180, 0, 0, 1.0)
        fr = CATransform3DTranslate(fr, -floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), -floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        
        animation.fromValue = NSValue(caTransform3D: fr)

        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = kCAFillModeForwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        let speed: Float = 1.0
        
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        tr = CATransform3DRotate(fr, to * CGFloat.pi / 180, 0, 0, 1.0)
        tr = CATransform3DTranslate(tr, -floorToScreenPixels(scaleFactor: System.backingScale, frame.width / 2), -floorToScreenPixels(scaleFactor: System.backingScale, frame.height / 2), 0)
        animation.toValue = NSValue(caTransform3D: tr)
        
        
        self.add(animation, forKey: "transform")
        
//        let animation = CABasicAnimation(keyPath: "transform")
//        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
//        var fr = CATransform3DIdentity
//        fr = CATransform3DTranslate(fr, floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width / 2), floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2), 0)
//        fr = CATransform3DRotate(fr, from * CGFloat.pi / 180, 0, 0, 1.0)
//        fr = CATransform3DTranslate(fr, -floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width / 2), -floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2), 0)
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
//       // tr = CATransform3DTranslate(tr, floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width / 2), floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2), 0)
//        tr = CATransform3DRotate(fr, to * CGFloat.pi / 180, 0, 0, 1.0)
//        //tr = CATransform3DTranslate(tr, -floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width / 2), -floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2), 0)
//        animation.toValue = NSValue(caTransform3D: tr)
//        
//        
//        self.add(animation, forKey: "transform")
    }

    
    public func animateAlpha(from: CGFloat, to: CGFloat, duration: Double, timingFunction: String = kCAMediaTimingFunctionEaseOut, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "opacity", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    public func animateSpring(from: AnyObject, to: AnyObject, keyPath: String, duration: Double, initialVelocity: CGFloat = 0.0, damping: CGFloat = 88.0, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let animation: CABasicAnimation
        if #available(iOS 9.0, *) {
            animation = makeSpringBounceAnimation(keyPath, initialVelocity, damping)
        } else {
            animation = makeSpringAnimation(keyPath)
        }
        animation.fromValue = from
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = kCAFillModeForwards
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
    
    public func animateScale(from: CGFloat, to: CGFloat, duration: Double, timingFunction: String = kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "transform.scale", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    public func animateScaleX(from: CGFloat, to: CGFloat, duration: Double, timingFunction: String = kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "transform.scale.x", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    public func animateScaleY(from: CGFloat, to: CGFloat, duration: Double, timingFunction: String = kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "transform.scale.y", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animatePosition(from: NSPoint, to: NSPoint, duration: Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            if let completion = completion {
                completion(true)
            }
            return
        }
        self.animate(from: NSValue(point: from), to: NSValue(point: to), keyPath: "position", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
    }
    
    func animateBounds(from: NSRect, to: NSRect, duration: Double, timingFunction: String, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            if let completion = completion {
                completion(true)
            }
            return
        }
        self.animate(from: NSValue(rect: from), to: NSValue(rect: to), keyPath: "bounds", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
    }
    
    public func animateBoundsOriginYAdditive(from: CGFloat, to: CGFloat, duration: Double) {
        self.animateAdditive(from: from as NSNumber, to: to as NSNumber, keyPath: "bounds.origin.y", key: "boundsOriginYAdditive", timingFunction: kCAMediaTimingFunctionEaseOut, duration: duration, removeOnCompletion: true)
    }
    
    public func animateFrame(from: CGRect, to: CGRect, duration: Double, timingFunction: String, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            if let completion = completion {
                completion(true)
            }
            return
        }
        self.animatePosition(from: CGPoint(x: from.midX, y: from.midY), to: CGPoint(x: to.midX, y: to.midY), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: nil)
        self.animateBounds(from: CGRect(origin: self.bounds.origin, size: from.size), to: CGRect(origin: self.bounds.origin, size: to.size), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
    }
    
    public func shake(_ duration:CFTimeInterval, from:NSPoint, to:NSPoint) {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = duration;
        animation.repeatCount = 4
        animation.autoreverses = true
        animation.isRemovedOnCompletion = true
        
        animation.fromValue = NSValue(point: from)
        animation.toValue = NSValue(point: to)
        
        self.add(animation, forKey: "position")
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
