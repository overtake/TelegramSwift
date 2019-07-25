//
//  ChatMessagePhotoContent.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit

final class ChatVideoAutoplayView {
    let mediaPlayer: MediaPlayer
    let view: MediaPlayerView
    
    fileprivate var playTimer: SwiftSignalKitMac.Timer?
    
    let bufferingIndicator: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 40, 40))
    private var timer: SwiftSignalKitMac.Timer? = nil
    var status: MediaPlayerStatus?
    
    init(mediaPlayer: MediaPlayer, view: MediaPlayerView) {
        self.mediaPlayer = mediaPlayer
        self.view = view
        mediaPlayer.actionAtEnd = .loop(nil)
        

        self.bufferingIndicator.backgroundColor = .blackTransparent
        self.bufferingIndicator.progressColor = .white
        self.bufferingIndicator.alwaysAnimate = true
    }
    
    func toggleVolume(_ enabled: Bool, animated: Bool) {
        if !animated {
            mediaPlayer.setVolume(enabled ? 1 : 0)
            timer?.invalidate()
            timer = nil
        } else {
            timer = nil
            
            let start:(Float) -> Void = { [weak self] volume in
                let fps = Float(1000 / 60)
                var current:Float = volume

                let tick = (enabled ? 1 - current : -current) / (fps * 0.3)
                
                self?.timer = SwiftSignalKitMac.Timer(timeout: abs(Double(tick)), repeat: true, completion: { [weak self] in
                    current += tick
                    self?.mediaPlayer.setVolume(min(1, max(0, current)))
                    
                    if current >= 1 || current <= 0 {
                        self?.timer?.invalidate()
                    }
                }, queue: .mainQueue())
                
                self?.timer?.start()
            }
            
            mediaPlayer.getVolume { volume in
                Queue.mainQueue().justDispatch {
                    start(volume)
                }
            }
        }
    }
    
    deinit {
        view.removeFromSuperview()
        bufferingIndicator.removeFromSuperview()
        timer?.invalidate()
        playTimer?.invalidate()
    }
}


class ChatInteractiveContentView: ChatMediaContentView {

    private let image:TransformImageView = TransformImageView()
    private var videoAccessory: ChatMessageAccessoryView? = nil
    private var progressView:RadialProgressView?
    private var timableProgressView: TimableProgressView? = nil
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    
    private let partDisposable = MetaDisposable()

    private var authenticFetchStatus: MediaResourceStatus?

    
    private let mediaPlayerStatusDisposable = MetaDisposable()
    private var autoplayVideoView: ChatVideoAutoplayView?
    
    override var backgroundColor: NSColor {
        get {
            return super.backgroundColor
        }
        set {
            super.backgroundColor = .clear
        }
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard let context = self.context, let window = self.kitWindow, let table = self.table, media is TelegramMediaImage, parent == nil || parent?.containsSecretMedia == false, fetchStatus == .Local else {return false}
        _ = startModalPreviewHandle(table, window: window, context: context)
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        //background = .random
        self.addSubview(image)
    }
    
//    override func mouseEntered(with event: NSEvent) {
//        super.mouseEntered(with: event)
//        updateAutoplaySound()
//    }
//
//    override func mouseExited(with event: NSEvent) {
//        super.mouseExited(with: event)
//        updateAutoplaySound()
//    }
//
    
    private var canPlaySound: Bool {
        return mouseInside() && globalAudio == nil && !hasPictureInPicture
    }
    
    override func updateMouse() {
        if let autoplayVideoView = autoplayVideoView, let media = media as? TelegramMediaFile, let status = autoplayVideoView.status, let parameters = parameters, parameters.soundOnHover {
            autoplayVideoView.toggleVolume(canPlaySound, animated: canPlaySound)
            updateVideoAccessory(.Local, file: media, mediaPlayerStatus: status, animated: true)
        }
    }
    
