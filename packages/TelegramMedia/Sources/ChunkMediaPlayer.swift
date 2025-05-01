import Foundation
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore
import TelegramMediaPlayer
import QuartzCore

private struct ChunkMediaPlayerControlTimebase {
    let timebase: CMTimebase
    let isAudio: Bool
}

private enum ChunkMediaPlayerPlaybackAction {
    case play
    case pause
}

public enum MediaPlayerSeek {
    case none
    case start
    case automatic
    case timecode(Double)
}

private final class ChunkMediaPlayerPartLoadedState {
    let part: ChunkMediaPlayerPart
    let frameSource: MediaFrameSource
    var mediaBuffersDisposable: Disposable?
    var mediaBuffers: MediaPlaybackBuffers?
    var extraVideoFrames: ([MediaTrackFrame], CMTime)?
    
    init(part: ChunkMediaPlayerPart, frameSource: MediaFrameSource, mediaBuffers: MediaPlaybackBuffers?) {
        self.part = part
        self.frameSource = frameSource
        self.mediaBuffers = mediaBuffers
    }
    
    deinit {
        self.mediaBuffersDisposable?.dispose()
    }
}

private final class ChunkMediaPlayerLoadedState {
    var partStates: [ChunkMediaPlayerPartLoadedState] = []
    var controlTimebase: ChunkMediaPlayerControlTimebase?
    var lostAudioSession: Bool = false
}

private struct MediaPlayerSeekState {
    let duration: Double
}

private enum ChunkMediaPlayerState {
    case paused
    case playing
}

public enum ChunkMediaPlayerActionAtEnd {
    case loop((() -> Void)?)
    case action(() -> Void)
    case loopDisablingSound(() -> Void)
    case stop
}

public enum ChunkMediaPlayerPlayOnceWithSoundActionAtEnd {
    case loop
    case loopDisablingSound
    case stop
    case repeatIfNeeded
}



public enum ChunkMediaPlayerStreaming {
    case none
    case conservative
    case earlierStart
    case story
    
    public var enabled: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
    
    public var parameters: (Double, Double, Double) {
        switch self {
            case .none, .conservative:
                return (1.0, 2.0, 3.0)
            case .earlierStart:
                return (1.0, 1.0, 2.0)
            case .story:
                return (0.25, 0.5, 1.0)
        }
    }
    
    public var isSeekable: Bool {
        switch self {
        case .none, .conservative, .earlierStart:
            return true
        case .story:
            return false
        }
    }
}



public protocol ChunkMediaPlayer: AnyObject {
    var status: Signal<MediaPlayerStatus, NoError> { get }
    var audioLevelEvents: Signal<Float, NoError> { get }
    var actionAtEnd: ChunkMediaPlayerActionAtEnd { get set }
    
    func play()
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek)
    func setSoundMuted(soundMuted: Bool)
    func continueWithOverridingAmbientMode(isAmbient: Bool)
    func continuePlayingWithoutSound(seek: MediaPlayerSeek)
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool)
    func setForceAudioToSpeaker(_ value: Bool)
    func setKeepAudioSessionWhilePaused(_ value: Bool)
    func pause()
    func togglePlayPause(faded: Bool)
    func seek(timestamp: Double, play: Bool?)
    func setBaseRate(_ baseRate: Double)
    func setVolume(volume: Float)
}
