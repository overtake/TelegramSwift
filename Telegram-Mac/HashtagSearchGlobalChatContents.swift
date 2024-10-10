//
//  HashtagSearchGlobalChatContents.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import Postbox
import TGUIKit
import TelegramCore

final class HashtagSearchGlobalChatContents: ChatCustomContentsProtocol {
    
    private final class Impl {
        let queue: Queue
        let context: AccountContext
        
        fileprivate var query: String {
            didSet {
                if self.query != oldValue {
                    self.updateHistoryViewRequest(reload: true)
                }
            }
        }
        private let onlyMy: Bool
        private var currentSearchState: (SearchMessagesResult, SearchMessagesState)?
        
        private(set) var mergedHistoryView: MessageHistoryView?
        private var sourceHistoryView: MessageHistoryView?
        
        private var historyViewDisposable: Disposable?
        let historyViewStream = ValuePipe<(MessageHistoryView, ViewUpdateType)>()
        private var nextUpdateIsHoleFill: Bool = false
        
        var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in } {
            didSet {
                if let state = self.currentSearchState {
                    hashtagSearchResultsUpdate(state)
                }
            }
        }
        
        let isSearchingPromise = ValuePromise<Bool>(true)
        
        private let initialState:(SearchMessagesResult, SearchMessagesState)?
        
