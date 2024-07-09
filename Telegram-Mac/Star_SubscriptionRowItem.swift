//
//  Star_SubscriptionRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit


final class Star_SubscriptionRowItem : GeneralRowItem {
    fileprivate let context:AccountContext
    fileprivate let subscription: Star_Subscription
    
    fileprivate let nameLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    
    fileprivate let amountLayout: TextViewLayout
    fileprivate let perMonthLayout: TextViewLayout?

    fileprivate let callback: (Star_Subscription)->Void
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, viewType: GeneralViewType, subscription: Star_Subscription, callback: @escaping(Star_Subscription)->Void) {
        self.context = context
        self.subscription = subscription
        self.callback = callback
        
        let amountAttr = NSMutableAttributedString()
        //TODOLANG
        switch subscription.state {
        case .active:
            amountAttr.append(string: "\(clown)\(TINY_SPACE)\(subscription.amount)", color: theme.colors.text, font: .medium(.title))
            amountAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file, playPolicy: .onceEnd), for: clown)
        case .cancelled:
            amountAttr.append(string: "cancelled", color: theme.colors.redUI, font: .normal(.short))
        }
        
        self.amountLayout = .init(amountAttr)
        
        let name: String = subscription.peer._asPeer().displayTitle
        self.nameLayout = .init(.initialize(string: name, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        
        
        if subscription.state == .active {
            self.perMonthLayout = .init(.initialize(string: "per month", color: theme.colors.grayText, font: .normal(.short)))
            self.perMonthLayout?.measure(width: .greatestFiniteMagnitude)
        } else {
            self.perMonthLayout = nil
        }
        
        //TODOLANG
        let date = stringForMediumDate(timestamp: subscription.renewDate)
        var dateText: String
        switch subscription.state {
        case .active:
            dateText = "renews on \(date)"
        case .cancelled:
            if subscription.renewDate < context.timestamp {
                dateText = "expired on \(date)"
            } else {
                dateText = "expires on \(date)"
            }
        }
        self.dateLayout = .init(.initialize(string: dateText, color: theme.colors.grayText, font: .normal(.text)))
        
                
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return Star_SubscriptionRowView.self
    }
    
    override var height: CGFloat {
        let height = 7 + nameLayout.layoutSize.height + 4 + dateLayout.layoutSize.height + 7
        return max(50, height)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        amountLayout.measure(width: .greatestFiniteMagnitude)
        nameLayout.measure(width: blockWidth - 20 - amountLayout.layoutSize.width - 10 - 50)
        dateLayout.measure(width: blockWidth - 20 - amountLayout.layoutSize.width - 10 - 50)

        perMonthLayout?.measure(width: blockWidth - 20 - amountLayout.layoutSize.width - 10 - 50)
        return true
    }
}

private final class Star_SubscriptionRowView : GeneralContainableRowView {
    private let amountView = InteractiveTextView()
    private let nameView = TextView()
    private let dateView = TextView()
    private let avatar: AvatarControl = AvatarControl(font: .avatar(15))
    
    private var perMonth: TextView?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(amountView)
        addSubview(nameView)
        addSubview(dateView)
        
        
        avatar.setFrameSize(NSMakeSize(40, 40))
        addSubview(avatar)
        
        amountView.userInteractionEnabled = false
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        dateView.userInteractionEnabled = false
        dateView.isSelectable = false
        
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
            if let item = self?.item as? Star_SubscriptionRowItem {
                item.callback(item.subscription)
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
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Star_SubscriptionRowItem else {
            return
        }
        
        amountView.set(text: item.amountLayout, context: item.context)
        dateView.update(item.dateLayout)
        nameView.update(item.nameLayout)
        
        if let perMonthLayout = item.perMonthLayout {
            let current: TextView
            if let view = self.perMonth {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false

                self.perMonth = current
                addSubview(current)
            }
            current.update(perMonthLayout)
        } else if let view = self.perMonth {
            performSubviewRemoval(view, animated: animated)
            self.perMonth = nil
        }
        
        avatar.setPeer(account: item.context.account, peer: item.subscription.peer._asPeer())

        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        if let perMonth {
            amountView.setFrameOrigin(NSMakePoint(containerView.frame.width - amountView.frame.width - 12, 9))
            perMonth.setFrameOrigin(NSMakePoint(containerView.frame.width - perMonth.frame.width - 12, amountView.frame.maxY))
        } else {
            amountView.centerY(x: containerView.frame.width - amountView.frame.width - 12)
        }
        avatar.centerY(x: 10)
        nameView.setFrameOrigin(NSMakePoint(10 + 44 + 10, 7))
        dateView.setFrameOrigin(NSMakePoint(nameView.frame.minX, containerView.frame.height - dateView.frame.height - 7))
        
    }
    
    override var additionBorderInset: CGFloat {
        return 40 + 6
    }
}
