//
//  StickerPreviewModalController.swift
//  Telegram
//
//  Created by keepcoder on 02/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

class StickerPreviewModalView : View, ModalPreviewControllerView {
    fileprivate let imageView:TransformImageView = TransformImageView()
    fileprivate let textView:TextView = TextView()
    private let fetchDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        textView.backgroundColor = .clear
        imageView.setFrameSize(100,100)
        self.background = .clear
    }
    
    deinit {
        fetchDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        imageView.center()
    }
    
    func update(with reference: QuickPreviewMedia, context: AccountContext, animated: Bool) -> Void {
        if let reference = reference.fileReference {
            
            let size = reference.media.dimensions?.size.aspectFitted(NSMakeSize(min(300, frame.size.width), min(300, frame.size.height))) ?? frame.size
            imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets()))
            imageView.frame = NSMakeRect(0, frame.height - size.height, size.width, size.height)
            if animated {
                imageView.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.2)
            }
            
            imageView.setSignal(chatMessageSticker(postbox: context.account.postbox, file: reference.media, small: false, scale: backingScaleFactor, fetched: true), clearInstantly: true, animate:true)
            
            let layout = TextViewLayout(.initialize(string: reference.media.stickerText?.fixed, color: nil, font: .normal(30.0)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            textView.centerX()
            if animated {
                textView.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.2)
            }
            
            needsLayout = true
        }
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
    
    func update(with reference: QuickPreviewMedia, context: AccountContext, animated: Bool) -> Void {
        if let reference = reference.fileReference {
            if animated {
                let current = self.player
                current.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak current] completed in
                    if completed {
                        current?.removeFromSuperview()
                    }
                })
            } else {
                self.player.removeFromSuperview()
            }
           
            self.player = GIFContainerView()
            self.player.layer?.borderWidth = 0
            self.player.layer?.cornerRadius = .cornerRadius
            addSubview(self.player)
            let size = reference.media.dimensions?.size.aspectFitted(NSMakeSize(frame.size.width, frame.size.height - 40)) ?? frame.size
            
            player.update(with: reference.resourceReference(reference.media.resource), size: size, viewSize: size, file: reference.media, context: context, table: nil, iconSignal: chatMessageVideo(postbox: context.account.postbox, fileReference: reference, scale: backingScaleFactor))
            player.frame = NSMakeRect(0, frame.height - size.height, size.width, size.height)
            if animated {
                player.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            needsLayout = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ImagePreviewModalView : View, ModalPreviewControllerView {
    fileprivate var imageView:TransformImageView = TransformImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        self.background = .clear
    }
    
    override func layout() {
        super.layout()
        imageView.center()
    }
    
    func update(with reference: QuickPreviewMedia, context: AccountContext, animated: Bool) -> Void {
        if let reference = reference.imageReference {
            let current = self.imageView
            if animated {
                current.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak current] completed in
                    if completed {
                        current?.removeFromSuperview()
                    }
                })
            } else {
                current.removeFromSuperview()
            }
            
            self.imageView = TransformImageView()
            self.imageView.layer?.borderWidth = 0
            addSubview(self.imageView)
            
            let size = frame.size
            
            let dimensions = largestImageRepresentation(reference.media.representations)?.dimensions.size ?? size

            let arguments = TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: dimensions.fitted(size), boundingSize: dimensions.fitted(size), intrinsicInsets: NSEdgeInsets(), resizeMode: .none)
            
            self.imageView.setSignal(signal: cachedMedia(media: reference.media, arguments: arguments, scale: backingScaleFactor, positionFlags: nil), clearInstantly: false)
            
            let updateImageSignal = chatMessagePhoto(account: context.account, imageReference: reference, scale: backingScaleFactor, synchronousLoad: true)
            self.imageView.setSignal(updateImageSignal, animate: false)
            self.imageView.set(arguments: arguments)
            
            imageView.setFrameSize(arguments.imageSize)
            if animated {
                imageView.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.2)
            }
            needsLayout = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



class AnimatedStickerPreviewModalView : View, ModalPreviewControllerView {
    private let loadResourceDisposable = MetaDisposable()
    fileprivate let textView:TextView = TextView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.background = .clear
        
        addSubview(textView)
        textView.backgroundColor = .clear
    }
    private var player: LottiePlayerView?
    
    override func layout() {
        super.layout()
        //player.center()
    }
    
    override func viewDidMoveToWindow() {
        if window == nil {
            player?.set(nil)
            player = nil
        }
    }
    
    deinit {
        self.loadResourceDisposable.dispose()
        var bp:Int = 0
        bp += 1
    }
    
    func update(with reference: QuickPreviewMedia, context: AccountContext, animated: Bool) -> Void {
        
        if let reference = reference.fileReference {
            self.player?.removeFromSuperview()
            self.player = nil
            
            let size = NSMakeSize(frame.width - 80, frame.height - 80)


            self.player = LottiePlayerView(frame: NSMakeRect(0, 0, size.width, size.height))
            addSubview(self.player!)
            self.player?.center()
            
            let mediaId = reference.media.id
            
            let data: Signal<MediaResourceData, NoError>
            if let resource = reference.media.resource as? LocalBundleResource {
                data = Signal { subscriber in
                    if let path = Bundle.main.path(forResource: resource.name, ofType: resource.ext), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                        subscriber.putNext(MediaResourceData(path: path, offset: 0, size: data.count, complete: true))
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }
            } else {
                data = context.account.postbox.mediaBox.resourceData(reference.media.resource, attemptSynchronously: true)
            }
            
            self.loadResourceDisposable.set((data |> map { resourceData -> Data? in
                
                if resourceData.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                    return data
                }
                return nil
            } |> deliverOnMainQueue).start(next: { [weak self] data in
                if let data = data {
                    self?.player?.set(LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .media(mediaId), size: size), cachePurpose: .none))
                } else {
                    self?.player?.set(nil)
                }
            }))

            if animated {
                player!.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            
            let layout = TextViewLayout(.initialize(string: reference.media.stickerText?.fixed, color: nil, font: .normal(30.0)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            textView.centerX()
            if animated {
                textView.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.2)
            }
            
        } else {
            var bp:Int = 0
            bp += 1
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
