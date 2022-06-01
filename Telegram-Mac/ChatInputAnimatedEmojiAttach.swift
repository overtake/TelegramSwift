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

final class ChatInputAnimatedEmojiAttach: View {
    
    private let media = MediaAnimatedStickerView(frame: .zero)
    private let disposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(media)
    }
    
    func set(_ mediaId: MediaId, size: NSSize, context: AccountContext) -> Void {
        let signal: Signal<StickerPackItem?, NoError> = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false) |> map { value in
            switch value {
            case let .result(_, items, _):
                return items.first(where: { $0.file.fileId == mediaId })
            default:
                return nil
            }
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] item in
            if let item = item {
                let size = item.file.dimensions?.size.aspectFitted(size) ?? size
                self?.media.setFrameSize(size)
                self?.media.update(with: item.file, size: size, context: context, table: nil, animated: false)
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
