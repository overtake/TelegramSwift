//
//  ShadowView.swift
//  TGUIKit
//
//  Created by keepcoder on 02/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

public class ShadowView: View {
    public var shadowBackground: NSColor = .white {
        didSet {
            needsDisplay = true
        }
    }
    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [shadowBackground.withAlphaComponent(0).cgColor, shadowBackground.cgColor]), locations: nil)!
        
        ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: layer.bounds.height), options: CGGradientDrawingOptions())
    }
    
}
