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


class ChatMediaAnimatedStickerView: ChatMediaContentView {

    private let loadResourceDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private let playThrottleDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let playerView: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 240, 240))
    private let thumbView = TransformImageView()
    private var sticker:LottieAnimation? = nil {
        didSet {
            updatePlayerIfNeeded()
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.playerView)
        addSubview(self.thumbView)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func clean() {
        stateDisposable.set(nil)
        loadResourceDisposable.set(nil)
        playThrottleDisposable.set(nil)
        fetchDisposable.set(nil)
    }
    
    deinit {
        loadResourceDisposable.dispose()
        stateDisposable.dispose()
        playThrottleDisposable.dispose()
        fetchDisposable.dispose()
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    private var previousAccept: Bool = false
    
    @objc func updatePlayerIfNeeded() {
        let accept = ((self.window != nil && self.window!.isKeyWindow) || (self.window != nil && !(self.window is Window))) && !NSIsEmptyRect(self.visibleRect) && !self.isDynamicContentLocked && self.sticker != nil
                
        var signal = Signal<Void, NoError>.single(Void())
        if accept && !nextForceAccept {
            signal = signal |> delay(accept ? 0.25 : 0, queue: .mainQueue())
        }
        if accept && self.sticker != nil {
            nextForceAccept = false
        }
        if previousAccept != accept {
            self.playThrottleDisposable.set(signal.start(next: { [weak self] in
                guard let `self` = self else {
                    return
                }
                self.playerView.set(accept ? self.sticker : nil)
                self.previousAccept = accept
            }))
        }
        previousAccept = accept
    }
    
    private var nextForceAccept: Bool = false

    
    override func previewMediaIfPossible() -> Bool {
        if let table = table, let context = context, let window = window as? Window {
            _ = startModalPreviewHandle(table, window: window, context: context)
        }
        return true
    }
    
    override func executeInteraction(_ isControl: Bool) {
        if let window = window as? Window {
            if let context = context, let peerId = parent?.id.peerId, let media = media as? TelegramMediaFile, let reference = media.stickerReference {
                showModal(with:StickersPackPreviewModalController(context, peerId: peerId, reference: reference), for:window)
            }
        }
    }
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
        } else {
            removeNotificationListeners()
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        updatePlayerIfNeeded()
    }
    
    override func willRemove() {
        super.willRemove()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToSuperview() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool, positionFlags: LayoutPositionFlags?, approximateSynchronousValue: Bool) {
        
        
        guard let file = media as? TelegramMediaFile else { return }

        let updated = self.media != nil ? !file.isSemanticallyEqual(to: self.media!) : true
        
        if parent?.stableId != self.parent?.stableId {
            self.sticker = nil
        } else if parent == nil, updated {
            self.sticker = nil
        }
        self.nextForceAccept = approximateSynchronousValue || parent?.id.namespace == Namespaces.Message.Local

        
        super.update(with: media, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
     
        
        let reference: MediaResourceReference
        
        if let message = parent {
            reference = FileMediaReference.message(message: MessageReference(message), media: file).resourceReference(file.resource)
        } else if let stickerReference = file.stickerReference {
            if file.resource is CloudStickerPackThumbnailMediaResource {
                reference = MediaResourceReference.stickerPackThumbnail(stickerPack: stickerReference, resource: file.resource)
            } else {
                reference = FileMediaReference.stickerPack(stickerPack: stickerReference, media: file).resourceReference(file.resource)
            }
        } else {
            reference = FileMediaReference.standalone(media: file).resourceReference(file.resource)
        }
        
        
        self.loadResourceDisposable.set((context.account.postbox.mediaBox.resourceData(file.resource, attemptSynchronously: approximateSynchronousValue) |> map { resourceData -> Data? in
            
            if resourceData.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                return data
            }
            return nil
        } |> deliverOnMainQueue).start(next: { [weak self] data in
            if let data = data {
                
                self?.sticker = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .media(self?.media?.id), size: size), cachePurpose: size.width < 200 ? .temporaryLZ4(.thumb) : parent != nil  ? .temporaryLZ4(.chat) : .none, maximumFps: size.width < 200 ? 30 : 60)
                self?.fetchStatus = .Local
            } else {
                self?.sticker = nil
                self?.fetchStatus = .Remote
            }
        }))
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
        
        
        self.thumbView.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor), clearInstantly: updated)
        if !self.thumbView.isFullyLoaded {
            self.thumbView.setSignal(chatMessageAnimatedSticker(postbox: context.account.postbox, file: file, small: false, scale: backingScaleFactor, fetched: false), cacheImage: { [weak file] signal in
                if let file = file {
                    return cacheMedia(signal: signal, media: file, arguments: arguments, scale: System.backingScale)
                } else {
                    return .complete()
                }
            })
            self.thumbView.set(arguments: arguments)
        } else {
            self.thumbView.dispose()
        }

        fetchDisposable.set(fetchedMediaResource(postbox: context.account.postbox, reference: reference).start())
        stateDisposable.set((self.playerView.state |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let `self` = self else { return }
            switch state {
            case .playing:
                self.playerView.isHidden = false
                self.thumbView.isHidden = true
            default:
                self.playerView.isHidden = true
                self.thumbView.isHidden = false
            }
        }))
    }
    
    override var contents: Any? {
        return self.thumbView.image
    }
    
    override func layout() {
        super.layout()
        self.playerView.frame = bounds
        self.thumbView.frame = bounds
    }
    
}
