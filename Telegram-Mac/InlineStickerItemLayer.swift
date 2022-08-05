//
//  InlineStickerItemLayer.swift
//  Telegram
//
//  Created by Mike Renoir on 07.07.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import TGUIKit


private final class MultiTargetAnimationContext {
    private var context: AnimationPlayerContext!
    private let handlers:Atomic<[Int: Handlers]> = Atomic(value: [:])
    final class Handlers {
        let displayFrame:(CGImage?)->Void
        let release:()->Void
        let updateState:(LottiePlayerState)->Void
        init(displayFrame: @escaping(CGImage?)->Void, release:@escaping()->Void, updateState: @escaping(LottiePlayerState)->Void) {
            self.displayFrame = displayFrame
            self.release = release
            self.updateState = updateState
        }
    }
    
    init(_ animation: LottieAnimation, handlers: Handlers, token: inout Int) {
        
        token = self.add(handlers)
        
        let handlers = self.handlers
        
        self.context = .init(animation, displayFrame: { frame, loop in
            let image = frame.image
            handlers.with { handlers in
                for (_, target) in handlers {
                    target.displayFrame(image)
                }
            }
        }, release: {
            handlers.with { handlers in
                for (_, target) in handlers {
                    target.release()
                }
            }
        }, updateState: { state in
            handlers.with { handlers in
                for (_, target) in handlers {
                    target.updateState(state)
                }
            }
        })
    }
    
    deinit {
        _ = handlers.modify { _ in
            [:]
        }
    }
    
    func add(_ handlers: Handlers) -> Int {
        let token = Int.random(in: 0..<Int.max)
        _ = self.handlers.modify { value in
            var value = value
            value[token] = handlers
            return value
        }
        return token
    }
    func remove(_ token: Int) -> Bool {
        return handlers.modify { value in
            var value = value
            value.removeValue(forKey: token)
            return value
        }.isEmpty
    }
}

private final class MultiTargetContextCache {
    private static var cache: [LottieAnimationEntryKey : MultiTargetAnimationContext] = [:]
    

    static func create(_ animation: LottieAnimation, displayFrame: @escaping(CGImage?)->Void, release:@escaping()->Void, updateState: @escaping(LottiePlayerState)->Void) -> Int {
        
        assertOnMainThread()
        
        let handlers: MultiTargetAnimationContext.Handlers = .init(displayFrame: displayFrame, release: release, updateState: updateState)
        
        if let context = cache[animation.key] {
            return context.add(handlers)
        }
        var token: Int = 0
        let context = MultiTargetAnimationContext(animation, handlers: handlers, token: &token)
        
        cache[animation.key] = context
        
        return token
    }
    
    static func exists(_ animation: LottieAnimation) -> Bool {
        return cache[animation.key] != nil
    }
    
    static func remove(_ token: Int, for key: LottieAnimationEntryKey) {
        let context = self.cache[key]
        if let context = context {
            let isEmpty = context.remove(token)
            if isEmpty {
                self.cache.removeValue(forKey: key)
            }
        }
    }
}

final class InlineStickerItemLayer : SimpleLayer {
    struct Key: Hashable {
        var id: Int64
        var index: Int
    }
    private let context: AccountContext
    private var infoDisposable: Disposable?
    
    weak var superview: NSView?
    
    private let fetchDisposable = MetaDisposable()
    private let resourceDisposable = MetaDisposable()
    
    private var previewDisposable: Disposable?
    private let delayDisposable = MetaDisposable()
    
    
    private(set) var file: TelegramMediaFile?
    
    private var preview: CGImage?
    
    private var shimmer: ShimmerLayer?
    
