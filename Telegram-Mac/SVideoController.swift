//
//  VideoStreamingTestModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/11/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox
import RangeSet
import IOKit.pwr_mgt
import TelegramMedia

enum SVideoStyle {
    case regular
    case pictureInPicture
}



class SVideoController: GenericViewController<SVideoView>, PictureInPictureControl {
    
    
   
    
    
    var style: SVideoStyle = .regular
    private var fullScreenWindow: Window?
    private var fullScreenRestoreState: (rect: NSRect, view: NSView)?
    private let mediaPlayer: MediaPlayer
    private let reference: FileMediaReference
    private let statusDisposable = MetaDisposable()
    private let bufferingDisposable = MetaDisposable()
    private let hideOnIdleDisposable = MetaDisposable()
    private let hideControlsDisposable = MetaDisposable()
    private let postbox: Postbox
    private var pictureInPicture: Bool = false
    private var hideControls: ValuePromise<Bool> = ValuePromise(true, ignoreRepeated: true)
    private var controlsIsHidden: Bool = false
    var togglePictureInPictureImpl:((Bool, PictureInPictureControl)->Void)?
    
    private var isPaused: Bool = true
    private var forceHiddenControls: Bool = false
    private var _videoFramePreview: MediaPlayerFramePreview?
    private var mode: PictureInPictureControlMode = .normal
    
    private var updateControls: SwiftSignalKit.Timer?
    
    private var videoFramePreview: MediaPlayerFramePreview {
        if let videoFramePreview = _videoFramePreview {
            return videoFramePreview
        } else {
            self._videoFramePreview = MediaPlayerFramePreview(postbox: postbox, fileReference: reference)
        }
        return _videoFramePreview!
    }
    
    
    func setMode(_ mode: PictureInPictureControlMode, animated: Bool) {
        genericView.setMode(mode, animated: animated)
        self.mode = mode
    }
    
    private var scrubbingFrame = Promise<MediaPlayerFramePreviewResult?>(nil)
    private var scrubbingFrames = false
    private var scrubbingFrameDisposable: Disposable?

    
    init(postbox: Postbox, reference: FileMediaReference, fetchAutomatically: Bool = false) {
        self.reference = reference
        self.postbox = postbox
        mediaPlayer = MediaPlayer(postbox: postbox, userLocation: reference.userLocation, userContentType: reference.userContentType, reference: reference.resourceReference(reference.media.resource), streamable: reference.media.isStreamable, video: true, preferSoftwareDecoding: false, enableSound: true, baseRate: FastSettings.playingVideoRate, volume: FastSettings.volumeRate, fetchAutomatically: fetchAutomatically)
        super.init()
        bar = .init(height: 0)
    }
    
    var status: Signal<MediaPlayerStatus, NoError> {
        return mediaPlayer.status
    }
    
    func play(_ startTime: TimeInterval? = nil) {
        mediaPlayer.play()
        self.isPaused = false
        if let startTime = startTime, startTime > 0 {
            mediaPlayer.seek(timestamp: startTime)
        }
    }
    
    func setBaseRate(_ baseRate: Double) {        
        mediaPlayer.setBaseRate(baseRate)
        FastSettings.setPlayingVideoRate(baseRate)
    }
    
    func playOrPause() {
        self.isPaused = !self.isPaused
        mediaPlayer.togglePlayPause()
        if let status = genericView.status {
            switch status.status {
            case .buffering:
                mediaPlayer.seek(timestamp: status.timestamp / status.duration)
            default:
                break
            }
        }
    }
    
    func pause() {
        self.isPaused = true
        mediaPlayer.pause()
    }
    
    func play() {
        self.isPaused = false
        self.play(nil)
    }
    
    
    func didEnter() {
        
    }
    
    func didExit() {
        
    }
    
    func isPlaying() -> Bool {
        return !self.isPaused
    }
    
    private func updateIdleTimer() {
        NSCursor.unhide()
        hideOnIdleDisposable.set((Signal<NoValue, NoError>.complete() |> delay(1.0, queue: Queue.mainQueue())).start(completed: { [weak self] in
            guard let `self` = self else {return}
            let hide = !self.genericView.isInMenu
            self.hideControls.set(hide)
            if !self.pictureInPicture, !self.isPaused, hide {
                NSCursor.hide()
            }
        }))
    }
    
