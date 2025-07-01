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
import Accelerate
import AppKit
import TelegramMedia

class InlineStickerLockLayer : SimpleLayer {
    private let lockedView: SimpleLayer = SimpleLayer()
    private let disposable = MetaDisposable()
    override init(frame frameRect: NSRect) {
        super.init()
        self.frame = frameRect
        addSublayer(lockedView)
        
        lockedView.contents = theme.icons.premium_lock
        let lockSize = theme.icons.premium_lock.backingSize
        lockedView.frame = frameRect.focus(NSMakeSize(lockSize.width * 0.7, lockSize.height * 0.7))
        self.cornerRadius = frameRect.height / 2
        self.masksToBounds = true
    }
    
    func updateImage(_ image: CGImage) {
        lockedView.contents = image
    }
    
    func tieToLayer(_ layer: InlineStickerItemLayer) {
        layer.contentDidUpdate = { [weak self] image in
            self?.applyBlur(color: theme.colors.background.darker(), image: image)
        }
    }
    
    func applyBlur(color: NSColor?, image: CGImage) {
        
        let signal: Signal<CGImage?, NoError> = Signal { subscriber in
            let blurredWidth = 12
            let blurredHeight = 12
            let context = DrawingContext(size: CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight)), scale: 1.0)
            let size = CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight))


            context.withContext { c in
                c.setFillColor((color ?? NSColor(0xffffff)).cgColor)
                c.fill(CGRect(origin: CGPoint(), size: size))
                
                let rect = CGRect(origin: CGPoint(x: -size.width / 2.0, y: -size.height / 2.0), size: CGSize(width: size.width * 1.8, height: size.height * 1.8))
                c.draw(image, in: rect)
            }
                        
            var destinationBuffer = vImage_Buffer()
            destinationBuffer.width = UInt(blurredWidth)
            destinationBuffer.height = UInt(blurredHeight)
            destinationBuffer.data = context.bytes
            destinationBuffer.rowBytes = context.bytesPerRow
            
            vImageBoxConvolve_ARGB8888(&destinationBuffer,
                                       &destinationBuffer,
                                       nil,
                                       0, 0,
                                       UInt32(15),
                                       UInt32(15),
                                       nil,
                                       vImage_Flags(kvImageTruncateKernel))
            
            let divisor: Int32 = 0x1000

            let rwgt: CGFloat = 0.3086
            let gwgt: CGFloat = 0.6094
            let bwgt: CGFloat = 0.0820

            let adjustSaturation: CGFloat = 1.7

            let a = (1.0 - adjustSaturation) * rwgt + adjustSaturation
            let b = (1.0 - adjustSaturation) * rwgt
            let c = (1.0 - adjustSaturation) * rwgt
            let d = (1.0 - adjustSaturation) * gwgt
            let e = (1.0 - adjustSaturation) * gwgt + adjustSaturation
            let f = (1.0 - adjustSaturation) * gwgt
            let g = (1.0 - adjustSaturation) * bwgt
            let h = (1.0 - adjustSaturation) * bwgt
            let i = (1.0 - adjustSaturation) * bwgt + adjustSaturation

            let satMatrix: [CGFloat] = [
                a, b, c, 0,
                d, e, f, 0,
                g, h, i, 0,
                0, 0, 0, 1
            ]

            var matrix: [Int16] = satMatrix.map { value in
                return Int16(value * CGFloat(divisor))
            }

            vImageMatrixMultiply_ARGB8888(&destinationBuffer, &destinationBuffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
            
            context.withFlippedContext { c in
                c.setFillColor((color ?? NSColor(0xffffff)).withMultipliedAlpha(0.6).cgColor)
                c.fill(CGRect(origin: CGPoint(), size: size))
            }
            
            subscriber.putNext(context.generateImage())
            return ActionDisposable {
                
            }
        }
        |> runOn(.concurrentBackgroundQueue())
        |> deliverOnMainQueue
        |> delay(self.contents != nil ? 0.1 : 0, queue: .concurrentBackgroundQueue())
        
        disposable.set(signal.start(next: { [weak self] image in
            self?.contents = image
        }))

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}



private final class MultiTargetAnimationContext {
    private var context: AnimationPlayerContext!
    private var handlers:[Int: Handlers] = [:]
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
    
    func jump(to frame: Int32) -> Void {
        context.jump(to: frame)
    }
    func setColors(_ colors: [LottieColor]) {
        context.setColors(colors)
    }
    
