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
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
                
                showModal(with:StickersPackPreviewModalController(context, peerId: peerId, reference: reference), for:window)
            }
        }
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
      

        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        if let file = media as? TelegramMediaFile {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
            
            self.image.animatesAlphaOnFirstTransition = false
           
            self.image.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor), clearInstantly: false)
            self.image.setSignal( chatMessageSticker(account: context.account, fileReference: parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file), type: .chatMessage, scale: backingScaleFactor), cacheImage: { [weak self] signal in
                if let strongSelf = self {
                    return cacheMedia(signal: signal, media: file, arguments: arguments, scale: strongSelf.backingScaleFactor)
                } else {
                    return .complete()
                }
            })
            
            self.image.set(arguments: arguments)
            self.image.setFrameSize(arguments.imageSize)
            _ = fileInteractiveFetched(account: context.account, fileReference: parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)).start()
        }
        
    }
    

    
}
