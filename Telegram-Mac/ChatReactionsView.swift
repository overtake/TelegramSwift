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



final class ChatReactionsLayout {
    
    struct Theme {
        let bgColor: NSColor
        let textColor: NSColor
        let borderColor: NSColor
        let selectedColor: NSColor
        let reactionSize: NSSize
        let inset: CGFloat
        
        static func Current(_ renderType: ChatItemRenderType) -> Theme {
            switch renderType {
            case .bubble:
                return .init(bgColor: theme.colors.background, textColor: theme.colors.text, borderColor: theme.colors.border, selectedColor: theme.colors.accent, reactionSize: NSMakeSize(18, 18), inset: 5)
            case .list:
                return .init(bgColor: theme.colors.background, textColor: theme.colors.text, borderColor: theme.colors.border, selectedColor: theme.colors.accent, reactionSize: NSMakeSize(18, 18), inset: 5)
            }
        }
    }
    
    final class Reaction : Equatable, Comparable, Identifiable {
        let value: MessageReaction
        let text: TextViewLayout
        let presentation: Theme
        let index: Int
        let minimiumSize: NSSize
        
        fileprivate(set) var rect: CGRect = .zero
        
        static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            return lhs.value == rhs.value
        }
        static func <(lhs: Reaction, rhs: Reaction) -> Bool {
            return lhs.index < rhs.index
        }
        var stableId: String {
            return self.value.value
        }
        
        init(value: MessageReaction, index: Int, presentation: Theme) {
            self.value = value
            self.index = index
            self.presentation = presentation
            self.text = TextViewLayout.init(.initialize(string: "\(value.count)", color: presentation.textColor, font: .normal(.text)))
            self.text.measure(width: .greatestFiniteMagnitude)
            
            var width: CGFloat = presentation.inset
            width += self.text.layoutSize.width
            width += presentation.inset
            width += presentation.reactionSize.width
            width += presentation.inset
            
            let height = max(self.text.layoutSize.height, presentation.reactionSize.height) + presentation.inset * 2
            
            self.minimiumSize = NSMakeSize(width, height)
        }
        
        func measure(for width: CGFloat, recommendedSize: NSSize) {
           
        }
    }
    
    fileprivate let message: Message
    fileprivate let renderType: ChatItemRenderType
    fileprivate let presentation: Theme
    
    private(set) var size: NSSize = .zero
    fileprivate let reactions: [Reaction]
    
    
    init(message: Message, renderType: ChatItemRenderType) {
        self.message = message
        self.renderType = renderType
        let presentation: Theme = .Current(renderType)
        self.presentation = presentation
        
        var index: Int = 0
        let getIndex:()->Int = {
            index += 1
            return index
        }
        
        
        self.reactions = message.reactionsAttribute?.reactions.map {
            .init(value: $0, index: getIndex(), presentation: presentation)
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
                point.x += reaction.minimiumSize.width
                reaction.rect = rect
            }
            point.x = 0
            point.y += line.map { $0.minimiumSize.height }.max()!
        }
        NSLog("rects: \(reactions.map { $0.rect })")
        self.size = NSMakeSize(width, point.y)
    }
}

final class ChatReactionsView : View {
    
    final class ReactionView: Control {
        private var reaction: ChatReactionsLayout.Reaction?
        
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.backgroundColor = .random
            scaleOnClick = true
        }
        
        func update(with reaction: ChatReactionsLayout.Reaction, animated: Bool) {
            self.reaction = reaction
            self.layer?.cornerRadius = reaction.rect.height / 2
        }
        
        func isOwner(of reaction: ChatReactionsLayout.Reaction) -> Bool {
            return self.reaction?.value.value == reaction.value.value
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {

            
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
            view.update(with: item, animated: animated)
            
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
            self.views[idx].update(with: item, animated: animated)
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