    init(_ animation: LottieAnimation, handlers: Handlers, token: inout Int) {
        
        token = self.add(handlers)
        
        let handlers:()->[Int: Handlers] = { [weak self] in
            return self?.handlers ?? [:]
        }
        
        self.context = .init(animation, displayFrame: { frame, loop in
            let image = frame.image
            DispatchQueue.main.async {
                for (_, target) in handlers() {
                    target.displayFrame(image)
                }
            }
            
        }, release: {
            DispatchQueue.main.async {
                for (_, target) in handlers() {
                    target.release()
                }
            }
        }, updateState: { state in
            DispatchQueue.main.async {
                for (_, target) in handlers() {
                    target.updateState(state)
                }
            }
        })
    }
    
    deinit {
       var bp = 0
        bp += 1
    }
    
    func add(_ handlers: Handlers) -> Int {
        let token = Int.random(in: 0..<Int.max)
        self.handlers[token] = handlers
        return token
    }
    func remove(_ token: Int) -> Bool {
        self.handlers.removeValue(forKey: token)
        return self.handlers.isEmpty
    }
    
    func playAgain() {
        self.context.playAgain()
    }
}



private final class MultiTargetContextCache {
    
    struct Key : Hashable {
        let key: LottieAnimationEntryKey
        let unique: Int
    }
    
    private static var cache: [Key : MultiTargetAnimationContext] = [:]
    

    static func create(_ animation: LottieAnimation, key: Key, displayFrame: @escaping(CGImage?)->Void, release:@escaping()->Void, updateState: @escaping(LottiePlayerState)->Void) -> Int {
        
        assertOnMainThread()
        
        let handlers: MultiTargetAnimationContext.Handlers = .init(displayFrame: displayFrame, release: release, updateState: updateState)
        
        if let context = cache[key] {
            return context.add(handlers)
        }
        var token: Int = 0
        let context = MultiTargetAnimationContext(animation, handlers: handlers, token: &token)
        
        cache[key] = context
        
        return token
    }
    
    static func exists(_ key: Key) -> Bool {
        return cache[key] != nil
    }
    static func find(_ key: Key) -> MultiTargetAnimationContext? {
        return cache[key]
    }
    
    static func remove(_ token: Int, for key: Key) {
        let context = self.cache[key]
        if let context = context {
            let isEmpty = context.remove(token)
            if isEmpty {
                self.cache.removeValue(forKey: key)
            }
        }
    }
}

final class InlineStickerView: Control {
    private let isPlayable: Bool
    let controlContent: Bool
    let animateLayer: InlineStickerItemLayer
    init(account: Account, inlinePacksContext: InlineStickersContext?, emoji: ChatTextCustomEmojiAttribute, size: NSSize, getColors:((TelegramMediaFile)->[LottieColor])? = nil, shimmerColor: InlineStickerItemLayer.Shimmer = .init(circle: false), isPlayable: Bool = true, playPolicy: LottiePlayPolicy = .loop, controlContent: Bool = true) {
        let layer = InlineStickerItemLayer(account: account, inlinePacksContext: inlinePacksContext, emoji: emoji, size: size, playPolicy: playPolicy, getColors: getColors, shimmerColor: shimmerColor)
        self.isPlayable = isPlayable
        self.animateLayer = layer
        self.controlContent = controlContent
        super.init(frame: size.bounds)
        self.layer?.addSublayer(layer)
        layer.superview = self
        userInteractionEnabled = false
    }
    init(account: Account, file: TelegramMediaFile, size: NSSize, getColors:((TelegramMediaFile)->[LottieColor])? = nil, shimmerColor: InlineStickerItemLayer.Shimmer = .init(circle: false), isPlayable: Bool = true, playPolicy: LottiePlayPolicy = .loop, controlContent: Bool = true, ignorePreview: Bool = false, synchronyous: Bool = false) {
        let layer = InlineStickerItemLayer(account: account, file: file, size: size, playPolicy: playPolicy, getColors: getColors, shimmerColor: shimmerColor, ignorePreview: ignorePreview, synchronyous: synchronyous)
        layer.isPlayable = isPlayable
        self.isPlayable = isPlayable
        self.animateLayer = layer
        self.controlContent = controlContent
        super.init(frame: size.bounds)
        self.layer?.addSublayer(layer)
        layer.superview = self
        userInteractionEnabled = false
    }
    
    
    @objc func updateAnimatableContent() -> Void {
        if controlContent {
            var isKeyWindow: Bool = false
            if let window = window {
                if !window.canBecomeKey {
                    isKeyWindow = true
                } else {
                    isKeyWindow = window.isKeyWindow
                }
            }
            animateLayer.isPlayable = isKeyWindow && isPlayable && self.visibleRect != .zero
        }
    }
    
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateListeners() {
        let center = NotificationCenter.default
        if let window = window {
            center.removeObserver(self)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
        } else {
            center.removeObserver(self)
        }
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}


final class InlineStickerItemLayer : SimpleLayer {
    
