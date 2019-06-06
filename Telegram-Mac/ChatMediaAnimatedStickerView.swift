//
//  ChatMediaAnimatedSticker.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac
import Lottie



private class AlphaFrameFilter: CIFilter {
    static var kernel: CIColorKernel? = {
        return CIColorKernel(source: """
kernel vec4 alphaFrame(__sample s, __sample m) {
  return vec4( s.rgb, m.r );
}
""")
    }()
    
    var inputImage: CIImage?
    var maskImage: CIImage?
    
    override var outputImage: CIImage? {
        let kernel = AlphaFrameFilter.kernel!
        guard let inputImage = inputImage, let maskImage = maskImage else {
            return nil
        }
        let args = [inputImage as AnyObject, maskImage as AnyObject]
        return kernel.apply(extent: inputImage.extent, arguments: args)
    }
}

private func createVideoComposition(for playerItem: AVPlayerItem) -> AVVideoComposition? {
    let videoSize = CGSize(width: playerItem.presentationSize.width, height: playerItem.presentationSize.height / 2.0)
    let composition = AVMutableVideoComposition(asset: playerItem.asset, applyingCIFiltersWithHandler: { request in
        let sourceRect = CGRect(origin: .zero, size: videoSize)
        let alphaRect = sourceRect.offsetBy(dx: 0, dy: sourceRect.height)
        let filter = AlphaFrameFilter()
        filter.inputImage = request.sourceImage.cropped(to: alphaRect)
            .transformed(by: CGAffineTransform(translationX: 0, y: -sourceRect.height))
        filter.maskImage = request.sourceImage.cropped(to: sourceRect)
        return request.finish(with: filter.outputImage!, context: nil)
    })
    composition.renderSize = videoSize
    return composition
}




private final class StickerAnimationView: View {
    private var account: Account?
    private var fileReference: FileMediaReference?
    private let disposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }
    
    var started: () -> Void = {}
    
    var player: AVPlayer? {
        get {
           return self.playerLayer.player
        }
        set {
            if let player = self.playerLayer.player {
                player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
            }
            self.playerLayer.player = newValue
            if let newValue = newValue {
                newValue.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [], context: nil)
            }
        }
    }
    
    private var playerItem: AVPlayerItem? = nil {
        willSet {
            self.playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
        didSet {
            self.playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: .new, context: nil)
            self.setupLooping()
        }
    }
    
    override init() {
        super.init()
        
        let layer = AVPlayerLayer()
        layer.pixelBufferAttributes = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
        layer.disableActions()
        self.layer = layer
        
        
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.didPlayToEndTimeObsever as Any)
        self.playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        self.player = nil
        self.playerItem = nil
        self.disposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    func setup(account: Account, fileReference: FileMediaReference) {
        self.disposable.set((chatMessageAnimationData(postbox: account.postbox, fileReference: fileReference, synchronousLoad: false) |> deliverOnMainQueue).start(next: { [weak self] data in
            if let strongSelf = self, data.complete {
                let playerItem = AVPlayerItem(url: URL(fileURLWithPath: data.path))
                strongSelf.player = AVPlayer(playerItem: playerItem)
                strongSelf.playerItem = playerItem
            }
        }))
        self.fetchDisposable.set(fetchedMediaResource(postbox: account.postbox, reference: fileReference.resourceReference(fileReference.media.resource)).start())
    }
    
    private func setupLooping() {
        guard let playerItem = self.playerItem, let player = self.player else {
            return
        }
        
        
        self.didPlayToEndTimeObsever = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: nil, using: { _ in
            player.seek(to: CMTime.zero) { _ in
                player.play()
            }
        })
    }
    
    private var didPlayToEndTimeObsever: NSObjectProtocol? = nil {
        willSet(newObserver) {
            if let observer = self.didPlayToEndTimeObsever, self.didPlayToEndTimeObsever !== newObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let playerItem = object as? AVPlayerItem, playerItem === self.playerItem {
            if case .readyToPlay = playerItem.status, playerItem.videoComposition == nil {
                playerItem.videoComposition = createVideoComposition(for: playerItem)
                playerItem.seekingWaitsForVideoCompositionRendering = true
            }
            self.player?.play()
        } else if let player = object as? AVPlayer, player === self.player {
            if self.isHidden && player.rate > 0.0 {
                delay(0.2, closure: { [weak self] in
                    self?.isHidden = false
                    self?.started()
                })
            }
        } else {
            return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
}



class ChatMediaAnimatedStickerView: ChatMediaContentView {

    private let loadResourceDisposable = MetaDisposable()
    
    private let playerView: GIFPlayerView = GIFPlayerView()
    private var playerData:AVGifData? = nil {
        didSet {
            updatePlayerIfNeeded()
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(playerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    deinit {
        loadResourceDisposable.dispose()
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    @objc func updatePlayerIfNeeded() {
        let accept = parameters?.autoplay == true && window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !self.isDynamicContentLocked
        playerView.set(data: accept ? self.playerData : nil)
        
    }
    
    
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: table?.clipView)
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
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool, positionFlags: LayoutPositionFlags?, approximateSynchronousValue: Bool) {
        
        super.update(with: media, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
     
        
        guard let file = media as? TelegramMediaFile else { return }
        
        let displaySize = size//CGSize(width: 256, height: 256)
        

        var imageSize: CGSize = size//CGSize(width: 256, height: 256)
        if let dimensions = file.dimensions {
            imageSize = dimensions.aspectFitted(displaySize)
        } else if let thumbnailSize = file.previewRepresentations.first?.dimensions {
            imageSize = thumbnailSize.aspectFitted(displaySize)
        }
    
        
        let fileReference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)
                
        updatePlayerIfNeeded()
        
        self.loadResourceDisposable.set((chatMessageAnimationData(postbox: context.account.postbox, fileReference: fileReference, synchronousLoad: false) |> deliverOnMainQueue).start(next: { [weak self] data in
            if data.complete {
                self?.playerData = AVGifData.dataFrom(data.path, animatedSticker: true)
                self?.playerView.setSignal(signal: .single((nil, true)))
            } else {
                self?.playerData = nil
            }
        }))
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: size, intrinsicInsets: NSEdgeInsets())
        self.playerView.setSignal(chatMessageSticker(postbox: context.account.postbox, file: file, small: true, scale: backingScaleFactor, fetched: true))
        self.playerView.set(arguments: arguments)
        
        _ = fetchedMediaResource(postbox: context.account.postbox, reference: fileReference.resourceReference(file.resource)).start()
    }
    
    override func layout() {
        super.layout()
        self.playerView.frame = bounds
    }
    
}
