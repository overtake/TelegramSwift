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
        case stats(read: [Peer]?, reactions: EngineMessageReactionListContext.State?, customFiles: [TelegramMediaFile]?)
        var isEmpty: Bool {
            switch self {
            case .loading:
                return false
            case let .stats(read, reactions, _):
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
        
        var emojiReferences: [StickerPackReference] {
            switch self {
            case .loading:
                return []
            case let .stats(_, _, files):
                return files?.compactMap { $0.emojiReference } ?? []
            }
        }
        
        func photos(_ message: Message) -> [Peer] {
            switch self {
            case .loading:
                return []
            case let .stats(read, reactions, _):
                var photos:[Peer] = []
                if let reactions = reactions {
                    photos = Array(reactions.items.map { $0.peer._asPeer() }.prefix(3))
                }
                if photos.isEmpty {
                    if photos.count < 3, let read = read {
                        let read = read.filter { read in
                            return !photos.contains(where: { $0.id == read.id })
                        }
                        photos += Array(read.prefix(3 - photos.count))
                    }
                }
                var contains:Set<PeerId> = Set()
                photos = photos.reduce([], { current, value in
                    if !contains.contains(value.id) {
                        contains.insert(value.id)
                        return current + [value]
                    }
                    return current
                })
                return photos
            }
        }
        
        var peers:[(Peer, MessageReaction.Reaction?)] {
            switch self {
            case let .stats(read, reactions, _):
                let readPeers = read ?? []
                let reactionPeers = reactions?.items.map { ($0.peer._asPeer(), $0.reaction) } ?? []
                let read:[(Peer, MessageReaction.Reaction?)] = readPeers.map { ($0, nil) }.filter({ value in
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
            case let .stats(read, reactions, _):
                if let reactions = reactions, !reactions.items.isEmpty {
                    if let read = read, read.count > reactions.totalCount {
                        return strings().chatContextReacted("\(reactions.totalCount)", "\(read.count)")
                    } else {
                        return strings().chatContextReactedFastCountable(reactions.totalCount)
                    }
                } else if let peers = read {
                    if peers.isEmpty {
                        return strings().chatMessageReadStatsEmptyViews
                    } else if peers.count == 1 {
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
        
        let customIds:[Int64] = message.effectiveReactions?.compactMap { value in
            switch value.value {
            case let .custom(fileId):
                return fileId
            default:
                return nil
            }
        } ?? []
        
        let customFiles = context.engine.stickers.resolveInlineStickers(fileIds: customIds) |> map { $0.map { $0.value } } |> map(Optional.init)
        let stats: Signal<MessageReadStats?, NoError> = context.engine.messages.messageReadStats(id: message.id)
        let reactions = self.reactions.state |> map(Optional.init)
        let combined = combineLatest(queue: .mainQueue(), reactions, stats, customFiles)
        
        let readStats: Signal<State, NoError> = .single((nil, nil, nil)) |> then(combined)
            |> deliverOnMainQueue
            |> map { reactions, readStats, customFiles in
                if reactions == nil && readStats == nil {
                    return .loading
                } else {
                    return .stats(read: readStats?.peers.map { $0._asPeer() }, reactions: reactions, customFiles: customFiles)
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
        let makeItem:(_ peer: (Peer, MessageReaction.Reaction?)) -> ContextMenuItem = { [weak chatInteraction] peer in
            let title = peer.0.displayTitle.prefixWithDots(25)
            
            let reaction: ReactionPeerMenu.Source?
            
            if let value = peer.1 {
                let file = availableReactions?.reactions.first(where: {
                    $0.value == value
                })?.staticIcon
                if let file = file {
                    reaction = .builtin(file)
                } else {
                    switch value {
                    case let .custom(fileId):
                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                        reaction = .custom(fileId, message.associatedMedia[mediaId] as? TelegramMediaFile)
                    default:
                        reaction = nil
                    }
                }
            } else {
                reaction = nil
            }
            
            
            let item = ReactionPeerMenu(title: title, handler: {
                chatInteraction?.openInfo(peer.0.id, false, nil, nil)
            }, peer: peer.0, context: context, reaction: reaction)
            let signal:Signal<(CGImage?, Bool), NoError>
            signal = peerAvatarImage(account: context.account, photo: .peer(peer.0, peer.0.smallProfileImage, peer.0.displayLetters, nil), displayDimensions: NSMakeSize(18 * System.backingScale, 18 * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
            _ = signal.start(next: { [weak item] image, _ in
                if let image = image {
                    item?.image = NSImage(cgImage: image, size: NSMakeSize(18, 18))
                }
            })
            return item
        }
       
        var items = state.peers.map {
            makeItem($0)
        }
        
        let hasReactions = state.peers.contains(where: { $0.1 != nil })
        
        if items.count > 1 || hasReactions {
            
            let references:[StickerPackReference] = state.emojiReferences
            
            if !references.isEmpty {
                
                items.append(ContextSeparatorItem())
                
                let sources:[StickerPackPreviewSource] = references.map {
                    .emoji($0)
                }
                let text = strings().chatContextMessageContainsEmojiCountable(sources.count)
                
                let item = MessageContainsPacksMenuItem(title: text, handler: {
                    showModal(with: StickerPackPreviewModalController(context, peerId: context.peerId, references: sources), for: context.window)
                }, packs: references, context: context)
                
                items.append(item)
            }
            
            
            menu.items = items

            
            self.item.submenu = menu
            if let view = self.view, view.mouseInside() || self.isSelected {
                self.interaction?.presentSubmenu(self.item)
            }
            
            menu.loadMore = { [weak self] in
                if let state = self?.state {
                    switch state {
                    case let .stats(_, reactions, _):
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

        size.width += 80
        
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

    private var isLoading: Bool = false
    
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
        if updated != self.photos || self.isLoading != item.state.isLoading(item.message) {
            self.photos = updated
            self.isLoading = item.state.isLoading(item.message)
            if self.isLoading {
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
            if !attr.canViewList {
                return false
            }
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
    enum Source : Equatable {
        case builtin(TelegramMediaFile)
        case custom(Int64, TelegramMediaFile?)
    }
    private let context: AccountContext
    private let reaction: Source?
    private let peer: Peer
    init(title: String, handler:@escaping()->Void, peer: Peer, context: AccountContext, reaction: Source?) {
        self.reaction = reaction
        self.peer = peer
        self.context = context
        super.init(title, handler: handler)
    }
    override var id: Int64 {
        var value: Hasher = Hasher()
        value.combine(peer.id.toInt64())
        if let reaction = reaction {
            switch reaction {
            case let .builtin(file):
                value.combine("builtin")
                value.combine(file.fileId.id)
            case let .custom(fileId, _):
                value.combine("custom")
                value.combine(fileId)
            }
        }
        return Int64(value.finalize().hashValue)
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return ReactionPeerMenuItem(item: self, peer: peer, interaction: interaction, presentation: presentation, context: context, reaction: self.reaction)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ReactionPeerMenuItem : AppMenuRowItem {
    
    
    fileprivate let context: AccountContext
    fileprivate let reaction: ReactionPeerMenu.Source?
    fileprivate let peer: Peer
    init(item: ContextMenuItem, peer: Peer, interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, context: AccountContext, reaction: ReactionPeerMenu.Source?) {
        self.context = context
        self.reaction = reaction
        self.peer = peer
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
        if item.image == nil {
            let image = generateImage(NSMakeSize(imageSize, imageSize), rotatedContext: { size, ctx in
                ctx.clear(size.bounds)
                ctx.setFillColor(presentation.borderColor.cgColor)
                ctx.fillEllipse(in: size.bounds)
            })!
            item.image = NSImage(cgImage: image, size: NSMakeSize(imageSize, imageSize))
        }
    }
    
    override var effectiveSize: NSSize {
        var size = super.effectiveSize
        if let _ = reaction {
            size.width += 16 + 2 + self.innerInset
        }
        if let s = PremiumStatusControl.controlSize(peer, false) {
            size.width += s.width + 2
        }
        return size
    }
    
    override func viewClass() -> AnyClass {
        return ReactionPeerMenuItemView.self
    }
}

private final class ReactionPeerMenuItemView : AppMenuRowView {
    private let imageView = AnimationLayerContainer(frame: NSMakeRect(0, 0, 16, 16))
    private var statusControl: PremiumStatusControl?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? ReactionPeerMenuItem else {
            return
        }
        
        if let statusControl = statusControl {
            statusControl.centerY(x: self.textX + item.text.layoutSize.width + 2)
            imageView.centerY(x: self.rightX - imageView.frame.width)
        }
        
        imageView.centerY(x: self.rightX - imageView.frame.width)

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        let previous = self.item as? ReactionPeerMenuItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? ReactionPeerMenuItem else {
            return
        }
        
        let control = PremiumStatusControl.control(item.peer, account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, isSelected: false, cached: self.statusControl, animated: animated)
        if let control = control {
            self.statusControl = control
            self.addSubview(control)
        } else if let view = self.statusControl {
            performSubviewRemoval(view, animated: animated)
            self.statusControl = nil
        }
                
        self.imageView.isHidden = item.reaction == nil
        
        let reactionSize = NSMakeSize(16, 16)
        
        if let reaction = item.reaction {
            
            
            if previous?.reaction != item.reaction {
                let layer: InlineStickerItemLayer
                switch reaction {
                case let .custom(fileId, file):
                    layer = .init(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: fileId, file: file, emoji: ""), size: reactionSize)
                case let .builtin(file):
                    layer = .init(account: item.context.account, file: file, size: reactionSize)
                }
                self.imageView.updateLayer(layer, animated: animated)
            }
            
        }
        needsLayout = true
    }
}


final class MessageContainsPacksMenuItem : ContextMenuItem {
   
    private let context: AccountContext
    private let packs: [StickerPackReference]
    init(title: String, handler:@escaping()->Void, packs: [StickerPackReference], context: AccountContext) {
        self.packs = packs
        self.context = context
        super.init(title, handler: handler, itemImage: MenuAnimation.menu_smile.value)
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return MessageContainsPacksItem(item: self, packs: packs, interaction: interaction, presentation: presentation, context: context)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



final class MessageContainsPacksItem : AppMenuRowItem {

    let packs: [StickerPackReference]
    let context: AccountContext
    
    init(item: ContextMenuItem, packs: [StickerPackReference], interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, context: AccountContext) {
        self.packs = packs
        self.context = context
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
    }
    
    public override var height: CGFloat {
        return 28 + 13
    }
    
//    override var effectiveSize: NSSize {
//        var size = super.effectiveSize
//        if let _ = reaction {
//            size.width += 16 + 2 + self.innerInset
//        }
//        if let s = PremiumStatusControl.controlSize(peer, false) {
//            size.width += s.width + 2
//        }
//        return size
//    }
    
    override func viewClass() -> AnyClass {
        return MessageContainsPacksItemView.self
    }

}

private final class MessageContainsPacksItemView: AppMenuRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        backgroundColor = .random
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