    override init(layer: Any) {
        let layer = layer as! InlineStickerItemLayer
        self.aspectFilled = layer.aspectFilled
        self.account = layer.account
        self.playPolicy = layer.playPolicy
        self.getColors = layer.getColors
        self.textColor = layer.textColor
        self.shimmerColor = layer.shimmerColor
        self.fileId = layer.fileId
        self.size = layer.size
        self.ignorePreview = layer.ignorePreview
        self.synchronyous = layer.synchronyous
        self.color = nil
        self.isSelected = layer.isSelected
        self.uniqueStarAnimation = layer.uniqueStarAnimation
        super.init()
    }
    
    struct Key: Hashable {
        var id: Int64
        var index: Int
        var color: NSColor? = nil
    }
    private let account: Account
    private var infoDisposable: Disposable?
    
    weak var superview: NSView?
    
    private let fetchDisposable = MetaDisposable()
    private let resourceDisposable = MetaDisposable()
    private let shimmerDataDisposable = MetaDisposable()
    private var previewDisposable: Disposable?
    private let delayDisposable = MetaDisposable()
    
    
    private(set) var file: TelegramMediaFile? {
        didSet {
            self.fileDidUpdate?(file)
        }
    }
    let fileId: Int64
    
    var fileDidUpdate:((TelegramMediaFile?)->Void)?
    
    private var preview: CGImage?
    
    private var shimmer: ShimmerLayer?
    
    private let aspectFilled: Bool
    var contentDidUpdate:((CGImage)->Void)? = nil
    
    override var contents: Any? {
        didSet {
            if let image = contents {
                self.contentDidUpdate?(image as! CGImage)
            }
        }
    }
    
    private var getColors:((TelegramMediaFile)->[LottieColor])?
    
    struct Shimmer {
        let color: NSColor
        let circle: Bool
        init(color:NSColor = NSColor(0x748391), circle: Bool) {
            self.color = color
            self.circle = circle
        }
    }
    private let shimmerColor: Shimmer
    let textColor: NSColor
    let size: NSSize
    let synchronyous: Bool
    let color: NSColor?
    let isSelected: Bool
    let uniqueStarAnimation: NSColor?
    
    init(account: Account, inlinePacksContext: InlineStickersContext?, emoji: ChatTextCustomEmojiAttribute, size: NSSize, playPolicy: LottiePlayPolicy = .loop, checkStatus: Bool = false, aspectFilled: Bool = false, getColors:((TelegramMediaFile)->[LottieColor])? = nil, shimmerColor: Shimmer = Shimmer(circle: false), textColor: NSColor = theme.colors.accent, ignorePreview: Bool = false, synchronyous: Bool = false, isSelected: Bool = false, uniqueStarAnimation: NSColor? = nil) {
        self.aspectFilled = aspectFilled
        self.account = account
        self.playPolicy = playPolicy
        self.getColors = getColors
        self.textColor = textColor
        self.uniqueStarAnimation = uniqueStarAnimation
        self.shimmerColor = shimmerColor
        self.fileId = emoji.fileId
        self.size = size
        self.color = emoji.color
        self.ignorePreview = ignorePreview
        self.isSelected = isSelected
        self.synchronyous = synchronyous
        super.init()
        self.frame = size.bounds
        self.initialize()
        
        let signal: Signal<TelegramMediaFile?, NoError>
        if let file = emoji.file {
            signal = .single(file)
        } else {
            if let inlinePacksContext = inlinePacksContext {
                signal = inlinePacksContext.load(fileId: emoji.fileId, checkStatus: checkStatus)
                |> deliverOnMainQueue
            } else {
                signal = TelegramEngine(account: account).stickers.resolveInlineStickers(fileIds: [emoji.fileId])
                |> map { $0.values.first }
                |> deliverOnMainQueue
            }
        }
        
        self.infoDisposable = signal.start(next: { [weak self] file in
            self?.file = file
            self?.updateSize(size: size, sync: self?.synchronyous == true)
        })
    }
    
