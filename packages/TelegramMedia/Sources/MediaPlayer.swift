import Foundation
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore
import MediaPlayer
import Postbox
import AppKit

private let traceEvents = false

private struct MediaPlayerControlTimebase {
    let timebase: CMTimebase
    let isAudio: Bool
    init(timebase: CMTimebase, isAudio: Bool) {
        self.timebase = timebase
        self.isAudio = isAudio
    }
}

private enum MediaPlayerPlaybackAction {
    case play
    case pause
}



private final class MediaPlayerLoadedState {
    let frameSource: MediaFrameSource
    let mediaBuffers: MediaPlaybackBuffers
    let controlTimebase: MediaPlayerControlTimebase
    var lostAudioSession: Bool = false
    var extraVideoFrames: ([MediaTrackFrame], CMTime)?
    init(frameSource: MediaFrameSource, mediaBuffers: MediaPlaybackBuffers, controlTimebase: MediaPlayerControlTimebase) {
        self.frameSource = frameSource
        self.mediaBuffers = mediaBuffers
        self.controlTimebase = controlTimebase
    }
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

private enum MediaPlayerState {
    case empty
    case seeking(frameSource: MediaFrameSource, timestamp: Double, disposable: Disposable, action: MediaPlayerPlaybackAction, enableSound: Bool)
    case paused(MediaPlayerLoadedState)
    case playing(MediaPlayerLoadedState)
}

public enum MediaPlayerActionAtEnd {
    case loop((() -> Void)?)
    case action(() -> Void)
    case loopDisablingSound(() -> Void)
    case stop
}

private final class MediaPlayerAudioRendererContext {
    let renderer: MediaPlayerAudioRenderer
    var requestedFrames = false
    
    init(renderer: MediaPlayerAudioRenderer) {
        self.renderer = renderer
    }
}

private final class MediaPlayerContext {
    private let queue: Queue
    
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let userContentType: MediaResourceUserContentType
    private let resourceReference: MediaResourceReference
    private let streamable: Bool
    private let video: Bool
    private let isSeekable: Bool
    private let preferSoftwareDecoding: Bool
    private var enableSound: Bool
    private var baseRate: Double
    private var volume: Float
    private let fetchAutomatically: Bool
    private var playAndRecord: Bool
    private var keepAudioSessionWhilePaused: Bool
    private var initialTimebase: CMTimebase?
    private var seekId: Int = 0
    
    private var state: MediaPlayerState = .empty {
        didSet {
            assert(queue.isCurrent())
        }
    }
    private var audioRenderer: MediaPlayerAudioRendererContext?
    private var forceAudioToSpeaker = false
    fileprivate let videoRenderer: VideoPlayerProxy
    
    private var tickTimer: SwiftSignalKit.Timer?
    
    private var lastStatusUpdateTimestamp: Double?
    private let playerStatus: ValuePromise<MediaPlayerStatus>
    
    fileprivate var actionAtEnd: MediaPlayerActionAtEnd = .stop
    
    fileprivate var timebasePromise: Promise<CMTimebase?> = Promise()
    
    private var stoppedAtEnd = false
    
    init(queue: Queue, playerStatus: ValuePromise<MediaPlayerStatus>, postbox: Postbox, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, resourceReference: MediaResourceReference, streamable: Bool, video: Bool, isSeekable: Bool, preferSoftwareDecoding: Bool, playAutomatically: Bool, enableSound: Bool, baseRate: Double, volume: Float, fetchAutomatically: Bool, playAndRecord: Bool, keepAudioSessionWhilePaused: Bool, initialTimebase: CMTimebase?) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.initialTimebase = initialTimebase
        self.playerStatus = playerStatus
        self.postbox = postbox
        self.userLocation = userLocation
        self.userContentType = userContentType
        self.resourceReference = resourceReference
        self.streamable = streamable
        self.video = video
        self.isSeekable = isSeekable
        self.preferSoftwareDecoding = preferSoftwareDecoding
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.volume = volume
        self.fetchAutomatically = fetchAutomatically
        self.playAndRecord = playAndRecord
        self.keepAudioSessionWhilePaused = keepAudioSessionWhilePaused
        
        self.videoRenderer = VideoPlayerProxy(queue: queue)
        
