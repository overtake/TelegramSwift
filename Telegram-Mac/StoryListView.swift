//
//  StoryContainerView.swift
//  Telegram
//
//  Created by Mike Renoir on 25.04.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TGModernGrowingTextView
import TelegramMedia

private final class StoryRepostView : Control {
    private let borderLayer = DashLayer()
    private let nameView = TextView()
    private let textView: TextView = TextView()
    
    private var text_inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]
    private var header_inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]

    private let disposable = MetaDisposable()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(nameView)
        addSubview(textView)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        textView.userInteractionEnabled = false
        textView.isSelectable = false

        self.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        self.layer?.addSublayer(borderLayer)
        self.layer?.cornerRadius = .cornerRadius
        
        scaleOnClick = true
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(forwardInfo: EngineStoryItem.ForwardInfo, story: EngineStoryItem, context: AccountContext, arguments: StoryArguments) {
        let colors: PeerNameColor?
        let nameText: String
        let text = "Story"
        
        
        
        let forwardPeer: Peer?
        let storyId: StoryId?
        switch forwardInfo {
        case let .known(peer, id, _):
            colors = peer.nameColor
            forwardPeer = peer._asPeer()
            nameText = peer._asPeer().compactDisplayTitle
            storyId = .init(peerId: peer.id, id: id)
        case let .unknown(name, _):
            colors = nil
            nameText = name
            forwardPeer = nil
            storyId = nil
        }
        
        let nameAttr = NSMutableAttributedString()
        
        if let forwardPeer = forwardPeer {
            if forwardPeer.isChannel {
                nameAttr.insert(.embedded(name: "Icon_Reply_Channel", color: NSColor(rgb: 0xffffff), resize: false), at: 0)
            } else if forwardPeer.isUser {
                nameAttr.insert(.embedded(name: "Icon_Reply_User", color: NSColor(rgb: 0xffffff), resize: false), at: 0)
            } else {
                nameAttr.append(.embedded(name: "Icon_Reply_Group", color: NSColor(rgb: 0xffffff), resize: false))
            }
        } else {
            nameAttr.insert(.embedded(name: "Icon_Reply_User", color: NSColor(rgb: 0xffffff), resize: false), at: 0)
        }
        
        nameAttr.append(string: nameText, color: NSColor.white, font: .normal(.text))
        
        
        let nameLayout = TextViewLayout(nameAttr, maximumNumberOfLines: 1)
        nameLayout.measure(width: .greatestFiniteMagnitude)
        self.nameView.update(nameLayout)
        
        
        let textLayout = TextViewLayout(.initialize(string: text, color: NSColor.white.withAlphaComponent(0.8), font: .normal(.text)), maximumNumberOfLines: 1)
        self.textView.update(textLayout)
        
        
        updateInlineStickers(context: context, view: self.nameView, textLayout: nameLayout, itemViews: &header_inlineStickerItemViews)
        updateInlineStickers(context: context, view: self.textView, textLayout: textLayout, itemViews: &text_inlineStickerItemViews)

        
        if let colors = colors {
            let value = context.peerNameColors.get(colors)
            borderLayer.colors = .init(main: NSColor(0xffffff), secondary: value.secondary != nil ? NSColor(0xffffff, 0) : nil, tertiary: value.tertiary != nil ? NSColor(0xffffff, 0) : nil)
        } else {
            borderLayer.colors = .init(main: NSColor(0xffffff), secondary: nil, tertiary: nil)
        }
        var height: CGFloat
        if let storyId = storyId, !text.isEmpty {
            self.borderLayer.isHidden = false
            self.textView.isHidden = false
            height = 36
            layer?.cornerRadius = .cornerRadius
            let signal = arguments.loadForward(storyId).get() |> deliverOnMainQueue
            disposable.set(signal.start(next: { [weak self] item in
                guard let `self` = self else {
                    return
                }
                if let item = item {
                    let textLayout = TextViewLayout(.initialize(string: item.text, color: NSColor.white.withAlphaComponent(0.8), font: .normal(.text)), maximumNumberOfLines: 1)
                    textLayout.measure(width: .greatestFiniteMagnitude)
                    self.textView.update(textLayout)
                }
                self.textView.isHidden = item?.text.isEmpty == true || item == nil
                height = self.textView.isHidden ? 20.0 : 36.0
                self.setFrameSize(NSMakeSize(self.frame.width, height))
                self.updateLayout(size: self.frame.size, transition: .immediate)

                borderLayer.isHidden = self.textView.isHidden
                if height == 20 {
                    self.layer?.cornerRadius = height / 2
                } else {
                    self.layer?.cornerRadius = .cornerRadius
                }
            }))
        } else {
            height = 20
            borderLayer.isHidden = true
            self.textView.isHidden = true
            layer?.cornerRadius = height / 2
        }
        
        self.removeAllHandlers()

        if let storyId = storyId {
            self.set(handler: { [weak arguments] _ in
                if storyId.id != 0 {
                    arguments?.openStory(storyId)
                } else {
                    for media in story.mediaAreas {
                        switch media {
                        case let .channelMessage(_, messageId):
                            arguments?.openChat(messageId.peerId, messageId, nil)
                        default:
                            break
                        }
                    }
                }
            }, for: .Click)
        }
        
        self.setFrameSize(NSMakeSize(self.frame.width, height))
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(layer: self.borderLayer, frame: NSMakeRect(0, 0, 3, size.height))
        transition.updateFrame(view: self.nameView, frame: CGRect(origin: NSMakePoint(6, 2), size: self.nameView.frame.size))
        transition.updateFrame(view: self.textView, frame: CGRect(origin: NSMakePoint(8, size.height - textView.frame.height - 3), size: self.textView.frame.size))

    }
    
    func updateInlineStickers(context: AccountContext, view textView: TextView, textLayout: TextViewLayout, itemViews: inout [InlineStickerItemLayer.Key: InlineStickerItemLayer]) {
        var validIds: [InlineStickerItemLayer.Key] = []
        var index: Int = textView.hashValue
        
        let textColor: NSColor
        if textLayout.attributedString.length > 0 {
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = textLayout.attributedString.attributes(at: max(0, textLayout.attributedString.length - 1), effectiveRange: &range)
            textColor = attrs[.foregroundColor] as? NSColor ?? theme.colors.text
        } else {
            textColor = theme.colors.text
        }

        for item in textLayout.embeddedItems {
            if let stickerItem = item.value as? InlineStickerItem, case let .attribute(emoji) = stickerItem.source {
                
                let id = InlineStickerItemLayer.Key(id: emoji.fileId, index: index, color: textColor)
                validIds.append(id)
                
                let rect = item.rect.insetBy(dx: 0, dy: 0)
                
                let view: InlineStickerItemLayer
                if let current = itemViews[id], current.frame.size == rect.size && current.textColor == id.color {
                    view = current
                } else {
                    itemViews[id]?.removeFromSuperlayer()
                    view = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: emoji, size: rect.size, textColor: textColor)
                    itemViews[id] = view
                    view.superview = textView
                    textView.addEmbeddedLayer(view)
                }
                index += 1
                
                view.frame = rect
            }
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayer) in itemViews {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            itemViews.removeValue(forKey: key)
        }
        updateAnimatableContent()
    }
    
    
    
    
    @objc func updateAnimatableContent() -> Void {
        for (_, value) in text_inlineStickerItemViews {
            if let superview = value.superview {
                value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && window != nil && window!.isKeyWindow
            }
        }
        for (_, value) in header_inlineStickerItemViews {
            if let superview = value.superview {
                value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && window != nil && window!.isKeyWindow
            }
        }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    private func updateListeners() {
        let center = NotificationCenter.default
        if let window = window {
            center.removeObserver(self)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
        } else {
            center.removeObserver(self)
        }
    }
    private var first: Bool = true
    func size(max width: CGFloat, transition: ContainedViewLayoutTransition) -> NSSize {
        nameView.resize(width - 15)
        textView.resize(width - 15)
        return NSMakeSize(max(nameView.frame.maxX, textView.frame.maxX) + 5, frame.height)
    }
    
    deinit {
        disposable.dispose()
    }
}



private extension NSImage {
    func tint(color: NSColor) -> NSImage {
        return NSImage(size: size, flipped: false) { (rect) -> Bool in
            color.set()
            rect.insetBy(dx: 2, dy: 2).fill()
            self.draw(in: rect, from: NSRect(origin: .zero, size: self.size), operation: .destinationIn, fraction: 1.0)
            return true
        }
    }
}

extension MediaArea {
    var title: String {
        switch self {
        case .venue:
            return strings().storyViewMediaAreaViewLocation
        case .reaction:
            return ""
        case .weather:
            return ""
        case .channelMessage:
            return strings().storyViewMediaAreaViewMessage
        case .link:
            return strings().storyViewMediaAreaOpenUrl
        case .starGift:
            return strings().storyWidgetOpenGift
        }
    }
    var menu: MenuAnimation {
        switch self {
        case .venue:
            return MenuAnimation.menu_location
        case .reaction:
            return MenuAnimation.menu_reactions
        case .channelMessage:
            return MenuAnimation.menu_show_message
        case .link:
            return MenuAnimation.menu_copy_link
        case .weather:
            return MenuAnimation.menu_copy_link
        case .starGift:
            return MenuAnimation.menu_show_message
        }
    }
    var canDraw: Bool {
        switch self {
        case .venue:
            return false
        case .channelMessage:
            return false
        case .reaction:
            return true
        case .link:
            return false
        case .weather:
            return true
        case .starGift:
            return false
        }
    }
    
