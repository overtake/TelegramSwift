//
//  ChatChannelSuggestView.swift
//  Telegram
//
//  Created by Mike Renoir on 10.11.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

private let avatarSize = NSMakeSize(60, 60)

final class ChannelSuggestData {
    
    struct Channel {
        let peer: Peer
        let name: TextViewLayout
        var size: NSSize {
            return NSMakeSize(avatarSize.width + 20, avatarSize.height + name.layoutSize.height + 4 + 10)
        }
    }
    
    private(set) var channels:[Channel] = []
    private(set) var size: NSSize = .zero
    
    init(channels: [Peer], presentation: TelegramPresentationTheme) {
        var list: [Channel] = []
        for channel in channels {
            let attr = NSMutableAttributedString()
            attr.append(string: channel.displayTitle, color: presentation.colors.text, font: .normal(.short))
            attr.append(string: "\n")
            attr.append(string: Int.random(in: 100000..<10000000).prettyNumber, color: presentation.colors.grayText, font: .normal(.small))
            let name = TextViewLayout(attr, maximumNumberOfLines: 2, alignment: .center)
            name.measure(width: avatarSize.width + 20)
            let value = Channel(peer: channel, name: name)
            list.append(value)
        }
        self.channels = list
    }
    
    func makeSize(width: CGFloat) {
        let effective_w: CGFloat = channels.reduce(0, {
            $0 + $1.size.width
        })
        let effective_h: CGFloat = channels.map { $0.size.height }.max()!
        self.size = NSMakeSize(min(effective_w, width), effective_h + 40)
    }
}

private final class ChannelView : Control {
    private let avatar = AvatarControl(font: .avatar(17))
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(avatarSize)
        addSubview(avatar)
        addSubview(textView)
        
        avatar.userInteractionEnabled = false
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        scaleOnClick = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(channel: ChannelSuggestData.Channel, context: AccountContext, animated: Bool) {
        avatar.setPeer(account: context.account, peer: channel.peer)
        textView.update(channel.name)
    }
    
    override func layout() {
        super.layout()
        avatar.centerX(y: 0)
        textView.centerX(y: avatar.frame.maxY + 4)
    }
}

final class ChatChannelSuggestView : Control {
    private let titleView = TextView()
    private let dismiss = ImageButton()
    private let container = View(frame: .zero)
    private let scrollView = HorizontalScrollView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(dismiss)
        addSubview(scrollView)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        scrollView.documentView = container
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(item: ChatServiceItem, data: ChannelSuggestData, animated: Bool) {
        
        let layout = TextViewLayout(.initialize(string: "Similar Values", color: item.presentation.colors.text, font: .medium(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        
        titleView.update(layout)
        
        dismiss.set(image: NSImage(named: "Icon_GradientClose")!.precomposed(item.presentation.colors.grayText), for: .Normal)
        dismiss.sizeToFit()
        backgroundColor = item.presentation.colors.background
        layer?.cornerRadius = 10
        
        container.removeAllSubviews()
        
        var x: CGFloat = 10
        for channel in data.channels {
            let view = ChannelView(frame: CGRect(origin: NSMakePoint(x, 0), size: channel.size))
            x += view.frame.width
            container.addSubview(view)
            view.set(channel: channel, context: item.context, animated: animated)
        }
        container.setFrameSize(NSMakeSize(container.subviewsWidthSize.width + 20, container.subviewsWidthSize.height))
    }
    
    override func layout() {
        super.layout()
        titleView.setFrameOrigin(NSMakePoint(10, 10))
        dismiss.setFrameOrigin(NSMakePoint(frame.width - dismiss.frame.width - 8, 5))
        scrollView.frame = NSMakeRect(0, 40, frame.width, container.frame.height)
    }
}
