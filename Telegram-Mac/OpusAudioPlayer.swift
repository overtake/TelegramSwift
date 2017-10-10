//
//  OpusAudioPlayer.swift
//  TelegramMac
//
//  Created by keepcoder on 25/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import AudioUnit
import SwiftSignalKitMac
class OpusAudioPlayer: AudioPlayer, OpusBridgeDelegate {

    let bridge:OpusObjcBridge
    
    override init(_ path: String) {
        bridge = OpusObjcBridge(path: path)
        super.init(path)
        bridge.delegate = self
    }
    
    override func play() {
        bridge.play()
    }
    
    override func playFrom(position: TimeInterval) {
        bridge.play(fromPosition: position)
    }
    
    override func set(position: TimeInterval) {
        bridge.setCurrentPosition(position)
    }
    
    override func pause() {
        bridge.pause()
    }
    
    override func stop() {
        bridge.stop()
    }
    
    override var duration: TimeInterval {
        return bridge.duration()
    }
    
    override var currentTime: TimeInterval {
        return bridge.currentPositionSync(true)
    }
    
    func audioPlayerDidStartPlaying(_ audioPlayer: OpusObjcBridge!) {
        Queue.mainQueue().async {
            self.delegate?.audioPlayerDidStartPlaying(self)
        }
    }
    
    func audioPlayerDidFinishPlaying(_ audioPlayer: OpusObjcBridge!) {
        Queue.mainQueue().async {
            self.delegate?.audioPlayerDidFinishPlaying(self)
        }
    }
    
    func audioPlayerDidPause(_ audioPlayer: OpusObjcBridge!) {
        Queue.mainQueue().async {
            self.delegate?.audioPlayerDidPaused(self)
        }
    }
    
}