        self.videoRenderer.visibilityUpdated = { [weak self] value in
            assert(queue.isCurrent())
            
            if let strongSelf = self, !strongSelf.enableSound {
                switch strongSelf.state {
                case .empty:
                    if value && playAutomatically {
                        strongSelf.play()
                    }
                case .paused:
                    if value {
                        strongSelf.play()
                    }
                case .playing:
                    if !value {
                        strongSelf.pause(lostAudioSession: false)
                    }
                case let .seeking(_, _, _, action, _):
                    switch action {
                    case .pause:
                        if value {
                            strongSelf.play()
                        }
                    case .play:
                        if !value {
                            strongSelf.pause(lostAudioSession: false)
                        }
                    }
                }
            }
        }
        
        self.videoRenderer.takeFrameAndQueue = (queue, { [weak self] in
            assert(queue.isCurrent())
            
            if let strongSelf = self {
                var maybeLoadedState: MediaPlayerLoadedState?
                
                switch strongSelf.state {
                case .empty:
                    return .noFrames
                case let .paused(state):
                    maybeLoadedState = state
                case let .playing(state):
                    maybeLoadedState = state
                case .seeking:
                    return .noFrames
                }
                
                if let loadedState = maybeLoadedState, let videoBuffer = loadedState.mediaBuffers.videoBuffer {
                    if let (extraVideoFrames, atTime) = loadedState.extraVideoFrames {
                        loadedState.extraVideoFrames = nil
                        return .restoreState(extraVideoFrames, atTime)
                    } else {
                        return videoBuffer.takeFrame()
                    }
                } else {
                    return .noFrames
                }
            } else {
                return .noFrames
            }

        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        self.tickTimer?.invalidate()
        
        if case let .seeking(_, _, disposable, _, _) = self.state {
            disposable.dispose()
        }
    }
    
    fileprivate func seek(timestamp: Double) {
        assert(self.queue.isCurrent())
        
        let action: MediaPlayerPlaybackAction
        switch self.state {
        case .empty, .paused:
            action = .pause
        case .playing:
            action = .play
        case let .seeking(_, _, _, currentAction, _):
            action = currentAction
        }
        self.seek(timestamp: timestamp, action: action)
    }
    
    fileprivate func seek(timestamp: Double, action: MediaPlayerPlaybackAction) {
        assert(self.queue.isCurrent())
        
        var loadedState: MediaPlayerLoadedState?
        switch self.state {
        case .empty:
            break
        case let .playing(currentLoadedState):
            loadedState = currentLoadedState
        case let .paused(currentLoadedState):
            loadedState = currentLoadedState
        case let .seeking(previousFrameSource, previousTimestamp, previousDisposable, _, previousEnableSound):
            if previousTimestamp.isEqual(to: timestamp) && self.enableSound == previousEnableSound {
                self.state = .seeking(frameSource: previousFrameSource, timestamp: previousTimestamp, disposable: previousDisposable, action: action, enableSound: self.enableSound)
            } else {
                previousDisposable.dispose()
            }
        }
        
        self.tickTimer?.invalidate()
        if let loadedState = loadedState {
            self.seekId += 1
            
            if loadedState.controlTimebase.isAudio {
                self.audioRenderer?.renderer.setRate(0.0)
            } else {
                if !CMTimebaseGetRate(loadedState.controlTimebase.timebase).isEqual(to: 0.0) {
                    CMTimebaseSetRate(loadedState.controlTimebase.timebase, rate: 0.0)
                }
            }
            let currentTimestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
            var duration: Double = 0.0
            var videoStatus: MediaTrackFrameBufferStatus?
            if let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer {
                videoStatus = videoTrackFrameBuffer.status(at: currentTimestamp)
                duration = max(duration, CMTimeGetSeconds(videoTrackFrameBuffer.duration))
            }
            
            var audioStatus: MediaTrackFrameBufferStatus?
            if let audioTrackFrameBuffer = loadedState.mediaBuffers.audioBuffer {
                audioStatus = audioTrackFrameBuffer.status(at: currentTimestamp)
                duration = max(duration, CMTimeGetSeconds(audioTrackFrameBuffer.duration))
            }
            let status = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: duration, dimensions: CGSize(), timestamp: min(max(timestamp, 0.0), duration), baseRate: self.baseRate, volume: self.volume, seekId: self.seekId, status: .buffering(initial: false, whilePlaying: action == .play))
            self.playerStatus.set(status)
        } else {
            let status = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: 0.0, dimensions: CGSize(), timestamp: timestamp, baseRate: self.baseRate, volume: self.volume, seekId: self.seekId, status: .buffering(initial: false, whilePlaying: action == .play))
            self.playerStatus.set(status)
        }
        
