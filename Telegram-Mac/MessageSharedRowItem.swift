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

import SwiftSignalKit

class MessageSharedRowItem: GeneralRowItem {
    fileprivate let viewsCountLayout: TextViewLayout
    fileprivate let sharesCountLayout: TextViewLayout?
    fileprivate let likesCountLayout: TextViewLayout?

    fileprivate let dateLayout: TextViewLayout
    fileprivate let titleLayout: TextViewLayout
    fileprivate let forward: StoryStatsPublicForwardsContext.State.Forward
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, forward: StoryStatsPublicForwardsContext.State.Forward, viewType: GeneralViewType, action: @escaping()->Void) {
        self.context = context
        self.forward = forward
        
        let title: String
        let date: String
        switch forward {
        case let .message(message):
            title = message._asMessage().effectiveAuthor?.displayTitle ?? ""
            date = stringForFullDate(timestamp: message.timestamp)
        case let .story(peer, storyItem):
            title = peer._asPeer().displayTitle
            date = stringForFullDate(timestamp: storyItem.timestamp)
        }
    
        self.titleLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.dateLayout = TextViewLayout(.initialize(string: date, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)

        let views: Int
        let shares: Int32
        let likes: Int32
        switch forward {
        case let .message(message):
            views = Int(message._asMessage().channelViewsCount ?? 0)
            shares = 0
            likes = message._asMessage().reactionsAttribute?.reactions.reduce(0, { $0 + $1.count }) ?? 0
        case let .story(_, storyItem):
            views = storyItem.views?.seenCount ?? 0
            shares = Int32(storyItem.views?.forwardCount ?? 0)
            likes = Int32(storyItem.views?.reactedCount ?? 0)
        }
                
        let viewsString = strings().channelStatsViewsCountCountable(views).replacingOccurrences(of: "\(views)", with: views.formattedWithSeparator)
        
        viewsCountLayout = TextViewLayout(.initialize(string: viewsString, color: theme.colors.text, font: .normal(.short)),maximumNumberOfLines: 1)
        
        if shares > 0 {
            sharesCountLayout = TextViewLayout(.initialize(string: shares.formattedWithSeparator, color: theme.colors.grayText, font: .normal(.short)),maximumNumberOfLines: 1)
        } else {
            sharesCountLayout = nil
        }
        if likes > 0 {
            likesCountLayout = TextViewLayout(.initialize(string: likes.formattedWithSeparator, color: theme.colors.grayText, font: .normal(.short)),maximumNumberOfLines: 1)
        } else {
            likesCountLayout = nil
        }
        
        super.init(initialSize, height: 46, stableId: stableId, viewType: viewType, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        viewsCountLayout.measure(width: .greatestFiniteMagnitude)
        sharesCountLayout?.measure(width: .greatestFiniteMagnitude)
        likesCountLayout?.measure(width: .greatestFiniteMagnitude)

        let titleAndDateWidth: CGFloat = blockWidth - viewType.innerInset.left - viewType.innerInset.right - 34 - 10 - 15
        
        titleLayout.measure(width: titleAndDateWidth)
        dateLayout.measure(width: titleAndDateWidth)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return MessageSharedRowView.self
    }
}


private final class MessageSharedRowView : GeneralContainableRowView {
    private let dateView = TextView()
    private let titleView = TextView()
    
    private let viewCountView = TextView()
    
    private var sharesCountView: CounterView?
    private var likesCountView: CounterView?

    
    private var imageView: AvatarControl = AvatarControl(font: .avatar(15))
    private var haloView: AvatarStoryIndicatorComponent.IndicatorView?

    private final class CounterView : View {
        private let textView = TextView()
        private let imageView = ImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(imageView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ text: TextViewLayout, image: CGImage) {
            self.textView.update(text)
            self.imageView.image = image
            self.imageView.sizeToFit()
            self.setFrameSize(NSMakeSize(text.layoutSize.width + imageView.frame.width + 4, text.layoutSize.height))
        }
        
        override func layout() {
            super.layout()
            self.imageView.centerY(x: 0)
            textView.centerY(x: self.imageView.frame.maxX + 4)
        }
    }

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(dateView)
        addSubview(titleView)
        addSubview(imageView)
        addSubview(viewCountView)
        viewCountView.userInteractionEnabled = false
        viewCountView.isSelectable = false

        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        titleView.isEventLess = true
        
        dateView.userInteractionEnabled = false
        dateView.isSelectable = false
        dateView.isEventLess = true
        
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
        
        viewCountView.setFrameOrigin(NSMakePoint(item.blockWidth - viewCountView.frame.width - item.viewType.innerInset.right, 5))

        
        titleView.setFrameOrigin(NSMakePoint(leftOffset, 7))
        dateView.setFrameOrigin(NSMakePoint(leftOffset, containerView.frame.height - dateView.frame.height - 7))

        imageView.centerY(x: item.viewType.innerInset.left)
        
        if let haloView = haloView {
            haloView.setFrameOrigin(NSMakePoint(imageView.frame.minX - 3, imageView.frame.minY - 3))
        }
        
        var point = NSMakePoint(item.blockWidth - item.viewType.innerInset.right, containerView.frame.height - 5)
        
        let controls = [self.sharesCountView, self.likesCountView].compactMap { $0 }
        
        for control in controls {
            point.x -= control.frame.width
            control.setFrameOrigin(NSMakePoint(point.x, point.y - control.frame.height))
            point.x -= 4
        }
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
            dateView.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MessageSharedRowItem else {
            return
        }
        
        if let shares = item.sharesCountLayout {
            let current: CounterView
            if let view = self.sharesCountView {
                current = view
            } else {
                current = CounterView(frame: .zero)
                self.addSubview(current)
                self.sharesCountView = current
            }
            current.update(shares, image: theme.icons.channel_stats_shares)

        } else if let view = sharesCountView {
            performSubviewRemoval(view, animated: animated)
            self.sharesCountView = nil
        }
        
        if let likes = item.likesCountLayout {
            let current: CounterView
            if let view = self.likesCountView {
                current = view
            } else {
                current = CounterView(frame: .zero)
                self.addSubview(current)
                self.likesCountView = current
            }
            current.update(likes, image: theme.icons.channel_stats_likes)

        } else if let view = likesCountView {
            performSubviewRemoval(view, animated: animated)
            self.likesCountView = nil
        }
        
        
        dateView.update(item.dateLayout)
        titleView.update(item.titleLayout)
        viewCountView.update(item.viewsCountLayout)
        
        switch item.forward {
        case let .message(message):
            imageView.setPeer(account: item.context.account, peer: message._asMessage().effectiveAuthor, message: message._asMessage())
            if let view = self.haloView {
                performSubviewRemoval(view, animated: animated)
                self.haloView = nil
            }
        case let .story(peer, _):
            imageView.setPeer(account: item.context.account, peer: peer._asPeer())
            let current: AvatarStoryIndicatorComponent.IndicatorView
            if let view = self.haloView {
                current = view
            } else {
                current = AvatarStoryIndicatorComponent.IndicatorView(frame: NSMakeSize(30, 30).bounds)
                self.addSubview(current)
                self.haloView = current
            }
            let component = AvatarStoryIndicatorComponent(stats: .init(totalCount: 1, unseenCount: 1, hasUnseenCloseFriends: false), presentation: theme)
            current.update(component: component, availableSize: NSMakeSize(30, 30), transition: .immediate)
        }
    }
    
    deinit {
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
