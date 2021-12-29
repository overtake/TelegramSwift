//
//  AddReactionManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.12.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit
import SwiftSignalKit
import TelegramCore
import Postbox
import ObjcUtils

final class AddReactionManager : NSObject, Notifable {
   
    private final class ItemView : View {
        private let reaction: AvailableReactions.Reaction
        init(frame frameRect: NSRect, reaction: AvailableReactions.Reaction) {
            self.reaction = reaction
            super.init(frame: frameRect)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }
    
    private final class ListView : View  {
        
        
        private final class ReactionView : Control {
                    
            private let player = LottiePlayerView(frame: NSMakeRect(0, 0, 20, 20))
            private let imageView = TransformImageView(frame: NSMakeRect(0, 0, 20, 20))
            private let disposable = MetaDisposable()
            let reaction: AvailableReactions.Reaction
            private let stateDisposable = MetaDisposable()
            required init(frame frameRect: NSRect, context: AccountContext, reaction: AvailableReactions.Reaction, add: @escaping(String)->Void) {
                self.reaction = reaction
                super.init(frame: frameRect)
                addSubview(imageView)
                addSubview(player)
                let signal = context.account.postbox.mediaBox.resourceData(reaction.selectAnimation.resource)
                |> filter {
                    $0.complete
                }
                |> deliverOnMainQueue
                
                stateDisposable.set(player.state.start(next: { [weak self] state in
                    switch state {
                    case .playing:
                        delay(0.016, closure: {
                            self?.imageView.removeFromSuperview()
                        })
                    case .stoped:
                        delay(0.016, closure: {
                            self?.imageView.removeFromSuperview()
                        })
                    default:
                        break
                    }
                }))
                
                let size = imageView.frame.size
                
                let arguments = TransformImageArguments(corners: .init(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsetsZero, emptyColor: nil)
                
                self.imageView.setSignal(signal: cachedMedia(media: reaction.staticIcon, arguments: arguments, scale: System.backingScale, positionFlags: nil), clearInstantly: true)

                if !self.imageView.isFullyLoaded {
                    imageView.setSignal(chatMessageSticker(postbox: context.account.postbox, file: .standalone(media: reaction.staticIcon), small: false, scale: System.backingScale), cacheImage: { result in
                        cacheMedia(result, media: reaction.staticIcon, arguments: arguments, scale: System.backingScale)
                    })
                }

                imageView.set(arguments: arguments)

                disposable.set(signal.start(next: { [weak self] resourceData in
                    if let data = try? Data(contentsOf: URL.init(fileURLWithPath: resourceData.path)) {
                        self?.apply(data)
                    }
                }))
                set(handler: { _ in
                    add(reaction.value)
                }, for: .Click)
                
                contextMenu = {
                    let menu = ContextMenu()
                    menu.addItem(ContextMenuItem(strings().chatContextReactionQuick, handler: {
                        context.reactions.updateQuick(reaction.value)
                    }, itemImage: MenuAnimation.menu_add_to_favorites.value))
                    return menu
                }
            }
            
            private func apply(_ data: Data) {
                let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .bundle("reaction_\(reaction.value)"), size: player.frame.size), type: .lottie, cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 30, runOnQueue: .mainQueue())
                
                player.set(animation, reset: true, saveContext: false, animated: false)

            }
            
            deinit {
                disposable.dispose()
                stateDisposable.dispose()
            }
            
            override func layout() {
                super.layout()
                updateLayout(size: self.frame.size, transition: .immediate)
            }
            
            func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
                transition.updateFrame(view: player, frame: self.focus(player.frame.size))
                transition.updateFrame(view: imageView, frame: self.focus(imageView.frame.size))
            }
            private var previous: ControlState = .Normal
            override func stateDidUpdate(_ state: ControlState) {
                super.stateDidUpdate(state)
                switch state {
                case .Hover:
                    if self.player.animation?.playPolicy == .framesCount(1) {
                        self.player.set(self.player.animation?.withUpdatedPolicy(.once), reset: false)
                    } else {
                        self.player.playAgain()
                    }
                default:
                    break
                }
                
                if previous == .Hover, state == .Highlight {
                    self.layer?.animateScaleCenter(from: 1, to: 0.8, duration: 0.2, removeOnCompletion: false)
                } else if state == .Hover && previous == .Highlight {
                    self.layer?.animateScaleCenter(from: 0.8, to: 1, duration: 0.2, removeOnCompletion: true)
                }
                previous = state
            }
            
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            required init(frame frameRect: NSRect) {
                fatalError("init(frame:) has not been implemented")
            }
        }
        
