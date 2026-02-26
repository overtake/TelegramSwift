//
//  StoryView.swift
//  Telegram
//
//  Created by Mike Renoir on 24.04.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramMedia
import TelegramMediaPlayer

private var _nextSeekdId: Int = 0
private func nextSeekdId() -> Int {
    _nextSeekdId += 1
    return _nextSeekdId
}

class StoryLayoutView : Control {
    
    var isHighQuality: Bool = true
    
    var media: EngineMedia? {
        if let story = self.story {
            return isHighQuality ? story.media : (story.alternativeMediaList.first ?? story.media)
        }
        return nil
    }
    
    fileprivate var magnifyView: MagnifyView!
    
    fileprivate let ready: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    
    var getReady: Signal<Bool, NoError> {
        return self.ready.get() |> filter { $0 } |> take(1)
    }
    
    enum State : Equatable {
        case waiting
        case playing(MediaPlayerStatus)
        case paused(MediaPlayerStatus)
        case loading(MediaPlayerStatus)
        case finished
        
        var status: MediaPlayerStatus? {
            switch self {
            case let .playing(status), let .paused(status), let .loading(status):
                return status
            default:
                return nil
            }
        }
        
        func shouldBeUpdated(compared: State) -> Bool {
            switch self {
            case .paused:
                if case .paused = compared {
                    return false
                }
            case .playing:
                if case .playing = compared {
                    return true
                }
            case .waiting:
                if case .waiting = compared {
                    return false
                }
            case .loading:
                if case .loading = compared {
                    return false
                }
            case .finished:
                if case .finished = compared {
                    return false
                }
            }
            return true
        }
    }
    
    fileprivate(set) var story: EngineStoryItem?
    fileprivate var peer: Peer?
    fileprivate var context: AccountContext?
    
    func isEqual(to storyId: Int32?) -> Bool {
        return self.story?.id == storyId
    }
    
    private(set) var state: State = .waiting
    private var timer: SwiftSignalKit.Timer?
    
    var onStateUpdate:((State)->Void)? = nil
    private var timerTime: TimeInterval?
    
    private let disposable = MetaDisposable()
    private let priorityDisposable = MetaDisposable()
    private var shimmer: ShimmerLayer?
    fileprivate let overlay = View()
    
    fileprivate func updateState(_ state: State) {
        if self.state != state, state.shouldBeUpdated(compared: self.state) {
            self.state = state
            
            switch state {
            case let .playing(status):
                self.timerTime = CACurrentMediaTime()
                
                self.timer = SwiftSignalKit.Timer(timeout: self.duration - status.timestamp, repeat: false, completion: { [weak self] in
                    self?.updateState(.finished)
                }, queue: .mainQueue())
                self.timer?.start()
            default:
                self.timerTime = nil
                self.timer?.invalidate()
                self.timer = nil
            }
            self.onStateUpdate?(state)
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(overlay)
        self.updateLayout(size: self.frame.size, transition: .immediate)
        self.layer?.cornerRadius = 10
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.delayDisposable.dispose()
        self.priorityDisposable.dispose()
    }
    
    func animateAppearing(disappear: Bool) {
    
    }
    
    var statusSignal: Signal<MediaResourceStatus, NoError> {
        if let context = self.context {
            if let media = story?.media._asMedia() as? TelegramMediaImage {
                return chatMessagePhotoStatus(account: context.account, photo: media, dimension: NSMakeSize(10000, 10000))
            } else if let media = story?.media._asMedia() as? TelegramMediaFile {
                return context.account.postbox.mediaBox.resourceStatus(media.resource)
            }
        }
        return .single(.Local)
    }
    
    
    func update(context: AccountContext, peerId: PeerId, story: EngineStoryItem, peer: Peer?) {
        self.peer = peer
        self.context = context
        self.story = story
        self.magnifyView?.minMagnify = 1.0
        self.magnifyView?.maxMagnify = 2.0
    }
    
    func initializeStatus() {
        var isFirst: Bool = true
        disposable.set((statusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
            self?.updateStatus(status, animated: !isFirst)
            isFirst = false
        }))
    }
    
    func getStatus(_ status: MediaResourceStatus) -> MediaResourceStatus {
        return status
    }
    private let delayDisposable = MetaDisposable()
    
