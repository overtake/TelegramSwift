//
//  TitledBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TitledBarView: BarView {
    
    public var text:NSAttributedString? {
        didSet {
            if text != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    public var status:NSAttributedString? {
        didSet {
            if status != oldValue {
                self.setNeedsDisplay()
            }
        }
    }

    override open func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let text = text {
            let (textLayout, textApply) = TextNode.layoutText(nil)(text, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - 50, NSHeight(layer.bounds)), nil,false)
            
            var tY = NSMinY(focus(textLayout.size))
            
            if let status = status {
                
                let (statusLayout, statusApply) = TextNode.layoutText(nil)(status, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - 50, NSHeight(layer.bounds)), nil,false)
                
                let t = textLayout.size.height + statusLayout.size.height + 2.0
                tY = (NSHeight(self.frame) - t) / 2.0
                
                let sY = tY + textLayout.size.height + 2.0
                
                statusApply().draw(NSMakeRect(round((NSWidth(layer.bounds) - statusLayout.size.width)/2.0), sY, statusLayout.size.width, statusLayout.size.height), in: ctx)
            }
            
            textApply().draw(NSMakeRect(round((NSWidth(layer.bounds) - textLayout.size.width)/2.0), tY, textLayout.size.width, textLayout.size.height), in: ctx)
        }
        
    }
    
    public init(_ text:NSAttributedString?) {
        self.text = text
        super.init()
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
