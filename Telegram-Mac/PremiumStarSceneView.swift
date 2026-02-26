//
//  PremiumStartSceneView.swift
//  Telegram
//
//  Created by Mike Renoir on 12.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SceneKit
import SwiftSignalKit
import GZIP

private let sceneVersion: Int = 2



protocol PremiumSceneView {
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
    func playAgain()
    
    var sceneBackground: NSColor { get set }
}

final class PremiumStarSceneView: View, SCNSceneRendererDelegate, PremiumSceneView {
   
    private let sceneView: SCNView
    
    private let tapDelay = MetaDisposable()
    private let appearanceDelay = MetaDisposable()
    
    deinit {
        appearanceDelay.dispose()
        tapDelay.dispose()
    }
    
    var sceneBackground: NSColor = .clear {
        didSet {
            sceneView.backgroundColor = sceneBackground
        }
    }

    required init(frame: CGRect) {
        self.sceneView = SCNView(frame: frame)
        self.sceneView.backgroundColor = .clear
//        self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
//        self.sceneView.isUserInteractionEnabled = false
        
        super.init(frame: frame)
        sceneView.wantsLayer = true
        self.addSubview(self.sceneView)
        self.layer?.masksToBounds = false
        sceneView.layer?.masksToBounds = false
        self.setup()
        
        let panGestureRecoginzer = NSPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        self.addGestureRecognizer(panGestureRecoginzer)
        
        let tapGestureRecoginzer = NSClickGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(tapGestureRecoginzer)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleTap(_ gesture: NSGestureRecognizer) {
        guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
            return
        }
        
        var left = true
        if let view = gesture.view {
            let point = gesture.location(in: view)
            let distanceFromCenter = abs(point.x - view.frame.size.width / 2.0)
            if distanceFromCenter > 60.0 {
                return
            }
            if point.x > view.frame.width / 2.0 {
                left = false
            }
        }
        
        if node.animationKeys.contains("tapRotate") {
            self.playAppearanceAnimation(velocity: nil, mirror: left, explode: true)
            return
        }
        
        let initial = node.rotation
        let target = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: left ? -0.6 : 0.6)
                    
        let animation = CASpringAnimation(keyPath: "rotation")
        animation.fromValue = NSValue(scnVector4: initial)
        animation.toValue = NSValue(scnVector4: target)
        animation.duration = 0.25
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .forwards
        node.addAnimation(animation, forKey: "tapRotate")
        
        node.rotation = target
        
        tapDelay.set(delaySignal(0.25).start(completed: {
            node.rotation = initial
            let springAnimation = CASpringAnimation(keyPath: "rotation")
            springAnimation.fromValue = NSValue(scnVector4: target)
            springAnimation.toValue = NSValue(scnVector4: SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: 0.0))
            springAnimation.mass = 1.0
            springAnimation.stiffness = 21.0
            springAnimation.damping = 5.8
            springAnimation.duration = springAnimation.settlingDuration * 0.8
            node.addAnimation(springAnimation, forKey: "tapRotate")
        }))
