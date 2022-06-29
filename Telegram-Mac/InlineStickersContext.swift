//
//  InlineStickersContext.swift
//  Telegram
//
//  Created by Mike Renoir on 27.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

private final class StickerReferenceDataContext {
    var data: [TelegramMediaFile] = []
    let subscribers = Bag<([TelegramMediaFile]) -> Void>()
}

final class InlineStickersContext {
    
    private let postbox: Postbox
    private let engine: TelegramEngine
    private var dataContexts: [StickerPackReference : StickerReferenceDataContext] = [:]
    
    private let fetchDisposable = MetaDisposable()
    private let loadDataDisposable = MetaDisposable()
    
    init(postbox: Postbox, engine: TelegramEngine) {
        self.postbox = postbox
        self.engine = engine
    }
    
    func stickerPack(reference: StickerPackReference) -> Signal<[TelegramMediaFile], NoError> {
        return Signal { subscriber in
            
            let context = self.dataContexts[reference] ?? .init()
            
            
            
            subscriber.putNext(context.data)

            self.dataContexts[reference] = context
            
            
            let index = context.subscribers.add({ data in
                subscriber.putNext(data)
            })
            
            
            let signal = self.engine.stickers.loadedStickerPack(reference: reference, forceActualized: false) |> deliverOnMainQueue
            
            let disposable = signal.start(next: { pack in
                let context = self.dataContexts[reference]!
                switch pack {
                case let .result(_, items, _):
                    context.data = items.map { $0.file }
                default:
                    break
                }
                for subscriber in context.subscribers.copyItems() {
                    subscriber(context.data)
                }
                self.dataContexts[reference] = context
            })
            
            return ActionDisposable {
                if let current = self.dataContexts[reference] {
                    current.subscribers.remove(index)
                }
                disposable.dispose()
            }
        }
    }
    
}
