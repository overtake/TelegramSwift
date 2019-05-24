//
//  MGalleryExternalVideoItem.swift
//  TelegramMac
//
//  Created by keepcoder on 19/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit
import AVFoundation
import AVKit


enum AVPlayerState : Equatable {
    case playing(duration: Float64)
    case paused(duration: Float64)
    case waiting
    
    @available(OSX 10.12, *)
    init(_ player: AVPlayer) {
        let duration: Float64
        if let item = player.currentItem {
            duration = CMTimeGetSeconds(item.duration)
        } else {
            duration = 0
        }
        switch player.timeControlStatus {
        case .playing:
            self = .playing(duration: duration)
        case .paused:
            self = .paused(duration: duration)
        case .waitingToPlayAtSpecifiedRate:
            self = .waiting
        }
    }
}

private final class GAVPlayer : AVPlayer {
    private var playerStatusContext = 0
    private let _playerState: ValuePromise<AVPlayerState> = ValuePromise(.waiting, ignoreRepeated: true)
    var playerState: Signal<AVPlayerState, NoError> {
        return _playerState.get() |> deliverOnMainQueue
    }
    
    var bufferingValue: ValuePromise<Bool> = ValuePromise(true, ignoreRepeated: true)
    
    override func pause() {
        super.pause()
    }
    override init(url: URL) {
        super.init(url: url)
    }
    override init(playerItem item: AVPlayerItem?) {
        super.init(playerItem: item)
        if #available(OSX 10.12, *) {
            addObserver(self, forKeyPath: "timeControlStatus", options: [.new, .initial], context: &playerStatusContext)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
        
        item?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.new, .initial], context: nil)
        item?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.new, .initial], context: nil)
        item?.addObserver(self, forKeyPath: "playbackBufferFull", options: [.new, .initial], context: nil)
    }
    
    override init() {
        super.init()
    }
    
    @objc private func playerDidEnd(_ notification: Notification) {
        seek(to: CMTime(seconds: 0, preferredTimescale: 1000000000));
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        //  Check status
        if keyPath == "timeControlStatus" && context == &playerStatusContext && change != nil
        {
            if #available(OSX 10.12, *) {
                _playerState.set(AVPlayerState(self))
            }
            //  Status is not unknown
            
        }
        
        if object is AVPlayerItem {
            switch keyPath {
            case "playbackBufferEmpty":
                bufferingValue.set(true)
            case "playbackLikelyToKeepUp":
                 bufferingValue.set(false)
            case "playbackBufferFull":
                 bufferingValue.set(false)
            default:
                break
            }
        }
    }
    
    deinit {
        if #available(OSX 10.12, *) {
            removeObserver(self, forKeyPath: "timeControlStatus")
        }
        self.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        self.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        self.currentItem?.removeObserver(self, forKeyPath: "playbackBufferFull")

        
        NotificationCenter.default.removeObserver(self)
    }
}

class VideoPlayerView : AVPlayerView {
    
    override func enterFullScreenMode(_ screen: NSScreen, withOptions options: [NSView.FullScreenModeOptionKey : Any]? = nil) -> Bool {
        return super.enterFullScreenMode(screen, withOptions: options)
    }
    
