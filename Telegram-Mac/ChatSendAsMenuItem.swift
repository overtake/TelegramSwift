//
//  ChatSendAdMenuItem.swift
//  Telegram
//
//  Created by Mike Renoir on 18.01.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore

class ContextSendAsMenuItem : ContextMenuItem {
    
    private let peer: SendAsPeer
    private let context: AccountContext
    private let isSelected: Bool
    init(peer: SendAsPeer, context: AccountContext, isSelected: Bool, handler: (() -> Void)? = nil) {
        self.peer = peer
        self.context = context
        self.isSelected = isSelected
        super.init(peer.peer.displayTitle.prefixWithDots(20), handler: handler)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return ContextSendAsMenuRowItem(.zero, item: self, interaction: interaction, presentation: presentation, peer: peer, context: context, isSelected: isSelected)
    }
}


private final class ContextSendAsMenuRowItem : AppMenuRowItem {
    private let disposable = MetaDisposable()
    fileprivate let context: AccountContext
    fileprivate let statusLayout: TextViewLayout
    fileprivate let peer: SendAsPeer
    fileprivate let selected: Bool
    init(_ initialSize: NSSize, item: ContextMenuItem, interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, peer: SendAsPeer, context: AccountContext, isSelected: Bool) {
        
        self.peer = peer
        self.context = context
        self.selected = isSelected
        let status: String
        if peer.peer.isUser {
            status = strings().chatSendAsPersonalAccount
        } else {
            if peer.peer.isGroup || peer.peer.isSupergroup {
                status = strings().chatSendAsGroupCountable(Int(peer.subscribers ?? 0))
            } else {
                status = strings().chatSendAsChannelCountable(Int(peer.subscribers ?? 0))
            }
        }
        self.statusLayout = .init(.initialize(string: status, color: presentation.disabledTextColor, font: .normal(.text)))
        
        super.init(initialSize, item: item, interaction: interaction, presentation: presentation)
        
        let signal:Signal<(CGImage?, Bool), NoError>
        
        let peer = self.peer.peer
        
        signal = peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.nameColor, peer.displayLetters, nil), displayDimensions: NSMakeSize(25 * System.backingScale, 25 * System.backingScale), font: .avatar(14), genCap: true, synchronousLoad: false, disableForum: true) |> deliverOnMainQueue
        disposable.set(signal.start(next: { [weak item] image, _ in
            if let image = image {
                item?.image = NSImage(cgImage: image, size: NSMakeSize(25, 25))
            }
        }))
    }
    
    override var imageSize: CGFloat {
        return 25
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var textSize: CGFloat {
        return max(text.layoutSize.width, statusLayout.layoutSize.width) + leftInset * 2 + innerInset * 2
    }
    
    override var effectiveSize: NSSize {
        var size = super.effectiveSize
        
        if peer.isPremiumRequired && !context.isPremium {
            size.width += 15
        }
        
        return size
    }
    
    override var height: CGFloat {
        return 35
    }
    
    override func makeSize(_ width: CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.statusLayout.measure(width: width - leftInset * 2 - innerInset * 2)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return ContextAccountMenuRowView.self
    }
}

private final class ContextAccountMenuRowView : AppMenuRowView {
    private let statusView: TextView = TextView()
    private var borderView: View?
    private var lockView: ImageView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(statusView)
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? ContextSendAsMenuRowItem else {
            return
        }
        
        statusView.setFrameOrigin(NSMakePoint(textX, textY + 14))
        if let borderView = borderView {
            borderView.frame = imageFrame.insetBy(dx: -2, dy: -2)
        }
        if let lockView = lockView {
            lockView.setFrameOrigin(textX + item.text.layoutSize.width, textY)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ContextSendAsMenuRowItem else {
            return
        }
        
        statusView.update(item.statusLayout)
        
        if item.peer.isPremiumRequired && !item.context.isPremium {
            let current: ImageView
            if let view = self.lockView {
                current = view
            } else {
                current = ImageView()
                addSubview(current)
                self.lockView = current
            }
            current.image = NSImage(named: "Icon_EmojiLock")?.precomposed(item.presentation.disabledTextColor)
            current.sizeToFit()
        } else if let view = self.lockView {
            performSubviewRemoval(view, animated: animated)
            self.lockView = nil
        }
        if item.selected {
            let current: View
            if let view = borderView {
                current = view
            } else {
                current = View()
                self.borderView = current
                addSubview(current)
            }
            current.setFrameSize(NSMakeSize(item.imageSize + 4, item.imageSize + 4))
            current.layer?.cornerRadius = current.frame.height / 2
            current.layer?.borderWidth = 1
            current.layer?.borderColor = item.presentation.colors.accent.cgColor
        } else if let view = borderView {
            performSubviewRemoval(view, animated: animated)
        }
    }
    
    
    override var textY: CGFloat {
        return 2
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