    var canClick: Bool {
        switch self {
        case .venue:
            return true
        case .channelMessage:
            return true
        case .reaction:
            return false
        case .link:
            return true
        case .weather:
            return false
        case .starGift:
            return true
        }
    }
    
    var reaction: MessageReaction.Reaction? {
        switch self {
        case let .reaction(_, reaction, _):
            return reaction
        default:
            return nil
        }
    }
    var isDark: Bool {
        switch self {
        case let .reaction(_, _, flags):
            return flags.contains(.isDark)
        default:
            return false
        }
    }
    
}

private protocol InteractiveMedia {
    var mediaArea: MediaArea { get }
    func apply(area: MediaArea, count: Int32?, arguments: StoryArguments, animated: Bool)
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition)
}


private final class Reaction_InteractiveMedia : Control, InteractiveMedia {
    
    var _mediaArea: MediaArea
    
    var mediaArea: MediaArea {
        return _mediaArea
    }
    
    private final class Container : NSImageView {
        override var isFlipped: Bool {
            return true
        }
    }
    
    private static let shadowImage: NSImage = {
        return NSImage(named: "Icon_Story_InlineReaction_Shadow")!
    }()
    
    private static let coverImage: NSImage = {
        return NSImage(named: "Icon_Story_InlineReaction")!
    }()

    
    private let bg_view: NSImageView = NSImageView()
    private let shadow_view: NSImageView = NSImageView()

    private var reactionLayer: InlineStickerItemLayer?
    private var arguments: StoryArguments?
    
    private var counterText: DynamicCounterTextView?

    
    private let control = View()
    private let counter = Container()
    
    
    private var reaction: MessageReaction.Reaction?
    
    required init(frame frameRect: NSRect, mediaArea: MediaArea) {
        _mediaArea = mediaArea
        super.init(frame: frameRect)
        addSubview(shadow_view)
        addSubview(bg_view)
        self.layer?.cornerRadius = frameRect.height / 2
        self.scaleOnClick = true
        
        bg_view.imageScaling = .scaleAxesIndependently
        shadow_view.imageScaling = .scaleAxesIndependently

        self.addSubview(control)
        self.addSubview(counter)
        
        counter.wantsLayer = true
        
        bg_view.wantsLayer = true
        shadow_view.wantsLayer = true
        
        control.layer?.masksToBounds = false
        counter.layer?.masksToBounds = false

        
        bg_view.image = Reaction_InteractiveMedia.coverImage
        shadow_view.image = Reaction_InteractiveMedia.shadowImage
        

        self.set(handler: { [weak self] _ in
            self?.action()
        }, for: .Click)
        
        self.layer?.masksToBounds = false
        
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    private func action() {
        guard let layer = self.reactionLayer, let arguments = self.arguments else {
            return
        }
        layer.isPlayable = true
        layer.playAgain()
        
        
        let update: UpdateMessageReaction?
        switch self.mediaArea {
        case let .reaction(_, reaction, _):
            switch reaction {
            case let .builtin(string):
                update = .builtin(string)
            case let .custom(fileId):
                update = .custom(fileId: fileId, file: layer.file)
            case .stars:
                update = .stars
            }
            arguments.like(reaction, arguments.interaction.presentation)
        default:
            update = nil
        }
        guard let item = update else {
            return
        }
        
        let action = StoryReactionAction(item: item, fromRect: nil)
        
        self.playReaction(action, context: arguments.context)
    }
    
    
    func apply(area: MediaArea, count: Int32?, arguments: StoryArguments, animated: Bool) {
        self.arguments = arguments
        self._mediaArea = mediaArea
        
        let isDark: Bool = area.isDark

        if self.reaction != area.reaction, let reaction = area.reaction {
            self.reactionLayer?.removeFromSuperlayer()
            self.reactionLayer = nil
            
            self.reactionLayer = makeView(reaction, state: arguments.interaction.presentation, context: arguments.context)
            
            self.bg_view.image = Reaction_InteractiveMedia.coverImage.tint(color: isDark ? NSColor(rgb: 0x000000, alpha: 0.5) : NSColor.white)
            
        }
        self.reaction = area.reaction

        
        if let count = count, count > 0 {
            let current: DynamicCounterTextView
            var isNew = false
            if let view = self.counterText {
                current = view
            } else {
                current = DynamicCounterTextView(frame: .zero)
                self.counterText = current
                counter.addSubview(current)
                isNew = true
            }
            
            let counterScale = max(0.01, min(1.8, frame.width / 140.0))


            let text = DynamicCounterTextView.make(for: Int(count).prettyNumber, count: "\(count)", font: .digitalRound(17 * counterScale), textColor: isDark ? .white : .black, width: .greatestFiniteMagnitude)
            current.update(text, animated: animated && !isNew)
            current.change(size: text.size, animated: animated && !isNew)
            
            if isNew, animated {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
            }
            
        } else if let view = self.counterText {
            performSubviewRemoval(view, animated: animated)
            self.counterText = nil
        }
        
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    private func makeView(_ reaction: MessageReaction.Reaction, state: StoryInteraction.State, context: AccountContext) -> InlineStickerItemLayer? {
        let layer: InlineStickerItemLayer?
        let minSide = floor(min(frame.width, frame.height) * 0.65)
        let size = CGSize(width: minSide, height: minSide)
        
        switch reaction {
        case let .custom(fileId):
            layer = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: size, playPolicy: .loop, getColors: { file in
                var colors: [LottieColor] = []
                if isDefaultStatusesPackId(file.emojiReference) {
                    colors.append(.init(keyPath: "", color: NSColor(0x000000)))
                }
                if file.paintToText {
                    colors.append(.init(keyPath: "", color: NSColor(0x000000)))
                }
                return colors
            })
        case .builtin:
            if let animation = state.reactions?.reactions.first(where: { $0.value == reaction }) {
                let file = animation.selectAnimation
                layer = InlineStickerItemLayer(account: context.account, file: file._parse(), size: size, playPolicy: .loop)
            } else {
                layer = nil
            }
        case .stars:
            layer = nil
        }
        if let layer = layer {
            layer.superview = self
            layer.frame = focus(size)
            control.layer?.addSublayer(layer)
            layer.isPlayable = true
        }
        return layer
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        let isFlipped: Bool
        switch self.mediaArea {
        case let .reaction(_, _, flags):
            isFlipped = flags.contains(.isFlipped)
        default:
            isFlipped = false
        }
        
        let insets = NSEdgeInsets(top: -0.08, left: -0.05, bottom: -0.01, right: -0.02)
        let bg_rect = CGRect(origin: CGPoint(x: size.width * insets.left, y: size.height * insets.top), size: CGSize(width: size.width - size.width * insets.left - size.width * insets.right, height: size.height - size.height * insets.top - size.height * insets.bottom))
                
        

        transition.updateFrame(view: shadow_view, frame: bg_rect)
        transition.updateFrame(view: bg_view, frame: bg_rect)
        
        transition.updateFrame(view: control, frame: size.bounds)
        transition.updateFrame(view: counter, frame: size.bounds)
        
        
        if let counterText = self.counterText {
            let point = CGPoint(x: size.width * 0.5 - counterText.frame.width * 0.5, y: floorToScreenPixels(backingScaleFactor, size.height * 0.765 - 5))
            transition.updateFrame(view: counterText, frame: CGRect(origin: point, size: counterText.frame.size))
        }
        
        counter.layer?.position = CGPoint(x: counter.frame.midX, y: counter.frame.midY)
        counter.layer?.anchorPoint = NSMakePoint(0.5, 0.5)
        counter.layer?.transform = CATransform3DMakeRotation(mediaArea.coordinates.rotation * Double.pi / 180.0, 0, 0.0, 1.0)
        
        let counterFractionOffset: CGFloat
        let stickerScale: CGFloat
        if counterText != nil {
            counterFractionOffset = -0.05
            stickerScale = 0.8
        } else {
            counterFractionOffset = 0.0
            stickerScale = 1.0
        }
        
        if let layer = self.reactionLayer {
            let rect = size.centered(around: CGPoint(x: size.width * 0.49, y: size.height * (0.47 + counterFractionOffset)))
            transition.updateFrame(layer: layer, frame: rect)
            layer.transform = CATransform3DMakeRotation(mediaArea.coordinates.rotation * Double.pi / 180.0, 0.0, 0.0, 1.0)
            layer.transform = CATransform3DScale(layer.transform, stickerScale, stickerScale, 1)
        }
        
        var transform = CATransform3DMakeRotation(mediaArea.coordinates.rotation * Double.pi / 180.0, 0, 0.0, 1.0)
        
        if isFlipped {
            transform = CATransform3DScale(transform, -1, 1, 1)
        }
        
        bg_view.layer?.position = CGPoint(x: bg_view.frame.midX, y: bg_view.frame.midY)
        bg_view.layer?.anchorPoint = NSMakePoint(0.5, 0.5)
        bg_view.layer?.transform = transform
        
        shadow_view.layer?.position = CGPoint(x: shadow_view.frame.midX, y: shadow_view.frame.midY)
        shadow_view.layer?.anchorPoint = NSMakePoint(0.5, 0.5)
        shadow_view.layer?.transform = transform
        


    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func playReaction(_ reaction: StoryReactionAction, context: AccountContext) -> Void {
         
        let size = NSMakeSize(self.frame.width * 3.0, self.frame.height * 3.0)
        
         var effectFileId: Int64?
         var effectFile: TelegramMediaFile?
         switch reaction.item {
         case let .custom(fileId, file):
             effectFileId = fileId
             effectFile = file
         case let .builtin(string):
             let reaction = context.reactions.available?.reactions.first(where: { $0.value.string.withoutColorizer == string.withoutColorizer })
             effectFile = reaction?.aroundAnimation?._parse()
         case .stars:
             break
         }
         
                
         let play:(NSView)->Void = { [weak self] container in
             guard let `self` = self else {
                 return
             }
             if let effectFileId = effectFileId {
                 let player = CustomReactionEffectView(frame: NSMakeSize(size.width * 2, size.height * 2).bounds, context: context, fileId: effectFileId, file: effectFile)
                 player.isEventLess = true
                 player.triggerOnFinish = { [weak player] in
                     player?.removeFromSuperview()
                 }
                 let rect = player.frame.size.centered(around: NSMakePoint(self.frame.midX, self.frame.midY))
                 player.frame = rect
                 container.addSubview(player)
                 
             } else if let effectFile = effectFile {
                 let player = InlineStickerView(account: context.account, file: effectFile, size: size, playPolicy: .playCount(1), controlContent: false)
                 player.isEventLess = true
                 player.animateLayer.isPlayable = true
                 let rect = player.frame.size.centered(around: NSMakePoint(self.frame.midX, self.frame.midY))

                 player.frame = rect
                 
                 container.addSubview(player)
                 player.animateLayer.triggerOnState = (.finished, { [weak player] state in
                     player?.removeFromSuperview()
                 })
             }
         }
         
         let completed: (Bool)->Void = { [weak self]  _ in
             DispatchQueue.main.async {
                 if let container = self?.superview {
                     play(container)
                 }
             }
         }
        completed(true)
     }
    
}

private final class Weather_InteractiveMedia: EventLessView, InteractiveMedia {
    
    var _mediaArea: MediaArea
    
    var mediaArea: MediaArea {
        return _mediaArea
    }
    
    
    private var emojiView: InlineStickerItemLayer?
    private var arguments: StoryArguments?
    
    private let textView: TextView = TextView()
    private let temperature: String
    let color: NSColor
    let emoji: String
    let file: Signal<TelegramMediaFile?, NoError>
    private let disposable = MetaDisposable()
    private let context: AccountContext
    
    private var emojiSize: NSSize = .zero
    private var emojiFile: TelegramMediaFile? = nil
    
    required init(frame frameRect: NSRect, mediaArea: MediaArea, context: AccountContext) {
        _mediaArea = mediaArea
        self.context = context
        switch mediaArea {
        case .weather(_, let emoji, let temperature, let color):
            self.emoji = emoji
            self.temperature = stringForTemperature(temperature).uppercased()
            self.file = context.diceCache.animatedEmojies |> map {
                return $0[emoji]?.file._parse()
            } |> deliverOnMainQueue
            self.color = NSColor(argb: UInt32(bitPattern: color))
        default:
            fatalError("no way to be here")
        }
        super.init(frame: frameRect)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        
        addSubview(textView)
                
        self.wantsLayer = true
        self.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.layer?.allowsEdgeAntialiasing = true
        self.layer?.rasterizationScale = backingScaleFactor
        self.layer?.shouldRasterize = true
        self.layer?.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerBottomEdge, .layerTopEdge]

        self.layer?.backgroundColor = color.cgColor

        self.layer?.cornerRadius = 10
        
        
        
        if #available(macOS 10.15, *) {
            self.layer?.cornerCurve = .continuous
        }
        
        self.rotateView(to: mediaArea.coordinates.rotation)
        
        self.updateLayout(size: self.frame.size, transition: .immediate)
        
        disposable.set(file.start(next: { [weak self] file in
            self?.emojiFile = file
            if let size = self?.frame.size {
                self?.updateLayout(size: size, transition: .immediate)
            }
        }))
    }
    
