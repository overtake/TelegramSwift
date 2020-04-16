//
//  DiceCache.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

private final class DiceSideDataContext {
    var data: (Data, TelegramMediaFile)?
    let subscribers = Bag<((Data, TelegramMediaFile)) -> Void>()
}

class DiceCache {
    private let postbox: Postbox
    private let network: Network
    
    private var dataContexts: [String: DiceSideDataContext] = [:]

    
    private let fetchDisposable = MetaDisposable()
    private let loadDataDisposable = MetaDisposable()
    
    init(postbox: Postbox, network: Network) {
        self.postbox = postbox
        self.network = network
        
        let dices = loadedStickerPack(postbox: postbox, network: network, reference: .dice(diceSymbol), forceActualized: false)
            |> map { result -> [String: StickerPackItem] in
                switch result {
                case let .result(_, items, _):
                    var dices: [String: StickerPackItem] = [:]
                    for case let item as StickerPackItem in items {
                        if let side = item.getStringRepresentationsOfIndexKeys().first {
                            dices[side] = item
                        }
                    }
                    return dices
                default:
                    return [:]
                }
        }
        
        let fetchDices = dices |> mapToSignal { dices -> Signal<Void, NoError> in
            let signals = dices.map { _, value -> Signal<FetchResourceSourceType, FetchResourceError> in
                let reference: MediaResourceReference
                if let stickerReference = value.file.stickerReference {
                    reference = FileMediaReference.stickerPack(stickerPack: stickerReference, media: value.file).resourceReference(value.file.resource)
                } else {
                    reference = FileMediaReference.standalone(media: value.file).resourceReference(value.file.resource)
                }
                return fetchedMediaResource(mediaBox: postbox.mediaBox, reference: reference)
            }
            return combineLatest(signals) |> map { _ in return } |> `catch` { _ in return .complete() }
        }
        
        fetchDisposable.set(fetchDices.start())
        
        let data = dices |> mapToSignal { dices -> Signal<[(String, Data, TelegramMediaFile)], NoError> in
            let signal = dices.map { key, value in
                return postbox.mediaBox.resourceData(value.file.resource) |> mapToSignal { resourceData -> Signal<Data, NoError> in
                    if resourceData.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                        return .single(data)
                    } else {
                        return .complete()
                    }
                } |> map { (key, $0, value.file) }
            }
            return combineLatest(signal)
        } |> deliverOnResourceQueue
        
        loadDataDisposable.set(data.start(next: { [weak self] data in
            guard let `self` = self else {
                return
            }
            for diceData in data {
                let context: DiceSideDataContext
                if let current = self.dataContexts[diceData.0] {
                    context = current
                } else {
                    context = DiceSideDataContext()
                    self.dataContexts[diceData.0] = context
                }
                context.data = (diceData.1, diceData.2)
                for subscriber in context.subscribers.copyItems() {
                    subscriber((diceData.1, diceData.2))
                }
            }
            
        }))
        
    }
    
    func diceData(_ side: String, synchronous: Bool) -> Signal<(Data, TelegramMediaFile), NoError> {
        return Signal { [weak self] subscriber in
            
            guard let `self` = self else {
                return EmptyDisposable
            }
            
            let disposable = MetaDisposable()
            
            let invoke = {
                let context: DiceSideDataContext
                if let current = self.dataContexts[side] {
                    context = current
                } else {
                    context = DiceSideDataContext()
                    self.dataContexts[side] = context
                }
                
                let index = context.subscribers.add({ data in
                    subscriber.putNext(data)
                })
                
                if let data = context.data {
                    subscriber.putNext(data)
                }
                disposable.set(ActionDisposable { [weak self] in
                    resourcesQueue.async {
                        if let current = self?.dataContexts[side] {
                            current.subscribers.remove(index)
                        }
                    }
                })
            }
            
            if synchronous {
                resourcesQueue.sync(invoke)
            } else {
                resourcesQueue.async(invoke)
            }
            
            
            return disposable
        }
    }
    
    func cleanup() {
        fetchDisposable.dispose()
        loadDataDisposable.dispose()
    }
    
    deinit {
       cleanup()
    }
}