    var isPip: Bool = false
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateLayout()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateLayout()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateLayout()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateLayout()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLayout()
    }
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateLayout()
    }
    
    
    func rewindForward(_ seekDuration: Float64 = 15) {
        guard let player = player, let duration = player.currentItem?.duration else { return }
        let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = min(playerCurrentTime + seekDuration, CMTimeGetSeconds(duration))
        
        let time2: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
        player.seek(to: time2, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }
    func rewindBack(_ seekDuration: Float64 = 15) {
        guard let player = player else { return }
        
        let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
        var newTime = playerCurrentTime - seekDuration
        
        if newTime < 0 {
            newTime = 0
        }
        let time2: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
        player.seek(to: time2, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        
    }
    
    private func updateLayout() {
        let controls = HackUtils.findElements(byClass: "AVMovableView", in: self)?.first as? NSView
        if let controls = controls {
            if let pip = controls.subviews.last as? ImageButton {
                pip.setFrameOrigin(controls.frame.width - pip.frame.width - 80, controls.frame.height - pip.frame.height - 16)
            }
            controls._change(opacity: _mouseInside() ? 1 : 0, animated: true)
            
        }
        
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        updateLayout()
    }
    
    override func layout() {
        super.layout()
        updateLayout()
    }
}


class MGalleryExternalVideoItem: MGalleryItem {
    let content:TelegramMediaWebpageLoadedContent
    private let _media:TelegramMediaImage
    
    var mediaImage: TelegramMediaImage {
        return _media
    }
    
    private(set) var startTime: TimeInterval = 0
    private var playAfter:Bool = true
    private let _playerItem: Promise<GAVPlayer> = Promise()
    
    var playerState: Signal<AVPlayerState, NoError> {
        return _playerItem.get() |> mapToSignal { $0.playerState }
    }
    override init(_ context: AccountContext, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        
        
        
        let webpage = entry.webpage!
        
        var startTime:TimeInterval = 0
        if case let .Loaded(content) = webpage.content {
            self.content = content
            
            
            _ = ObjcUtils._youtubeVideoId(fromText: content.embedUrl, originalUrl: content.url, startTime: &startTime)
            
            self._media = content.image!
        } else {
            fatalError("content for external video not found")
        }
        super.init(context, entry, pagerSize)
        self.startTime = startTime
        
        _playerItem.set((path.get() |> distinctUntilChanged |> deliverOnMainQueue) |> map { path -> GAVPlayer in
            let url = URL(string: path) ?? URL(fileURLWithPath: path)
            return GAVPlayer(url: url)
            })
        
        disposable.set(combineLatest(_playerItem.get() |> deliverOnMainQueue, view.get() |> distinctUntilChanged |> deliverOnMainQueue |> map { $0 as! AVPlayerView }).start(next: { [weak self] player, view in
            if let strongSelf = self {
                view.player = player
                if strongSelf.playAfter {
                    strongSelf.playAfter = false
                    
                    player.play()
                    if strongSelf.startTime > 0 {
                        player.seek(to: CMTimeMake(value: Int64(strongSelf.startTime * 1000.0), timescale: 1000))
                    }
                }
                let controls = HackUtils.findElements(byClass: "AVMovableView", in: view)?.first as? NSView
                if let controls = controls, let pip = strongSelf.pipButton {
                    controls.addSubview(pip)
                    view.needsLayout = true
                }
            }
        }))
    
    }
    
    private var _cachedView: VideoPlayerView?
    private var pipButton: ImageButton?
    
    override func toggleFullScreen() {
        if let view = _cachedView {
            let controls = HackUtils.findElements(byClass: "AVMovableView", in: view)?.first as? NSView
            if let controls = controls {
                if let view = controls.subviews.first?.subviews.first?.subviews.first?.subviews.last?.subviews.first?.subviews.last {
                    if let view = view as? NSButton {
                        view.performClick(self)
                    }
                }
            }
        }
    }
    
    override func togglePlayerOrPause() {
        if let view = _cachedView, let player = view.player {
            switch player.rate {
            case 0:
                player.play()
            default:
                player.pause()
            }
        }
    }
    
    override func rewindBack() {
        _cachedView?.rewindBack()
    }
    override func rewindForward() {
        _cachedView?.rewindForward()
    }
    
    override func singleView() -> NSView {
        let view: VideoPlayerView
        if let _cachedView = _cachedView {
            view = _cachedView
        } else {
            view = VideoPlayerView()
        }
        view.showsFullScreenToggleButton = true
        view.showsFrameSteppingButtons = true
        view.controlsStyle = .floating
        view.autoresizingMask = []
        view.autoresizesSubviews = false
        
        let pip:ImageButton = ImageButton()
        pip.style = ControlStyle(highlightColor: .grayIcon)
        pip.set(image: #imageLiteral(resourceName: "Icon_PIPVideoEnable").precomposed(NSColor.white.withAlphaComponent(0.9)), for: .Normal)
        
        pip.set(handler: { [weak view, weak self] _ in
            if let view = view, let strongSelf = self, let viewer = viewer {
                let frame = view.window!.convertToScreen(view.convert(view.bounds, to: nil))
                if !viewer.pager.isFullScreen {
                    closeGalleryViewer(false)
                    showLegacyPipVideo(view, viewer: viewer, item: strongSelf, origin: frame.origin, delegate: viewer.delegate, contentInteractions: viewer.contentInteractions, type: viewer.type)
                }
            }
        }, for: .Down)
        
        _ = pip.sizeToFit()
        
        pipButton = pip
        
        
        
        _cachedView = view
        return view
        
    }
    private var isPausedGlobalPlayer: Bool = false
    
    override func appear(for view: NSView?) {
        super.appear(for: view)
        
        pausepip()
        
        if let pauseMusic = globalAudio?.pause() {
            isPausedGlobalPlayer = pauseMusic
        }
        
        if let view = view as? AVPlayerView {
            if let player = view.player {
                player.play()
                playAfter = false
            } else {
                playAfter = true
            }
        } else {
            playAfter = true
        }
    }
    
    override var maxMagnify: CGFloat {
        return min(pagerSize.width / sizeValue.width, pagerSize.height / sizeValue.height)
    }
    
    override func disappear(for view: NSView?) {
        super.disappear(for: view)
        if isPausedGlobalPlayer {
            _ = globalAudio?.play()
        }
        if let view = view as? VideoPlayerView, !view.isPip {
            view.player?.pause()
        }
        playAfter = false
    }
    
    override var status: Signal<MediaResourceStatus, NoError> {
        return _playerItem.get() |> mapToSignal { value in
            return value.bufferingValue.get() |> map { buffering in
                return buffering ? .Fetching(isActive: true, progress: 0.8) : .Local
            }
        }
    }
 
    override var sizeValue: NSSize {
        return NSMakeSize(1280, 720).fitted(pagerSize)
    }
    
    override func request(immediately: Bool) {
        
        let webpage = entry.webpage!

        
        let signal:Signal<(TransformImageArguments) -> DrawingContext?,NoError> = chatMessagePhoto(account: context.account, imageReference: ImageMediaReference.webPage(webPage: WebpageReference(webpage), media: _media), scale: System.backingScale)
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: sizeValue, boundingSize: sizeValue, intrinsicInsets: NSEdgeInsets())
        let result = signal |> deliverOn(graphicsThreadPool) |> mapToThrottled { transform -> Signal<CGImage?, NoError> in
            return .single(transform(arguments)?.generateImage())
        }
        
        switch webpage.content {
        case let .Loaded(content):
            _ = sharedVideoLoader.fetch(for: content).start()
        default:
            break
        }
        
        self.path.set(sharedVideoLoader.status(for: content) |> `catch` {_ in return .complete()} |> mapToSignal { (status) -> Signal<String, NoError> in
            if let status = status, case let .loaded(video) = status {
                return .single(video.stream)
            }
            return .complete()
        } |> deliverOnMainQueue)
        
        self.image.set(result |> map { .image($0) } |> deliverOnMainQueue)
        
        fetch()
    }
    
    
    
    
    override func fetch() -> Void {
        fetching.set(sharedVideoLoader.fetch(for: content).start())
    }
    
}
