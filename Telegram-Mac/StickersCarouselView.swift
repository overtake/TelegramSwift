//
//  StickersCarouselView.swift
//  Telegram
//
//  Created by Mike Renoir on 15.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramMedia

private let itemSize = CGSize(width: 220.0, height: 220.0)

class StickersCarouselView: View, PremiumSlideView {
    private let context: AccountContext
    private let stickers: [TelegramMediaFile]
    private var itemContainerViews: [NSView] = []
    private var itemViews: [Int: MediaAnimatedStickerView] = [:]
    private let scrollView: ScrollView
    private let tapView: Control
    
    private var animator: DisplayLinkAnimator?
    private var currentPosition: CGFloat = 0.0
    private var currentIndex: Int = 0
    
    private var validLayout: CGSize?
    
    private var playingIndices = Set<Int>()
    
    private let positionDelta: Double
    
    private var previousInteractionTimestamp: Double = 0.0
    private var timer: SwiftSignalKit.Timer?
    
    private var effectView = View()
    
    init(context: AccountContext, stickers: [TelegramMediaFile]) {
        self.context = context
        self.stickers = stickers
        
        self.scrollView = ScrollView()
        self.tapView = Control()
        
        self.positionDelta = 1.0 / CGFloat(self.stickers.count)
        
        super.init(frame: .zero)
        
        self.scrollView.background = .clear
                
        self.tapView.set(handler: { [weak self] _ in
            self?.stickerTapped()
        }, for: .Click)
        
        self.addSubview(self.scrollView)
        self.scrollView.documentView = self.tapView
        
        for _ in self.stickers {
            let containerView = View()
            self.addSubview(containerView)
                        
            self.itemContainerViews.append(containerView)
        }
        effectView.isEventLess = true
        self.addSubview(effectView)
        
        NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveScrollNotification, object: scrollView, queue: nil, using: { [weak self] notification in
            self?.scrollDidEndLiveScrolling()
        })

