//
//  VideoStickerContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 10/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import TGUIKit
import Postbox
import SwiftSignalKit
class VideoStickerContentView: ChatMediaContentView {
    
    private var player:GifPlayerBufferView
    private var placeholderView: StickerShimmerEffectView?
    
    private let fetchDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    
    override var backgroundColor: NSColor {
        set {
            super.backgroundColor = .clear
        }
        get {
            return super.backgroundColor
        }
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard let context = self.context, let window = self.kitWindow, let table = self.table else {return false}
        startModalPreviewHandle(table, window: window, context: context)
        return true
    }
    
    required init(frame frameRect: NSRect) {
        player = GifPlayerBufferView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(player)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func clean() {
        playerDisposable.dispose()
        statusDisposable.dispose()
        removeNotificationListeners()
    }
    
    override func cancel() {
        fetchDisposable.set(nil)
    }
    
   
    
    override func fetch() {
        if let context = context, let media = media as? TelegramMediaFile {
            if let parent = parent {
                fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media)).start())
            } else {
                fetchDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: media)).start())
            }
        }
    }
    
    override func layout() {
        super.layout()
        player.frame = bounds

        self.player.positionFlags = positionFlags
        updatePlayerIfNeeded()
    }

    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }

    @objc func updatePlayerIfNeeded() {
         let accept = window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !self.isDynamicContentLocked
        player.ticking = accept
    }
    
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: table?.clipView)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.frameDidChangeNotification, object: table?.view)
        } else {
            removeNotificationListeners()
        }
    }
    
    override func willRemove() {
        super.willRemove()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    deinit {
        //player.set(data: nil)
    }
    
    var blurBackground: Bool {
        return (parent != nil && parent?.groupingKey == nil) || parent == nil
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        let mediaUpdated = self.media == nil || !self.media!.isSemanticallyEqual(to: media)
        
        
        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        

        var topLeftRadius: CGFloat = .cornerRadius
        var bottomLeftRadius: CGFloat = .cornerRadius
        var topRightRadius: CGFloat = .cornerRadius
        var bottomRightRadius: CGFloat = .cornerRadius
        
        
        if let positionFlags = positionFlags {
            if positionFlags.contains(.top) && positionFlags.contains(.left) {
                topLeftRadius = topLeftRadius * 3 + 2
            }
            if positionFlags.contains(.top) && positionFlags.contains(.right) {
                topRightRadius = topRightRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                bottomLeftRadius = bottomLeftRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                bottomRightRadius = bottomRightRadius * 3 + 2
            }
        }
        
        updateListeners()
        self.player.positionFlags = positionFlags

        if let media = media as? TelegramMediaFile {
            
            let dimensions = media.dimensions?.size ?? size
            
            let reference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: media) : FileMediaReference.standalone(media: media)
            let fitted = dimensions.aspectFilled(size)
            player.setVideoLayerGravity(.resizeAspect)
            
            let arguments = TransformImageArguments(corners: ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius)), imageSize: fitted, boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: .blurBackground)

            player.update(reference, context: context, resizeInChat: blurBackground)
            
            if !player.isRendering {
                
                let hasPlaceholder = (parent == nil || media.immediateThumbnailData != nil) && self.player.image == nil
                
                if hasPlaceholder {
                    let current: StickerShimmerEffectView
                    if let local = self.placeholderView {
                        current = local
                    } else {
                        current = StickerShimmerEffectView()
                        current.frame = bounds
                        self.placeholderView = current
                        addSubview(current, positioned: .below, relativeTo: player)
                        if animated {
                            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        }
                    }
                    current.update(backgroundColor: nil, foregroundColor: NSColor(rgb: 0x748391, alpha: 0.2), shimmeringColor: NSColor(rgb: 0x748391, alpha: 0.35), data: media.immediateThumbnailData, size: size)
                    current.updateAbsoluteRect(bounds, within: size)
                } else {
                    self.removePlaceholder(animated: animated)
                }
                
                self.player.imageUpdated = { [weak self] value in
                    if value != nil {
                        self?.removePlaceholder(animated: animated)
                    }
                }
                
                player.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor, positionFlags: positionFlags), clearInstantly: mediaUpdated)
                
                let signal = chatMessageSticker(postbox: context.account.postbox, file: reference, small: size.width < 120, scale: backingScaleFactor)
                
                player.setSignal(signal, animate: animated, cacheImage: { [weak media] result in
                    if let media = media {
                        cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: positionFlags)
                    }
                })
                player.set(arguments: arguments)
            } else {
                self.removePlaceholder(animated: animated)
            }
            
        }
        
    }
    
    private func removePlaceholder(animated: Bool) {
        if let view = self.placeholderView {
            performSubviewRemoval(view, animated: animated)
            self.placeholderView = nil
        }
    }
    
    
    override var contents: Any? {
        return player.layer?.contents
    }
    
    override open func copy() -> Any {
        return player.copy()
    }
    
}
