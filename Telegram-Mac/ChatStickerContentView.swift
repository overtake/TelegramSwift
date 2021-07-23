//
//  ChatStickerContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 20/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox
class ChatStickerContentView: ChatMediaContentView {
    private let statusDisposable = MetaDisposable()
    private var image:TransformImageView = TransformImageView()
    private var placeholderView: StickerShimmerEffectView?
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        statusDisposable.dispose()
    }
    
    
    override func clean() {
        statusDisposable.set(nil)
    }
    
    override var backgroundColor: NSColor {
        didSet {
           
        }
    }
    
    override func previewMediaIfPossible() -> Bool {
        if let table = table, let context = context, let window = window as? Window {
            _ = startModalPreviewHandle(table, window: window, context: context)
        }
        return true
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        self.addSubview(image)
       
    }
    
    override func executeInteraction(_ isControl: Bool) {
        if let window = window as? Window {
            if let context = context, let peerId = parent?.id.peerId, let media = media as? TelegramMediaFile, let reference = media.stickerReference {
                
                showModal(with:StickerPackPreviewModalController(context, peerId: peerId, reference: reference), for:window)
            }
        }
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
      
        let previous = self.parent
        
        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        if let file = media as? TelegramMediaFile {
            
            let reference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : stickerPackFileReference(file)
            
            let dimensions =  file.dimensions?.size.aspectFitted(size) ?? size
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
            
            self.image.animatesAlphaOnFirstTransition = false
           
            
            self.image.setSignal(signal: cachedMedia(media: reference.media, arguments: arguments, scale: backingScaleFactor), clearInstantly: parent?.stableId != previous?.stableId)
            
            let hasPlaceholder = (parent == nil || file.immediateThumbnailData != nil) && self.image.image == nil
            
            if hasPlaceholder {
                let current: StickerShimmerEffectView
                if let local = self.placeholderView {
                    current = local
                } else {
                    current = StickerShimmerEffectView()
                    current.frame = bounds
                    self.placeholderView = current
                    addSubview(current, positioned: .below, relativeTo: image)
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                current.update(backgroundColor: nil, foregroundColor: NSColor(rgb: 0x748391, alpha: 0.2), shimmeringColor: NSColor(rgb: 0x748391, alpha: 0.35), data: file.immediateThumbnailData, size: size)
                current.updateAbsoluteRect(bounds, within: size)
            } else {
                self.removePlaceholder(animated: animated)
            }
            
            self.image.imageUpdated = { [weak self] value in
                if value != nil {
                    self?.removePlaceholder(animated: animated)
                }
            }
            
            
            if !self.image.isFullyLoaded {
                self.image.setSignal( chatMessageSticker(postbox: context.account.postbox, file: reference, small: size.width < 120, scale: backingScaleFactor, fetched: true), cacheImage: { [weak file] result in
                    if let media = file {
                        return cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
                    }
                })
                self.image.set(arguments: arguments)
            } else {
                self.image.dispose()
            }
            
            self.image.setFrameSize(dimensions)
            self.image.center()
            self.fetchStatus = .Local
            
            let signal = context.account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue
            
            statusDisposable.set(signal.start(next: { [weak self] status in
                self?.fetchStatus = status
            }))
        }
        
    }
    
    private func removePlaceholder(animated: Bool) {
        if let placeholderView = self.placeholderView {
            if animated {
                placeholderView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak placeholderView] _ in
                    placeholderView?.removeFromSuperview()
                })
            } else {
                placeholderView.removeFromSuperview()
            }
            self.placeholderView = nil
        }
    }
    
    override func layout() {
        super.layout()
        self.image.center()
        self.placeholderView?.frame = bounds
    }
    

    override var contents: Any? {
        return self.image.layer?.contents
    }
}
