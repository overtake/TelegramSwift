//
//  MessageSharedRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

class MessageSharedRowItem: GeneralRowItem {
    fileprivate let viewsCountLayout: TextViewLayout
    fileprivate let titleLayout: TextViewLayout
    fileprivate let message: Message
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, message: Message, viewType: GeneralViewType, action: @escaping()->Void) {
        self.context = context
        self.message = message
    
        self.titleLayout = TextViewLayout(.initialize(string: message.effectiveAuthor?.displayTitle ?? "", color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        
        let views = Int(message.channelViewsCount ?? 0)
        
        let viewsString = L10n.channelStatsViewsCountCountable(views).replacingOccurrences(of: "\(views)", with: views.formattedWithSeparator)
        
        viewsCountLayout = TextViewLayout(.initialize(string: viewsString, color: theme.colors.grayText, font: .normal(.short)),maximumNumberOfLines: 1)
        
        super.init(initialSize, height: 46, stableId: stableId, viewType: viewType, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        viewsCountLayout.measure(width: .greatestFiniteMagnitude)
        let titleAndDateWidth: CGFloat = blockWidth - viewType.innerInset.left - viewType.innerInset.right
        
        titleLayout.measure(width: titleAndDateWidth)
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return MessageSharedRowView.self
    }
}


private final class MessageSharedRowView : GeneralContainableRowView {
    private let viewCountView = TextView()
    private let titleView = TextView()
    private var imageView: AvatarControl = AvatarControl(font: .avatar(15))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(viewCountView)
        addSubview(titleView)
        addSubview(imageView)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        titleView.isEventLess = true
        
        viewCountView.userInteractionEnabled = false
        viewCountView.isSelectable = false
        viewCountView.isEventLess = true
        
        imageView.setFrameSize(NSMakeSize(30, 30))
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? MessageSharedRowItem else {
                return
            }
            item.action()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? MessageSharedRowItem else {
            return
        }
        
        let leftOffset: CGFloat = 34 + 10 + item.viewType.innerInset.left
        
        titleView.setFrameOrigin(NSMakePoint(leftOffset, 7))
        viewCountView.setFrameOrigin(NSMakePoint(leftOffset, containerView.frame.height - viewCountView.frame.height - 7))

        imageView.centerY(x: item.viewType.innerInset.left)
    }
    
    override var backdorColor: NSColor {
        return isSelect ? theme.colors.accentSelect : theme.colors.background
    }
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? GeneralRowItem {
            self.background = item.viewType.rowBackground
            let highlighted = isSelect ? self.backdorColor : theme.colors.grayHighlight
            titleView.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            viewCountView.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MessageSharedRowItem else {
            return
        }
        
        viewCountView.update(item.viewsCountLayout)
        titleView.update(item.titleLayout)
        imageView.setPeer(account: item.context.account, peer: item.message.effectiveAuthor, message: item.message)
    }
    
    deinit {
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
