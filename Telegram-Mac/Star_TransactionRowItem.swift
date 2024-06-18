//
//  Star_TransactionRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

final class Star_TransactionItem : GeneralRowItem {
    fileprivate let context:AccountContext
    fileprivate let transaction: Star_Transaction
    
    fileprivate let amountLayout: TextViewLayout
    fileprivate let nameLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
            
    fileprivate let callback: (Star_Transaction)->Void
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, viewType: GeneralViewType, transaction: Star_Transaction, callback: @escaping(Star_Transaction)->Void) {
        self.context = context
        self.transaction = transaction
        self.callback = callback
        
        let amountAttr = NSMutableAttributedString()
        if transaction.amount < 0 {
            amountAttr.append(string: "\(transaction.amount) \(clown)", color: theme.colors.redUI, font: .medium(.text))
        } else {
            amountAttr.append(string: "+\(transaction.amount) \(clown)", color: theme.colors.greenUI, font: .medium(.text))
        }
        amountAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file, playPolicy: .onceEnd), for: clown)
        
        self.amountLayout = .init(amountAttr)
        
        let name: String
        
        switch transaction.type.source {
        case .appstore:
            name = strings().starListTransactionAppStore
        case .fragment:
            name = strings().starListTransactionFragment
        case .playmarket:
            name = strings().starListTransactionPlayMarket
        case .peer:
            name = transaction.peer?._asPeer().displayTitle ?? ""
        case .premiumbot:
            name = strings().starListTransactionPremiumBot
        case .unknown:
            name = strings().starListTransactionUnknown
        }
        
        self.nameLayout = .init(.initialize(string: name, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        
        var date = stringForFullDate(timestamp: transaction.date)
        if transaction.native.flags.contains(.isRefund) {
            date += " — \(strings().starListRefund)"
        }
        self.dateLayout = .init(.initialize(string: date, color: theme.colors.grayText, font: .normal(.text)))
        
                
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return TransactionView.self
    }
    
    override var height: CGFloat {
        return max(50, 7 + nameLayout.layoutSize.height + 4 + dateLayout.layoutSize.height + 7)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        amountLayout.measure(width: .greatestFiniteMagnitude)
        nameLayout.measure(width: blockWidth - 20 - amountLayout.layoutSize.width - 10 - 40)
        dateLayout.measure(width: blockWidth - 20 - amountLayout.layoutSize.width - 10 - 40)

        return true
    }
}

private final class TransactionView : GeneralContainableRowView {
    private let amountView = InteractiveTextView()
    private let nameView = TextView()
    private let dateView = TextView()
    private var avatarView: AvatarControl?
    private var avatarImage: ImageView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(amountView)
        addSubview(nameView)
        addSubview(dateView)
        
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
            if let item = self?.item as? Star_TransactionItem {
                item.callback(item.transaction)
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
        
        guard let item = item as? Star_TransactionItem else {
            return
        }
        
        amountView.set(text: item.amountLayout, context: item.context)
        dateView.update(item.dateLayout)
        nameView.update(item.nameLayout)
        
        //

        if let peer = item.transaction.peer {
            if let avatarImage {
                performSubviewRemoval(avatarImage, animated: animated)
                self.avatarImage = nil
            }
            let current: AvatarControl
            if let view = self.avatarView {
                current = view
            } else {
                current = AvatarControl(font: .avatar(12))
                current.setFrameSize(NSMakeSize(36, 36))
                self.avatarView = current
                addSubview(current)
            }
            current.setPeer(account: item.context.account, peer: peer._asPeer())
        } else {
            if let view = avatarView {
                performSubviewRemoval(view, animated: animated)
                self.avatarView = nil
            }
            let current: ImageView
            if let view = self.avatarImage {
                current = view
            } else {
                current = ImageView(frame: NSMakeRect(0, 0, 36, 36))
                self.avatarImage = current
                addSubview(current)
            }
            switch item.transaction.type.source {
            case .appstore:
                current.image = NSImage(resource: .iconAppStoreStarTopUp).precomposed()
            case .fragment:
                current.image = NSImage(resource: .iconFragmentStarTopUp).precomposed()
            case .playmarket:
                current.image = NSImage(resource: .iconAndroidStarTopUp).precomposed()
            case .peer:
                break
            case .premiumbot:
                current.image = NSImage(resource: .iconPremiumStarTopUp).precomposed()
            case .unknown:
                current.image = NSImage(resource: .iconStarTransactionPreviewUnknown).precomposed()
            }
        }
        
        
        
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        amountView.centerY(x: containerView.frame.width - amountView.frame.width - 10)
        avatarView?.centerY(x: 10)
        avatarImage?.centerY(x: 10)
        nameView.setFrameOrigin(NSMakePoint(10 + 36 + 10, 7))
        dateView.setFrameOrigin(NSMakePoint(10 + 36 + 10, containerView.frame.height - dateView.frame.height - 7))

    }
    
    override var additionBorderInset: CGFloat {
        return 36 + 6
    }
}
