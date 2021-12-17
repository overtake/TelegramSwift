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
        case stats(read: [Peer]?, reactions: EngineMessageReactionListContext.State?)
        var isEmpty: Bool {
            switch self {
            case .loading:
                return false
            case let .stats(read, reactions):
                var readIsEmpty = true
                var reactionsIsEmpty = true
                if let read = read {
                    readIsEmpty = read.isEmpty
                }
                if let reactions = reactions {
                    reactionsIsEmpty = reactions.items.isEmpty
                }
                return readIsEmpty && reactionsIsEmpty
            }
        }
        
        func isLoading(_ message: Message) -> Bool {
            return self.text(message).isEmpty
        }
        
        func photos(_ message: Message) -> [Peer] {
            switch self {
            case .loading:
                return []
            case let .stats(read, reactions):
                var photos:[Peer] = []
                if let reactions = reactions {
                    photos = Array(reactions.items.map { $0.peer._asPeer() }.prefix(3))
                }
                if photos.count < 3, let read = read {
                    let read = read.filter { read in
                        return !photos.contains(where: { $0.id == read.id })
                    }
                    photos += Array(read.prefix(3 - photos.count))
                }
                return photos
            }
        }
        
        var peers:[(Peer, String?)] {
            switch self {
            case let .stats(read, reactions):
                let readPeers = read ?? []
                let reactionPeers = reactions?.items.map { ($0.peer._asPeer(), $0.reaction) } ?? []
                let read:[(Peer, String?)] = readPeers.map { ($0, nil) }.filter({ value in
                    return !reactionPeers.contains(where: {
                        $0.0.id == value.0.id
                    })
                })
                return reactionPeers + read
            default:
                return []
            }
        }
 
        
        func text(_ message: Message) -> String {
            switch self {
            case let .stats(read, reactions):
                if let reactions = reactions, !reactions.items.isEmpty {
                    if let read = read {
                        return strings().chatContextReacted("\(reactions.totalCount)", "\(read.count + reactions.totalCount)")
                    } else {
                        return strings().chatContextReactedFastCountable(reactions.totalCount)
                    }
                } else if let peers = read {
                    if peers.count == 1 {
                        return peers[0].compactDisplayTitle.prefixWithDots(20)
                    } else {
                        if let media = message.media.first as? TelegramMediaFile {
                            if media.isInstantVideo {
                                return strings().chatMessageReadStatsWatchedCountable(peers.count)
                            } else if media.isVoice {
                                return strings().chatMessageReadStatsListenedCountable(peers.count)
                            } else {
                                return strings().chatMessageReadStatsSeenCountable(peers.count)
                            }
                        } else {
                            return strings().chatMessageReadStatsSeenCountable(peers.count)
                        }
                    }
                } else {
                    return strings().chatMessageReadStatsEmptyViews
                }
            case .loading:
                if let attr = message.reactionsAttribute {
                    let count = attr.reactions.reduce(0, {
                        $0 + Int($1.count)
                    })
                    if count != 0 {
                        return strings().chatContextReactedFastCountable(count)
                    } else {
                        return ""
                    }
                } else {
                    return ""
                }
            }
        }
    }
    
    fileprivate let message: Message
    fileprivate let context: AccountContext
    private let disposable = MetaDisposable()
    private let chatInteraction: ChatInteraction
    
    fileprivate var state: State = .loading
    private let availableReactions: AvailableReactions?
    private let reactions: EngineMessageReactionListContext
    
    private let menu = ContextMenu()
    
    init(interaction: AppMenuBasicItem.Interaction, chatInteraction: ChatInteraction, item: ContextMenuItem, presentation: AppMenu.Presentation, context: AccountContext, message: Message, availableReactions: AvailableReactions?) {
        self.message = message
        self.context = context
        self.reactions = context.engine.messages.messageReactionList(message: .init(self.message), reaction: nil)
        self.chatInteraction = chatInteraction
        self.availableReactions = availableReactions
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
        
        self.load()
    }
    
    func load() {
        
        let stats: Signal<MessageReadStats?, NoError> = context.engine.messages.messageReadStats(id: message.id)
        let reactions = self.reactions.state |> map(Optional.init)
        let combined = combineLatest(queue: .mainQueue(), reactions, stats)
        
        let readStats: Signal<State, NoError> = .single((nil, nil)) |> then(combined)
            |> deliverOnMainQueue
            |> map { reactions, readStats in
                if reactions == nil && readStats == nil {
                    return .loading
                } else {
                    return .stats(read: readStats?.peers.map { $0._asPeer() }, reactions: reactions)
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
        let availableReactions = self.availableReactions
        let makeItem:(_ peer: (Peer, String?)) -> ContextMenuItem = { [weak chatInteraction] peer in
            let title = peer.0.displayTitle.prefixWithDots(25)
            
            let reaction = availableReactions?.reactions.first(where: {
                $0.value.fixed == peer.1?.fixed
            })?.staticIcon
            
            let item = ReactionPeerMenu(title: title, handler: {
                chatInteraction?.openInfo(peer.0.id, false, nil, nil)
            }, peerId: peer.0.id, context: context, reaction: reaction)
            let signal:Signal<(CGImage?, Bool), NoError>
            signal = peerAvatarImage(account: context.account, photo: .peer(peer.0, peer.0.smallProfileImage, peer.0.displayLetters, nil), displayDimensions: NSMakeSize(18 * System.backingScale, 18 * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
            _ = signal.start(next: { [weak item] image, _ in
                if let image = image {
                    item?.image = NSImage(cgImage: image, size: NSMakeSize(18, 18))
                }
            })
            return item
        }
       
        let items = state.peers.map {
            makeItem($0)
        }
        
        let hasReactions = state.peers.contains(where: { $0.1 != nil })
        
        if items.count > 1 || hasReactions {
            
            menu.items = items
            self.item.submenu = menu
            if let view = self.view, view.mouseInside() || self.isSelected {
                self.interaction?.presentSubmenu(self.item)
            }
            
            menu.loadMore = { [weak self] in
                if let state = self?.state {
                    switch state {
                    case let .stats(_, reactions):
                        if let reactions = reactions, reactions.canLoadMore {
                            self?.reactions.loadMore()
                        }
                    default:
                        break
                    }
                }
            }
            self.item.handler = nil
        } else {
            self.item.submenu = nil
            self.interaction?.cancelSubmenu(self.item)
            if let item = items.first {
                self.item.handler = item.handler
            } else {
                self.item.handler = nil
            }
            
        }
        
        self.item.title = state.text(self.message)
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var effectiveSize: NSSize {
        var size = super.effectiveSize
        
        let viewSize = NSMakeSize(15 * CGFloat(3) - (CGFloat(3) - 1) * 1, 15)
        size.width += viewSize.width + 6

        size.width += 30
        
        return size
    }
    
    override func viewClass() -> AnyClass {
        return MessageReadMenuItemView.self
    }
}

private final class MessageReadMenuItemView : AppMenuRowView {
    
    private var photos:[PeerId]? = nil
    
    final class AvatarContentView: View {
        private var disposable: Disposable?
        private var images:[CGImage] = []
        init(context: AccountContext, message: Message, peers:[Peer]?, size: NSSize) {
            
            
            let count: CGFloat = peers != nil ? CGFloat(peers!.count) : 3
            let viewSize = NSMakeSize(size.width * count - (count - 1) * 1, size.height)
            
            super.init(frame: CGRect(origin: .zero, size: viewSize))
            
            if let peers = peers {
                let signal:Signal<[(CGImage?, Bool)], NoError> = combineLatest(peers.map { peer in
                    return peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, nil), displayDimensions: NSMakeSize(size.width * System.backingScale, size.height * System.backingScale), font: .avatar(6), genCap: true, synchronousLoad: false)
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
                let image = generateImage(NSMakeSize(size.width, size.height), scale: System.backingScale, rotatedContext: { size, ctx in
                    ctx.clear(size.bounds)
                    ctx.setFillColor(AppMenu.Presentation.current(theme.colors).disabledTextColor.withAlphaComponent(0.5).cgColor)
                    ctx.fillEllipse(in: size.bounds)
                })!
                self.images = [image, image, image]
            }
           
        }
        
        override func draw(_ layer: CALayer, in context: CGContext) {
            super.draw(layer, in: context)
            
            
            let mergedImageSize: CGFloat = frame.height
            let mergedImageSpacing: CGFloat = frame.height - 2
            
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
        if item.state.isLoading(item.message) {
            if loadingView == nil {
                loadingView = View(frame: NSMakeRect(0, 0, 20, 6))
                loadingView?.layer?.cornerRadius = 3
                loadingView?.backgroundColor = item.presentation.disabledTextColor.withAlphaComponent(0.5)
                self.addSubview(loadingView!)
            }
        } else {
            if let loadingView = loadingView {
                performSubviewRemoval(loadingView, animated: animated)
                self.loadingView = nil
            }
        }
        let contentView: AvatarContentView?
        
        let photos = item.state.photos(item.message)
        
        let updated = photos.map { $0.id }
        if updated != self.photos {
            self.photos = updated
            
            if item.state.isLoading(item.message) {
                contentView = .init(context: item.context, message: item.message, peers: nil, size: NSMakeSize(18, 18))
            } else {
                if !item.state.isEmpty {
                    contentView = .init(context: item.context, message: item.message, peers: item.state.photos(item.message), size: NSMakeSize(18, 18))
                } else {
                    contentView = nil
                }
            }
            if let contentView = self.contentView {
                performSubviewRemoval(contentView, animated: animated)
            }
            self.contentView = contentView
            if let contentView = contentView {
                addSubview(contentView)
                contentView.centerY(x: self.rightX - contentView.frame.width - 2)
                if animated {
                    contentView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        guard let item = self.item as? MessageReadMenuRowItem else {
            return
        }
        if let contentView = contentView {
            if item.item.submenu != nil {
                contentView.centerY(x: self.rightX - contentView.frame.width - 4)
            } else {
                contentView.centerY(x: self.rightX - contentView.frame.width)
            }
        }
        if let loadingView = loadingView {
            let contentSize = contentView?.frame.width ?? 0
            loadingView.setFrameSize(NSMakeSize(self.rightX - self.textX - 10 - contentSize, loadingView.frame.height))
            loadingView.centerY(x: self.textX)
        }
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
        super.init("", handler: nil, itemImage: message.hasReactions ? MenuAnimation.menu_reactions.value : MenuAnimation.menu_seen.value)
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
        
        
        if let attr = message.reactionsAttribute, !attr.reactions.isEmpty {
            if peer.isGroup || peer.isSupergroup {
                return true
            }
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




final class ReactionPeerMenu : ContextMenuItem {
    
    private let context: AccountContext
    private let reaction: TelegramMediaFile?
    private let peerId: PeerId
    init(title: String, handler:@escaping()->Void, peerId: PeerId, context: AccountContext, reaction: TelegramMediaFile?) {
        self.reaction = reaction
        self.peerId = peerId
        self.context = context
        super.init(title, handler: handler)
    }
    override var id: Int64 {
        return peerId.toInt64()
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return ReactionPeerMenuItem(item: self, interaction: interaction, presentation: presentation, context: context, reaction: self.reaction)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ReactionPeerMenuItem : AppMenuRowItem {
    fileprivate let context: AccountContext
    fileprivate let reaction: TelegramMediaFile?
    init(item: ContextMenuItem, interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, context: AccountContext, reaction: TelegramMediaFile?) {
        self.context = context
        self.reaction = reaction
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
    }
    
    override var effectiveSize: NSSize {
        var size = super.effectiveSize
        size.width += 16 + 2 + self.innerInset
        return size
    }
    
    override func viewClass() -> AnyClass {
        return ReactionPeerMenuItemView.self
    }
}

private final class ReactionPeerMenuItemView : AppMenuRowView {
    private let imageView = TransformImageView(frame: NSMakeRect(0, 0, 16, 16))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        imageView.centerY(x: self.rightX - imageView.frame.width)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ReactionPeerMenuItem else {
            return
        }
                
        self.imageView.isHidden = item.reaction == nil
        
        let reactionSize = NSMakeSize(16, 16)
        
        if let reaction = item.reaction {
            let arguments = TransformImageArguments(corners: .init(), imageSize: reactionSize, boundingSize: reactionSize, intrinsicInsets: NSEdgeInsetsZero, emptyColor: .color(.clear))
            
            self.imageView.setSignal(signal: cachedMedia(media: reaction, arguments: arguments, scale: System.backingScale, positionFlags: nil), clearInstantly: true)

            if !self.imageView.isFullyLoaded {
                self.imageView.setSignal(chatMessageImageFile(account: item.context.account, fileReference: .standalone(media: reaction), scale: System.backingScale), cacheImage: { result in
                    cacheMedia(result, media: reaction, arguments: arguments, scale: System.backingScale)
                })
            }

            self.imageView.set(arguments: arguments)

        }
        needsLayout = true
    }
}


















/*
 
 
 
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

 */
