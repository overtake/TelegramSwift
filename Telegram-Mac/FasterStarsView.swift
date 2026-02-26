//
//  FasterStarsView.swift
//  Telegram
//
//  Created by Mike Renoir on 14.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SceneKit

final class FasterStarsView: NSView, PremiumDecorationProtocol {
    private let sceneView: SCNView
    
    private var particles: SCNNode?
    
    override init(frame: CGRect) {
        self.sceneView = SCNView(frame: CGRect(origin: .zero, size: frame.size))
        self.sceneView.backgroundColor = .clear
        if let url = Bundle.main.url(forResource: "lightspeed", withExtension: "scn") {
            self.sceneView.scene = try? SCNScene(url: url, options: nil)
        }
        
        super.init(frame: frame)
        wantsLayer = true
        self.layer?.opacity = 0.0
        
        self.addSubview(self.sceneView)
        
        self.particles = self.sceneView.scene?.rootNode.childNode(withName: "particles", recursively: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.particles = nil
    }
    
    func setVisible(_ visible: Bool) {
        if visible, let particles = self.particles, particles.parent == nil {
            self.sceneView.scene?.rootNode.addChildNode(particles)
        }

        self._change(opacity: visible ? 0.4 : 0.0, animated: true, completion: { [weak self] finished in
            if let strongSelf = self, finished && !visible && strongSelf.particles?.parent != nil {
                strongSelf.particles?.removeFromParentNode()
            }
        })
    }
    
    private var playing = false
    func startAnimation() {
        guard !self.playing, let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "particles", recursively: false), let particles = node.particleSystems?.first else {
            return
        }
        self.playing = true
        
        let speedAnimation = CABasicAnimation(keyPath: "speedFactor")
        speedAnimation.fromValue = 1.0
        speedAnimation.toValue = 1.8
        speedAnimation.duration = 0.8
        speedAnimation.fillMode = .forwards
        particles.addAnimation(speedAnimation, forKey: "speedFactor")
        
        particles.speedFactor = 3.0
        
        let stretchAnimation = CABasicAnimation(keyPath: "stretchFactor")
        stretchAnimation.fromValue = 0.05
        stretchAnimation.toValue = 0.3
        stretchAnimation.duration = 0.8
        stretchAnimation.fillMode = .forwards
        particles.addAnimation(stretchAnimation, forKey: "stretchFactor")
        
        particles.stretchFactor = 0.3
    }
    
    func resetAnimation() {
        guard self.playing, let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "particles", recursively: false), let particles = node.particleSystems?.first else {
            return
        }
        self.playing = false
        
        let speedAnimation = CABasicAnimation(keyPath: "speedFactor")
        speedAnimation.fromValue = 3.0
        speedAnimation.toValue = 1.0
        speedAnimation.duration = 0.35
        speedAnimation.fillMode = .forwards
        particles.addAnimation(speedAnimation, forKey: "speedFactor")
        
        particles.speedFactor = 1.0
        
        let stretchAnimation = CABasicAnimation(keyPath: "stretchFactor")
        stretchAnimation.fromValue = 0.3
        stretchAnimation.toValue = 0.05
        stretchAnimation.duration = 0.35
        stretchAnimation.fillMode = .forwards
        particles.addAnimation(stretchAnimation, forKey: "stretchFactor")
        
        particles.stretchFactor = 0.05
    }
    
    override func layout() {
        super.layout()
        self.sceneView.frame = CGRect(origin: .zero, size: frame.size)
    }
    
}

