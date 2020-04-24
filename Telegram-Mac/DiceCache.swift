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

struct InteractiveEmojiConfetti : Equatable {
    let playAt: Int32
    let value:Int32
}

struct InteractiveEmojiConfiguration : Equatable {
    static var defaultValue: InteractiveEmojiConfiguration {
        return InteractiveEmojiConfiguration(emojis: [], confettiCompitable: [:])
    }
    
    let emojis: [String]
    private let confettiCompitable: [String: InteractiveEmojiConfetti]
        
    fileprivate init(emojis: [String], confettiCompitable: [String: InteractiveEmojiConfetti]) {
        self.emojis = emojis.map { $0.fixed }
        self.confettiCompitable = confettiCompitable
    }
    
    static func with(appConfiguration: AppConfiguration) -> InteractiveEmojiConfiguration {
        if let data = appConfiguration.data, let value = data["emojies_send_dice"] as? [String] {
            let dict:[String : Any]? = data["emojies_send_dice_success"] as? [String:Any]
            
            var confetti:[String: InteractiveEmojiConfetti] = [:]
            if let dict = dict {
                for (key, value) in dict {
                    if let data = value as? [String: Any], let frameStart = data["frame_start"] as? Double, let value = data["value"] as? Double {
                        confetti[key] = InteractiveEmojiConfetti(playAt: Int32(frameStart), value: Int32(value))
                    }
                }
            }
            return InteractiveEmojiConfiguration(emojis: value, confettiCompitable: confetti)
        } else {
            return .defaultValue
        }
    }
    
    func playConfetti(_ emoji: String) -> InteractiveEmojiConfetti? {
        return confettiCompitable[emoji]
    }
}

private final class DiceSideDataContext {
    var data: (Data?, TelegramMediaFile)?
    let subscribers = Bag<((Data?, TelegramMediaFile)) -> Void>()
}

class DiceCache {
    private let postbox: Postbox
    private let network: Network
    
    private var dataContexts: [String : [String: DiceSideDataContext]] = [:]

    
    private let fetchDisposable = MetaDisposable()
    private let loadDataDisposable = MetaDisposable()
    
    init(postbox: Postbox, network: Network) {
        self.postbox = postbox
        self.network = network
        
        
        
        let availablePacks = postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]) |> map { view in
            return view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? AppConfiguration.defaultValue
        } |> map {
            return InteractiveEmojiConfiguration.with(appConfiguration: $0)
        } |> distinctUntilChanged
        
        
        let packs = availablePacks |> mapToSignal { config -> Signal<[(String, [String: StickerPackItem])], NoError> in
            var signals: [Signal<(String, [String: StickerPackItem]), NoError>] = []
            for emoji in config.emojis {
                signals.append(loadedStickerPack(postbox: postbox, network: network, reference: .dice(emoji), forceActualized: false)
                    |> map { result -> (String, [String: StickerPackItem]) in
                        switch result {
                        case let .result(_, items, _):
                            var dices: [String: StickerPackItem] = [:]
                            for case let item as StickerPackItem in items {
                                if let side = item.getStringRepresentationsOfIndexKeys().first {
                                    dices[side.fixed] = item
                                }
                            }
                            return (emoji, dices)
                        default:
                            return (emoji, [:])
                        }
                    })
            }
            return combineLatest(signals)
        }
        
        
        let fetchDices = packs |> map { value in
            return value.reduce([], { current, value in
                return current + value.1
            })
        } |> mapToSignal { dices -> Signal<Void, NoError> in
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
        
        let data = packs |> mapToSignal { values -> Signal<[String : [(String, Data?, TelegramMediaFile)]], NoError> in
            
            var signals: [Signal<(String, [(String, Data?, TelegramMediaFile)]), NoError>] = []
            
            for value in values {
                let dices = value.1.map { key, value in
                    return postbox.mediaBox.resourceData(value.file.resource) |> mapToSignal { resourceData -> Signal<Data?, NoError> in
                        if resourceData.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                            return .single(data)
                        } else {
                            return .single(nil)
                        }
                    } |> map { (key.fixed, $0, value.file) }
                }
                signals.append(combineLatest(dices) |> map { (value.0, $0) })
            }
            
            return combineLatest(signals) |> map { values in
                var dict: [String : [(String, Data?, TelegramMediaFile)]] = [:]
                
                for value in values {
                    dict[value.0] = value.1
                }
                return dict
            }
        } |> deliverOnResourceQueue
        
        loadDataDisposable.set(data.start(next: { [weak self] data in
            guard let `self` = self else {
                return
            }
            for diceData in data {
                
                var dict = self.dataContexts[diceData.key] ?? [:]
                
                for diceData in diceData.value {
                    let context: DiceSideDataContext
                    if let current = dict[diceData.0] {
                        context = current
                    } else {
                        context = DiceSideDataContext()
                        dict[diceData.0] = context
                    }
                    context.data = (diceData.1, diceData.2)
                    for subscriber in context.subscribers.copyItems() {
                        subscriber((diceData.1, diceData.2))
                    }
                }
                self.dataContexts[diceData.key] = dict
                
            }
            
        }))
        
    }
    
    func interactiveSymbolData(baseSymbol: String, side: String, synchronous: Bool) -> Signal<(Data?, TelegramMediaFile), NoError> {
        return Signal { [weak self] subscriber in
            
            guard let `self` = self else {
                return EmptyDisposable
            }
            var cancelled = false
            let disposable = MetaDisposable()
            
            let invoke = {
                if !cancelled {
                    var dataContext: [String: DiceSideDataContext]
                    if let dc = self.dataContexts[baseSymbol] {
                        dataContext = dc
                    } else {
                        dataContext = [:]
                    }
                    
                    let context: DiceSideDataContext
                    if let current = dataContext[side] {
                        context = current
                    } else {
                        context = DiceSideDataContext()
                        dataContext[side] = context
                    }
                    self.dataContexts[baseSymbol] = dataContext
                    
                    let index = context.subscribers.add({ data in
                        if !cancelled {
                            subscriber.putNext(data)
                        }
                    })
                    
                    if let data = context.data {
                        subscriber.putNext(data)
                    }
                    disposable.set(ActionDisposable { [weak self] in
                        resourcesQueue.async {
                            if let current = self?.dataContexts[baseSymbol]?[side] {
                                current.subscribers.remove(index)
                            }
                        }
                    })
                }
                
            }
            
          //  if synchronous {
                resourcesQueue.sync(invoke)
           // } else {
            //    resourcesQueue.async(invoke)
          //  }
            
            
            return ActionDisposable {
                disposable.dispose()
                cancelled = true
            }
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
