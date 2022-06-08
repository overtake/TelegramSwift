//
//  TranscribeAudioTextView.swift
//  Telegram
//
//  Created by Mike Renoir on 07.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class TranscribeAudioTextView : View {
    private let textView = TextView()
    private let lottiePlayer = LottiePlayerView()
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
    }
    
    func update(data: ChatMediaVoiceLayoutParameters.TranscribeData, animated: Bool) {
        if let textLayout = data.text {
            textView.update(textLayout)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
