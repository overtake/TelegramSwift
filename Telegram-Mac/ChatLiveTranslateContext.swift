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

private func translateTexts(context: AccountContext, from: String?, to: String, blocks: [String]) -> Signal<[(detect: String?, result: String)?], NoError> {
    var signals:[Signal<(detect: String?, result: String)?, NoError>] = []
    for block in blocks {
        signals.append(context.engine.messages.translate(text: block, toLang: to) |> mapToSignal { value in
            if let value = value {
                return .single((detect: nil, result: value))
            } else {
                return Translate.translateText(text: block, from: from, to: to)
                |> map(Optional.init)
                |> `catch` { _ in return .single(nil) }
            }
        })
    }

    
    return combineLatest(signals)
}

final class ChatLiveTranslateContext {
    
    struct State : Equatable {
        
        enum Result : Equatable {
            case loading
            case complete
        }
        
        var canTranslate: Bool
        var translate: Bool
        var from: String
        var to: String
        
        var result:[MessageId : Result]
        
        static var `default`: State {
            return .init(canTranslate: false, translate: false, from: "", to: "", result: [:])
        }
        fileprivate var queued:[MessageId] = []
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
            $0 as? CachedChannelData
        }
        
        let should: Signal<(Bool, String, String), NoError> = combineLatest(queue:  prepareQueue,preloadedChatHistoryViewForLocation(.Initial(count: 30), context: context, chatLocation: .peer(peerId), chatLocationContextHolder: Atomic(value: nil), tagMask: nil, additionalData: []), appearanceSignal, context.account.postbox.loadedPeerWithId(context.peerId), context.account.postbox.loadedPeerWithId(peerId), baseAppSettings(accountManager: context.sharedContext.accountManager), cachedData) |> map { update, appearance, peer, mainPeer, settings, cachedData in
            switch update {
            case let.HistoryView(view, _, _, _):
                let messages = view.entries.compactMap {
                    $0.message
                }.filter { !$0.text.isEmpty }
                var languages = messages.compactMap {
                    Translate.detectLanguage(for: $0.text)
                }
                var counts: [String : Int] = [:]
                for language in languages {
                    var count = counts[language] ?? 0
                    count += 1
                    counts[language] = count
                }
                languages = languages.sorted(by: { lhs, rhs in
                    let lhsCount = counts[lhs] ?? 0
                    let rhsCount = counts[rhs] ?? 0
                    return lhsCount > rhsCount
                })
                let ignore = settings.doNotTranslate ?? appAppearance.language.baseLanguageCode
                
                if peer.isPremium, mainPeer.isChannel, !languages.isEmpty, settings.translateChannels, cachedData?.flags.contains(.translationHidden) == false {
                    if languages[0] != ignore {
                        return (true, languages[0], appearance.language.baseLanguageCode)
                    }
                }
            default:
                break
            }
            return (false, "", "")
        } |> deliverOnPrepareQueue
        
        shouldDisposable.set(should.start(next: { [weak self] translate, from, to in
            self?.updateState { current in
                var current = current
                current.canTranslate = translate
                current.from = from
                current.to = to
                if !current.canTranslate {
                    current.result = [:]
                    current.translate = false
                }
                return current
            }
        }))
        actionsDisposable.add(state.start(next: { [weak self] state in
            prepareQueue.justDispatch {
                if !state.queued.isEmpty {
                    let messages = state.queued.filter { state.result[$0] == nil }
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
                    current.result[id] = .complete
                }
                return current
            }
        }))
        
        self.updateState { current in
            var current = current
            current.queued.removeAll()
            for id in msgIds {
                current.result[id] = .loading
            }
            return current
        }
    }
    
    func toggleTranslate() {
        updateState { current in
            var current = current
            current.translate = !current.translate
            if !current.translate {
                current.result = [:]
                current.queued = []
            }
            return current
        }
    }
    
    var state: Signal<State, NoError> {
        return statePromise.get()
    }
    
    private var holder:[MessageId] = []
    
    func translate(_ message: [Message]) {
        prepareQueue.justDispatch { [weak self] in
            let ids = message.filter { $0.translationAttribute == nil }.map { $0.id }
            let translated = message.filter { $0.translationAttribute != nil }.map { $0.id }
            
            if !translated.isEmpty {
                self?.updateState { current in
                    var current = current
                    if current.translate {
                        for id in translated {
                            current.result[id] = .complete
                        }
                    }
                    return current
                }
                
            }
            
            if self?.holder != ids {
                self?.holder = ids
                let signal = Signal<Void, NoError>.complete() |> delay(0.05, queue: prepareQueue)
                
                self?.holderDisposable.set(signal.start(completed: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.holder.removeAll()
                    self.updateState { current in
                        var current = current
                        if current.translate {
                            for id in ids {
                                if current.result[id] == nil {
                                    current.queued.append(id)
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
    }
}