        NotificationCenter.default.addObserver(forName: NSScrollView.willStartLiveScrollNotification, object: scrollView, queue: nil, using: { [weak self] notification in
            self?.scrollWillStartLiveScrolling()
        })


        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.clipView, queue: OperationQueue.main, using: { [weak self] notification  in
            self?.scrollViewDidScroll()
        })
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    private func stickerTapped() {
        self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
        
        guard self.animator == nil, self.scrollStartPosition == nil, let point = window?.mouseLocationOutsideOfEventStream else {
            return
        }
        
        let current = self.convert(point, from: nil)
        guard let index = self.itemContainerViews.firstIndex(where: { $0.frame.contains(current) }) else {
            return
        }
        
        self.scrollTo(index, playAnimation: true, immediately: true, duration: 0.4)
    }
    
    func animateIn() {
        self.scrollTo(1, playAnimation: true, immediately: true, duration: 0.5, clockwise: true)
        
        if self.timer == nil {
            self.previousInteractionTimestamp = CACurrentMediaTime()
            self.timer = SwiftSignalKit.Timer(timeout: 0.2, repeat: true, completion: { [weak self] in
                if let strongSelf = self {
                    let currentTimestamp = CACurrentMediaTime()
                    if currentTimestamp > strongSelf.previousInteractionTimestamp + 2.0 {
                        var nextIndex = strongSelf.currentIndex - 1
                        if nextIndex < 0 {
                            nextIndex = strongSelf.stickers.count + nextIndex
                        }
                        strongSelf.scrollTo(nextIndex, playAnimation: true, immediately: true, duration: 0.85, clockwise: true)
                        strongSelf.previousInteractionTimestamp = currentTimestamp
                    }
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
    }
    
    func scrollTo(_ index: Int, playAnimation: Bool, immediately: Bool, duration: Double, clockwise: Bool? = nil) {
        guard index >= 0 && index < self.stickers.count else {
            return
        }
        self.currentIndex = index
        let delta = self.positionDelta
        
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
        
        if immediately {
            self.playSelectedSticker(index: index)
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
            if playAnimation && !immediately {
                self?.playSelectedSticker(index: index)
            }
        })
    }
    
    func willAppear() {
        setVisible(true)
        self.playSelectedSticker(index: nil)
    }
    func willDisappear() {
        setVisible(false)
    }
    
    private var visibility = false
    func setVisible(_ visible: Bool) {
        guard self.visibility != visible else {
            return
        }
        self.visibility = visible
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    private var ignoreContentOffsetChange = false
    private func resetScrollPosition() {
        self.scrollStartPosition = nil
        self.ignoreContentOffsetChange = true
        self.scrollView.clipView.scroll(to: CGPoint(x: 0.0, y: tapView.frame.height / 2 - self.scrollView.frame.height * 0.5))
        self.ignoreContentOffsetChange = false
    }
    
    func playSelectedSticker(index: Int?) {
        let index = index ?? max(0, Int(round(self.currentPosition / self.positionDelta)) % self.stickers.count)
        
        guard !self.playingIndices.contains(index) else {
            return
        }
        self.addEffect(to: index)
    }
    
    private var scrollStartPosition: (contentOffset: CGFloat, position: CGFloat)?
    func scrollWillStartLiveScrolling() {
        if self.scrollStartPosition == nil {
            self.scrollStartPosition = (scrollView.contentOffset.y, self.currentPosition)
        }
        
        for (_, itemView) in self.itemViews {
            //itemView.setCentral(false)
        }
    }
    
        
    func scrollViewDidScroll() {
        
        if let animator = self.animator {
            animator.invalidate()
            self.animator = nil
        }
        
        guard !self.ignoreContentOffsetChange, let (startContentOffset, startPosition) = self.scrollStartPosition else {
            return
        }

        let delta = scrollView.contentOffset.y - startContentOffset
        let positionDelta = delta * 0.0005
        var updatedPosition = startPosition + positionDelta
        while updatedPosition >= 1.0 {
            updatedPosition -= 1.0
        }
        while updatedPosition < 0.0 {
            updatedPosition += 1.0
        }
        self.currentPosition = updatedPosition
        
        let indexDelta = self.positionDelta
        let index = max(0, Int(round(self.currentPosition / indexDelta)) % self.stickers.count)
        if index != self.currentIndex {
            self.currentIndex = index
            
            addEffect(to: index)
        }
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    private func addEffect(to index: Int) {
        let file = self.stickers[index]
        if let effect = file.premiumEffect {
            let animationSize = NSMakeSize(itemSize.width * 1.3, itemSize.height * 1.3)
            
            let signal: Signal<LottieAnimation?, NoError> =  context.account.postbox.mediaBox.resourceData(effect.resource) |> filter { $0.complete } |> take(1) |> map { data in
                if data.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    return LottieAnimation(compressed: data, key: .init(key: .bundle("_prem_effect_\(file.fileId.id)"), size: animationSize, backingScale: Int(System.backingScale), mirror: false), cachePurpose: .temporaryLZ4(.effect), playPolicy: .onceEnd)
                } else {
                    return nil
                }
            }
            |> deliverOnMainQueue
            
            _ = signal.start(next: { [weak self] animation in
                if let animation = animation {
                    self?.addAnimationEffect(animation, index: index)
                }
            })
        }
    }
    
    private func addAnimationEffect(_ animation: LottieAnimation, index: Int) {
        let viewFrame = self.bounds
        let animationSize = NSMakeSize(itemSize.width * 1.3, itemSize.height * 1.3)
        animation.triggerOn = (LottiePlayerTriggerFrame.last, { [weak self] in
            self?.removeAnimationEffects(for: index)
        }, {})
        
        let view = EmojiAnimationEffectView(animation: .builtin(animation), animationSize: animationSize, animationPoint: .zero, frameRect: viewFrame)
        view.index = index
        effectView.addSubview(view)
        updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    private func removeAnimationEffects(for index: Int) {
        let subviews = effectView.subviews
        for view in subviews {
            if let view = view as? EmojiAnimationEffectView {
                if view.index == index {
                    view.removeFromSuperview()
                }
            }
        }
    }
    
    func scrollDidEndLiveScrolling() {
        guard let (startContentOffset, _) = self.scrollStartPosition else {
            return
        }
        
        let delta = self.positionDelta
        let scrollDelta = scrollView.documentOffset.y - startContentOffset
        let positionDelta = scrollDelta * 0.0005
        let positionCounts = round(positionDelta / delta)
        let adjustedPositionDelta = delta * positionCounts
        let adjustedScrollDelta = adjustedPositionDelta * 2000.0
                
//        scrollView.clipView.scroll(to: CGPoint(x: 0.0, y: startContentOffset + adjustedScrollDelta), animated: true)
    }
    
    
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        self.scrollView.frame = CGRect(origin: CGPoint(), size: size)
        if self.tapView.frame == .zero {
            self.tapView.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 100000000))
            self.resetScrollPosition()
        }
        
        self.effectView.frame = size.bounds
        
        let delta = self.positionDelta
    
        let bounds = CGRect(origin: .zero, size: size)
        let areaSize = CGSize(width: floor(size.width * 4.0), height: size.height * 2.2)
        
        for i in 0 ..< self.stickers.count {
            let containerView = self.itemContainerViews[i]
            
            var angle = CGFloat.pi * 0.5 + CGFloat(i) * delta * CGFloat.pi * 2.0 - self.currentPosition * CGFloat.pi * 2.0 - CGFloat.pi * 0.5
            if angle < 0.0 {
                angle = CGFloat.pi * 2.0 + angle
            }
            if angle > CGFloat.pi * 2.0 {
                angle = angle - CGFloat.pi * 2.0
            }
            
            func calculateRelativeAngle(_ angle: CGFloat) -> CGFloat {
                var relativeAngle = angle
                if relativeAngle > CGFloat.pi {
                    relativeAngle = (2.0 * CGFloat.pi - relativeAngle) * -1.0
                }
                return relativeAngle
            }
            
            let relativeAngle = calculateRelativeAngle(angle)
            let distance = abs(relativeAngle)
            
            let point = CGPoint(
                x: cos(angle),
                y: sin(angle)
            )
                        
            let itemFrame = CGRect(origin: CGPoint(x: -size.width - 0.5 * itemSize.width - 30.0 + point.x * areaSize.width * 0.5 - itemSize.width * 0.5, y: size.height * 0.5 + point.y * areaSize.height * 0.5 - itemSize.height * 0.5), size: itemSize)
            containerView.frame = itemFrame
            
            let value = 1.0 - distance * 0.75

            
            
            var fr = CATransform3DIdentity
            fr = CATransform3DTranslate(fr, itemFrame.width / 2, itemFrame.height / 2, 0)
            fr = CATransform3DScale(fr, value, value, 1)
            fr = CATransform3DTranslate(fr, -(itemFrame.width / 2), -(itemFrame.height / 2), 0)
            containerView.layer?.sublayerTransform = fr
            
           
            
            transition.updateAlpha(view: containerView, alpha: 1.0 - distance * 0.6)
            
            let isVisible = self.visibility && itemFrame.intersects(bounds)
            if isVisible {
                let itemView: MediaAnimatedStickerView
                if let current = self.itemViews[i] {
                    itemView = current
                } else {
                    itemView = MediaAnimatedStickerView(frame: .zero)
                    itemView.update(with: self.stickers[i], size: itemSize, context: context, table: nil, animated: false)
                    containerView.addSubview(itemView)
                    self.itemViews[i] = itemView
                }
                
//                itemView.setCentral(isCentral)
                
                itemView.frame = CGRect(origin: CGPoint(), size: itemFrame.size)
                itemView.updateLayout(size: itemFrame.size, transition: transition)
                
                for view in effectView.subviews {
                    if let view = view as? EmojiAnimationEffectView {
                        if view.index == i {
                            view.frame = NSMakeRect(itemFrame.midX - view.frame.width / 2, itemFrame.midY - view.frame.height / 2, view.frame.width, view.frame.height)
                        }
                    }
                }
                
            } else {
                if let itemView = self.itemViews[i] {
                    itemView.removeFromSuperview()
                    self.itemViews[i] = nil
                }
                self.removeAnimationEffects(for: i)
            }

            for view in effectView.subviews {
                if let view = view as? EmojiAnimationEffectView {
                    if view.index == i {
                        var fr = CATransform3DIdentity
                        fr = CATransform3DTranslate(fr, view.frame.width / 2, view.frame.height / 2, 0)
                        fr = CATransform3DScale(fr, value, value, 1)
                        fr = CATransform3DTranslate(fr, -(view.frame.width / 2), -(view.frame.height / 2), 0)
                        view.layer?.transform = fr
                    }
                }
                
            }
            
        }
    }
}

