//
//  StickerPreviewModalController.swift
//  Telegram
//
//  Created by keepcoder on 02/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

class StickerPreviewModalView : View, ModalPreviewControllerView {
    fileprivate let imageView:TransformImageView = TransformImageView()
    fileprivate let textView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        textView.backgroundColor = .clear
        imageView.setFrameSize(100,100)
        self.background = .clear
    }
    
    override func layout() {
        super.layout()
        imageView.center()
        
    }
    
    func update(with reference: FileMediaReference, account:Account) -> Void {
        imageView.setSignal( chatMessageSticker(account: account, fileReference: reference, type: .full, scale: backingScaleFactor), clearInstantly: true, animate:true)
        let size = reference.media.dimensions?.aspectFitted(NSMakeSize(frame.size.width, frame.size.height - 100)) ?? frame.size
        imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets()))
        imageView.frame = NSMakeRect(0, frame.height - size.height, size.width, size.height)
        imageView.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.2)
        
        let layout = TextViewLayout(.initialize(string: reference.media.stickerText?.fixed, color: nil, font: .normal(30.0)))
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
        textView.centerX()
        
        textView.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.2)
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



class GifPreviewModalView : View, ModalPreviewControllerView {
    fileprivate var player:GIFContainerView = GIFContainerView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(player)
        player.setFrameSize(100,100)
        self.background = .clear
    }
    
    override func layout() {
        super.layout()
        player.center()
        
    }
    
    func update(with reference: FileMediaReference, account:Account) -> Void {
        
        
        let current = self.player
        current.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak current] completed in
            if completed {
                current?.removeFromSuperview()
            }
        })
        self.player = GIFContainerView()
        self.player.layer?.borderWidth = 0
        addSubview(self.player)
        let size = reference.media.dimensions?.aspectFitted(NSMakeSize(frame.size.width, frame.size.height - 40)) ?? frame.size
        
        player.update(with: reference.resourceReference(reference.media.resource), size: size, viewSize: size, file: reference.media, account: account, table: nil, iconSignal: chatMessageVideo(postbox: account.postbox, fileReference: reference, scale: backingScaleFactor))
        player.frame = NSMakeRect(0, frame.height - size.height, size.width, size.height)
        player.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
