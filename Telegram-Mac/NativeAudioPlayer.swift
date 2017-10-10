//
//  NativeAudioPlayer.swift
//  TelegramMac
//
//  Created by keepcoder on 22/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import AVFoundation

//kCMTimebaseNotification_EffectiveRateChanged
class NativeAudioPlayer: AudioPlayer {
    private var _player:AVPlayer
    private let item:AVPlayerItem
    
    private var observerContext = 0

    override init(_ path:String) {
        item = AVPlayerItem(url: URL(fileURLWithPath: path))
        _player = AVPlayer(playerItem: item)
        super.init(path)

        NotificationCenter.default.addObserver(self, selector: #selector(audioPlayerDidFinishPlaying(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
        
        
        var deviceId:AudioDeviceID = AudioDeviceID()
        var deviceIdRequest:AudioObjectPropertyAddress  = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
        var deviceIdSize:UInt32 = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceIdRequest, 0, nil, &deviceIdSize, &deviceId) == noErr {
            var masterClock:CMClock?
            CMAudioDeviceClockCreateFromAudioDeviceID(kCFAllocatorDefault, deviceId, &masterClock)
            _player.masterClock = masterClock
        }
        
        item.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.initial, .new], context: &observerContext)
        item.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.timebase), options: [.initial, .new], context: &observerContext)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard context == &observerContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        guard let keyPath = keyPath else {
            return
        }
        
        switch keyPath {
        case #keyPath(AVPlayerItem.status):
            guard item.status == .readyToPlay else { return }
            delegate?.audioPlayerDidStartPlaying(self)
        case #keyPath(AVPlayerItem.timebase):
            delegate?.audioPlayerDidChangedTimebase(self)
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }


    override var timebase:CMTimebase? {
        return _player.currentItem?.timebase
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.timebase))

    }
    
    @objc func audioPlayerDidFinishPlaying(_ player: AVPlayer) {
        delegate?.audioPlayerDidFinishPlaying(self)
    }
    
    override func cleanup() {
        queue.sync {
            self._player.pause()
        }
    }
    
    override func playFrom(position: TimeInterval) {
        queue.async {
            if position > 0 {
                self._player.seek(to: CMTimeMakeWithSeconds(position, 10000), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
            }
            self._player.play()
            self.delegate?.audioPlayerDidChangedTimebase(self)

        }
    }
    
    override func set(position:TimeInterval) {
        queue.async {
            self._player.seek(to: CMTimeMakeWithSeconds(position, 10000), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
            self.delegate?.audioPlayerDidChangedTimebase(self)
        }
    }
    
    override func play() {
        queue.async {
            self._player.play()
        }
        if let _ = timebase {
            delegate?.audioPlayerDidStartPlaying(self)
        }
    }
    
    override func pause() {
        queue.sync {
            self._player.pause()
        }
        delegate?.audioPlayerDidPaused(self)
        delegate?.audioPlayerDidChangedTimebase(self)
    }
    
    override func stop() {
        queue.async {
            self._player.seek(to: CMTimeMake(0, self._player.currentTime().timescale))
            self._player.pause()
        }
    }

    override var currentTime: TimeInterval {
        var time:TimeInterval = 0
        
        queue.sync {
            time = CMTimeGetSeconds(self._player.currentTime())
        }
        
        return time
    }
    
    override var duration: TimeInterval {
        var time:Float64?
        queue.sync {
            time = CMTimeGetSeconds(self.item.asset.duration)
        }
        
        return time ?? 0
    }
}
