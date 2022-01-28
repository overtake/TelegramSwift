//
//  StickerMediaContentView.swift
//  Telegram
//
//  Created by Mike Renoir on 21.01.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox


class StickerMediaContentView: ChatMediaContentView {
    private var content: ChatMediaContentView?
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
       
    }
    
    override func clean() {
        content?.clean()
    }
    
    override var backgroundColor: NSColor {
        didSet {
            content?.backgroundColor = backgroundColor
        }
    }
    
    override func mouseInside() -> Bool {
        return content?.mouseInside() ?? mouseInside()
    }
    
    override func previewMediaIfPossible() -> Bool {
        return content?.previewMediaIfPossible() ?? false
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
    }
    
    override func executeInteraction(_ isControl: Bool) {
        if let window = window as? Window {
            if let context = context, let peerId = parent?.id.peerId, let media = media as? TelegramMediaFile, !media.isEmojiAnimatedSticker, let reference = media.stickerReference {
                showModal(with:StickerPackPreviewModalController(context, peerId: peerId, reference: reference), for:window)
            } else if let media = media as? TelegramMediaFile, let sticker = media.stickerText, !sticker.isEmpty {
                self.playIfNeeded(true)
                parameters?.runEmojiScreenEffect(sticker)
            }
        }
    }
    
    override func playIfNeeded(_ playSound: Bool = false) {
        content?.playIfNeeded(playSound)
    }
    
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
              
        let previous = self.media
        
        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        let file = media as! TelegramMediaFile
        
        var contentClass: ChatMediaContentView.Type
        if file.isAnimatedSticker || (!file.isStaticSticker && file.mimeType == "image/webp") || file.isWebm {
            contentClass = MediaAnimatedStickerView.self
        } else if file.isVideoSticker {
            contentClass = VideoStickerContentView.self
        } else {
            contentClass = ChatStickerContentView.self
        }
        if content == nil || !content!.isKind(of: contentClass)  {
            if let view = self.content {
                performSubviewRemoval(view, animated: animated)
            }
            let content = contentClass.init(frame:size.bounds)
            self.content = content
            self.addSubview(content)
        }
        
        guard let content = self.content else {
            return
        }
        content.update(with: file, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
        
        content.userInteractionEnabled = false
    }
    
    
    override func layout() {
        super.layout()
        
    }
    
    override func copy() -> Any {
        return content?.copy() ?? super.copy()
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return content?.interactionContentView(for: innerId, animateIn: animateIn) ?? self
    }
    
    override func interactionControllerDidFinishAnimation(interactive: Bool) {
        content?.interactionControllerDidFinishAnimation(interactive: interactive)
    }
    
    override func videoTimebase() -> CMTimebase? {
        return content?.videoTimebase()
    }
    override func applyTimebase(timebase: CMTimebase?) {
        content?.applyTimebase(timebase: timebase)
    }
    
    override func addAccesoryOnCopiedView(view: NSView) {
        content?.addAccesoryOnCopiedView(view: view)
    }

    override var contents: Any? {
        return content?.contents
    }
    
    override func willRemove() -> Void {
        content?.willRemove()
    }
    
    override func cancel() -> Void {
        content?.cancel()
    }
    
    override func open() -> Void {
        content?.open()
    }
    
    override func fetch() -> Void {
        content?.fetch()
    }
    
    override func preloadStreamblePart() {
        content?.preloadStreamblePart()
    }
    
    override func updateMouse() {
        content?.updateMouse()
    }
}
