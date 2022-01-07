//
//  ChatReactionsView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.12.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import MergeLists
import Reactions
import AppKit
import SwiftSignalKit


final class ChatReactionsLayout {
    
    struct Theme : Equatable {
        let bgColor: NSColor
        let textColor: NSColor
        let borderColor: NSColor
        let selectedColor: NSColor
        let textSelectedColor: NSColor
        let reactionSize: NSSize
        let insetOuter: CGFloat
        let insetInner: CGFloat

        let renderType: ChatItemRenderType
        let isIncoming: Bool
        let isOutOfBounds: Bool
        let hasWallpaper: Bool
        
        static func Current(theme: TelegramPresentationTheme, renderType: ChatItemRenderType, isIncoming: Bool, isOutOfBounds: Bool, hasWallpaper: Bool, stateOverlayTextColor: NSColor, mode: ChatReactionsLayout.Mode) -> Theme {
            let bgColor: NSColor
            let textColor: NSColor
            let textSelectedColor: NSColor
            let borderColor: NSColor
            let selectedColor: NSColor
            switch mode {
            case .full:
                switch renderType {
                case .bubble:
                    if isOutOfBounds {
                        bgColor = theme.blurServiceColor
                        textColor = theme.chatServiceItemTextColor
                        borderColor = .clear
                        selectedColor = theme.colors.accent
                        textSelectedColor = theme.colors.underSelectedColor
                    } else {
                        if isIncoming {
                            bgColor = theme.colors.accent.withAlphaComponent(0.1)
                            textColor = theme.colors.accent
                            borderColor = .clear
                            selectedColor = theme.colors.accent
                            textSelectedColor = theme.colors.underSelectedColor
                        } else {
                            bgColor = theme.chat.grayText(false, true).withAlphaComponent(0.1)
                            textColor = theme.chat.grayText(false, true)
                            borderColor = .clear
                            selectedColor = theme.chat.grayText(false, true)
                            textSelectedColor = theme.colors.blendedOutgoingColors
                        }
                    }
                case .list:
                    bgColor = theme.colors.accent.withAlphaComponent(0.1)
                    textColor = theme.colors.accent
                    borderColor = .clear
                    selectedColor = theme.colors.accent
                    textSelectedColor = theme.colors.underSelectedColor
                }
            case .short:
                bgColor = .clear
                textColor = stateOverlayTextColor
                borderColor = .clear
                selectedColor = .clear
                textSelectedColor = .clear
            }
           
            let size: NSSize
            switch mode {
            case .full:
                size = NSMakeSize(16, 16)
            case .short:
                size = NSMakeSize(12, 12)
            }
            
            return .init(bgColor: bgColor, textColor: textColor, borderColor: borderColor, selectedColor: selectedColor, textSelectedColor: textSelectedColor, reactionSize: size, insetOuter: 10, insetInner: mode == .short ? 1 : 5, renderType: renderType, isIncoming: isIncoming, isOutOfBounds: isOutOfBounds, hasWallpaper: hasWallpaper)

        }
    }
    
    final class Reaction : Equatable, Comparable, Identifiable {
        
        struct Avatar : Comparable, Identifiable {
            static func < (lhs: Avatar, rhs: Avatar) -> Bool {
                return lhs.index < rhs.index
            }
            
            var stableId: PeerId {
                return peer.id
            }
            
            static func == (lhs: Avatar, rhs: Avatar) -> Bool {
                if lhs.index != rhs.index {
                    return false
                }
                if !lhs.peer.isEqual(rhs.peer) {
                    return false
                }
                return true
            }
            
            let peer: Peer
            let index: Int
        }

        
        let value: MessageReaction
        let text: DynamicCounterTextView.Value?
        let presentation: Theme
        let index: Int
        let minimumSize: NSSize
        let available: AvailableReactions.Reaction
        let mode: ChatReactionsLayout.Mode
        let disposable: MetaDisposable = MetaDisposable()
        let delayDisposable = MetaDisposable()
        let action:()->Void
        let context: AccountContext
        let message: Message
        let openInfo: (PeerId)->Void
        let canViewList: Bool
        
