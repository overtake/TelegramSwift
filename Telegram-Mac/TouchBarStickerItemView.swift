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
    private var animatedSticker:ChatMediaAnimatedStickerView?
    private var imageView: TransformImageView?
    private let fetchDisposable = MetaDisposable()
    private(set) var file: TelegramMediaFile?
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
//        let gesture = NSPressGestureRecognizer(target: self, action: #selector(pressGesture))
//        gesture.minimumPressDuration = 0.5
//        self.addGestureRecognizer(gesture)
    }
    
    var quickPreview: QuickPreviewMedia? {
        if let file = file {
            let reference = file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file) : FileMediaReference.standalone(media: file)
            if file.isAnimatedSticker {
                return .file(reference, AnimatedStickerPreviewModalView.self)
            } else {
                return .file(reference, StickerPreviewModalView.self)
            }
        }
        return nil
    }
    
    
    func update(context: AccountContext, file: TelegramMediaFile) {
        self.file = file
        if file.isAnimatedSticker {
            self.imageView?.removeFromSuperview()
            self.imageView = nil

            if self.animatedSticker == nil {
                self.animatedSticker = ChatMediaAnimatedStickerView(frame: NSZeroRect)
                addSubview(self.animatedSticker!)
            }
            guard let animatedSticker = self.animatedSticker else {
                return
            }
            animatedSticker.update(with: file, size: NSMakeSize(30, 30), context: context, parent: nil, table: nil, parameters: nil, animated: false, positionFlags: nil, approximateSynchronousValue: false)
        } else {
            self.animatedSticker?.removeFromSuperview()
            self.animatedSticker = nil
            if self.imageView == nil {
                self.imageView = TransformImageView()
                addSubview(self.imageView!)
            }
            guard let imageView = self.imageView else {
                return
            }
            let dimensions = file.dimensions ?? frame.size
            let imageSize = NSMakeSize(30, 30)
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFitted(imageSize), boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
            
            imageView.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor), clearInstantly: true)
            imageView.setSignal(chatMessageSticker(postbox: context.account.postbox, file: file, small: true, scale: backingScaleFactor, fetched: true), cacheImage: { result in
                cacheMedia(result, media: file, arguments: arguments, scale: System.backingScale)
            })
            imageView.set(arguments: arguments)
            imageView.setFrameSize(imageSize)
        }
       
     //   fetchDisposable.set(fileInteractiveFetched(account: account, fileReference: FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file)).start())
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
        
        imageView?.center()
        animatedSticker?.center()
    }
}