        private let scrollView = ScrollView()
        private let documentView = View()
        private let list: [AvailableReactions.Reaction]
        private let isReversed: Bool
        required init(frame frameRect: NSRect, context: AccountContext, isReversed: Bool, list: [AvailableReactions.Reaction], add:@escaping(String)->Void) {
            self.list = list
            self.isReversed = isReversed
            super.init(frame: frameRect)
            addSubview(scrollView)
            scrollView.background = .clear
            scrollView.documentView = documentView
            let size = NSMakeSize(30, 30)
            var y: CGFloat = 0
            for reaction in (isReversed ? list.reversed() : list) {
                let reaction = ReactionView(frame: NSMakeRect(0, y, size.width, size.height), context: context, reaction: reaction, add: add)
                documentView.addSubview(reaction)
                y += size.height
            }
            updateLayout(size: frame.size, transition: .immediate)
            
            if isReversed {
                scrollView.clipView.scroll(to: NSMakePoint(0, documentView.frame.height - scrollView.frame.height))
            }
        }
        
        func rect(for reaction: AvailableReactions.Reaction) -> NSRect {
            let view = documentView.subviews.compactMap {
                $0 as? ReactionView
            }.first(where: {
                $0.reaction == reaction
            })
            if let view = view {
                return view.frame
            } else {
                return .zero
            }
        }
        
        
        override func layout() {
            super.layout()
            updateLayout(size: frame.size, transition: .immediate)
        }
        
        static func height(for list: [AvailableReactions.Reaction]) -> CGFloat {
            return min(30 * 5, CGFloat(list.count) * 30)
        }
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
        