        init(queue: Queue, context: AccountContext, query: String, onlyMy: Bool, initialState: (SearchMessagesResult, SearchMessagesState)?) {
            self.queue = queue
            self.context = context
            self.query = query
            self.onlyMy = onlyMy
            self.initialState = initialState
            
            self.currentSearchState = initialState
            
            if let initialState {
                let updateType: ViewUpdateType = .Initial
                let historyView = MessageHistoryView(tag: nil, namespaces: .just(Set([Namespaces.Message.Cloud])), entries: initialState.0.messages.reversed().map { MessageHistoryEntry(message: $0, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)) }, holeEarlier: false, holeLater: false, isLoading: false)
                self.sourceHistoryView = historyView
                self.updateHistoryView(updateType: updateType)
            } else {
                self.updateHistoryViewRequest(reload: false)
            }
        }
        
        deinit {
            self.historyViewDisposable?.dispose()
        }
        
        private func updateHistoryViewRequest(reload: Bool) {
            guard self.historyViewDisposable == nil || reload else {
                return
            }
            self.historyViewDisposable?.dispose()
            
            let search: Signal<(SearchMessagesResult, SearchMessagesState), NoError>
            if self.onlyMy {
                search = self.context.engine.messages.searchMessages(location: .general(scope: .everywhere, tags: nil, minDate: nil, maxDate: nil), query: "#\(self.query)", state: initialState?.1)
            } else {
                search = self.context.engine.messages.searchHashtagPosts(hashtag: self.query, state: initialState?.1)
            }
            
            self.isSearchingPromise.set(true)
            self.historyViewDisposable = (search
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                let updateType: ViewUpdateType = .Initial
                
                let historyView = MessageHistoryView(tag: nil, namespaces: .just(Set([Namespaces.Message.Cloud])), entries: result.0.messages.reversed().map { MessageHistoryEntry(message: $0, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)) }, holeEarlier: false, holeLater: false, isLoading: false)
                self.sourceHistoryView = historyView
                self.updateHistoryView(updateType: updateType)
                                
                Queue.mainQueue().async {
                    self.currentSearchState = result
                    self.hashtagSearchResultsUpdate(result)
                }
                
                self.historyViewDisposable?.dispose()
                self.historyViewDisposable = nil
                
                self.isSearchingPromise.set(false)
            })
        }
        
        private func updateHistoryView(updateType: ViewUpdateType) {
            var entries = self.sourceHistoryView?.entries ?? []
            entries.sort(by: { $0.message.index < $1.message.index })
            
            let mergedHistoryView = MessageHistoryView(tag: nil, namespaces: .just(Set([Namespaces.Message.Cloud])), entries: entries, holeEarlier: false, holeLater: false, isLoading: false)
            self.mergedHistoryView = mergedHistoryView
            
            self.historyViewStream.putNext((mergedHistoryView, updateType))
        }
        
        func loadMore() {
            guard self.historyViewDisposable == nil, let currentSearchState = self.currentSearchState else {
                return
            }
            
            let search: Signal<(SearchMessagesResult, SearchMessagesState), NoError>
            if self.onlyMy {
                search = self.context.engine.messages.searchMessages(location: .general(scope: .everywhere, tags: nil, minDate: nil, maxDate: nil), query: "#\(self.query)", state: currentSearchState.1)
            } else {
                search = self.context.engine.messages.searchHashtagPosts(hashtag: self.query, state: currentSearchState.1)
            }
            
            self.historyViewDisposable?.dispose()
            self.historyViewDisposable = (search
            |> deliverOn(self.queue)).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                let updateType: ViewUpdateType = .FillHole
                
                let historyView = MessageHistoryView(tag: nil, namespaces: .just(Set([Namespaces.Message.Cloud])), entries: result.0.messages.reversed().map { MessageHistoryEntry(message: $0, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)) }, holeEarlier: false, holeLater: false, isLoading: false)
                self.sourceHistoryView = historyView
                                                     
                self.updateHistoryView(updateType: updateType)
                
                Queue.mainQueue().async {
                    self.currentSearchState = result
                    
                    self.hashtagSearchResultsUpdate(result)
                }
                
                self.historyViewDisposable?.dispose()
                self.historyViewDisposable = nil
            })
        }
        
        func enqueueMessages(messages: [EnqueueMessage]) {
        }

        func deleteMessages(ids: [EngineMessage.Id]) {
            
        }
        
        func messagesAtIds(_ ids: [MessageId], album: Bool) -> Signal<[Message], NoError> {
            let messages = self.mergedHistoryView?.entries.map { $0.message } ?? []
            
            var filtered = messages.filter({ ids.contains($0.id) })
            
            if album {
                let grouping = filtered.filter{ $0.groupingKey != nil }
                for groupMessage in grouping {
                    let additional = messages.filter { $0.groupingKey == groupMessage.groupingKey && $0.id != groupMessage.id }
                    filtered.append(contentsOf: additional)
                }
            }
            
            return .single(filtered)
        }
        
        func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
        }
    }
    
    var kind: ChatCustomContentsKind

    var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return self.impl.signalWith({ impl, subscriber in
            if let mergedHistoryView = impl.mergedHistoryView {
                subscriber.putNext((mergedHistoryView, .Initial))
            }
            return impl.historyViewStream.signal().start(next: subscriber.putNext)
        })
    }
    
    var searching: Signal<Bool, NoError> {
        return self.impl.signalWith({ impl, subscriber in
            return impl.isSearchingPromise.get().start(next: subscriber.putNext)
        })
    }
    
    var messageLimit: Int? {
        return nil
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(context: AccountContext, kind: ChatCustomContentsKind, query: String, onlyMy: Bool, initialState: (SearchMessagesResult, SearchMessagesState)?) {
        self.kind = kind
        
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, context: context, query: query, onlyMy: onlyMy, initialState: initialState)
        })
    }
    
    func enqueueMessages(messages: [EnqueueMessage]) {
        
    }

    func deleteMessages(ids: [EngineMessage.Id]) {

    }
    
    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {

    }
    
    func quickReplyUpdateShortcut(value: String) {
        
    }
    
    func businessLinkUpdate(message: String, entities: [TelegramCore.MessageTextEntity], title: String?) {
        
    }
    
    func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in } {
        didSet {
            self.impl.with { impl in
                impl.hashtagSearchResultsUpdate = self.hashtagSearchResultsUpdate
            }
        }
    }
    
    func hashtagSearchUpdate(query: String) {
        self.impl.with { impl in
            impl.query = query
        }
    }
    
    func enqueueMessages(messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {
        return .complete()
    }
    
    func messagesAtIds(_ ids: [MessageId], album: Bool) -> Signal<[Message], NoError> {
        return self.impl.signalWith({ impl, subscriber in
            return impl.messagesAtIds(ids, album: album).startStandalone(next: { messages in
                subscriber.putNext(messages)
                subscriber.putCompletion()
            })
        })
    }
    
}

