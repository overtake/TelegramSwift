//
//  ChatNavigateScroller.swift
//  Telegram-Mac
//
//  Created by keepcoder on 20/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac


class ChatNavigateScroller: ImageButton {

    private let disposable:MetaDisposable = MetaDisposable()
    private var badge:BadgeNode?
    private var badgeView:View = View()
    private let account:Account
    init(_ account:Account, _ chatLocation: ChatLocation) {
        self.account = account
        super.init()
        autohighlight = false
        set(image: theme.icons.chatScrollUp, for: .Normal)
        set(image: theme.icons.chatScrollUpActive, for: .Highlight)
        self.setFrameSize(60,60)
        
        self.disposable.set((account.postbox.unreadMessageCountsView(items: [chatLocation.unreadMessageCountsItem]) |> deliverOnMainQueue).start(next: { [weak self] unreadView in
            if let strongSelf = self {
                let count = unreadView.count(for: chatLocation.unreadMessageCountsItem) ?? 0
                if count > 0 {
                    strongSelf.badge = BadgeNode(.initialize(string: Int(count).prettyNumber, color: .white, font: .bold(.small)), theme.colors.blueUI)
                    strongSelf.badge!.view = strongSelf.badgeView
                    strongSelf.badgeView.setFrameSize(strongSelf.badge!.size)
                    strongSelf.addSubview(strongSelf.badgeView)
                } else {
                    strongSelf.badgeView.removeFromSuperview()
                }
                strongSelf.needsLayout = true

            }
        }))
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        set(image: theme.icons.chatScrollUp, for: .Normal)
        set(image: theme.icons.chatScrollUpActive, for: .Highlight)
        badge?.fillColor = theme.colors.blueUI
    }
    
    override func scrollWheel(with event: NSEvent) {
        
    }
    
    override func layout() {
        super.layout()
        badgeView.centerX(y:0)
    }
    
    deinit {
        disposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
