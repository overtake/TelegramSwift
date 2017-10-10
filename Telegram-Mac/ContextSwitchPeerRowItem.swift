//
//  ContextSwitchPeerRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 13/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
class ContextSwitchPeerRowItem: TableRowItem {
    fileprivate let account:Account
    fileprivate let peerId:PeerId
    fileprivate let switchPeer:ChatContextResultSwitchPeer
    fileprivate let layout:TextViewLayout
    fileprivate let callback:()->Void
    init(_ initialSize:NSSize, peerId:PeerId, switchPeer:ChatContextResultSwitchPeer, account:Account, callback:@escaping()->Void) {
        self.account = account
        self.peerId = peerId
        self.switchPeer = switchPeer
        self.callback = callback
        layout = TextViewLayout(.initialize(string: switchPeer.text, color: theme.colors.link, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        layout.measure(width: initialSize.width - 40)
        super.init(initialSize)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        layout.measure(width: width - 40)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return ContextSwitchPeerRowView.self
    }
    
    override var height: CGFloat {
        return 40
    }
    
}

class ContextSwitchPeerRowView: TableRowView {
    private let textView:TextView = TextView()
    private let overlay:OverlayControl = OverlayControl()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        addSubview(overlay)
        addSubview(textView)
        
        textView.backgroundColor = theme.colors.background
        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? ContextSwitchPeerRowItem {
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
        if let item = item as? ContextSwitchPeerRowItem {
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
