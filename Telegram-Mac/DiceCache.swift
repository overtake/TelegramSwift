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

struct EmojiesSoundConfiguration : Equatable {
    
    static var defaultValue: EmojiesSoundConfiguration {
        return EmojiesSoundConfiguration(sounds: [:])
    }
    
    public let sounds: [String: TelegramMediaFile]
    
    fileprivate init(sounds: [String: TelegramMediaFile]) {
        self.sounds = sounds
    }
    
    static func with(appConfiguration: AppConfiguration) -> EmojiesSoundConfiguration {
        if let data = appConfiguration.data, let values = data["emojies_sounds"] as? [String: Any] {
            var sounds: [String: TelegramMediaFile] = [:]
            for (key, value) in values {
                if let dict = value as? [String: String], var fileReferenceString = dict["file_reference_base64"] {
                    fileReferenceString = fileReferenceString.replacingOccurrences(of: "-", with: "+")
                    fileReferenceString = fileReferenceString.replacingOccurrences(of: "_", with: "/")
                    while fileReferenceString.count % 4 != 0 {
                        fileReferenceString.append("=")
                    }
                    
                    if let idString = dict["id"], let id = Int64(idString), let accessHashString = dict["access_hash"], let accessHash = Int64(accessHashString), let fileReference = Data(base64Encoded: fileReferenceString) {
                        let resource = CloudDocumentMediaResource(datacenterId: 1, fileId: id, accessHash: accessHash, size: nil, fileReference: fileReference, fileName: nil)
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: nil, attributes: [])
                        sounds[key] = file
                    }
                }
            }
            return EmojiesSoundConfiguration(sounds: sounds)
        } else {
            return .defaultValue
        }
    }

    
}

private final class DiceSideDataContext {
    var data: [(String, Data?, TelegramMediaFile)] = []
    let subscribers = Bag<([(String, Data?, TelegramMediaFile)]) -> Void>()
}

class DiceCache {
    private let postbox: Postbox
    private let network: Network
    
    private var dataContexts: [String : DiceSideDataContext] = [:]

    
    private let fetchDisposable = MetaDisposable()
    private let loadDataDisposable = MetaDisposable()
    private let emojiesSoundDisposable = MetaDisposable()
    
    init(postbox: Postbox, network: Network) {
        self.postbox = postbox
        self.network = network
        
        
        
        let availablePacks = postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]) |> map { view in
            return view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? AppConfiguration.defaultValue
        } |> map {
            return InteractiveEmojiConfiguration.with(appConfiguration: $0)
        } |> distinctUntilChanged
        
        
        let emojiesSound = postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]) |> map { view in
            return view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? AppConfiguration.defaultValue
        } |> map { value -> EmojiesSoundConfiguration in
            return EmojiesSoundConfiguration.with(appConfiguration: value)
        } |> distinctUntilChanged |> mapToSignal { value -> Signal<Never, NoError> in
            //val
            let list = value.sounds.map { fetchedMediaResource(mediaBox: postbox.mediaBox, reference: MediaResourceReference.standalone(resource: $0.value.resource )) }
            let signals = combineLatest(list)
            
            return signals |> ignoreValues |> `catch` { _ -> Signal<Never, NoError> in return .complete() }
        }
        
        emojiesSoundDisposable.set(emojiesSound.start())
        
        let packs = availablePacks |> mapToSignal { config -> Signal<[(String, [StickerPackItem])], NoError> in
            var signals: [Signal<(String, [StickerPackItem]), NoError>] = []
            for emoji in config.emojis {
                signals.append(loadedStickerPack(postbox: postbox, network: network, reference: .dice(emoji), forceActualized: true)
                    |> map { result -> (String, [StickerPackItem]) in
                        switch result {
                        case let .result(_, items, _):
                            var dices: [StickerPackItem] = []
                            for case let item as StickerPackItem in items {
                                dices.append(item)
                            }
                            return (emoji, dices)
                        default:
                            return (emoji, [])
                        }
                    })
            }
            return combineLatest(signals)
        }
        
        
        let fetchDices = packs |> map { value in
            return value.map { $0.1 }.reduce([], { current, value in
                return current + value
            })
        } |> mapToSignal { dices -> Signal<Void, NoError> in
            let signals = dices.map { value -> Signal<FetchResourceSourceType, FetchResourceError> in
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
                let dices = value.1.map { value in
                    return postbox.mediaBox.resourceData(value.file.resource) |> mapToSignal { resourceData -> Signal<Data?, NoError> in
                        if resourceData.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                            return .single(data)
                        } else {
                            return .single(nil)
                        }
                    } |> map { (value.getStringRepresentationsOfIndexKeys().first!.fixed, $0, value.file) }
                }
                signals.append(combineLatest(dices) |> map { (value.0, $0) })
            }
            
            return combineLatest(signals) |> map { values in
                var dict: [String : [(String, Data?, TelegramMediaFile)]] = [:]
                
                for value in values {
                    dict[value.0.fixed] = value.1
                }
                return dict
            }
        } |> deliverOnResourceQueue
        
        loadDataDisposable.set(data.start(next: { [weak self] data in
            guard let `self` = self else {
                return
            }
            for diceData in data {
                let context = self.dataContexts[diceData.key] ?? DiceSideDataContext()
                context.data = diceData.value
                for subscriber in context.subscribers.copyItems() {
                    subscriber(diceData.value)
                }
                self.dataContexts[diceData.key] = context
            }
        }))
        
    }
    
    func interactiveSymbolData(baseSymbol: String, synchronous: Bool) -> Signal<[(String, Data?, TelegramMediaFile)], NoError> {
        return Signal { [weak self] subscriber in
            
            guard let `self` = self else {
                return EmptyDisposable
            }
            var cancelled = false
            let disposable = MetaDisposable()
            
            let invoke = {
                if !cancelled {
                    var dataContext: DiceSideDataContext
                    if let dc = self.dataContexts[baseSymbol] {
                        dataContext = dc
                    } else {
                        dataContext = DiceSideDataContext()
                    }
                    
                    self.dataContexts[baseSymbol] = dataContext
                    
                    let index = dataContext.subscribers.add({ data in
                        if !cancelled {
                            subscriber.putNext(data)
                        }
                    })
                    
                    subscriber.putNext(dataContext.data)
                    
                    disposable.set(ActionDisposable { [weak self] in
                        resourcesQueue.async {
                            if let current = self?.dataContexts[baseSymbol] {
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
        emojiesSoundDisposable.dispose()
    }
    
    deinit {
       cleanup()
    }
}