        func update(list: [AvailableReactions.Reaction]) {
            
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: self.scrollView, frame: size.bounds)
            transition.updateFrame(view: self.documentView, frame: NSMakeSize(frame.width, CGFloat(list.count) * 30).bounds)
        }
    }
    
    private final class ReactionView : Control {
        
        weak var item: TableRowItem?

        
        private let imageView = TransformImageView(frame: NSMakeRect(0, 0, 12, 12))
        private let visualEffect = NSVisualEffectView(frame: .zero)
        private let backgroundView = View()
        private let isBubbled: Bool
        private let reactions: [AvailableReactions.Reaction]
        private let context: AccountContext
        private let disposable = MetaDisposable()
        private var listView: ListView?
        private let add:(String)->Void
        var isReversed: Bool = false
        var isRemoving: Bool = false
        required init(frame frameRect: NSRect, isBubbled: Bool, context: AccountContext, reactions: [AvailableReactions.Reaction], add:@escaping(String)->Void) {
            self.isBubbled = isBubbled
            self.reactions = reactions
            self.context = context
            self.add = add
            super.init(frame: frameRect)
            self.visualEffect.state = .active
            self.visualEffect.wantsLayer = true
            self.visualEffect.blendingMode = .withinWindow
            backgroundView.isEventLess = true
            
            self.layer?.cornerRadius = frameRect.height / 2
            updateLocalizationAndTheme(theme: theme)
            
            visualEffect.layer?.cornerRadius = frameRect.height / 2
            backgroundView.layer?.cornerRadius = frameRect.height / 2

            let shadow = NSShadow()
            shadow.shadowBlurRadius = 8
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
            shadow.shadowOffset = NSMakeSize(0, 0)
            self.shadow = shadow
            addSubview(visualEffect)
            addSubview(backgroundView)
            addSubview(imageView)

            
            let first = reactions[0]
            let size = imageView.frame.size
            
            let arguments = TransformImageArguments(corners: .init(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsetsZero, emptyColor: nil)
            
            self.imageView.setSignal(signal: cachedMedia(media: first.staticIcon, arguments: arguments, scale: System.backingScale, positionFlags: nil), clearInstantly: true)

            if !self.imageView.isFullyLoaded {
                imageView.setSignal(chatMessageSticker(postbox: context.account.postbox, file: .standalone(media: first.staticIcon), small: false, scale: System.backingScale), cacheImage: { result in
                    cacheMedia(result, media: first.staticIcon, arguments: arguments, scale: System.backingScale)
                })
            }

            imageView.set(arguments: arguments)
            
            set(handler: { _ in
                add(first.value)
            }, for: .Click)
            
            set(handler: { [weak self] _ in
                self?.present()
            }, for: .RightDown)


        }
        private var previous: ControlState = .Normal
        override func stateDidUpdate(_ state: ControlState) {
            let state: ControlState = isSelected ? .Highlight : state
            if state == .Hover, previous == .Normal {
              //  self.layer?.animateScaleCenter(from: 1, to: 1.2, duration: 0.2, removeOnCompletion: false)
            } else if state == .Normal, previous == .Hover || previous == .Highlight {
              //  self.layer?.animateScaleCenter(from: 1.2, to: 1, duration: 0.2, removeOnCompletion: false)
            }
            
            if state == .Hover && previous != .Hover {
                disposable.set(delaySignal(0.7).start(completed: { [weak self] in
                    self?.present()
                }))
            } else if state != .Hover {
                disposable.set(nil)
            }
            previous = state
            updateLocalizationAndTheme(theme: theme)
            
        }
        
        deinit {
            disposable.dispose()
        }
        
        private func present() {
            
            guard self.reactions.count > 1 && self.listView == nil else {
                return
            }
            
            if !isBubbled {
                let shadow = NSShadow()
                shadow.shadowBlurRadius = 8
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
                shadow.shadowOffset = NSMakeSize(0, 0)
                self.shadow = shadow
                addSubview(visualEffect, positioned: .below, relativeTo: self.imageView)
                addSubview(backgroundView, positioned: .below, relativeTo: self.imageView)
            }
            
            let height = ListView.height(for: self.reactions)
            
            
            self.isReversed = self.frame.minY - height - 20 > 0
            
            
            self.listView = ListView(frame: NSMakeRect(0, 0, 30, ListView.height(for: self.reactions)), context: context, isReversed: isReversed, list: reactions, add: { [weak self] value in
                self?.add(value)
            })
            
            guard let listView = listView else {
                return
            }
            
            addSubview(listView, positioned: .below, relativeTo: self.imageView)
            

            let frame = self.frame
            let updated = makeRect(frame)

            
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateFrame(view: self, frame: updated)
            self.updateLayout(updated.size, transition: transition)

            guard let layer = self.layer else {
                return
            }
            
            layer.animateScaleCenter(fromX: frame.width / updated.width, fromY: frame.height / updated.height, to: 1, anchor: NSMakePoint(updated.width / 2, isReversed ? updated.height : 0), duration: 0.2)
            
            listView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            
            let from = frame.width / 2
            let to = updated.width / 2
            layer.cornerRadius = to
            
            let animation = layer.makeAnimation(from: NSNumber(value: from), to: NSNumber(value: to), keyPath: "cornerRadius", timingFunction: .easeInEaseOut, duration: 0.2)
            
            layer.add(animation, forKey: "cornerRadius")
            
            
            visualEffect.layer?.cornerRadius = to
            backgroundView.layer?.cornerRadius = to
            
            backgroundView.layer?.add(animation, forKey: "cornerRadius")
            visualEffect.layer?.add(animation, forKey: "cornerRadius")
            
            performSubviewRemoval(self.imageView, animated: true)
        }
        
        override func updateLocalizationAndTheme(theme: PresentationTheme) {
            super.updateLocalizationAndTheme(theme: theme)
            let theme = theme as! TelegramPresentationTheme
            
            
            if theme.colors.isDark {
                visualEffect.material = .dark
            } else {
                visualEffect.material = .light
            }
            backgroundView.backgroundColor = theme.colors.background.withAlphaComponent(0.4)
            needsLayout = true
            
           
        }
        
        override func scrollWheel(with event: NSEvent) {
            if let superview = superview as? ChatControllerView {
                superview.tableView.scrollWheel(with: event)
            }
            disposable.set(nil)
        }
        
        var isRevealed: Bool {
            return listView != nil
        }
        override func layout() {
            super.layout()
            updateLayout(self.frame.size, transition: .immediate)
        }
        
        func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
            if let listView = self.listView {
                transition.updateFrame(view: listView, frame: self.bounds)
            }
            transition.updateFrame(view: visualEffect, frame: self.bounds)
            transition.updateFrame(view: self.backgroundView, frame: self.bounds)
            transition.updateFrame(view: imageView, frame: focus(imageView.frame.size))
        }
        
        var getBounds:()->NSRect = { return .zero }
        
        func makeRect(_ rect: NSRect) -> NSRect {
            if let _ = listView {
                let height = ListView.height(for: self.reactions)
                
                let dx = 30 - rect.width
                
                
                let x = rect.minX - dx / 2
                var y = rect.minY
                
                if isReversed {
                    y = rect.maxY - height
                }
                
                return NSMakeRect(x, y, 30, height)
            }
            return rect
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }
    
    private var currentView: ReactionView?
    
    private weak var view: ChatControllerView?
    private let window: Window
    private let priority: HandlerPriority
    private let context: AccountContext
    private let disposable = MetaDisposable()
    private let delayDisposable = MetaDisposable()
    private let lockDisposable = MetaDisposable()
    private var reactions: AvailableReactions?
    private var peerView: PeerView?
    private var settings: ReactionSettings = ReactionSettings.default
    private var disabled: Bool = false
    private let chatInteraction: ChatInteraction
    
    private var inOrderToRemove:[WeakReference<ReactionView>] = []
    private var uniqueLimit: Int = Int.max
    init(chatInteraction: ChatInteraction, view: ChatControllerView, peerView: PeerView?, context: AccountContext, priority: HandlerPriority, window: Window) {
        self.chatInteraction = chatInteraction
        self.window = window
        self.view = view
        self.context = context
        self.priority = priority
        self.peerView = peerView
        super.init()
        initialize()
    }
    
    func updatePeerView(_ peerView: PeerView?) {
        self.peerView = peerView
        self.delayAndUpdate()
    }
    
    
    private func initialize() {
        
        if let value = context.appConfiguration.data?["reactions_uniq_max"] as? Double {
            self.uniqueLimit = Int(value)
        }

        chatInteraction.add(observer: self)
        
        window.set(mouseHandler: { [weak self] event in
            self?.delayAndUpdate()
            return .rejected
        }, with: self, for: .mouseEntered, priority: self.priority)
        
        window.set(mouseHandler: { [weak self] event in
            self?.delayAndUpdate()
            return .rejected
        }, with: self, for: .mouseExited, priority: self.priority)
        
        window.set(mouseHandler: { [weak self] event in
            self?.delayAndUpdate()
            return .rejected
        }, with: self, for: .mouseMoved, priority: self.priority)
        
        self.view?.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] _ in
            self?.delayAndUpdate()
        }))
        
        let settings = context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
           |> map { preferencesView -> ReactionSettings in
               let reactionSettings: ReactionSettings
               if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
                   reactionSettings = value
               } else {
                   reactionSettings = .default
               }
               return reactionSettings
           }
        disposable.set(combineLatest(queue: .mainQueue(), context.reactions.stateValue, settings).start(next: { [weak self] reactions, settings in
            self?.reactions = reactions
            self?.settings = settings
            self?.delayAndUpdate()
        }))
    }
    
    deinit {
        disposable.dispose()
        window.removeAllHandlers(for: self)
        delayDisposable.dispose()
        lockDisposable.dispose()
        chatInteraction.remove(observer: self)
    }
    
    private var previousItem: ChatRowItem?
    private var lockId: AnyHashable? {
        didSet {
            if lockId != nil {
                lockDisposable.set(delaySignal(1.0).start(completed: { [weak self] in
                    self?.lockId = nil
                    self?.update(transition: .animated(duration: 0.2, curve: .easeOut))
                }))
            }
        }
    }
    
    private func delayAndUpdate() {
        self.update()
    }
        
    func update(transition: ContainedViewLayoutTransition = .immediate) {
        
        var available:[AvailableReactions.Reaction] = []
        let settings: ReactionSettings = self.settings
        

        if let reactions = reactions {
            if let cachedData = peerView?.cachedData as? CachedGroupData {
                available = reactions.enabled.filter {
                    cachedData.allowedReactions == nil || cachedData.allowedReactions!.contains($0.value)
                }
            } else if let cachedData = peerView?.cachedData as? CachedChannelData {
                available = reactions.enabled.filter {
                    cachedData.allowedReactions == nil || cachedData.allowedReactions!.contains($0.value)
                }
            } else {
                available = reactions.enabled
            }
        }
       
        if let index = available.firstIndex(where: { $0.value == settings.quickReaction }) {
            available.move(at: index, to: 0)
        }
        
        inOrderToRemove = inOrderToRemove.filter({
            $0.value != nil
        })
        
        let uniqueLimit = self.uniqueLimit
        
        func filter(_ list:[AvailableReactions.Reaction], attr: ReactionsMessageAttribute?) -> [AvailableReactions.Reaction] {
            if let attr = attr {
                if attr.reactions.count >= uniqueLimit {
                    return list.filter { reaction in
                        return attr.reactions.contains(where: {
                            $0.value == reaction.value
                        })
                    }
                } else {
                    return list
                }
            } else {
                return list
            }
        }
        
        updateToBeRemoved(transition: transition)
        
        if let view = self.view, !available.isEmpty, !disabled {
            
            
            let point = view.tableView.contentView.convert(self.window.mouseLocationOutsideOfEventStream, from: nil)
            let inside = view.convert(self.window.mouseLocationOutsideOfEventStream, from: nil)
            
            if let current = currentView, current.isRevealed, let item = previousItem {
                let base = current.frame
                let safeRect = base.insetBy(dx: -20 * 4, dy: -20)
                var inSafeRect = NSPointInRect(inside, safeRect)
                inSafeRect = inSafeRect && NSPointInRect(NSMakePoint(base.maxX, base.maxY), view.tableView.frame)
                
                if !inSafeRect || item.view?.visibleRect == .zero {
                    self.clear()
                } else if let itemView = item.view as? ChatRowView {
                    let rect = itemView.rectForReaction
                    let prev = current.isReversed
                    let base = current.makeRect(view.convert(rect, from: itemView))
                    let updated = current.isReversed
                    if prev != updated {
                        self.clear()
                    } else {
                        transition.updateFrame(view: current, frame: base)
                    }
                }
                return
            }

            
            let context = self.context
            
            let findClosest:(NSPoint)->ChatRowItem? = { [weak view] point in
                if let view = view {
                    let current = view.tableView.row(at: point)
                    if current == -1 {
                        return nil
                    }
                    let around:[Int] = [current, current - 1, current + 1].filter { current in
                        return current >= 0 && current < view.tableView.count
                    }
                    var candidates: [ChatRowItem] = []
                    for index in around {
                        if let item = view.tableView.item(at: index) as? ChatRowItem {
                            candidates.append(item)
                        }
                    }
                    if candidates.isEmpty {
                        return nil
                    }
                    var best: ChatRowItem? = nil
                    var min_dst: CGFloat = .greatestFiniteMagnitude
                    for item in candidates {
                        if let itemView = item.view as? ChatRowView {
                            let rect = view.convert(itemView.rectForReaction, from: itemView)
                            let dst = inside.distance(p2: NSMakePoint(rect.midX, rect.midY))
                            if dst < min_dst {
                                best = item
                                min_dst = dst
                            }
                        }
                    }
                    return best
                }
                return nil
            }
            
            if let item = findClosest(point), NSPointInRect(inside, view.tableView.frame) {
                let canReact = item.canReact == true && lockId != item.stableId
                
                if canReact {
                    if item.message?.id != self.previousItem?.message?.id {
                        let animated = item.stableId != self.previousItem?.stableId
                        self.previousItem = item
                        self.removeCurrent(animated: animated)
                        
                        if let itemView = item.view as? ChatRowView, let message = item.message {
                            let rect = itemView.rectForReaction
                            let base = view.convert(rect, from: itemView)
                            
                            let safeRect = base.insetBy(dx: -base.width * 4, dy: -base.height * 4)
                            
                            if NSPointInRect(inside, safeRect), NSPointInRect(NSMakePoint(base.midX, base.midY), view.tableView.frame) {
                                delayDisposable.set(delaySignal(0.4).start(completed: { [weak self, weak item, weak view] in
                                    if let item = item, let view = view {
                                        
                                        let available = filter(available, attr: item.firstMessage?.reactionsAttribute)
                                        
                                        let current = ReactionView(frame: base, isBubbled: item.isBubbled, context: context, reactions: available, add: { [weak self] value in
                                            let isSelected = message.reactionsAttribute?.reactions.contains(where: { $0.value == value && $0.isSelected }) == true
                                            context.reactions.react(message.id, value: isSelected ? nil : value)
                                            self?.clearAndLock()
                                        })
                                                                                
                                        current.getBounds = { [weak view] in
                                            if let view = view {
                                                return view.tableView.bounds
                                            } else {
                                                return .zero
                                            }
                                        }
                                        view.addSubview(current, positioned: .above, relativeTo: view.tableView)
                                        if animated {
                                            current.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                                            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                                        }
                                        self?.currentView = current
                                        current.item = item
                                    }
                                }))
                            } else {
                                if !self.isInside {
                                    self.clear()
                                }
                            }
                        } else {
                            if !self.isInside {
                                self.clear()
                            }
                        }
                    } else if let itemView = item.view as? ChatRowView, let current = self.currentView {
                        let rect = itemView.rectForReaction
                        
                        let base = current.makeRect(view.convert(rect, from: itemView))

                        let safeRect = base.insetBy(dx: -base.width * 4, dy: -base.height * 4)
                        if NSPointInRect(inside, safeRect), NSPointInRect(NSMakePoint(base.midX, base.midY), view.tableView.frame) {
                            transition.updateFrame(view: current, frame: base)
                            current.updateLayout(base.size, transition: transition)
                        } else {
                            self.clear()
                        }
                    }
                } else {
                    if !self.isInside {
                        self.clear()
                    }
                }
            } else {
                if !self.isInside {
                    self.clear()
                }
            }
        } else {
            self.clear()
        }
    }
    
    private var isInside: Bool {
        return self.currentView != nil && currentView!.mouseInside()
    }
    
    private func clear() {
        if let view = self.currentView, view.isRevealed {
            self.lockId = self.previousItem?.stableId
        }
        self.removeCurrent(animated: true)
        self.previousItem = nil
        self.delayDisposable.set(nil)
    }
    private func clearAndLock() {
        self.lockId = self.previousItem?.stableId
        clear()
    }
    
    private func removeCurrent(animated: Bool) {
        if let view = currentView {
            self.currentView = nil
            performSubviewRemoval(view, animated: animated, duration: 0.2, scale: !view.isRevealed)
            view.isRemoving = true
            self.inOrderToRemove.append(.init(value: view))
        }
    }
    
    private func updateToBeRemoved(transition: ContainedViewLayoutTransition) {
        for value in inOrderToRemove {
            if let current = value.value, let view = self.view {
                if let itemView = current.item?.view as? ChatRowView {
                    let rect = itemView.rectForReaction
                    let base = current.makeRect(view.convert(rect, from: itemView))
                    transition.updateFrame(view: current, frame: base)
                }
            }
        }
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        self.update(transition: transition)
        if transition.isAnimated {
            updateToBeRemoved(transition: transition)
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        let presentation = value as? ChatPresentationInterfaceState
        if let presentation = presentation {
            if presentation.state == .selecting {
                disabled = true
                clear()
                removeCurrent(animated: true)
            } else {
                disabled = false
                update()
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? AddReactionManager {
            return other === self
        } else {
            return false
        }
    }
    
}



//
//                        let viewRect = view.convert(rect, from: itemView)
//                        let dst = 50 - min(max(0, inside.distance(p2: NSMakePoint(viewRect.midX, viewRect.midY))), 50)
//
//
//                        let multiplier = log2(mappingRange(dst, 0, 50, 1, 100))
//
//                        NSLog("\(log2(mappingRange(dst, 0, 50, 1, 100)))")
                        
//                        let updated = base.insetBy(dx: -3 * (multiplier / 7), dy: -3 * (multiplier / 7))
                        
