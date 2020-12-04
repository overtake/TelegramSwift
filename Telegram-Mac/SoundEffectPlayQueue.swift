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
import SyncCore
import TelegramCore

final class SoundEffectPlayQueue {
    private var queue: [Int64: MediaPlayer] = [:]
    private let disposable = MetaDisposable()
    private let postbox: Postbox
    init(postbox: Postbox) {
        self.postbox = postbox
    }
    
    func play(name: String?) {
        if let name = name, let filePath = Bundle.main.path(forResource: name, ofType: "wav") {
            let id = arc4random64()
            let resource = LocalFileReferenceMediaResource(localFilePath: filePath, randomId: id)
            let player = MediaPlayer(postbox: postbox, reference: MediaResourceReference.standalone(resource: resource), streamable: false, video: false, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true)
            player.setVolume(0.25)
            queue[id] = player
            player.play()
            player.actionAtEnd = .action({ [weak self] in
                DispatchQueue.main.async { [weak self] in
                    self?.queue.removeValue(forKey: id)
                }
            })
        }

    }
    
    deinit {
        disposable.dispose()
    }
    
}
