//
//  ChatNavigateScroller.swift
//  Telegram-Mac
//
//  Created by keepcoder on 20/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox


class ChatNavigationScroller: ImageButton {
    
    enum Source {
        case mentions
        case failed
        case reactions
        case scroller
        var image: CGImage {
            switch self {
            case .mentions:
                return theme.icons.chatMention
            case .failed:
                return theme.icons.chat_failed_scroller
            case .reactions:
                return theme.icons.chat_reactions_badge
            case .scroller:
                return theme.icons.chatScrollUp
            }
        }
        var active: CGImage {
            switch self {
            case .mentions:
                return theme.icons.chatMentionActive
            case .failed:
                return theme.icons.chat_failed_scroller_active
            case .reactions:
                return theme.icons.chat_reactions_badge_active
            case .scroller:
                return theme.icons.chatScrollUpActive
            }
        }
    }

    private var badge:BadgeNode?
    private var badgeView:View = View()
    private let source: Source
    private var count: Int32 = 0
    init(_ source: Source) {
        self.source = source
        super.init()
        autohighlight = false
        set(image: source.image, for: .Normal)
        set(image: source.active, for: .Highlight)
        self.setFrameSize(60,60)
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.1)
        shadow.shadowOffset = NSMakeSize(0, 2)
        self.shadow = shadow
        
    }
    
    func updateCount(_ count: Int32) {
        self.count = count
        if count > 0 {
            badge = BadgeNode(.initialize(string: Int(count).prettyNumber, color: .white, font: .bold(.small)), theme.colors.accent)
            badge!.view = badgeView
            badgeView.setFrameSize(badge!.size)
            addSubview(badgeView)
        } else {
            badgeView.removeFromSuperview()
        }
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        set(image: source.image, for: .Normal)
        set(image: source.active, for: .Highlight)
    }
    
    override func scrollWheel(with event: NSEvent) {
        
    }
    
    var hasBadge: Bool {
        return count > 0
    }
    
    override func layout() {
        super.layout()
        badgeView.centerX(y:0)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    
}


