//
//  File.swift
//  
//
//  Created by Mike Renoir on 22.01.2024.
//

import Foundation
import TGUIKit
import AppKit



public class CallBlobView : LayerBackedView {
    public let blob = CallBlobsLayer()
    private let backgroundLayer = CALayer()
    public var maskLayer = CALayer() {
        didSet {
            oldValue.removeFromSuperlayer()
            self.layer?.addSublayer(maskLayer)
            maskLayer.mask = backgroundLayer
            maskLayer.frame = frame.size.bounds
        }
    }
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        blob.frame = frameRect.size.bounds
        backgroundLayer.frame = frameRect.size.bounds
        maskLayer.frame = frameRect.size.bounds
        self.layer?.addSublayer(maskLayer)
        backgroundLayer.addSublayer(blob)
        maskLayer.mask = backgroundLayer
            
        blob.masksToBounds = false
        blob.isInHierarchy = true
        self.layer?.masksToBounds = false
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateLevel(_ level: CGFloat) {
        self.blob.waveSpeed = Float(level)
        let scale = mapRange(level, inMin: 1, inMax: 1.5, outMin: 1.0, outMax: 1.06)
        self.blob.transform = CATransform3DScale(CATransform3DIdentity, scale, scale, 1)
        self.blob.animateTransform()
        
    }
    
    public func setColor(_ color: NSColor, animated: Bool) {
        self.maskLayer.backgroundColor = color.cgColor
        if animated {
            self.maskLayer.animateBackground()
        }
    }
    public func startAnimating() {
        blob.isInHierarchy = true
    }
    
    public func stopAnimating() {
        blob.isInHierarchy = false
    }
}
