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
import TelegramMedia

func parabollicReactionAnimation(_ layer: CALayer, fromPoint: NSPoint, toPoint: NSPoint, window: Window, completion: ((Bool)->Void)? = nil, duration: Double = 0.2) {
    
    let view = View(frame: window.frame.size.bounds)
    view.isEventLess = true
    view.flip = false
    view.backgroundColor = .clear
    window.contentView?.addSubview(view)
    
    layer.removeFromSuperlayer()
    layer.frame = CGRect(origin: toPoint.offsetBy(dx: -layer.frame.width/2, dy: -layer.frame.height/2), size: layer.frame.size)
    
    view.layer?.addSublayer(layer)
    
    let transition = ContainedViewLayoutTransition.animated(duration: duration, curve: .linear)
    
    let keyFrames = generateParabollicMotionKeyframes(from: fromPoint, to: toPoint, elevation: fromPoint.y < toPoint.y ? 50 : -50)
    
    let animation = CABasicAnimation(keyPath: "transform.scale")
    animation.fromValue = 1
    animation.toValue = 2.0
    animation.duration = transition.duration / 2
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    animation.isRemovedOnCompletion = true
    animation.fillMode = .forwards
    animation.speed = 1
    animation.repeatCount = 1
    animation.autoreverses = true
    
    layer.add(animation, forKey: "transform.scale")
    
    transition.animatePositionWithKeyframes(layer: layer, keyframes: keyFrames, removeOnCompletion: true, completion: { [weak view] completed in
        CATransaction.begin()
        completion?(completed)

        CATransaction.commit()
        DispatchQueue.main.async {
            view?.removeFromSuperview()
        }
    })
}



private func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat) -> [CGPoint] {
    let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - elevation)
    
    let x1 = sourcePoint.x
    let y1 = sourcePoint.y
    let x2 = midPoint.x
    let y2 = midPoint.y
    let x3 = targetPosition.x
    let y3 = targetPosition.y
    
    var keyframes: [CGPoint] = []
    if abs(y1 - y3) < 5.0 && abs(x1 - x3) < 5.0 {
        for i in 0 ..< 10 {
            let k = CGFloat(i) / CGFloat(10 - 1)
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = sourcePoint.y * (1.0 - k) + targetPosition.y * k
            keyframes.append(CGPoint(x: x, y: y))
        }
    } else {
        let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        
        for i in 0 ..< 10 {
            let k = CGFloat(i) / CGFloat(10 - 1)
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = a * x * x + b * x + c
            keyframes.append(CGPoint(x: x, y: y))
        }
    }
    
    return keyframes
}



enum ContextReaction : Equatable {
    case builtin(value: MessageReaction.Reaction, staticFile: TelegramMediaFile, selectFile: TelegramMediaFile, appearFile: TelegramMediaFile, isSelected: Bool)
    case custom(value: MessageReaction.Reaction, fileId: Int64, TelegramMediaFile?, isSelected: Bool)
    
    var file: TelegramMediaFile? {
        switch self {
        case let .builtin(_, staticFile, _, _, _):
            return staticFile
        case let .custom(_, _, file, _ ):
            return file
        }
    }
    var fileId: Int64 {
        switch self {
        case let .builtin(_, staticFile, _, _, _):
            return staticFile.fileId.id
        case let .custom(_, fileId, _, _):
            return fileId
        }
    }
    var isSelected: Bool {
        switch self {
        case let .builtin(_, _, _, _, isSelected):
            return isSelected
        case let .custom(_, _, _, isSelected):
            return isSelected
        }
    }
    func selectAnimation(_ context: AccountContext) -> Signal<TelegramMediaFile, NoError> {
        switch self {
        case let .builtin(_, _, selectAnimation, _, _):
            return .single(selectAnimation)
        case .custom:
            return .complete()
        }
    }
    var selectedAnimation: TelegramMediaFile? {
        switch self {
        case let .builtin(_, _, selectAnimation, _, _):
            return selectAnimation
        case let .custom(_, _, file, _ ):
            return file
        }
    }
    var appearAnimation: TelegramMediaFile? {
        switch self {
        case let .builtin(_, _, _, appearAnimation, _):
            return appearAnimation
        case .custom:
            return nil
        }
    }
    var value: MessageReaction.Reaction {
        switch self {
        case let .builtin(value, _, _, _, _):
            return value
        case let .custom(value, _, _, _):
            return value
        }
    }
    
}