        let avatars:[Avatar]
        var rect: CGRect = .zero
        
        static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            return lhs.value == rhs.value &&
            lhs.presentation == rhs.presentation &&
            lhs.index == rhs.index &&
            lhs.minimumSize == rhs.minimumSize &&
            lhs.available == rhs.available &&
            lhs.mode == rhs.mode &&
            lhs.rect == rhs.rect &&
            lhs.canViewList == rhs.canViewList
            
        }
        static func <(lhs: Reaction, rhs: Reaction) -> Bool {
            return lhs.index < rhs.index
        }
        var stableId: String {
            return self.value.value
        }
        
        init(value: MessageReaction, recentPeers:[Peer], canViewList: Bool, message: Message, context: AccountContext, mode: ChatReactionsLayout.Mode, index: Int, available: AvailableReactions.Reaction, presentation: Theme, action:@escaping()->Void, openInfo: @escaping (PeerId)->Void) {
            self.value = value
            self.index = index
            self.message = message
            self.canViewList = canViewList
            self.action = action
            self.context = context
            self.presentation = presentation
            self.available = available
            self.mode = mode
            self.openInfo = openInfo
            switch mode {
            case .full:
                if recentPeers.isEmpty {
                    self.text = DynamicCounterTextView.make(for: Int(value.count).prettyNumber, count: "\(value.count)", font: .normal(.text), textColor: value.isSelected ? presentation.textSelectedColor : presentation.textColor, width: .greatestFiniteMagnitude)
                } else {
                    self.text = nil
                }
                
                var width: CGFloat = presentation.insetOuter
                width += presentation.reactionSize.width
                if let text = text {
                    width += presentation.insetInner
                    width += text.size.width
                    width += presentation.insetOuter
                } else if !recentPeers.isEmpty {
                    width += presentation.insetInner
                    if recentPeers.count == 1 {
                        width += presentation.reactionSize.width
                    } else if !recentPeers.isEmpty {
                        width += 12 * CGFloat(recentPeers.count)
                    }
                    width += presentation.insetOuter
                }
                
                
                
                
                var index: Int = 0
                self.avatars = recentPeers.map { peer in
                    let avatar = Avatar(peer: peer, index: index)
                    index += 1
                    return avatar
                }
                                
                let height = presentation.reactionSize.height + presentation.insetInner * 2
                
                self.minimumSize = NSMakeSize(width, height)

            case .short:
                var width: CGFloat = presentation.reactionSize.width
                let height = presentation.reactionSize.height
                if value.count > 1 {
                    let text = DynamicCounterTextView.make(for: "\(value.count)", count: "\(value.count)", font: .italic(.short), textColor: presentation.textColor, width: .greatestFiniteMagnitude)
                    self.text = text
                    width += text.size.width + 2
                } else {
                    self.text = nil
                    width += 2
                }
                self.avatars = []
                self.minimumSize = NSMakeSize(width, height)
            }
        }
        
        func measure(for width: CGFloat, recommendedSize: NSSize) {
           
        }
        
        private var menu: ContextMenu?
        
        private var reactions: EngineMessageReactionListContext?
        
        func cancelMenu() {
            delayDisposable.set(nil)
            disposable.set(nil)
        }
        
