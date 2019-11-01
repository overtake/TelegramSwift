//
//  PeerPresenceStatusManager.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import SwiftSignalKit
import TelegramCore
import SyncCore

final class PeerPresenceStatusManager {
    private let update: () -> Void
    private var timer: SwiftSignalKit.Timer?
    
    init(update: @escaping () -> Void) {
        self.update = update
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func reset(presence: TelegramUserPresence, timeDifference: Int32) {
        timer?.invalidate()
        timer = nil
        
        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
        let timeout = userPresenceStringRefreshTimeout(presence, timeDifference: timeDifference, relativeTo: Int32(timestamp))
        if timeout.isFinite {
            self.timer = SwiftSignalKit.Timer(timeout: timeout, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.update()
                }
                }, queue: Queue.mainQueue())
            self.timer?.start()
        }
    }
}
