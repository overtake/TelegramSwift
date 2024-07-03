//
//  File.swift
//  
//
//  Created by Mike Renoir on 18.01.2022.
//

import Foundation
import AppKit


public func createEmitterBehavior(type: String) -> NSObject {
    let selector = ["behaviorWith", "Type:"].joined(separator: "")
    let behaviorClass = NSClassFromString(["CA", "Emitter", "Behavior"].joined(separator: "")) as! NSObject.Type
    let behaviorWithType = behaviorClass.method(for: NSSelectorFromString(selector))!
    let castedBehaviorWithType = unsafeBitCast(behaviorWithType, to:(@convention(c)(Any?, Selector, Any?) -> NSObject).self)
    return castedBehaviorWithType(behaviorClass, NSSelectorFromString(selector), type)
}

private func generateMaskImage(size originalSize: CGSize, position: CGPoint, inverse: Bool) -> CGImage? {
    var size = originalSize
    var position = position
    var scale: CGFloat = 1.0
    if max(size.width, size.height) > 640.0 {
        size = size.aspectFitted(CGSize(width: 640.0, height: 640.0))
        scale = size.width / originalSize.width
        position = CGPoint(x: position.x * scale, y: position.y * scale)
    }
    return generateImage(size, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
                
        
        let startAlpha: CGFloat = inverse ? 0.0 : 1.0
        let endAlpha: CGFloat = inverse ? 1.0 : 0.0
        
        var locations: [CGFloat] = [0.0, 0.7, 0.95, 1.0]
        let colors: [CGColor] = [NSColor(rgb: 0xffffff, alpha: startAlpha).cgColor, NSColor(rgb: 0xffffff, alpha: startAlpha).cgColor, NSColor(rgb: 0xffffff, alpha: endAlpha).cgColor, NSColor(rgb: 0xffffff, alpha: endAlpha).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        let center = position
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: min(10.0, min(size.width, size.height) * 0.4) * scale, options: .drawsAfterEndLocation)
    })
}

public class InvisibleInkDustView: View {
    private var currentParams: (size: CGSize, color: NSColor, textColor: NSColor, rects: [CGRect], wordRects: [CGRect])?
    private var animColor: CGColor?
    
    private let textMaskView: View
    private let textSpotView: ImageView
    
    private var emitterView: View
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
    private let emitterMaskView: View
    private let emitterSpotView: ImageView
    private let emitterMaskFillView: View
        
    public var isRevealed = false
    
    public override init() {
        
        self.emitterView = View()
        
        self.textMaskView = View()
        self.textSpotView = ImageView()
        
        self.emitterMaskView = View()
        self.emitterSpotView = ImageView()
        
        self.emitterMaskFillView = View()
        self.emitterMaskFillView.backgroundColor = .white
        
        super.init()
        
        self.addSubview(self.emitterView)
        
        self.textMaskView.addSubview(self.textSpotView)
        self.emitterMaskView.addSubview(self.emitterSpotView)
        self.emitterMaskView.addSubview(self.emitterMaskFillView)
        
        initialize()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    private func initialize() {
        
        let emitter = CAEmitterCell()
        emitter.contents = NSImage(named: "textSpeckle_Normal")?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        emitter.contentsScale = 1.8
        emitter.emissionRange = .pi * 2.0
        emitter.lifetime = 1.0
        emitter.scale = 0.5
        emitter.velocityRange = 20.0
        emitter.name = "dustCell"
        emitter.alphaRange = 1.0
        emitter.setValue("point", forKey: "particleType")
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        self.emitter = emitter

        let fingerAttractor = createEmitterBehavior(type: "simpleAttractor")
        fingerAttractor.setValue("fingerAttractor", forKey: "name")
        
        let alphaBehavior = createEmitterBehavior(type: "valueOverLife")
        alphaBehavior.setValue("color.alpha", forKey: "keyPath")
        alphaBehavior.setValue([0.0, 0.0, 1.0, 0.0, -1.0], forKey: "values")
        alphaBehavior.setValue(true, forKey: "additive")
        
        let behaviors = [fingerAttractor, alphaBehavior]
    
        let emitterLayer = CAEmitterLayer()
        emitterLayer.masksToBounds = true
        emitterLayer.allowsGroupOpacity = true
        emitterLayer.lifetime = 1
        emitterLayer.emitterCells = [emitter]
        emitterLayer.emitterPosition = CGPoint(x: 0, y: 0)
        emitterLayer.seed = arc4random()
        emitterLayer.emitterSize = CGSize(width: 1, height: 1)
        emitterLayer.emitterShape = CAEmitterLayerEmitterShape(rawValue: "rectangles")
        emitterLayer.setValue(behaviors, forKey: "emitterBehaviors")
        
        emitterLayer.setValue(4.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
        emitterLayer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        
        self.emitterLayer = emitterLayer
        
        self.emitterView.layer?.addSublayer(emitterLayer)
        
        self.updateEmitter()
        
    }
    
    public func update(revealed: Bool) {
        guard self.isRevealed != revealed else {
            return
        }
        
        self.isRevealed = revealed
        
        if revealed {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
            transition.updateAlpha(view: self, alpha: 0.0)
        } else {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
            transition.updateAlpha(view: self, alpha: 1.0)
        }
    }
    
   
    
    private func updateEmitter() {
        guard let (size, color, _, _, wordRects) = self.currentParams else {
            return
        }
        
        self.emitter?.color = self.animColor ?? color.cgColor
        self.emitterLayer?.setValue(wordRects, forKey: "emitterRects")
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        
        let radius = max(size.width, size.height)
        self.emitterLayer?.setValue(max(size.width, size.height), forKeyPath: "emitterBehaviors.fingerAttractor.radius")
        self.emitterLayer?.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        
        var square: Float = 0.0
        for rect in wordRects {
            square += Float(rect.width * rect.height)
        }
        
        self.emitter?.birthRate = min(100000, square * 0.35)

    }
    
    public func update(size: CGSize, color: NSColor, textColor: NSColor, rects: [CGRect], wordRects: [CGRect]) {
        self.currentParams = (size, color, textColor, rects, wordRects)
                
        self.emitterView.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterMaskView.frame = self.emitterView.bounds
        self.emitterMaskFillView.frame = self.emitterView.bounds
        self.textMaskView.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: size)
        
        self.updateEmitter()

    }
    
    public func point(inside point: CGPoint, with event: NSEvent?) -> Bool {
        if let (_, _, _, rects, _) = self.currentParams, !self.isRevealed {
            for rect in rects {
                if rect.contains(point) {
                    return true
                }
            }
            return false
        } else {
            return false
        }
    }
}












public class MediaDustView: View {
    private var currentParams: (size: CGSize, color: NSColor, textColor: NSColor)?
    private var animColor: CGColor?
    
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
        
