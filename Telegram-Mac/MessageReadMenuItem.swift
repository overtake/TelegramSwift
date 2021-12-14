//
//  MessageViewsMenuItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import TGUIKit
import Postbox
import AppKit


final class MessageReadMenuRowItem : AppMenuRowItem {
    
    enum State {
        case loading
        case empty
        case stats([Peer])
        
        var isEmpty: Bool {
            switch self {
            case let .stats(peers):
                return peers.isEmpty
            default:
                return true
            }
        }
    }
    
    fileprivate let message: Message
    fileprivate let context: AccountContext
    private let disposable = MetaDisposable()
    private let chatInteraction: ChatInteraction
    
    fileprivate var state: State = .loading
    private let availableReactions: AvailableReactions?
    init(interaction: AppMenuBasicItem.Interaction, chatInteraction: ChatInteraction, item: ContextMenuItem, presentation: AppMenu.Presentation, context: AccountContext, message: Message, availableReactions: AvailableReactions?) {
        self.message = message
        self.context = context
        self.chatInteraction = chatInteraction
        self.availableReactions = availableReactions
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
        
        self.load()
    }
    
    func load() {
        let readStats: Signal<State, NoError> = .single(nil) |> then(context.engine.messages.messageReadStats(id: message.id))
            |> deliverOnMainQueue
            |> map { value in
                if let value = value {
                    if !value.peers.isEmpty {
                        return .stats(value.peers.map { $0._asPeer() })
                    } else {
                        return .empty
                    }
                } else {
                    return .loading
                }
            }

        disposable.set(readStats.start(next: { [weak self] state in
            self?.updateState(state, animated: true)
        }))
    }
    
    private func updateState(_ state: State, animated: Bool) {
        
        self.state = state
        
        let chatInteraction = self.chatInteraction
        let message = self.message
        let context = self.context
        let makeItem:(_ peer: Peer) -> ContextMenuItem = { [weak chatInteraction] peer in
            let title = peer.displayTitle.prefixWithDots(25)
            let item = ContextMenuItem(title, handler: {
                chatInteraction?.openInfo(peer.id, false, nil, nil)
            })
            let signal:Signal<(CGImage?, Bool), NoError>
            if peer.id == context.peerId {
                let icon = theme.icons.searchSaved
                signal = generateEmptyPhoto(NSMakeSize(18, 18), type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(10, 10)), cornerRadius: nil)) |> deliverOnMainQueue |> map { ($0, true) }
            } else {
                signal = peerAvatarImage(account: self.context.account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, message), displayDimensions: NSMakeSize(18 * System.backingScale, 18 * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
            }
            _ = signal.start(next: { [weak item] image, _ in
                if let image = image {
                    item?.image = NSImage(cgImage: image, size: NSMakeSize(18, 18))
                }
            })
            return item
        }
        
        
        let text: String
        switch state {
        case .empty:
            if let media = message.media.first as? TelegramMediaFile {
                if media.isInstantVideo {
                    text = strings().chatMessageReadStatsEmptyWatches
                } else if media.isVoice {
                    text = strings().chatMessageReadStatsEmptyListens
                } else {
                    text = strings().chatMessageReadStatsEmptyViews
                }
            } else {
                text = strings().chatMessageReadStatsEmptyViews
            }
        case let .stats(peers):
            if peers.count == 1 {
                text = peers[0].displayTitle.prefixWithDots(20)
            } else {
                if let media = message.media.first as? TelegramMediaFile {
                    if media.isInstantVideo {
                        text = strings().chatMessageReadStatsWatchedCountable(peers.count)
                    } else if media.isVoice {
                        text = strings().chatMessageReadStatsListenedCountable(peers.count)
                    } else {
                        text = strings().chatMessageReadStatsSeenCountable(peers.count)
                    }
                } else {
                    text = strings().chatMessageReadStatsSeenCountable(peers.count)
                }
            }
            let menu = ContextMenu()
            
//            menu.addItem(ReactionsHeaderMenuItem(context: context, availableReactions: self.availableReactions))
//            menu.addItem(ContextSeparatorItem())
            
            for peer in peers {
                menu.addItem(makeItem(peer))
            }
            self.item.submenu = menu
        case .loading:
            text = ""
        }
        self.item.title = text
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var effectiveSize: NSSize {
        var size = super.effectiveSize
        
        switch state {
        case .loading:
            let viewSize = NSMakeSize(15 * 3 - (3 - 1) * 1, 15)
            size.width += viewSize.width + 6
        case let .stats(peers):
            let current = Array(peers.prefix(3))
            let viewSize = NSMakeSize(15 * CGFloat(current.count) - (CGFloat(current.count) - 1) * 1, 15)
            size.width += viewSize.width + 6
        default:
            break
        }
        return size
    }
    
