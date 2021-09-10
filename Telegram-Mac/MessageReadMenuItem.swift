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




private final class MessageViewsMenuItemView : View {
    
    final class AvatarContentView: View {
        private var disposable: Disposable?
        private var images:[CGImage] = []
        init(context: AccountContext, message: Message, peers:[Peer]?, size: NSSize) {
            
            let count: CGFloat = peers != nil ? CGFloat(peers!.count) : 3
            let viewSize = NSMakeSize(size.width * count - (count - 1) * 1, size.height)
            
            super.init(frame: CGRect(origin: .zero, size: viewSize))
            
            if let peers = peers {
                let signal:Signal<[(CGImage?, Bool)], NoError> = combineLatest(peers.map { peer in
                    return peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, message), displayDimensions: size, scale: System.backingScale, font: .avatar(size.height / 3 + 3), genCap: true, synchronousLoad: false)
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

    
    private let selectedView = View()
    private let textView = NSTextField()
    
    private var contentView: AvatarContentView?
    private var loadingView: View?
    
    private var state: MessageReadMenuItem.State?
    private var context: AccountContext?
    private var message: Message?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        selectedView.layer?.cornerRadius = 3
        addSubview(selectedView)
        textView.isBordered = false
        textView.isBezeled = false
        textView.isSelectable = false
        textView.isEditable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.wantsLayer = true
        addSubview(textView)
    }
    
    private let disposableSet: DisposableDict<PeerId> = DisposableDict()
    
    func updateState(_ state: MessageReadMenuItem.State, message: Message, context: AccountContext, animated: Bool) -> Void {
        self.state = state
        self.context = context
        self.message = message
        
        if let item = self.enclosingMenuItem {
            
            switch state {
            case let .stats(peers):
                let menu = ContextMenu()
                var items:[ContextMenuItem] = []
                for peer in peers {
                    let item = ContextMenuItem(peer.displayTitle.prefix(30), handler: {
                        context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peer.id))
                    })
                    let avatar = peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, message), displayDimensions: NSMakeSize(15, 15), scale: System.backingScale, font: .avatar(5), genCap: true, synchronousLoad: false) |> deliverOnMainQueue

                    disposableSet.set(avatar.start(next: { [weak item] image, _ in
                        DispatchQueue.main.async {
                            item?.image = image?._NSImage
                        }
                    }), forKey: peer.id)
                    
                    items.append(item)
                }
                menu.items = items
                item.submenu = menu
            default:
                break
            }
        }
        
        if let item = self.enclosingMenuItem {
            updateIsSelected(item.isHighlighted && !state.isEmpty, message: message, context: context, state: state, animated: animated)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    deinit {
        disposableSet.dispose()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let item = self.enclosingMenuItem, let state = self.state, let context = self.context, let message = self.message {
            updateIsSelected(item.isHighlighted && !state.isEmpty, message: message, context: context, state: state, animated: false)
        }
        needsLayout = true

    }
    
    func updateIsSelected(_ isSelected: Bool, message: Message, context: AccountContext, state: MessageReadMenuItem.State, animated: Bool) {
        selectedView.isHidden = !isSelected
        selectedView.backgroundColor = theme.colors.accent //NSColor.selectedMenuItemColor
       
        let textColor = isSelected ? theme.colors.underSelectedColor : theme.colors.text
        let textLayot: TextViewLayout?
        let contentView: AvatarContentView?
        let loadingView: View?
        switch state {
        case .empty:
            let text: String
            if let media = message.media.first as? TelegramMediaFile {
                if media.isInstantVideo {
                    text = L10n.chatMessageReadStatsEmptyWatches
                } else if media.isVoice {
                    text = L10n.chatMessageReadStatsEmptyListens
                } else {
                    text = L10n.chatMessageReadStatsEmptyViews
                }
            } else {
                text = L10n.chatMessageReadStatsEmptyViews
            }
            textLayot = TextViewLayout(.initialize(string: text, color: textColor, font: .normal(.text)))
            contentView = nil
            loadingView = nil
        case .loading:
            textLayot = nil
            contentView = .init(context: context, message: message, peers: nil, size: NSMakeSize(15, 15))
            loadingView = View(frame: NSMakeRect(0, 0, 20, 6))
            loadingView?.layer?.cornerRadius = 3
            loadingView?.backgroundColor = NSColor.lightGray
        case let .stats(peers):
            let text: String
            if let media = message.media.first as? TelegramMediaFile {
                if media.isInstantVideo {
                    text = L10n.chatMessageReadStatsWatchedCountable(peers.count)
                } else if media.isVoice {
                    text = L10n.chatMessageReadStatsListenedCountable(peers.count)
                } else {
                    text = L10n.chatMessageReadStatsSeenCountable(peers.count)
                }
            } else {
                text = L10n.chatMessageReadStatsSeenCountable(peers.count)
            }
            textLayot = TextViewLayout(.initialize(string: text, color: textColor, font: .normal(.text)))
            loadingView = nil
            contentView = .init(context: context, message: message, peers: Array(peers.prefix(3)), size: NSMakeSize(15, 15))
        }
        textLayot?.measure(width: frame.width - 40)
        
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
        
        if let loadingView = self.loadingView {
            performSubviewRemoval(loadingView, animated: animated)
        }
        self.loadingView = loadingView
        if let loadingView = loadingView {
            addSubview(loadingView)
            if animated {
                loadingView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        }
        textView._change(opacity: textLayot != nil ? 1 : 0, animated: animated)
        if let textLayot = textLayot {
            textView.attributedStringValue = textLayot.attributedString
            textView.sizeToFit()
        }
        
        needsLayout = true
    }
    
    override func layout() {
        if let view = superview, self.frame != view.bounds {
            self.frame = view.bounds
        }
        
        let minx: CGFloat = 6
        
        selectedView.frame = frame.insetBy(dx: minx, dy: 0)
        textView.centerY(x: minx * 2, addition: -1)
        
        if let contentView = contentView {
            contentView.centerY(x: frame.width - contentView.frame.width - minx * 2)
        }
        if let loadingView = loadingView {
            loadingView.centerY(x: minx * 2)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}




final class MessageReadMenuItem {
    
    
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
    
    fileprivate let context: AccountContext
    fileprivate let message: Message
    fileprivate let disposable = MetaDisposable()
    
    private let state: Promise<State> = Promise(.loading)
    
    init(context: AccountContext, message: Message) {
        self.context = context
        self.message = message
        DispatchQueue.main.async { [weak self] in
            self?.load()
        }
    }
    
    func load() {
//        #if DEBUG
//        let readStats: Signal<State, NoError> = context.engine.peers.recentPeers() |> map { recent in
//            switch recent {
//            case let .peers(peers):
//                return .stats(peers)
//            case .disabled:
//                return .empty
//            }
//        } |> take(1)
//        #else
        let readStats: Signal<State, NoError> = context.engine.messages.messageReadStats(id: message.id)
            |> deliverOnMainQueue
            |> map { value in
                if let value = value, !value.peers.isEmpty {
                    return .stats(value.peers.map { $0._asPeer() })
                } else {
                    return .empty
                }
            }
//        #endif
               
        
        self.state.set(readStats |> deliverOnMainQueue)

        
        let context = self.context
        let message = self.message
        
        disposable.set(self.state.get().start(next: { [weak self] state in
            self?._cachedView?.updateState(state, message: message, context: context, animated: true)
        }))
    }
    
    deinit {
        disposable.dispose()
    }
    
    private var _cachedView: MessageViewsMenuItemView? = nil
    var view: View {
        if let _cachedView = _cachedView {
            return _cachedView
        }
        _cachedView = MessageViewsMenuItemView(frame: NSMakeRect(0, 0, 180, 20))
        _cachedView?.updateState(.loading, message: message, context: context, animated: false)
        return _cachedView!
    }
    
    
    static func canViewReadStats(message: Message, chatInteraction: ChatInteraction, appConfig: AppConfiguration) -> Bool {
        
        guard let peer = message.peers[message.id.peerId] else {
            return false
        }
        
        if message.flags.contains(.Incoming) {
            switch peer {
            case let peer as TelegramChannel:
                if peer.adminRights == nil || !peer.groupAccess.isCreator || peer.isChannel {
                    return false
                }
            case let peer as TelegramGroup:
                switch peer.role {
                case .member:
                    return false
                default:
                    break
                }
            default:
                return false
            }
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
