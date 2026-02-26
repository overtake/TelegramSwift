//
//  ChatTopicSeparatorItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.05.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramCore
import TGUIKit

extension ChatHistoryEntry.TopicType {
    var title: String {
        switch self {
        case let .peer(peer):
            return peer._asPeer().displayTitle
        case let .topic(_, info):
            return info.title
        }
    }
    var threadId: Int64 {
        switch self {
        case let .peer(peer):
            return peer.id.toInt64()
        case let .topic(threadId, _):
            return threadId
        }
    }
}

class ChatTopicSeparatorItem : TableStickItem {
    
    let layout:TextViewLayout
    let color: NSColor
    let entry: ChatHistoryEntry
    let interaction: ChatInteraction?
    let presentation: TelegramPresentationTheme
    
    var context: AccountContext? {
        return interaction?.context
    }
    
    init(_ initialSize:NSSize, _ entry:ChatHistoryEntry, interaction: ChatInteraction, theme: TelegramPresentationTheme) {
        
        self.entry = entry
        self.interaction = interaction
        self.presentation = theme
        
        guard case let .topicSeparator(_, type, _, _) = entry else {
            fatalError()
        }
        
        let color = theme.chatServiceItemTextColor
        self.color = color
        
        self.layout = TextViewLayout(.initialize(string: type.title, color: color, font: .medium(theme.fontSize)), maximumNumberOfLines: 1, truncationType: .end, alignment: .center)

        
        super.init(initialSize)
    }
    
    var shouldBlurService: Bool {
        if isLite(.blur) {
            return false
        }
        return presentation.shouldBlurService
    }
    
    required init(_ initialSize: NSSize) {
        self.entry = .empty(MessageIndex.absoluteLowerBound(), theme)
        self.layout = TextViewLayout(NSAttributedString())
        self.interaction = nil
        self.presentation = theme
        self.color = .random
        super.init(initialSize)
    }
    
    override var canBeAnchor: Bool {
        return false
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        layout.measure(width: width - 100)
        return success
    }
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    override var height: CGFloat {
        return 28
    }
    
    override func viewClass() -> AnyClass {
        return ChatTopicSeparatorItemView.self
    }
    
}

private class ChatTopicSeparatorItemView : TableStickView {
    
    private final class LineView : View {
        
        weak var item: ChatTopicSeparatorItem? {
            didSet {
                needsDisplay = true
            }
        }
        
        override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            
            guard let item else {
                return
            }
            
            let bounds = layer.bounds
            let lineWidth: CGFloat = 1.0
            let dashLength: CGFloat = 4.0
            let dashGap: CGFloat = 2.0
            let centerY = bounds.midY

            ctx.saveGState()

            // Set stroke color (you can customize this)
            ctx.setStrokeColor(item.presentation.chatServiceItemColor.cgColor)

            // Set line width
            ctx.setLineWidth(lineWidth)

            // Set line cap to round
            ctx.setLineCap(.round)

            // Set line dash pattern
            ctx.setLineDash(phase: 0, lengths: [dashLength, dashGap])

            // Move to start point and add line to end point
            ctx.move(to: CGPoint(x: bounds.minX, y: centerY))
            ctx.addLine(to: CGPoint(x: bounds.maxX, y: centerY))

            // Stroke the path
            ctx.strokePath()

