//
//  ChannelRecentPostRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore




class ChannelRecentPostRowItem: GeneralRowItem {
    fileprivate let viewsCountLayout: TextViewLayout
    fileprivate let sharesCountLayout: TextViewLayout?
    fileprivate let likesCountLayout: TextViewLayout?

    fileprivate let titleLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    fileprivate let postStats: StatsPostItem
    fileprivate let contentImageMedia: TelegramMediaImage?
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, postStats: StatsPostItem, viewType: GeneralViewType, action: @escaping()->Void) {
        self.context = context
        self.postStats = postStats
        
        self.contentImageMedia = postStats.image
        
        self.titleLayout = TextViewLayout(NSAttributedString.initialize(string: postStats.title, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.dateLayout = TextViewLayout(NSAttributedString.initialize(string: stringForFullDate(timestamp: postStats.timestamp), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        
        let views = postStats.views
        let shares = postStats.shares
        let likes = postStats.likes

        let viewsString = strings().channelStatsViewsCountCountable(views).replacingOccurrences(of: "\(views)", with: views.formattedWithSeparator)

        viewsCountLayout = TextViewLayout(NSAttributedString.initialize(string: viewsString, color: theme.colors.text, font: .normal(.short)),maximumNumberOfLines: 1)
        
        if shares > 0 {
            sharesCountLayout = TextViewLayout(NSAttributedString.initialize(string: shares.formattedWithSeparator, color: theme.colors.grayText, font: .normal(.short)),maximumNumberOfLines: 1)
        } else {
            sharesCountLayout = nil
        }
        if likes > 0 {
            likesCountLayout = TextViewLayout(NSAttributedString.initialize(string: likes.formattedWithSeparator, color: theme.colors.grayText, font: .normal(.short)),maximumNumberOfLines: 1)
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

        
        let likesAndShares = (sharesCountLayout?.layoutSize.width ?? 0) + (likesCountLayout?.layoutSize.width ?? 0)
        
        let titleAndDateWidth: CGFloat = blockWidth - viewType.innerInset.left - (contentImageMedia != nil ? 34 + 10 : 0) - max(viewsCountLayout.layoutSize.width, likesAndShares + 20) - 10 - viewType.innerInset.right

        titleLayout.measure(width: titleAndDateWidth)
        dateLayout.measure(width: titleAndDateWidth)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return ChannelRecentPostRowView.self
    }
}


private final class ChannelRecentPostRowView : GeneralContainableRowView {
    
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
    
    private let viewCountView = TextView()
    
    private var sharesCountView: CounterView?
    private var likesCountView: CounterView?
    
    private let titleView = TextView()
    private let dateView = TextView()
    private let fetchDisposable = MetaDisposable()
    private var imageView: TransformImageView?
    private var haloView: AvatarStoryIndicatorComponent.IndicatorView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(viewCountView)
        addSubview(titleView)
        addSubview(dateView)
        
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        titleView.isEventLess = true
        
        viewCountView.userInteractionEnabled = false
        viewCountView.isSelectable = false
        viewCountView.isEventLess = true
        
        dateView.userInteractionEnabled = false
        dateView.isSelectable = false
        dateView.isEventLess = true
        
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
            guard let item = self?.item as? ChannelRecentPostRowItem else {
                return
            }
            item.action()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? ChannelRecentPostRowItem else {
            return
        }
        
        viewCountView.setFrameOrigin(NSMakePoint(item.blockWidth - viewCountView.frame.width - item.viewType.innerInset.right, 5))
        

        let leftOffset: CGFloat = (imageView != nil ? 34 + 10 : 0) + item.viewType.innerInset.left
        
        titleView.setFrameOrigin(NSMakePoint(leftOffset, 5))
        dateView.setFrameOrigin(NSMakePoint(leftOffset, containerView.frame.height - dateView.frame.height - 5))
        
        imageView?.centerY(x: item.viewType.innerInset.left)
        if let imageView = imageView, let haloView = haloView {
            haloView.setFrameOrigin(NSMakePoint(imageView.frame.minX - 3, imageView.frame.minY - 3))
        }
        //       // sharesCountView.setFrameOrigin(NSMakePoint(item.blockWidth - sharesCountView.frame.width - item.viewType.innerInset.right, containerView.frame.height - sharesCountView.frame.height - 5))

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
        
        guard let item = item as? ChannelRecentPostRowItem else {
            return
        }
        
        viewCountView.update(item.viewsCountLayout)
        
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

        let imageSize = item.postStats.isStory ? NSMakeSize(30, 30) : NSMakeSize(34, 34)
        
        let arguments = TransformImageArguments(corners: .init(radius: item.postStats.isStory ? imageSize.height / 2 : 4), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
        
        if let reference = item.postStats.imageReference {
            if imageView == nil {
                self.imageView = TransformImageView(frame: imageSize.bounds)
                addSubview(self.imageView!)
            }
            let updateIconImageSignal = chatWebpageSnippetPhoto(account: item.context.account, imageReference: reference, scale: backingScaleFactor, small:true)
            imageView?.setSignal(updateIconImageSignal)
            imageView?.set(arguments: arguments)
            imageView?.setFrameSize(imageSize)
            fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: item.context.account, imageReference: reference).start())
            
        } else {
            imageView?.removeFromSuperview()
            imageView = nil
            fetchDisposable.set(nil)
        }
        
        if item.postStats.isStory {
            let current: AvatarStoryIndicatorComponent.IndicatorView
            if let view = self.haloView {
                current = view
            } else {
                current = AvatarStoryIndicatorComponent.IndicatorView(frame: imageSize.bounds)
                self.addSubview(current)
                self.haloView = current
            }
            let component = AvatarStoryIndicatorComponent(stats: .init(totalCount: 1, unseenCount: 1, hasUnseenCloseFriends: false), presentation: theme)
            current.update(component: component, availableSize: imageSize, transition: .immediate)
        } else if let view = self.haloView {
            performSubviewRemoval(view, animated: animated)
            self.haloView = nil
        }
    }

    deinit {
        fetchDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