    func playReaction(_ reaction: StoryReactionAction, context: AccountContext) -> Void {
         
        let size = NSMakeSize(self.frame.width * 3.0, self.frame.height * 3.0)
        
         var effectFileId: Int64?
         var effectFile: TelegramMediaFile?
         switch reaction.item {
         case let .custom(fileId, file):
             effectFileId = fileId
             effectFile = file
         case let .builtin(string):
             let reaction = context.reactions.available?.reactions.first(where: { $0.value.string.withoutColorizer == string.withoutColorizer })
             effectFile = reaction?.aroundAnimation?._parse()
         case .stars:
             break
         }
         
                
         let play:(NSView)->Void = { [weak self] container in
             guard let `self` = self else {
                 return
             }
             if let effectFileId = effectFileId {
                 let player = CustomReactionEffectView(frame: NSMakeSize(size.width * 2, size.height * 2).bounds, context: context, fileId: effectFileId, file: effectFile)
                 player.isEventLess = true
                 player.triggerOnFinish = { [weak player] in
                     player?.removeFromSuperview()
                 }
                 let rect = player.frame.size.centered(around: NSMakePoint(self.frame.midX, self.frame.midY))
                 player.frame = rect
                 container.addSubview(player)
                 
             } else if let effectFile = effectFile {
                 let player = InlineStickerView(account: context.account, file: effectFile, size: size, playPolicy: .playCount(1), controlContent: false)
                 player.isEventLess = true
                 player.animateLayer.isPlayable = true
                 let rect = player.frame.size.centered(around: NSMakePoint(self.frame.midX, self.frame.midY))

                 player.frame = rect
                 
                 container.addSubview(player)
                 player.animateLayer.triggerOnState = (.finished, { [weak player] state in
                     player?.removeFromSuperview()
                 })
             }
         }
         
         let completed: (Bool)->Void = { [weak self]  _ in
             DispatchQueue.main.async {
                 if let container = self?.superview {
                     play(container)
                 }
             }
         }
        completed(true)
     }
    
