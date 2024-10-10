//
//  ReactionCarouselView.swift
//  Telegram
//
//  Created by Mike Renoir on 03.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import AppKit
import TelegramMedia

private final class ReactionView : Control {
            
    private let player = LottiePlayerView(frame: NSMakeRect(0, 0, 80, 80))
    private let imageView = TransformImageView(frame: NSMakeRect(0, 0, 80, 80))
    private let disposable = MetaDisposable()
    private let appearDisposable = MetaDisposable()
    let reaction: AvailableReactions.Reaction
    let context: AccountContext
    private let stateDisposable = MetaDisposable()
    private var selectAnimationData: Data?
    private var currentKey: String?
    
    
    required init(frame frameRect: NSRect, context: AccountContext, reaction: AvailableReactions.Reaction, add: @escaping(MessageReaction.Reaction)->Void) {
        self.reaction = reaction
        self.context = context
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(player)
        

        let signal = context.account.postbox.mediaBox.resourceData(reaction.activateAnimation.resource, attemptSynchronously: true)
        |> filter {
            $0.complete
        }
        |> deliverOnMainQueue
        
        _ = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .standalone(resource: reaction.selectAnimation.resource)).start()
        _ = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .standalone(resource: reaction.appearAnimation.resource)).start()
        
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
                self?.selectAnimationData = data
                self?.apply(data, key: "select", policy: .framesCount(1))
            }
        }))
        set(handler: { _ in
            add(reaction.value)
        }, for: .Click)
        

    }
    
    private func apply(_ data: Data, key: String, policy: LottiePlayPolicy) {
        let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .bundle("reaction_\(reaction.value)_\(key)"), size: player.frame.size), type: .lottie, cachePurpose: .none, playPolicy: policy, maximumFps: 60, runOnQueue: .mainQueue(), metalSupport: false)
        player.set(animation, reset: true, saveContext: true, animated: false)
        self.currentKey = key
    }
    
    deinit {
        disposable.dispose()
        stateDisposable.dispose()
        appearDisposable.dispose()
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
        
//        if previous == .Hover, state == .Highlight {
//            self.layer?.animateScaleCenter(from: 1, to: 0.95, duration: 0.2, removeOnCompletion: false)
//        } else if state == .Hover && previous == .Highlight {
//            self.layer?.animateScaleCenter(from: 0.95, to: 1, duration: 0.2, removeOnCompletion: true)
//        }
        previous = state
    }
    
    func playSelectAnimation() {
                    
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}



private let itemSize = CGSize(width: 110, height: 110)

final class ReactionCarouselView: View {
    
    private final class EffectView : View {
        