        let frameSource = FFMpegMediaFrameSource(queue: self.queue, postbox: self.postbox, userLocation: self.userLocation, userContentType: self.userContentType, resourceReference: self.resourceReference, tempFilePath: nil, streamable: self.streamable, isSeekable: self.isSeekable, video: self.video, preferSoftwareDecoding: self.preferSoftwareDecoding, fetchAutomatically: self.fetchAutomatically)
        let disposable = MetaDisposable()
        self.state = .seeking(frameSource: frameSource, timestamp: timestamp, disposable: disposable, action: action, enableSound: self.enableSound)
        
        self.lastStatusUpdateTimestamp = nil
        
        let seekResult = frameSource.seek(timestamp: timestamp) |> deliverOn(self.queue)
        
        disposable.set(seekResult.start(next: { [weak self] seekResult in
            if let strongSelf = self {
                var result: MediaFrameSourceSeekResult?
                seekResult.with { object in
                    assert(strongSelf.queue.isCurrent())
                    result = object
                }
                if let result = result {
                    strongSelf.seekingCompleted(seekResult: result)
                } else {
                    assertionFailure()
                }
            }
            }, error: { _ in
        }))
    }
    
    fileprivate func seekingCompleted(seekResult: MediaFrameSourceSeekResult) {
        if traceEvents {
            print("seekingCompleted at \(CMTimeGetSeconds(seekResult.timestamp))")
        }
        
        assert(self.queue.isCurrent())
        
        guard case let .seeking(frameSource, _, _, action, _) = self.state else {
            assertionFailure()
            return
        }
        
        var buffers = seekResult.buffers
        if !self.enableSound {
            buffers = MediaPlaybackBuffers(audioBuffer: nil, videoBuffer: buffers.videoBuffer)
        }
        
        buffers.audioBuffer?.statusUpdated = { [weak self] in
            self?.tick()
        }
        buffers.videoBuffer?.statusUpdated = { [weak self] in
            self?.tick()
        }
        let controlTimebase: MediaPlayerControlTimebase
        
        if let _ = buffers.audioBuffer {
            let renderer: MediaPlayerAudioRenderer
            if let currentRenderer = self.audioRenderer, !currentRenderer.requestedFrames {
                renderer = currentRenderer.renderer
            } else {
                self.audioRenderer?.renderer.stop()
                self.audioRenderer = nil
                
                let queue = self.queue
                renderer = MediaPlayerAudioRenderer(playAndRecord: self.playAndRecord, forceAudioToSpeaker: self.forceAudioToSpeaker, baseRate: self.baseRate, volume: self.volume, updatedRate: { [weak self] in
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.tick()
                        }
                    }
                    }, audioPaused: { [weak self] in
                        queue.async {
                            if let strongSelf = self {
                                if strongSelf.enableSound {
                                    strongSelf.pause(lostAudioSession: true)
                                } else {
                                    strongSelf.seek(timestamp: 0.0, action: .play)
                                }
                            }
                        }
                })
                self.audioRenderer = MediaPlayerAudioRendererContext(renderer: renderer)
                renderer.start()
            }
            
