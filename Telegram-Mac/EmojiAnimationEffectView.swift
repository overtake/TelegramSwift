//
//  EmojiAnimationEffect.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit
import TelegramMedia

final class EmojiAnimationEffectView : View {
    enum Source {
        case builtin(LottieAnimation)
        case custom(CustomReactionEffectView)
    }
    private let player: NSView
    private let animation: Source
    let animationSize: NSSize
    private var animationPoint: CGPoint
    
    var index: Int? = nil
    
    init(animation: Source, animationSize: NSSize, animationPoint: CGPoint, frameRect: NSRect) {
        self.animation = animation
        self.animationSize = animationSize
        self.animationPoint = animationPoint
        let view: NSView
        
        
        switch animation {
        case let .builtin(animation):
            let player = LottiePlayerView(frame: .init(origin: animationPoint, size: animationSize))
            player.set(animation)
            view = player
            player.isEventLess = true
        case let .custom(current):
            view = current
        }
        self.player = view
        super.init(frame: frameRect)
        addSubview(view)
        isEventLess = true
        updateLayout(size: frameRect.size, transition: .immediate)
        
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
        
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.player, frame: CGRect(origin: animationPoint, size: animationSize))
        if let view = player as? LottiePlayerView {
            view.update(size: animationSize, transition: transition)
        }
    }
    
    func updatePoint(_ point: NSPoint, transition: ContainedViewLayoutTransition) {
        self.animationPoint = point
        self.updateLayout(size: frame.size, transition: transition)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
