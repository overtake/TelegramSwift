//
//  SoundEffectPlayQueue.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import Postbox

import TelegramCore
import TGUIKit
final class SoundEffectPlay {
    private static var queue: [Int64: MediaPlayer] = [:]
    static func play(postbox: Postbox, name: String?) {
        if let name = name, let filePath = Bundle.main.path(forResource: name, ofType: "mp3") {
            let id = arc4random64()
            let resource = LocalFileReferenceMediaResource(localFilePath: filePath, randomId: id)
            let player = MediaPlayer(postbox: postbox, reference: MediaResourceReference.standalone(resource: resource), streamable: false, video: false, preferSoftwareDecoding: false, enableSound: true, volume: 1.0, fetchAutomatically: true)
         //   player.setVolume(0.6)
            queue[id] = player
            player.play()
            player.actionAtEnd = .action({
                DispatchQueue.main.async {
                    SoundEffectPlay.queue.removeValue(forKey: id)
                }
            })
        }

    }
}
