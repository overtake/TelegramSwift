//
//  ChatLiveTranslateContext.swift
//  Telegram
//
//  Created by Mike Renoir on 17.01.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import Translate
import InAppSettings

enum AppConfigTranslateState : String {
    case enabled
    case disabled
    case system
    case alternative
    
    var canTranslate: Bool {
        switch self {
        case .enabled, .alternative:
            return true
        default:
            return false
        }
    }
}


struct ChatTranslationState: Codable {
    enum CodingKeys: String, CodingKey {
        case baseLang
        case fromLang
        case toLang
        case isEnabled
        case paywall
    }
    
    var baseLang: String
    var fromLang: String
    var toLang: String?
    var isEnabled: Bool?
    var paywall: Bool
    
    init(
        baseLang: String,
        fromLang: String,
        toLang: String?,
        isEnabled: Bool?,
        paywall: Bool
    ) {
        self.baseLang = baseLang
        self.fromLang = fromLang
        self.toLang = toLang
        self.isEnabled = isEnabled
        self.paywall = paywall
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.baseLang = try container.decode(String.self, forKey: .baseLang)
        self.fromLang = try container.decode(String.self, forKey: .fromLang)
        self.toLang = try container.decodeIfPresent(String.self, forKey: .toLang)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled)
        self.paywall = try container.decodeIfPresent(Bool.self, forKey: .paywall) ?? false

    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.baseLang, forKey: .baseLang)
        try container.encode(self.fromLang, forKey: .fromLang)
        try container.encodeIfPresent(self.toLang, forKey: .toLang)
        try container.encodeIfPresent(self.isEnabled, forKey: .isEnabled)
        try container.encode(self.paywall, forKey: .paywall)
    }
}


private func cachedChatTranslationState(engine: TelegramEngine, peerId: EnginePeer.Id) -> Signal<ChatTranslationState?, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    return engine.data.subscribe(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.translationState, id: key))
    |> map { entry -> ChatTranslationState? in
        return entry?.get(ChatTranslationState.self)
    }
}

private func updateChatTranslationState(engine: TelegramEngine, peerId: EnginePeer.Id, state: ChatTranslationState?) -> Signal<Never, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    if let state = state {
        return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.translationState, id: key, item: state)
    } else {
        return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.translationState, id: key)
    }
}

func updateChatTranslationStateInteractively(engine: TelegramEngine, peerId: EnginePeer.Id, _ f: @escaping (ChatTranslationState) -> ChatTranslationState) -> Signal<Never, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.translationState, id: key))
    |> map { entry -> ChatTranslationState? in
        return entry?.get(ChatTranslationState.self)
    }
    |> mapToSignal { current -> Signal<Never, NoError> in
        if let current = current {
            return updateChatTranslationState(engine: engine, peerId: peerId, state: f(current))
        } else {
            return .never()
        }
    }
}



final class ChatLiveTranslateContext {
    
    struct State : Equatable {
        
        enum Result : Equatable {
            case loading(toLang: String)
            case complete(toLang: String)
            var toLang: String {
                switch self {
                case let .loading(toLang):
                    return toLang
                case let .complete(toLang):
                    return toLang
                }
            }
        }
        
        var canTranslate: Bool
        var translate: Bool
        var autotranslate: Bool
        var from: String
        var to: String
        var paywall: Bool
        
        struct Key: Hashable {
            let id: MessageId
            let toLang: String
            
            static func Key(id: MessageId, toLang: String) -> Key {
                return .init(id: id, toLang: toLang)
            }
        }
        var result:[Key : Result]
        
        static var `default`: State {
            return .init(canTranslate: false, translate: false, autotranslate: false, from: "", to: "", paywall: false, result: [:])
        }
        fileprivate var queued:[Message] = []
    }
    
    private let peerId: PeerId
    private let context: AccountContext
    
    
    
