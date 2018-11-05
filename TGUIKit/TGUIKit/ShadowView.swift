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
    public var direction: ShadowDirection = .vertical(true)
    public var shadowBackground: NSColor = .white {
        didSet {
            needsDisplay = true
        }
    }
    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [shadowBackground.withAlphaComponent(0).cgColor, shadowBackground.cgColor]), locations: nil)!
        
        switch direction {
        case .vertical:
            ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: layer.bounds.height), options: CGGradientDrawingOptions())
        case let .horizontal(reversed):
            if reversed {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: layer.bounds.height), end: CGPoint(x: layer.bounds.width, y: layer.bounds.height), options: CGGradientDrawingOptions())
            } else {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: layer.bounds.width, y: layer.bounds.height), end: CGPoint(x: 0, y: layer.bounds.height), options: CGGradientDrawingOptions())
            }
        }
    }
    
}