    fileprivate func updateStatus(_ status: MediaResourceStatus, animated: Bool) {
        let hasLoading: Bool
        switch status {
        case .Local:
            hasLoading = false
            delayDisposable.set(nil)
        default:
            hasLoading = true
            delayDisposable.set(nil)
        }
        if hasLoading {
            delayDisposable.set(delaySignal(1.5).start(completed: { [weak self] in
                guard let `self` = self else {
                    return
                }
                let current: ShimmerLayer
                if let local = self.shimmer {
                    current = local
                } else {
                    current = ShimmerLayer()
                    current.frame = self.bounds
                    self.shimmer = current
                    self.overlay.layer?.addSublayer(current)
                    if animated {
                        current.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                current.update(backgroundColor: nil, shimmeringColor: NSColor(0xffffff, 0.3), data: nil, size: self.frame.size, imageSize: self.frame.size)
                current.updateAbsoluteRect(self.bounds, within: self.frame.size)
            }))
            
        } else if let layer = self.shimmer {
            performSublayerRemoval(layer, animated: animated)
            self.shimmer = nil
        }
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    var currentTimestamp: Double {
        if let status = self.state.status {
            if let timerTime = timerTime {
                return status.timestamp + (CACurrentMediaTime() - timerTime)
            } else {
                return status.timestamp
            }
        } else {
            return 0
        }
    }
    
    var duration: Double {
        return 7
    }
    
    func seek(toProgress progress: Double) {
        
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: overlay, frame: size.bounds)
        if let magnifyView = magnifyView {
            transition.updateFrame(view: magnifyView, frame: size.bounds)
            magnifyView.contentSize = size
        }
        
        if let shimmer = self.shimmer {
            transition.updateFrame(layer: shimmer, frame: size.bounds)
            shimmer.updateAbsoluteRect(size.bounds, within: size)
        }
    }
    
    var magnify: MagnifyView? {
        return self.magnifyView
    }
    
    func restart() {
        self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: 0, baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: 0, status: .playing)))
    }
    
    func appear(isMuted: Bool, volume: Float) {
        self.updateState(.waiting)
        
        if let story = self.story, let context = self.context, let media = self.media {
            switch media {
            case let .image(image):
                if let representation = largestImageRepresentation(image.representations) {
                    self.priorityDisposable.set(context.engine.resources.pushPriorityDownload(resourceId: representation.resource.id.stringRepresentation))
                }
            case let .file(file):
                self.priorityDisposable.set(context.engine.resources.pushPriorityDownload(resourceId: file.resource.id.stringRepresentation))
            default:
                self.priorityDisposable.set(nil)
            }
        }
    }
    func disappear() {
        self.updateState(.waiting)
        self.priorityDisposable.set(nil)
    }
    func preload() {
        
    }
    func pause() {
        if case .paused = state.status?.status {
            
        } else {
            if let current = state.status {
                self.updateState(.paused(.init(generationTimestamp: current.generationTimestamp, duration: self.duration, dimensions: .zero, timestamp: current.timestamp + (CACurrentMediaTime() - current.generationTimestamp), baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: 0, status: .paused)))
            } else {
                self.updateState(.paused(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: 0, baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: 0, status: .paused)))
            }
        }
        
    }
    
    func bufferingPlay() {
        if case .playing = state.status?.status {
            
        } else {
            if let current = state.status {
                self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: current.timestamp, baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: 0, status: .playing)))
            } else {
                self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: 0, baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: 0, status: .playing)))
            }
        }
    }
    
    func bufferingPause() {
        if case .paused = state.status?.status {
            
        } else {
            if let current = state.status {
                self.updateState(.paused(.init(generationTimestamp: current.generationTimestamp, duration: self.duration, dimensions: .zero, timestamp: current.timestamp + (CACurrentMediaTime() - current.generationTimestamp), baseRate: 1, volume: 1, seekId: 0, status: .paused)))
            } else {
                self.updateState(.paused(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: 0, baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: 0, status: .paused)))
            }
        }
        
    }
    
    func play() {
        if case .playing = state.status?.status {
            
        } else {
            if let current = state.status {
                self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: current.timestamp, baseRate: 1, volume: 1, seekId: 0, status: .playing)))
            } else {
                self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: 0, baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: 0, status: .playing)))
            }
        }
        
    }
    
    
    func mute() {
        
    }
    func unmute() {
        
    }
    func setVolume(_ volume: Float) {
        
    }
    
    static public var size: NSSize = NSMakeSize(9 * 40, 16 * 40)
    
    static func makeView(for story: EngineStoryItem, isHighQuality: Bool, peerId: PeerId, peer: Peer?, context: AccountContext, frame: NSRect) -> StoryLayoutView {
        let view: StoryLayoutView
        if story.media._asMedia() is TelegramMediaImage {
            view = StoryImageView(frame: frame)
        } else if let file = story.media._asMedia() as? TelegramMediaFile, file.isVideo {
            view = StoryVideoView(frame: frame)
        } else {
            view = StoryUnsupportedView(frame: frame)
        }
        view.isHighQuality = isHighQuality
        view.update(context: context, peerId: peerId, story: story, peer: peer)
        view.initializeStatus()
        return view
    }
}