    private func drawSticker(_ file: TelegramMediaFile, context: AccountContext) {
        
        
        self.emojiView?.removeFromSuperlayer()
        
        let layer = InlineStickerItemLayer(account: context.account, file: file, size: emojiSize)
        layer.superview = self
        layer.isPlayable = true
        
        self.layer?.addSublayer(layer)
        
        self.emojiView = layer
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.rotateView(to: _mediaArea.coordinates.rotation)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required override init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func updateLayer() {
        super.updateLayer()
        self.rotateView(to: _mediaArea.coordinates.rotation)
    }
    
    private func action() {
        // Define your action here
    }
    
    func apply(area: MediaArea, count: Int32?, arguments: StoryArguments, animated: Bool) {
        self.arguments = arguments
        self._mediaArea = area
        
        self.rotateView(to: area.coordinates.rotation)
        
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        let string = NSMutableAttributedString(
            string: temperature,
            font: .medium(size.height * 0.69),
            textColor: color.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
        )
        string.addAttribute(.kern, value: -(size.height / 38.0) as NSNumber, range: NSMakeRange(0, string.length))

        let layout = TextViewLayout(string)
        layout.measure(width: .greatestFiniteMagnitude)
        self.textView.update(layout)
        
        transition.updateFrame(view: self.textView, frame: self.textView.centerFrameY(x: size.width - textView.frame.width - size.height * 0.2, addition: -floorToScreenPixels(size.height * 0.1)))
        
        
        let prevEmojiSize = self.emojiSize
        let emojiSize = CGSize(width: floor(size.height * 0.5), height: floor(size.height * 0.5))
        if prevEmojiSize != emojiSize, let file = emojiFile {
            self.emojiSize = emojiSize
            self.drawSticker(file, context: context)
        }
        if let layer = self.emojiView {
            var rect = layer.frame
            rect.origin.x = size.height * 0.1
            rect.origin.y = floorToScreenPixels((size.height - rect.size.height) / 2)
            transition.updateFrame(layer: layer, frame: rect)
        }
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    private func rotateView(to angle: Double) {
        let radians = angle * Double.pi / 180.0
        self.layer?.transform = CATransform3DMakeRotation(CGFloat(radians), 0, 0, 1.0)
    }
}


final class StoryListView : Control, Notifable {
    

    enum UpdateIndexResult {
        case invoked
        case moveBack
        case moveNext
    }
    
    struct TransitionData {
        let direction: TranslateDirection
        let animateContainer: LayerBackedView
        let view1: LayerBackedView
        let view2: LayerBackedView
        let previous: StoryListView
    }
    
    fileprivate let ready: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    
    var getReady: Signal<Bool, NoError> {
        return self.ready.get() |> filter { $0 } |> take(1)
    }
    
    fileprivate var transition: TransitionData?

    var storyId: AnyHashable? {
        if let entry = entry {
            return entry.item.storyItem.id
        }
        return nil
    }
    var story: StoryContentItem? {
        if let entry = entry {
            return entry.item
        }
        return nil
    }
    var id: PeerId? {
        return self.entry?.peer.id
    }
    
    private class Text : Control {
        
        enum State : Equatable {
            case concealed
            case revealed
        }
        
        var state: State = .concealed
        
        private let scrollView = ScrollView()
        private var textView: TextView?
        private let documentView = View()
        private let container = Control()
        private let shadowView = ShadowView()
        private var arguments: StoryArguments?
        private var inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]
        
        private var showMore: TextView?
        
        private var repostView: StoryRepostView?

        
        required init(frame frameRect: NSRect) {
            scrollView.background = .clear
            super.init(frame: frameRect)
            self.addSubview(shadowView)
            addSubview(container)
            container.addSubview(self.scrollView)
            self.scrollView.documentView = documentView
            
            shadowView.direction = .vertical(true)
            shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.6)
            
            
            NotificationCenter.default.addObserver(forName: NSScrollView.boundsDidChangeNotification, object: scrollView.clipView, queue: nil, using: { [weak self] _ in
                self?.updateScroll()
            })
            
            scrollView.applyExternalScroll = { [weak self] event in
                if self?.arguments?.interaction.presentation.inTransition == true {
                    self?.superview?.scrollWheel(with: event)
                    return true
                }
                return false
            }
            
            
            self.layer?.cornerRadius = 10
        }
        
        
        private func updateScroll() {
            switch state {
            case .concealed:
                if container.userInteractionEnabled, scrollView.clipView.bounds.minY > 5 {
                    self.scrollView.clipView.scroll(to: .zero, animated: false)
                    self.container.send(event: .Click)
                }
            case .revealed:
                if self.userInteractionEnabled, scrollView.clipView.bounds.minY < -5 {
                    self.scrollView.clipView.scroll(to: .zero, animated: false)
                    self.send(event: .Click)
                }
            }
        }
        

        
        override func layout() {
            super.layout()
            self.updateLayout(size: frame.size, transition: .immediate)
        }
        
        func update(text: String, entities: [MessageTextEntity], story: EngineStoryItem, forwardInfo: EngineStoryItem.ForwardInfo?, context: AccountContext, state: State, transition: ContainedViewLayoutTransition, toggleState: @escaping(State)->Void, arguments: StoryArguments?) -> NSSize {
            
            self.state = state
            self.arguments = arguments
            
            let attributed = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: entities)], for: text, message: nil, context: context, fontSize: darkAppearance.fontSize, openInfo: { [weak arguments, weak self] peerId, toChat, messageId, initialAction in
                if toChat {
                    arguments?.openChat(peerId, messageId, initialAction)
                } else if let view = self {
                    arguments?.openPeerInfo(peerId, view)
                }
            }, hashtag: arguments?.hashtag ?? { _ in }, textColor: darkAppearance.colors.text, linkColor: darkAppearance.colors.text, monospacedPre: darkAppearance.colors.text, monospacedCode: darkAppearance.colors.text, underlineLinks: true, isDark: true, bubbled: false).mutableCopy() as! NSMutableAttributedString
            
            
            InlineStickerItem.apply(to: attributed, associatedMedia: [:], entities: entities, isPremium: context.isPremium)
            
            
            let layout: TextViewLayout = .init(attributed, maximumNumberOfLines: state == .revealed ? 0 : 2, selectText: darkAppearance.colors.grayText, spoilerColor: darkAppearance.colors.text)
            layout.measure(width: frame.width - 20)
            layout.interactions = globalLinkExecutor
            
            
            
            if !layout.isPerfectSized {
                container.set(cursor: NSCursor.pointingHand, for: .Hover)
                container.set(cursor: NSCursor.pointingHand, for: .Highlight)
            } else {
                container.set(cursor: NSCursor.arrow, for: .Hover)
                container.set(cursor: NSCursor.arrow, for: .Highlight)
            }
            
            if !layout.isPerfectSized, state != .revealed {
                
                let current: TextView
                let isNew: Bool
                if let view = self.showMore {
                    current = view
                    isNew = false
                } else {
                    current = TextView()
                    self.showMore = current
                    self.documentView.addSubview(current)

                    current.set(handler: { control in
                        toggleState(.revealed)
                    }, for: .Click)
                   
                    isNew = true
                }
                let moreLayout = TextViewLayout.init(.initialize(string: strings().storyItemTextShowMore, color: darkAppearance.colors.text, font: .bold(.text)))
                moreLayout.measure(width: .greatestFiniteMagnitude)
                current.update(moreLayout)
                
                layout.cutout = .init(topLeft: nil, topRight: nil, bottomRight: NSMakeSize(moreLayout.layoutSize.width, 10))
                layout.measure(width: frame.width - 20)
                
                if isNew {
                    current.setFrameOrigin(NSMakePoint(documentView.frame.width - current.frame.width - 10, documentView.frame.height - current.frame.height - 10))
                    if transition.isAnimated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                
            } else if let view = self.showMore {
                performSubviewRemoval(view, animated: transition.isAnimated)
                self.showMore = nil
            }
            
            if self.textView?.textLayout?.attributedString != layout.attributedString || self.textView?.textLayout?.lines.count != layout.lines.count {
                let textView = TextView(frame: CGRect(origin: NSMakePoint(10, 5), size: layout.layoutSize))
                textView.update(layout)
                
                if let current = self.textView {
                    performSubviewRemoval(current, animated: transition.isAnimated)
                    self.textView = nil
                }
                self.documentView.addSubview(textView, positioned: .below, relativeTo: showMore)
                if transition.isAnimated {
                    textView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                self.textView = textView
            }
            
            
            self.removeAllHandlers()
            self.set(handler: { control in
                toggleState(.concealed)
            }, for: .Click)
            
            container.removeAllHandlers()
            container.set(handler: { control in
                toggleState(.revealed)
            }, for: .Click)
            
            let cantReveal = state == .concealed && layout.isPerfectSized
            
            self.container.userInteractionEnabled = state == .concealed && !cantReveal
            self.userInteractionEnabled = state == .revealed
            self.textView?.userInteractionEnabled = state == .revealed || cantReveal
            

//            self.container.isEventLess = !self.container.userInteractionEnabled
            self.isEventLess = !self.userInteractionEnabled
//            self.textView.isEventLess = !self.container.userInteractionEnabled
            
            if let textView = self.textView {
                self.updateInlineStickers(context: context, view: textView, textLayout: layout)
            }
            
            if let forwardInfo = forwardInfo, let arguments = arguments {
                let current: StoryRepostView
                if let view = self.repostView {
                    current = view
                } else {
                    current = StoryRepostView(frame: NSMakeRect(0, 0, frame.width - 20, 36))
                    self.repostView = current
                    self.addSubview(current)
                }
                current.set(forwardInfo: forwardInfo, story: story, context: context, arguments: arguments)
            } else if let view = self.repostView {
                performSubviewRemoval(view, animated: false)
            }
            
            self.updateLayout(size: frame.size, transition: transition)
            
            switch state {
            case .concealed:
                self.shadowView.background = NSColor.clear
                if transition.isAnimated {
                    self.shadowView.layer?.animateBackground()
                }
            case .revealed:
                self.shadowView.background = NSColor.black.withAlphaComponent(0.9)
                if transition.isAnimated {
                    self.shadowView.layer?.animateBackground()
                }
            }
            
            return frame.size
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {

            if let textView = textView {
                let containerSize = NSMakeSize(frame.width, min(textView.frame.height + 20, 208 + 20))
                let rect = CGRect(origin: NSMakePoint(0, size.height - containerSize.height), size: containerSize)
                transition.updateFrame(view: container, frame: rect)

                
                
                
                transition.updateFrame(view: documentView, frame: NSMakeRect(0, 0, container.frame.width, textView.frame.height + 10))
                transition.updateFrame(view: scrollView.contentView, frame: documentView.bounds)
                transition.updateFrame(view: scrollView, frame: container.bounds)

                transition.updateFrame(view: shadowView, frame: container.frame)

                if let view = repostView {
                    let size = view.size(max: size.width - 20, transition: transition)
                    var y = container.frame.minY - size.height
                    if state == .revealed {
                        y -= 10
                    }
                    transition.updateFrame(view: view, frame: NSMakeRect(10, y, size.width, size.height))
                    view.updateLayout(size: size, transition: transition)
                }
                
                
                textView.resize(size.width - 20)
                transition.updateFrame(view: textView, frame: CGRect.init(origin: NSMakePoint(10, 10), size: textView.frame.size))
                
                if let view = self.showMore {
                    transition.updateFrame(view: view, frame: CGRect.init(origin: NSMakePoint(documentView.frame.width - view.frame.width - 10, documentView.frame.height - view.frame.height), size: view.frame.size))
                }
            }
        }
        
        func updateInlineStickers(context: AccountContext, view textView: TextView, textLayout: TextViewLayout) {
            

            let textColor = darkAppearance.colors.text
            
            var validIds: [InlineStickerItemLayer.Key] = []
            var index: Int = textView.hashValue
            
            for item in textLayout.embeddedItems {
                if let stickerItem = item.value as? InlineStickerItem, case let .attribute(emoji) = stickerItem.source {
                    
                    let id = InlineStickerItemLayer.Key(id: emoji.fileId, index: index)
                    validIds.append(id)
                    
                    
                    let rect: NSRect
                    if textLayout.isBigEmoji {
                        rect = item.rect
                    } else {
                        rect = item.rect
                    }
                    
                    let view: InlineStickerItemLayer
                    if let current = self.inlineStickerItemViews[id], current.frame.size == rect.size {
                        view = current
                    } else {
                        self.inlineStickerItemViews[id]?.removeFromSuperlayer()
                        view = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: emoji, size: rect.size, textColor: textColor)
                        self.inlineStickerItemViews[id] = view
                        view.superview = textView
                        textView.addEmbeddedLayer(view)
                    }
                    index += 1
                    var isKeyWindow: Bool = false
                    if let window = window {
                        if !window.canBecomeKey {
                            isKeyWindow = true
                        } else {
                            isKeyWindow = window.isKeyWindow
                        }
                    }
                    view.isPlayable = NSIntersectsRect(rect, textView.visibleRect) && isKeyWindow
                    view.frame = rect
                }
            }
            
            var removeKeys: [InlineStickerItemLayer.Key] = []
            for (key, itemLayer) in self.inlineStickerItemViews {
                if !validIds.contains(key) {
                    removeKeys.append(key)
                    itemLayer.removeFromSuperlayer()
                }
            }
            for key in removeKeys {
                self.inlineStickerItemViews.removeValue(forKey: key)
            }
            
            updateAnimatableContent()
        }

        
        @objc func updateAnimatableContent() -> Void {
            var isKeyWindow: Bool = false
            if let window = window {
                if !window.canBecomeKey {
                    isKeyWindow = true
                } else {
                    isKeyWindow = window.isKeyWindow
                }
            }
            for layer in inlineStickerItemViews.values {
                layer.isPlayable = isKeyWindow
            }
        }
        
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.updateListeners()
            self.updateAnimatableContent()
        }
        
        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            self.updateListeners()
            self.updateAnimatableContent()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        private func updateListeners() {
            let center = NotificationCenter.default
            if let window = window {
                center.removeObserver(self)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
            } else {
                center.removeObserver(self)
            }
        }
        
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var entry: StoryContentContextState.FocusedSlice? = nil
    private let magnifyDispsosable = MetaDisposable()
    private var current: StoryLayoutView? {
        didSet {
            if let magnify = current?.magnify {
                controls.redirectView = magnify
                magnifyDispsosable.set(magnify.magnifyUpdaterValue.start(next: { [weak self] value in
                    self?.arguments?.interaction.updateMagnify(value)
                }))
            } else {
                self.arguments?.interaction.updateMagnify(1.0)
                magnifyDispsosable.set(nil)
                controls.redirectView = nil
            }
        }
    }
    private var arguments: StoryArguments?
    private var context: AccountContext?
    private let controls = StoryControlsView(frame: .zero)
    private let navigator = StoryListNavigationView(frame: .zero)
    private var text: Text?
    
    private var prevStoryView: ShadowView?
    private var nextStoryView: ShadowView?
    
    private var interactiveMedias:View = View(frame: .zero)
    private var interactiveMedias_values:[InteractiveMedia & NSView] = []

    private var pauseOverlay: Control? = nil
    
    private var mediaAreaViewer: StoryViewMediaAreaViewer?
        
    var storyDidUpdate:((Message)->Void)?
    
    private(set) var inputView: (NSView & StoryInput)!
    let container = View()
    private let content = View()
    
    
    var textView: NSTextView? {
        return self.inputView.input
    }
    var inputTextView: UITextView? {
        return self.inputView.text
    }
    
    
    func setArguments(_ arguments: StoryArguments?) -> Void {
        self.arguments = arguments
        arguments?.interaction.add(observer: self)
    }
    required init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
        
        container.layer?.masksToBounds = true
        content.addSubview(self.controls)
        content.addSubview(self.interactiveMedias)
        content.addSubview(self.navigator)
        container.layer?.masksToBounds = false
        content.layer?.masksToBounds = false
        interactiveMedias.layer?.masksToBounds = false
                
        container.addSubview(content)
        
        interactiveMedias.isEventLess = true
        
        controls.controlOpacityEventIgnored = true
        
        addSubview(container)
        controls.layer?.cornerRadius = 10
        
        navigator.seek = { [weak self] value in
            if let value {
                self?.current?.seek(toProgress: Double(value))
            }
        }
        
        var seekPaused: Bool = false
        
        navigator.seekStart = { [weak self] in
            self?.arguments?.interaction.update { current in
                var current = current
                current.isSeeking = true
                return current
            }
            if case .playing = self?.current?.state  {
                seekPaused = true
                self?.current?.pause()
            } else {
                seekPaused = false
            }
        }
        navigator.seekFinish = { [weak self] in
            self?.arguments?.interaction.update { current in
                var current = current
                current.isSeeking = false
                return current
            }
            if case .paused = self?.current?.state, seekPaused {
                self?.current?.play()
            }
            seekPaused = false
        }
        controls.set(handler: { [weak self] control in
            guard let arguments = self?.arguments, let story = self?.story, let peer = story.peer, let event = NSApp.currentEvent else {
                return
            }
            let peerId = peer.id
            if peer.isService {
                if let menu = arguments.storyContextMenu(story) {
                    AppMenu.show(menu: menu, event: event, for: control)
                }
            } else {
                
                var selectedItems: [EmojiesSectionRowItem.SelectedItem] = []
                
                if let reaction = story.storyItem.myReaction {
                    switch reaction {
                    case let .builtin(emoji):
                        selectedItems.append(.init(source: .builtin(emoji), type: .transparent))
                    case let .custom(fileId):
                        selectedItems.append(.init(source: .custom(fileId), type: .transparent))
                    case .stars:
                        break
                    }
                }
                let window: Signal<Window?, NoError>
                if story.peerId == arguments.context.peerId {
                    window = .single(nil)
                } else {
                    window = storyReactionsWindow(context: arguments.context, peerId: peerId, react: arguments.likeAction, onClose: {
                        
                    }, selectedItems: selectedItems) |> deliverOnMainQueue
                }
                
                _ = window.start(next: { [weak arguments] panel in
                    if let menu = arguments?.storyContextMenu(story) {
                        
                        menu.topWindow = panel
                        AppMenu.show(menu: menu, event: event, for: control)
                    }
                })
            }
        }, for: .RightDown)
        
        controls.set(handler: { [weak self] _ in
            self?.updateSides()
            self?.arguments?.down()
        }, for: .Down)
        
        controls.set(handler: { [weak self] _ in
            self?.updateSides()
            self?.arguments?.longDown()
        }, for: .LongMouseDown)
        
        
        controls.set(handler: { [weak self] _ in
            self?.arguments?.up()
            self?.updateSides()
        }, for: .Up)
        
        controls.set(handler: { [weak self] control in
            if let event = NSApp.currentEvent {
                let point = control.convert(event.locationInWindow, from: nil)
                if let value = self?.findMediaArea(point) {
                    self?.arguments?.activateMediaArea(value)
                } else {
                    if point.x < control.frame.width / 2 {
                        self?.arguments?.prevStory()
                    } else {
                        self?.arguments?.nextStory()
                    }
                    self?.updateSides()
                }
            }
        }, for: .Click)
        
        
        self.userInteractionEnabled = false
    }
    
    
    private func mediaAreaViewerRect(_ mediaArea: MediaArea) -> NSRect {
        let referenceSize = self.controls.frame.size
        let size = CGSize(width: 16.0, height: 16.0)
        var frame = CGRect(x: mediaArea.coordinates.x / 100.0 * referenceSize.width - size.width / 2.0, y: (mediaArea.coordinates.y - mediaArea.coordinates.height * 0.5)  / 100.0 * referenceSize.height - size.height / 2.0, width: size.width, height: size.height)
        frame = frame.offsetBy(dx: 0.0, dy: -8)

        return frame
    }
    
    func showMediaAreaViewer(_ mediaArea: MediaArea) {
        guard let event = NSApp.currentEvent, let arguments else {
            return
        }
        if let viewer = self.mediaAreaViewer {
            performSubviewRemoval(viewer, animated: false)
            self.mediaAreaViewer = nil
        }
        
        let rect = self.mediaAreaViewerRect(mediaArea)
        
        let view = StoryViewMediaAreaViewer(frame: rect)
        self.mediaAreaViewer = view
        
        self.content.addSubview(view)
                
//        if case let .weather(_, emoji, _, _) = mediaArea {
//            return
//        }
        
        var items: [ContextMenuItem] = []
        
        
        items.append(ContextMenuItem(mediaArea.title, handler: { [weak self] in
            self?.arguments?.invokeMediaArea(mediaArea)
        }, itemImage: mediaArea.menu.value))
        
        switch mediaArea {
        case .link(let coordinates, let url):
            items.append(ContextSeparatorItem())
            let item = ContextMenuItem(url, itemMode: .normal)
            item.isEnabled = false
            items.append(item)
        default:
            break
        }

        ContextMenu.show(items: items, view: view, event: event, onClose: { [weak self] in
            self?.arguments?.deactivateMediaArea(mediaArea)
        }, presentation: .current(darkAppearance.colors))
    }
    
    func hideMediaAreaViewer() {
        if let viewer = self.mediaAreaViewer {
            performSubviewRemoval(viewer, animated: false)
            self.mediaAreaViewer = nil
        }
    }
    
    
    private func mediaRect(_ area: MediaArea) -> NSRect {
        let referenceSize = self.controls.frame.size
        let coordinates = area.coordinates
        
        let areaSize = CGSize(width: coordinates.width / 100.0 * referenceSize.width, height: coordinates.height / 100.0 * referenceSize.height)
        let targetFrame = CGRect(x: floorToScreenPixels(coordinates.x / 100.0 * referenceSize.width - areaSize.width * 0.5), y: floorToScreenPixels(coordinates.y / 100.0 * referenceSize.height - areaSize.height * 0.5), width: floorToScreenPixels(areaSize.width), height: floorToScreenPixels(areaSize.height))
        
        return targetFrame
    }
    
    private func findMediaArea(_ point: NSPoint) -> MediaArea? {
        guard let story = self.story else {
            return nil
        }
        
        let point = NSMakePoint(point.x, point.y)
                
        let referenceSize = self.controls.frame.size
        
        var selectedMediaArea: MediaArea?
                                                
        func isPoint(_ point: CGPoint, in area: MediaArea) -> Bool {
            let tx = point.x - area.coordinates.x / 100.0 * referenceSize.width
            let ty = point.y - area.coordinates.y / 100.0 * referenceSize.height
            
            let rad = -area.coordinates.rotation * Double.pi / 180.0
            let cosTheta = cos(rad)
            let sinTheta = sin(rad)
            let rotatedX = tx * cosTheta - ty * sinTheta
            let rotatedY = tx * sinTheta + ty * cosTheta
            
            return abs(rotatedX) <= area.coordinates.width / 100.0 * referenceSize.width / 2.0 && abs(rotatedY) <= area.coordinates.height / 100.0 * referenceSize.height / 2.0
        }

        
        for area in story.storyItem.mediaAreas {
            if isPoint(point, in: area), area.canClick {
                selectedMediaArea = area
                break
            }
        }
        return selectedMediaArea
    }
    
    private func updateSides(animated: Bool = true) {
        if let args = self.arguments {
            let isPrev: Bool?
            if !args.interaction.presentation.longDown, let event = NSApp.currentEvent, event.type == .leftMouseDown {
                let point = controls.convert(event.locationInWindow, from: nil)
                if point.x < controls.frame.width / 2 {
                    isPrev = true
                } else {
                    isPrev = false
                }
            } else {
                isPrev = nil
            }
            
            if let isPrev = isPrev, mediaAreaViewer == nil {
                self.prevStoryView?.change(opacity: isPrev ? 1 : 0, animated: animated)
                self.nextStoryView?.change(opacity: !isPrev ? 1 : 0, animated: animated)
            } else {
                self.prevStoryView?.change(opacity: 0, animated: animated)
                self.nextStoryView?.change(opacity: 0, animated: animated)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    

    func resetInputView() {
        self.inputView.resetInputView()
        self.arguments?.interaction.update { current in
            var current = current
            current.hasReactions = false
            return current
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        guard let value = value as? StoryInteraction.State, let oldValue = oldValue as? StoryInteraction.State else {
            return
        }
        guard let context = self.arguments?.context else {
            return
        }
        
        
        
        var isPaused: Bool = false

        if let current = current, current.isEqual(to: value.storyId) {
            if value.isPaused {
                current.pause()
                isPaused = true
            } else {
                current.play()
                isPaused = false
            }
        } else {
            current?.pause()
            isPaused = true
        }
        
        if oldValue.isMuted != value.isMuted {
            if value.isMuted {
                current?.mute()
            } else {
                current?.unmute()
            }
        }
        
        if oldValue.volume != value.volume {
            current?.setVolume(value.volume)
        }
        
        controls.updateMuted(isMuted: value.isMuted, volume: value.volume)
        
        if oldValue.readingText != value.readingText {
            if let story = self.current?.story {
                self.updateText(story, state: value.readingText ? .revealed : .concealed, animated: animated, context: context)
            }
        }
        
        if value.inputRecording != oldValue.inputRecording {
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
        
        if let groupId = self.entry?.peer.id {
            let curInput = value.inputs[groupId]
            let prevInput = oldValue.inputs[groupId]
            if let curInput = curInput, let prevInput = prevInput {
                inputView.updateInputText(curInput, prevState: prevInput, animated: animated)
            }
            inputView.updateState(value, animated: animated)
        }
                
        
        if isPaused, let storyView = self.current, self.entry?.peer.id == value.entryId, value.wideInput || value.inputRecording != nil || value.hasReactions {
            let current: Control
            if let view = self.pauseOverlay {
                current = view
            } else {
                current = Control(frame: storyView.frame)
                current.layer?.cornerRadius = 10
                self.content.addSubview(current, positioned: .below, relativeTo: navigator)
                self.pauseOverlay = current
                
                current.set(handler: { [weak self] _ in
                    self?.resetInputView()
                }, for: .Click)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        } else if let view = self.pauseOverlay {
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
            performSubviewRemoval(view, animated: animated)
            self.pauseOverlay = nil
        }
        
        self.controls.userInteractionEnabled = !value.magnified

   
        let isControlHid = value.longDown || value.magnified //|| value.isSpacePaused
        let prevIsControlHid = oldValue.longDown || oldValue.magnified //|| oldValue.isSpacePaused

        if isControlHid != prevIsControlHid {
            self.controls.change(opacity: isControlHid ? 0 : 1, animated: animated)
            self.navigator.change(opacity: isControlHid ? 0 : 1, animated: animated)
        }
        self.text?.change(opacity: isControlHid || value.wideInput ? 0 : 1, animated: animated)

        self.updateSides(animated: animated)
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return self === other as? StoryListView
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        var bottomInset: CGFloat = 110
        if self.inputView is StoryBotInputView {
            bottomInset = 50
        }
        
        let maxSize = NSMakeSize(frame.width - 100, frame.height - bottomInset)
        let aspect = StoryLayoutView.size.aspectFitted(maxSize)
        let containerSize: NSSize
        if let arguments = self.arguments, arguments.interaction.presentation.wideInput || arguments.interaction.presentation.inputRecording != nil {
            containerSize = NSMakeSize(min(aspect.width + 60, size.width - 20), aspect.height)
        } else {
            containerSize = aspect
        }
        if container.superview == self {
            transition.updateFrame(view: container, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor, (frame.width - containerSize.width) / 2), y: 20), size: NSMakeSize(containerSize.width, size.height)))
        }

        
        if let current = self.current, self.content.superview == container {
            let rect = CGRect(origin: CGPoint(x: (containerSize.width - aspect.width) / 2, y: 0), size: aspect)
            transition.updateFrame(view: self.content, frame: rect)

            transition.updateFrame(view: self.interactiveMedias, frame: rect.size.bounds)
            
            transition.updateFrame(view: current, frame: rect.size.bounds)
            
            transition.updateFrame(view: controls, frame: rect.size.bounds)
            controls.updateLayout(size: rect.size, transition: transition)
                        
            transition.updateFrame(view: navigator, frame: CGRect(origin: CGPoint(x: 0, y: 0 + 2), size: NSMakeSize(rect.width, 10)))
            navigator.updateLayout(size: rect.size, transition: transition)
            
            if let pauseOverlay = pauseOverlay {
                transition.updateFrame(view: pauseOverlay, frame: rect.size.bounds)
            }
            
            if let view = self.prevStoryView {
                transition.updateFrame(view: view, frame: NSMakeRect(0, 0, 40, rect.height))
            }
            if let view = self.nextStoryView {
                transition.updateFrame(view: view, frame: NSMakeRect(rect.width - 40, 0, 40, rect.height))
            }
            
            layoutInteractiveMedia(transition: transition)
        }
        inputView?.updateInputState(animated: transition.isAnimated)
        
        if let text = self.text {
            var rect = text.bounds
            rect.size.width = aspect.width
            rect.origin.x = 0
            rect.origin.y = controls.frame.maxY - text.frame.height
            transition.updateFrame(view: text, frame: rect)
            text.updateLayout(size: rect.size, transition: transition)
        }
    }
    
    func animateAppearing(from control: NSView) {
        
        guard let superview = control.superview else {
            return
        }
        
        let newRect = container.frame
        let origin = self.convert(control.frame.origin, from: superview)
        let oldRect = CGRect(origin: origin, size: control.frame.size)
                
        
        container.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: 0.2, timingFunction: .default)
        container.layer?.animateScaleX(from: oldRect.width / newRect.width, to: 1, duration: 0.2, timingFunction: .default)
        container.layer?.animateScaleY(from: oldRect.height / newRect.height, to: 1, duration: 0.2, timingFunction: .default)
        
        current?.animateAppearing(disappear: false)
        
    }
    var contentView: NSView {
        return container
    }
    
    func animateDisappearing(to control: NSView) {
        
        guard let superview = control.superview else {
            return
        }
        
        
        let aspectSize = control.frame.size

        let point = self.convert(content.frame.origin, from: container)
        
        self.addSubview(content)
        content.setFrameOrigin(point)
        let oldRect = content.frame

        
        let origin = self.convert(control.frame.origin, from: superview)
        let newRect = CGRect(origin: NSMakePoint(origin.x + (control.frame.width - aspectSize.width) / 2, origin.y + (control.frame.height - aspectSize.height) / 2), size: aspectSize)
                
                
        current?.animateAppearing(disappear: true)
        
        let duration: Double = 0.2
        
        guard let layer = content.layer else {
            return
        }
        layer.animatePosition(from: oldRect.origin, to: newRect.origin, duration: duration, timingFunction: .default, removeOnCompletion: false)
        layer.animateScaleX(from: 1, to: newRect.width / oldRect.width, duration: duration, timingFunction: .default, removeOnCompletion: false)
        layer.animateScaleY(from: 1, to: newRect.height / oldRect.height, duration: duration, timingFunction: .default, removeOnCompletion: false)
        
        
        
        if control is AvatarControl || control is AvatarStoryControl {
            let anim = layer.makeAnimation(from: NSNumber(value: content.layer!.cornerRadius), to: NSNumber(value: CGFloat(content.frame.width / 2)), keyPath: "cornerRadius", timingFunction: .default, duration: duration, removeOnCompletion: false)
            layer.add(anim, forKey: "cornerRadius")
        }
       
    }
    
    func zoomIn() {
        self.current?.magnify?.zoomIn()
    }
    func zoomOut() {
        self.current?.magnify?.zoomOut()
    }

    func update(context: AccountContext, entry: StoryContentContextState.FocusedSlice?) {
                
        
        self.context = context
        self.entry = entry
        self.controls.isHidden = entry == nil
        
        guard let arguments = self.arguments else {
            return
        }

        if let entry = entry {
            self.navigator.initialize(count: entry.item.dayCounters?.totalCount ?? entry.totalCount)
            
            if self.inputView == nil {
                let maxSize = NSMakeSize(frame.width - 100, frame.height - 110)
                let aspect = StoryLayoutView.size.aspectFitted(maxSize)
                
                if entry.peer._asPeer().isBot {
                    self.inputView = StoryBotInputView(frame: NSMakeRect(0, 0, aspect.width, 50))
                } else if entry.peer._asPeer() is TelegramChannel {
                    if entry.peer._asPeer().isSupergroup {
                        self.inputView = StoryInputView(frame: NSMakeRect(0, 0, aspect.width, 50))
                    } else {
                        self.inputView = StoryChannelInputView(frame: NSMakeRect(0, 0, aspect.width, 50))
                    }
                } else if entry.peer.isService {
                    self.inputView = StoryNoReplyInput(frame: NSMakeRect(0, 0, aspect.width, 50))
                } else if entry.additionalPeerData.premiumRequired && !arguments.context.isPremium {
                    self.inputView = StoryPremRequiredInput(frame: NSMakeRect(0, 0, aspect.width, 50))
                } else if entry.peer.id == context.peerId {
                    self.inputView = StoryMyInputView(frame: NSMakeRect(0, 0, aspect.width, 50))
                } else {
                    self.inputView = StoryInputView(frame: NSMakeRect(0, 0, aspect.width, 50))
                }
                self.container.addSubview(self.inputView)
                
                inputView.installInputStateUpdate({ [weak self] state in
                    switch state {
                    case .focus:
                        self?.arguments?.inputFocus()
                    case .none:
                        self?.arguments?.inputUnfocus()
                    }
                    if let `self` = self {
                        self.updateLayout(size: self.frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
                    }
                })
                
                self.inputView.update(entry.item, animated: false)
                self.inputView.setArguments(self.arguments, groupId: entry.peer.id)
            }
            
            if let current = self.current, !current.isEqual(to: entry.item.storyItem.id) {
                self.redraw()
                self.initInteractiveMedia(current, arguments: arguments, animated: false)
            } else if let current = self.current, current.isHighQuality != entry.additionalPeerData.preferHighQualityStories {
                self.redraw()
            } else if let current = self.current {
                self.updateStoryState(current.state)
                self.controls.update(context: context, arguments: arguments, groupId: entry.peer.id, peer: entry.peer._asPeer(), slice: entry, story: entry.item, animated: true)
                self.inputView.update(entry.item, animated: true)
                self.updateInteractiveMedia(current, arguments: arguments, animated: true)
            } else {
                self.redraw()
                if let current = self.current {
                    self.initInteractiveMedia(current, arguments: arguments, animated: false)
                }
            }
        } else {
            let size = NSMakeSize(frame.width - 100, frame.height - 110)
            let aspect = StoryLayoutView.size.aspectFitted(size)
            let current = StoryLayoutView(frame: aspect.bounds)
            self.current = current
            content.addSubview(current, positioned: .below, relativeTo: self.controls)
            self.updateLayout(size: frame.size, transition: .immediate)
        }
        
    }
    
    private let disposable = MetaDisposable()
    func redraw() {
        guard let context = context, let arguments = self.arguments, let entry = self.entry else {
            return
        }
        let groupId = entry.peer.id
        let previous = self.current
        
        let size = NSMakeSize(frame.width - 100, frame.height - 110)
        let aspect = StoryLayoutView.size.aspectFitted(size)
        let current = StoryLayoutView.makeView(for: entry.item.storyItem, isHighQuality: entry.additionalPeerData.preferHighQualityStories, peerId: entry.peer.id, peer: entry.peer._asPeer(), context: context, frame: aspect.bounds)
        
        self.current = current
        self.firstPlayingState = true
        
        if let previous = previous {
            previous.onStateUpdate = nil
            previous.disappear()
        }
        
        if previous?.story?.id != entry.item.storyItem.id {
            if let text = self.text {
                performSubviewRemoval(text, animated: false)
                self.text = nil
            }
        }
        
        let story = entry.item
        


        
        self.content.addSubview(current, positioned: .below, relativeTo: self.controls)
        
        
        if entry.previousItemId != nil {
            let current: ShadowView
            if let view = self.prevStoryView {
                current = view
            } else {
                current = ShadowView()
                current.isEventLess = true
                current.shadowBackground = NSColor.black.withAlphaComponent(0.15)
                current.layer?.opacity = 0
                self.prevStoryView = current
            }
            self.content.addSubview(current, positioned: .below, relativeTo: self.navigator)
            current.direction = .horizontal(false)
        } else if let view = self.prevStoryView {
            performSubviewRemoval(view, animated: false)
            self.prevStoryView = nil
        }
        if entry.nextItemId != nil {
            let current: ShadowView
            if let view = self.nextStoryView {
                current = view
            } else {
                current = ShadowView()
                current.isEventLess = true
                current.layer?.opacity = 0
                current.shadowBackground = NSColor.black.withAlphaComponent(0.2)
                self.nextStoryView = current
            }
            self.content.addSubview(current, positioned: .above, relativeTo: self.current)
            current.direction = .horizontal(true)
        } else if let view = self.nextStoryView {
            performSubviewRemoval(view, animated: false)
            self.nextStoryView = nil
        }
        
        self.updateLayout(size: self.frame.size, transition: .immediate)

        self.controls.update(context: context, arguments: arguments, groupId: groupId, peer: entry.peer._asPeer(), slice: entry, story: story, animated: false)

        
        arguments.interaction.flushPauses()
        
        
        current.onStateUpdate = { [weak self] state in
            self?.updateStoryState(state)
        }
        
        current.appear(isMuted: arguments.interaction.presentation.isMuted, volume: arguments.interaction.presentation.volume)
        self.updateStoryState(current.state)

        self.inputView.update(entry.item, animated: false)
        
        
        self.updateText(story.storyItem, state: .concealed, animated: false, context: context)

        self.ready.set(true)
        
        
        let ready: Signal<Bool, NoError> = current.getReady
        
        _ = ready.start(next: { [weak previous, weak current] _ in
            previous?.removeFromSuperview()
            current?.backgroundColor = NSColor.black
        })
        
    }
    
    private func updateInteractiveMedia(_ storyView: StoryLayoutView, arguments: StoryArguments, animated: Bool) {
        guard let medias = self.entry?.item.storyItem.mediaAreas.filter({ $0.canDraw }) else {
            return
        }
        
        var index: Int = 0
      
        for media in medias {
            switch media {
            case let .reaction(_, reaction, _):
                let entryViews = self.entry?.item.storyItem.views
                let count = entryViews?.reactions.first(where: { $0.value == reaction })?.count
                interactiveMedias_values[index].apply(area: media, count: count, arguments: arguments, animated: animated)
                index += 1
            case let .weather(_, emoji, temperature, _):
                interactiveMedias_values[index].apply(area: media, count: nil, arguments: arguments, animated: animated)
                index += 1
            default:
                break
            }
        }
        self.layoutInteractiveMedia(transition: .immediate)
    }
    private func initInteractiveMedia(_ storyView: StoryLayoutView, arguments: StoryArguments, animated: Bool) {
        guard let medias = self.entry?.item.storyItem.mediaAreas.filter({ $0.canDraw }) else {
            return
        }
        
        self.interactiveMedias.removeAllSubviews()
        self.interactiveMedias_values.removeAll()
        
        
        for media in medias {
            switch media {
            case .reaction:
                let rect = mediaRect(media)
                let view = Reaction_InteractiveMedia(frame: rect, mediaArea: media)
                interactiveMedias.addSubview(view)
                interactiveMedias_values.append(view)
            case .weather:
                let rect = mediaRect(media)
                let view = Weather_InteractiveMedia(frame: rect, mediaArea: media, context: arguments.context)
                interactiveMedias.addSubview(view)
                interactiveMedias_values.append(view)
            default:
                break
            }
        }
        self.updateInteractiveMedia(storyView, arguments: arguments, animated: animated)
    }
    
    func layoutInteractiveMedia(transition: ContainedViewLayoutTransition) {
        let views = interactiveMedias.subviews.compactMap({ $0 as? (InteractiveMedia & NSView) })
        for view in views {
            let rect = mediaRect(view.mediaArea)
            transition.updateFrame(view: view, frame: rect)
            view.updateLayout(size: rect.size, transition: .immediate)
        }
    }
    
    private func updateText(_ story: EngineStoryItem, state: Text.State, animated: Bool, context: AccountContext) {
        
        let text = story.text
        
        let entities: [MessageTextEntity] = story.entities
        
        var hasText: Bool = !text.isEmpty && !(story.media._asMedia() is TelegramMediaUnsupported)
        if let _ = story.forwardInfo {
            hasText = true
        }
        
        if hasText {
            let current: Text
            if let view = self.text {
                current = view
            } else {
                current = Text(frame: NSMakeRect(0, container.frame.maxY - 100, container.frame.width, controls.frame.height))
                self.text = current
                content.addSubview(current, positioned: .above, relativeTo: interactiveMedias)
            }
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.2, curve: .easeOut)
            } else {
                transition = .immediate
            }
            let size = current.update(text: text, entities: entities, story: story, forwardInfo: story.forwardInfo, context: context, state: state, transition: transition, toggleState: { [weak self] state in
                self?.arguments?.interaction.update { current in
                    var current = current
                    current.readingText = state == .revealed
                    current.isSpacePaused = false
                    return current
                }
            }, arguments: arguments)
            
            let rect = CGRect(origin: NSMakePoint(0, controls.frame.height - size.height), size: size)
            transition.updateFrame(view: current, frame: rect)
            
            
        } else if let view = self.text {
            performSubviewRemoval(view, animated: false)
            self.text = nil
        }
    }
    
    private var firstPlayingState = true
    
    private func updateStoryState(_ state: StoryLayoutView.State) {
        guard let view = self.current, let entry = self.entry else {
            return
        }
        
        switch state {
        case .playing:
            self.navigator.set(entry.item.dayCounters?.position ?? entry.item.position ?? 0, state: view.state, canSeek: view is StoryVideoView, duration: view.duration, animated: true)
            if firstPlayingState {
                self.arguments?.markAsRead(entry.peer.id, entry.item.storyItem.id)
            }
            firstPlayingState = false
        case .finished:
            self.arguments?.nextStory()
        default:
            self.navigator.set(entry.item.dayCounters?.position ?? entry.item.position ?? 0, state: view.state, canSeek: view is StoryVideoView, duration: view.duration, animated: true)
        }
    }
    
    var contentSize: NSSize {
        return self.container.frame.size
    }
    var contentRect: CGRect {
        let maxSize = NSMakeSize(frame.width - 100, frame.height - 110)
        let aspect = StoryLayoutView.size.aspectFitted(maxSize)
        return CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor, (frame.width - aspect.width) / 2), y: 20), size: NSMakeSize(aspect.width, frame.height))
    }
    var storyRect: CGRect {
        if let current = self.current {
            return NSMakeRect(contentRect.minX, 20, current.frame.width, current.frame.height)
        }
        return self.container.frame
    }
    
    
    func previous() -> UpdateIndexResult {
        guard let entry = self.entry else {
            return .invoked
        }
        if entry.previousItemId != nil {
            return .invoked
        } else {
            return .moveBack
        }
    }
    
    func next() -> UpdateIndexResult {
        guard let entry = self.entry else {
            return .invoked
        }
        if entry.nextItemId != nil {
            return .invoked
        } else {
            return .moveNext
        }
    }
    
    func restart() {
        self.current?.restart()
//        self.select(at: 0)
    }
    
    func play() {
        self.current?.play()
    }
    func pause() {
        self.current?.pause()
    }
    
    func showVoiceError() {
        if let control = (self.inputView as? StoryInputView)?.actionControl, let peer = self.story?.peer?._asPeer() {
            tooltip(for: control, text: strings().chatSendVoicePrivacyError(peer.compactDisplayTitle))
        }
    }
    
    func showShareError() {
        if let control = (self.inputView as? StoryInputView)?.actionControl {
            tooltip(for: control, text: "This story can't be shared")
        }
    }
    
    deinit {
        self.disposable.dispose()
        magnifyDispsosable.dispose()
        arguments?.interaction.remove(observer: self)
        //self.current?.disappear()
    }
}