            ctx.restoreGState()
            
        }
    }
    
    private let textView:TextView = TextView()
    private var avatarView: AvatarControl?
    private var iconView: InlineStickerView?
    private let containerView: View = View()
    private let backgroundView = View()
    private let overlay = Control()
    private let chevron = ImageView()
    private let lineView = LineView()
    private var visualEffect: VisualEffect?
    required init(frame frameRect: NSRect) {
        
        self.textView.isSelectable = false
        self.textView.userInteractionEnabled = false
        self.containerView.wantsLayer = true
        super.init(frame: frameRect)
        addSubview(lineView)
        addSubview(backgroundView)
        containerView.addSubview(textView)
        containerView.addSubview(chevron)
        addSubview(containerView)
        
        addSubview(overlay)
        
        
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
       
        return .clear
    }
    
    override func updateIsVisible(_ visible: Bool, animated: Bool) {
        backgroundView.change(opacity: visible ? 1 : 0, animated: animated)
        containerView.change(opacity: visible ? 1 : 0, animated: animated)
    }
    
    override var header: Bool {
        didSet {
            lineView.change(opacity: header ? 0 : 1, animated: true)
            
        }
    }
    
    override func updateColors() {
        super.updateColors()
        
        guard let item = item as? ChatTopicSeparatorItem else {
            return
        }
        backgroundView.backgroundColor = item.presentation.chatServiceItemColor
    }
    

    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? ChatTopicSeparatorItem, let monoforumState = item.entry.additionalData.monoforumState else {
            return
        }
        
        let animationView = self.avatarView ?? self.iconView

        
        let blockWidth = (animationView?.frame.width ?? 0) + textView.frame.width + chevron.frame.width + 5 + 3
        
        transition.updateFrame(view: containerView, frame: focus(NSMakeSize(blockWidth, size.height)).offsetBy(dx: monoforumState == .vertical ? 40 : 0, dy: 0))
        
        
        
        if let animationView {
            transition.updateFrame(view: animationView, frame: animationView.centerFrameY(x: self.iconView != nil ? 1 : 0))
            transition.updateFrame(view: textView, frame: textView.centerFrameY(x: animationView.frame.maxX + 5))
        }
        transition.updateFrame(view: chevron, frame: chevron.centerFrameY(x: textView.frame.maxX + 3, addition: -1))
        transition.updateFrame(view: overlay, frame: size.bounds)
        
        
        transition.updateFrame(view: backgroundView, frame: NSMakeRect(containerView.frame.minX - 3, 2, containerView.frame.width + 3, size.height - 4))
        
        transition.updateFrame(view: lineView, frame: size.bounds)
        
        if let visualEffect {
            transition.updateFrame(view: visualEffect, frame: backgroundView.bounds)
        }

    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated:animated)
        
        guard let item = item as? ChatTopicSeparatorItem else {
            return
        }
        
        guard case let .topicSeparator(_, type, _, _) = item.entry else {
            return
        }
        
        if item.shouldBlurService {
            let blurBackground = item.presentation.blurServiceColor
            
            if self.visualEffect == nil {
                self.visualEffect = VisualEffect(frame: self.bounds)
                self.backgroundView.addSubview(self.visualEffect!, positioned: .below, relativeTo: nil)
            }
            self.visualEffect?.bgColor = blurBackground
            self.backgroundView.backgroundColor = .clear
        } else {
            if let visualEffect {
                performSubviewRemoval(visualEffect, animated: animated)
                self.visualEffect = nil
            }
            self.backgroundView.backgroundColor = item.presentation.chatServiceItemColor
        }
        
        lineView.item = item
        
        backgroundView.layer?.cornerRadius = (item.height - 4) / 2
        
        chevron.image = NSImage(resource: .iconAffiliateChevron).precomposed(item.color.withAlphaComponent(0.6), zoom: 0.8)
        chevron.sizeToFit()
        
        self.textView.update(item.layout)
        
        if let context = item.context {
            
            switch type {
            case let .peer(peer):
                
                if let iconView {
                    performSubviewRemoval(iconView, animated: animated)
                    self.iconView = nil
                }
                
                let current: AvatarControl
                if let view = self.avatarView {
                    current = view
                } else {
                    current = AvatarControl(font: .avatar(10))
                    current.setFrameSize(NSMakeSize(18, 18))
                    containerView.addSubview(current)
                    self.avatarView = current
                }
                current.setPeer(account: context.account, peer: peer._asPeer())
            case let .topic(threadId, info):
                
                if let avatarView {
                    performSubviewRemoval(avatarView, animated: animated)
                    self.avatarView = nil
                }
                
                let fileId = info.icon ?? 0
                if let view = self.iconView, view.animateLayer.fileId == fileId || view.animateLayer.fileId == threadId {
                } else {
                    if let iconView {
                        iconView.removeFromSuperview()
                        self.iconView = nil
                    }
                    
                    let file: TelegramMediaFile?
                    if fileId == 0 {
                        file = ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor, isGeneral: threadId == 1)
                    } else {
                        file = nil
                    }
                    
                    let animatedView = InlineStickerView(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId == 0 ? threadId : fileId, file: file, emoji: ""), size: NSMakeSize(18, 18))
                    
                    self.iconView = animatedView
                    containerView.addSubview(animatedView)
                }

            }
            
            overlay.setSingle(handler: { [weak item] _ in
                item?.interaction?.updateChatLocationThread(type.threadId)
            }, for: .Click)
        }
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        self.updateLayout(size: self.frame.size, transition: transition)

    }
    
}