class StoryUnsupportedView : StoryLayoutView {
    private let textView = TextView()
    private let bgView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(bgView)
        addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(context: AccountContext, peerId: PeerId, story: EngineStoryItem, peer: Peer?) {
        super.update(context: context, peerId: peerId, story: story, peer: peer)
        
        bgView.backgroundColor = darkAppearance.colors.listBackground
        let attr = NSMutableAttributedString()
        _ = attr.append(string: strings().storyMediaUnsupported, color: darkAppearance.colors.text, font: .italic(.text))
        attr.detectLinks(type: [.Links], context: context)
        let layout = TextViewLayout(attr)
        layout.measure(width: frame.width - 40)
        layout.interactions = globalLinkExecutor
        textView.update(layout)
        
        ready.set(true)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        bgView.frame = bounds
        textView.resize(frame.width - 40)
        textView.center()
    }
}


class StoryImageView : StoryLayoutView {
    private let imageView = TransformImageView()
    private let awaitingDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        magnifyView = .init(imageView, contentSize: frameRect.size)
        addSubview(magnifyView, positioned: .below, relativeTo: overlay)
    }
    
    deinit {
        awaitingDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(context: AccountContext, peerId: PeerId, story: EngineStoryItem, peer: Peer?) {
        
        let updated = self.story?.id != story.id
        
        
        
        super.update(context: context, peerId: peerId, story: story, peer: peer)
        
        guard let peer = peer, let peerReference = PeerReference(peer), let media = self.media?._asMedia() else {
            return
        }
        
        imageView.preventsCapture = story.isForwardingDisabled && peerId != context.peerId
        
        var updateImageSignal: Signal<ImageDataTransformation, NoError>?
        
        
        let size = frame.size
        var dimensions: NSSize = size
                
        if let image = media as? TelegramMediaImage {
            dimensions = image.representations.first?.dimensions.size ?? dimensions
        } else if let file = media as? TelegramMediaFile {
            dimensions = file.dimensions?.size ?? dimensions
        }
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: .none)

        var resource: TelegramMediaResource? = nil
        if let image = media as? TelegramMediaImage  {
            let reference = ImageMediaReference.story(peer: peerReference, id: story.id, media: image)
            updateImageSignal = chatMessagePhoto(account: context.account, imageReference: reference, toRepresentationSize: NSMakeSize(10000, 10000), scale: backingScaleFactor, synchronousLoad: false, autoFetchFullSize: true)
            resource = image.representations.last?.resource
        } else if let file = media as? TelegramMediaFile {
            let fileReference = FileMediaReference.story(peer: peerReference, id: story.id, media: file)
            updateImageSignal = chatMessageVideo(account: context.account, fileReference: fileReference, scale: backingScaleFactor)
            resource = nil
        }
        
        self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor, positionFlags: nil), clearInstantly: false)

        self.awaitPlaying = !imageView.isFullyLoaded
        
        if let updateImageSignal = updateImageSignal, !self.imageView.isFullyLoaded {
            self.imageView.setSignal(updateImageSignal, animate: true, cacheImage: { [weak media, weak self] result in
                if let media = media {
                    cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: nil)
                }
                if result.image != nil {
                    self?.ready.set(true)
                }
                self?.awaitPlaying = !result.highQuality
            }, isProtected: story.isForwardingDisabled && peerId != context.peerId)
        } else {
            self.ready.set(true)
        }
        self.imageView.set(arguments: arguments)
        
        if let resource = resource {
            let signal = context.account.postbox.mediaBox.resourceStatus(resource, approximateSynchronousValue: true) |> deliverOnMainQueue
            awaitingDisposable.set(signal.start(next: { [weak self] status in
                self?.mediaStatus = status
            }))
        }
        delay(0.2, closure: { [weak self] in
            self?.ready.set(true)
        })
    }
    
    private var mediaStatus: MediaResourceStatus? {
        didSet {
            if mediaStatus == .Local {
                let awaiting = self.awaitPlaying
                self.awaitPlaying = false
                self.mediaStatus = nil
                if awaiting {
                    self.play()
                }
            }
        }
    }
    private var awaitPlaying: Bool = false
    override func play() {
        if let _ = mediaStatus {
            self.awaitPlaying = true
        } else {
            super.play()
        }
    }
    
    override func pause() {
        super.pause()
        awaitPlaying = false
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        transition.updateFrame(view: imageView, frame: size.bounds)
    }
}


class StoryVideoView : StoryImageView {
    private var mediaPlayer: MediaPlayer? = nil
    let view: MediaPlayerView
    
