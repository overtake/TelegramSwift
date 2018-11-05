//
//  GalleryTouchBarThumbItemView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

@available(OSX 10.12.2, *)
class GalleryTouchBarThumbItemView: NSScrubberItemView {
    fileprivate let imageView: TransformImageView = TransformImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    func update(_ item: MGalleryItem) {        
        var signal:Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        var size: NSSize?
        if let item = item as? MGalleryPhotoItem {
            signal = chatWebpageSnippetPhoto(account: item.account, imageReference: item.entry.imageReference(item.media), scale: backingScaleFactor, small: true, secureIdAccessContext: item.secureIdAccessContext)
            size = item.media.representations.first?.dimensions
        } else if let item = item as? MGalleryGIFItem {
            signal = chatMessageImageFile(account: item.account, fileReference: item.entry.fileReference(item.media), scale: backingScaleFactor)
            size = item.media.videoSize
        } else if let item = item as? MGalleryExternalVideoItem {
            signal = chatWebpageSnippetPhoto(account: item.account, imageReference: item.entry.imageReference(item.mediaImage), scale: backingScaleFactor, small: true, secureIdAccessContext: nil)
            size = item.mediaImage.representations.first?.dimensions
        } else if let item = item as? MGalleryVideoItem {
            signal = chatMessageImageFile(account: item.account, fileReference: item.entry.fileReference(item.media), scale: backingScaleFactor)
            size = item.media.videoSize
        } else if let item = item as? MGalleryPeerPhotoItem {
            signal = chatMessagePhotoThumbnail(account: item.account, imageReference: item.entry.imageReference(item.media), scale: backingScaleFactor)
            
            size = item.media.representations.first?.dimensions
        }
        item.fetch()
        
        if let signal = signal, let size = size {
            imageView.setSignal(signal)
            let arguments = TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize:size.aspectFilled(NSMakeSize(36, 30)), boundingSize: NSMakeSize(36, 30), intrinsicInsets: NSEdgeInsets())
            imageView.set(arguments: arguments)
        }
        imageView.setFrameSize(36, 30)
    }
    
    override func layout() {
        super.layout()
        imageView.center()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
