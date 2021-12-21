//
//  ChatAddReactionControl.swift
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


final class ChatAddReactionControl : NSObject {
    
    private final class ReactionView : Control {
        private let imageView = ImageView()
        private let visualEffect = NSVisualEffectView(frame: .zero)
        private let backgroundView = View()
        private let isBubbled: Bool
        private let reactions: AvailableReactions?
        required init(frame frameRect: NSRect, isBubbled: Bool, reactions: AvailableReactions?, add:@escaping(String)->Void) {
            self.isBubbled = isBubbled
            self.reactions = reactions
            super.init(frame: frameRect)
            self.visualEffect.state = .active
            self.visualEffect.wantsLayer = true
            self.visualEffect.state = .active
            self.visualEffect.blendingMode = .withinWindow
            imageView.isEventLess = true
            backgroundView.isEventLess = true
            
            
            self.layer?.cornerRadius = frameRect.height / 2
            updateLocalizationAndTheme(theme: theme)
            
            visualEffect.layer?.cornerRadius = frameRect.height / 2
            backgroundView.layer?.cornerRadius = frameRect.height / 2

            if isBubbled {
                let shadow = NSShadow()
                shadow.shadowBlurRadius = 8
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
                shadow.shadowOffset = NSMakeSize(0, 0)
                self.shadow = shadow
                addSubview(visualEffect)
                addSubview(backgroundView)
            }
            addSubview(imageView)

            
            contextMenu = { [weak self] in
                guard let reactions = self?.reactions else {
                    return nil
                }
                let menu = ContextMenu(betterInside: true)
                
                for reaction in reactions.reactions {
                    menu.addItem(ContextMenuItem(reaction.value.fixed, handler: {
                        add(reaction.value)
                    }))
                }
                return menu
            }
        }
        private var previous: ControlState = .Normal
        override func stateDidUpdate(_ state: ControlState) {
            let state: ControlState = isSelected ? .Highlight : state
            if state == .Hover, previous == .Normal {
                self.layer?.animateScaleCenter(from: 1, to: 1.2, duration: 0.2, removeOnCompletion: false)
            } else if state == .Normal, previous == .Hover || previous == .Highlight {
                self.layer?.animateScaleCenter(from: 1.2, to: 1, duration: 0.2, removeOnCompletion: false)
            }
            previous = state
            updateLocalizationAndTheme(theme: theme)
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
            imageView.image = isSelected ? theme.icons.chat_reactions_add_active : isBubbled ? theme.icons.chat_reactions_add_bubble : theme.icons.chat_reactions_add
            imageView.sizeToFit()
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            updateLayout(self.frame.size, transition: .immediate)
        }
        
        func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: visualEffect, frame: self.bounds)
            transition.updateFrame(view: self.backgroundView, frame: self.bounds)
            transition.updateFrame(view: imageView, frame: focus(imageView.frame.size))
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
    private let delay = MetaDisposable()
    private var reactions: AvailableReactions?
    init(view: ChatControllerView, context: AccountContext, priority: HandlerPriority, window: Window) {
        self.window = window
        self.view = view
        self.context = context
        self.priority = priority
        super.init()
        initialize()
    }
    
    
    
    private func initialize() {
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
        
        disposable.set(context.reactions.stateValue.start(next: { [weak self] reactions in
            self?.reactions = reactions
            self?.delayAndUpdate()
        }))
    }
    
    deinit {
        disposable.dispose()
        window.removeAllHandlers(for: self)
        delay.dispose()
    }
    
    private var previousItem: ChatRowItem?
    
    private func delayAndUpdate() {
        self.update()
    }
    
    private func update() {
        
        
        if let view = self.view {
            let context = self.context
            let point = view.tableView.contentView.convert(self.window.mouseLocationOutsideOfEventStream, from: nil)
            let inside = view.convert(self.window.mouseLocationOutsideOfEventStream, from: nil)
            let reactions = self.reactions
            let row = view.tableView.row(at: point)
            if row != -1, NSPointInRect(inside, view.tableView.frame)  {
                let item = view.tableView.item(at: row) as? ChatRowItem
                let canReact = item?.canReact == true
                
                if let item = item, canReact {
                    if item.message?.id != self.previousItem?.message?.id {
                        let animated = item.stableId != self.previousItem?.stableId
                        self.previousItem = item
                        self.removeCurrent(animated: animated)
                        
                        if let itemView = item.view as? ChatRowView, let message = item.message {
                            let rect = itemView.rectForReaction
                            let base = view.convert(rect, from: itemView)
                            if NSPointInRect(NSMakePoint(base.midX, base.midY), view.tableView.frame) {
                                delay.set(delaySignal(0.1).start(completed: { [weak self, weak item, weak view] in
                                    if let item = item, let view = view {
                                        let current = ReactionView(frame: base, isBubbled: item.isBubbled, reactions: reactions, add: { value in
                                            let isSelected = message.reactionsAttribute?.reactions.contains(where: { $0.value == value }) == true
                                            context.reactions.react(message.id, value: isSelected ? nil : value)
                                        })
                                        view.addSubview(current, positioned: .above, relativeTo: view.tableView)
                                        if animated {
                                            current.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                                            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                                        }
                                        self?.currentView = current
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
                        let base = view.convert(rect, from: itemView)
                        if NSPointInRect(NSMakePoint(base.midX, base.midY), view.tableView.frame) {
                            current.frame = view.convert(rect, from: itemView)
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
        }
    }
    
    private var isInside: Bool {
        return self.currentView != nil && currentView!.mouseInside()
    }
    
    private func clear() {
        self.removeCurrent(animated: true)
        self.previousItem = nil
        self.delay.set(nil)
    }
    
    private func removeCurrent(animated: Bool) {
        if let view = currentView {
            self.currentView = nil
            performSubviewRemoval(view, animated: animated, scale: true)
        }
    }
    
}
