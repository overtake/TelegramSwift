//
//  ContextPeerMenuItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.01.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore

class ContextAccountMenuItem : ContextMenuItem {
    
    private let account: AccountWithInfo
    private let context: AccountContext
    init(account: AccountWithInfo, context: AccountContext, handler: (() -> Void)? = nil) {
        self.account = account
        self.context = context
        super.init(account.peer.displayTitle.prefixWithDots(20), handler: handler)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return ContextAccountMenuRowItem(.zero, item: self, interaction: interaction, presentation: presentation, account: account, badge: GlobalBadgeNode(account.account, sharedContext: context.sharedContext, getColor: { selected in
            theme.colors.accent
        })
)
    }
}


private final class ContextAccountMenuRowItem : AppMenuRowItem {
    let badge: GlobalBadgeNode
    private let disposable = MetaDisposable()
    init(_ initialSize: NSSize, item: ContextMenuItem, interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, account: AccountWithInfo, badge: GlobalBadgeNode) {
        self.badge = badge
        badge.customLayout = true
        super.init(initialSize, item: item, interaction: interaction, presentation: presentation)
        
        let signal:Signal<(CGImage?, Bool), NoError>
        signal = peerAvatarImage(account: account.account, photo: .peer(account.peer, account.peer.smallProfileImage, account.peer.displayLetters, nil), displayDimensions: NSMakeSize(18 * System.backingScale, 18 * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
        disposable.set(signal.start(next: { [weak item] image, _ in
            if let image = image {
                item?.image = NSImage(cgImage: image, size: NSMakeSize(18, 18))
            }
        }))
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var effectiveSize: NSSize {
        var size = super.effectiveSize
        size.width += badge.size.width
        return size
    }
    
    override func viewClass() -> AnyClass {
        return ContextAccountMenuRowView.self
    }
}

private final class ContextAccountMenuRowView : AppMenuRowView {
    private let badgeView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(badgeView)
    }
    
    override func layout() {
        super.layout()
        badgeView.centerY(x: self.rightX - badgeView.frame.width)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ContextAccountMenuRowItem else {
            return
        }
        self.badgeView.setFrameSize(item.badge.size)
        item.badge.view = badgeView
        
        item.badge.onUpdate = { [weak item, weak self] in
            if let item = item, let view = self?.badgeView {
                view.setFrameSize(item.badge.size)
            }
            self?.needsLayout = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
