//
//  TitledBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TitledBarView: BarView {
    
    var textNode:TextNode = TextNode()
    
    var text:NSAttributedString

    override open func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let (textLayout, textApply) = TextNode.layoutText(textNode)(text, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - 50, NSHeight(layer.bounds)), nil,false)
        textApply().draw(NSMakeRect(round((NSWidth(layer.bounds) - textLayout.size.width)/2.0), round((NSHeight(layer.bounds) - textLayout.size.height)/2.0), textLayout.size.width, textLayout.size.height), in: ctx)
        
    }
    
    public init(_ text:NSAttributedString) {
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
