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
    
    private let media = MediaAnimatedStickerView(frame: .zero)
    private let disposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(media)
        
        media.backgroundColor = .clear
    }
    
    func set(_ attachment: TGTextAttachment, size: NSSize, context: AccountContext) -> Void {
        
        let reference = attachment.reference as! StickerPackReference
        let fileId = attachment.fileId as! Int64
        
        let signal: Signal<TelegramMediaFile?, NoError> = context.inlinePacksContext.stickerPack(reference: reference) |> map { files in
            return files.first(where: { $0.fileId.id == fileId })
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] file in
            if let file = file {
                let size = file.dimensions?.size.aspectFitted(size) ?? size
                self?.media.setFrameSize(size)
                self?.media.update(with: file, size: size, context: context, table: nil, animated: false)
            }
            self?.needsLayout = true
        }))
    }
    
    override func layout() {
        super.layout()
        self.media.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