            controlTimebase = MediaPlayerControlTimebase(timebase: renderer.audioTimebase, isAudio: true)
        } else {
            self.audioRenderer?.renderer.stop()
            self.audioRenderer = nil
            
            var timebase: CMTimebase?
            CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault, masterClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
            CMTimebaseSetRate(timebase!, rate: self.baseRate)
            CMTimebaseSetTime(timebase!, time: seekResult.timestamp)
            controlTimebase = MediaPlayerControlTimebase(timebase: timebase!, isAudio: false)
        }
        
        var loadedState: MediaPlayerLoadedState? = MediaPlayerLoadedState(frameSource: frameSource, mediaBuffers: buffers, controlTimebase: controlTimebase)
        loadedState!.extraVideoFrames = (seekResult.extraDecodedVideoFrames, seekResult.timestamp)
        self.timebasePromise.set(.single(loadedState!.controlTimebase.timebase))
        
        
        if let audioRenderer = self.audioRenderer?.renderer {
            let queue = self.queue
            
           
            
            audioRenderer.flushBuffers(at: seekResult.timestamp, completion: { [weak self] in
                queue.async { [weak self] in
                    if let strongSelf = self {
                        
                        if let loadedState = loadedState {
                            switch action {
                            case .play:
                                strongSelf.state = .playing(loadedState)
                                strongSelf.audioRenderer?.renderer.start()
                            case .pause:
                                strongSelf.state = .paused(loadedState)
                            }
                        }
                       

                        strongSelf.lastStatusUpdateTimestamp = nil
                        strongSelf.tick()
                    } else {
                        loadedState = nil
                    }
                }
            })
        } else {
            if let loadedState = loadedState {
                switch action {
                case .play:
                    self.state = .playing(loadedState)
                case .pause:
                    self.state = .paused(loadedState)
                }
            }
            
            
            self.lastStatusUpdateTimestamp = nil
            self.tick()
        }
    }
    
    fileprivate func play() {
        assert(self.queue.isCurrent())
        
        switch self.state {
        case .empty:
            self.lastStatusUpdateTimestamp = nil
            if self.enableSound {
                let queue = self.queue
                let renderer = MediaPlayerAudioRenderer( playAndRecord: self.playAndRecord, forceAudioToSpeaker: self.forceAudioToSpeaker, baseRate: self.baseRate, volume: self.volume, updatedRate: { [weak self] in
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.tick()
                        }
                    }
                    }, audioPaused: { [weak self] in
                        queue.async {
                            if let strongSelf = self {
                                if strongSelf.enableSound {
                                    strongSelf.pause(lostAudioSession: true)
                                } else {
                                    strongSelf.seek(timestamp: 0.0, action: .play)
                                }
                            }
                        }
                })
                self.audioRenderer = MediaPlayerAudioRendererContext(renderer: renderer)
                renderer.start()
            }
            self.seek(timestamp: 0.0, action: .play)
        case let .seeking(frameSource, timestamp, disposable, _, enableSound):
            self.state = .seeking(frameSource: frameSource, timestamp: timestamp, disposable: disposable, action: .play, enableSound: enableSound)
            self.lastStatusUpdateTimestamp = nil
        case let .paused(loadedState):
            if loadedState.lostAudioSession {
                let timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
                self.seek(timestamp: timestamp, action: .play)
            } else {
                self.lastStatusUpdateTimestamp = nil
                if self.stoppedAtEnd {
                    self.seek(timestamp: 0.0, action: .play)
                } else {
                    self.state = .playing(loadedState)
                    self.tick()
                }
            }
        case .playing:
            break
        }
    }
    
    fileprivate func playOnceWithSound(playAndRecord: Bool) {
        assert(self.queue.isCurrent())
        
        if !self.enableSound {
            self.lastStatusUpdateTimestamp = nil
            self.enableSound = true
            self.playAndRecord = playAndRecord
            self.seek(timestamp: 0.0, action: .play)
        }
    }
    
    fileprivate func toggleSoundEnabled() {
        assert(self.queue.isCurrent())
        
        var loadedState: MediaPlayerLoadedState?
        switch self.state {
        case .empty:
            break
        case let .playing(currentLoadedState):
            loadedState = currentLoadedState
        case let .paused(currentLoadedState):
            loadedState = currentLoadedState
        case let .seeking(_, timestamp, disposable, action, _):
            self.state = .empty
            disposable.dispose()
            self.enableSound = !self.enableSound
            self.seek(timestamp: timestamp, action: action)
        }
        
        if let loadedState = loadedState {
            self.enableSound = !self.enableSound
            let timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
            self.lastStatusUpdateTimestamp = timestamp
            self.seek(timestamp: timestamp)
        }
        
    }
    
    fileprivate func continuePlayingWithoutSound() {
        if self.enableSound {
            self.lastStatusUpdateTimestamp = nil
            
            var loadedState: MediaPlayerLoadedState?
            switch self.state {
            case .empty:
                break
            case let .playing(currentLoadedState):
                loadedState = currentLoadedState
            case let .paused(currentLoadedState):
                loadedState = currentLoadedState
            case let .seeking(_, timestamp, disposable, action, _):
                if self.enableSound {
                    self.state = .empty
                    disposable.dispose()
                    self.enableSound = false
                    self.seek(timestamp: timestamp, action: action)
                }
            }
            
            if let loadedState = loadedState {
                self.enableSound = false
                self.playAndRecord = false
                let timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
                self.seek(timestamp: timestamp, action: .play)
            }
        }
    }
    
    fileprivate func setBaseRate(_ baseRate: Double) {
        self.baseRate = baseRate
        self.lastStatusUpdateTimestamp = nil
        self.tick()
        self.audioRenderer?.renderer.setBaseRate(baseRate)
    }
    
    fileprivate func setForceAudioToSpeaker(_ value: Bool) {
        if self.forceAudioToSpeaker != value {
            self.forceAudioToSpeaker = value
            
            self.audioRenderer?.renderer.setForceAudioToSpeaker(value)
        }
    }
    
    fileprivate func setKeepAudioSessionWhilePaused(_ value: Bool) {
        if self.keepAudioSessionWhilePaused != value {
            self.keepAudioSessionWhilePaused = value
            
            var isPlaying = false
            switch self.state {
            case .playing:
                isPlaying = true
            case let .seeking(_, _, _, action, _):
                switch action {
                case .play:
                    isPlaying = true
                default:
                    break
                }
            default:
                break
            }
            if value && !isPlaying {
                self.audioRenderer?.renderer.stop()
            } else {
                self.audioRenderer?.renderer.start()
            }
        }
    }
    
    fileprivate func pause(lostAudioSession: Bool) {
        assert(self.queue.isCurrent())
        
        switch self.state {
        case .empty:
            break
        case let .seeking(frameSource, timestamp, disposable, _, enableSound):
            self.state = .seeking(frameSource: frameSource, timestamp: timestamp, disposable: disposable, action: .pause, enableSound: enableSound)
            self.lastStatusUpdateTimestamp = nil
        case let .paused(loadedState):
            if lostAudioSession {
                loadedState.lostAudioSession = true
            }
        case let .playing(loadedState):
            if lostAudioSession {
                loadedState.lostAudioSession = true
            }
            self.state = .paused(loadedState)
            self.lastStatusUpdateTimestamp = nil
            self.tick()
        }
    }
    
    
    fileprivate func togglePlayPause() {
        assert(self.queue.isCurrent())
        
        switch self.state {
        case .empty:
            self.play()
        case let .seeking(_, _, _, action, _):
            switch action {
            case .play:
                self.pause(lostAudioSession: false)
            case .pause:
                self.play()
            }
        case .paused:
            self.play()
        case .playing:
            self.pause(lostAudioSession: false)
        }
    }
    
    fileprivate func setVolume(_ volume: Float) {
        assert(self.queue.isCurrent())
        self.volume = volume
        audioRenderer?.renderer.setVolume(volume)
    }
    fileprivate func toggleVolumeOnOff() {
        assert(self.queue.isCurrent())
        if self.volume > 0 {
            self.volume = 0
        } else {
            self.volume = 1.0
        }
        audioRenderer?.renderer.setVolume(volume)
    }
    
    
    fileprivate func getVolume(_ completion: @escaping(Float) -> Void) {
        assert(self.queue.isCurrent())
        completion(volume)
    }
    
    
    private func tick() {
        self.tickTimer?.invalidate()
        
        var maybeLoadedState: MediaPlayerLoadedState?
        
        switch self.state {
        case .empty:
            return
        case let .paused(state):
            maybeLoadedState = state
        case let .playing(state):
            maybeLoadedState = state
        case .seeking:
            return
        }
        
        guard let loadedState = maybeLoadedState else {
            return
        }
        
        let timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
        if traceEvents {
            print("tick at \(timestamp)")
        }
        
        var duration: Double = 0.0
        var videoStatus: MediaTrackFrameBufferStatus?
        if let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer {
            videoStatus = videoTrackFrameBuffer.status(at: timestamp)
            duration = max(duration, CMTimeGetSeconds(videoTrackFrameBuffer.duration))
        }
        
        var audioStatus: MediaTrackFrameBufferStatus?
        if let audioTrackFrameBuffer = loadedState.mediaBuffers.audioBuffer {
            audioStatus = audioTrackFrameBuffer.status(at: timestamp)
            duration = max(duration, CMTimeGetSeconds(audioTrackFrameBuffer.duration))
        }
        
        var performActionAtEndNow = false
        
        var worstStatus: MediaTrackFrameBufferStatus?
        for status in [videoStatus, audioStatus] {
            if let status = status {
                if let worst = worstStatus {
                    switch status {
                    case .buffering:
                        worstStatus = status
                    case let .full(currentFullUntil):
                        switch worst {
                        case .buffering:
                            worstStatus = worst
                        case let .full(worstFullUntil):
                            if currentFullUntil < worstFullUntil {
                                worstStatus = status
                            } else {
                                worstStatus = worst
                            }
                        case .finished:
                            worstStatus = status
                        }
                    case let .finished(currentFinishedAt):
                        switch worst {
                        case .buffering, .full:
                            worstStatus = worst
                        case let .finished(worstFinishedAt):
                            if currentFinishedAt < worstFinishedAt {
                                worstStatus = worst
                            } else {
                                worstStatus = status
                            }
                        }
                    }
                } else {
                    worstStatus = status
                }
            }
        }
        
        var rate: Double
        var buffering = false
        
        if let worstStatus = worstStatus, case let .full(fullUntil) = worstStatus, fullUntil.isFinite {
            if case .playing = self.state {
                rate = self.baseRate
                
                let nextTickDelay = max(0.0, fullUntil - timestamp) / self.baseRate
                let tickTimer = SwiftSignalKit.Timer(timeout: nextTickDelay, repeat: false, completion: { [weak self] in
                    self?.tick()
                }, queue: self.queue)
                self.tickTimer = tickTimer
                tickTimer.start()
            } else {
                rate = 0.0
            }
        } else if let worstStatus = worstStatus, case let .finished(finishedAt) = worstStatus, finishedAt.isFinite {
            let nextTickDelay = max(0.0, finishedAt - timestamp) / self.baseRate
            if nextTickDelay.isLessThanOrEqualTo(0.0) {
                rate = 0.0
                performActionAtEndNow = true
            } else {
                if case .playing = self.state {
                    rate = self.baseRate
                    
                    let tickTimer = SwiftSignalKit.Timer(timeout: nextTickDelay, repeat: false, completion: { [weak self] in
                        self?.tick()
                    }, queue: self.queue)
                    self.tickTimer = tickTimer
                    tickTimer.start()
                } else {
                    rate = 0.0
                }
            }
        } else {
            buffering = true
            rate = 0.0
        }
        
        var reportRate = rate
        
        if loadedState.controlTimebase.isAudio {
            if rate.isEqual(to: 1.0) {
                self.audioRenderer?.renderer.start()
            }
            self.audioRenderer?.renderer.setRate(rate)
            if rate.isEqual(to: 1.0), let audioRenderer = self.audioRenderer {
                let timebaseRate = CMTimebaseGetRate(audioRenderer.renderer.audioTimebase)
                if !timebaseRate.isEqual(to: rate) {
                    reportRate = timebaseRate
                }
            }
        } else {
            if !CMTimebaseGetRate(loadedState.controlTimebase.timebase).isEqual(to: rate) {
                CMTimebaseSetRate(loadedState.controlTimebase.timebase, rate: rate)
            }
        }
        
        if let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer, videoTrackFrameBuffer.hasFrames {
            self.videoRenderer.state = (loadedState.controlTimebase.timebase, true, videoTrackFrameBuffer.rotationAngle, videoTrackFrameBuffer.aspect)
        }
        
        if let audioRenderer = self.audioRenderer, let audioTrackFrameBuffer = loadedState.mediaBuffers.audioBuffer, audioTrackFrameBuffer.hasFrames {
            let queue = self.queue
            audioRenderer.requestedFrames = true
            audioRenderer.renderer.beginRequestingFrames(queue: queue.queue, takeFrame: { [weak audioTrackFrameBuffer] in
                assert(queue.isCurrent())
                if let audioTrackFrameBuffer = audioTrackFrameBuffer {
                    return audioTrackFrameBuffer.takeFrame()
                } else {
                    return .noFrames
                }
            })
        }
        
        var statusTimestamp = CACurrentMediaTime()
        let playbackStatus: MediaPlayerPlaybackStatus
        if buffering {
            var whilePlaying = false
            if case .playing = self.state {
                whilePlaying = true
            }
            playbackStatus = .buffering(initial: false, whilePlaying: whilePlaying)
        } else if !rate.isZero {
            if reportRate.isZero {
                //playbackStatus = .buffering(initial: false, whilePlaying: true)
                playbackStatus = .playing
                statusTimestamp = 0.0
            } else {
                playbackStatus = .playing
            }
        } else {
            playbackStatus = .paused
        }
        if self.lastStatusUpdateTimestamp == nil || self.lastStatusUpdateTimestamp! < statusTimestamp + 500 {
            lastStatusUpdateTimestamp = statusTimestamp
            var reportTimestamp = timestamp
            if case .seeking(_, timestamp, _, _, _) = self.state {
                reportTimestamp = timestamp
            }
            let status = MediaPlayerStatus(generationTimestamp: statusTimestamp, duration: duration, dimensions: CGSize(), timestamp: min(max(reportTimestamp, 0.0), duration), baseRate: self.baseRate, volume: self.volume, seekId: self.seekId, status: playbackStatus)
            self.playerStatus.set(status)
        }
        
        
        if performActionAtEndNow {
            switch self.actionAtEnd {
            case let .loop(f):
                self.stoppedAtEnd = false
                self.seek(timestamp: 0.0, action: .play)
                f?()
            case .stop:
                self.stoppedAtEnd = true
                self.pause(lostAudioSession: false)
            case let .action(f):
                self.stoppedAtEnd = true
                //  self.pause(lostAudioSession: false)
                f()
            case let .loopDisablingSound(f):
                self.stoppedAtEnd = false
                self.enableSound = false
                self.seek(timestamp: 0.0, action: .play)
                f()
            }
        } else {
            self.stoppedAtEnd = false
        }
    }
}