    private func updateControlVisibility(_ isMouseUpOrDown: Bool = false) {
        updateIdleTimer()
        
        
        if let rootView = genericView.superview?.superview {
            var hide = !genericView._mouseInside() && !rootView.isHidden && (NSEvent.pressedMouseButtons & (1 << 0)) == 0
            
           
            if !hide, (NSEvent.pressedMouseButtons & (1 << 0)) != 0 {
                hide = genericView.controlsStyle.isPip
            }

            
            if self.fullScreenWindow != nil && isMouseUpOrDown, !genericView.insideControls {
                hide = true
                if !self.isPaused {
                    NSCursor.hide()
                }
            }
            if contextMenuOnScreen() {
                hide = false
            }
            hideControls.set(hide || forceHiddenControls)
        } else {
            hideControls.set(forceHiddenControls)
        }
    }
    
    
    
    private func setHandlersOn(window: Window) {
        
        updateIdleTimer()
        
        let mouseInsidePlayer = genericView.mediaPlayer.mouseInside()
        
        hideControls.set(!mouseInsidePlayer || forceHiddenControls)
        
        window.set(mouseHandler: { [weak self] (event) -> KeyHandlerResult in
            if let window = self?.genericView.window, let contentView = window.contentView {
                let point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                if contentView.hitTest(point) != nil {
                    self?.updateControlVisibility()
                }
            }
            return .rejected
        }, with: self, for: .mouseMoved, priority: .modal)
        
        window.set(mouseHandler: { [weak self] (event) -> KeyHandlerResult in
            if let window = self?.genericView.window, let contentView = window.contentView {
                let point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                if contentView.hitTest(point) != nil {
                    self?.updateControlVisibility()
                }
            }
            return .rejected
        }, with: self, for: .mouseExited, priority: .modal)
        
        window.set(mouseHandler: { [weak self] (event) -> KeyHandlerResult in
            self?.updateIdleTimer()
            
            return .rejected
        }, with: self, for: .leftMouseDragged, priority: .modal)
        
        window.set(mouseHandler: { [weak self] (event) -> KeyHandlerResult in
            if let window = self?.genericView.window, let contentView = window.contentView {
                let point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                if contentView.hitTest(point) != nil {
                    self?.updateControlVisibility()
                }
            }
            return .rejected
        }, with: self, for: .mouseEntered, priority: .modal)
        
        window.set(mouseHandler: { [weak self] (event) -> KeyHandlerResult in
            if self?.genericView.mediaPlayer.mouseInside() == true {
                self?.updateControlVisibility(true)
            }
            return .rejected
        }, with: self, for: .leftMouseDown, priority: .modal)
        
        window.set(mouseHandler: { [weak self] (event) -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            if let window = self.genericView.window, let contentView = window.contentView {
                let point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                if contentView.hitTest(point) != nil {
                    self.updateControlVisibility(true)
                }
            }
            self.genericView.subviews.last?.mouseUp(with: event)
            return .rejected
        }, with: self, for: .leftMouseUp, priority: .modal)
        
//        self.updateControls = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: { [weak self] in
//            self?.updateControlVisibility()
//        }, queue: .mainQueue())
//
//        self.updateControls?.start()
        
    }
    
    private var assertionID: IOPMAssertionID = 0
    private var success: IOReturn?
    
    private func disableScreenSleep() -> Bool? {
        guard success == nil else { return nil }
        success = IOPMAssertionCreateWithName( kIOPMAssertionTypeNoDisplaySleep as CFString,
                                               IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                               "Video Playing" as CFString,
                                               &assertionID )
        return success == kIOReturnSuccess
    }
    