    private let statePromise = ValuePromise<State>(ignoreRepeated: true)
    private let stateValue = Atomic(value: State.default)
    
    private func updateState(_ f: (State) -> State) -> Void {
        statePromise.set(stateValue.modify (f))
    }
    
    private let shouldDisposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let holderDisposable = MetaDisposable()
    deinit {
        shouldDisposable.dispose()
        actionsDisposable.dispose()
        holderDisposable.dispose()
    }
    
    init(peerId: PeerId, context: AccountContext) {
        self.peerId = peerId
        self.context = context
        
        let cachedData = getCachedDataView(peerId: peerId, postbox: context.account.postbox) |> map {
            $0
        }
        
        let translationState = chatTranslationState(context: context, peerId: peerId)
        
        let autoTranslate = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.AutoTranslateEnabled(id: peerId))


        
        let should: Signal<(ChatTranslationState?, Appearance, Bool, Bool), NoError> = combineLatest(queue: prepareQueue, cachedData, translationState, baseAppSettings(accountManager: context.sharedContext.accountManager), appearanceSignal, getPeerView(peerId: context.peerId, postbox: context.account.postbox), autoTranslate) |> map { cachedData, translationState, settings, appearance, peer, autoTranslate in
            
            var isHidden: Bool
            if let cachedData = cachedData as? CachedChannelData {
                isHidden = cachedData.flags.contains(.translationHidden)
            } else if let cachedData = cachedData as? CachedGroupData {
                isHidden = cachedData.flags.contains(.translationHidden)
            } else if let cachedData = cachedData as? CachedUserData {
                isHidden = cachedData.flags.contains(.translationHidden)
            } else {
                isHidden = true
            }
            
            if let peer = peer {
                isHidden = !peer.isPremium || isHidden
            } else {
                isHidden = true
            }
            
            var translationState = translationState
            if let paywall = settings.paywall, isHidden {
                translationState?.paywall = paywall.show
            } else {
                translationState?.paywall = false
            }
            
            if let state = translationState, state.paywall && peer?.isPremium == false {
                isHidden = false
            }
            
            let translateConfig = AppConfigTranslateState(rawValue: context.appConfiguration.getStringValue("translations_auto_enabled", orElse: "enabled")) ?? .disabled

            if !isHidden, !translateConfig.canTranslate {
                isHidden = true
            }
            
            if !isHidden && translationState?.fromLang != translationState?.toLang  {
                return (translationState, appearance, peer?.isPremium == true, autoTranslate)
            } else {
                return (nil, appearance, peer?.isPremium == true, autoTranslate)
            }
            
        } |> deliverOnPrepareQueue
        
