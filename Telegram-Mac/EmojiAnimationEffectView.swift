//
//  EmojiAnimationEffect.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class EmojiAnimationEffectView : View {
    
    private let player: LottiePlayerView
    private let animation: LottieAnimation
    let animationSize: NSSize
    private var animationPoint: CGPoint
    init(animation: LottieAnimation, animationSize: NSSize, animationPoint: CGPoint, frameRect: NSRect) {
        self.animation = animation
        self.player = LottiePlayerView(frame: .init(origin: animationPoint, size: animationSize))
        self.animationSize = animationSize
        self.animationPoint = animationPoint
        super.init(frame: frameRect)
        addSubview(player)
        player.set(animation)
        isEventLess = true
        
        updateLayout(size: frameRect.size, transition: .immediate)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
        
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.player, frame: CGRect(origin: animationPoint, size: animationSize))
        self.player.update(size: animationSize, transition: transition)
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