    override func viewClass() -> AnyClass {
        return MessageReadMenuItemView.self
    }
}

private final class MessageReadMenuItemView : AppMenuRowView {
    
    
    
    final class AvatarContentView: View {
        private var disposable: Disposable?
        private var images:[CGImage] = []
        init(context: AccountContext, message: Message, peers:[Peer]?, size: NSSize) {
            
            let count: CGFloat = peers != nil ? CGFloat(peers!.count) : 3
            let viewSize = NSMakeSize(size.width * count - (count - 1) * 1, size.height)
            
            super.init(frame: CGRect(origin: .zero, size: viewSize))
            
            if let peers = peers {
                let signal:Signal<[(CGImage?, Bool)], NoError> = combineLatest(peers.map { peer in
                    return peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, nil), displayDimensions: size, scale: System.backingScale, font: .avatar(size.height / 3 + 3), genCap: true, synchronousLoad: false)
                })
                
                
                let disposable = (signal
                    |> deliverOnMainQueue).start(next: { [weak self] values in
                        guard let strongSelf = self else {
                            return
                        }
                        let images = values.compactMap { $0.0 }
                        strongSelf.updateImages(images)
                    })
                self.disposable = disposable
            } else {
                let image = generateImage(size, rotatedContext: { size, ctx in
                    ctx.clear(size.bounds)
                    ctx.setFillColor(theme.colors.grayUI.withAlphaComponent(0.8).cgColor)
                    ctx.fillEllipse(in: size.bounds)
                })!
                self.images = [image, image, image]
            }
           
        }
        
        override func draw(_ layer: CALayer, in context: CGContext) {
            super.draw(layer, in: context)
            
            
            let mergedImageSize: CGFloat = 15.0
            let mergedImageSpacing: CGFloat = 13.0
            
            context.setBlendMode(.copy)
            context.setFillColor(NSColor.clear.cgColor)
            context.fill(bounds)
            
            context.setBlendMode(.copy)
            
            
            var currentX = mergedImageSize + mergedImageSpacing * CGFloat(images.count - 1) - mergedImageSize
            for i in 0 ..< self.images.count {
                
                let image = self.images[i]
                
                context.saveGState()
                
                context.translateBy(x: frame.width / 2.0, y: frame.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -frame.width / 2.0, y: -frame.height / 2.0)
                
                let imageRect = CGRect(origin: CGPoint(x: currentX, y: 0.0), size: CGSize(width: mergedImageSize, height: mergedImageSize))
                context.setFillColor(NSColor.clear.cgColor)
                context.fillEllipse(in: imageRect.insetBy(dx: -1.0, dy: -1.0))
                
                context.draw(image, in: imageRect)
                
                currentX -= mergedImageSpacing
                context.restoreGState()
            }
        }
        
        private func updateImages(_ images: [CGImage]) {
            self.images = images
            needsDisplay = true
        }
        
        deinit {
            disposable?.dispose()
        }
        
        required init?(coder decoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }


    private var contentView: AvatarContentView?
    private var loadingView: View?

    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MessageReadMenuRowItem else {
            return
        }
        switch item.state {
        case .loading:
            if loadingView == nil {
                loadingView = View(frame: NSMakeRect(0, 0, 20, 6))
                loadingView?.layer?.cornerRadius = 3
                loadingView?.backgroundColor = item.presentation.disabledTextColor
                self.addSubview(loadingView!)
            }
        default:
            if let loadingView = loadingView {
                performSubviewRemoval(loadingView, animated: animated)
                
            }
        }
        let contentView: AvatarContentView?
        switch item.state {
        case .loading:
            contentView = .init(context: item.context, message: item.message, peers: nil, size: NSMakeSize(15, 15))
        case let .stats(peers):
            contentView = .init(context: item.context, message: item.message, peers: Array(peers.prefix(3)), size: NSMakeSize(15, 15))
        default:
            contentView = nil
        }
        if let contentView = self.contentView {
            performSubviewRemoval(contentView, animated: animated)
        }
        self.contentView = contentView
        if let contentView = contentView {
            addSubview(contentView)
            if animated {
                contentView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        }
    }
    
    override func layout() {
        super.layout()
        if let contentView = contentView {
            contentView.centerY(x: self.rightX - contentView.frame.width)
        }
        loadingView?.centerY(x: self.textX)
    }
}


