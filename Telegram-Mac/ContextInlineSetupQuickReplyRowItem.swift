//
//  ContextInlineSetupQuickReplyRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox

class ContextInlineSetupQuickReplyRowItem: TableRowItem {
    fileprivate let account:Account
    fileprivate let layout:TextViewLayout
    fileprivate let callback:()->Void
    init(_ initialSize:NSSize, account:Account, callback:@escaping()->Void) {
        self.account = account
        self.callback = callback
        layout = TextViewLayout(.initialize(string: strings().chatInputContextEditQuickReply, color: theme.colors.link, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        layout.measure(width: initialSize.width - 40)
        super.init(initialSize)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        layout.measure(width: width - 40)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return ContextInlineSetupQuickReplyRowView.self
    }
    
    override var height: CGFloat {
        return 40
    }
    
}

class ContextInlineSetupQuickReplyRowView: TableRowView {
    private let textView:TextView = TextView()
    private let overlay:OverlayControl = OverlayControl()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(overlay)
        overlay.addSubview(textView)
        
        overlay.scaleOnClick = true
        
        textView.backgroundColor = theme.colors.background
        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? ContextInlineSetupQuickReplyRowItem {
                item.callback()
            }
        }, for: .Click)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        needsDisplay = true
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ContextInlineSetupQuickReplyRowItem {
            overlay.setFrameSize(frame.size)
            textView.update(item.layout)
            textView.center()
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item, let table = item.table {
            if item.index != table.count - 1 {
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize))
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}



