//
//  BadgeNode.swift
//  TGUIKit
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import AppKit

public class BadgeNode: Node {
    private var textLayout:(TextNodeLayout, TextNode)
    
    public var fillColor:NSColor {
        didSet {
            if fillColor != oldValue {
                self.view?.setNeedsDisplay()
            }
        }
    }
    public var aroundFill:NSColor? {
        didSet {
            if aroundFill != aroundFill {
                self.view?.setNeedsDisplay()
            }
        }
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let view = view {
            ctx.setFillColor(fillColor.cgColor)
            
            let rect = frame.size.bounds
            if let aroundFill = aroundFill {
                let outerPath = CGMutablePath()
                outerPath.addRoundedRect(in: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2)
                outerPath.closeSubpath()
                
                let innerRect = rect.insetBy(dx: 1, dy: 1)
                
                let innerPath = CGMutablePath()
                innerPath.addRoundedRect(in: innerRect, cornerWidth: innerRect.height / 2, cornerHeight: innerRect.height / 2)
                
                ctx.addPath(outerPath)
                ctx.closePath()
                ctx.setFillColor(aroundFill.cgColor)
                ctx.fillPath()

                
                ctx.addPath(innerPath)
                ctx.closePath()
                ctx.setFillColor(fillColor.cgColor)
                ctx.fillPath()
                
            } else {
                ctx.round(self.size, self.size.height/2.0)
                ctx.fill(layer.bounds)
            }
            
            let focus = view.focus(textLayout.0.size)
            textLayout.1.draw(focus, in: ctx, backingScaleFactor: view.backingScaleFactor, backgroundColor: view.backgroundColor)
        }
        
    }
    
    public var additionSize: NSSize = NSMakeSize(8, 7)
    
    public init(_ attributedString:NSAttributedString, _ fillColor:NSColor, aroundFill:NSColor? = nil) {
        textLayout = TextNode.layoutText(maybeNode: nil,  attributedString, nil, 1, .middle, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .left)
        self.fillColor = fillColor
        self.aroundFill = aroundFill
        super.init()
        
        
        size = NSMakeSize(textLayout.0.size.width + additionSize.width, textLayout.0.size.height + additionSize.height)
        size = NSMakeSize(max(size.height,size.width), size.height)
        
    }
    
    
}
