//
//  PersonalChannelRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import DateUtils
final class PersonalChannelRowItem: GeneralRowItem {
    let titleLayout: TextViewLayout
    let textLayout: TextViewLayout
    let dateLayout: TextViewLayout?
    let context: AccountContext
    let peer: EnginePeer
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, item: UserInfoPersonalChannel, viewType: GeneralViewType, action:@escaping()->Void) {
        self.context = context
        self.peer = item.peer
        self.titleLayout = .init(.initialize(string: item.peer._asPeer().displayTitle, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        let text = chatListText(account: context.account, for: item.message?._asMessage())
        self.textLayout = .init(text, maximumNumberOfLines: 2)
        
        if let message = item.message {
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= context.timeDifference
            self.dateLayout = .init(.initialize(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: .normal(.short)), maximumNumberOfLines: 1)
            self.dateLayout?.measure(width: .greatestFiniteMagnitude)
        } else {
            self.dateLayout = nil
        }
        super.init(initialSize, height: 70, stableId: stableId, viewType: viewType, action: action)
    }
    
    override func viewClass() -> AnyClass {
        return PersonalChannelRowView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        textLayout.measure(width: blockWidth - 30 - 50)
        titleLayout.measure(width: blockWidth - 30 - 50 - (dateLayout != nil ? dateLayout!.layoutSize.width + 5 : 0))

        return true
    }
}


private final class PersonalChannelRowView : GeneralContainableRowView {
    private let avatar = AvatarControl(font: .avatar(22))
    private let titleView = TextView()
    private let textView = InteractiveTextView(frame: .zero)
    private var dateView: TextView?
    private var statusControl: PremiumStatusControl?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(NSMakeSize(50, 50))
        addSubview(avatar)
        addSubview(titleView)
        addSubview(textView)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        textView.userInteractionEnabled = false
        textView.isEventLess = true
        
        avatar.userInteractionEnabled = false
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.scaleOnClick = true
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? GeneralRowItem {
                item.action()
            }
        }, for: .Click)

    }
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? GeneralRowItem {
            self.background = item.viewType.rowBackground
            let highlighted = isSelect ? self.backdorColor : theme.colors.grayHighlight
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        avatar.setFrameOrigin(NSMakePoint(12, 10))
        titleView.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, 10))
        
        statusControl?.setFrameOrigin(NSMakePoint(titleView.frame.maxX + 2, titleView.frame.minY - 1))
        
        textView.setFrameOrigin(NSMakePoint(titleView.frame.minX, titleView.frame.maxY + 3))
        if let dateView {
            dateView.setFrameOrigin(NSMakePoint(containerView.frame.width - dateView.frame.width - 14, 10))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PersonalChannelRowItem else {
            return
        }
        
        self.avatar.setPeer(account: item.context.account, peer: item.peer._asPeer())
        
        self.textView.set(text: item.textLayout, context: item.context)
        self.titleView.update(item.titleLayout)
        
        if let dateLayout = item.dateLayout {
            let current: TextView
            if let view = self.dateView {
                current = view
            } else {
                current = TextView()
                self.dateView = current
                current.userInteractionEnabled = false
                current.isSelectable = false
                addSubview(current)
            }
            current.update(dateLayout)
        } else if let view = self.dateView {
            performSubviewRemoval(view, animated: animated)
            self.dateView = nil
        }
        
        let control = PremiumStatusControl.control(item.peer._asPeer(), account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, isSelected: false, isBig: true, color: theme.colors.accent, cached: self.statusControl, animated: animated)
        
        if let control = control {
            self.statusControl = control
            self.addSubview(control)
        } else if let view = self.statusControl {
            performSubviewRemoval(view, animated: animated)
            self.statusControl = nil
        }
        
        needsLayout = true
    }
    
    
}
