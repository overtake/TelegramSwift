//
//  CallAudioPlayer.swift
//  Telegram
//
//  Created by keepcoder on 04/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import AVFoundation

class CallAudioPlayer : NSObject, AVAudioPlayerDelegate {
    
    private var player: AVAudioPlayer?;
    public var completion:(()->Void)?
    
    let tone: URL
    
    init(_ url:URL, loops:Int, completion:(()->Void)? = nil) {
        self.tone = url
        self.player = try? AVAudioPlayer(contentsOf: url)
        self.completion = completion
        super.init()
        
        player?.numberOfLoops = loops
        player?.delegate = self
    }
    
    func play() {
        player?.play()
    }
    func stop() {
        player?.stop()
        player?.delegate = nil
        player = nil
    }
    deinit {
        stop()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.completion?()
        player.delegate = nil
    }
    
}