    private func  enableScreenSleep() -> Bool {
        if success != nil {
            success = IOPMAssertionRelease(assertionID)
            success = nil
            return true
        }
        return false
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
      
        if let window = window {
            setHandlersOn(window: window)
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideOnIdleDisposable.set(nil)
        _ = enableScreenSleep()
        NSCursor.unhide()
        window?.removeAllHandlers(for: self)
    }
    
    var isPictureInPicture: Bool {
        return self.pictureInPicture
    }
    
    
    func hideControlsIfNeeded(_ forceHideControls: Bool = false) -> Bool {
        self.forceHiddenControls = forceHideControls
        if !controlsIsHidden {
            hideControls.set(true)
            return true
        }
        
        return false
    }
    
    func unhideControlsIfNeeded(_ forceUnhideControls: Bool = true) -> Bool {
        forceHiddenControls = !forceUnhideControls
        if controlsIsHidden {
            hideControls.set(forceUnhideControls)
            return true
        }
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.layerContentsRedrawPolicy = .duringViewResize

        
        mediaPlayer.attachPlayerView(genericView.mediaPlayer)
        genericView.isStreamable = reference.media.isStreamable
        hideControlsDisposable.set(hideControls.get().start(next: { [weak self] hide in
            self?.genericView.hideControls(hide, animated: true)
            self?.controlsIsHidden = hide
        }))
        
        
        let statusValue:Atomic<MediaPlayerStatus?> = Atomic(value: nil)
        let updateTemporaryStatus:(_ f: (MediaPlayerStatus?)->MediaPlayerStatus?) -> Void = { [weak self] f in
            self?.genericView.status = statusValue.modify(f)
        }
        
        let duration = Double(reference.media.duration ?? 0)
        
        statusDisposable.set((mediaPlayer.status |> deliverOnMainQueue).start(next: { [weak self] status in
            let status = status.withUpdatedDuration(status.duration != 0 ? status.duration : duration)
            switch status.status {
            case .playing:
                _ = self?.disableScreenSleep()
            case let .buffering(_, whilePlaying):
                if whilePlaying {
                    _ = self?.disableScreenSleep()
                } else {
                    _ = self?.enableScreenSleep()
                }
            case .paused:
                _ = self?.enableScreenSleep()
            }
            _ = statusValue.swap(status)
           
            self?.genericView.status = status
        }))
        let size = reference.media.resource.size ?? 0
        
        let bufferingStatus = postbox.mediaBox.resourceRangesStatus(reference.media.resource)
            |> map { ranges -> (RangeSet<Int64>, Int64) in
                return (ranges, size)
        } |> deliverOnMainQueue
        
        bufferingDisposable.set(bufferingStatus.start(next: { [weak self] bufferingStatus in
            self?.genericView.bufferingStatus = bufferingStatus
        }))
        
        self.scrubbingFrameDisposable = (self.scrubbingFrame.get()
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let `self` = self else {
                    return
                }
            let live = (NSEvent.pressedMouseButtons & (1 << 0)) != 0 && self.genericView.mouseDownIncontrols
                if let result = result {
                    self.genericView.showScrubblerPreviewIfNeeded(live: live)
                    self.genericView.setCurrentScrubblingState(result, live: live)
                } else {
                    self.genericView.hideScrubblerPreviewIfNeeded(live: live)
                    // empty image
                }
            })

        var paused: Bool? = nil
        
        genericView.interactions = SVideoInteractions(playOrPause: { [weak self] in
            self?.playOrPause()
        }, rewind: { [weak self] timestamp in
            self?.mediaPlayer.seek(timestamp: timestamp)
        }, scrobbling: { [weak self] timecode in
            guard let `self` = self else { return }

            if let timecode = timecode {
                if !self.scrubbingFrames {
                    self.scrubbingFrames = true
                    self.scrubbingFrame.set(self.videoFramePreview.generatedFrames
                        |> map(Optional.init))
                }
                self.videoFramePreview.generateFrame(at: timecode)
            } else {
                self.scrubbingFrame.set(.single(nil))
                self.videoFramePreview.cancelPendingFrames()
                self.scrubbingFrames = false
            }
        }, volume: { [weak self] value in
            self?.mediaPlayer.setVolume(value)
            FastSettings.setVolumeRate(value)
            updateTemporaryStatus { status in
                return status?.withUpdatedVolume(value)
            }
        }, toggleFullScreen: { [weak self] in
            self?.toggleFullScreen()
        }, togglePictureInPicture: { [weak self] in
            self?.togglePictureInPicture()
        }, closePictureInPicture: {
            closePipVideo()
        }, setBaseRate: { [weak self] rate in
            self?.setBaseRate(rate)
        }, pause: { [weak self] in
            if self?.isPaused == false {
                self?.pause()
                paused = true
            }
        }, play: { [weak self] in
            if paused == true {
                self?.play()
                paused = nil
            }
        })
        
        if let duration = reference.media.duration, duration < 30 {
            mediaPlayer.actionAtEnd = .loop({ [weak self] in
                Queue.mainQueue().async {
                    self?.updateIdleTimer()
                }
            })
        } else {
            mediaPlayer.actionAtEnd = .action { [weak self] in
                Queue.mainQueue().async {
                    self?.mediaPlayer.seek(timestamp: 0)
                    self?.mediaPlayer.pause()
                    self?.updateIdleTimer()
                    self?.hideControls.set(false)
                }
            }
        }
        
        readyOnce()
    }
    
