//
//  ShadowView.swift
//  TGUIKit
//
//  Created by keepcoder on 02/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

public enum ShadowDirection {
    case horizontal(Bool)
    case vertical(Bool)
}
public class ShadowView: View {
    
    
    public override init() {
        super.init(frame: .zero)
        setup()
    }
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var gradient: CAGradientLayer {
        return self.layer as! CAGradientLayer
    }
    
    private func setup() {
        self.layer = CAGradientLayer()
        self.shadowBackground = .white
    }
    
    public var direction: ShadowDirection = .vertical(true) {
        didSet {
            self.update()
        }
    }
    public var shadowBackground: NSColor = .white {
        didSet {
            self.update()
        }
    }
    
    private func update() {
        self.gradient.colors = [shadowBackground.withAlphaComponent(0).cgColor, shadowBackground.cgColor];
//            self.gradient.locations = [0.0, 1.0];

        switch direction {
        case let .vertical(reversed):
            if reversed {
                self.gradient.startPoint = CGPoint(x: 0, y: 0)
                self.gradient.endPoint = CGPoint(x: 0.0, y: 1)
            } else {
                self.gradient.startPoint = CGPoint(x: 0, y: 1)
                self.gradient.endPoint = CGPoint(x: 0.0, y: 0)
            }
        case let .horizontal(reversed):
            if reversed {
                self.gradient.startPoint = CGPoint(x: 0, y: 1)
                self.gradient.endPoint = CGPoint(x: 1, y: 1)
            } else {
                self.gradient.startPoint = CGPoint(x: 1, y: 1)
                self.gradient.endPoint = CGPoint(x: 0, y: 1)
            }
        }
    }
}