final class MessageReadMenuItem : ContextMenuItem {
    
   
        
    fileprivate let context: AccountContext
    fileprivate let message: Message
    private let chatInteraction: ChatInteraction
    private let availableReactions: AvailableReactions?
    init(context: AccountContext, chatInteraction: ChatInteraction, message: Message, availableReactions: AvailableReactions?) {
        self.context = context
        self.message = message
        self.availableReactions = availableReactions
        self.chatInteraction = chatInteraction
        super.init("", handler: nil, itemImage: MenuAnimation.menu_seen.value)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return MessageReadMenuRowItem(interaction: interaction, chatInteraction: chatInteraction, item: self, presentation: presentation, context: context, message: message, availableReactions: availableReactions)
    }
    
    static func canViewReadStats(message: Message, chatInteraction: ChatInteraction, appConfig: AppConfiguration) -> Bool {
        
        guard let peer = message.peers[message.id.peerId] else {
            return false
        }
        
        if message.flags.contains(.Incoming) {
            return false
        }
        for media in message.media {
            if let _ = media as? TelegramMediaAction {
                return false
            }
        }

        for attr in message.attributes {
            if let attr = attr as? ConsumableContentMessageAttribute {
                if !attr.consumed {
                    return false
                }
            }
        }
        var maxParticipantCount = 50
        var maxTimeout = 7 * 86400
        if let data = appConfig.data {
            if let value = data["chat_read_mark_size_threshold"] as? Double {
                maxParticipantCount = Int(value)
            }
            if let value = data["chat_read_mark_expire_period"] as? Double {
                maxTimeout = Int(value)
            }
        }

        switch peer {
        case let channel as TelegramChannel:
            if case .broadcast = channel.info {
                return false
            } else {
                if let cachedData = chatInteraction.getCachedData() as? CachedChannelData {
                    let members = cachedData.participantsSummary.memberCount ?? 0
                    if members > maxParticipantCount {
                        return false
                    }
                } else {
                    return false
                }
            }
            
        case let group as TelegramGroup:
            if group.participantCount > maxParticipantCount {
                return false
            }
        default:
            return false
        }

        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if Int64(message.timestamp) + Int64(maxTimeout) < Int64(timestamp) {
            return false
        }

        return true
    }

}




final class ReactionsHeaderMenuItem : ContextMenuItem {
    