        func loadMenu() -> ContextMenu? {
            if let peer = self.message.peers[message.id.peerId] {
                guard peer.isGroup || peer.isSupergroup else {
                    return nil
                }
            }
            if !self.canViewList {
                return nil
            }
            if let menu = menu {
                return menu
            } else {
                let menu = ContextMenu()
                self.menu = menu
                let current: EngineMessageReactionListContext
                if let reactions = reactions {
                    current = reactions
                } else {
                    current = context.engine.messages.messageReactionList(message: .init(self.message), reaction: self.value.value)
                    self.reactions = current
                }
                let signal = current.state |> deliverOnMainQueue
                self.disposable.set(signal.start(next: { [weak self] state in
                    self?.applyState(state)
                }))
                
                return menu
            }
        }
        private var state: EngineMessageReactionListContext.State?
        func applyState(_ state: EngineMessageReactionListContext.State) {
            self.state = state
            let account = self.context.account
            let context = self.context
            weak var weakSelf = self
            let makeItem:(_ peer: Peer) -> ContextMenuItem = { peer in
                let title = peer.displayTitle.prefixWithDots(25)
                let item = ReactionPeerMenu(title: title, handler: {
                    weakSelf?.openInfo(peer.id)
                }, peerId: peer.id, context: context, reaction: nil)
                
                let signal:Signal<(CGImage?, Bool), NoError>
                signal = peerAvatarImage(account: account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, nil), displayDimensions: NSMakeSize(18 * System.backingScale, 18 * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
                _ = signal.start(next: { [weak item] image, _ in
                    if let image = image {
                        item?.image = NSImage(cgImage: image, size: NSMakeSize(18, 18))
                    }
                })
                return item
            }
            menu?.loadMore = { [weak self] in
                if self?.state?.canLoadMore == true {
                    self?.reactions?.loadMore()
                }
            }
            menu?.items = state.items.map {
                return makeItem($0.peer._asPeer())
            }
        }
    }
    fileprivate let context: AccountContext
    fileprivate let message: Message
    fileprivate let renderType: ChatItemRenderType
    fileprivate let available: AvailableReactions?
    fileprivate let engine: Reactions
    fileprivate let openInfo:(PeerId)->Void
    let presentation: Theme
    
    private(set) var size: NSSize = .zero
    fileprivate let reactions: [Reaction]
    private var lines:[[Reaction]] = []
    
    enum Mode {
        case full
        case short
    }
    
    let mode: Mode
    
    init(context: AccountContext, message: Message, available: AvailableReactions?, engine:Reactions, theme: TelegramPresentationTheme, renderType: ChatItemRenderType, isIncoming: Bool, isOutOfBounds: Bool, hasWallpaper: Bool, stateOverlayTextColor: NSColor, openInfo:@escaping(PeerId)->Void) {
        
        let mode: Mode = message.id.peerId.namespace == Namespaces.Peer.CloudUser ? .short : .full
        
        self.message = message
        self.context = context
        self.renderType = renderType
        self.available = available
        self.engine = engine
        self.mode = mode
        self.openInfo = openInfo
        let presentation: Theme = .Current(theme: theme, renderType: renderType, isIncoming: isIncoming, isOutOfBounds: isOutOfBounds, hasWallpaper: hasWallpaper, stateOverlayTextColor: stateOverlayTextColor, mode: mode)
        self.presentation = presentation
        
        var index: Int = 0
        let getIndex:()->Int = {
            index += 1
            return index
        }
        
        let reactions = message.effectiveReactions(context.peerId)!
        
        var indexes:[String: Int] = [:]
        if let available = available {
            var index: Int = 0
            for value in available.reactions {
                indexes[value.value] = index
                index += 1
            }
        }
        
        let sorted = reactions.reactions.sorted(by: { lhs, rhs in
            if lhs.count == rhs.count {
                let lhsIndex = indexes[lhs.value]
                let rhsIndex = indexes[rhs.value]
                if let lhsIndex = lhsIndex, let rhsIndex = rhsIndex {
                    return lhsIndex < rhsIndex
                } else {
                    return false
                }
            } else {
                return lhs.count > rhs.count
            }
        })
        
        self.reactions = sorted.compactMap { reaction in
            if let available = available?.reactions.first(where: { $0.value == reaction.value }) {
                
                var recentPeers:[Peer] = reactions.recentPeers.filter { recent in
                    return recent.value == reaction.value
                }.compactMap {
                    message.peers[$0.peerId]
                }
                
                if let peer = message.peers[message.id.peerId] {
                    if !peer.isGroup && !peer.isSupergroup {
                        recentPeers = []
                    }
                    let count = reactions.reactions.reduce(0, {
                        $0 + $1.count
                    })
                    if count >= 3 || count > recentPeers.count {
                        recentPeers = []
                    }
                }
                return .init(value: reaction, recentPeers: recentPeers, canViewList: reactions.canViewList, message: message, context: context, mode: mode, index: getIndex(), available: available, presentation: presentation, action: {
                    engine.react(message.id, value: reaction.isSelected ? nil : reaction.value)
                }, openInfo: openInfo)
            } else {
                return nil
            }
        }
    }
    
