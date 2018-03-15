import Foundation
import SwiftSignalKitMac

final class MediaPlaybackBuffers {
    let audioBuffer: MediaTrackFrameBuffer?
    let videoBuffer: MediaTrackFrameBuffer?
    
    init(audioBuffer: MediaTrackFrameBuffer?, videoBuffer: MediaTrackFrameBuffer?) {
        self.audioBuffer = audioBuffer
        self.videoBuffer = videoBuffer
    }
}