    init(account: Account, file: TelegramMediaFile, size: NSSize, playPolicy: LottiePlayPolicy = .loop, aspectFilled: Bool = false, getColors:((TelegramMediaFile)->[LottieColor])? = nil, shimmerColor: Shimmer = Shimmer(circle: false), textColor: NSColor = theme.colors.accent, ignorePreview: Bool = false, synchronyous: Bool = false, isSelected: Bool = false, uniqueStarAnimation: NSColor? = nil) {
        self.aspectFilled = aspectFilled
        self.account = account
        self.playPolicy = playPolicy
        self.getColors = getColors
        self.textColor = textColor
        self.shimmerColor = shimmerColor
        self.fileId = file.fileId.id
        self.size = size
        self.ignorePreview = ignorePreview
        self.synchronyous = synchronyous
        self.color = nil
        self.isSelected = isSelected
        self.uniqueStarAnimation = uniqueStarAnimation
        super.init()
        self.frame = size.bounds
        self.initialize()
        self.file = file
        self.updateSize(size: size, sync: synchronyous)
        
    }

    
    private func initialize() {
        if playPolicy != .loop {
            unique = Int(arc4random64())
        }
        let textColor = self.textColor
        let color = self.color
        if self.getColors == nil {
            self.getColors = { file in
                var colors: [LottieColor] = []
                if isDefaultStatusesPackId(file.emojiReference) {
                    colors.append(.init(keyPath: "", color: theme.colors.accent))
                }
                if file.paintToText {
                    colors.append(.init(keyPath: "", color: textColor))
                }
                if let color {
                    colors.append(.init(keyPath: "", color: color))
                }
                return colors
            }
        }
        self.contentsGravity = .center
        self.masksToBounds = false
        self.isOpaque = true
        self.contentsScale = System.backingScale
    }
    
