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
import TGUIKit

final class ChatMessageThrottledProcessingManager {
    private let queue = Queue()
    
    private let delay: Double
    private let submitInterval: Double?
    
    var process: ((Set<MessageId>) -> Void)?
    
    private var timer: SwiftSignalKit.Timer?
    private var processedList: [MessageId] = []
    private var processed: [MessageId: Double] = [:]
    private var buffer = Set<MessageId>()
    
    private let disposable = MetaDisposable()
    
    init(delay: Double = 1.0, submitInterval: Double? = nil) {
        self.delay = delay
        self.submitInterval = submitInterval
    }
    
    func setProcess(process: @escaping (Set<MessageId>) -> Void) {
        self.queue.async {
            self.process = process
        }
    }
    
    func add(_ messageIds: [MessageId]) {
        self.queue.async {
            let timestamp = CFAbsoluteTimeGetCurrent()
            
            for id in messageIds {
                if let processedTimestamp = self.processed[id] {
                    if let submitInterval = self.submitInterval, (timestamp - processedTimestamp) >= submitInterval {
                        self.processed[id] = timestamp
                        self.processedList.append(id)
                        self.buffer.insert(id)
                    }
                } else {
                    self.processed[id] = timestamp
                    self.processedList.append(id)
                    self.buffer.insert(id)
                }
            }
            
            if self.processedList.count > 1000 {
                for i in 0 ..< 200 {
                    self.processed.removeValue(forKey: self.processedList[i])
                }
                self.processedList.removeSubrange(0 ..< 200)
            }
            
            if self.timer == nil {
                var completionImpl: (() -> Void)?
                let timer = SwiftSignalKit.Timer(timeout: self.delay, repeat: false, completion: {
                    completionImpl?()
                }, queue: self.queue)
                completionImpl = { [weak self, weak timer] in
                    if let strongSelf = self {
                        if let timer = timer, strongSelf.timer === timer {
                            strongSelf.timer = nil
                        }
                        let buffer = strongSelf.buffer
                        strongSelf.buffer.removeAll()

                        if let submitInterval = strongSelf.submitInterval {
                            strongSelf.disposable.set(delaySignal(submitInterval).start(completed: { [weak strongSelf]in
                                strongSelf?.add(Array(buffer))
                            }))
                        } else {
                            strongSelf.disposable.set(nil)
                        }
                        DispatchQueue.main.async {
                            strongSelf.process?(buffer)
                        }
                    }
                }
                self.timer = timer
                timer.start()
            }
        }
    }
}


final class ChatMessageVisibleThrottledProcessingManager {
    private let queue = Queue()
    
    private let delay: Double
    
    private var currentIds = Set<MessageId>()
    
    var process: ((Set<MessageId>) -> Void)?
    
    private var timer: SwiftSignalKit.Timer?
    
    init(delay: Double = 1.0) {
        self.delay = delay
    }
    
    func setProcess(process: @escaping (Set<MessageId>) -> Void) {
        self.queue.async {
            self.process = process
        }
    }
    
    func update(_ ids: Set<MessageId>) {
        self.queue.async {
            if self.currentIds != ids {
                self.currentIds = ids
                if self.timer == nil {
                    var completionImpl: (() -> Void)?
                    let timer = SwiftSignalKit.Timer(timeout: self.delay, repeat: false, completion: {
                        completionImpl?()
                    }, queue: self.queue)
                    completionImpl = { [weak self, weak timer] in
                        if let strongSelf = self {
                            if let timer = timer, strongSelf.timer === timer {
                                strongSelf.timer = nil
                            }
                            strongSelf.process?(strongSelf.currentIds)
                        }
                    }
                    self.timer = timer
                    timer.start()
                }
            }
        }
    }
}