private var timer: DisplayLinkAnimator?

extension StoryListView {
    enum TranslateDirection {
        case left
        case right
    }
    
    
    func initAnimateTranslate(previous: StoryListView, direction: TranslateDirection) {
        
        
        let animateContainer = LayerBackedView()
        animateContainer.frame = container.frame
        animateContainer.layer?.masksToBounds = false

        addSubview(animateContainer, positioned: .above, relativeTo: container)

        let view1 = LayerBackedView()
        view1.layer?.isDoubleSided = false
        view1.layer?.masksToBounds = false
        previous.container.frame = animateContainer.bounds
        view1.addSubview(previous.container)

        let view2 = LayerBackedView()
        view2.layer?.isDoubleSided = false
        view2.layer?.masksToBounds = false
        self.container.frame = animateContainer.bounds
        view2.addSubview(self.container)

        view1.frame = animateContainer.bounds
        view2.frame = animateContainer.bounds
        animateContainer.addSubview(view1)
        animateContainer.addSubview(view2)


        animateContainer._anchorPoint = NSMakePoint(0.5, 0.5)
        view1._anchorPoint = NSMakePoint(1.0, 1.0)
        view2._anchorPoint = NSMakePoint(1.0, 1.0)

        var view2Transform:CATransform3D = CATransform3DMakeTranslation(0.0, 0.0, 0.0)
        switch direction {
        case .right:
            view2Transform = CATransform3DTranslate(view2Transform, -view2.bounds.size.width, 0, 0);
            view2Transform = CATransform3DRotate(view2Transform, CGFloat(-(Double.pi/2)), 0, 1, 0);
        case .left:
            view2Transform = CATransform3DRotate(view2Transform, CGFloat(Double.pi/2), 0, 1, 0);
            view2Transform = CATransform3DTranslate(view2Transform, view2.bounds.size.width, 0, 0);
        }

        view2._transformation = view2Transform

        var sublayerTransform:CATransform3D = CATransform3DIdentity
        sublayerTransform.m34 = CGFloat(1.0 / (-3500))
        animateContainer._sublayerTransform = sublayerTransform
        
        self.transition = .init(direction: direction, animateContainer: animateContainer, view1: view1, view2: view2, previous: previous)

    }
    
