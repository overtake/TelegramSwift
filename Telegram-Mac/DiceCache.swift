//
//  DiceCache.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

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
        self.emojis = emojis.map { $0.withoutColorizer }
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

private final class EmojiDataContext {
    var data: [(String, Data?, TelegramMediaFile)] = []
    let subscribers = Bag<([(String, Data?, TelegramMediaFile)]) -> Void>()
}

class DiceCache {
    private let postbox: Postbox
    private let engine: TelegramEngine
    private var dataContexts: [String : EmojiDataContext] = [:]
    private var dataEffectsContexts: [String : EmojiDataContext] = [:]
    
    private let fetchDisposable = MetaDisposable()
    private let loadDataDisposable = MetaDisposable()
    private let emojiesSoundDisposable = MetaDisposable()
    
    var animatedEmojies:Signal<[String: StickerPackItem], NoError> {
        return _animatedEmojies.get()
    }
    private let _animatedEmojies:Promise<[String : StickerPackItem]> = .init()
    
    private let _emojies_reactions = Promise<ItemCollectionsView>()
    private let _emojies_status = Promise<ItemCollectionsView>()
    private let _emojies = Promise<ItemCollectionsView>()
    

    var emojies_reactions: Signal<ItemCollectionsView, NoError> {
        return postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentReactions, Namespaces.OrderedItemList.CloudTopReactions, Namespaces.OrderedItemList.CloudDefaultTagReactions], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 8000)
    }
    
    var top_reactions: Signal<ItemCollectionsView, NoError> {
        return postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentReactions, Namespaces.OrderedItemList.CloudTopReactions, Namespaces.OrderedItemList.CloudDefaultTagReactions], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 100)
    }
    
    var emojies_status: Signal<ItemCollectionsView, NoError> {
        return postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudFeaturedStatusEmoji, Namespaces.OrderedItemList.CloudRecentStatusEmoji], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 8000)
    }
    var background_icons: Signal<ItemCollectionsView, NoError> {
        return postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudFeaturedBackgroundIconEmoji], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 8000)
    }
    var channel_statuses: Signal<ItemCollectionsView, NoError> {
        return postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudFeaturedChannelStatusEmoji], namespaces: [Namespaces.ItemCollection.CloudIconChannelStatusEmoji], aroundIndex: nil, count: 8000)
    }
    var emojies: Signal<ItemCollectionsView, NoError> {
        return postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 8000)
    }
    
    var premium_gifts: Signal<LoadedStickerPack, NoError> {
        return engine.stickers.loadedStickerPack(reference: .premiumGifts, forceActualized: false)
    }
    
    init(postbox: Postbox, engine: TelegramEngine) {
        self.postbox = postbox
        self.engine = engine
        
        
        self._animatedEmojies.set(engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
                                  |> map { result -> [String: StickerPackItem] in
                                      switch result {
                                      case let .result(_, items, _):
                                          var animatedEmojiStickers: [String: StickerPackItem] = [:]
                                          for case let item in items {
                                              if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                                                  animatedEmojiStickers[emoji.withoutColorizer] = item
                                              }
                                          }
                                          return animatedEmojiStickers
                                      default:
                                          return [:]
                                      }
                              })
        
        let availablePacks = postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]) |> map { view in
            return view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
        } |> map {
            return InteractiveEmojiConfiguration.with(appConfiguration: $0)
        } |> distinctUntilChanged
        
        
        let emojiesSound = postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]) |> map { view in
            return view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
        } |> map { value -> EmojiesSoundConfiguration in
            return EmojiesSoundConfiguration.with(appConfiguration: value)
        } |> distinctUntilChanged |> mapToSignal { value -> Signal<Never, NoError> in
            //val
            let list = value.sounds.map { fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .other, reference: MediaResourceReference.standalone(resource: $0.value.resource )) }
            let signals = combineLatest(list)
            
            return signals |> ignoreValues |> `catch` { _ -> Signal<Never, NoError> in return .complete() }
        }
        
        emojiesSoundDisposable.set(emojiesSound.start())
        
        let packs = availablePacks |> mapToSignal { config -> Signal<[(String, [StickerPackItem])], NoError> in
            var signals: [Signal<(String, [StickerPackItem]), NoError>] = []
            for emoji in config.emojis {
                signals.append(engine.stickers.loadedStickerPack(reference: .dice(emoji), forceActualized: true)
                    |> map { result -> (String, [StickerPackItem]) in
                        switch result {
                        case let .result(_, items, _):
                            var dices: [StickerPackItem] = []
                            for case let item in items {
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
        
        let emojiEffects: Signal<[StickerPackItem], NoError> = engine.stickers.loadedStickerPack(reference: .animatedEmojiAnimations, forceActualized: true)
            |> map { result -> [StickerPackItem] in
                switch result {
                case let .result(_, items, _):
                    var effects: [StickerPackItem] = []
                    for case let item in items {
                        effects.append(item)
                    }
                    return effects
                default:
                    return []
                }
            }

        let fetchDices = combineLatest(packs, emojiEffects) |> map { value, effects in
            return value.map { $0.1 }.reduce([], { current, value in
                return current + value
            }) + effects
        } |> mapToSignal { dices -> Signal<Void, NoError> in
            let signals = dices.map { value -> Signal<FetchResourceSourceType, FetchResourceError> in
                let reference: MediaResourceReference
                if let stickerReference = value.file.stickerReference {
                    reference = FileMediaReference.stickerPack(stickerPack: stickerReference, media: value.file).resourceReference(value.file.resource)
                } else {
                    reference = FileMediaReference.standalone(media: value.file).resourceReference(value.file.resource)
                }
                return fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .other, reference: reference)
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
                    } |> map { ((value.file.stickerText ?? value.getStringRepresentationsOfIndexKeys().first!).withoutColorizer, $0, value.file) }
                }
                signals.append(combineLatest(dices) |> map { (value.0, $0) })
            }
            
            return combineLatest(signals) |> map { values in
                var dict: [String : [(String, Data?, TelegramMediaFile)]] = [:]
                
                for value in values {
                    dict[value.0.withoutColorizer] = value.1
                }
                return dict
            }
        } |> deliverOnResourceQueue
        
        
        let dataEffects = emojiEffects |> mapToSignal { values -> Signal<[String: [(String, Data?, TelegramMediaFile)]], NoError> in
            
                        
            let effects = values.map { value in
                return postbox.mediaBox.resourceData(value.file.resource) |> mapToSignal { resourceData -> Signal<Data?, NoError> in
                    if resourceData.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                        return .single(data)
                    } else {
                        return .single(nil)
                    }
                } |> map { ((value.file.stickerText ?? value.getStringRepresentationsOfIndexKeys().first!).withoutColorizer, $0, value.file) }
            }
            return combineLatest(effects) |> map { values in
                var dict: [String : [(String, Data?, TelegramMediaFile)]] = [:]
                
                for value in values {
                    var list = dict[value.0.withoutColorizer] ?? []
                    list.append(value)
                    dict[value.0] = list
                }
                return dict
            }
        } |> deliverOnResourceQueue
        
        loadDataDisposable.set(combineLatest(data, dataEffects).start(next: { [weak self] data, dataEffects in
            guard let `self` = self else {
                return
            }
            for diceData in data {
                let context = self.dataContexts[diceData.key] ?? EmojiDataContext()
                context.data = diceData.value
                for subscriber in context.subscribers.copyItems() {
                    subscriber(diceData.value)
                }
                self.dataContexts[diceData.key] = context
            }
            for effect in dataEffects {
                let context = self.dataEffectsContexts[effect.key] ?? EmojiDataContext()
                context.data = effect.value
                for subscriber in context.subscribers.copyItems() {
                    subscriber(effect.value)
                }
                self.dataEffectsContexts[effect.key] = context
            }
        }))
        
    }
    
    func animationEffect(for emoji: String) -> Signal<[(String, Data?, TelegramMediaFile)], NoError> {
        return Signal { [weak self] subscriber in
            guard let `self` = self else {
                return EmptyDisposable
            }
            var cancelled = false
            let disposable = MetaDisposable()
            
            let invoke = {
                if !cancelled {
                    var dataContext: EmojiDataContext
                    if let dc = self.dataEffectsContexts[emoji.withoutColorizer] {
                        dataContext = dc
                    } else {
                        dataContext = EmojiDataContext()
                    }
                    
                    self.dataEffectsContexts[emoji.withoutColorizer] = dataContext
                    
                    let index = dataContext.subscribers.add({ data in
                        if !cancelled {
                            subscriber.putNext(data)
                        }
                    })
                    subscriber.putNext(dataContext.data)
                    disposable.set(ActionDisposable { [weak self] in
                        resourcesQueue.async {
                            if let current = self?.dataEffectsContexts[emoji.withoutColorizer] {
                                current.subscribers.remove(index)
                            }
                        }
                    })
                }
                
            }
            resourcesQueue.sync(invoke)

            return ActionDisposable {
                disposable.dispose()
                cancelled = true
            }
        }
    }

    
    func listOfEmojies(engine: TelegramEngine) -> Signal<[String], NoError> {
        let availablePacks = engine.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]) |> map { view in
            return view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
        } |> map {
            return InteractiveEmojiConfiguration.with(appConfiguration: $0)
        } |> distinctUntilChanged
        
        let emojies = engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
            |> map { result -> [String] in
                switch result {
                case let .result(_, items, _):
                    var stickers: [String] = []
                    for case let item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            stickers.append(emoji)
                        }
                    }
                    return stickers
                default:
                    return []
                }
        }
        return emojies
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
                    var dataContext: EmojiDataContext
                    if let dc = self.dataContexts[baseSymbol] {
                        dataContext = dc
                    } else {
                        dataContext = EmojiDataContext()
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