    public var isRevealed = false
    
    private let maskLayer = SimpleShapeLayer()
    
    public override init() {
                
        super.init()
        
        initialize()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    private func initialize() {
        
        let emitter = CAEmitterCell()
        emitter.color = NSColor(rgb: 0xffffff, alpha: 0.0).cgColor
        emitter.contents = NSImage(named: "textSpeckle_Normal")?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        emitter.contentsScale = 1.8
        emitter.emissionRange = .pi * 2.0
        emitter.lifetime = 8.0
        emitter.scale = 0.5
        emitter.velocityRange = 0.0
        emitter.name = "dustCell"
        emitter.alphaRange = 1.0
        emitter.setValue("point", forKey: "particleType")
        emitter.setValue(1.0, forKey: "mass")
        emitter.setValue(0.01, forKey: "massRange")
        self.emitter = emitter
        
        let alphaBehavior = createEmitterBehavior(type: "valueOverLife")
        alphaBehavior.setValue("color.alpha", forKey: "keyPath")
        alphaBehavior.setValue([0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1], forKey: "values")
        alphaBehavior.setValue(true, forKey: "additive")
        
        let scaleBehavior = createEmitterBehavior(type: "valueOverLife")
        scaleBehavior.setValue("scale", forKey: "keyPath")
        scaleBehavior.setValue([0.0, 0.5], forKey: "values")
        scaleBehavior.setValue([0.0, 0.05], forKey: "locations")
        
        let randomAttractor0 = createEmitterBehavior(type: "simpleAttractor")
        randomAttractor0.setValue("randomAttractor0", forKey: "name")
        randomAttractor0.setValue(20, forKey: "falloff")
        randomAttractor0.setValue(35, forKey: "radius")
        randomAttractor0.setValue(5, forKey: "stiffness")
        randomAttractor0.setValue(NSValue(point: .zero), forKey: "position")
        
        let randomAttractor1 = createEmitterBehavior(type: "simpleAttractor")
        randomAttractor1.setValue("randomAttractor1", forKey: "name")
        randomAttractor1.setValue(20, forKey: "falloff")
        randomAttractor1.setValue(35, forKey: "radius")
        randomAttractor1.setValue(5, forKey: "stiffness")
        randomAttractor1.setValue(NSValue(point: .zero), forKey: "position")
        
        let fingerAttractor = createEmitterBehavior(type: "simpleAttractor")
        fingerAttractor.setValue("fingerAttractor", forKey: "name")
        
        let behaviors = [randomAttractor0, randomAttractor1, fingerAttractor, alphaBehavior, scaleBehavior]
    
        let emitterLayer = CAEmitterLayer()
        emitterLayer.masksToBounds = true
        emitterLayer.allowsGroupOpacity = true
        emitterLayer.lifetime = 1
        emitterLayer.emitterCells = [emitter]
        emitterLayer.seed = arc4random()
        emitterLayer.emitterShape = .rectangle
        emitterLayer.setValue(behaviors, forKey: "emitterBehaviors")
        
        emitterLayer.setValue(4.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
        emitterLayer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        
        self.emitterLayer = emitterLayer
        
        emitterLayer.mask = maskLayer
        maskLayer.fillRule = .evenOdd

        self.layer?.addSublayer(emitterLayer)
        
        self.updateEmitter()
        
  //      self.setupRandomAnimations()

    }
    
    public func update(revealed: Bool) {
        guard self.isRevealed != revealed else {
            return
        }
        
        self.isRevealed = revealed
        
        if revealed {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
            transition.updateAlpha(view: self, alpha: 0.0)
        } else {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
            transition.updateAlpha(view: self, alpha: 1.0)
        }
    }
    
    private var didSetupAnimations = false
    private func setupRandomAnimations() {
        guard self.frame.width > 0.0, self.emitterLayer != nil, !self.didSetupAnimations else {
            return
        }
        self.didSetupAnimations = true
        
        let falloffAnimation1 = CABasicAnimation(keyPath: "emitterBehaviors.randomAttractor0.falloff")
        falloffAnimation1.beginTime = 0.0
        falloffAnimation1.fillMode = .both
        falloffAnimation1.isRemovedOnCompletion = false
        falloffAnimation1.autoreverses = true
        falloffAnimation1.repeatCount = .infinity
        falloffAnimation1.duration = 2.0
        falloffAnimation1.fromValue = -20.0 as NSNumber
        falloffAnimation1.toValue = 60.0 as NSNumber
        falloffAnimation1.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.emitterLayer?.add(falloffAnimation1, forKey: "emitterBehaviors.randomAttractor0.falloff")

        let positionAnimation1 = CAKeyframeAnimation(keyPath: "emitterBehaviors.randomAttractor0.position")
        positionAnimation1.beginTime = 0.0
        positionAnimation1.fillMode = .both
        positionAnimation1.isRemovedOnCompletion = false
        positionAnimation1.autoreverses = true
        positionAnimation1.repeatCount = .infinity
        positionAnimation1.duration = 3.0
        positionAnimation1.calculationMode = .discrete

        let xInset1: CGFloat = self.frame.width * 0.2
        let yInset1: CGFloat = self.frame.height * 0.2
        var positionValues1: [CGPoint] = []
        for _ in 0 ..< 35 {
            positionValues1.append(CGPoint(x: CGFloat.random(in: xInset1 ..< self.frame.width - xInset1), y: CGFloat.random(in: yInset1 ..< self.frame.height - yInset1)))
        }
        positionAnimation1.values = positionValues1

        self.emitterLayer?.add(positionAnimation1, forKey: "emitterBehaviors.randomAttractor0.position")

        let falloffAnimation2 = CABasicAnimation(keyPath: "emitterBehaviors.randomAttractor1.falloff")
        falloffAnimation2.beginTime = 0.0
        falloffAnimation2.fillMode = .both
        falloffAnimation2.isRemovedOnCompletion = false
        falloffAnimation2.autoreverses = true
        falloffAnimation2.repeatCount = .infinity
        falloffAnimation2.duration = 2.0
        falloffAnimation2.fromValue = -20.0 as NSNumber
        falloffAnimation2.toValue = 60.0 as NSNumber
        falloffAnimation2.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.emitterLayer?.add(falloffAnimation2, forKey: "emitterBehaviors.randomAttractor1.falloff")

        let positionAnimation2 = CAKeyframeAnimation(keyPath: "emitterBehaviors.randomAttractor1.position")
        positionAnimation2.beginTime = 0.0
        positionAnimation2.fillMode = .both
        positionAnimation2.isRemovedOnCompletion = false
        positionAnimation2.autoreverses = true
        positionAnimation2.repeatCount = .infinity
        positionAnimation2.duration = 3.0
        positionAnimation2.calculationMode = .discrete

        let xInset2: CGFloat = self.frame.width * 0.1
        let yInset2: CGFloat = self.frame.height * 0.1
        var positionValues2: [CGPoint] = []
        for _ in 0 ..< 35 {
            positionValues2.append(CGPoint(x: CGFloat.random(in: xInset2 ..< self.frame.width - xInset2), y: CGFloat.random(in: yInset2 ..< self.frame.height - yInset2)))
        }
        positionAnimation2.values = positionValues2

        self.emitterLayer?.add(positionAnimation2, forKey: "emitterBehaviors.randomAttractor1.position")
    }
        

    
    private func updateEmitter() {
        guard let (size, _, _) = self.currentParams else {
            return
        }
        self.maskLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer?.emitterSize = size
        self.emitterLayer?.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        let radius = max(size.width, size.height)
        self.emitterLayer?.setValue(max(size.width, size.height), forKeyPath: "emitterBehaviors.fingerAttractor.radius")
        self.emitterLayer?.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        
        let square = Float(size.width * size.height)
        
        self.emitter?.birthRate = min(100000, square * 0.02)

    }
    
    public func update(size: CGSize, color: NSColor, textColor: NSColor, mask: CGPath) {
        self.currentParams = (size, color, textColor)
        self.maskLayer.path = mask
        self.updateEmitter()
        self.setupRandomAnimations()
    }
    
}
