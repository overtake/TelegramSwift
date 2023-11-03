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
import InputView

final class ChatInputAnimatedEmojiAttach: View {
    
    private var media: InlineStickerItemLayer!
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    func set(_ attachment: TGTextAttachment, size: NSSize, context: AccountContext) -> Void {
        
        let fileId = attachment.fileId as! Int64
        let file = attachment.file as? TelegramMediaFile
    
        let fromRect = attachment.fromRect
        
        
        self.media = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: file, emoji: attachment.text), size: size, textColor: theme.colors.text)
        
        let mediaRect = self.focus(media.frame.size)
        
        self.media.isPlayable = !isLite(.emoji)
        self.media.frame = mediaRect
        self.layer?.addSublayer(media)
                
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


final class InputAnimatedEmojiAttach: View {
    
    private var media: InlineStickerItemLayer!
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.masksToBounds = false
        
    }
    func set(_ attachment: TextInputTextCustomEmojiAttribute, size: NSSize, context: AccountContext, textColor: NSColor, playPolicy: LottiePlayPolicy = .loop) -> Void {
        
        
        let fileId = attachment.fileId
        let file = attachment.file
            
        self.media = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: file, emoji: ""), size: size, playPolicy: playPolicy, textColor: textColor)
        
        let mediaRect = self.focus(media.frame.size)
        
        self.media.isPlayable = !isLite(.emoji)
        self.media.frame = mediaRect
        self.layer?.addSublayer(media)
                
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard let media = self.media else {
            return
        }
        media.frame = focus(media.frame.size)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


