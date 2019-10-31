//
//  ChannelDiscussionInputView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

class ChannelDiscussionInputView: View {
    private let leftButton: TitleButton = TitleButton()
    private let rightButton: TitleButton = TitleButton()
    private var badge:BadgeNode?
    private var badgeView:View = View()
    private let disposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        leftButton.disableActions()
        rightButton.disableActions()
        addSubview(leftButton)
        addSubview(rightButton)
        addSubview(badgeView)
    }
    
    func update(with chatInteraction: ChatInteraction, discussionGroupId: PeerId?, leftAction: String, rightAction: String) {
        leftButton.style = ControlStyle(font: .normal(.title),foregroundColor: theme.colors.accent)
        leftButton.set(text: leftAction, for: .Normal)
        leftButton.set(background: theme.colors.grayBackground, for: .Highlight)
        
        rightButton.style = ControlStyle(font: .normal(.title),foregroundColor: theme.colors.accent)
        rightButton.set(text: rightAction, for: .Normal)
        rightButton.set(background: theme.colors.grayBackground, for: .Highlight)
        
        
        leftButton.removeAllHandlers()
        leftButton.set(handler: { [weak chatInteraction] _ in
            chatInteraction?.toggleNotifications(nil)
        }, for: .Click)
        
        rightButton.removeAllHandlers()
        rightButton.set(handler: { [weak chatInteraction] _ in
            chatInteraction?.openDiscussion()
        }, for: .Click)
        
        let context = chatInteraction.context
        if let discussionGroupId = discussionGroupId {
            self.disposable.set((context.account.postbox.unreadMessageCountsView(items: [.peer(discussionGroupId)]) |> deliverOnMainQueue).start(next: { [weak self] unreadView in
                if let strongSelf = self {
                    let count = unreadView.count(for: .peer(discussionGroupId)) ?? 0
                    if count > 0 {
                        strongSelf.badge = BadgeNode(.initialize(string: Int(count).prettyNumber, color: .white, font: .bold(.small)), theme.colors.accent)
                        strongSelf.badge!.view = strongSelf.badgeView
                        strongSelf.badgeView.setFrameSize(strongSelf.badge!.size)
                        strongSelf.addSubview(strongSelf.badgeView)
                    } else {
                        strongSelf.badgeView.removeFromSuperview()
                    }
                    strongSelf.needsLayout = true
                    
                }
            }))
        } else {
            self.badgeView.removeFromSuperview()
            self.disposable.set(nil)
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        leftButton.style = ControlStyle(font: .normal(.title),foregroundColor: theme.colors.accent)
        leftButton.set(background: theme.colors.grayBackground, for: .Highlight)
        rightButton.style = ControlStyle(font: .normal(.title),foregroundColor: theme.colors.accent)
        rightButton.set(background: theme.colors.grayBackground, for: .Highlight)
        
    }
    
    override func layout() {
        super.layout()
        leftButton.frame = NSMakeRect(0, 0, frame.width / 2, frame.height)
        rightButton.frame = NSMakeRect(frame.width / 2, 0, frame.width / 2, frame.height)
        badgeView.centerY(x: rightButton.frame.maxX - (rightButton.frame.width - rightButton.textSize.width) / 2 + 5)

    }
    
    
    deinit {
        disposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