    init(context: AccountContext, emoji: ChatTextCustomEmojiAttribute, size: NSSize) {
        self.context = context
        super.init()
        self.frame = size.bounds
        self.initialize()
        
        let signal: Signal<TelegramMediaFile?, NoError>
        if let file = emoji.file {
            signal = .single(file)
        } else {
            signal = context.inlinePacksContext.load(fileId: emoji.fileId) |> deliverOnMainQueue
        }
        
        self.infoDisposable = signal.start(next: { [weak self] file in
            self?.file = file
            self?.updateSize(size: size)
        })
    }
    
    init(context: AccountContext, file: TelegramMediaFile, size: NSSize) {
        self.context = context
        super.init()
        self.initialize()
        self.file = file
        self.updateSize(size: size)
        
    }

    
    private func initialize() {
        self.contentsGravity = .center
        self.isOpaque = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var animation: LottieAnimation?
    private var playerState: LottiePlayerState?
    var isPlayable: Bool? = nil {
        didSet {
            if oldValue != isPlayable {
                self.set(self.animation)
            }
        }
    }
    private var contextToken: (Int, LottieAnimationEntryKey)?
    private func set(_ animation: LottieAnimation?) {
        self.animation = animation
        if let animation = animation, let isPlayable = self.isPlayable, isPlayable {
            weak var layer: CALayer? = self
            var first: Bool = true
            delayDisposable.set(delaySignal(MultiTargetContextCache.exists(animation) ? 0 : 0.1).start(completed: { [weak self] in
                self?.contextToken = (MultiTargetContextCache.create(animation, displayFrame: { image in
                    DispatchQueue.main.async {
                        let animate = layer?.contents != nil && first
                        layer?.contents = image
                        if animate {
                            layer?.animateContents()
                        }
                        first = false
                    }
                }, release: {
                    
                }, updateState: { [weak self] state in
                    self?.updateState(state)
                }), animation.key)
                
                
            }))
        } else {
            if let contextToken = contextToken {
                MultiTargetContextCache.remove(contextToken.0, for: contextToken.1)
            }
            self.contextToken = nil
            self.updateState(.stoped)
            self.delayDisposable.set(nil)
        }
    }
    
    private func updateState(_ state: LottiePlayerState) {
        self.playerState = state
        
        if state != .playing, let preview = self.preview {
            self.contents = preview
        }
        if state == .playing {
            if let shimmer = shimmer {
                shimmer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmer] _ in
                    shimmer?.removeFromSuperlayer()
                })
                self.shimmer = nil
            }
        }
    }
    
    func updateSize(size: NSSize) {
        if let file = self.file {
            
           
            
                        
            let aspectSize = file.dimensions?.size.aspectFitted(size) ?? size
                                                
            let reference: FileMediaReference
            let mediaResource: MediaResourceReference
             if let stickerReference = file.stickerReference {
                if file.resource is CloudStickerPackThumbnailMediaResource {
                    reference = FileMediaReference.stickerPack(stickerPack: stickerReference, media: file)
                    mediaResource = MediaResourceReference.stickerPackThumbnail(stickerPack: stickerReference, resource: file.resource)
                } else {
                    reference = FileMediaReference.stickerPack(stickerPack: stickerReference, media: file)
                    mediaResource = reference.resourceReference(file.resource)
                }
            } else {
                reference = FileMediaReference.standalone(media: file)
                mediaResource = reference.resourceReference(file.resource)
            }
            
            let data: Signal<MediaResourceData, NoError>
            if let resource = file.resource as? LocalBundleResource {
                data = Signal { subscriber in
                    if let path = Bundle.main.path(forResource: resource.name, ofType: resource.ext), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                        subscriber.putNext(MediaResourceData(path: path, offset: 0, size: Int64(data.count), complete: true))
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                } |> runOn(resourcesQueue)
            } else {
                data = context.account.postbox.mediaBox.resourceData(file.resource, attemptSynchronously: false)
            }
            if file.isAnimatedSticker || file.isVideoSticker {
                self.resourceDisposable.set((data |> map { resourceData -> Data? in
                    if resourceData.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                        if file.isWebm {
                            return resourceData.path.data(using: .utf8)!
                        } else {
                            return data
                        }
                    }
                    return nil
                } |> deliverOnMainQueue).start(next: { [weak self] data in
                    if let data = data {
                        let playPolicy: LottiePlayPolicy = .loop
                        let maximumFps: Int = 30
                        let cache: ASCachePurpose = .temporaryLZ4(.effect)
                        let type: LottieAnimationType
                        if file.isWebm {
                            type = .webm
                        } else if file.mimeType == "image/webp" {
                            type = .webp
                        } else {
                            type = .lottie
                        }
                        self?.set(LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .media(file.id), size: aspectSize), type: type, cachePurpose: cache, playPolicy: playPolicy, maximumFps: maximumFps, metalSupport: false))
                        
                    } else {
                        self?.set(nil)
                    }
                }))
            } else {
                self.resourceDisposable.set(nil)
            }
            
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: mediaResource).start())
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: aspectSize, boundingSize: size, intrinsicInsets: NSEdgeInsets())

            
            let signal: Signal<ImageDataTransformation, NoError>
                
            switch file.mimeType {
            case "image/webp":
                signal = chatMessageSticker(postbox: context.account.postbox, file: reference, small: aspectSize.width <= 5, scale: System.backingScale, fetched: true)
            default:
                signal = chatMessageAnimatedSticker(postbox: context.account.postbox, file: reference, small: size.width <= 5, scale: System.backingScale, size: aspectSize, fetched: true, thumbAtFrame: 0, isVideo: file.fileName == "webm-preview" || file.isVideoSticker)
            }
            
            var result: TransformImageResult?
            _ = cachedMedia(media: file, arguments: arguments, scale: System.backingScale).start(next: { value in
                result = value
            })
            if self.playerState != .playing {
                self.contents = result?.image
                
                if let image = result?.image {
                    self.preview = image
                }
            }
            if self.preview == nil, let data = file.immediateThumbnailData, self.playerState != .playing {
                let current: ShimmerLayer
                if let layer = self.shimmer {
                    current = layer
                } else {
                    current = ShimmerLayer()
                    addSublayer(current)
                    self.shimmer = current
                    current.frame = size.bounds.focus(aspectSize)
                }
                current.update(backgroundColor: nil, foregroundColor: NSColor(rgb: 0x748391, alpha: 0.2), shimmeringColor: NSColor(rgb: 0x748391, alpha: 0.35), data: data, size: aspectSize)
                current.updateAbsoluteRect(size.bounds, within: aspectSize)
            } else {
                if let shimmer = shimmer {
                    shimmer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmer] _ in
                        shimmer?.removeFromSuperlayer()
                    })
                    self.shimmer = nil
                }
            }
            
            previewDisposable?.dispose()
            
            if result == nil || result?.highQuality == false {
                let result = signal |> map { data -> TransformImageResult in
                    let context = data.execute(arguments, data.data)
                    let image = context?.generateImage()
                    return TransformImageResult(image, context?.isHighQuality ?? false)
                } |> deliverOnMainQueue
                
                previewDisposable = result.start(next: { [weak self] result in
                    if self?.playerState != .playing {
                        let animate = self?.contents != nil
                        self?.contents = result.image
                        if animate {
                            self?.animateContents()
                        }
                    }
                    if let image = result.image {
                        self?.preview = image
                        if let shimmer = self?.shimmer {
                            shimmer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmer] _ in
                                shimmer?.removeFromSuperlayer()
                            })
                            self?.shimmer = nil
                        }
                    }
                    cacheMedia(result, media: file, arguments: arguments, scale: System.backingScale)
                })
            } 
        }
    }
    
    deinit {
        infoDisposable?.dispose()
        previewDisposable?.dispose()
        resourceDisposable.dispose()
        delayDisposable.dispose()
        
        if let contextToken = contextToken {
            MultiTargetContextCache.remove(contextToken.0, for: contextToken.1)
        }
    }
    

}