    func togglePictureInPicture() {
        if let function = togglePictureInPictureImpl {
            if fullScreenRestoreState != nil {
                toggleFullScreen()
            }
            self.pictureInPicture = !pictureInPicture
            window?.removeAllHandlers(for: self)
            function(pictureInPicture, self)
            if let window = view.window?.contentView?.window as? Window {
                setHandlersOn(window: window)
            }
            
            genericView.set(isInPictureInPicture: pictureInPicture)
        }
    }
    
    func togglePlayerOrPause() {
        playOrPause()
    }
    
    
    func rewindBackward() {
        genericView.rewindBackward()
    }
    func rewindForward() {
        genericView.rewindForward()
    }
    
    var isFullscreen: Bool {
        return self.fullScreenRestoreState != nil
    }
    
    func toggleFullScreen() {
        if let screen = NSScreen.main {
            if let window = fullScreenWindow, let state = fullScreenRestoreState {
                
                var topInset: CGFloat = 0
                
                if #available(macOS 12.0, *) {
                    topInset = screen.safeAreaInsets.top
                }
                
                
                window.setFrame(NSMakeRect(screen.frame.minX + state.rect.minX, screen.frame.minY + screen.frame.height - state.rect.maxY - topInset, state.rect.width, state.rect.height), display: true, animate: true)
                window.orderOut(nil)
                view.frame = state.rect
                state.view.addSubview(view)
                
                genericView.set(isInFullScreen: false)
                genericView.mediaPlayer.setVideoLayerGravity(.resizeAspectFill)

                
                window.removeAllHandlers(for: self)
                if let window = self.window {
                    setHandlersOn(window: window)
                }
                
                self.fullScreenWindow = nil
                self.fullScreenRestoreState = nil
            } else {
                
                genericView.mediaPlayer.setVideoLayerGravity(.resizeAspect)

                
                fullScreenRestoreState = (rect: view.frame, view: view.superview!)
                fullScreenWindow = Window(contentRect: NSMakeRect(view.frame.minX, screen.frame.height - view.frame.maxY, view.frame.width, view.frame.height), styleMask: [.fullSizeContentView, .borderless], backing: .buffered, defer: true, screen: screen)
                
                setHandlersOn(window: fullScreenWindow!)
                window?.removeAllHandlers(for: self)
                
                
                fullScreenWindow?.isOpaque = true
                fullScreenWindow?.hasShadow = false
                fullScreenWindow?.level = .screenSaver
                self.view.frame = self.view.bounds
                fullScreenWindow?.contentView?.addSubview(self.view)
                fullScreenWindow?.orderFront(nil)
                genericView.set(isInFullScreen: true)
                fullScreenWindow?.becomeKey()
                fullScreenWindow?.setFrame(screen.frame, display: true, animate: true)
            }
        }
    }
    
    deinit {
        statusDisposable.dispose()
        bufferingDisposable.dispose()
        hideOnIdleDisposable.dispose()
        hideControlsDisposable.dispose()
        updateControls?.invalidate()
        _ = IOPMAssertionRelease(assertionID)
        NSCursor.unhide()
    }
    
}
