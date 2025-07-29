//
//  PremiumDiamondSceneView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26.06.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//

import Cocoa
import SceneKit
import SwiftSignalKit
import TGUIKit

private let sceneVersion: Int = 2



final class PremiumDiamondSceneView: View, SCNSceneRendererDelegate, PremiumSceneView {
    
    private let sceneView: SCNView
    private let diamondView = View()
    #if arch(arm64)
    private let diamondLayer: DiamondLayer
    #else
    private let diamondFallbackView: MediaAnimatedStickerView
    #endif
    private let appearanceDelay = MetaDisposable()
    
    private var didSetReady = false
    
    deinit {
        appearanceDelay.dispose()
    }
    
    var sceneBackground: NSColor = .clear {
        didSet {
            sceneView.backgroundColor = sceneBackground
        }
    }
    
    required init(frame: CGRect) {
        self.sceneView = SCNView(frame: frame)
        self.sceneView.backgroundColor = .clear
        self.sceneView.wantsLayer = true
        self.sceneView.layer?.masksToBounds = false
        self.sceneView.preferredFramesPerSecond = 60
        self.sceneView.isJitteringEnabled = true
        
        #if arch(arm64)
        self.diamondLayer = DiamondLayer()
        #else
        self.diamondFallbackView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 120, 120))
        #endif
        
        super.init(frame: frame)
        
        
        self.layout()
        
        self.addSubview(sceneView)
        self.addSubview(diamondView)
//        self.layer?.addSublayer(testLayer)
        
#if arch(arm64)
        diamondView.layer?.addSublayer(diamondLayer)
#else
        diamondView.addSubview(diamondFallbackView)
#endif
        
        
        
        self.setup()
        
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.addGestureRecognizer(panGesture)
        
        let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tapGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        guard let url = Bundle.main.url(forResource: "diamond", withExtension: "scn") else { return }
        guard let scene = try? SCNScene(url: url, options: nil) else { return }
        
        self.sceneView.scene = scene
        self.sceneView.delegate = self
    }
    
    func initFallbackView(context: AccountContext) {
        #if arch(x86_64)
        diamondFallbackView.update(with: LocalAnimatedSticker.diamond.file, size: NSMakeSize(120, 120), context: context, table: nil, animated: false)
        #endif
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if !didSetReady {
            didSetReady = true
            onReady()
        }
    }
    
    private func onReady() {
        setupScaleAnimation()
        playAppearanceAnimation(explode: true)
    }
    
    private func setupScaleAnimation() {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.duration = 2.0
        animation.fromValue = 0.9
        animation.toValue = 1.0
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.autoreverses = true
        animation.repeatCount = .infinity
        #if arch(arm64)
        self.diamondLayer.add(animation, forKey: "scale")
        #endif
    }
    
    private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
        guard let scene = self.sceneView.scene,
              let swirlNode = scene.rootNode.childNode(withName: "swirl", recursively: false),
              let leftParticles = scene.rootNode.childNode(withName: "particles_left", recursively: false),
              let rightParticles = scene.rootNode.childNode(withName: "particles_right", recursively: false),
              let leftBottomParticles = scene.rootNode.childNode(withName: "particles_left_bottom", recursively: false),
              let rightBottomParticles = scene.rootNode.childNode(withName: "particles_right_bottom", recursively: false) else {
            return
        }
        
        if explode {
            if let left = leftParticles.particleSystems?.first,
               let right = rightParticles.particleSystems?.first,
               let leftBottom = leftBottomParticles.particleSystems?.first,
               let rightBottom = rightBottomParticles.particleSystems?.first {
                
                left.speedFactor = 2.0
                left.particleVelocity = 1.6
                left.birthRate = 60.0
                left.particleLifeSpan = 4.0
                
                right.speedFactor = 2.0
                right.particleVelocity = 1.6
                right.birthRate = 60.0
                right.particleLifeSpan = 4.0
                
                leftBottom.particleVelocity = 1.6
                leftBottom.birthRate = 24.0
                leftBottom.particleLifeSpan = 7.0
                
                rightBottom.particleVelocity = 1.6
                rightBottom.birthRate = 24.0
                rightBottom.particleLifeSpan = 7.0
                
                swirlNode.physicsField?.isActive = true
                
                appearanceDelay.set(delaySignal(1.0).start(completed: {
                    swirlNode.physicsField?.isActive = false
                    
                    left.birthRate = 15.0
                    left.particleVelocity = 1.0
                    left.particleLifeSpan = 3.0
                    
                    right.birthRate = 15.0
                    right.particleVelocity = 1.0
                    right.particleLifeSpan = 3.0
                    
                    leftBottom.particleVelocity = 1.0
                    leftBottom.birthRate = 10.0
                    leftBottom.particleLifeSpan = 5.0
                    
                    rightBottom.particleVelocity = 1.0
                    rightBottom.birthRate = 10.0
                    rightBottom.particleLifeSpan = 5.0
                }))
            }
            
            //self.diamondLayer.playAppearanceAnimation(velocity: velocity, smallAngle: smallAngle, explode: true)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.sceneView.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
        //self.sceneView.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
//        self.diamondLayer.bounds = size.bounds
//        self.diamondLayer.position = NSMakePoint(size.width / 2, 0)
        diamondView.frame = size.bounds
        #if arch(arm64)
        diamondLayer.frame = size.bounds
        #else
        diamondFallbackView.frame = diamondView.focus(NSMakeSize(120, 120))
        #endif
    }
    
    override func layout() {
        super.layout()
        
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func playAgain() {
        self.playAppearanceAnimation(explode: true)
    }
    
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
#if arch(arm64)
        self.diamondLayer.handlePan(gesture)
#endif
    }
    
    @objc private func handleTap(_ gesture: NSClickGestureRecognizer) {
        self.playAppearanceAnimation(explode: true)
    }
    
    override func viewDidMoveToWindow() {
#if arch(arm64)
        self.diamondLayer.isInHierarchy = window != nil
#endif
    }
}