        private let player: LottiePlayerView
        private let animation: LottieAnimation
        let animationSize: NSSize
        let value: MessageReaction.Reaction
        init(animation: LottieAnimation, value: MessageReaction.Reaction, animationSize: NSSize, frameRect: NSRect) {
            self.animation = animation
            self.value = value
            self.player = LottiePlayerView(frame: .init(origin: .zero, size: animationSize))
            self.animationSize = animationSize
            super.init(frame: frameRect)
            addSubview(player)
            player.set(animation)
            isEventLess = true
            player.isEventLess = true
            updateLayout(size: frameRect.size, transition: .immediate)
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: frame.size, transition: .immediate)
        }
            
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: self.player, frame: size.bounds)
            self.player.update(size: size, transition: transition)
        }

        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }

    
    private let context: AccountContext
    private let reactions: [AvailableReactions.Reaction]
    private var itemViews: [ReactionView] = []
    private let scrollView: ScrollView = ScrollView()
    private let tapView = View()
    
    private var timer: SwiftSignalKit.Timer?
    
    private let disposable = MetaDisposable()
    
    
    private var animator: DisplayLinkAnimator?
    private var currentPosition: CGFloat = 0.0
    
    private var validLayout: CGSize?
    
    init(context: AccountContext, reactions: [AvailableReactions.Reaction]) {
        self.context = context
        self.reactions = Array(reactions.filter { $0.isPremium }.filter { $0.aroundAnimation != nil })
        
        super.init(frame: .zero)
        
        self.scrollView.background = .clear
        
        self.addSubview(self.scrollView)
                
        self.scrollView.documentView = tapView
        
        
//        NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveScrollNotification, object: scrollView, queue: nil, using: { [weak self] notification in
//            self?.scrollDidEndLiveScrolling()
//        })
//        
//        NotificationCenter.default.addObserver(forName: NSScrollView.willStartLiveScrollNotification, object: scrollView, queue: nil, using: { [weak self] notification in
//            self?.scrollWillStartLiveScrolling()
//        })
//        
//        
//        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.clipView, queue: OperationQueue.main, using: { [weak self] notification  in
//            self?.scrollViewDidScroll()
//        })
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    

    
    func animateIn() {
        delay(0.2, closure: {
            let delta = 1.0 / CGFloat(self.itemViews.count)
            let currentIndex = max(0, min(self.itemViews.count - 1, Int(round(self.currentPosition / delta))))
            self.scrollTo(abs(self.itemViews.count - currentIndex - 1), playReaction: true, duration: 0.5, clockwise: true)
        })
    }
    
    func animateOut() {
        self.timer?.invalidate()
        self.timer = nil
        self.animator = nil
    }
    
    func scrollTo(_ index: Int, playReaction: Bool, duration: Double, clockwise: Bool? = nil) {
        
        let totatCount = self.itemViews.count
        
        guard index >= 0 && index < totatCount else {
            return
        }
        

        self.timer?.invalidate()
        self.timer = nil
        
        let delta = 1.0 / CGFloat(totatCount)
        
        
        
        let startPosition = self.currentPosition
        let newPosition = delta * CGFloat(index)
        var change = newPosition - startPosition
        if let clockwise = clockwise {
            if clockwise {
                if change > 0.0 {
                    change = change - 1.0
                }
            } else {
                if change < 0.0 {
                    change = 1.0 + change
                }
            }
        } else {
            if change > 0.5 {
                change = change - 1.0
            } else if change < -0.5 {
                change = 1.0 + change
            }
        }
        
        let currentIndex = max(0, min(self.itemViews.count - 1, Int(round(self.currentPosition / delta))))
        if playReaction, currentIndex == index, change == 0 {
            self.playReaction()
            return
        }
        
        self.animator = DisplayLinkAnimator(duration: duration, from: 0.0, to: 1.0, update: { [weak self] t in
            let t = listViewAnimationCurveSystem(t)
            var updatedPosition = startPosition + change * t
            while updatedPosition >= 1.0 {
                updatedPosition -= 1.0
            }
            while updatedPosition < 0.0 {
                updatedPosition += 1.0
            }
            self?.currentPosition = updatedPosition
            if let size = self?.validLayout {
                self?.updateLayout(size: size, transition: .immediate)
            }
        }, completion: { [weak self] in
            self?.animator = nil
            if playReaction {
                self?.playReaction()
            }
            
            self?.timer = SwiftSignalKit.Timer(timeout: 2.5, repeat: false, completion: {
                var updated: Int = index - 1
                if updated < 0 {
                    updated = totatCount - 1
                }
                self?.scrollTo(updated, playReaction: true, duration: 0.5, clockwise: nil)
            }, queue: .mainQueue())
            
            self?.timer?.start()
        })
    }
    
    func setup() {
        for (i, reaction) in self.reactions.enumerated() {
            let itemView = ReactionView(frame: .zero, context: context, reaction: reaction, add: { [weak self] value in
                self?.scrollTo(i, playReaction: false, duration: 0.5, clockwise: nil)
                guard let aroundAnimation = reaction.aroundAnimation else {
                    return
                }
                self?.add(effect: reaction.value, file: aroundAnimation)
            })
            self.addSubview(itemView)
                        
            self.itemViews.append(itemView)
        }
        
        needsLayout = true
    }
    
    private func add(effect value: MessageReaction.Reaction, file: TelegramMediaFile) {
        
        let animationSize = NSMakeSize(200, 200)
        
        let signal: Signal<LottieAnimation?, NoError> =  context.account.postbox.mediaBox.resourceData(file.resource)
            |> filter { $0.complete }
            |> take(1)
            |> map { data in
                if let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    return LottieAnimation(compressed: data, key: .init(key: .bundle("_reaction_e_\(value)"), size: animationSize, backingScale: Int(System.backingScale), mirror: false), cachePurpose: .temporaryLZ4(.effect), playPolicy: .onceEnd)
                } else {
                  return nil
                }
            } |> deliverOnMainQueue
           
        disposable.set(signal.start(next: { [weak self] animation in
            self?.playEffect(animation, value: value)
        }))
        
        
    }
    
    private func playEffect(_ animation: LottieAnimation?, value: MessageReaction.Reaction) {
        if let animation = animation {
            
            var getView:(()->NSView?)? = nil
            
            animation.triggerOn = (LottiePlayerTriggerFrame.last, { [weak self] in
                self?.removeEffect(getView?())
            }, {})
            let current: EffectView = EffectView(animation: animation, value: value, animationSize: animation.key.size, frameRect: animation.key.size.bounds)
            
            getView = { [weak current] in
                return current
            }
            for itemView in itemViews {
                if itemView.reaction.value == value {
                    itemView.playSelectAnimation()
                }
            }
            self.addSubview(current)
        }
        updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    private func removeEffect(_ view: NSView?) {
        if let view = view {
            performSubviewRemoval(view, animated: true)
        }
    }
    
    private var ignoreContentOffsetChange = false
    private func resetScrollPosition() {
        self.scrollStartPosition = nil
        self.ignoreContentOffsetChange = true
        self.scrollView.clipView.scroll(to: CGPoint(x: 5000.0 - self.scrollView.frame.width * 0.5, y: 5000.0 - self.scrollView.frame.height * 0.5))
        self.ignoreContentOffsetChange = false
    }
    
    func playReaction() {
        
        let delta = 1.0 / CGFloat(self.itemViews.count)
        let index = max(0, min(self.itemViews.count - 1, Int(round(self.currentPosition / delta))))
        
        let reaction = self.itemViews[index].reaction
               
        guard let aroundAnimation = reaction.aroundAnimation else {
            return
        }
        
        self.add(effect: reaction.value, file: aroundAnimation)
    }
    
    deinit {
        disposable.dispose()
    }
    
    private var scrollStartPosition: (contentOffset: CGFloat, position: CGFloat)?
    func scrollWillStartLiveScrolling() {
        if self.scrollStartPosition == nil {
            self.scrollStartPosition = (scrollView.contentOffset.x, self.currentPosition)
        }
    }
    
    func scrollViewDidScroll() {
        guard !self.ignoreContentOffsetChange, let (startContentOffset, startPosition) = self.scrollStartPosition else {
            return
        }

        var delta = scrollView.contentOffset.x - startContentOffset
        
        if delta == 0 {
            delta = scrollView.contentOffset.y - startContentOffset
        }
        let positionDelta = delta * -0.001
        var updatedPosition = startPosition + positionDelta
        while updatedPosition >= 1.0 {
            updatedPosition -= 1.0
        }
        while updatedPosition < 0.0 {
            updatedPosition += 1.0
        }
        self.currentPosition = updatedPosition
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    func scrollDidEndLiveScrolling() {
        self.resetScrollPosition()
        
        let delta = 1.0 / CGFloat(self.itemViews.count)
        let index = max(0, min(self.itemViews.count - 1, Int(round(self.currentPosition / delta))))
        self.scrollTo(index, playReaction: true, duration: 0.2)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let size = NSMakeSize(size.width, size.height - 40)
        
        self.scrollView.frame = CGRect(origin: CGPoint(), size: NSMakeSize(size.width, size.height))
        if self.scrollView.contentSize.width.isZero {
            self.resetScrollPosition()
        }
        self.tapView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 10000000, height: 10000000))
        
        let delta = 1.0 / CGFloat(self.itemViews.count)
    
        let areaSize = CGSize(width: floor(size.width * 0.7), height: size.height * 0.44)
        
        var i = 0
        for itemView in self.itemViews {
            var angle = CGFloat.pi * 0.5 + CGFloat(i) * delta * CGFloat.pi * 2.0 - self.currentPosition * CGFloat.pi * 2.0
            if angle < 0.0 {
                angle = CGFloat.pi * 2.0 + angle
            }
            if angle > CGFloat.pi * 2.0 {
                angle = angle - CGFloat.pi * 2.0
            }
            
            func calculateRelativeAngle(_ angle: CGFloat) -> CGFloat {
                var relativeAngle = angle - CGFloat.pi * 0.5
                if relativeAngle > CGFloat.pi {
                    relativeAngle = (2.0 * CGFloat.pi - relativeAngle) * -1.0
                }
                return relativeAngle
            }
                        
            let rotatedAngle = angle - CGFloat.pi / 2.0
            
            var updatedAngle = rotatedAngle + 0.5 * sin(rotatedAngle)
            updatedAngle = updatedAngle + CGFloat.pi / 2.0

            let relativeAngle = calculateRelativeAngle(updatedAngle)
            let distance = abs(relativeAngle) / CGFloat.pi
            
            let point = CGPoint(
                x: cos(updatedAngle),
                y: sin(updatedAngle)
            )

            let value = 1.0 - distance * 0.8

            
            let itemFrame = CGRect(origin: CGPoint(x: size.width * 0.5 + point.x * areaSize.width * 0.5 - itemSize.width * 0.5, y: size.height * 0.5 + point.y * areaSize.height * 0.5 - itemSize.height * 0.5), size: itemSize)
            itemView.frame = itemFrame
            
//
            var fr = CATransform3DIdentity
            fr = CATransform3DTranslate(fr, itemFrame.width / 2, itemFrame.height / 2, 0)
            fr = CATransform3DScale(fr, value, value, 1)
            fr = CATransform3DTranslate(fr, -(itemFrame.width / 2), -(itemFrame.height / 2), 0)
            itemView.layer?.sublayerTransform = fr
            
            
            transition.updateFrame(view: itemView, frame: itemFrame)
            for view in self.subviews {
                if let view = view as? EffectView {
                    if view.value == itemView.reaction.value {
                        let rect = NSMakeRect(itemFrame.midX - view.frame.width / 2, itemFrame.midY - view.frame.height / 2, view.frame.width, view.frame.height)
                        transition.updateFrame(view: view, frame: rect)
                    }
                }
            }
            
            i += 1
        }
    }
}


//CGRect(origin: CGPoint(), size: itemFrame.size)
//            itemNode.updateLayout(size: itemFrame.size, isExpanded: false, largeExpanded: false, isPreviewing: false, transition: transition)
