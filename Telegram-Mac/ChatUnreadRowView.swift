//
//  ChatUnreadRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class ChatUnreadRowView: TableRowView {
    
    private var text:TextNode = TextNode()

    override func draw(_ dirtyRect: NSRect) {

        // Drawing code here.
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(theme.colors.grayBackground.cgColor)
        
        ctx.fill(self.bounds)
        
        
        if let item = self.item as? ChatUnreadRowItem {
            let (layout, apply) = TextNode.layoutText(maybeNode: text, item.text, nil, 1, .end, NSMakeSize(NSWidth(self.frame), NSHeight(self.frame)), nil,false, .left)
            apply.draw(NSMakeRect(round((NSWidth(layer.bounds) - layout.size.width)/2.0), round((NSHeight(layer.bounds) - layout.size.height)/2.0), layout.size.width, layout.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
        }
        
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
}
