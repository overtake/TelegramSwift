//
//  ChatUnreadRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
class ChatUnreadRowItem: ChatRowItem {

    override var height: CGFloat {
        return 26
    }
    
    
    public var text:NSAttributedString;
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account:Account, _ entry:ChatHistoryEntry) {
        
        let titleAttr:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleAttr.append(string:tr(.messagesUnreadMark), color: theme.colors.grayText, font: .normal(.text))
        text = titleAttr.copy() as! NSAttributedString

        
        super.init(initialSize,chatInteraction,entry)
    }
    
    override var messageIndex:MessageIndex? {
        switch entry {
        case .UnreadEntry(let index, _):
            return index
        default:
            break
        }
        return super.messageIndex
    }
    
    override func viewClass() -> AnyClass {
        return ChatUnreadRowView.self
    }
    
}

private class ChatUnreadRowView: TableRowView {
    
    private var text:TextNode = TextNode()
    
    override func draw(_ dirtyRect: NSRect) {
        
        // Drawing code here.
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(theme.colors.background.cgColor)
        ctx.fill(bounds)
        
        ctx.setFillColor(theme.colors.grayBackground.cgColor)
        ctx.fill(NSMakeRect(0, 3, frame.width, frame.height - 6))
        
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