    func haveSpace(for value: CGFloat, maxSize: CGFloat) -> Bool {
        let maxSize = max(self.size.width, maxSize)
        if let last = lines.last {
            let w = last.last!.rect.maxX
            if w + value > maxSize {
                return false
            }
        }
        return true
    }
    
    var lastLineSize: NSSize {
        if let line = lines.last {
            if let lastItem = line.last {
                return NSMakeSize(lastItem.rect.maxX, lastItem.rect.height)
            }
        }
        return .zero
    }
    var oneLine: Bool {
        return lines.count == 1
    }
    
   
    func measure(for width: CGFloat) {
                
        var lines:[[Reaction]] = []
        
        var line:[Reaction] = []
        var current: CGFloat = 0
        for reaction in reactions {
            current += reaction.minimumSize.width
            let force: Bool
            if let lastCount = lines.last?.count {
                force = lastCount == line.count
            } else {
                force = false
            }
            if (current - presentation.insetInner > width && !line.isEmpty) || force {
                lines.append(line)
                line.removeAll()
                line.append(reaction)
                current = reaction.minimumSize.width
            } else {
                line.append(reaction)
            }
            current += presentation.insetInner
        }
        if !line.isEmpty {
            lines.append(line)
            line.removeAll()
        }
            
        
        let count = lines.reduce(0, {
            $0 + $1.count
        })
        
        
        
        assert(count == reactions.count)
        
        self.lines = lines
        
        if !lines.isEmpty {
            var point: CGPoint = .zero
            for line in lines {
                for reaction in line {
                    var rect = NSZeroRect
                    rect.origin = point
                    rect.size = reaction.minimumSize
                    point.x += reaction.minimumSize.width + presentation.insetInner
                    reaction.rect = rect
                }
                point.x = 0
                point.y += line.map { $0.minimumSize.height }.max()! + presentation.insetInner
            }
            let max_w = lines.max(by: { lhs, rhs in
                return lhs.last!.rect.maxX < rhs.last!.rect.maxX
            })!.last!.rect.maxX
            self.size = NSMakeSize(max_w, point.y - presentation.insetInner)
        } else {
            self.size = .zero
        }
        
    }
}

protocol ReactionViewImpl {
    func update(with reaction: ChatReactionsLayout.Reaction, account: Account, animated: Bool)
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}

final class ChatReactionsView : View {
    
    
    final class ReactionView: Control, ReactionViewImpl {
        private var reaction: ChatReactionsLayout.Reaction?
        private let imageView: TransformImageView = TransformImageView()
        private var textView: DynamicCounterTextView?
        private let avatarsContainer = View(frame: NSMakeRect(0, 0, 16 * 3, 16))
        private var avatars:[AvatarContentView] = []
        private var peers:[ChatReactionsLayout.Reaction.Avatar] = []
        private var first: Bool = true
        private var backgroundView: View? = nil
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            addSubview(imageView)
            addSubview(avatarsContainer)
            avatarsContainer.isEventLess = true
            scaleOnClick = true
            