    private var soundOffOnInlineImage: CGImage? {
        return autoplayVideo && parameters?.soundOnHover == true ? mouseInside() && canPlaySound ? theme.icons.inlineVideoSoundOn : theme.icons.inlineVideoSoundOff : nil
    }
    
    override func open() {
        if let parent = parent {
            parameters?.showMedia(parent)
            autoplayVideoView?.toggleVolume(false, animated: false)
        }
    }
    
    private func updateMediaStatus(_ status: MediaPlayerStatus, animated: Bool = false) {
        if let autoplayVideoView = autoplayVideoView, let media = self.media as? TelegramMediaFile {
            autoplayVideoView.status = status
            updateVideoAccessory(.Local, file: media, mediaPlayerStatus: status, animated: animated)
            
            switch status.status {
            case .playing:
                autoplayVideoView.playTimer?.invalidate()
                autoplayVideoView.playTimer = SwiftSignalKitMac.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                    self?.updateVideoAccessory(.Local, file: media, mediaPlayerStatus: status, animated: animated)
                    }, queue: .mainQueue())
                
                autoplayVideoView.playTimer?.start()
            default:
                autoplayVideoView.playTimer?.invalidate()
            }

            
        }
    }
    

    override func interactionControllerDidFinishAnimation(interactive: Bool) {

    }
    
    override func addAccesoryOnCopiedView(view: NSView) {
        if let videoAccessory = videoAccessory?.copy() as? NSView {
            if visibleRect.minY < videoAccessory.frame.midY && visibleRect.minY + visibleRect.height > videoAccessory.frame.midY {
                videoAccessory.frame.origin.y = frame.height - videoAccessory.frame.maxY
                view.addSubview(videoAccessory)
            }
           
        }
        if let progressView = progressView {
            let pView = RadialProgressView(theme: progressView.theme, twist: true)
            pView.state = progressView.state
            pView.frame = progressView.frame
            if visibleRect.minY < progressView.frame.midY && visibleRect.minY + visibleRect.height > progressView.frame.midY {
                pView.frame.origin.y = frame.height - progressView.frame.maxY
                view.addSubview(pView)
            }
        }
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    deinit {
        removeNotificationListeners()
        mediaPlayerStatusDisposable.dispose()
        partDisposable.dispose()
    }
    
    @objc func updatePlayerIfNeeded() {
        let accept = window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !self.isDynamicContentLocked
        if let autoplayView = autoplayVideoView {
            if accept {
                autoplayView.mediaPlayer.play()
            } else {
                autoplayView.mediaPlayer.pause()
                autoplayVideoView?.playTimer?.invalidate()
            }
        }
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

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            self.autoplayVideoView = nil
        }
    }
    
    override func layout() {
        super.layout()
        progressView?.center()
        timableProgressView?.center()
        videoAccessory?.setFrameOrigin(8, 8)
        autoplayVideoView?.bufferingIndicator.center()
        self.image.setFrameSize(frame.size)
        self.autoplayVideoView?.view.setFrameSize(frame.size)
    }
    
    private func updateVideoAccessory(_ status: MediaResourceStatus, file: TelegramMediaFile, mediaPlayerStatus: MediaPlayerStatus? = nil, animated: Bool = false) {
        let maxWidth = frame.width - 10
        let text: String
        
        var isBuffering: Bool = false
        if let fetchStatus = self.fetchStatus, let status = mediaPlayerStatus {
            switch status.status {
            case .buffering:
                switch fetchStatus {
                case .Local:
                    break
                default:
                    isBuffering = true
                }
            default:
                break
            }
           
        }
        
        switch status {
        case let .Fetching(_, progress):
            let current = String.prettySized(with: Int(Float(file.elapsedSize) * progress), afterDot: 1)
            var size = "\(current) / \(String.prettySized(with: file.elapsedSize))"
            if (maxWidth < 100 && parent?.groupingKey != nil) || file.elapsedSize == 0 {
                size = "\(Int(progress * 100))%"
            }
            if file.isStreamable, parent?.groupingKey == nil, maxWidth > 100 {
                if let parent = parent {
                    if !parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                        size = String.durationTransformed(elapsed: file.videoDuration) + ", \(size)"
                    }
                } else {
                    size = String.durationTransformed(elapsed: file.videoDuration) + ", \(size)"
                } 
            }
            text = size
        case .Remote:
            var size = String.durationTransformed(elapsed: file.videoDuration)
            if file.isStreamable, parent?.groupingKey == nil, maxWidth > 100 {
                 size = size + ", " + String.prettySized(with: file.elapsedSize)
            }
            text = size
        case .Local:
            if let status = mediaPlayerStatus, status.generationTimestamp > 0, status.duration > 0 {
                text = String.durationTransformed(elapsed: Int(status.duration - (status.timestamp + (CACurrentMediaTime() - status.generationTimestamp))))
            } else {
                text = String.durationTransformed(elapsed: file.videoDuration)
            }
        }
        
        let isStreamable: Bool
        if let parent = parent {
            isStreamable = !parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) && file.isStreamable
        } else {
            isStreamable = file.isStreamable
        }
        
        videoAccessory?.updateText(text, maxWidth: maxWidth, status: status, isStreamable: isStreamable, isCompact: parent?.groupingKey != nil, soundOffOnImage: !isBuffering ? soundOffOnInlineImage : nil, isBuffering: isBuffering, animated: animated, fetch: { [weak self] in
            self?.fetch()
        }, cancelFetch: { [weak self] in
            self?.cancelFetching()
        }, click: {
                
        })
        
    }
    
    override func executeInteraction(_ isControl: Bool) {
        if let progressView = progressView {
            switch progressView.state {
            case .Fetching:
                if isControl {
                    if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                        delete()
                    }
                    cancelFetching()
                }
            default:
                super.executeInteraction(isControl)
            }
        } else {
            if autoplayVideo {
                open()
            } else {
                super.executeInteraction(isControl)
            }
        }
    }
    
    var autoplayVideo: Bool {
        if #available(OSX 10.12, *) {
        } else {
            return false
        }

        if let media = media as? TelegramMediaFile, let parameters = self.parameters {
            return (media.isStreamable || authenticFetchStatus == .Local) && (autoDownload || authenticFetchStatus == .Local) && parameters.autoplay && (parent?.groupingKey == nil || self.frame.width == superview?.frame.width)
        }
        return false
    }

    override func update(with media: Media, size:NSSize, context:AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        
        partDisposable.set(nil)
        
        
        let mediaUpdated = self.media == nil || !media.isSemanticallyEqual(to: self.media!)
        if mediaUpdated {
            self.autoplayVideoView = nil
        }
        
        var clearInstantly: Bool = mediaUpdated
        if clearInstantly, parent?.stableId == self.parent?.stableId {
            clearInstantly = false
        }

        super.update(with: media, size: size, context: context, parent:parent, table: table, parameters:parameters, positionFlags: positionFlags)

        
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


        var updateImageSignal: Signal<ImageDataTransformation, NoError>?
        var updatedStatusSignal: Signal<(MediaResourceStatus, MediaResourceStatus), NoError>?
        
        if true /*mediaUpdated*/ {
            
            var dimensions: NSSize = size
            
            if let image = media as? TelegramMediaImage {
                
                autoplayVideoView = nil
                videoAccessory?.removeFromSuperview()
                videoAccessory = nil
                dimensions = image.representationForDisplayAtSize(size)?.dimensions ?? size
                
                if let parent = parent, parent.containsSecretMedia {
                    updateImageSignal = chatSecretPhoto(account: context.account, imageReference: ImageMediaReference.message(message: MessageReference(parent), media: image), scale: backingScaleFactor, synchronousLoad: approximateSynchronousValue)
                } else {
                    updateImageSignal = chatMessagePhoto(account: context.account, imageReference: parent != nil ? ImageMediaReference.message(message: MessageReference(parent!), media: image) : ImageMediaReference.standalone(media: image), scale: backingScaleFactor, synchronousLoad: approximateSynchronousValue)
                }
                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessagePhotoStatus(account: context.account, photo: image), context.account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus in
                            if let pendingStatus = pendingStatus, parent.forwardInfo == nil || resourceStatus != .Local {
                                return (.Fetching(isActive: true, progress: min(pendingStatus.progress, pendingStatus.progress * 85 / 100)), .Fetching(isActive: true, progress: min(pendingStatus.progress, pendingStatus.progress * 85 / 100)))
                            } else {
                                return (resourceStatus, resourceStatus)
                            }
                    } |> deliverOnMainQueue
                } else {
                    updatedStatusSignal = chatMessagePhotoStatus(account: context.account, photo: image, approximateSynchronousValue: approximateSynchronousValue) |> map {($0, $0)} |> deliverOnMainQueue
                }
            
            } else if let file = media as? TelegramMediaFile {
                
                let fileReference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)
                
               
                
                if file.isVideo, size.height > 80 {
                    if videoAccessory == nil {
                        videoAccessory = ChatMessageAccessoryView(frame: NSMakeRect(5, 5, 0, 0))
                        addSubview(videoAccessory!)
                    }
                } else {
                    videoAccessory?.removeFromSuperview()
                    videoAccessory = nil
                }
                
                if let parent = parent, parent.containsSecretMedia {
                    updateImageSignal = chatSecretMessageVideo(account: context.account, fileReference: fileReference, scale: backingScaleFactor)
                } else {
                    updateImageSignal = chatMessageVideo(postbox: context.account.postbox, fileReference: fileReference, scale: backingScaleFactor) //chatMessageVideo(account: account, video: file, scale: backingScaleFactor)
                }
                
                dimensions = file.dimensions ?? size
                

                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessageFileStatus(account: context.account, file: file), context.account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus in
                            if let pendingStatus = pendingStatus {
                                return (.Fetching(isActive: true, progress: pendingStatus.progress), .Fetching(isActive: true, progress: pendingStatus.progress))
                            } else {
                                return (resourceStatus, resourceStatus)
                            }
                    } |> deliverOnMainQueue
                } else {
                    updatedStatusSignal = chatMessageFileStatus(account: context.account, file: file, approximateSynchronousValue: approximateSynchronousValue) |> deliverOnMainQueue |> map { [weak parent, weak file] status in
                        if let parent = parent, let file = file {
                            if file.isStreamable && parent.id.peerId.namespace != Namespaces.Peer.SecretChat {
                                return (.Local, status)
                            }
                        }
                        return (status, status)
                    }
                }
            }
            
            let blurBackground: Bool = media is TelegramMediaImage && (parent != nil && parent?.groupingKey == nil)
            
            let arguments = TransformImageArguments(corners: ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius)), imageSize: blurBackground ? dimensions.fitted(NSMakeSize(320, 320)) : dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: blurBackground ? .blurBackground : .none)
            
            
            self.image.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor, positionFlags: positionFlags), clearInstantly: clearInstantly)

            if let updateImageSignal = updateImageSignal, !self.image.isFullyLoaded {
                self.image.setSignal( updateImageSignal, animate: true, cacheImage: { [weak media] result in
                    if let media = media {
                        cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: positionFlags)
                    }
                })
            }
            
            self.image.set(arguments: arguments)
        }
        
        var first: Bool = true
        
        if let updateStatusSignal = updatedStatusSignal {
            self.statusDisposable.set(updateStatusSignal.start(next: { [weak self] (status, authentic) in
                
                
                
                if let strongSelf = self {
                    
                    strongSelf.authenticFetchStatus = authentic

                    
                    var authentic = authentic
                    if strongSelf.autoplayVideo {
                        strongSelf.fetchStatus = authentic
                        authentic = .Local
                    } else {
                        switch authentic {
                        case .Fetching:
                            strongSelf.fetchStatus = status
                        default:
                            strongSelf.fetchStatus = status
                        }
                    }
                    
                    
                    
                    
                    if let file = strongSelf.media as? TelegramMediaFile, strongSelf.autoplayVideo {
                        if strongSelf.autoplayVideoView == nil {
                            let autoplay: ChatVideoAutoplayView
                            
                            let fileReference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)
                            
                            autoplay = ChatVideoAutoplayView(mediaPlayer: MediaPlayer(postbox: context.account.postbox, reference: fileReference.resourceReference(fileReference.media.resource), streamable: file.isStreamable, video: true, preferSoftwareDecoding: false, enableSound: parameters?.soundOnHover == true, volume: 0.0, fetchAutomatically: true), view: MediaPlayerView(backgroundThread: true))
                            
                            strongSelf.autoplayVideoView = autoplay
                            if parent == nil {
                                strongSelf.autoplayVideoView?.view.setVideoLayerGravity(.resizeAspectFill)
                            } else {
                                strongSelf.autoplayVideoView?.view.setVideoLayerGravity(.resize)
                            }
                            strongSelf.updatePlayerIfNeeded()
                        }
                        if let autoplay = strongSelf.autoplayVideoView {
                            autoplay.view.frame = NSMakeRect(0, 0, size.width, size.height)
                            if let positionFlags = positionFlags {
                                autoplay.view.positionFlags = positionFlags
                            } else {
                                autoplay.view.layer?.cornerRadius = .cornerRadius
                            }
                            strongSelf.addSubview(autoplay.view, positioned: .above, relativeTo: strongSelf.image)
                            
                            autoplay.mediaPlayer.attachPlayerView(autoplay.view)
                        }
                        
                    } else {
                        strongSelf.autoplayVideoView = nil
                    }
                    
                    if let autoplay = strongSelf.autoplayVideoView {
                        strongSelf.mediaPlayerStatusDisposable.set((autoplay.mediaPlayer.status |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                            strongSelf?.updateMediaStatus(status, animated: !first)
                        }))
                    }
                   
                    
                    
                    if let file = media as? TelegramMediaFile, strongSelf.autoplayVideoView == nil  {
                        strongSelf.updateVideoAccessory(parent == nil ? .Local : authentic, file: file, animated: !first)
                        first = false
                    }
                    var containsSecretMedia:Bool = false
                    
                    if let message = parent {
                        containsSecretMedia = message.containsSecretMedia
                    }
                    
                    if let _ = parent?.autoremoveAttribute?.countdownBeginTime {
                        strongSelf.progressView?.removeFromSuperview()
                        strongSelf.progressView = nil
                        if strongSelf.timableProgressView == nil {
                            strongSelf.timableProgressView = TimableProgressView()
                            strongSelf.addSubview(strongSelf.timableProgressView!)
                        }
                    } else {
                        strongSelf.timableProgressView?.removeFromSuperview()
                        strongSelf.timableProgressView = nil
                        
                        switch status {
                        case .Local:
                            self?.image.animatesAlphaOnFirstTransition = false
                        default:
                            self?.image.animatesAlphaOnFirstTransition = false
                        }
                        
                        var removeProgress: Bool = strongSelf.autoplayVideo
                        if case .Local = status, media is TelegramMediaImage, !containsSecretMedia {
                            removeProgress = true
                        }
                        
                        if removeProgress {
                             if let progressView = strongSelf.progressView {
                                switch progressView.state {
                                case .Fetching:
                                    progressView.state = .Fetching(progress:1.0, force: false)
                                case .ImpossibleFetching:
                                    progressView.state = .ImpossibleFetching(progress:1.0, force: false)
                                default:
                                    break
                                }
                                strongSelf.progressView = nil
                                progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] completed in
                                    if completed {
                                         progressView?.removeFromSuperview()
                                    }
                                })
                               
                            }
                        } else {
                            strongSelf.progressView?.layer?.removeAllAnimations()
                            if strongSelf.progressView == nil {
                                let progressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
                                progressView.frame = CGRect(origin: CGPoint(), size: CGSize(width: parent?.groupingKey != nil ? 30 : 40.0, height: parent?.groupingKey != nil ? 30 : 40.0))
                                strongSelf.progressView = progressView
                                strongSelf.addSubview(progressView)
                                strongSelf.progressView?.center()
                                progressView.fetchControls = strongSelf.fetchControls
                            }
                        }
                    }
                    
                    
                    let progressStatus: MediaResourceStatus
                    if strongSelf.parent?.groupingKey != nil {
                        switch authentic {
                        case .Fetching:
                            progressStatus = authentic
                        default:
                            progressStatus = status
                        }
                    } else {
                        progressStatus = status
                    }
    
                    
                    switch progressStatus {
                    case let .Fetching(_, progress):
                        strongSelf.progressView?.state = parent == nil ? .ImpossibleFetching(progress: progress, force: false) : (progress == 1.0 && strongSelf.parent?.groupingKey != nil ? .Success : .Fetching(progress: progress, force: false))
                    case .Local:
                        var state: RadialProgressState = .None
                        if containsSecretMedia {
                            state = .Icon(image: theme.icons.chatSecretThumb, mode:.destinationOut)
                            
                            if let attribute = parent?.autoremoveAttribute, let countdownBeginTime = attribute.countdownBeginTime {
                                let difference:TimeInterval = TimeInterval((countdownBeginTime + attribute.timeout)) - (CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                let start = difference / Double(attribute.timeout) * 100.0
                                strongSelf.timableProgressView?.theme = TimableProgressTheme(outer: 3, seconds: difference, start: start, border: false)
                                strongSelf.timableProgressView?.progress = 0
                                strongSelf.timableProgressView?.startAnimation()
                                
                            }
                        } else {
                            if let file = media as? TelegramMediaFile {
                                if file.isVideo {
                                    state = .Play
                                }
                            }
                        }
                        
                        strongSelf.progressView?.state = state
                    case .Remote:
                        strongSelf.progressView?.state = .Remote
                    }
                    strongSelf.needsLayout = true
                }
            }))
           
        }
        
    }
    
    override func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        super._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        
        image._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    override func setContent(size: NSSize) {
        super.setContent(size: size)
    }
    
    override func clean() {
        statusDisposable.dispose()
    }
    
    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    override func cancelFetching() {
        if let context = context, let parent = parent {
            if let media = media as? TelegramMediaFile {
                messageMediaFileCancelInteractiveFetch(context: context, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media))
            } else if let media = media as? TelegramMediaImage {
                chatMessagePhotoCancelInteractiveFetch(account: context.account, photo: media)
            }
        }
        
    }
    override func fetch() {
        if let context = context {
            if let media = media as? TelegramMediaFile {
                if let parent = parent {
                    fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media)).start())
                } else {
                    fetchDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: media)).start())
                }
            } else if let media = media as? TelegramMediaImage {
                fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: context.account, imageReference: parent != nil ? ImageMediaReference.message(message: MessageReference(parent!), media: media) : ImageMediaReference.standalone(media: media)).start())
            }
        }
    }
    
    
    override func preloadStreamblePart() {
        if let context = context {
            if let media = media as? TelegramMediaFile, let fileSize = media.size {
                let reference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: media) : FileMediaReference.standalone(media: media)
                
                
                let preload = combineLatest(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: reference.resourceReference(media.resource), range: (0 ..< Int(2.0 * 1024 * 1024), .default), statsCategory: .video), fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: reference.resourceReference(media.resource), range: (max(0, fileSize - Int(256 * 1024)) ..< Int(Int32.max), .default), statsCategory: .video))
                
                partDisposable.set(preload.start())

            }
        }
    }
    
    
    override func copy() -> Any {
        return image.copy()
    }
    override var contents: Any? {
        return image.layer?.contents
    }
    
}