final class ContextAddReactionsListView : View, StickerFramesCollector  {
    
    
    private final class ReactionView : Control {
                
        let player: LottiePlayerView
        private var imageView: InlineStickerView?
        private let disposable = MetaDisposable()
        private let appearDisposable = MetaDisposable()
        private let fetchDisposables = DisposableSet()
        let reaction: ContextReaction
        let context: AccountContext
        private let stateDisposable = MetaDisposable()
        private var selectAnimationData: Data?
        private var currentKey: String?
        
        private var selectionView : View?
        private let presentation: TelegramPresentationTheme
        
        required init(frame frameRect: NSRect, context: AccountContext, reaction: ContextReaction, add: @escaping(MessageReaction.Reaction, Bool, NSRect?)->Void, theme: TelegramPresentationTheme) {
            
            let size: NSSize = reaction.isSelected ? NSMakeSize(25, 24) : NSMakeSize(frameRect.width, 30)
            let rect = CGRect(origin: .zero, size: size)
            
            let isLite = context.isLite(.emoji)
            
            self.presentation = theme
            self.player = LottiePlayerView(frame: rect)
            self.reaction = reaction
            self.context = context
           
            super.init(frame: frameRect)
            
            let imageView: InlineStickerView
            if let file = reaction.selectedAnimation {
                imageView = InlineStickerView(account: context.account, file: file, size: size, isPlayable: false)
            } else {
                imageView = InlineStickerView(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: reaction.fileId, file: nil, emoji: clown), size: size, isPlayable: false)
            }
            self.imageView = imageView
            addSubview(imageView)

            addSubview(player)
            self.player.isHidden = false

           
            switch reaction {
            case .builtin:
                self.layer?.cornerRadius = 0
            case .custom:
                self.layer?.cornerRadius = 4
            }
            
            stateDisposable.set(player.state.start(next: { [weak self] state in
                switch state {
                case .playing:
                    delay(0.016, closure: {
                        self?.imageView?.removeFromSuperview()
                    })
                case .stoped:
                    delay(0.016, closure: {
                        self?.imageView?.removeFromSuperview()
                    })
                default:
                    break
                }
            }))
                                    

            let signal = reaction.selectAnimation(context) |> mapToSignal {
                context.account.postbox.mediaBox.resourceData($0.resource, attemptSynchronously: true)
            }
            |> filter {
                $0.complete
            }
            |> deliverOnMainQueue
            
            disposable.set(signal.start(next: { [weak self] resourceData in
                if let data = try? Data(contentsOf: URL.init(fileURLWithPath: resourceData.path)) {
                    self?.selectAnimationData = data
                    if isLite {
                        let apply:()->Void = {
                            self?.apply(data, key: "select", policy: .framesCount(1))
                        }
                        apply()
                    }
                }
            }))
            set(handler: { control in
                if let window = control.window {
                    let wrect = control.convert(control.frame.size.bounds, to: nil)
                    let srect = window.convertToScreen(wrect)
                    add(reaction.value, true, context.window.convertFromScreen(srect))
                }
            }, for: .Click)
            
            contextMenu = {
                let menu = ContextMenu()
                menu.addItem(ContextMenuItem(strings().chatContextReactionQuick, handler: {
                    context.reactions.updateQuick(reaction.value)
                }, itemImage: MenuAnimation.menu_add_to_favorites.value))
                return menu
            }
            
            if reaction.isSelected {
                let view = View()
                self.selectionView = view
                view.frame = NSMakeRect(0, 0, 34, 34)
                view.layer?.cornerRadius = view.frame.height / 2
                view.backgroundColor = theme.colors.vibrant.mixedWith(NSColor(0x000000), alpha: 0.1)
                self.addSubview(view, positioned: .below, relativeTo: self.subviews.first)
                
                if case .custom = reaction.value {
                    self.player.layer?.cornerRadius = 4
                    self.imageView?.layer?.cornerRadius = 4
                }
            }