    func translate(progress: CGFloat, finish: Bool, cancel: Bool = false, completion:@escaping(Bool, StoryListView)->Void) {
            
        guard let transition = self.transition else {
            return
        }
        
        
        let animateContainer = transition.animateContainer
        let view1 = transition.view1
        let view2 = transition.view2
        let previous = transition.previous
        
        if finish {
            self.transition = nil
        }
        
        let completed: (Bool)->Void = { [weak self, weak previous, weak animateContainer, weak view1, weak view2] completed in
            
            view1?.removeFromSuperview()
            view2?.removeFromSuperview()
            
            if let previous = previous {
                if cancel {
                    previous.addSubview(previous.container)
                    previous.updateLayout(size: previous.frame.size, transition: .immediate)
                } else {
                    previous.removeFromSuperview()
                }
            }
            
            
            animateContainer?.removeFromSuperview()
            if !cancel {
                if let container = self?.container {
                    self?.addSubview(container, positioned: .below, relativeTo: nil)
                }
            }
            
            if let `self` = self {
                self.updateLayout(size: self.frame.size, transition: .immediate)
            }
            if let previous = previous {
                completion(!cancel, previous)
            }
            
        }
        
        if finish, progress != 1 {
            
            let duration = 0.25
            
            let rotation:CABasicAnimation
            let translation:CABasicAnimation
            let translationZ:CABasicAnimation

            let group:CAAnimationGroup = CAAnimationGroup()
            group.duration = duration
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if !cancel {
                switch transition.direction {
                case .right:
                    let toValue:Float = Float(animateContainer.bounds.size.width / 2)
                    translation = CABasicAnimation(keyPath: "sublayerTransform.translation.x")
                    translation.toValue = NSNumber(value: toValue)
                    
                    rotation = CABasicAnimation(keyPath: "sublayerTransform.rotation.y")
                    rotation.toValue = NSNumber(value: (Double.pi/2))
                    
                    translationZ = CABasicAnimation(keyPath: "sublayerTransform.translation.z")
                    translationZ.toValue = NSNumber(value: -toValue)
                case .left:
                    let toValue:Float = Float(animateContainer.bounds.size.width / 2)
                    translation = CABasicAnimation(keyPath: "sublayerTransform.translation.x")
                    translation.toValue = NSNumber(value: -toValue)
                    
                    rotation = CABasicAnimation(keyPath: "sublayerTransform.rotation.y")
                    rotation.toValue = NSNumber(value: -(Double.pi/2))
                    
                    translationZ = CABasicAnimation(keyPath: "sublayerTransform.translation.z")
                    translationZ.toValue = NSNumber(value: -toValue)
                }
                view2._change(opacity: 1, duration: duration, timingFunction: .easeOut)
                view1._change(opacity: 0, duration: duration, timingFunction: .easeOut)
            } else {
                translation = CABasicAnimation(keyPath: "sublayerTransform.translation.x")
                translation.toValue = NSNumber(value: 0)
                
                rotation = CABasicAnimation(keyPath: "sublayerTransform.rotation.y")
                rotation.toValue = NSNumber(value: 0)
                
                translationZ = CABasicAnimation(keyPath: "sublayerTransform.translation.z")
                translationZ.toValue = NSNumber(value: 0)
                
                view2._change(opacity: 0, duration: duration, timingFunction: .easeOut)
                view1._change(opacity: 1, duration: duration, timingFunction: .easeOut)

            }
            
            group.animations = [rotation, translation, translationZ]
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            
            group.completion = completed
            
            animateContainer.layer?.add(group, forKey: "translate")
        } else {
            switch transition.direction {
            case .right:
                let toValue:CGFloat = CGFloat(animateContainer.bounds.size.width / 2)
                animateContainer.layer?.setValue(NSNumber(value: toValue * progress), forKeyPath: "sublayerTransform.translation.x")
                animateContainer.layer?.setValue(NSNumber(value: (Double.pi/2) * progress), forKeyPath: "sublayerTransform.rotation.y")
                animateContainer.layer?.setValue(NSNumber(value: -toValue * progress), forKeyPath: "sublayerTransform.translation.z")
                animateContainer._sublayerTransform = animateContainer.layer?.sublayerTransform
            case .left:
                let toValue:CGFloat = CGFloat(animateContainer.bounds.size.width / 2)
                animateContainer.layer?.setValue(NSNumber(value: -toValue * progress), forKeyPath: "sublayerTransform.translation.x")
                animateContainer.layer?.setValue(NSNumber(value: -(Double.pi/2) * progress), forKeyPath: "sublayerTransform.rotation.y")
                animateContainer.layer?.setValue(NSNumber(value: -toValue * progress), forKeyPath: "sublayerTransform.translation.z")
                animateContainer._sublayerTransform = animateContainer.layer?.sublayerTransform
            }
            view2.layer?.opacity = Float(1 * progress)
            view1.layer?.opacity = Float(1 - progress)

            if progress == 1, finish {
                completed(true)
            }
        }
    }
    
    var hasInput: Bool {
        return self.textView != nil
    }

}
