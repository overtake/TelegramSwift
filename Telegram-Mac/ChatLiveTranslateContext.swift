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


public struct ChatTranslationState: Codable {
    enum CodingKeys: String, CodingKey {
        case baseLang
        case fromLang
        case toLang
        case isEnabled
    }
    
    public let baseLang: String
    public let fromLang: String
    public let toLang: String?
    public let isEnabled: Bool
    
    public init(
        baseLang: String,
        fromLang: String,
        toLang: String?,
        isEnabled: Bool
    ) {
        self.baseLang = baseLang
        self.fromLang = fromLang
        self.toLang = toLang
        self.isEnabled = isEnabled
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.baseLang = try container.decode(String.self, forKey: .baseLang)
        self.fromLang = try container.decode(String.self, forKey: .fromLang)
        self.toLang = try container.decodeIfPresent(String.self, forKey: .toLang)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.baseLang, forKey: .baseLang)
        try container.encode(self.fromLang, forKey: .fromLang)
        try container.encodeIfPresent(self.toLang, forKey: .toLang)
        try container.encode(self.isEnabled, forKey: .isEnabled)
    }

    public func withToLang(_ toLang: String?) -> ChatTranslationState {
        return ChatTranslationState(
            baseLang: self.baseLang,
            fromLang: self.fromLang,
            toLang: toLang,
            isEnabled: self.isEnabled
        )
    }
    
    public func withIsEnabled(_ isEnabled: Bool) -> ChatTranslationState {
        return ChatTranslationState(
            baseLang: self.baseLang,
            fromLang: self.fromLang,
            toLang: self.toLang,
            isEnabled: isEnabled
        )
    }
}



