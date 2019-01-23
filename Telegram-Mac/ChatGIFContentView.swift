//
//  ChatGIFContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 10/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import PostboxMac
import SwiftSignalKitMac
class ChatGIFContentView: ChatMediaContentView {
    
    private var player:GIFPlayerView = GIFPlayerView()
    private var progressView:RadialProgressView?
    
    private var canPlayForce: Bool = FastSettings.gifsAutoPlay
    
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    private let nextTimebase: Atomic<CMTimebase?> = Atomic(value: nil)
    private var data:AVGifData? {
        didSet {
            updatePlayerIfNeeded()
        }
    }
    
    override var backgroundColor: NSColor {
        set {
            super.backgroundColor = .clear
        }
        get {
            return super.backgroundColor
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(player)
        player.layer?.cornerRadius = .cornerRadius
       // player.set
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func clean() {
        statusDisposable.dispose()
        playerDisposable.dispose()
        removeNotificationListeners()
    }
    
    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    override func open() {
        if let parent = parent {
            if !canPlayForce {
                canPlayForce = true
                updatePlayerIfNeeded()
            } else if !(parent.media.first is TelegramMediaGame) {
                parameters?.showMedia(parent)
            }
        }
    }

    override func videoTimebase() -> CMTimebase? {
        return player.controlTimebase
    }
    override func applyTimebase(timebase: CMTimebase?) {
        _ = nextTimebase.swap(timebase)
    }
    
    override func cancelFetching() {
        if let account = account, let media = media as? TelegramMediaFile {
            if let parent = parent {
                messageMediaFileCancelInteractiveFetch(account: account, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media))
            } else {
                cancelFreeMediaFileInteractiveFetch(account: account, resource: media.resource)
            }
        }
    }
    
    override func fetch() {
        if let account = account, let media = media as? TelegramMediaFile {
            if let parent = parent {
                fetchDisposable.set(messageMediaFileInteractiveFetched(account: account, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media)).start())
            } else {
                fetchDisposable.set(freeMediaFileInteractiveFetched(account: account, fileReference: FileMediaReference.standalone(media: media)).start())
            }
        }
    }
    
