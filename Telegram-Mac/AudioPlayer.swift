//
//  AudioPlayer.swift
//  TelegramMac
//
//  Created by keepcoder on 22/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac

protocol AudioPlayerDelegate : class {
    func audioPlayerDidFinishPlaying(_ audioPlayer:AudioPlayer)
    func audioPlayerDidStartPlaying(_ audioPlayer:AudioPlayer)
    func audioPlayerDidChangedTimebase(_ audioPlayer:AudioPlayer)

    func audioPlayerDidPaused(_ audioPlayer:AudioPlayer)
}

private var audioQueue:Queue = Queue(name: "AudioQueue")

class AudioPlayer: NSObject {
    
    
    
    let path:String
    public weak var delegate:AudioPlayerDelegate?
    
    static func player(for path:String) -> AudioPlayer {
        
        if OpusObjcBridge.canPlayFile(path) {
            return OpusAudioPlayer(path)
        }
        
        return NativeAudioPlayer(path)
    }
    
    init(_ path:String) {
        self.path = path
    }
    
    func play() {
        
    }
    func pause() {
        
    }
    func stop() {
        
    }
    func reset() {
        
    }
    func cleanup() {
        
    }
    
    deinit {
        cleanup()
    }
    
    func playFrom(position:TimeInterval) {
        
    }
    
    func set(position:TimeInterval) {
        
    }
    
    var duration:TimeInterval {
        return 0.0
    }
    
    var currentTime:TimeInterval {
        return 0.0
    }
    
    var queue:Queue {
        return audioQueue
    }
    
    var timebase:CMTimebase? {
        return nil
    }
    
}
