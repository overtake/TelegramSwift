//
//  TranscribeAudioTextView.swift
//  Telegram
//
//  Created by Mike Renoir on 07.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramMedia

final class TranscribeAudioTextView : View {
    private let textView = TextView()
    private var lottiePlayer: LottiePlayerView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: textView, frame: textView.frame.size.bounds)
        updateDots(size: size, transition: transition)
    }
    
    private func updateDots(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let layout = textView.textLayout, let last = layout.lines.last {
            if let view = lottiePlayer {
                let x: CGFloat
                if last.frame.maxX + view.frame.width > size.width {
                    x = -3
                } else {
                    x = last.frame.maxX
                }
                transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: x, y: size.height - view.frame.height + 1), size: view.frame.size))
            }
        }
    }
    
    func update(data: ChatMediaVoiceLayoutParameters.TranscribeData, animated: Bool) {
        if let textLayout = data.text {
            textView.update(textLayout)
        }
        
        let size = data.dotsSize
        if data.isPending, let dataSize = data.size {
            let current: LottiePlayerView
            if let view = lottiePlayer {
                current = view
            } else {
                current = LottiePlayerView()
                current.setFrameSize(size)
                self.lottiePlayer = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                let animation = LocalAnimatedSticker.voice_dots
                if let compressed = animation.data {
                    let colors: [LottieColor] = [LottieColor(keyPath: "", color: data.fontColor)]
                    current.set(LottieAnimation(compressed: compressed, key: .init(key: .bundle("dots_\(animation.rawValue)"), size: size, colors: colors), playPolicy: .loop, colors: colors))
                }
            }
            updateDots(size: dataSize, transition: .immediate)
        } else if let view = lottiePlayer {
            self.lottiePlayer = nil
            performSubviewRemoval(view, animated: animated)
        }
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
