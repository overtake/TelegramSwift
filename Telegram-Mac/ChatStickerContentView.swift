//
//  ChatStickerContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 20/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
class ChatStickerContentView: ChatMediaContentView {

    private var image:TransformImageView = TransformImageView()
    private let overlay: Control = Control()
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backgroundColor: NSColor {
        didSet {
            overlay.backgroundColor = .clear
        }
    }
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        self.addSubview(image)
        addSubview(overlay)
        
        overlay.set(handler: { [weak self] _ in
            guard let event = NSApp.currentEvent else {return}
            self?.mouseUp(with: event)
        }, for: .Click)
        
        
        struct EmptyProtocol : StickerPreviewProtocol {
            private weak var tableView: TableView?
            init(tableView: TableView?) {
                self.tableView = tableView
            }
            func stickerAtLocationInWindow(_ point: NSPoint) -> TelegramMediaFile? {
                if let tableView = tableView, let point = tableView.documentView?.convert(point, from: nil) {
                    let row = tableView.row(at: point)
                    if row >= 0, let view = tableView.item(at: row).view as? ChatMediaView {
                        if view.contentNode is ChatStickerContentView {
                            return view.contentNode?.media as? TelegramMediaFile
                        }
                    }
                }
                return nil
            }
        }
        
        overlay.set(handler: { [weak self] _ in
            guard let `self` = self, let account = self.account, let window = self.kitWindow else {return}
            _ = startStickerPreviewHandle(EmptyProtocol(tableView: self.table), window: window, account: account)
        }, for: .LongMouseDown)
    }
    
    override func executeInteraction(_ isControl: Bool) {
        if let window = window as? Window {
            if let account = account, let peerId = parent?.id.peerId, let media = media as? TelegramMediaFile, let reference = media.stickerReference {
                
                showModal(with:StickersPackPreviewModalController(account, peerId: peerId, reference: reference), for:window)
            }
        }
    }
    
    override func update(with media: Media, size: NSSize, account: Account, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: GroupLayoutPositionFlags? = nil) {
      
        let mediaUpdated = self.media == nil || !self.media!.isEqual(media)

        super.update(with: media, size: size, account: account, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        if let file = media as? TelegramMediaFile, mediaUpdated {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
            
            self.image.animatesAlphaOnFirstTransition = true
            
           
            self.image.setSignal(signal: cachedMedia(media: file, size: arguments.imageSize, scale: backingScaleFactor))
            
            if self.image.layer?.contents == nil {
                self.image.setSignal( chatMessageSticker(account: account, file: file, type: .chatMessage, scale: backingScaleFactor), cacheImage: { [weak self] signal in
                    if let strongSelf = self {
                        return cacheMedia(signal: signal, media: file, size: arguments.imageSize, scale: strongSelf.backingScaleFactor)
                    } else {
                        return .complete()
                    }
                })
            }
            
            self.image.set(arguments: arguments)
            self.image.setFrameSize(arguments.imageSize)
            overlay.setFrameSize(arguments.imageSize)
            _ = fileInteractiveFetched(account: account, file: file).start()
        }
        
    }
    

    
}