    private let context: AccountContext
    private let availableReactions: AvailableReactions?
    init(context: AccountContext, availableReactions: AvailableReactions?) {
        self.context = context
        self.availableReactions = availableReactions
        super.init("")
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func stickClass() -> AnyClass {
        return ReactionsHeaderMenuRowItem.self
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return ReactionsHeaderMenuRowItem(.zero, item: self, presentation: presentation, interaction: interaction, context: self.context, availableReactions: self.availableReactions)
    }
}

private final class ReactionsHeaderMenuRowItem : TableStickItem {
    fileprivate let context: AccountContext?
    fileprivate let availableReactions: AvailableReactions?
    fileprivate let presentaion: AppMenu.Presentation?
    fileprivate let interaction: AppMenuBasicItem.Interaction?
    fileprivate let item: ContextMenuItem?
    init(_ initialSize: NSSize, item: ContextMenuItem, presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction, context: AccountContext, availableReactions: AvailableReactions?) {
        self.context = context
        self.availableReactions = availableReactions
        self.item = item
        self.presentaion = presentation
        self.interaction = interaction
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        self.context = nil
        self.availableReactions = nil
        self.item = nil
        self.presentaion = nil
        self.interaction = nil
        super.init(initialSize)
    }
    
    
    override func viewClass() -> AnyClass {
        return ReactionsHeaderMenuRowView.self
    }
    override var height: CGFloat {
        return 26 + 4
    }
}

private final class ReactionsHeaderMenuRowView: TableStickView {
    private let tableView = HorizontalTableView(frame: .zero)
    private let visualView = NSVisualEffectView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(visualView)
        addSubview(tableView)
        self.visualView.wantsLayer = true
        self.visualView.state = .active
        self.visualView.blendingMode = .behindWindow

        tableView.getBackgroundColor = {
            .clear
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        visualView.frame = bounds
        tableView.frame = self.bounds.insetBy(dx: 0, dy: 2)
    }
    
    override func updateIsVisible(_ visible: Bool, animated: Bool) {
        
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ReactionsHeaderMenuRowItem else {
            return
        }
        
        
        
        tableView.removeAll()
        
        guard let presentation = item.presentaion else {
            return
        }
        guard let context = item.context else {
            return
        }
        
        if presentation.colors.isDark {
            visualView.material = .dark
        } else {
            visualView.material = .light
        }
        
        let data = ChatReactionsLayout.Theme(bgColor: .clear, textColor: presentation.textColor, borderColor: .clear, selectedColor: presentation.disabledTextColor.withAlphaComponent(0.4), reactionSize: NSMakeSize(16, 16), insetOuter: 10, insetInner: 5, renderType: .list, isIncoming: false, isOutOfBounds: false, hasWallpaper: false)
        
        if let availableReactions = item.availableReactions {
            var index: Int = 0
            _ = tableView.addItem(item: GeneralRowItem(.zero, height: 4, backgroundColor: .clear))
            for reaction in availableReactions.reactions {
                let layout = ChatReactionsLayout.Reaction(value: MessageReaction(value: reaction.value, count: 55, isSelected: index == 0), index: index, available: reaction, presentation: data, action: {
                    
                })
                layout.rect = layout.minimiumSize.bounds
                index += 1
                _ = tableView.addItem(item: ReactionMenuItem(.zero, context: context, layout: layout))
                
                if reaction != availableReactions.reactions.last {
                    _ = tableView.addItem(item: GeneralRowItem(.zero, height: 4, backgroundColor: .clear))
                }
            }
            _ = tableView.addItem(item: GeneralRowItem(.zero, height: 4, backgroundColor: .clear))
        }

        needsLayout = true
    }
}


private final class ReactionMenuItem : TableRowItem {
    fileprivate let layout: ChatReactionsLayout.Reaction
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, context: AccountContext, layout: ChatReactionsLayout.Reaction) {
        self.layout = layout
        self.context = context
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return layout.value.value
    }
    
    override var width: CGFloat {
        return layout.minimiumSize.height
    }
    
    override var height: CGFloat {
        return layout.minimiumSize.width
    }
    
    override func viewClass() -> AnyClass {
        return ReactionMenuItemView.self
    }
}

private final class ReactionMenuItemView : HorizontalRowView {
    private let view:ChatReactionsView.ReactionView = .init(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        view.center()
    }
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ReactionMenuItem else {
            return
        }
        view.setFrameSize(item.layout.minimiumSize)
        view.update(with: item.layout, account: item.context.account, animated: animated)
        view.updateLayout(size: item.layout.minimiumSize, transition: .immediate)
        
        needsLayout = true
    }
}
