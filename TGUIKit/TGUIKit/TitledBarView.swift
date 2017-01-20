//
//  TitledBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TitledBarView: BarView {
    
    public var titleImage:CGImage?
    
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
            let (textLayout, textApply) = TextNode.layoutText(nil)(text, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - 50, NSHeight(layer.bounds)), nil,false, .left)
            var tY = NSMinY(focus(textLayout.size))
            
            if let status = status {
                
                let (statusLayout, statusApply) = TextNode.layoutText(nil)(status, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - 50, NSHeight(layer.bounds)), nil,false, .left)
                
                let t = textLayout.size.height + statusLayout.size.height + 2.0
                tY = (NSHeight(self.frame) - t) / 2.0
                
                let sY = tY + textLayout.size.height + 2.0
                
                statusApply().draw(NSMakeRect(floorToScreenPixels((layer.bounds.width - statusLayout.size.width)/2.0), sY, statusLayout.size.width, statusLayout.size.height), in: ctx)
            }
            
            var textRect = NSMakeRect(floorToScreenPixels((layer.bounds.width - textLayout.size.width)/2.0), tY, textLayout.size.width, textLayout.size.height)
            
            if let titleImage = titleImage {
                ctx.draw(titleImage, in: NSMakeRect(textRect.minX - titleImage.backingSize.width, tY + 4, titleImage.backingSize.width, titleImage.backingSize.height))
                textRect.origin.x += floorToScreenPixels(titleImage.backingSize.width/2)
            }
            
            textApply().draw(textRect, in: ctx)
        }
        
    }
    
    public init(_ text:NSAttributedString?, _ status:NSAttributedString? = nil) {
        self.text = text
        self.status = status
        
        super.init()
        
    }
    
    public override init() {
        super.init()
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
