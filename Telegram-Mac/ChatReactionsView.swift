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



final class ChatReactionsLayout {
    
    struct Theme : Equatable {
        let bgColor: NSColor
        let textColor: NSColor
        let borderColor: NSColor
        let selectedColor: NSColor
        let reactionSize: NSSize
        let insetOuter: CGFloat
        let insetInner: CGFloat

        static func Current(theme: TelegramPresentationTheme, renderType: ChatItemRenderType, isIncoming: Bool, isOutOfBounds: Bool, hasWallpaper: Bool) -> Theme {
            switch renderType {
            case .bubble:
                if isOutOfBounds {
                    return .init(bgColor: theme.colors.bubbleBackground_incoming.lighter(), textColor: theme.colors.textBubble_incoming, borderColor: .clear, selectedColor: theme.colors.bubbleBackground_incoming.darker(), reactionSize: NSMakeSize(16, 16), insetOuter: 10, insetInner: 5)
                } else {
                    if isIncoming {
                        return .init(bgColor: theme.colors.bubbleBackground_incoming.lighter(), textColor: theme.colors.textBubble_incoming, borderColor: .clear, selectedColor: theme.colors.bubbleBackground_incoming.darker(), reactionSize: NSMakeSize(16, 16), insetOuter: 10, insetInner: 5)
                    } else {
                        return .init(bgColor: theme.colors.blendedOutgoingColors.lighter(), textColor: theme.colors.textBubble_outgoing, borderColor: .clear, selectedColor: theme.colors.blendedOutgoingColors.darker(), reactionSize: NSMakeSize(16, 16), insetOuter: 10, insetInner: 5)
                    }
                }
            case .list:
                if theme.dark {
                    return .init(bgColor: theme.colors.grayBackground.lighter(amount: 0.3), textColor: theme.colors.text, borderColor: .clear, selectedColor: theme.colors.grayForeground, reactionSize: NSMakeSize(16, 16), insetOuter: 10, insetInner: 5)
                } else {
                    return .init(bgColor: theme.colors.grayBackground, textColor: theme.colors.text, borderColor: .clear, selectedColor: theme.colors.grayForeground, reactionSize: NSMakeSize(16, 16), insetOuter: 10, insetInner: 5)
                }
            }
        }
    }
    
    final class Reaction : Equatable, Comparable, Identifiable {
        let value: MessageReaction
        let text: DynamicCounterTextView.Value
        let presentation: Theme
        let index: Int
        let minimiumSize: NSSize
        let available: AvailableReactions.Reaction
        let action:()->Void
        fileprivate(set) var rect: CGRect = .zero
        
        static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            return lhs.value == rhs.value &&
            lhs.presentation == rhs.presentation &&
            lhs.index == rhs.index &&
            lhs.minimiumSize == rhs.minimiumSize &&
            lhs.available == rhs.available
        }
        static func <(lhs: Reaction, rhs: Reaction) -> Bool {
            return lhs.index < rhs.index
        }
        var stableId: String {
            return self.value.value
        }
        
        init(value: MessageReaction, index: Int, available: AvailableReactions.Reaction, presentation: Theme, action:@escaping()->Void) {
            self.value = value
            self.index = index
            self.action = action
            self.presentation = presentation
            self.available = available
            
            self.text = DynamicCounterTextView.make(for: "\(value.count)", count: "\(value.count)", font: .normal(.text), textColor: presentation.textColor, width: .greatestFiniteMagnitude)
            
            var width: CGFloat = presentation.insetOuter
            width += presentation.reactionSize.width
            width += presentation.insetInner
            width += self.text.size.width
            width += presentation.insetOuter
            
            
            let height = max(self.text.size.height, presentation.reactionSize.height) + presentation.insetInner * 2
            
            self.minimiumSize = NSMakeSize(width, height)
        }
        
