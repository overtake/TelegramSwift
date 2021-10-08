//
//  VisualEffectView.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 27.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation


open class VisualEffect: NSVisualEffectView {
    private let overlay: CALayer = CALayer()
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    public init() {
        super.init(frame: .zero)
        setup()
    }
    
    public var bgColor: NSColor = NSColor.black.withAlphaComponent(0.2) {
        didSet {
            overlay.backgroundColor = bgColor.cgColor
        }
    }
    
    
    func setup() {
        self.wantsLayer = true
        self.blendingMode = .withinWindow
        self.state = .active
        self.bgColor = NSColor.black.withAlphaComponent(0.2)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.overlay.frame = bounds
        CATransaction.commit()
        layer?.addSublayer(self.overlay)
    }
    
    
    open override func updateLayer() {
        super.updateLayer()
        
        if #available(macOS 10.13, *) {
            guard let backdrop = self.layer?.sublayers?.first else {
                return
            }
            let sublayers = backdrop.sublayers ?? []
            for layer in sublayers {
                if layer.name != "backdrop" && layer.name != "Backdrop" {
                    layer.removeFromSuperlayer()
                }
            }
            let allowedKeys: [String] = [
                                    "colorSaturate",
                                    "gaussianBlur"
                                ]

            sublayers.first?.filters = sublayers.first?.filters?.filter { filter in
                guard let filter = filter as? NSObject else {
                    return true
                }
                let filterName = String(describing: filter)
                if !allowedKeys.contains(filterName) {
                    return false
                }
                return true
            }
            for sublayer in sublayers {
                sublayer.backgroundColor = nil
                sublayer.isOpaque = false
            }
        }
    }
    
    public func change(size: NSSize, animated: Bool, _ save: Bool = true, removeOnCompletion: Bool = true, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = .easeOut, completion: ((Bool) -> Void)? = nil) {
        
        self._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        
        
        func animate(_ layer: CALayer, main: Bool) -> Void {
            if animated {
                var presentBounds:NSRect = layer.bounds
                let presentation = layer.presentation()
                if let presentation = presentation, layer.animation(forKey:"bounds") != nil {
                    presentBounds.size.width = NSWidth(presentation.bounds)
                    presentBounds.size.height = NSHeight(presentation.bounds)
                }
                layer.animateBounds(from: presentBounds, to: NSMakeRect(0, 0, size.width, size.height), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, completion: main ? completion : nil)
            } else {
                layer.removeAnimation(forKey: "bounds")
            }
        }
        
        guard let backdrop = self.layer?.sublayers?.first else {
            return
        }
        animate(backdrop, main: true)
        
        let sublayers = backdrop.sublayers ?? []
        for layer in sublayers {
            animate(layer, main: false)
        }
        if animated {
            animate(overlay, main: false)
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.overlay.frame = bounds
            CATransaction.commit()
        }
    }
    
    open override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.overlay.frame = bounds
        CATransaction.commit()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
