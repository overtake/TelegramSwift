//
//  ChatHoleRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class ChatHoleRowView: TableRowView {
    
    private var text:TextNode = TextNode()

    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        
        if let item = self.item as? ChatHoleRowItem {
            let (layout, apply) = TextNode.layoutText(maybeNode: text, item.text, nil, 1, .end, NSMakeSize(NSWidth(self.frame), NSHeight(self.frame)), nil,false, .left)
            apply.draw(NSMakeRect(round((NSWidth(self.frame) - layout.size.width)/2.0), round((NSHeight(self.frame) - layout.size.height)/2.0), layout.size.width, layout.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
        }
        
    }
}
