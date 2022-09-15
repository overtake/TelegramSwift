//
//  ChatInputAnimatedEmojiAttach.swift
//  Telegram
//
//  Created by Mike Renoir on 30.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TGModernGrowingTextView

final class ChatInputAnimatedEmojiAttach: View {
    
    private var media: InlineStickerItemLayer!
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    func set(_ attachment: TGTextAttachment, size: NSSize, context: AccountContext) -> Void {
        
        let fileId = attachment.fileId as! Int64
        let file = attachment.file as? TelegramMediaFile
    
        let fromRect = attachment.fromRect
        
        
        self.media = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: file, emoji: attachment.text), size: size)
        
        let mediaRect = self.focus(media.frame.size)
        
        self.media.isPlayable = true
        self.media.frame = mediaRect
        self.layer?.addSublayer(media)
        
        if fromRect != .zero {
            
            self.isHidden = true
            DispatchQueue.main.async {
                
                let layer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: file, emoji: attachment.text), size: size)
                let toRect = self.convert(self.bounds, to: nil)
                
                let from = fromRect.origin.offsetBy(dx: fromRect.width / 2, dy: fromRect.height / 2)
                let to = toRect.origin.offsetBy(dx: toRect.width / 2, dy: toRect.height / 2)

                parabollicReactionAnimation(layer, fromPoint: from, toPoint: to, window: context.window, completion: { [weak self] _ in
                    self?.isHidden = false
                    self?.layer?.animateScaleSpring(from: 0.8, to: 1.0, duration: 0.2, bounce: true)
                })
            }
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        self.media.frame = focus(media.frame.size)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