            self.set(handler: { [weak self] _ in
                self?.reaction?.action()
            }, for: .Click)
            
            
            self.contextMenu = { [weak self] in
                if let reaction = self?.reaction {
                    return reaction.loadMenu()
                }
                return nil
            }
            
            
            self.set(handler: { [weak self] _ in
                self?.reaction?.cancelMenu()
            }, for: .Normal)
            
            
            
        }
        
        func update(with reaction: ChatReactionsLayout.Reaction, account: Account, animated: Bool) {
            let selectedUpdated = self.reaction?.value.isSelected != reaction.value.isSelected
            let reactionUpdated = self.reaction?.value.value != reaction.value.value
            self.reaction = reaction
            self.layer?.cornerRadius = reaction.rect.height / 2
            
            let presentation = reaction.presentation
            
            if let text = reaction.text {
                let current: DynamicCounterTextView
                if let view = self.textView {
                    current = view
                } else {
                    current = DynamicCounterTextView(frame: CGRect(origin: NSMakePoint(presentation.insetOuter + presentation.reactionSize.width + presentation.insetInner, (frame.height - text.size.height) / 2), size: text.size))
                    current.userInteractionEnabled = false
                    self.textView = current
                    addSubview(current)
                }
                current.update(text, animated: animated)
            } else {
                if let view = self.textView {
                    performSubviewRemoval(view, animated: animated)
                    self.textView = nil
                }
            }
            
            
            let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.peers, rightList: reaction.avatars)
            
            let size = reaction.presentation.reactionSize
            