//        delay(0.25, closure: {
//
//        })
//
    }
    
    private var previousAngle: Float = 0.0
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
            return
        }
        
        if #available(macOS 10.13, *) {
            node.removeAnimation(forKey: "rotate", blendOutDuration: 0.1)
            node.removeAnimation(forKey: "tapRotate", blendOutDuration: 0.1)
        } else {
            node.removeAllAnimations()
        }
        
        switch gesture.state {
            case .began:
                self.previousAngle = 0.0
            case .changed:
                let translation = gesture.translation(in: gesture.view)
//                let anglePan = deg2rad(Float(translation.x))
                
                let x = Float(translation.x)
                let y = Float(-translation.y)

                let anglePan = sqrt(pow(x,2)+pow(y,2))*(Float)(Float.pi)/180.0

                var rotationVector = SCNVector4()
                rotationVector.x = CGFloat(-y)
                rotationVector.y = CGFloat(x)
                rotationVector.z = 0
                rotationVector.w = CGFloat(anglePan)
            
                self.previousAngle = anglePan
                node.rotation = rotationVector//SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: CGFloat(self.previousAngle))
            case .ended:
            
            if self.previousAngle == 0 {
                handleTap(gesture)
                return;
            }
            let velocity = gesture.velocity(in: gesture.view)
            
            var smallAngle = false
            if (self.previousAngle < .pi / 2 && self.previousAngle > -.pi / 2) && abs(velocity.x) < 200 {
                smallAngle = true
            }
        
            self.playAppearanceAnimation(velocity: velocity.x, smallAngle: smallAngle, explode: !smallAngle && abs(velocity.x) > 600)
            node.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: 0.0)
            default:
                break
        }
    }
    
    private func setup() {
        guard let url = Bundle.main.url(forResource: "star2", withExtension: "scn") else {
            return
        }
        
        guard let scene = try? SCNScene(url: url, options: nil) else {
            return
        }
        
//        self.sceneView.col = .bgra8Unorm_srgb
        self.sceneView.backgroundColor = .clear
        self.sceneView.preferredFramesPerSecond = 60
        self.sceneView.isJitteringEnabled = true

        self.sceneView.scene = scene
        self.sceneView.delegate = self
                
        
    }
    
    private var didSetReady = false
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if !self.didSetReady {
            self.didSetReady = true

            self.onReady()
        }
    }
    
    private func onReady() {
        self.setupGradientAnimation()
        self.setupShineAnimation()
        
        self.playAppearanceAnimation(explode: true)
    }
    
    private func setupGradientAnimation() {
        guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
            return
        }
        guard let initial = node.geometry?.materials.first?.diffuse.contentsTransform else {
            return
        }
        
        let animation = CABasicAnimation(keyPath: "contentsTransform")
        animation.duration = 4.5
        animation.fromValue = NSValue(scnMatrix4: initial)
        animation.toValue = NSValue(scnMatrix4: SCNMatrix4Translate(initial, -0.35, 0.35, 0))
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.autoreverses = true
        animation.repeatCount = .infinity
        
        node.geometry?.materials.first?.diffuse.addAnimation(animation, forKey: "gradient")
    }
    
    private func setupShineAnimation() {
        guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
            return
        }
        guard let initial = node.geometry?.materials.first?.emission.contentsTransform else {
            return
        }
        
        let animation = CABasicAnimation(keyPath: "contentsTransform")
        animation.fillMode = .forwards
        animation.fromValue = NSValue(scnMatrix4: initial)
        animation.toValue = NSValue(scnMatrix4: SCNMatrix4Translate(initial, -1.6, 0.0, 0.0))
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.beginTime = 0.6
        animation.duration = 0.9
        
        let group = CAAnimationGroup()
        group.animations = [animation]
        group.beginTime = 1.0
        group.duration = 3.0
        group.repeatCount = .infinity
        
        node.geometry?.materials.first?.emission.addAnimation(group, forKey: "shimmer")
        
        if #available(macOS 14.0, *), let material = node.geometry?.materials.first {
            material.metalness.intensity = 0.2
        }
    }
    
    func showStar() {
        guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
            return
        }
        node.isHidden = false
    }
    func hideStar() {
        guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
            return
        }
        node.isHidden = true
    }
    
    private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
        guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
            return
        }
        
        
        if explode, let node = scene.rootNode.childNode(withName: "swirl", recursively: false), let particles = scene.rootNode.childNode(withName: "particles", recursively: false) {
            let particleSystem = particles.particleSystems?.first
            particleSystem?.particleColorVariation = SCNVector4(0.15, 0.2, 0.35, 0.3)
            particleSystem?.particleVelocity = 2.2
            particleSystem?.birthRate = 4.5
            particleSystem?.particleLifeSpan = 2.0
            
            node.physicsField?.isActive = true
            appearanceDelay.set(delaySignal(1.0).start(completed: {
                node.physicsField?.isActive = false
                particles.particleSystems?.first?.birthRate = 1.2
                particleSystem?.particleVelocity = 1.65
                particleSystem?.particleLifeSpan = 4.0
            }))
        }
    
        let from = node.presentation.rotation
        node.removeAnimation(forKey: "tapRotate")
        
        var toValue: Float = smallAngle ? 0.0 : .pi * 2.0
        if let velocity = velocity, !smallAngle && abs(velocity) > 200 && velocity < 0.0 {
            toValue *= -1
        }
        if mirror {
            toValue *= -1
        }
        let to = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: CGFloat(toValue))
        let distance = rad2deg(Float(to.w - from.w))
        
        let springAnimation = CASpringAnimation(keyPath: "rotation")
        springAnimation.fromValue = NSValue(scnVector4: from)
        springAnimation.toValue = NSValue(scnVector4: to)
        springAnimation.mass = 1.0
        springAnimation.stiffness = 21.0
        springAnimation.damping = 5.8
        springAnimation.duration = springAnimation.settlingDuration * 0.75
        springAnimation.initialVelocity = velocity.flatMap { abs($0 / CGFloat(distance)) } ?? 1.7
        
        node.addAnimation(springAnimation, forKey: "rotate")
    }
    
    func playAgain() {
        self.playAppearanceAnimation(explode: true)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: size.width * 2.0, height: size.height * 2.0))
//        self.sceneView.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}
