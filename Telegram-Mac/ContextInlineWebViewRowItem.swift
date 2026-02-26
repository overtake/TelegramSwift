//
//  ContextInlineWebViewRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 03.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox


class ContextInlineWebViewRowItem: TableRowItem {
    fileprivate let account:Account
    fileprivate let layout:TextViewLayout
    fileprivate let callback:()->Void
    init(_ initialSize:NSSize, text: String, url: String, account:Account, callback:@escaping()->Void) {
        self.account = account
        self.callback = callback
        layout = TextViewLayout(.initialize(string: text, color: theme.colors.link, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        layout.measure(width: initialSize.width - 40)
        super.init(initialSize)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        layout.measure(width: width - 40)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return ContextInlineWebViewRowView.self
    }
    
    override var height: CGFloat {
        return 40
    }
    
}

class ContextInlineWebViewRowView: TableRowView {
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
            if let item = self?.item as? ContextInlineWebViewRowItem {
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
        if let item = item as? ContextInlineWebViewRowItem {
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