            for removed in removed.reversed() {
                let control = avatars.remove(at: removed)
                let peer = self.peers[removed]
                let haveNext = reaction.avatars.contains(where: { $0.stableId == peer.stableId })
                control.updateLayout(size: size, isClipped: false, animated: animated)
                if animated && !haveNext {
                    control.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, timingFunction: .easeOut, removeOnCompletion: false, completion: { [weak control] _ in
                        control?.removeFromSuperview()
                    })
                    control.layer?.animateScaleSpring(from: 1.0, to: 0.2, duration: 0.2)
                } else {
                    control.removeFromSuperview()
                }
            }
            for inserted in inserted {
                let control = AvatarContentView(context: reaction.context, peer: inserted.1.peer, message: reaction.message, synchronousLoad: false, size: size)
                control.updateLayout(size: size, isClipped: inserted.0 != 0, animated: animated)
                control.userInteractionEnabled = false
                control.setFrameSize(size)
                control.setFrameOrigin(NSMakePoint(CGFloat(inserted.0) * 12, 0))
                avatars.insert(control, at: inserted.0)
                avatarsContainer.subviews.insert(control, at: inserted.0)
                if animated {
                    if let index = inserted.2 {
                        control.layer?.animatePosition(from: NSMakePoint(CGFloat(index) * 12, 0), to: control.frame.origin, duration: 0.2, timingFunction: .easeOut)
                    } else {
                        control.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, timingFunction: .easeOut)
                        control.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.2)
                    }
                }
            }
            for updated in updated {
                let control = avatars[updated.0]
                control.updateLayout(size: size, isClipped: updated.0 != 0, animated: animated)
                let updatedPoint = NSMakePoint(CGFloat(updated.0) * 12, 0)
                if animated {
                    control.layer?.animatePosition(from: control.frame.origin - updatedPoint, to: .zero, duration: 0.2, timingFunction: .easeOut, additive: true)
                }
                control.setFrameOrigin(updatedPoint)
            }
            var index: CGFloat = 10
            for control in avatarsContainer.subviews.compactMap({ $0 as? AvatarContentView }) {
                control.layer?.zPosition = index
                index -= 1
            }
            
            self.peers = reaction.avatars
            
            self.backgroundColor = reaction.presentation.bgColor

            
            if selectedUpdated {
                if reaction.value.isSelected {
                    let view = View(frame: bounds)
                    view.isEventLess = true
                    view.layer?.cornerRadius = view.frame.height / 2
                    self.backgroundView = view
                    self.addSubview(view, positioned: .below, relativeTo: subviews.first)
                    
                    if animated {
                        view.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.3)
                        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                } else {
                    if let view = backgroundView {
                        performSubviewRemoval(view, animated: animated, scale: true)
                        self.backgroundView = nil
                    }
                }
            }

            self.backgroundView?.backgroundColor = reaction.presentation.selectedColor

            
            if animated {
                self.layer?.animateBorder()
                self.layer?.animateBackground()
            }

            let arguments = TransformImageArguments(corners: .init(), imageSize: reaction.presentation.reactionSize, boundingSize: reaction.presentation.reactionSize, intrinsicInsets: NSEdgeInsetsZero, emptyColor: nil)
            
            self.imageView.setSignal(signal: cachedMedia(media: reaction.available.staticIcon, arguments: arguments, scale: System.backingScale, positionFlags: nil), clearInstantly: true)

            if !self.imageView.isFullyLoaded {
                imageView.setSignal(chatMessageSticker(postbox: account.postbox, file: .standalone(media: reaction.available.staticIcon), small: false, scale: System.backingScale), cacheImage: { result in
                    cacheMedia(result, media: reaction.available.staticIcon, arguments: arguments, scale: System.backingScale)
                })
            }
            
            if !first, reactionUpdated, animated {
                self.imageView.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
            }

            imageView.set(arguments: arguments)
            if first {
                updateLayout(size: reaction.rect.size, transition: .immediate)
                first = false
            }
        }
        
        func isOwner(of reaction: ChatReactionsLayout.Reaction) -> Bool {
            return self.reaction?.value.value == reaction.value.value
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
            guard let reaction = reaction else {
                return
            }
            
            if let backgroundView = backgroundView {
                transition.updateFrame(view: backgroundView, frame: size.bounds)
            }
            
            let presentation = reaction.presentation

            transition.updateFrame(view: self.imageView, frame: CGRect(origin: NSMakePoint(presentation.insetOuter, (size.height - presentation.reactionSize.height) / 2), size: presentation.reactionSize))
            
            if let textView = textView, let text = reaction.text {
                let center = focus(text.size)
                transition.updateFrame(view: textView, frame: CGRect(origin: NSMakePoint(self.imageView.frame.maxX + presentation.insetInner, center.minY), size: text.size))
            }
            
            let center = focus(presentation.reactionSize)
            transition.updateFrame(view: avatarsContainer, frame: CGRect(origin: NSMakePoint(self.imageView.frame.maxX + presentation.insetInner, center.minY), size: avatarsContainer.frame.size))
            
        }
        override func layout() {
            super.layout()
            updateLayout(size: frame.size, transition: .immediate)
        }
    }
    
    final class ShortReactionView: Control, ReactionViewImpl {
        private var reaction: ChatReactionsLayout.Reaction?
        private let imageView: TransformImageView = TransformImageView()
        private var textView: DynamicCounterTextView?
        private var first = true
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            userInteractionEnabled = false
            addSubview(imageView)
        }
        
        func update(with reaction: ChatReactionsLayout.Reaction, account: Account, animated: Bool) {
            self.reaction = reaction
            
            let arguments = TransformImageArguments(corners: .init(), imageSize: reaction.presentation.reactionSize, boundingSize: reaction.presentation.reactionSize, intrinsicInsets: NSEdgeInsetsZero, emptyColor: nil)
            self.imageView.setSignal(signal: cachedMedia(media: reaction.available.staticIcon, arguments: arguments, scale: System.backingScale, positionFlags: nil), clearInstantly: true)
            if !self.imageView.isFullyLoaded {
                imageView.setSignal(chatMessageSticker(postbox: account.postbox, file: .standalone(media: reaction.available.staticIcon), small: false, scale: System.backingScale), cacheImage: { result in
                    cacheMedia(result, media: reaction.available.staticIcon, arguments: arguments, scale: System.backingScale)
                })
            }
            imageView.set(arguments: arguments)
            
            if let text = reaction.text {
                let current: DynamicCounterTextView
                if let view = self.textView {
                    current = view
                } else {
                    current = DynamicCounterTextView()
                    self.textView = current
                    addSubview(current)
                }
                current.update(text, animated: animated)
            } else {
                if let view = self.textView {
                    performSubviewRemoval(view, animated: animated)
                    self.textView = nil
                }
            }
            
            if first {
                updateLayout(size: reaction.rect.size, transition: .immediate)
                first = false
            }
        }
        
        func isOwner(of reaction: ChatReactionsLayout.Reaction) -> Bool {
            return self.reaction?.value.value == reaction.value.value
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
            guard let reaction = reaction else {
                return
            }
            if let textView = textView, let text = reaction.text {
                var text_r = focus(text.size)
                text_r.origin.x = 2
                var img_r = focus(reaction.presentation.reactionSize)
                img_r.origin.x = text_r.maxX
                transition.updateFrame(view: textView, frame: text_r)
                transition.updateFrame(view: self.imageView, frame: img_r)
            } else {
                var img_r = focus(reaction.presentation.reactionSize)
                img_r.origin.x = 2
                transition.updateFrame(view: self.imageView, frame: img_r)
            }
        }
        override func layout() {
            super.layout()
            updateLayout(size: frame.size, transition: .immediate)
        }
    }

    
    private var currentLayout: ChatReactionsLayout?
    private var reactions:[ChatReactionsLayout.Reaction] = []
    private var views:[NSView] = []
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    
    func update(with layout: ChatReactionsLayout, animated: Bool) {
                
        
        let previous = self.reactions
        
        let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.reactions, rightList: layout.reactions)
        

        var deletedViews:[Int: NSView] = [:]
        var reused:Set<Int> = Set()
        
        for idx in removed.reversed() {
            self.reactions.remove(at: idx)
            let view = self.views.remove(at: idx)
            deletedViews[idx] = view
        }
        for (idx, item, pix) in inserted {
            var prevFrame: NSRect? = nil
            var prevView: NSView? = nil
            if let pix = pix {
                prevFrame = previous[pix].rect
                prevView = deletedViews[pix]
                if prevView != nil {
                    reused.insert(pix)
                }
            } else if inserted.count == 1, removed.count == 1 {
               let kv = deletedViews.first!
               prevView = kv.value
               reused.insert(kv.key)
           }
            let getView: ()->NSView = {
                switch layout.mode {
                case .full:
                    return ReactionView(frame: item.rect)
                case .short:
                    return ShortReactionView(frame: item.rect)
                }
            }
            
            let view = prevView ?? getView()
            view.frame = prevFrame ?? item.rect
            self.views.insert(view, at: idx)
            self.reactions.insert(item, at: idx)
            (view as? ReactionViewImpl)?.update(with: item, account: layout.context.account, animated: animated)
            if animated, prevView == nil {
                view.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.3)
                view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            addSubview(view)
        }
        
        for (idx, item, prev) in updated {
            if prev != idx {
                self.views[idx].frame = previous[prev].rect
            }
            (self.views[idx] as? ReactionViewImpl)?.update(with: item, account: layout.context.account, animated: animated)
            self.reactions[idx] = item
        }
        
        for (i, view) in views.enumerated() {
            view.layer?.zPosition = CGFloat(i)
        }
        
        for (index, view) in deletedViews {
            if !reused.contains(index) {
                performSubviewRemoval(view, animated: animated, checkCompletion: true, scale: true)
            }
        }

        self.currentLayout = layout
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeInOut)
        } else {
            transition = .immediate
        }
        
        self.updateLayout(size: layout.size, transition: transition)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        for (i, view) in views.enumerated() {
            let rect = self.reactions[i].rect
            transition.updateFrame(view: view, frame: rect)
            (view as? ReactionView)?.updateLayout(size: rect.size, transition: transition)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
