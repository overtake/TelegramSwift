//
//  ChatMessageThrottledProcessingManager.swift
//  Telegram
//
//  Created by keepcoder on 07/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit

private let queue = Queue(name: "ChatMessageThrottledProcessingManager")

final class ChatMessageThrottledProcessingManager {
    
    private let delay: TimeInterval
    init(delay: TimeInterval = 1.0) {
        self.delay = delay
    }
    
    var process: ((Set<MessageId>) -> Void)?
    
    private var timer: SwiftSignalKit.Timer?
    private var processed = Set<MessageId>()
    private var buffer = Set<MessageId>()
    
    func setProcess(process: @escaping (Set<MessageId>) -> Void) {
        queue.async {
            self.process = process
        }
    }
    
    func add(_ messageIds: [MessageId]) {
        queue.async {
            for id in messageIds {
                if !self.processed.contains(id) {
                    self.processed.insert(id)
                    self.buffer.insert(id)
                }
            }
            
            if self.timer == nil {
                var completionImpl: (() -> Void)?
                let timer = SwiftSignalKit.Timer(timeout: self.delay, repeat: false, completion: {
                    completionImpl?()
                }, queue: queue)
                completionImpl = { [weak self, weak timer] in
                    if let strongSelf = self {
                        if let timer = timer, strongSelf.timer === timer {
                            strongSelf.timer = nil
                        }
                        let buffer = strongSelf.buffer
                        strongSelf.buffer.removeAll()
                        strongSelf.process?(buffer)
                    }
                }
                self.timer = timer
                timer.start()
            }
        }
    }
}