        shouldDisposable.set(should.start(next: { [weak self] state, appearance, isPremium, autoTranslate in
            self?.updateState { current in
                var current = current
                let to = state?.toLang ?? appearance.languageCode
                let toUpdated = current.to != to
                if let state = state, state.fromLang != to, state.fromLang != "" {
                    current.from = state.fromLang
                    current.to = to
                    current.canTranslate = true
                } else {
                    current.canTranslate = false
                }
                if let isEnabled = state?.isEnabled {
                    current.translate = isEnabled && isPremium
                } else if autoTranslate {
                    current.translate = true
                } else {
                    current.translate = false
                }
                current.autotranslate = autoTranslate
                current.paywall = isPremium ? false : (state?.paywall ?? false)
                if !current.canTranslate || !current.translate || toUpdated {
                    current.result = [:]
                }
                return current
            }
        }))
        actionsDisposable.add(state.start(next: { [weak self] state in
            prepareQueue.justDispatch {
                if !state.queued.isEmpty {
                    var textCount: Int = 0
                    var count: Int = 0
                    let messages = state.queued.reversed().filter { state.result[.Key(id: $0.id, toLang: state.to)] == nil }.prefix(while: { msg in
                        textCount += msg.text.count
                        count += 1
                        return textCount < 25000 && count < 21
                    }).uniqueElements
                    
                    let messageIds = messages.map { $0.id }.uniqueElements.sorted(by: >)
                    if !messageIds.isEmpty {
                        self?.activateTranslation(for: messageIds, state: state)
                    }
                }
            }
        }))
    }
        
    private func activateTranslation(for msgIds: [MessageId], state: State) -> Void {
        let signal = context.engine.messages.translateMessages(messageIds: msgIds, fromLang: nil, toLang: state.to, enableLocalIfPossible: false)
        
        actionsDisposable.add(signal.start(error: { [weak self] error in
            self?.updateState { current in
                var current = current
                for id in msgIds {
                    current.result.removeValue(forKey: .Key(id: id, toLang: current.to))
                }
                return current
            }
        }))
        
        self.updateState { current in
            var current = current
            current.queued.removeAll()
            for id in msgIds {
                current.result[.Key(id: id, toLang: current.to)] = .loading(toLang: current.to)
            }
            return current
        }
    }
    
    func toggleTranslate() {
        
        let state = stateValue.with { $0 }
        
        _ = updateChatTranslationStateInteractively(engine: context.engine, peerId: peerId, { current in
            var current = current
            if let isEnabled = current.isEnabled {
                current.isEnabled = !isEnabled
            } else {
                current.isEnabled = !state.autotranslate
            }
            return current
        }).start()
    }
    
    var state: Signal<State, NoError> {
        return statePromise.get()
    }
    
    private var holder:[MessageId] = []
    
    func translate(_ message: [Message]) {
        prepareQueue.justDispatch { [weak self] in
            guard let `self` = self else {
                return
            }
            let toLang = self.stateValue.with { $0.to }
            let isEnabled = self.stateValue.with { $0.canTranslate && $0.translate }
            if !isEnabled {
                return
            }
            let msgs = message.filter { !$0.hasTranslationAttribute(toLang: toLang) }.map { $0 }
            let translated = message.filter { $0.hasTranslationAttribute(toLang: toLang) }.map { $0 }
            
            if !translated.isEmpty {
                self.updateState { current in
                    var current = current
                    if current.translate {
                        for msg in translated {
                            current.result[.Key(id: msg.id, toLang: toLang)] = .complete(toLang: toLang)
                        }
                        for msg in msgs {
                            if !translated.contains(msg), case .complete(toLang: toLang) = current.result[.Key(id: msg.id, toLang: toLang)] {
                                current.result.removeValue(forKey: .Key(id: msg.id, toLang: toLang))
                            }
                        }
                    }
                    return current
                }
                
            }
            let ids = msgs.map ({ $0.id })
            if self.holder != ids {
                self.holder = ids
                let signal = Signal<Void, NoError>.complete() |> delay(0.01, queue: prepareQueue)
                
                self.holderDisposable.set(signal.start(completed: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                //    self.holder.removeAll()
                    self.updateState { current in
                        var current = current
                        if current.translate {
                            for msg in msgs {
                                if current.result[.Key(id: msg.id, toLang: current.to)] == nil {
                                    current.queued.append(msg)
                                }
                            }
                        }
                        return current
                    }
                }))
            }
        }
    }
    
    func hideTranslation() {
        _ = context.engine.messages.togglePeerMessagesTranslationHidden(peerId: self.peerId, hidden: true).start()
        _ = updateChatTranslationStateInteractively(engine: context.engine, peerId: peerId, { current in
            var current = current
            current.isEnabled = false
            return current
        }).start()
    }
    func showTranslation() {
        _ = context.engine.messages.togglePeerMessagesTranslationHidden(peerId: self.peerId, hidden: false).start()
        _ = updateChatTranslationStateInteractively(engine: context.engine, peerId: peerId, { current in
            var current = current
            current.isEnabled = true
            return current
        }).start()
    }
    
    func translate(toLang: String) -> Void {
        _ = updateChatTranslationStateInteractively(engine: context.engine, peerId: peerId, { current in
            var current = current
            current.toLang = toLang
            return current
        }).start()
    }
    
    func enablePaywall() -> Void {
        _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, {
            $0.withUpdatedPaywall($0.paywall?.increase() ?? .initialize())
        }).start()
    }
    func disablePaywall() -> Void {
        _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, {
            $0.withUpdatedPaywall($0.paywall?.flush())
        }).start()
    }
}

