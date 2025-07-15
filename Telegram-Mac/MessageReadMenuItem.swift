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
import TelegramMedia

final class MessageReadMenuRowItem : AppMenuRowItem {
    
    enum State {
        case loading
        case stats(read: [Peer]?, readTimestamps: [PeerId: Int32], reactions: EngineMessageReactionListContext.State?, customFiles: [TelegramMediaFile]?)
        var isEmpty: Bool {
            switch self {
            case .loading:
                return false
            case let .stats(read, _ , reactions, _):
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
        
        func isLoading(_ message: Message, context: AccountContext) -> Bool {
            return self.text(message, context: context).isEmpty
        }
        
        var emojiReferences: [StickerPackReference] {
            switch self {
            case .loading:
                return []
            case let .stats(_, _, _, files):
                return files?.compactMap { $0.emojiReference } ?? []
            }
        }
        
        func photos(_ message: Message) -> [Peer] {
            switch self {
            case .loading:
                return []
            case let .stats(read, _, reactions, _):
                var photos:[Peer] = []
                if message.id.peerId.namespace == Namespaces.Peer.CloudUser {
                    return []
                }
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
        
        var peers:[(Peer, MessageReaction.Reaction?, Int32?)] {
            switch self {
            case let .stats(read, readTimestamps, reactions, _):
                let readPeers = read ?? []
                let reactionPeers = reactions?.items.map { ($0.peer._asPeer(), $0.reaction, $0.timestamp ?? readTimestamps[$0.peer.id]) } ?? []
                let read:[(Peer, MessageReaction.Reaction?, Int32?)] = readPeers.map { ($0, nil, readTimestamps[$0.id]) }.filter({ value in
                    return !reactionPeers.contains(where: {
                        $0.0.id == value.0.id
                    })
                })
                return reactionPeers + read
            default:
                return []
            }
        }
 
        
        func text(_ message: Message, context: AccountContext) -> String {
            switch self {
            case let .stats(read, readTimestamps, reactions, _):
                if let reactions = reactions, !reactions.items.isEmpty {
                    if let read = read, read.count > reactions.totalCount {
                        return strings().chatContextReacted("\(reactions.totalCount)", "\(read.count)")
                    } else {
                        return strings().chatContextReactedFastCountable(reactions.totalCount)
                    }
                } else if let peers = read {
                    if peers.isEmpty {
                        if message.id.peerId.namespace == Namespaces.Peer.CloudUser {
                            return strings().chatMessageReadStatsShowDate
                        } else {
                            return strings().chatMessageReadStatsEmptyViews
                        }
                    } else if peers.count == 1 {
                        if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let readTimestamp = readTimestamps[peers[0].id] {
                            return stringForRelativeTimestamp(relativeTimestamp: readTimestamp, relativeTo: context.timestamp)
                        }
                        return peers[0].compactDisplayTitle.prefixWithDots(20)
                    } else {
                        if let media = message.anyMedia as? TelegramMediaFile {
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
                    if message.id.peerId.namespace == Namespaces.Peer.CloudUser {
                        return strings().chatMessageReadStatsShowDate
                    } else {
                        return strings().chatMessageReadStatsEmptyViews
                    }
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
    
    override var textMaxWidth: CGFloat {
        let value = super.textMaxWidth
        if self.state.isEmpty {
            return value
        }
        if state.photos(message).isEmpty {
            return value
        }
        return value - 60
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
        
        
        self.reactions = context.engine.messages.messageReactionList(message: .init(self.message), readStats: nil, reaction: nil)
        self.chatInteraction = chatInteraction
        self.availableReactions = availableReactions
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
        
        self.load()
    }
    
    var isTags: Bool {
        return self.chatInteraction.peerId == context.peerId
    }
    
    func load() {
        
        let customIds:[Int64] = message.effectiveReactions(isTags: isTags)?.compactMap { value in
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
                    return .stats(read: readStats?.peers.map { $0._asPeer() }, readTimestamps: readStats?.readTimestamps ?? [:], reactions: reactions, customFiles: customFiles)
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
        let makeItem:(_ peer: (Peer, MessageReaction.Reaction?, Int32?)) -> ContextMenuItem = { [weak chatInteraction] peer in
            let title = peer.0.displayTitle.prefixWithDots(25)
            
            let reaction: ReactionPeerMenu.Source?
            
            if let value = peer.1 {
                let file = availableReactions?.reactions.first(where: {
                    $0.value == value
                })?.staticIcon
                if let file = file {
                    reaction = .builtin(file._parse())
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
            }, peer: peer.0, context: context, reaction: reaction, readTimestamp: peer.2)
            let signal:Signal<(CGImage?, Bool), NoError>
            signal = peerAvatarImage(account: context.account, photo: .peer(peer.0, peer.0.smallProfileImage, peer.0.nameColor, peer.0.displayLetters, nil, nil), displayDimensions: NSMakeSize(18 * System.backingScale, 18 * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
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
        let hasRead = state.peers.contains(where: { $0.2 != nil })

        if items.count > 1 || hasReactions || hasRead, message.id.peerId.namespace != Namespaces.Peer.CloudUser {
            
            let references:[StickerPackReference] = state.emojiReferences.uniqueElements
            
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
                    case let .stats(_, _, reactions, _):
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
        
        self.item.title = state.text(self.message, context: context)
        
        
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var effectiveSize: NSSize {
        var size = super.effectiveSize
        
        let viewSize = NSMakeSize(15 * CGFloat(3) - (CGFloat(3) - 1) * 1, 15)
        size.width += viewSize.width + 6

        size.width += 100
        
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
                    return peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.nameColor, peer.displayLetters, nil, nil), displayDimensions: NSMakeSize(size.width * System.backingScale, size.height * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false)
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


    private var avatars: AvatarContentView?
    private var loadingView: View?

    private var isLoading: Bool = false
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MessageReadMenuRowItem else {
            return
        }
        if item.state.isLoading(item.message, context: item.context) {
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
        let avatars: AvatarContentView?
        
        let photos = item.state.photos(item.message)
        
        let updated = photos.map { $0.id }
        if updated != self.photos || self.isLoading != item.state.isLoading(item.message, context: item.context), item.message.id.peerId.namespace != Namespaces.Peer.CloudUser {
            self.photos = updated
            self.isLoading = item.state.isLoading(item.message, context: item.context)
            if self.isLoading {
                avatars = .init(context: item.context, message: item.message, peers: nil, size: NSMakeSize(18, 18))
            } else {
                if !item.state.isEmpty {
                    avatars = .init(context: item.context, message: item.message, peers: item.state.photos(item.message), size: NSMakeSize(18, 18))
                } else {
                    avatars = nil
                }
            }
            if let avatars = self.avatars {
                performSubviewRemoval(avatars, animated: animated)
            }
            self.avatars = avatars
            if let avatars = avatars {
                addSubview(avatars)
                avatars.centerY(x: self.rightX - contentView.frame.width - 2)
                if animated {
                    avatars.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
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
        if let avatars = avatars {
            if item.item.submenu != nil {
                avatars.centerY(x: self.rightX - avatars.frame.width - 4)
            } else {
                avatars.centerY(x: self.rightX - avatars.frame.width)
            }
        }
        if let loadingView = loadingView {
            let contentSize = avatars?.frame.width ?? 0
            loadingView.setFrameSize(NSMakeSize(self.rightX - self.textX - 10 - contentSize, loadingView.frame.height))
            loadingView.centerY(x: self.textX)
        }
    }
    
    override func invokeClick() {
        guard let item = self.item as? MessageReadMenuRowItem else {
            return
        }
        if item.state.isEmpty, !item.state.isLoading(item.message, context: item.context), item.message.id.peerId.namespace == Namespaces.Peer.CloudUser, let peer = item.message.peers[item.message.id.peerId] {
            showModal(with: PremiumShowStatusController(context: item.context, peer: .init(peer), source: .read), for: item.context.window)
            item.interaction?.close()
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
        super.init("", handler: nil, itemImage: message.hasReactions ? MenuAnimation.menu_reactions.value : MenuAnimation.menu_seen.value, removeTail: true)
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
        
        if chatInteraction.mode == .scheduled {
            return false
        }
        if peer.isBot {
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
        
        if message.flags.contains(.Incoming) && message.author?.id != chatInteraction.context.peerId {
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
                if let cachedData = chatInteraction.presentation.cachedData as? CachedChannelData {
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
        case _ as TelegramUser:
            if let cachedData = chatInteraction.presentation.cachedData as? CachedUserData {
                if cachedData.flags.contains(.readDatesPrivate) {
                    return false
                }
            } else {
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

extension ContextMenuItem {
    static func makeItemAvatar(_ item: ContextMenuItem, account: Account, peer: Peer, source: PeerPhoto, selfAsSaved: Bool = true) {
        let signal:Signal<(CGImage?, Bool), NoError>
        
        if peer.id == account.peerId, selfAsSaved {
            let icon = theme.icons.searchSaved
            signal = generateEmptyPhoto(NSMakeSize(18, 18), type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(10, 10)), cornerRadius: nil), bubble: false) |> deliverOnMainQueue |> map { ($0, true) }
        } else {
            signal = peerAvatarImage(account: account, photo: source, displayDimensions: NSMakeSize(18 * System.backingScale, 18 * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
        }
        item.contextObject = signal.start(next: { [weak item] image, _ in
            if let image = image {
                item?.image = NSImage(cgImage: image, size: NSMakeSize(18, 18))
            }
        })
    }
    
    static func makeEmoji(_ item: ContextMenuItem, context: AccountContext, file: TelegramMediaFile) {
     
        let size = NSMakeSize(18, 18)
        
        let aspectSize = file.dimensions?.size.aspectFitted(size) ?? size
        
        let signal = chatMessageAnimatedSticker(postbox: context.account.postbox, file: .standalone(media: file), small: false, scale: System.backingScale, size: aspectSize, fetched: true, thumbAtFrame: 0, isVideo: file.fileName == "webm-preview" || file.isVideoSticker)

        let arguments = TransformImageArguments(corners: .init(), imageSize: size, boundingSize: aspectSize, intrinsicInsets: .init(), emptyColor: nil)
        
        let result = signal |> map { data -> TransformImageResult in
            let context = data.execute(arguments, data.data)
            let image = context?.generateImage()
            return TransformImageResult(image, context?.isHighQuality ?? false)
        } |> deliverOnMainQueue
                
        item.contextObject = result.start(next: { [weak item] result in
            item?.image = result.image.flatMap({
                NSImage(cgImage: $0, size: size)
            })
        })
        
    }
}



extension ContextMenuItem {
    static func checkPremiumRequired(_ item: ContextMenuItem, context: AccountContext, peer: Peer) {
        if let peer = peer as? TelegramUser {
            if peer.maybePremiumRequired, !context.isPremium {
                let premRequired = getCachedDataView(peerId: peer.id, postbox: context.account.postbox)
                |> map { $0 as? CachedUserData }
                |> filter { $0 != nil }
                |> take(1)
                |> map { $0!.flags.contains(.premiumRequired) }
                |> deliverOnMainQueue
                
                _ = premRequired.startStandalone(next: { [weak item] value in
                    //item?.isEnabled = !value
                    let image = NSImage(named: "menu_lock")!
                    item?.state = .on
                    item?.stateOnImage = image
                    item?.handler = {
                        showModalText(for: context.window, text: strings().peerForwardPremiumRequired(peer.compactDisplayTitle), button: strings().alertLearnMore, callback: { _ in
                            prem(with: PremiumBoardingController(context: context), for: context.window)
                        })
                    }
                    item?.redraw?()
                    
                })
            }
        }
    }
}

final class ReactionPeerMenu : ContextMenuItem {
    enum Source : Equatable {
        case builtin(TelegramMediaFile)
        case custom(Int64, TelegramMediaFile?)
        case stars(TelegramMediaFile, TelegramMediaFile?)
    }
    enum Destination {
        case common
        case forward(callback: (Int64)->Void)
    }
    private let context: AccountContext
    private let reaction: Source?
    private let peer: Peer
    private let destination: Destination
    private let readTimestamp: Int32?
    private let disposable = MetaDisposable()
    private let afterNameBadge: CGImage?
    
    init(title: String, handler:@escaping()->Void, peer: Peer, context: AccountContext, reaction: Source?, readTimestamp: Int32? = nil, message: Message? = nil, destination: Destination = .common, afterNameBadge: CGImage? = nil) {
        self.reaction = reaction
        self.peer = peer
        self.context = context
        self.destination = destination
        self.readTimestamp = readTimestamp
        self.afterNameBadge = afterNameBadge
        
        super.init(title, handler: handler)
        
        if peer.isForum || (peer.isAdmin && peer.isMonoForum), case let .forward(callback) = destination {
            let signal = chatListViewForLocation(chatListLocation: .forum(peerId: peer.id), location: .Initial(100, nil), filter: nil, account: context.account) |> filter {
                !$0.list.isLoading
            } |> map {
                $0.list.items
            } |> take(1) |> deliverOnMainQueue
            disposable.set(signal.start(next: { [weak self] list in
                let menu = ContextMenu()
                for item in list.prefix(20) {
                    if let threadData = item.threadData {
                        let threadId: Int64?
                        switch item.id {
                        case let .forum(id):
                            threadId = id
                        default:
                            threadId = nil
                        }
                        if peer.canSendMessage(true, media: message?.media.first, threadData: threadData) {
                            let menuItem = ContextMenuItem(threadData.info.title, handler: {
                                if let threadId = threadId {
                                    callback(threadId)
                                }
                            })
                            
                            let threadMesssage = item.messages.first
                            
                            if let threadId, peer.isMonoForum, let peer = threadMesssage?.peers[PeerId(threadId)] {
                                ContextMenuItem.makeItemAvatar(menuItem, account: context.account, peer: peer, source: .peer(peer, peer.smallProfileImage, peer.nameColor, peer.displayLetters, threadMesssage?._asMessage(), nil))
                                menuItem.title = peer.displayTitle
                            } else {
                                ContextMenuItem.makeItemAvatar(menuItem, account: context.account, peer: peer, source: .topic(threadData.info, threadId == 1))
                                menuItem.title = threadData.info.title
                            }
                            
                            switch destination {
                            case .forward:
                                ContextMenuItem.checkPremiumRequired(menuItem, context: context, peer: peer)
                            default:
                                break
                            }
                            menu.addItem(menuItem)
                        }
                       
                    }
                }
                self?.submenu = menu
            }))
        }
        ContextMenuItem.makeItemAvatar(self, account: context.account, peer: peer, source: .peer(peer, peer.smallProfileImage, peer.nameColor, peer.displayLetters, message, nil))
        ContextMenuItem.checkPremiumRequired(self, context: context, peer: peer)
    }
    
    deinit {
        disposable.dispose()
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
            case let .stars(file, _):
                value.combine("stars")
                value.combine(file.fileId.id)
            }
        }
        return Int64(value.finalize().hashValue)
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return ReactionPeerMenuItem(item: self, peer: peer, interaction: interaction, presentation: presentation, context: context, reaction: self.reaction, readTimestamp: self.readTimestamp, afterNameBadge: afterNameBadge)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ReactionPeerMenuItem : AppMenuRowItem {
    
    
    fileprivate let context: AccountContext
    fileprivate let reaction: ReactionPeerMenu.Source?
    fileprivate let peer: Peer
    fileprivate let readTimestamp: Int32?
    fileprivate let afterNameBadge: CGImage?
    init(item: ContextMenuItem, peer: Peer, interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, context: AccountContext, reaction: ReactionPeerMenu.Source?, readTimestamp: Int32?, afterNameBadge: CGImage? = nil) {
        self.context = context
        self.reaction = reaction
        self.peer = peer
        self.readTimestamp = readTimestamp
        self.afterNameBadge = afterNameBadge
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
    
    override var textSize: CGFloat {
        if let readTimestamp = self.readTimestamp {
            let string = stringForRelativeTimestamp(relativeTimestamp: readTimestamp, relativeTo: context.timestamp)
            let attr: NSAttributedString = .initialize(string: string, color: presentation.textColor, font: .medium(.text))
            let size = attr.sizeFittingWidth(.greatestFiniteMagnitude)
            return max(size.width + leftInset * 2 + innerInset * 2, super.textSize)
        } else {
            return super.textSize
        }
    }
    
    override var effectiveSize: NSSize {
        var size = super.effectiveSize
        
        if let _ = reaction {
            size.width += 16 + 2 + self.innerInset
        }
        
        if let s = PremiumStatusControl.controlSize(peer, false, left: false), peer.id != context.peerId {
            size.width += s.width + 2
        }
        if let afterNameBadge {
            size.width += afterNameBadge.backingSize.width + 2
        }
        return size
    }
    
    override func viewClass() -> AnyClass {
        return ReactionPeerMenuItemView.self
    }
}


func stringForRelativeTimestamp(relativeTimestamp: Int32, relativeTo timestamp: Int32) -> String {
    var t: time_t = time_t(relativeTimestamp)
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    var now: time_t = time_t(timestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
    
    let hours = timeinfo.tm_hour
    let minutes = timeinfo.tm_min
    
    if dayDifference == 0 {
        return strings().timeTodayAt(stringForShortTimestamp(hours: hours, minutes: minutes))
    } else {
        return DateSelectorUtil.chatFullDateFormatter.string(from: Date.init(timeIntervalSince1970: TimeInterval(relativeTimestamp)))
    }
}

private final class ReadTimestampView : View {
    private let textView = TextView()
    private var readLayer: InlineStickerItemLayer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(timestamp: Int32, relativeTo: Int32, maxSize: NSSize, context: AccountContext, presentation: AppMenu.Presentation, isReaction: Bool) -> NSSize {
        let string = stringForRelativeTimestamp(relativeTimestamp: timestamp, relativeTo: relativeTo)
        let textLayout = TextViewLayout(.initialize(string: string, color: presentation.textColor, font: .medium(.text)), maximumNumberOfLines: 1)
        textLayout.measure(width: maxSize.width - 20)
        self.textView.update(textLayout)
        
        let readSize = NSMakeSize(16, 16)
        readLayer = .init(account: context.account, file: isReaction ? MenuAnimation.menu_reactions.file : MenuAnimation.menu_seen.file, size: readSize, playPolicy: .onceEnd, getColors: { file in
            var colors:[LottieColor] = []
            colors.append(.init(keyPath: "", color: presentation.textColor))
            return colors
        }, ignorePreview: true)
        readLayer?.isPlayable = true
        readLayer?.frame = CGRect(origin: CGPoint.init(x: 2, y: (maxSize.height - readSize.height) / 2), size: readSize)
        self.layer?.addSublayer(readLayer!)
        return NSMakeSize(self.textView.frame.width + 20, maxSize.height)

    }
    
    override func layout() {
        super.layout()
        self.textView.centerY(x: 20)
    }
}

private final class ReactionPeerMenuItemView : AppMenuRowView {
    private let imageView = AnimationLayerContainer(frame: NSMakeRect(0, 0, 16, 16))
    private var statusControl: PremiumStatusControl?
    private let delayDisposable = MetaDisposable()
    private var timestamp: ReadTimestampView?
    
    private var afterNameImageView: ImageView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    deinit {
        delayDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? ReactionPeerMenuItem else {
            return
        }
        
        var maxX: CGFloat = self.textX + item.text.layoutSize.width + 2
        
        if let statusControl = statusControl {
            statusControl.centerY(x: maxX)
            imageView.centerY(x: self.rightX - imageView.frame.width)
            maxX += statusControl.frame.width + 2

        }
        
        imageView.centerY(x: self.rightX - imageView.frame.width)

        if let timestamp = timestamp {
            timestamp.centerY(x: self.textX)
        }
        
        if let afterNameBadge = afterNameImageView {
            afterNameBadge.centerY(x: maxX)
        }
    }
    
    override func updateState(_ state: ControlState) {
        super.updateState(state)
        
        
        var state = containerView.controlState

        
        if currentState != state {
            if state == .Hover {
                delayDisposable.set(delaySignal(0.05).start(completed: { [weak self] in
                    self?.applyState(state)
                }))
            } else {
                delayDisposable.set(nil)
                self.applyState(state)
            }
        }
        
        self.currentState = state
    }
    private var currentState: ControlState?
    func applyState(_ state: ControlState) {
        guard let item = self.item as? ReactionPeerMenuItem else {
            return
        }
        if state == .Hover, let timestamp = item.readTimestamp {
            contentView.change(pos: NSMakePoint(0, -contentView.frame.height), animated: true, duration: 0.35, timingFunction: .spring)
            contentView.change(opacity: 0, animated: true)

            let current: ReadTimestampView
            if let view = self.timestamp {
                current = view
            } else {
                current = ReadTimestampView(frame: .zero)
                self.timestamp = current
                self.containerView.addSubview(current)
                
                let size = current.update(timestamp: timestamp, relativeTo: item.context.timestamp, maxSize: NSMakeSize(item.textMaxWidth, contentView.frame.height), context: item.context, presentation: item.presentation, isReaction: item.reaction != nil)
                current.frame = CGRect(origin: CGPoint(x: self.textX, y: focus(size).minY), size: size)
                
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                
                current.layer?.animatePosition(from: NSMakePoint(current.frame.minX, current.frame.height), to: current.frame.origin)
            }
            
            
        } else {
            contentView.change(pos: NSMakePoint(0, 0), animated: true, duration: 0.35, timingFunction: .spring)
            contentView.change(opacity: 1, animated: true)
            
            if let view = self.timestamp {
                performSubviewRemoval(view, animated: true)
                self.timestamp = nil
                view.layer?.animatePosition(from: view.frame.origin, to: NSMakePoint(view.frame.minX, view.frame.height),duration: 0.35, timingFunction: .spring, removeOnCompletion: false)
            }
        }
    }
    override func set(item: TableRowItem, animated: Bool = false) {
        let previous = self.item as? ReactionPeerMenuItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? ReactionPeerMenuItem else {
            return
        }
        
        if item.peer.id != item.context.peerId {
            let control = PremiumStatusControl.control(item.peer, account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, left: false, isSelected: false, cached: self.statusControl, animated: animated)
            if let control = control {
                self.statusControl = control
                self.addSubview(control)
            } else if let view = self.statusControl {
                performSubviewRemoval(view, animated: animated)
                self.statusControl = nil
            }
        } else if let view = self.statusControl {
            performSubviewRemoval(view, animated: animated)
            self.statusControl = nil
        }
        
        if let afterNameBadge = item.afterNameBadge {
            let current: ImageView
            if let view = self.afterNameImageView {
                current = view
            } else {
                current = ImageView()
                addSubview(current)
                self.afterNameImageView = current
            }
            current.image = afterNameBadge
            current.sizeToFit()
        } else if let view = self.afterNameImageView {
            performSubviewRemoval(view, animated: animated)
            self.afterNameImageView = nil
        }
        
        
        statusControl?.alphaValue = item.item.isEnabled ? 1 : 0.6
        
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
                case let .stars(file, _):
                    layer = .init(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: file.fileId.id, file: file, emoji: ""), size: reactionSize)
                }
                let isLite = item.context.isLite(.emoji)
                self.imageView.updateLayer(layer, isLite: isLite, animated: animated)
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
        super.init(title, handler: handler, itemImage: MenuAnimation.menu_smile.value, removeTail: false)
    }
    
    override var cuttail: Int? {
        return nil
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
            }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}





final class MessageAuthorMenuItem : ContextMenuItem {
   
    private let context: AccountContext
    private let messageId: MessageId
    
    fileprivate var peerId: PeerId?
    
    init(handler:@escaping(PeerId)->Void, messageId: MessageId, context: AccountContext) {
        self.messageId = messageId
        self.context = context
        var invoke:()->Void = { }
        super.init("", handler: {
            invoke()
        }, removeTail: false)
        
        invoke = { [weak self] in
            if let peerId = self?.peerId {
                handler(peerId)
            }
        }
        
    }
    
    override var cuttail: Int? {
        return nil
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return MessageAuthorMenuRowItem(item: self, messageId: messageId, interaction: interaction, presentation: presentation, context: context)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class MessageAuthorMenuRowItem : AppMenuRowItem {

    let context: AccountContext
    let messageId: MessageId
    
    enum State : Equatable {
        case loading
        case peer(EnginePeer)
    }
    
    fileprivate var state: State = .loading {
        didSet {
            updateState(state)
        }
    }
    
    private let disposable = MetaDisposable()
    
    init(item: ContextMenuItem, messageId: MessageId, interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, context: AccountContext) {
        self.messageId = messageId
        self.context = context
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
        
        let signal = context.engine.messages.requestMessageAuthor(id: messageId) |> deliverOnMainQueue
        
        disposable.set(signal.startStrict(next: { [weak self] peer in
            if let peer {
                self?.state = .peer(peer)
            }
        }))
    }
    
    private func updateState(_ state: State) {
        guard let menuItem = menuItem as? MessageAuthorMenuItem else {
            return
        }
        switch state {
        case .loading:
            break
        case let .peer(peer):
//            ContextMenuItem.makeItemAvatar(menuItem, account: context.account, peer: peer._asPeer(), source: .peer(peer._asPeer(), peer.smallProfileImage, peer.nameColor, peer.displayLetters, nil, nil))
            menuItem.title = strings().monoforumSentBy(peer._asPeer().displayTitle)
            menuItem.peerId = peer.id
        }
        
        self.redraw(animated: false)
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    override func viewClass() -> AnyClass {
        return MessageAuthorMenuItemView.self
    }

}

private final class MessageAuthorMenuItemView: AppMenuRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MessageAuthorMenuRowItem else {
            return
        }
    }
}
