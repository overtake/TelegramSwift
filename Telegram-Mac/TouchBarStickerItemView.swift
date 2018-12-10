//
//  TouchBarThumbailItemView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import TGUIKit



@available(OSX 10.12.2, *)
class TouchBarStickerItemView: NSScrubberItemView {
    
    private let imageView: TransformImageView = TransformImageView()
    private let fetchDisposable = MetaDisposable()
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        subviews = [imageView]
    }
    
    func update(account: Account, file: TelegramMediaFile) {
        let dimensions = file.dimensions ?? frame.size
        let imageSize = NSMakeSize(30, 30)
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFitted(imageSize), boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())

        imageView.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor), clearInstantly: true)
        imageView.setSignal(chatMessageSticker(account: account, fileReference: file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file) : FileMediaReference.standalone(media: file), type: .thumb, scale: backingScaleFactor), cacheImage: { [weak self] signal in
            if let strongSelf = self {
                return cacheMedia(signal: signal, media: file, arguments: arguments, scale: strongSelf.backingScaleFactor)
            } else {
                return .complete()
            }
        })
        imageView.set(arguments: arguments)
        imageView.setFrameSize(imageSize)
        fetchDisposable.set(fileInteractiveFetched(account: account, fileReference: FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file)).start())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
       // layer?.backgroundColor = NSColor.controlColor.cgColor
    }
    
    deinit {
        fetchDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
    }
}