    override func layout() {
        super.layout()
        player.frame = bounds
        self.player.positionFlags = positionFlags
        progressView?.center()
    }

    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }

    @objc func updatePlayerIfNeeded() {
         let accept = canPlayForce && window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !self.isDynamicContentLocked
        player.set(data: accept ? data : nil, timebase: nextTimebase.swap(nil))
        progressView?.isHidden = !FastSettings.gifsAutoPlay && canPlayForce
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
    
    deinit {
        player.set(data: nil)
    }
    
    override func update(with media: Media, size: NSSize, account: Account, parent: Message?, table: TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        let mediaUpdated = self.media == nil || !self.media!.isSemanticallyEqual(to: media)
        
        
        super.update(with: media, size: size, account: account, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        

        var topLeftRadius: CGFloat = .cornerRadius
        var bottomLeftRadius: CGFloat = .cornerRadius
        var topRightRadius: CGFloat = .cornerRadius
        var bottomRightRadius: CGFloat = .cornerRadius
        
        
        if let positionFlags = positionFlags {
            if positionFlags.contains(.top) && positionFlags.contains(.left) {
                topLeftRadius = topLeftRadius * 3 + 2
            }
            if positionFlags.contains(.top) && positionFlags.contains(.right) {
                topRightRadius = topRightRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                bottomLeftRadius = bottomLeftRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                bottomRightRadius = bottomRightRadius * 3 + 2
            }
        }

        
        updateListeners()
        
        if let media = media as? TelegramMediaFile {
            
            let dimensions = media.dimensions ?? size
            var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
            
            let reference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: media) : FileMediaReference.standalone(media: media)
            let fitted = dimensions.fitted(NSMakeSize(320, 320))
            player.setVideoLayerGravity(fitted.width == size.width ? .resizeAspectFill : .resizeAspect)
            let arguments = TransformImageArguments(corners: ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius)), imageSize: fitted, boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: .fill(theme.colors.grayBackground))

            player.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor, positionFlags: positionFlags), clearInstantly: mediaUpdated)

            
            player.setSignal(chatMessageVideo(postbox: account.postbox, fileReference: reference, scale: backingScaleFactor), cacheImage: { [weak self] image in
                if let strongSelf = self {
                    return cacheMedia(signal: image, media: media, arguments: arguments, scale: strongSelf.backingScaleFactor, positionFlags: positionFlags)
                } else {
                    return .complete()
                }
            })
            player.set(arguments: arguments)
            
            if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                updatedStatusSignal = combineLatest(chatMessageFileStatus(account: account, file: media), account.pendingMessageManager.pendingMessageStatus(parent.id))
                    |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                        if let pendingStatus = pendingStatus {
                            return .Fetching(isActive: true, progress: min(pendingStatus.progress, pendingStatus.progress * 85 / 100))
                        } else {
                            return resourceStatus
                        }
                    } |> deliverOnMainQueue
            } else {
                updatedStatusSignal = chatMessageFileStatus(account: account, file: media, approximateSynchronousValue: approximateSynchronousValue)
            }
            
            if let updatedStatusSignal = updatedStatusSignal {
                
                
                self.statusDisposable.set((combineLatest(updatedStatusSignal, account.postbox.mediaBox.resourceData(media.resource)) |> deliverOnResourceQueue |> map {  status, resource -> (MediaResourceStatus, AVGifData?) in
                    if resource.complete {
                        return (status, AVGifData.dataFrom(resource.path))
                    } else if status == .Local, let resource = media.resource as? LocalFileReferenceMediaResource {
                        return (status, AVGifData.dataFrom(resource.localFilePath))
                    } else {
                        return (status, nil)
                    }
                    } |> deliverOnMainQueue).start(next: { [weak self] status, data in
                        if let strongSelf = self {
                            strongSelf.data = data
                            strongSelf.fetchStatus = status
                            if case .Local = status, FastSettings.gifsAutoPlay {
                                if let progressView = strongSelf.progressView {
                                    progressView.state = .Fetching(progress: 1, force: false)
                                    strongSelf.progressView = nil
                                    progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] completed in
                                        if completed {
                                            progressView?.removeFromSuperview()
                                        }
                                    })
                                }
                                
                            } else {
                                if strongSelf.progressView == nil, parent != nil {
                                    let progressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
                                    progressView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
                                    strongSelf.progressView = progressView
                                    strongSelf.addSubview(progressView)
                                    strongSelf.progressView?.center()
                                    strongSelf.progressView?.fetchControls = strongSelf.fetchControls
                                }
                            }
                            
                            switch status {
                            case let .Fetching(_, progress):
                                strongSelf.progressView?.state = .Fetching(progress: progress, force: false)
                            case .Local:
                                strongSelf.progressView?.state = .Play
                            case .Remote:
                                strongSelf.progressView?.state = .Remote
                            }
                        }
                    }))
            }

        }
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        var bp:Int = 0
        bp += 1
    }
    
    override open func copy() -> Any {
        let view = NSView()
        view.wantsLayer = true
        
        view.background = .clear
        view.layer?.contents = player.layer?.contents
        view.frame = self.visibleRect
        view.layer?.masksToBounds = true
        
        
        if bounds != visibleRect {
            if let image = player.layer?.contents {
                view.layer?.contents = generateImage(player.bounds.size, contextGenerator: { size, ctx in
                    ctx.clear(player.bounds)
                    ctx.setFillColor(.clear)
                    ctx.fill(player.bounds)
                    
                    if player.visibleRect.minY == 0  {
                        ctx.clip(to: NSMakeRect(0, 0, player.bounds.width, player.bounds.height - ( player.bounds.height - player.visibleRect.height)))
                    } else {
                        ctx.clip(to: NSMakeRect(0, (player.bounds.height - player.visibleRect.height), player.bounds.width, player.bounds.height - ( player.bounds.height - player.visibleRect.height)))
                    }
                    ctx.draw(image as! CGImage, in: player.bounds)
                }, opaque: false)
            }
        }
        
        view.layer?.shouldRasterize = true
        view.layer?.rasterizationScale = backingScaleFactor
        
        return view
    }
    
}
