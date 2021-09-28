//
//  VisualEffectView.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 27.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation


open class VisualEffect: NSVisualEffectView {
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    public init() {
        super.init(frame: .zero)
        setup()
    }
    
    func setup() {
        self.wantsLayer = true
        self.blendingMode = .withinWindow
        self.state = .active
    }
    
    open override func updateLayer() {
        super.updateLayer()
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
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