extension MessageTextEntityType {
    var isCode: Bool {
        switch self {
        case .Code, .Pre:
            return true
        default:
            return false
        }
    }
}

func chatTranslationState(context: AccountContext, peerId: EnginePeer.Id) -> Signal<ChatTranslationState?, NoError> {
    let baseLang = appAppearance.languageCode
    return baseAppSettings(accountManager: context.sharedContext.accountManager)
    |> mapToSignal { settings in
        if !settings.translateChats {
            return .single(nil)
        }
        
        var dontTranslateLanguages: [String] = []
        if !settings.doNotTranslate.isEmpty {
            dontTranslateLanguages = Array(settings.doNotTranslate)
        } else {
            dontTranslateLanguages = [baseLang]
        }
        
        return cachedChatTranslationState(engine: context.engine, peerId: peerId)
        |> mapToSignal { cached in
            if let cached = cached, cached.baseLang == baseLang {
                if !dontTranslateLanguages.contains(cached.fromLang) {
                    return .single(cached)
                } else {
                    return .single(nil)
                }
            } else {
                return .single(nil)
                |> then(
                    context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 32, fixedCombinedReadStates: nil)
                    |> filter { messageHistoryView -> Bool in
                        return messageHistoryView.0.entries.count > 10
                    }
                    |> take(1)
                    |> map { messageHistoryView, _, _ -> ChatTranslationState? in
                        let messages = messageHistoryView.entries.map(\.message)
                        
                        var fromLangs: [String: Int] = [:]
                        var count = 0
                        for message in messages {
                            if message.text.count > 10 {
                                var text = String(message.text.prefix(256))
                                if var entities = message.textEntitiesAttribute?.entities.filter({ $0.type.isCode }) {
                                    entities = entities.sorted(by: { $0.range.lowerBound > $1.range.lowerBound })
                                    var ranges: [Range<String.Index>] = []
                                    for entity in entities {
                                        if entity.range.lowerBound > text.count || entity.range.upperBound > text.count {
                                            continue
                                        }
                                        ranges.append(text.index(text.startIndex, offsetBy: entity.range.lowerBound) ..< text.index(text.startIndex, offsetBy: entity.range.upperBound))
                                    }
                                    for range in ranges {
                                        text.removeSubrange(range)
                                    }
                                }
                                if text.count < 10 {
                                    continue
                                }

                                let fromLang = Translate.detectLanguage(for: text)
                                if let fromLang = fromLang {
                                    fromLangs[fromLang] = (fromLangs[fromLang] ?? 0) + 1
                                    count += 1
                                }
                            }
                            if count >= 16 {
                                break
                            }
                        }
                        
                        var mostFrequent: (String, Int)?
                        if count >= 5 {
                            for (lang, count) in fromLangs {
                                if let current = mostFrequent {
                                    if count > current.1 {
                                        mostFrequent = (lang, count)
                                    }
                                } else {
                                    mostFrequent = (lang, count)
                                }
                            }
                        }
                        if let fromLang = mostFrequent?.0 {
                            let state = ChatTranslationState(baseLang: baseLang, fromLang: fromLang, toLang: nil, isEnabled: nil, paywall: false)
                            let _ = updateChatTranslationState(engine: context.engine, peerId: peerId, state: state).start()
                            if !dontTranslateLanguages.contains(fromLang) {
                                return state
                            } else {
                                return nil
                            }
                        } else {
                            return nil
                        }
                    }
                )
            }
        }
    }
}