            if let file = reaction.selectedAnimation {
                fetchDisposables.add(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: file.resource)).start())
            }
            if let file = reaction.appearAnimation {
                fetchDisposables.add(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: file.resource)).start())
            }
            
        }
        
        var isLite: Bool {
            return context.isLite(.emoji)
        }
        
        private func apply(_ data: Data, key: String, policy: LottiePlayPolicy) {
            let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .bundle("reaction_\(reaction.value)_\(key)"), size: player.frame.size), type: .lottie, cachePurpose: .none, playPolicy: policy, maximumFps: 60, runOnQueue: Queue(), metalSupport: false)
            player.set(animation, reset: true, saveContext: true, animated: false)
            self.currentKey = key
        }
        
        deinit {
            disposable.dispose()
            stateDisposable.dispose()
            appearDisposable.dispose()
            fetchDisposables.dispose()
        }
        
        override func layout() {
            super.layout()
            updateLayout(size: self.frame.size, transition: .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: player, frame: self.focus(player.frame.size))
            if let imageView = imageView {
                transition.updateFrame(view: imageView, frame: self.focus(imageView.frame.size))
            }
            if let selectionView = self.selectionView {
                selectionView.center()
            }
        }
        private var previous: ControlState = .Normal
        override func stateDidUpdate(_ state: ControlState) {
            super.stateDidUpdate(state)
            let isLite = context.isLite(.emoji)
            switch state {
            case .Hover:
                if self.player.currentState != .playing, !isLite {
                    if self.player.animation?.playPolicy == .framesCount(1) {
                        self.player.set(self.player.animation?.withUpdatedPolicy(.once), reset: false)
                    } else {
                        if let data = selectAnimationData, self.currentKey != "select" {
                            self.apply(data, key: "select", policy: .framesCount(1))
                        } else {
                            self.player.playAgain()
                        }
                    }
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
        
        private var timestamp: TimeInterval? = Date().timeIntervalSince1970
        
        func playAppearAnimation() {
            guard self.visibleRect != .zero && !self.isLite else {
                return
            }
          
            
            
            if let appearAnimation = reaction.selectedAnimation {
                let signal = context.account.postbox.mediaBox.resourceData(appearAnimation.resource, attemptSynchronously: true)
                |> filter {
                    $0.complete
                } |> take(1)
                |> deliverOnMainQueue
                
//                self.imageView?.removeFromSuperview()
                            
                appearDisposable.set(signal.start(next: { [weak self] resourceData in
                    if let data = try? Data(contentsOf: URL.init(fileURLWithPath: resourceData.path)) {
                        if let timestamp = self?.timestamp, Date().timeIntervalSince1970 - timestamp > 0.1 {
                            return
                        }
                        self?.apply(data, key: "appear", policy: .toEnd(from: 0))
                    }
                }))
            } else {
                imageView?.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.35, bounce: true)
            }
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }
    
    class ShowMore : Control {
        private let imageView = ImageView()
        required init(frame frameRect: NSRect, theme: TelegramPresentationTheme) {
            super.init(frame: frameRect)
            self.backgroundColor = theme.colors.vibrant.mixedWith(NSColor(0x000000), alpha: 0.1)
            self.scaleOnClick = true
            self.layer?.cornerRadius = frameRect.height / 2
            addSubview(self.imageView)
            self.imageView.image = theme.icons.reactions_show_more
            self.imageView.sizeToFit()
        }
        
        override func layout() {
            super.layout()
            imageView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }
    
    private let scrollView = HorizontalScrollView()
    private let documentView = View()
    private let list: [ContextReaction]
    
    private let topGradient = ShadowView()
    private let bottomGradient = ShadowView()

    private let backgroundView = View()
    private let visualEffect = NSVisualEffectView(frame: .zero)
    private let radiusLayer: CGFloat?
    
    private var aboveTextView: TextView?
    
    private let showMore: ShowMore
    private let revealReactions:((ContextAddReactionsListView & StickerFramesCollector)->Void)?
    
    private let maskLayer = SimpleShapeLayer()
    private let backgroundColorView = View()
    private let shadowLayer = SimpleShapeLayer()
    private let presentation: TelegramPresentationTheme
    private let hasBubble: Bool
    private let aboveText: TextViewLayout?
    required init(frame frameRect: NSRect, context: AccountContext, list: [ContextReaction], add:@escaping(MessageReaction.Reaction, Bool, NSRect?)->Void, radiusLayer: CGFloat? = 15, revealReactions:((ContextAddReactionsListView & StickerFramesCollector)->Void)? = nil, presentation: TelegramPresentationTheme = theme, hasBubble: Bool = true, aboveText: TextViewLayout? = nil) {
        self.list = list
        self.showMore = ShowMore(frame: NSMakeRect(0, 0, 34, 34), theme: presentation)
        self.revealReactions = revealReactions
        self.radiusLayer = radiusLayer
        self.presentation = presentation
        self.hasBubble = hasBubble
        self.aboveText = aboveText
        super.init(frame: frameRect)
        
        
        let theme = presentation
        
        backgroundView.layer?.mask = maskLayer
        if !isLite(.blur) {
            self.visualEffect.state = .active
            self.visualEffect.wantsLayer = true
            self.visualEffect.blendingMode = hasBubble ? .behindWindow : .withinWindow
        }
        
        
        
        showMore.isHidden = revealReactions == nil
        
        showMore.set(handler: { [weak self] control in
            if let view = self {
                revealReactions?(view)
            }
            control.layer?.animateScaleCenter(from: 1, to: 0.1, duration: 0.35, removeOnCompletion: false)
            control.layer?.animateAlpha(from: 1, to: 0, duration: 0.35, removeOnCompletion: false)
        }, for: .Click)
        
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOffset = CGSize(width: 0.0, height: 0)
        shadowLayer.shadowRadius = 2
        shadowLayer.shadowOpacity = 0.2
        shadowLayer.fillColor = NSColor.clear.cgColor
        self.layer?.addSublayer(shadowLayer)

        bottomGradient.shadowBackground = theme.colors.background.withAlphaComponent(1)
        bottomGradient.direction = .horizontal(true)
        topGradient.shadowBackground = theme.colors.background.withAlphaComponent(1)
        topGradient.direction = .horizontal(false)
        
        if !isLite(.blur) {
            visualEffect.material = theme.colors.isDark ? .dark : .mediumLight
        }
        
        if #available(macOS 11.0, *), !isLite(.blur) {
            backgroundColorView.backgroundColor = theme.colors.background.withAlphaComponent(0.7)
        } else {
            backgroundColorView.backgroundColor = theme.colors.background
        }
        if #available(macOS 11.0, *), !isLite(.blur) {
            backgroundView.addSubview(visualEffect)
        }
        backgroundView.addSubview(backgroundColorView)

        
        
        addSubview(backgroundView)
        backgroundView.addSubview(scrollView)
        addSubview(showMore)
        
        backgroundView.addSubview(topGradient)
        backgroundView.addSubview(bottomGradient)

        
        if revealReactions == nil {
            NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.clipView, queue: OperationQueue.main, using: { [weak self] notification  in
                self?.updateScroll()
            })
        } else {
            var calc:CGFloat = 0
            var clicked: Bool = false
            scrollView.applyExternalScroll = { [weak self] event in
                calc += abs(event.deltaY)
                calc += abs(event.deltaX)
                
                if calc > 30, !clicked {
                    self?.showMore.send(event: .Click)
                    AppMenu.closeAll()
                    clicked = true
                    return false
                }
                return true
            }
        }
        
                
        scrollView.background = .clear
        scrollView.documentView = documentView
        let size = ContextAddReactionsListView.size
        var x: CGFloat = 1
        
       
        
        
        var y: CGFloat = 3
        if let aboveText = aboveText {
            y += aboveText.layoutSize.height + 2
        }
        
        for reaction in list {
            let add:(ContextReaction)->Void = { reaction in
                let itemSize = size.bounds
                let reaction = ReactionView(frame: NSMakeRect(x, y, itemSize.width, itemSize.height), context: context, reaction: reaction, add: add, theme: presentation)
                
                self.documentView.addSubview(reaction)
                x += size.width + 4
            }
            if x < frame.width {
                add(reaction)
            } else {
                DispatchQueue.main.async {
                    add(reaction)
                }
            }
        }
        
        if let aboveText = aboveText {
            let aboveTextView = TextView()
            aboveTextView.userInteractionEnabled = true
            aboveTextView.isSelectable = false
            addSubview(aboveTextView)
            self.aboveTextView = aboveTextView
            aboveTextView.update(aboveText)
        }
        
        updateLayout(size: frame.size, transition: .immediate)
        
       

        for view in self.documentView.subviews {
            let view = view as? ReactionView
            view?.playAppearAnimation()
        }
        updateScroll()
    }
    
    func collect() -> [Int : LottiePlayerView] {
        var frames:[Int : LottiePlayerView] = [:]
        for (i, view) in self.documentView.subviews.enumerated() {
            if let view = view as? ReactionView {
                frames[i] = view.player
            }
        }
        return frames
    }
    
    func invokeFirst() {
        for view in self.documentView.subviews {
            if let view = view as? ReactionView {
                view.send(event: .Click)
                return
            }
        }
    }
    
    static var size: CGSize {
        return .init(width: 37, height: 34)
    }
    
    func rect(for reaction: ContextReaction) -> NSRect {
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
    
    private var previousOffset: NSPoint = .zero
    private var previousRange: [Int] = []
    private func updateScroll() {
        
        self.topGradient.isHidden = self.scrollView.documentOffset.x == 0
        self.bottomGradient.isHidden = self.scrollView.documentOffset.x == self.scrollView.documentSize.width - self.scrollView.frame.width

        let range = visibleRange(self.scrollView.documentOffset)
        if previousRange != range, !previousRange.isEmpty {
            let new = range.filter({
                !previousRange.contains($0)
            })
            for i in new {
                let view = self.documentView.subviews[i] as? ReactionView
                view?.playAppearAnimation()
            }
        }
        self.previousRange = range
        
        if self.radiusLayer != nil {
            for view in documentView.subviews {
                var fr = CATransform3DIdentity
                if view.visibleRect.size != view.frame.size {
                    let value = max(0.5, view.visibleRect.width / view.frame.width)
                    fr = CATransform3DTranslate(fr, view.frame.width / 2, view.frame.height / 2, 0)
                    fr = CATransform3DScale(fr, value, value, 1)
                    fr = CATransform3DTranslate(fr, -(view.frame.width / 2), -(view.frame.height / 2), 0)
                    view.layer?.transform = fr
                } else {
                    view.layer?.transform = fr
                }
            }
        }
       
    }
    
    private func visibleRange(_ documentOffset: NSPoint) -> [Int] {
        var range: [Int] = []
        for (i, view) in documentView.subviews.enumerated() {
            if view.visibleRect != .zero {
                range.append(i)
            }
        }
        return range
    }
    
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    static func width(for count: Int, maxCount: Int = .max, allowToAll: Bool = true) -> CGFloat {
        var width = CGFloat(min(count, maxCount)) * self.size.width
        width += CGFloat(min(count, maxCount)) * 4
        if maxCount != .max, allowToAll {
            width += self.size.width
        }
        return width
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
        
        var rect = size.bounds.insetBy(dx: 10, dy: 10)
        rect.origin.y -= 5
        
        for subview in documentView.subviews {
            let point: NSPoint
            if let aboveText = aboveText {
                point = NSMakePoint(subview.frame.minX, aboveText.layoutSize.height + 2 + 3)
            } else {
                point = NSMakePoint(subview.frame.minX, 3)
            }
            transition.updateFrame(view: subview, frame: CGRect(origin: point, size: subview.frame.size))
        }
        
        if let aboveTextView = aboveTextView {
            aboveTextView.centerX(y: 8)
        }
        
        
        let documentRect = NSMakeSize(ContextAddReactionsListView.width(for: self.list.count), rect.height).bounds
        var scrollRect = rect
        if documentRect.width < scrollRect.width, self.list.count < 6 {
            scrollRect.size.width = documentRect.width
            scrollRect.origin.x = rect.minX + (rect.width - documentRect.width) / 2
        }
        transition.updateFrame(view: self.documentView, frame: documentRect)
        transition.updateFrame(view: self.scrollView, frame: scrollRect)

        transition.updateFrame(view: self.topGradient, frame: NSMakeRect(10, 0, 10, size.height))
        transition.updateFrame(view: self.bottomGradient, frame: NSMakeRect(rect.width, 0, 10, size.height))
        
        transition.updateFrame(view: visualEffect, frame: size.bounds)
        transition.updateFrame(view: backgroundView, frame: size.bounds)
        transition.updateFrame(view: backgroundColorView, frame: size.bounds)
        
        if let aboveText = aboveText {
            transition.updateFrame(view: showMore, frame: NSMakeRect(rect.maxX - showMore.frame.width - 3, rect.minY + 3 + aboveText.layoutSize.height + 2, showMore.frame.width, showMore.frame.height))
        } else {
            transition.updateFrame(view: showMore, frame: NSMakeRect(rect.maxX - showMore.frame.width - 3, rect.minY + 3, showMore.frame.width, showMore.frame.height))
        }
        
//        transition.updateFrame(layer: maskLayer, frame: rect.size.bounds)
        transition.updateFrame(layer: shadowLayer, frame: size.bounds)

        maskLayer.path = getMaskPath(rect: rect, hasBubble: self.hasBubble)
        
        shadowLayer.path = getMaskPath(rect: rect, hasBubble: self.hasBubble)
        shadowLayer.shadowPath = getMaskPath(rect: rect, hasBubble: self.hasBubble)

        
        if transition.isAnimated {
            maskLayer.animatePath()
        }
    }
    
    private func getMaskPath(rect: CGRect, hasBubble: Bool = true) -> CGPath {
        
        let mutablePath = CGMutablePath()
        mutablePath.addRoundedRect(in: rect, cornerWidth: 20, cornerHeight: 20)
        
        if hasBubble {
            let bubbleRect = NSMakeRect(rect.width - 40, rect.maxY - 10, 20, 20)
            mutablePath.addRoundedRect(in: bubbleRect, cornerWidth: bubbleRect.width / 2, cornerHeight: bubbleRect.width / 2)
        }

        return mutablePath
    }
}
//
//private final class LockView : View {
//    private let visualEffect = NSVisualEffectView()
//    override init() {
//        let frameRect = NSMakeSize(20, 20).bounds
//        super.init(frame: frameRect, theme: TelegramPresentationTheme)
//        addSubview(visualEffect)
//        visualEffect.wantsLayer = true
//        visualEffect.blendingMode = .withinWindow
//        visualEffect.state = .active
//        visualEffect.material = theme.dark ? .dark : .light
//
//        let maskLayer = CALayer()
//        maskLayer.frame = frameRect
//        maskLayer.contents = theme.icons.premium_reaction_lock
//
//        self.layer?.mask = maskLayer
//
//        self.background = theme.colors.grayText.withAlphaComponent(0.5)
//
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    required init(frame frameRect: NSRect) {
//        fatalError("init(frame:) has not been implemented")
//    }
//}


/*
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
            
            private let premium: LockView?
            
            required init(frame frameRect: NSRect, context: AccountContext, reaction: AvailableReactions.Reaction, add: @escaping(MessageReaction.Reaction)->Void) {
                self.reaction = reaction
                if reaction.isPremium, !context.isPremium {
                    self.premium = LockView()
                } else {
                    self.premium = nil
                }
                super.init(frame: frameRect)
                addSubview(imageView)
                addSubview(player)
                let signal = context.account.postbox.mediaBox.resourceData(reaction.selectAnimation.resource, attemptSynchronously: true)
                |> filter {
                    $0.complete
                }
                |> deliverOnMainQueue
                
                _ = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: reaction.selectAnimation.resource)).start()

                _ = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: reaction.appearAnimation.resource)).start()

                
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
                
                if !reaction.isPremium || context.isPremium {
                    contextMenu = {
                        let menu = ContextMenu()
                        menu.addItem(ContextMenuItem(strings().chatContextReactionQuick, handler: {
                            context.reactions.updateQuick(reaction.value)
                        }, itemImage: MenuAnimation.menu_add_to_favorites.value))
                        return menu
                    }
                }
                
                if let premium = premium {
                    addSubview(premium)
                }
                self.imageView.isHidden = premium != nil
                self.player.isHidden = premium != nil
            }
            
            private func apply(_ data: Data) {
                let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .bundle("reaction_\(reaction.value)"), size: player.frame.size), type: .lottie, cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 30, runOnQueue: .mainQueue())
                
                player.set(animation, reset: false, saveContext: true, animated: false)

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
                
                if let premium = premium {
                    transition.updateFrame(view: premium, frame: self.focus(premium.frame.size))
                }
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
        
        private let topGradient = ShadowView()
        private let bottomGradient = ShadowView()

        required init(frame frameRect: NSRect, context: AccountContext, isReversed: Bool, list: [AvailableReactions.Reaction], add:@escaping(MessageReaction.Reaction)->Void) {
            self.list = list
            self.isReversed = isReversed
            super.init(frame: frameRect)
            addSubview(scrollView)
            addSubview(topGradient)
            addSubview(bottomGradient)
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
            
            bottomGradient.shadowBackground = theme.colors.background.withAlphaComponent(1)
            bottomGradient.direction = .vertical(true)
            topGradient.shadowBackground = theme.colors.background.withAlphaComponent(1)
            topGradient.direction = .vertical(false)
            
            layer?.cornerRadius = frame.width / 2
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
            return min(30 * 4 + 15, CGFloat(list.count) * 30)
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
            
            transition.updateFrame(view: self.topGradient, frame: NSMakeRect(0, 0, frame.width, 10))
            transition.updateFrame(view: self.bottomGradient, frame: NSMakeRect(0, frame.height - 10, frame.width, 10))
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
        private let add:(MessageReaction.Reaction)->Void
        var isReversed: Bool = false
        var isRemoving: Bool = false
        required init(frame frameRect: NSRect, isBubbled: Bool, context: AccountContext, reactions: [AvailableReactions.Reaction], add:@escaping(MessageReaction.Reaction)->Void) {
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
        
        override var acceptsFirstResponder: Bool {
            return false
        }
        
        override func scrollWheel(with event: NSEvent) {
            disposable.set(nil)
            if isRemoving {
                self.nextResponder?.scrollWheel(with: event)
            }
            if let window = _window, window.inLiveSwiping {
                return
            }
            if let superview = superview as? ChatControllerView {
                superview.tableView.scrollWheel(with: event)
            }
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
    private var mouseLocked: Bool = false
    private let chatInteraction: ChatInteraction
    private let hideDelay = MetaDisposable()
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
            self?.delayAndUpdate(mouseMoved: false)
            return .rejected
        }, with: self, for: .mouseEntered, priority: self.priority)
        
        window.set(mouseHandler: { [weak self] event in
            self?.delayAndUpdate(mouseMoved: false)
            return .rejected
        }, with: self, for: .mouseExited, priority: self.priority)
        
        window.set(mouseHandler: { [weak self] event in
            self?.delayAndUpdate(mouseMoved: true)
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
        disposable.set(combineLatest(queue: .mainQueue(), context.reactions.stateValue, settings, window.keyWindowUpdater).start(next: { [weak self] reactions, settings, isKeyWindow in
            self?.reactions = reactions
            self?.settings = settings
            if !isKeyWindow {
                self?.clear()
            } else {
                self?.delayAndUpdate()
            }
        }))
    }
    
    deinit {
        disposable.dispose()
        window.removeAllHandlers(for: self)
        delayDisposable.dispose()
        lockDisposable.dispose()
        chatInteraction.remove(observer: self)
        hideDelay.dispose()
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
    
    private func delayAndUpdate(mouseMoved: Bool = false) {
        if mouseMoved {
            self.mouseLocked = false
            self.hideDelay.set(delaySignal(3.0).start(completed: { [weak self] in
                if self?.currentView?.isRevealed == false {
                    self?.clear()
                }
                self?.mouseLocked = true
            }))
        }
        self.update()
    }
        
    func update(transition: ContainedViewLayoutTransition = .immediate) {
        
        view?.tableView.tile()

        
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
        var needRemove: Bool = false
        available.removeAll(where: { value in
            if value.isPremium, !context.isPremium {
                if needRemove {
                    return true
                }
                needRemove = true
                return context.premiumIsBlocked
            } else {
                return false
            }
        })
        
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
        
        if let view = self.view, !available.isEmpty, !disabled, !mouseLocked {
            
            
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
                let canReact = item.canReact == true && lockId != item.stableId && context.window.isKeyWindow
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
                                delayDisposable.set(delaySignal(0.35).start(completed: { [weak self, weak item, weak view] in
                                    if let item = item, let view = view, item.stableId == self?.previousItem?.stableId {
                                        
                                        let rect = itemView.rectForReaction
                                        let base = view.convert(rect, from: itemView)

                                        let available = filter(available, attr: item.firstMessage?.reactionsAttribute)
                                        
                                        let current = ReactionView(frame: base, isBubbled: item.isBubbled, context: context, reactions: available, add: { [weak self] value in
                                            
                                            context.reactions.react(message.id, values: message.newReactions(with: value.toUpdate(nil)))
                                            
                                            self?.clearAndLock()
                                        })
                                                                                
                                        current.getBounds = { [weak view] in
                                            if let view = view {
                                                return view.tableView.bounds
                                            } else {
                                                return .zero
                                            }
                                        }
                                        view.addSubview(current, positioned: .above, relativeTo: view.floatingPhotosView)
                                        if animated {
                                            current.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                                            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                                        }
                                        self?.currentView = current
                                        current.item = item
                                    }
                                }))
                            } else {
                                if !isInside {
                                    self.clear()
                                }
                            }
                        } else {
                            if !isInside {
                                self.clear()
                            }
                        }
                    } else if let itemView = item.view as? ChatRowView {
                        let rect = itemView.rectForReaction
                        
                        let base = view.convert(rect, from: itemView)

                        
                        let safeRect = base.insetBy(dx: -base.width * 4, dy: -base.height * 4)
                        if !NSPointInRect(inside, safeRect) || !NSPointInRect(NSMakePoint(base.midX, base.midY), view.tableView.frame) {
                            self.clear()
                        } else if let current = currentView {
                            transition.updateFrame(view: current, frame: base)
                            current.updateLayout(base.size, transition: transition)
                        }
                    }
                } else {
                    if !isInside {
                        self.clear()
                    }
                }
            } else {
                if !isInside {
                    self.clear()
                }
            }
        } else {
            if !isInside {
                self.clear()
            }
        }
    }
    
    private var isInside: Bool {
        return self.currentView != nil && currentView!.mouseInside()
    }
    
    private func clear(animated: Bool = true) {
        if let view = self.currentView, view.isRevealed {
            self.lockId = self.previousItem?.stableId
        }
        self.removeCurrent(animated: animated)
        self.previousItem = nil
        self.delayDisposable.set(nil)
    }
    private func clearAndLock() {
        self.lockId = self.previousItem?.stableId
        self.mouseLocked = false
        self.hideDelay.set(nil)
        clear()
    }
    
    func clearAndTempLock() {
        self.clear(animated: false)
        self.mouseLocked = true
    }
    
    private func removeCurrent(animated: Bool) {
        if let view = currentView {
            self.currentView = nil
            view.userInteractionEnabled = false
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
        let newValue = value as? ChatPresentationInterfaceState
        let oldValue = oldValue as? ChatPresentationInterfaceState
        if let newValue = newValue, oldValue?.state != newValue.state {
            if newValue.state == .selecting {
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
 
 */



//
//                        let viewRect = view.convert(rect, from: itemView)
//                        let dst = 50 - min(max(0, inside.distance(p2: NSMakePoint(viewRect.midX, viewRect.midY))), 50)
//
//
//                        let multiplier = log2(mappingRange(dst, 0, 50, 1, 100))
//
//                        NSLog("\(log2(mappingRange(dst, 0, 50, 1, 100)))")
                        
//                        let updated = base.insetBy(dx: -3 * (multiplier / 7), dy: -3 * (multiplier / 7))
                        
