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
            let borderColor: NSColor
            let selectedColor: NSColor
            switch mode {
            case .full:
                switch renderType {
                case .bubble:
                    if isOutOfBounds {
                        bgColor = theme.colors.bubbleBackground_incoming
                        textColor = theme.colors.textBubble_incoming
                        borderColor = .clear
                        selectedColor = theme.colors.bubbleBackground_incoming.darker()
                    } else {
                        if isIncoming {
                            bgColor = theme.colors.bubbleBackground_incoming.lighter()
                            textColor = theme.colors.textBubble_incoming
                            borderColor = .clear
                            selectedColor = theme.colors.bubbleBackground_incoming.darker()
                        } else {
                            bgColor = theme.colors.blendedOutgoingColors.lighter()
                            textColor = theme.colors.textBubble_outgoing
                            borderColor = .clear
                            selectedColor = theme.colors.blendedOutgoingColors.darker()
                        }
                    }
                case .list:
                    if theme.dark {
                        bgColor = theme.colors.grayBackground.lighter(amount: 0.3)
                        textColor = theme.colors.text
                        borderColor = .clear
                        selectedColor = theme.colors.grayForeground
                    } else {
                        bgColor = theme.colors.grayBackground
                        textColor = theme.colors.text
                        borderColor = .clear
                        selectedColor = theme.colors.grayForeground
                    }
                }
            case .short:
                bgColor = .clear
                textColor = stateOverlayTextColor
                borderColor = .clear
                selectedColor = .clear
            }
           
            let size: NSSize
            switch mode {
            case .full:
                size = NSMakeSize(16, 16)
            case .short:
                size = NSMakeSize(12, 12)
            }
            
            return .init(bgColor: bgColor, textColor: textColor, borderColor: borderColor, selectedColor: selectedColor, reactionSize: size, insetOuter: 10, insetInner: 5, renderType: renderType, isIncoming: isIncoming, isOutOfBounds: isOutOfBounds, hasWallpaper: hasWallpaper)

        }
    }
    
    final class Reaction : Equatable, Comparable, Identifiable {
        let value: MessageReaction
        let text: DynamicCounterTextView.Value!
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
        var rect: CGRect = .zero
        
        static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            return lhs.value == rhs.value &&
            lhs.presentation == rhs.presentation &&
            lhs.index == rhs.index &&
            lhs.minimumSize == rhs.minimumSize &&
            lhs.available == rhs.available &&
            lhs.mode == rhs.mode
        }
        static func <(lhs: Reaction, rhs: Reaction) -> Bool {
            return lhs.index < rhs.index
        }
        var stableId: String {
            return self.value.value
        }
        
        init(value: MessageReaction, message: Message, context: AccountContext, mode: ChatReactionsLayout.Mode, index: Int, available: AvailableReactions.Reaction, presentation: Theme, action:@escaping()->Void, openInfo: @escaping (PeerId)->Void) {
            self.value = value
            self.index = index
            self.message = message
            self.action = action
            self.context = context
            self.presentation = presentation
            self.available = available
            self.mode = mode
            self.openInfo = openInfo
            switch mode {
            case .full:
                self.text = DynamicCounterTextView.make(for: "\(value.count)", count: "\(value.count)", font: .normal(.text), textColor: presentation.textColor, width: .greatestFiniteMagnitude)
                
                var width: CGFloat = presentation.insetOuter
                width += presentation.reactionSize.width
                width += presentation.insetInner
                width += self.text.size.width
                width += presentation.insetOuter
                
                
                let height = max(self.text.size.height, presentation.reactionSize.height) + presentation.insetInner * 2
                
                self.minimumSize = NSMakeSize(width, height)

            case .short:
                var width: CGFloat = presentation.reactionSize.width
                let height = presentation.reactionSize.height
                if value.count > 1 {
                    self.text = DynamicCounterTextView.make(for: "\(value.count)", count: "\(value.count)", font: .italic(.short), textColor: presentation.textColor, width: .greatestFiniteMagnitude)
                    width += self.text.size.width + 2
                } else {
                    self.text = nil
                    width += 2
                }
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
        
        self.reactions = message.effectiveReactions(context.peerId)?.reactions.compactMap { reaction in
            if let available = available?.reactions.first(where: { $0.value.fixed == reaction.value.fixed }) {
                return .init(value: reaction, message: message, context: context, mode: mode, index: getIndex(), available: available, presentation: presentation, action: {
                    engine.react(message.id, value: reaction.isSelected ? nil : reaction.value)
                }, openInfo: openInfo)
            } else {
                return nil
            }
        } ?? []
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
    
   
    func measure(for width: CGFloat) {
                
        var lines:[[Reaction]] = []
        var width = width
        let medium = self.reactions.reduce(0, { $0 + $1.minimumSize.width }) / CGFloat(self.reactions.count)
        switch mode {
        case .full:
            if presentation.renderType == .bubble {
                if !presentation.isOutOfBounds {
                    width = max(width, min(320, medium * 4))
                }
            }
        default:
            break
        }
       
        
        var line:[Reaction] = []
        var current: CGFloat = 0
        for reaction in reactions {
            if current > width && !line.isEmpty {
                lines.append(line)
                line.removeAll()
                line.append(reaction)
                current = reaction.minimumSize.width + presentation.insetInner
            } else {
                line.append(reaction)
                current += reaction.minimumSize.width + presentation.insetInner
            }
        }
        if !line.isEmpty {
            lines.append(line)
            line.removeAll()
        }
        
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
        private let textView = DynamicCounterTextView(frame: .zero)
        private var first: Bool = true
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            textView.userInteractionEnabled = false
            addSubview(imageView)
            addSubview(textView)
            
            
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
            self.reaction = reaction
            self.layer?.cornerRadius = reaction.rect.height / 2
            self.textView.update(reaction.text, animated: animated)
            
//            self.layer?.borderWidth = reaction.value.isSelected || reaction.presentation.borderColor != .clear ? .borderSize : 0
//            self.layer?.borderColor = .clear
//
//
            
            self.backgroundColor = reaction.value.isSelected ? reaction.presentation.selectedColor : reaction.presentation.bgColor

            if animated {
                self.layer?.animateBorder()
                self.layer?.animateBackground()
            }

            let arguments = TransformImageArguments(corners: .init(), imageSize: reaction.presentation.reactionSize, boundingSize: reaction.presentation.reactionSize, intrinsicInsets: NSEdgeInsetsZero, emptyColor: .color(.clear))
            
            self.imageView.setSignal(signal: cachedMedia(media: reaction.available.staticIcon, arguments: arguments, scale: System.backingScale, positionFlags: nil), clearInstantly: true)

            if !self.imageView.isFullyLoaded {
                imageView.setSignal(chatMessageImageFile(account: account, fileReference: .standalone(media: reaction.available.staticIcon), scale: System.backingScale), cacheImage: { result in
                    cacheMedia(result, media: reaction.available.staticIcon, arguments: arguments, scale: System.backingScale)
                })
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
            let presentation = reaction.presentation

            transition.updateFrame(view: self.imageView, frame: CGRect(origin: NSMakePoint(presentation.insetOuter, (size.height - presentation.reactionSize.height) / 2), size: presentation.reactionSize))
            
            let center = focus(reaction.text.size)
            
            transition.updateFrame(view: self.textView, frame: CGRect.init(origin: NSMakePoint(self.imageView.frame.maxX + presentation.insetInner, center.minY), size: reaction.text.size))
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
            
            let arguments = TransformImageArguments(corners: .init(), imageSize: reaction.presentation.reactionSize, boundingSize: reaction.presentation.reactionSize, intrinsicInsets: NSEdgeInsetsZero, emptyColor: .color(.clear))
            self.imageView.setSignal(signal: cachedMedia(media: reaction.available.staticIcon, arguments: arguments, scale: System.backingScale, positionFlags: nil), clearInstantly: true)
            if !self.imageView.isFullyLoaded {
                imageView.setSignal(chatMessageImageFile(account: account, fileReference: .standalone(media: reaction.available.staticIcon), scale: System.backingScale), cacheImage: { result in
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
            if let textView = textView {
                var text_r = focus(reaction.text.size)
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

        for idx in removed.reversed() {
            self.reactions.remove(at: idx)
            let view = self.views.remove(at: idx)
            deletedViews[idx] = view
            performSubviewRemoval(view, animated: animated, checkCompletion: true)
        }
        for (idx, item, pix) in inserted {
            var prevFrame: NSRect? = nil
            var prevView: NSView? = nil
            if let pix = pix {
                prevFrame = previous[pix].rect
                prevView = deletedViews[pix]
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
            if prevView == nil, animated {
                view.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            if idx == 0 {
                addSubview(view, positioned: .below, relativeTo: self.subviews.first)
            } else {
                addSubview(view, positioned: .above, relativeTo: self.subviews[idx - 1])
            }
        }
        
        for (idx, item, prev) in updated {
            if prev != idx {
                self.views[idx].frame = previous[prev].rect
            }
            (self.views[idx] as? ReactionViewImpl)?.update(with: item, account: layout.context.account, animated: animated)
            self.reactions[idx] = item
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