    override var masksToBounds: Bool {
        set {

        }
        get {
            return false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var animation: LottieAnimation?
    private(set) var playerState: LottiePlayerState? {
        didSet {
            if let value = playerState {
                self.triggerNextState?(value)
                self.triggerNextState = nil
                
                if let triggerOnState = triggerOnState, value == triggerOnState.0 {
                    triggerOnState.1(value)
                    self.triggerOnState = nil
                }
            }
        }
    }
    private let playPolicy: LottiePlayPolicy
    
    var triggerNextState: ((LottiePlayerState)->Void)? = nil
    var triggerOnState: (LottiePlayerState, (LottiePlayerState)->Void)? = nil

    
    private var unique: Int = 0
    var stopped: Bool = false
    var ignorePreview: Bool = false
    
    func reset() -> Void {
        if let contextToken = contextToken {
            MultiTargetContextCache.remove(contextToken.0, for: contextToken.1)
        }
        self.contents = nil
        self.contextToken = nil
        self.updateState(.stoped)
        self.delayDisposable.set(nil)
        unique = Int(arc4random64())
    }
    
    func apply() {
        self.set(self.animation, force: true)
    }
    
    var isPlayable: Bool? = nil {
        didSet {
            if oldValue != isPlayable {
                self.set(self.animation?.withUpdatedPolicy(self.playPolicy))
            }
        }
    }
    
    func playAgain() {
        if let key = self.contextToken {
            if let context = MultiTargetContextCache.find(key.1) {
                context.playAgain()
            }
        }
    }
    
    private var isPreviousPreview: Bool = false
    
    var noDelayBeforeplay = false
    
    private var contextToken: (Int, MultiTargetContextCache.Key)?
    private func set(_ animation: LottieAnimation?, force: Bool = false) {
        self.animation = animation
        if let animation = animation, let isPlayable = self.isPlayable, isPlayable, !stopped {
            weak var layer: InlineStickerItemLayer? = self
            let key: MultiTargetContextCache.Key = .init(key: animation.key, unique: unique)
            
            delayDisposable.set(delaySignal(MultiTargetContextCache.exists(key) || force || noDelayBeforeplay ? 0 : 0.1).start(completed: { [weak self] in

                self?.contextToken = (MultiTargetContextCache.create(animation, key: key, displayFrame: { image in
                    layer?.contents = image
                    if layer?.isPreviousPreview == true {
                        layer?.animateContents()
                        layer?.isPreviousPreview = false
                    }
                    if self?.superview?.window == nil {
                        DispatchQueue.main.async {
                            self?.set(nil, force: true)
                        }
                    }
                }, release: {

                }, updateState: { [weak self] state in
                    self?.updateState(state)
                }), key)
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
        
        if state != .playing, let preview = self.preview, !ignorePreview {
            self.contents = preview
        }
        if state == .playing {
            if let shimmer = shimmer {
                shimmer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmer] _ in
                    shimmer?.removeFromSuperlayer()
                })
                self.shimmer = nil
            }
        } else if state == .finished, case .playCount = self.playPolicy {
            stopped = true
        }
    }
    
    func jump(to frame: Int32) -> Void {
        var initWithFrame: Bool = true
        if let key = self.contextToken {
            if let context = MultiTargetContextCache.find(key.1) {
                context.jump(to: frame)
                initWithFrame = false
            }
        }
    }
    
    func setColors(_ colors: [LottieColor]) {
        if let key = self.contextToken {
            MultiTargetContextCache.find(key.1)?.setColors(colors)
        }
    }
    
    func updateSize(size: NSSize, sync: Bool) {
        
        shimmerDataDisposable.set(nil)
        
        if let file = self.file {
            let synchronyous = self.synchronyous
            let playPolicy = self.playPolicy

            let aspectSize: NSSize
            let dimensionSize: NSSize
            if aspectFilled {
                aspectSize = file.dimensions?.size.aspectFilled(size) ?? size
            } else {
                aspectSize = file.dimensions?.size.aspectFitted(size) ?? size
            }
            dimensionSize = file.dimensions?.size ?? size
            let reference: FileMediaReference
            let mediaResource: MediaResourceReference
            if let stickerReference = file.stickerReference ?? file.emojiReference {
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
            
//            if file.isAnimatedSticker || file.isVideoSticker {
//                fetchDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.account, userLocation: .other, fileReference: reference, resource: reference.media.resource).start())
//            } else {
//                fetchDisposable.set(nil)
//            }
            
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
                data = account.postbox.mediaBox.resourceData(file.resource, attemptSynchronously: sync)
            }
            if file.isAnimatedSticker || file.isVideoSticker || (file.isCustomEmoji && (file.isSticker || file.isVideo)), playPolicy != .framesCount(1) {
                self.resourceDisposable.set((data |> map { resourceData -> Data? in
                    if resourceData.complete {
                        if file.isWebm {
                            return resourceData.path.data(using: .utf8)!
                        } else if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                            return data
                        }
                    }
                    return nil
                } |> deliverOnMainQueue).start(next: { [weak self] data in
                    if let data = data {
                        let maximumFps: Int = 30
                        var cache: ASCachePurpose = .temporaryLZ4(.effect)
                        let colors = self?.getColors?(file) ?? []
                        if !colors.isEmpty {
                            cache = .none
                        }
                        let type: LottieAnimationType
                        if file.isWebm {
                            type = .webm
                        } else if file.mimeType == "image/webp" {
                            type = .webp
                        } else {
                            type = .lottie
                        }
                        self?.set(LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .media(file.id), size: aspectSize, colors: colors), type: type, cachePurpose: cache, playPolicy: playPolicy, maximumFps: maximumFps, colors: colors, runOnQueue: synchronyous ? .mainQueue() : lottieStateQueue, metalSupport: false))
                        
                    } else {
                        self?.set(nil)
                    }
                }))
            } else {
                self.resourceDisposable.set(nil)
            }
            
            let shimmerColor = self.shimmerColor
            let fillColor: NSColor? = getColors?(file).first?.color
            let emptyColor: TransformImageEmptyColor?
            if let fillColor = fillColor {
                emptyColor = .fill(fillColor)
            } else {
                emptyColor = nil
            }
            
            if file.mimeType == "bundle/jpeg", let resource = file.resource as? LocalBundleResource {
                let image = NSImage(named: resource.name)?.precomposed(self.isSelected ? textColor : (resource.color ?? theme.colors.accentIcon), scale: System.backingScale)
                self.contents = image
                
                if resource.resize {
                    self.contentsGravity = .resizeAspect
                } else {
                    self.contentsGravity = .center
                }
            } else {
                self.contentsGravity = .center

                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: aspectSize, boundingSize: size, intrinsicInsets: NSEdgeInsets(), emptyColor: emptyColor)

                let fontSize = NSMakeSize(theme.fontSize + 8, theme.fontSize + 5)
                let fontAspectSize = file.dimensions?.size.aspectFitted(fontSize) ?? fontSize

                let fontArguments = TransformImageArguments(corners: ImageCorners(), imageSize: fontAspectSize, boundingSize: fontSize, intrinsicInsets: NSEdgeInsets(), emptyColor: emptyColor)

                
                let signal: Signal<ImageDataTransformation, NoError>

                switch file.mimeType {
                case "image/webp":
                    signal = chatMessageSticker(postbox: account.postbox, file: reference, small: aspectSize.width <= 5, scale: System.backingScale, fetched: true)
                case "bundle/topic":
                    if let resource = file.resource as? ForumTopicIconResource {
                        signal = makeTopicIcon(resource.title, bgColors: resource.bgColors, strokeColors: resource.strokeColors)
                    } else {
                        signal = .complete()
                    }
                default:
                    signal = chatMessageAnimatedSticker(postbox: account.postbox, file: reference, small: aspectSize.width <= 5, scale: System.backingScale, size: aspectSize, fetched: true, thumbAtFrame: 0, isVideo: file.fileName == "webm-preview" || file.isVideoSticker)
                }

                var result: TransformImageResult?
                _ = cachedMedia(media: file, arguments: arguments, scale: System.backingScale).start(next: { value in
                    result = value
                })
                if self.playerState != .playing {
                    self.contents = result?.image
                    if let image = result?.image {
                        self.contentDidUpdate?(image)
                        self.preview = image
                        self.isPreviousPreview = false
                    }
                }
               
                let ignore: Bool = file.mimeType.hasPrefix("bundle") || file.resource is LocalBundleResource
                
                if self.preview == nil, self.playerState != .playing, !ignore {
                    
                    let dataSignal = account.postbox.mediaBox.resourceData(mediaResource.resource)
                    |> map { $0.complete }
                    |> take(1)
                    |> deliverOnMainQueue
                    
                    shimmerDataDisposable.set(dataSignal.start(next: { [weak self] completed in
                        if !completed, self?.preview == nil, self?.playerState != .playing {
                            let current: ShimmerLayer
                            if let layer = self?.shimmer {
                                current = layer
                            } else {
                                current = ShimmerLayer()
                                self?.addSublayer(current)
                                self?.shimmer = current
                            }
                                                        
                            let data = !isLite(.animations) ? file.immediateThumbnailData : nil
                            
                            let shimmerSize = aspectSize
                            
                            current.update(backgroundColor: nil, foregroundColor: shimmerColor.color.withAlphaComponent(0.2), shimmeringColor: shimmerColor.color.withAlphaComponent(0.35), data: data, size: shimmerSize, imageSize: dimensionSize)
                            current.updateAbsoluteRect(size.bounds, within: shimmerSize)
                            
                            current.frame = size.bounds.focus(aspectSize)
                            
                            self?.isPreviousPreview = false

                        } else {
                            if let shimmer = self?.shimmer {
                                shimmer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmer] _ in
                                    shimmer?.removeFromSuperlayer()
                                })
                                self?.shimmer = nil
                            }
                        }
                    }))
                    
                    
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
                    let result = signal |> map { data -> (TransformImageResult, TransformImageResult) in
                        let context = data.execute(arguments, data.data)
                        let image = context?.generateImage()
                        let fontContext = data.execute(fontArguments, data.data)
                        let fontImage = fontContext?.generateImage()
                        return (TransformImageResult(image, context?.isHighQuality ?? false), TransformImageResult(fontImage, fontContext?.isHighQuality ?? false))
                    } |> deliverOnMainQueue

                    previewDisposable = result.start(next: { [weak self] result, fontResult in
                        if self?.playerState != .playing {
                            self?.contents = result.image
                        }
                        if self?.isPreviousPreview == true {
                            self?.animateContents()
                            self?.isPreviousPreview = false
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

                        cacheMedia(fontResult, media: file, arguments: fontArguments, scale: System.backingScale)
                        cacheMedia(result, media: file, arguments: arguments, scale: System.backingScale)
                    })
                }
            }
            
        }
    }
    
    deinit {
        fetchDisposable.dispose()
        infoDisposable?.dispose()
        previewDisposable?.dispose()
        resourceDisposable.dispose()
        delayDisposable.dispose()
        shimmerDataDisposable.dispose()
        if let contextToken = contextToken {
            MultiTargetContextCache.remove(contextToken.0, for: contextToken.1)
        }
    }
    

}
