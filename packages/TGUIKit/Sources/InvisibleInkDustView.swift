//
//  File.swift
//  
//
//  Created by Mike Renoir on 18.01.2022.
//

import Foundation
import AppKit


private func createEmitterBehavior(type: String) -> NSObject {
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
    
    private weak var textView: TextView?
    private let textMaskView: View
    private let textSpotView: ImageView
    
    private var emitterView: View
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
    private let emitterMaskView: View
    private let emitterSpotView: ImageView
    private let emitterMaskFillView: View
        
    public var isRevealed = false
    
    public init(textView: TextView?) {
        self.textView = textView
        
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
        guard self.isRevealed != revealed, let textView = self.textView else {
            return
        }
        
        self.isRevealed = revealed
        
        if revealed {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
            transition.updateAlpha(view: self, alpha: 0.0)
            transition.updateAlpha(view: textView, alpha: 1.0)
        } else {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
            transition.updateAlpha(view: self, alpha: 1.0)
            transition.updateAlpha(view: textView, alpha: 0.0)
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



/*
 @objc private func click(_ event: NSEvent) {
     guard let (_, _, textColor, _, _) = self.currentParams, let textView = self.textView, !self.isRevealed else {
         return
     }
     
     self.isRevealed = true
     
     let position = event.location(in: self.view)
     self.emitterLayer?.setValue(true, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
     self.emitterLayer?.setValue(position, forKeyPath: "emitterBehaviors.fingerAttractor.position")
     
     let maskSize = self.emitterView.frame.size
     Queue.concurrentDefaultQueue().async {
         let textMaskImage = generateMaskImage(size: maskSize, position: position, inverse: false)
         let emitterMaskImage = generateMaskImage(size: maskSize, position: position, inverse: true)
         
         Queue.mainQueue().async {
             self.textSpotView.image = textMaskImage
             self.emitterSpotView.image = emitterMaskImage
         }
     }
        
     Queue.mainQueue().after(0.1 * UIView.animationDurationFactor()) {
         textView.alpha = 1.0
         
         textView.view.mask = self.textMaskView.view
         self.textSpotView.frame = CGRect(x: 0.0, y: 0.0, width: self.emitterMaskView.frame.width * 3.0, height: self.emitterMaskView.frame.height * 3.0)
             
         let xFactor = (position.x / self.emitterView.frame.width - 0.5) * 2.0
         let yFactor = (position.y / self.emitterView.frame.height - 0.5) * 2.0
         let maxFactor = max(abs(xFactor), abs(yFactor))

         var scaleAddition = maxFactor * 4.0
         var durationAddition = -maxFactor * 0.2
         if self.emitterView.frame.height > 0.0, self.emitterView.frame.width / self.emitterView.frame.height < 0.7 {
             scaleAddition *= 5.0
             durationAddition *= 2.0
         }
         
         self.textSpotView.layer.anchorPoint = CGPoint(x: position.x / self.emitterMaskView.frame.width, y: position.y / self.emitterMaskView.frame.height)
         self.textSpotView.position = position
         self.textSpotView.layer.animateScale(from: 0.3333, to: 10.5 + scaleAddition, duration: 0.55 + durationAddition, removeOnCompletion: false, completion: { _ in
             textView.view.mask = nil
         })
         self.textSpotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
         
         self.emitterView.view.mask = self.emitterMaskView.view
         self.emitterSpotView.frame = CGRect(x: 0.0, y: 0.0, width: self.emitterMaskView.frame.width * 3.0, height: self.emitterMaskView.frame.height * 3.0)
         
         self.emitterSpotView.layer.anchorPoint = CGPoint(x: position.x / self.emitterMaskView.frame.width, y: position.y / self.emitterMaskView.frame.height)
         self.emitterSpotView.position = position
         self.emitterSpotView.layer.animateScale(from: 0.3333, to: 10.5 + scaleAddition, duration: 0.55 + durationAddition, removeOnCompletion: false, completion: { [weak self] _ in
             self?.alpha = 0.0
             self?.emitterView.view.mask = nil
             
             self?.emitter?.color = textColor.cgColor
         })
         self.emitterMaskFillView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
     }
     
     Queue.mainQueue().after(0.8 * UIView.animationDurationFactor()) {
         self.emitterLayer?.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
         self.textSpotView.layer.removeAllAnimations()
         
         self.emitterSpotView.layer.removeAllAnimations()
         self.emitterMaskFillView.layer.removeAllAnimations()
     }
     
     var spoilersLength: Int = 0
     if let spoilers = textView.cachedLayout?.spoilers {
         for spoiler in spoilers {
             spoilersLength += spoiler.0.length
         }
     }
     
     let timeToRead = min(45.0, ceil(max(4.0, Double(spoilersLength) * 0.04)))
     Queue.mainQueue().after(timeToRead * UIView.animationDurationFactor()) {
         if let (_, color, _, _, _) = self.currentParams {
             let colorSpace = CGColorSpaceCreateDeviceRGB()
             let animation = POPBasicAnimation()
             animation.property = (POPAnimatableProperty.property(withName: "color", initializer: { property in
                 property?.readBlock = { node, values in
                     if let color = (node as! InvisibleInkDustView).emitter?.color {
                         if let a = color.components {
                             values?[0] = a[0]
                             values?[1] = a[1]
                             values?[2] = a[2]
                             values?[3] = a[3]
                         }
                     }
                 }
                 property?.writeBlock = { node, values in
                     if let values = values, let color = CGColor(colorSpace: colorSpace, components: values) {
                         (node as! InvisibleInkDustView).animColor = color
                         (node as! InvisibleInkDustView).updateEmitter()
                     }
                 }
                 property?.threshold = 0.4
             }) as! POPAnimatableProperty)
             animation.fromValue = self.emitter?.color
             animation.toValue = color
             animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
             animation.duration = 0.1
             animation.completionBlock = { [weak self] _, _ in
                 if let strongSelf = self {
                     strongSelf.animColor = nil
                     strongSelf.updateEmitter()
                 }
             }
             self.pop_add(animation, forKey: "color")
         }
         
         Queue.mainQueue().after(0.15) {
             let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
             transition.updateAlpha(node: self, alpha: 1.0)
             transition.updateAlpha(node: textView, alpha: 0.0, completion: { [weak self] _ in
                 self?.isRevealed = false
             })
         }
     }
 }
 */