        func measure(for width: CGFloat, recommendedSize: NSSize) {
           
        }
    }
    fileprivate let account: Account
    fileprivate let message: Message
    fileprivate let renderType: ChatItemRenderType
    fileprivate let available: AvailableReactions?
    fileprivate let engine: Reactions
    let presentation: Theme
    
    private(set) var size: NSSize = .zero
    fileprivate let reactions: [Reaction]
    
    
    init(account: Account, message: Message, available: AvailableReactions?, engine:Reactions, renderType: ChatItemRenderType, theme: TelegramPresentationTheme, isIncoming: Bool, isOutOfBounds: Bool, hasWallpaper: Bool) {
        self.message = message
        self.account = account
        self.renderType = renderType
        self.available = available
        self.engine = engine
        let presentation: Theme = .Current(theme: theme, renderType: renderType, isIncoming: isIncoming, isOutOfBounds: isOutOfBounds, hasWallpaper: hasWallpaper)
        self.presentation = presentation
        
        var index: Int = 0
        let getIndex:()->Int = {
            index += 1
            return index
        }
        
        self.reactions = message.reactionsAttribute?.reactions.compactMap { reaction in
            if let available = available?.reactions.first(where: { $0.value.fixed == reaction.value.fixed }) {
                return .init(value: reaction, index: getIndex(), available: available, presentation: presentation, action: {
                    engine.react(message.id, value: reaction.isSelected ? nil : reaction.value)
                })
            } else {
                return nil
            }
        } ?? []
    }
    
    
    func measure(for width: CGFloat) {
        
        var lines:[[Reaction]] = []
        
        var line:[Reaction] = []
        var current: CGFloat = 0
        for reaction in reactions {
            current += reaction.minimiumSize.width
            if current > width && !line.isEmpty {
                lines.append(line)
                line.removeAll()
                current = 0
            } else {
                line.append(reaction)
                current += presentation.insetInner
            }
        }
        if !line.isEmpty {
            lines.append(line)
            line.removeAll()
        }
        
        var point: CGPoint = .zero
        for line in lines {
            for reaction in line {
                var rect = NSZeroRect
                rect.origin = point
                rect.size = reaction.minimiumSize
                point.x += reaction.minimiumSize.width + presentation.insetInner
                reaction.rect = rect
            }
            point.x = 0
            point.y += line.map { $0.minimiumSize.height }.max()! + presentation.insetInner
        }
        self.size = NSMakeSize(width, point.y - presentation.insetInner)
    }
}

final class ChatReactionsView : View {
    
    final class ReactionView: Control {
        private var reaction: ChatReactionsLayout.Reaction?
        private let imageView: TransformImageView = TransformImageView()
        private let textView = DynamicCounterTextView(frame: .zero)
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            textView.userInteractionEnabled = false
            addSubview(imageView)
            addSubview(textView)
            
            
            scaleOnClick = true
            
            self.set(handler: { [weak self] _ in
                self?.reaction?.action()
            }, for: .Click)
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
    }
    
    private var currentLayout: ChatReactionsLayout?
    private var reactions:[ChatReactionsLayout.Reaction] = []
    private var views:[ReactionView] = []
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    
    func update(with layout: ChatReactionsLayout, animated: Bool) {
                
        
        let previous = self.reactions
        
        let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.reactions, rightList: layout.reactions)
        

        var deletedViews:[Int: ReactionView] = [:]

        for idx in removed.reversed() {
            self.reactions.remove(at: idx)
            let view = self.views.remove(at: idx)
            deletedViews[idx] = view
            performSubviewRemoval(view, animated: animated, checkCompletion: true)
        }
        for (idx, item, pix) in inserted {
            var prevFrame: NSRect? = nil
            var prevView: ReactionView? = nil
            if let pix = pix {
                prevFrame = previous[pix].rect
                prevView = deletedViews[pix]
            }
            let view = prevView ?? ReactionView(frame: item.rect)
            view.frame = prevFrame ?? item.rect
            self.views.insert(view, at: idx)
            self.reactions.insert(item, at: idx)
            view.update(with: item, account: layout.account, animated: animated)
            if prevView == nil, animated {
                view.layer?.animateScale(from: 0.1, to: 1, duration: 0.2)
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
            self.views[idx].update(with: item, account: layout.account, animated: animated)
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
            view.updateLayout(size: rect.size, transition: transition)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