public enum MediaPlayerPlaybackStatus: Equatable {
    case playing
    case paused
    case buffering(initial: Bool, whilePlaying: Bool)
    
    public static func ==(lhs: MediaPlayerPlaybackStatus, rhs: MediaPlayerPlaybackStatus) -> Bool {
        switch lhs {
        case .playing:
            if case .playing = rhs {
                return true
            } else {
                return false
            }
        case .paused:
            if case .paused = rhs {
                return true
            } else {
                return false
            }
        case let .buffering(initial, whilePlaying):
            if case .buffering(initial, whilePlaying) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public struct MediaPlayerStatus: Equatable {
    public let generationTimestamp: Double
    public let duration: Double
    public let dimensions: CGSize
    public let timestamp: Double
    public let baseRate: Double
    public let volume: Float
    public let seekId: Int
    public let status: MediaPlayerPlaybackStatus
    public init(generationTimestamp: Double, duration: Double, dimensions: CGSize, timestamp: Double, baseRate: Double, volume: Float, seekId: Int, status: MediaPlayerPlaybackStatus) {
        self.generationTimestamp = generationTimestamp
        self.duration = duration
        self.dimensions = dimensions
        self.timestamp = timestamp
        self.baseRate = baseRate
        self.volume = volume
        self.seekId = seekId
        self.status = status
    }
}


public extension MediaPlayerStatus {
    func withUpdatedVolume(_ volume: Float) -> MediaPlayerStatus {
        return MediaPlayerStatus(generationTimestamp: self.generationTimestamp, duration: self.duration, dimensions: self.dimensions, timestamp: self.timestamp, baseRate: self.baseRate, volume: volume, seekId: self.seekId, status: self.status)
    }
    func withUpdatedTimestamp(_ timestamp: Double) -> MediaPlayerStatus {
        return MediaPlayerStatus(generationTimestamp: self.generationTimestamp, duration: self.duration, dimensions: self.dimensions, timestamp: timestamp, baseRate: self.baseRate, volume: self.volume, seekId: self.seekId, status: self.status)
    }
    func withUpdatedDuration(_ duration: Double) -> MediaPlayerStatus {
        return MediaPlayerStatus(generationTimestamp: self.generationTimestamp, duration: duration, dimensions: self.dimensions, timestamp: self.timestamp, baseRate: self.baseRate, volume: self.volume, seekId: self.seekId, status: self.status)
    }
}

let playerQueue = Queue()


public final class MediaPlayer {
        
    private var contextRef: QueueLocalObject<MediaPlayerContext>
    
    private let timebasePromise:Promise<CMTimebase?> = Promise()
    
    public var timebase: Signal<CMTimebase?, NoError> {
        return timebasePromise.get()
    }
    
    private let statusValue = ValuePromise<MediaPlayerStatus>(ignoreRepeated: true)
    
    public var status: Signal<MediaPlayerStatus, NoError> {
        return self.statusValue.get()
    }
    
    public var actionAtEnd: MediaPlayerActionAtEnd = .stop {
        didSet {
            let value = self.actionAtEnd
            contextRef.with { context in
                context.actionAtEnd = value
            }
        }
    }
    
    public init(postbox: Postbox, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, reference: MediaResourceReference, streamable: Bool, video: Bool, preferSoftwareDecoding: Bool, isSeekable: Bool = true, playAutomatically: Bool = false, enableSound: Bool, baseRate: Double = 1.0, volume: Float = 0.8, fetchAutomatically: Bool, playAndRecord: Bool = false, keepAudioSessionWhilePaused: Bool = true, initialTimebase: CMTimebase? = nil) {
        
        self.statusValue.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: baseRate, volume: volume, seekId: 0, status: .paused))
        
        let statusValue = self.statusValue
        
        self.contextRef = QueueLocalObject(queue: playerQueue, generate: {
            return MediaPlayerContext(queue: playerQueue, playerStatus: statusValue, postbox: postbox, userLocation: userLocation, userContentType: userContentType, resourceReference: reference, streamable: streamable, video: video, isSeekable: isSeekable, preferSoftwareDecoding: preferSoftwareDecoding, playAutomatically: playAutomatically, enableSound: enableSound, baseRate: baseRate, volume: volume, fetchAutomatically: fetchAutomatically, playAndRecord: playAndRecord, keepAudioSessionWhilePaused: keepAudioSessionWhilePaused, initialTimebase: initialTimebase)

        })
        
        let timebasePromise = self.timebasePromise
        self.contextRef.with({ context in
            timebasePromise.set(context.timebasePromise.get())
        })

    }
    
    
    
    deinit {
        
    }
    
    public func play() {
        contextRef.with {
            $0.play()
        }
    }
    
    public func playOnceWithSound(playAndRecord: Bool) {
        contextRef.with {
            $0.playOnceWithSound(playAndRecord: playAndRecord)
        }
    }
    
    public func toggleSoundEnabled() {
        contextRef.with {
            $0.toggleSoundEnabled()
        }
    }
    
    public func continuePlayingWithoutSound() {
        contextRef.with {
            $0.continuePlayingWithoutSound()
        }
    }
    
    public func setForceAudioToSpeaker(_ value: Bool) {
        contextRef.with { context in
            context.setForceAudioToSpeaker(value)
        }
    }
    
    public func setKeepAudioSessionWhilePaused(_ value: Bool) {
        contextRef.with { context in
            context.setKeepAudioSessionWhilePaused(value)
        }
    }
    
    public func pause() {
        contextRef.with { context in
            context.pause(lostAudioSession: false)
        }
    }
    
    public func togglePlayPause() {
        contextRef.with { context in
            context.togglePlayPause()
        }
    }
    
    public func setVolume(_ volume: Float) {
        contextRef.with { context in
            context.setVolume(volume)
        }
    }
    
    public func toggleVolumeOnOff() {
        contextRef.with { context in
            context.toggleVolumeOnOff()
        }
    }
    
    public func getVolume(_ completion: @escaping(Float) -> Void) {
        contextRef.with { context in
            context.getVolume(completion)
        }
    }
    
    public func seek(timestamp: Double) {
        contextRef.with { context in
            context.seek(timestamp: timestamp)
        }
    }
    
    
    public func setBaseRate(_ baseRate: Double) {
        contextRef.with { context in
            context.setBaseRate(baseRate)
        }
    }
    
    public func attachPlayerView(_ node: MediaPlayerView) {
        let nodeRef: Unmanaged<MediaPlayerView> = Unmanaged.passRetained(node)
        contextRef.with { context in
            context.videoRenderer.attachNodeAndRelease(nodeRef)
        }
    }
}
