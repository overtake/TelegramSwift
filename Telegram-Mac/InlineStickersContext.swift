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

func isDefaultStatusesPackId(_ reference: StickerPackReference?) -> Bool {
    if case let .id(id, _) = reference {
        if id == 773947703670341676 || id == 2964141614563343 {
            return true
        }
    }
    return reference == .iconStatusEmoji
}

extension StickerPackReference {
    var id: Int64? {
        switch self {
        case let .id(id, _):
            return id
        default:
            return nil
        }
    }
}

final class InlineStickersContext {
    
    private struct Key : Hashable {
        enum Source : Int32 {
            case normal
            case status
        }
        let fileId: Int64
        let source: Source
        
    }
    
    private let postbox: Postbox
    private let engine: TelegramEngine
    private var dataContexts: [Key : InlineFileDataContext] = [:]
    
    private let fetchDisposable = MetaDisposable()
    private let loadDataDisposable = MetaDisposable()
    
    init(postbox: Postbox, engine: TelegramEngine) {
        self.postbox = postbox
        self.engine = engine
    }
    
    func load(fileId: Int64, checkStatus: Bool = false) -> Signal<TelegramMediaFile?, NoError> {
        return Signal { subscriber in
            
            let key: Key = .init(fileId: fileId, source: checkStatus ? .status : .normal)
            
            let context = self.dataContexts[key] ?? .init()
            
            if let file = context.data {
                subscriber.putNext(file)
            }

            let index = context.subscribers.add({ data in
                subscriber.putNext(data)
            })
            
            var disposable: Disposable?
            
            if self.dataContexts[key] == nil {
               
                
                let signal = self.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                |> deliverOnMainQueue
                
                disposable = signal.start(next: { file in
                    
                    let current = file[fileId]
                    
                    context.data = current
                    for subscriber in context.subscribers.copyItems() {
                        subscriber(context.data)
                    }
                    self.dataContexts[key] = context
                })
            }
                
            self.dataContexts[key] = context

            return ActionDisposable {
                if let current = self.dataContexts[key] {
                    current.subscribers.remove(index)
                }
                disposable?.dispose()
            }
        }
    }
    
}