    private let statusDisposable = MetaDisposable()
        
    override func update(context: AccountContext, peerId: PeerId, story: EngineStoryItem, peer: Peer?) {
        super.update(context: context, peerId: peerId, story: story, peer: peer)
        
        guard let peer = peer, let peerReference = PeerReference(peer), let media = self.media?._asMedia() else {
            return
        }
        
        let file = media as! TelegramMediaFile
        let reference = FileMediaReference.story(peer: peerReference, id: story.id, media: file)
        let mediaPlayer = MediaPlayer(postbox: context.account.postbox, userLocation: .peer(peerId), userContentType: .video, reference: reference.resourceReference(file.resource), streamable: true, video: true, preferSoftwareDecoding: false, isSeekable: false, enableSound: true, volume: FastSettings.volumeStoryRate, fetchAutomatically: true)
                
        mediaPlayer.attachPlayerView(self.view)
        
        self.mediaPlayer = mediaPlayer
        mediaPlayer.actionAtEnd = .action({ [weak self] in
            DispatchQueue.main.async {
                self?.updateState(.finished)
            }
        })
        
        self.view.preventsCapture = story.isForwardingDisabled && peerId != context.peerId
        
        var shouldBeResumedAfterBufferring = false
        
        statusDisposable.set((mediaPlayer.status |> deliverOnMainQueue).start(next: { [weak self] status in
            if case let .buffering(_, whilePlaying) = status.status {
                self?.bufferingPause()
                shouldBeResumedAfterBufferring = whilePlaying
            } else if shouldBeResumedAfterBufferring {
                self?.bufferingPlay()
                shouldBeResumedAfterBufferring = false
            }
        }))
        
    }
    
    override var magnify: MagnifyView? {
        return nil
    }
    
    override var statusSignal: Signal<MediaResourceStatus, NoError> {
        if let context = self.context, let mediaPlayer = mediaPlayer {
            if let media = story?.media._asMedia() as? TelegramMediaFile {
                return combineLatest(context.account.postbox.mediaBox.resourceStatus(media.resource), mediaPlayer.status) |> map { resourceStatus, playerStatus in
                    switch resourceStatus {
                    case .Local:
                        return .Local
                    default:
                        switch playerStatus.status {
                        case .buffering:
                            return .Fetching(isActive: true, progress: 0)
                        default:
                            return .Local
                        }
                    }
                }
            }
        }
        return .single(.Local)
    }
    
    deinit {
        statusDisposable.dispose()
    }
    
    override var currentTimestamp: Double {
        if let status = self.state.status {
            return status.timestamp
        } else {
            return 0
        }
    }
    
    override var duration: Double {
        let file = self.story?.media._asMedia() as? TelegramMediaFile
        return max(Double(file?.videoDuration ?? 5.0), 1)//max(Double(max(duration, Double(file?.videoDuration ?? 5))), 1.0)
    }
    
    override func restart() {
        super.restart()
        mediaPlayer?.seek(timestamp: 0)
    }
    override func mute() {
        super.mute()
        mediaPlayer?.setVolume(0)
    }
    override func unmute() {
        mediaPlayer?.setVolume(1)
    }
    override func setVolume(_ volume: Float) {
        mediaPlayer?.setVolume(volume)
    }
    
    override func play() {
        super.play()
        mediaPlayer?.play()
    }
    override func pause() {
        super.pause()
        mediaPlayer?.pause()
    }
    override func appear(isMuted: Bool, volume: Float) {
        super.appear(isMuted: isMuted, volume: volume)
        mediaPlayer?.setVolume(isMuted ? 0 : volume)
    }
    override func disappear() {
        super.disappear()
        mediaPlayer?.pause()
        mediaPlayer?.seek(timestamp: 0)
    }

    required init(frame frameRect: NSRect) {
        self.view = MediaPlayerView()
        super.init(frame: frameRect)
        self.addSubview(view, positioned: .below, relativeTo: overlay)
        self.view.frame = bounds
        self.view.setVideoLayerGravity(.resizeAspectFill)
    }
    
    
    override func seek(toProgress progress: Double) {
        let seek = self.duration * progress
        let result = min(duration * Double(progress), duration)

        self.mediaPlayer?.seek(timestamp: seek)
        
        guard let status = state.status else {
            return
        }
        switch status.status {
        case .playing:
            self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: result, baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: nextSeekdId(), status: .playing)))
        case .paused:
            self.updateState(.paused(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: result, baseRate: 1, volume: FastSettings.volumeStoryRate, seekId: nextSeekdId(), status: .paused)))
        case .buffering:
            break
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        transition.updateFrame(view: view, frame: size.bounds)
    }
}
