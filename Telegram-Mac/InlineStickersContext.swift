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

private final class InlineFileDataContext {
    var data: TelegramMediaFile?
    let subscribers = Bag<(TelegramMediaFile?) -> Void>()
}

final class InlineStickersContext {
    
    private let postbox: Postbox
    private let engine: TelegramEngine
    private var dataContexts: [Int64 : InlineFileDataContext] = [:]
    
    private let fetchDisposable = MetaDisposable()
    private let loadDataDisposable = MetaDisposable()
    
    init(postbox: Postbox, engine: TelegramEngine) {
        self.postbox = postbox
        self.engine = engine
    }
    
    func load(fileId: Int64) -> Signal<TelegramMediaFile?, NoError> {
        return Signal { subscriber in
            
            let context = self.dataContexts[fileId] ?? .init()
            
            subscriber.putNext(context.data)

            let index = context.subscribers.add({ data in
                subscriber.putNext(data)
            })
            
            var disposable: Disposable?
            
            if self.dataContexts[fileId] == nil {
                let signal = self.engine.stickers.resolveInlineSticker(fileId: fileId)
                
                disposable = signal.start(next: { file in
                    context.data = file
                    for subscriber in context.subscribers.copyItems() {
                        subscriber(context.data)
                    }
                    self.dataContexts[fileId] = context
                })
            }
                
            self.dataContexts[fileId] = context

            return ActionDisposable {
                if let current = self.dataContexts[fileId] {
                    current.subscribers.remove(index)
                }
                disposable?.dispose()
            }
        }
    }
    
}
