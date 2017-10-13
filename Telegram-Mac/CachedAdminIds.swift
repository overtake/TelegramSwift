//
//  CachedAdminIds.swift
//  Telegram
//
//  Created by keepcoder on 11/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private final class CachedAdminIdsContext {
    var hash:Int32 = 0
    var ids:[PeerId] = []
    let subscribers = Bag<([PeerId]) -> Void>()
}

private func hashForIdsReverse(_ ids: [Int32]) -> Int32 {
    var acc: UInt32 = 0
    
    for id in ids {
        let low = UInt32(UInt32(bitPattern: id) & (0xffffffff as UInt32))
        let high = UInt32((UInt32(bitPattern: id) >> 32) & (0xffffffff as UInt32))
        
        acc = (acc &* 20261) &+ high
        acc = (acc &* 20261) &+ low
    }
    return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
}

class CachedAdminIds: NSObject {
    private let statusQueue = Queue()

    
    private var idsContexts: [PeerId: CachedAdminIdsContext] = [:]

    private var disposableTokens:[PeerId: Disposable] = [:]
    func ids(postbox: Postbox, network:Network, peerId:PeerId) -> Signal<[PeerId], Void> {
        if peerId.namespace != Namespaces.Peer.CloudChannel {
            return .single([])
        }
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.statusQueue.async {
                
                let idsContexts: CachedAdminIdsContext
                if let current = self.idsContexts[peerId] {
                    idsContexts = current
                } else {
                    idsContexts = CachedAdminIdsContext()
                    self.idsContexts[peerId] = idsContexts
                }
                
                let index = idsContexts.subscribers.add { ids in
                    subscriber.putNext(ids)
                }
                
                subscriber.putNext(idsContexts.ids)
                
                
                self.disposableTokens[peerId]?.dispose()
                
                
                let signal = channelAdminIds(postbox: postbox, network: network, peerId: peerId, hash: idsContexts.hash) |> deliverOn(self.statusQueue) |> then( deferred {
                    return channelAdminIds(postbox: postbox, network: network, peerId: peerId, hash: idsContexts.hash) |> delay(60, queue: self.statusQueue)
                } |> restart)
                
                self.disposableTokens[peerId] = signal.start(next: { ids in
                    idsContexts.ids = ids
                    idsContexts.hash = hashForIdsReverse(ids.map({$0.id}))
                    for subscriber in idsContexts.subscribers.copyItems() {
                        subscriber(idsContexts.ids)
                    }
                })
                
                disposable.set(ActionDisposable {
                    self.statusQueue.async {
                        if let current = self.idsContexts[peerId] {
                            current.subscribers.remove(index)
                        }
                    }
                })
            }
            
            return disposable
        }
        
    }
    
    
    
    func remove(for peerId:PeerId) {
        disposableTokens[peerId]?.dispose()
    }
    
    deinit {
        for (_, value) in disposableTokens {
            value.dispose()
        }
    }
    
}
