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
    
    private class LockView : NSVisualEffectView {
        private let lockedView: ImageView = ImageView()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(lockedView)
            
            wantsLayer = true
            self.blendingMode = .withinWindow
            self.state = .active
            self.material = .dark
            
            lockedView.image = theme.icons.premium_lock
            lockedView.sizeToFit()
            lockedView.setFrameSize(lockedView.frame.width * 0.7, lockedView.frame.height * 0.7)
            self.layer?.cornerRadius = frameRect.height / 2
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            lockedView.center()
        }
    }

    private var lockedView: LockView?
    
    private var content: ChatMediaContentView? {
        didSet {
            if isLocked {
                content?.layer?.opacity = 0.7
            } else {
                content?.layer?.opacity = 1.0
            }
        }
    }
    
    
    override var isHidden: Bool {
        didSet {
            if let content = content as? MediaAnimatedStickerView {
                content.updatePlayerIfNeeded()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
       
    }
    
    
    private var isLocked: Bool = false
    func set(locked: Bool, animated: Bool) {
        self.isLocked = locked
        if isLocked {
            content?.layer?.opacity = 0.7
        } else {
            content?.layer?.opacity = 1.0
        }
        if isLocked {
            let current: LockView
            if let view = self.lockedView {
                current = view
            } else {
                current = LockView(frame: NSMakeRect(0, 0, 17, 17))
                self.lockedView = current
                addSubview(current, positioned: .above, relativeTo: content)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        } else if let view = lockedView {
            performSubviewRemoval(view, animated: animated)
            self.lockedView = nil
        }
        
        needsLayout = true
    }
    
    func play() {
        if let content = content as? MediaAnimatedStickerView {
            content.play()
        }
    }
    
    var playOnHover: Bool? = nil {
        didSet {
            if let content = content as? MediaAnimatedStickerView {
                content.playOnHover = playOnHover
            }
        }
    }
    
    var overridePlayValue: Bool? = nil {
        didSet {
            if let content = content as? MediaAnimatedStickerView {
                content.overridePlayValue = overridePlayValue
            }
        }
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
        return content?.mouseInside() ?? super.mouseInside()
    }
    
    override func previewMediaIfPossible() -> Bool {
        return content?.previewMediaIfPossible() ?? false
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
    }
    
    override var canSpamClicks: Bool {
        return content?.canSpamClicks ?? super.canSpamClicks
    }
    
    private var suggestOpenPremiumPack: Bool = false
    
    override func executeInteraction(_ isControl: Bool) {
        if let window = window as? Window, let context = self.context, let media = media as? TelegramMediaFile, let peerId = parent?.id.peerId {
            
            if suggestOpenPremiumPack, let reference = media.stickerReference {
                
                let title: String?
                switch reference {
                case let .name(name):
                    title = name
                default:
                    title = nil
                }
                
                showModalText(for: context.window, text: strings().stickerPremiumClickInfo, title: title, callback: { _ in
                    showModal(with:StickerPackPreviewModalController(context, peerId: peerId, references: [.stickers(reference)]), for:window)
                })
                suggestOpenPremiumPack = false
            } else {
                if media.isPremiumSticker, !context.premiumIsBlocked {
                    if !suggestOpenPremiumPack {
                        suggestOpenPremiumPack = true
                    }
                }
            }
            
            if media.isPremiumSticker, !media.noPremium, !context.premiumIsBlocked, let parent = parent {
                self.playIfNeeded(true)
                parameters?.runPremiumScreenEffect(parent)
                return
            }
            
            if let reference = media.stickerReference, media.fileName != "telegram-animoji.tgs" {
                showModal(with:StickerPackPreviewModalController(context, peerId: peerId, references: [.stickers(reference)]), for: context.window)
            } else if let sticker = media.stickerText, !sticker.isEmpty {
                let signal = context.diceCache.animationEffect(for: sticker.emojiUnmodified) |> deliverOnMainQueue
                _ = signal.start(next: { [weak self] files in
                    if files.isEmpty || media.customEmojiText != nil {
                        if let reference = media.emojiReference {
                            showModal(with:StickerPackPreviewModalController(context, peerId: peerId, references: [.emoji(reference)]), for: context.window)
                        }
                    } else {
                        self?.parameters?.runEmojiScreenEffect(sticker)
                    }
                    self?.playIfNeeded(true)
                })
            }
        }
    }
    
    override func playIfNeeded(_ playSound: Bool = false) {
        content?.playIfNeeded(playSound)
    }
    
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        
        
        let prev = self.media as? TelegramMediaFile
        let prevParent = self.parent
        
        suggestOpenPremiumPack = false
                      
        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        self.fetchStatus = .Local
        
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
            self.addSubview(content, positioned: .below, relativeTo: lockedView)
        }
        
        guard let content = self.content else {
            return
        }
        if let content = content as? MediaAnimatedStickerView {
            content.playOnHover = playOnHover
        }
        
        let aspectSize = file.dimensions?.size.aspectFitted(size) ?? size

        content.update(with: file, size: aspectSize, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
        
        content.userInteractionEnabled = false
        
        if let prevParent = prevParent, let parent = parent {
            let prevSending = prevParent.flags.contains(.Sending) || prevParent.flags.contains(.Unsent)
            let sending = parent.flags.contains(.Sending) || parent.flags.contains(.Unsent)
            if prevSending && !sending, file.fileId == prev?.fileId {
                if file.isPremiumSticker, !file.noPremium {
                    parameters?.runPremiumScreenEffect(parent)
                }
            }
        }
    
        
        
        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        if let view = lockedView {
            view.centerX(y: frame.height - view.frame.height)
        }
        self.content?.center()
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
    
    override func fetch(userInitiated: Bool) -> Void {
        content?.fetch(userInitiated: true)
    }
    
    override func preloadStreamblePart() {
        content?.preloadStreamblePart()
    }
    
    override func updateMouse() {
        content?.updateMouse()
    }
}