func translateMessageIds(context: AccountContext, messageIds: [EngineMessage.Id], toLang: String) -> Signal<Void, NoError> {
    return context.account.postbox.transaction { transaction -> Signal<Void, NoError> in
        var messageIdsToTranslate: [EngineMessage.Id] = []
        var messageIdsSet = Set<EngineMessage.Id>()
        for messageId in messageIds {
            if let message = transaction.getMessage(messageId) {
                if let replyAttribute = message.attributes.first(where: { $0 is ReplyMessageAttribute }) as? ReplyMessageAttribute, let replyMessage = message.associatedMessages[replyAttribute.messageId] {
                    if !replyMessage.text.isEmpty {
                        if let translation = replyMessage.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute, translation.toLang == toLang {
                        } else {
                            if !messageIdsSet.contains(replyMessage.id) {
                                messageIdsToTranslate.append(replyMessage.id)
                                messageIdsSet.insert(replyMessage.id)
                            }
                        }
                    }
                }
                if !message.text.isEmpty && message.author?.id != context.account.peerId {
                    if let translation = message.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute, translation.toLang == toLang {
                    } else {
                        if !messageIdsSet.contains(messageId) {
                            messageIdsToTranslate.append(messageId)
                            messageIdsSet.insert(messageId)
                        }
                    }
                }
            } else {
                if !messageIdsSet.contains(messageId) {
                    messageIdsToTranslate.append(messageId)
                    messageIdsSet.insert(messageId)
                }
            }
        }
        return context.engine.messages.translateMessages(messageIds: messageIdsToTranslate, toLang: toLang)
        |> `catch` { _ -> Signal<Void, NoError> in
            return .complete()
        }
    } |> switchToLatest
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

public func updateChatTranslationStateInteractively(engine: TelegramEngine, peerId: EnginePeer.Id, _ f: @escaping (ChatTranslationState) -> ChatTranslationState) -> Signal<Never, NoError> {
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
        var from: String
        var to: String
        
        struct Key: Hashable {
            let id: MessageId
            let toLang: String
            
            static func Key(id: MessageId, toLang: String) -> Key {
                return .init(id: id, toLang: toLang)
            }
        }
        var result:[Key : Result]
        
        static var `default`: State {
            return .init(canTranslate: false, translate: false, from: "", to: "", result: [:])
        }
        fileprivate var queued:[Message] = []
    }
    
    private let peerId: PeerId
    private let context: AccountContext
    
    
    
    private let statePromise = ValuePromise(State.default, ignoreRepeated: true)
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
        
        let should: Signal<(ChatTranslationState?, Appearance), NoError> = combineLatest(queue: prepareQueue, cachedData, translationState, baseAppSettings(accountManager: context.sharedContext.accountManager), appearanceSignal, getPeerView(peerId: context.peerId, postbox: context.account.postbox)) |> map { cachedData, translationState, settings, appearance, peer in
            
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
            
            if !isHidden && translationState?.fromLang != translationState?.toLang  {
                return (translationState, appearance)
            } else {
                return (nil, appearance)
            }
            
        } |> deliverOnPrepareQueue
        
        shouldDisposable.set(should.start(next: { [weak self] state, appearance in
            self?.updateState { current in
                var current = current
                let to = state?.toLang ?? appearance.language.baseLanguageCode
                let toUpdated = current.to != to
                if let state = state {
                    current.from = state.fromLang
                    current.to = to
                    current.canTranslate = true
                } else {
                    current.canTranslate = false
                }
                if let isEnabled = state?.isEnabled {
                    current.translate = isEnabled
                } else {
                    current.translate = false
                }
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
                    }).map { $0.id }
                    if !messages.isEmpty {
                        self?.activateTranslation(for: messages, state: state)
                    }
                }
            }
            
        }))
    }
    private func activateTranslation(for msgIds: [MessageId], state: State) -> Void {
        let signal = context.engine.messages.translateMessages(messageIds: msgIds, toLang: state.to)
        actionsDisposable.add(signal.start(next: { [weak self] results in
            self?.updateState { current in
                var current = current
                for id in msgIds {
                    current.result[.Key(id: id, toLang: current.to)] = .complete(toLang: current.to)
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
        _ = updateChatTranslationStateInteractively(engine: context.engine, peerId: peerId, { current in
            var current = current
            current = current.withIsEnabled(!current.isEnabled)
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
            let msgs = message.filter { $0.translationAttribute(toLang: toLang) == nil }.map { $0 }
            let translated = message.filter { $0.translationAttribute(toLang: toLang) != nil }.map { $0 }
            
            if !translated.isEmpty {
                self.updateState { current in
                    var current = current
                    if current.translate {
                        for msg in translated {
                            current.result[.Key(id: msg.id, toLang: toLang)] = .complete(toLang: toLang)
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
                    self.holder.removeAll()
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
            current = current.withIsEnabled(false)
            return current
        }).start()
    }
    func showTranslation() {
        _ = context.engine.messages.togglePeerMessagesTranslationHidden(peerId: self.peerId, hidden: false).start()
        _ = updateChatTranslationStateInteractively(engine: context.engine, peerId: peerId, { current in
            var current = current
            current = current.withIsEnabled(true)
            return current
        }).start()
    }
    
    func translate(toLang: String) -> Void {
        _ = updateChatTranslationStateInteractively(engine: context.engine, peerId: peerId, { current in
            var current = current
            current = current.withToLang(toLang)
            return current
        }).start()
    }
}



func chatTranslationState(context: AccountContext, peerId: EnginePeer.Id) -> Signal<ChatTranslationState?, NoError> {
    let baseLang = appAppearance.language.baseLanguageCode
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
                        return messageHistoryView.0.entries.count > 1
                    }
                    |> take(1)
                    |> map { messageHistoryView, _, _ -> ChatTranslationState? in
                        let messages = messageHistoryView.entries.map(\.message)
                        
                        var fromLangs: [String: Int] = [:]
                        var count = 0
                        for message in messages {
                            if let _ = URL(string: message.text) {
                                continue
                            }
                            if message.text.count > 10 {
                                let text = String(message.text.prefix(100))
                                let fromLang = Translate.detectLanguage(for: text)
                                if let fromLang = fromLang {
                                    fromLangs[fromLang] = (fromLangs[fromLang] ?? 0) + 1
                                }
                                count += 1
                            }
                            if count >= 10 {
                                break
                            }
                        }
                        
                        
                        var mostFrequent: (String, Int)?
                        for (lang, count) in fromLangs {
                            if let current = mostFrequent {
                                if count > current.1 {
                                    mostFrequent = (lang, count)
                                }
                            } else {
                                mostFrequent = (lang, count)
                            }
                        }
                        let fromLang = mostFrequent?.0 ?? ""
                        let state = ChatTranslationState(baseLang: baseLang, fromLang: fromLang, toLang: nil, isEnabled: false)
                        let _ = updateChatTranslationState(engine: context.engine, peerId: peerId, state: state).start()
                        if !dontTranslateLanguages.contains(fromLang) {
                            return state
                        } else {
                            return nil
                        }
                    }
                )
            }
        }
    }
}

