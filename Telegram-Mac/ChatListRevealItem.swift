//
//  ChatListRevealItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import SyncCore

class ChatListRevealItem: TableStickItem {
    fileprivate let action:(()->Void)?
    fileprivate let context: AccountContext?
    init(_ initialSize: NSSize, context: AccountContext, action: (()->Void)? = nil) {
        self.action = action
        self.context = context
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        self.action = nil
        self.context = nil
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return UIChatListEntryId.reveal
    }
    
    override func viewClass() -> AnyClass {
        return ChatListRevealView.self
    }
}


private final class ChatListRevealView : TableStickView {
    private let textView: TextView = TextView()
    private let separator: View = View()
    private var badgeNode: GlobalBadgeNode?
    private let containerView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(textView)
        containerView.addSubview(separator)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        containerView.isEventLess = true
        border = [.Right]
        separator.change(opacity: 0, animated: false)
    }
    
    override func mouseUp(with event: NSEvent) {
       
    }
    override func mouseDown(with event: NSEvent) {
        if mouseInside() {
            if let item = item as? ChatListRevealItem {
                item.action?()
            }
        }
    }
    
    override func updateIsVisible(_ visible: Bool, animated: Bool) {
        super.updateIsVisible(visible, animated: animated)
        var visible = visible
        if let table = item?.table {
            visible = visible && table.documentOffset.y > 0
        }
        separator.change(opacity: visible ? 1 : 0, animated: false)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        super.updateColors()
        separator.backgroundColor = theme.colors.border
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListRevealItem else {
            return
        }
        if let context = item.context, self.badgeNode == nil {
            self.badgeNode = GlobalBadgeNode(context.account, sharedContext: context.sharedContext, view: View(), layoutChanged: { [weak self] in
                self?.needsLayout = true
            }, getColor: { _ in return theme.colors.accent }, fontSize: 9, applyFilter: false)
            containerView.addSubview(self.badgeNode!.view!)
        }
        
        
        let layout = TextViewLayout(.initialize(string: L10n.chatListCloseFilter, color: theme.colors.accent, font: .normal(.text)))
        textView.update(layout)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        containerView.frame = bounds
        
        let layout = textView.layout
        layout?.measure(width: frame.width - 40)
        textView.update(layout)
        
        let badgeSize = self.badgeNode?.view?.frame.size ?? .zero
        
        textView.centerY(x: floorToScreenPixels(backingScaleFactor, (frame.width - (textView.frame.width + badgeSize.width + 10)) / 2))
        
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        
        self.badgeNode?.view?.setFrameOrigin(NSMakePoint(textView.frame.maxX + 10, 6))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
