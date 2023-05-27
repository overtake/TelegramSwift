//
//  StoryChatContent.swift
//  Telegram
//
//  Created by Mike Renoir on 25.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox



final class StoryContentItem {
    
    let id: AnyHashable
    let position: Int
    let peer: EnginePeer?
    let storyItem: EngineStoryItem
    let preload: Signal<Never, NoError>?
    let delete: (() -> Void)?
    let markAsSeen: (() -> Void)?
    let hasLike: Bool
    let isMy: Bool
    
    var peerId: EnginePeer.Id? {
        return self.peer?.id
    }

    init(
        id: AnyHashable,
        position: Int,
        peer: EnginePeer?,
        storyItem: EngineStoryItem,
        preload: Signal<Never, NoError>?,
        delete: (() -> Void)?,
        markAsSeen: (() -> Void)?,
        hasLike: Bool,
        isMy: Bool
    ) {
        self.id = id
        self.position = position
        self.peer = peer
        self.storyItem = storyItem
        self.preload = preload
        self.delete = delete
        self.markAsSeen = markAsSeen
        self.hasLike = hasLike
        self.isMy = isMy
    }
}


final class StoryContentItemSlice {
    let id: AnyHashable
    let focusedItemId: AnyHashable?
    let items: [StoryContentItem]
    let totalCount: Int
    let previousItemId: AnyHashable?
    let nextItemId: AnyHashable?
    let update: (StoryContentItemSlice, AnyHashable) -> Signal<StoryContentItemSlice, NoError>

    init(
        id: AnyHashable,
        focusedItemId: AnyHashable?,
        items: [StoryContentItem],
        totalCount: Int,
        previousItemId: AnyHashable?,
        nextItemId: AnyHashable?,
        update: @escaping (StoryContentItemSlice, AnyHashable) -> Signal<StoryContentItemSlice, NoError>
    ) {
        self.id = id
        self.focusedItemId = focusedItemId
        self.items = items
        self.totalCount = totalCount
        self.previousItemId = previousItemId
        self.nextItemId = nextItemId
        self.update = update
    }
}

final class StoryContentContextState {
    final class FocusedSlice: Equatable {
        let peer: EnginePeer
        let item: StoryContentItem
        let totalCount: Int
        let previousItemId: Int32?
        let nextItemId: Int32?
        
        init(
            peer: EnginePeer,
            item: StoryContentItem,
            totalCount: Int,
            previousItemId: Int32?,
            nextItemId: Int32?
        ) {
            self.peer = peer
            self.item = item
            self.totalCount = totalCount
            self.previousItemId = previousItemId
            self.nextItemId = nextItemId
        }
        
        static func ==(lhs: FocusedSlice, rhs: FocusedSlice) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.item.id != rhs.item.id {
                return false
            }
            if lhs.totalCount != rhs.totalCount {
                return false
            }
            if lhs.previousItemId != rhs.previousItemId {
                return false
            }
            if lhs.nextItemId != rhs.nextItemId {
                return false
            }
            return true
        }
    }
    
    let slice: FocusedSlice?
    let previousSlice: FocusedSlice?
    let nextSlice: FocusedSlice?
    
    init(
        slice: FocusedSlice?,
        previousSlice: FocusedSlice?,
        nextSlice: FocusedSlice?
    ) {
        self.slice = slice
        self.previousSlice = previousSlice
        self.nextSlice = nextSlice
    }
}

enum StoryContentContextNavigation {
    enum Direction {
        case previous
        case next
    }
    
    case item(Direction)
    case peer(Direction)
}

protocol StoryContentContext: AnyObject {
    var stateValue: StoryContentContextState? { get }
    var state: Signal<StoryContentContextState, NoError> { get }
    var updated: Signal<Void, NoError> { get }
    
    func resetSideStates()
    func navigate(navigation: StoryContentContextNavigation)
}


final class StoryContentContextImpl: StoryContentContext {
    private struct StoryKey: Hashable {
        var peerId: EnginePeer.Id
        var id: Int32
    }
    
    private final class PeerContext {
        private let context: AccountContext
        private let peerId: EnginePeer.Id
        
        private(set) var sliceValue: StoryContentContextState.FocusedSlice?
        
        let updated = Promise<Void>()
        
        private(set) var isReady: Bool = false
        
        private var disposable: Disposable?
        private var loadDisposable: Disposable?
        
        private let currentFocusedIdPromise = Promise<Int32?>()
        private var storedFocusedId: Int32?
        var currentFocusedId: Int32? {
            didSet {
                if self.currentFocusedId != self.storedFocusedId {
                    self.storedFocusedId = self.currentFocusedId
                    self.currentFocusedIdPromise.set(.single(self.currentFocusedId))
                }
            }
        }
        
        init(context: AccountContext, peerId: EnginePeer.Id, focusedId initialFocusedId: Int32?, loadIds: @escaping ([StoryKey]) -> Void) {
            self.context = context
            self.peerId = peerId
            
            self.currentFocusedIdPromise.set(.single(initialFocusedId))
            
            self.disposable = (combineLatest(queue: .mainQueue(),
                self.currentFocusedIdPromise.get(),
                context.account.postbox.combinedView(
                    keys: [
                        PostboxViewKey.basicPeer(peerId),
                        PostboxViewKey.storiesState(key: .peer(peerId)),
                        PostboxViewKey.storyItems(peerId: peerId)
                    ]
                )
            )
            |> mapToSignal { currentFocusedId, views -> Signal<(Int32?, CombinedView, [PeerId: Peer]), NoError> in
                return context.account.postbox.transaction { transaction -> (Int32?, CombinedView, [PeerId: Peer]) in
                    var peers: [PeerId: Peer] = [:]
                    if let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView {
                        for item in itemsView.items {
                            if let item = item.value.get(Stories.StoredItem.self), case let .item(itemValue) = item {
                                if let views = itemValue.views {
                                    for peerId in views.seenPeerIds {
                                        if let peer = transaction.getPeer(peerId) {
                                            peers[peer.id] = peer
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return (currentFocusedId, views, peers)
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] currentFocusedId, views, peers in
                guard let `self` = self else {
                    return
                }
                guard let peerView = views.views[PostboxViewKey.basicPeer(peerId)] as? BasicPeerView else {
                    return
                }
                guard let stateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                    return
                }
                guard let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView else {
                    return
                }
                guard let peer = peerView.peer.flatMap(EnginePeer.init) else {
                    return
                }
                let state = stateView.value?.get(Stories.PeerState.self)
                
                var focusedIndex: Int?
                if let currentFocusedId {
                    focusedIndex = itemsView.items.firstIndex(where: { $0.id == currentFocusedId })
                }
                if focusedIndex == nil, let state {
                    if let storedFocusedId = self.storedFocusedId {
                        focusedIndex = itemsView.items.firstIndex(where: { $0.id >= storedFocusedId })
                    } else {
                        focusedIndex = itemsView.items.firstIndex(where: { $0.id > state.maxReadId })
                    }
                }
                if focusedIndex == nil {
                    if !itemsView.items.isEmpty {
                        focusedIndex = 0
                    }
                }
                
                if let focusedIndex {
                    self.storedFocusedId = itemsView.items[focusedIndex].id
                    
                    var previousItemId: Int32?
                    var nextItemId: Int32?
                    
                    if focusedIndex != 0 {
                        previousItemId = itemsView.items[focusedIndex - 1].id
                    }
                    if focusedIndex != itemsView.items.count - 1 {
                        nextItemId = itemsView.items[focusedIndex + 1].id
                    }
                    
                    var loadKeys: [StoryKey] = []
                    for index in (focusedIndex - 2) ... (focusedIndex + 2) {
                        if index >= 0 && index < itemsView.items.count {
                            if let item = itemsView.items[focusedIndex].value.get(Stories.StoredItem.self), case .placeholder = item {
                                loadKeys.append(StoryKey(peerId: peerId, id: item.id))
                            }
                        }
                    }
                    
                    if let item = itemsView.items[focusedIndex].value.get(Stories.StoredItem.self), case let .item(item) = item, let media = item.media {
                        let mappedItem = EngineStoryItem(
                            id: item.id,
                            timestamp: item.timestamp,
                            media: EngineMedia(media),
                            text: item.text,
                            entities: item.entities,
                            views: item.views.flatMap { views in
                                return EngineStoryItem.Views(
                                    seenCount: views.seenCount,
                                    seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                        return peers[id].flatMap(EnginePeer.init)
                                    }
                                )
                            },
                            privacy: nil
                        )
                        
                        self.sliceValue = StoryContentContextState.FocusedSlice(
                            peer: peer,
                            item: StoryContentItem(
                                id: AnyHashable(item.id),
                                position: focusedIndex,
                                peer: peer,
                                storyItem: mappedItem,
                                preload: nil,
                                delete: { [weak context] in
                                    guard let context else {
                                        return
                                    }
                                    let _ = context
                                },
                                markAsSeen: { [weak context] in
                                    guard let context else {
                                        return
                                    }
                                    let _ = context.engine.messages.markStoryAsSeen(peerId: peerId, id: item.id).start()
                                },
                                hasLike: false,
                                isMy: peerId == context.account.peerId
                            ),
                            totalCount: itemsView.items.count,
                            previousItemId: previousItemId,
                            nextItemId: nextItemId
                        )
                        self.isReady = true
                        self.updated.set(.single(Void()))
                    }
                } else {
                    self.isReady = true
                    self.updated.set(.single(Void()))
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
            self.loadDisposable?.dispose()
        }
    }
    
    private final class StateContext {
        let centralPeerContext: PeerContext
        let previousPeerContext: PeerContext?
        let nextPeerContext: PeerContext?
        
        let updated = Promise<Void>()
        
        var isReady: Bool {
            if !self.centralPeerContext.isReady {
                return false
            }
            return true
        }
        
        private var centralDisposable: Disposable?
        private var previousDisposable: Disposable?
        private var nextDisposable: Disposable?
        
        init(
            centralPeerContext: PeerContext,
            previousPeerContext: PeerContext?,
            nextPeerContext: PeerContext?
        ) {
            self.centralPeerContext = centralPeerContext
            self.previousPeerContext = previousPeerContext
            self.nextPeerContext = nextPeerContext
            
            self.centralDisposable = (centralPeerContext.updated.get()
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let `self` = self else {
                    return
                }
                self.updated.set(.single(Void()))
            })
            
            if let previousPeerContext {
                self.previousDisposable = (previousPeerContext.updated.get()
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let `self` = self else {
                        return
                    }
                    self.updated.set(.single(Void()))
                })
            }
            
            if let nextPeerContext {
                self.nextDisposable = (nextPeerContext.updated.get()
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let `self` = self else {
                        return
                    }
                    self.updated.set(.single(Void()))
                })
            }
        }
        
        deinit {
            self.centralDisposable?.dispose()
            self.previousDisposable?.dispose()
            self.nextDisposable?.dispose()
        }
        
        func findPeerContext(id: EnginePeer.Id) -> PeerContext? {
            if self.centralPeerContext.sliceValue?.peer.id == id {
                return self.centralPeerContext
            }
            if let previousPeerContext = self.previousPeerContext, previousPeerContext.sliceValue?.peer.id == id {
                return previousPeerContext
            }
            if let nextPeerContext = self.nextPeerContext, nextPeerContext.sliceValue?.peer.id == id {
                return nextPeerContext
            }
            return nil
        }
    }
    
    private let context: AccountContext
    
    private(set) var stateValue: StoryContentContextState?
    var state: Signal<StoryContentContextState, NoError> {
        return self.statePromise.get()
    }
    private let statePromise = Promise<StoryContentContextState>()
    
    private let updatedPromise = Promise<Void>()
    var updated: Signal<Void, NoError> {
        return self.updatedPromise.get()
    }
    
    private var focusedItem: (peerId: EnginePeer.Id, storyId: Int32?)?
    
    private var currentState: StateContext?
    private var currentStateUpdatedDisposable: Disposable?
    
    private var pendingState: StateContext?
    private var pendingStateReadyDisposable: Disposable?
    
    private var storySubscriptions: EngineStorySubscriptions?
    private var storySubscriptionsDisposable: Disposable?
    
    private var requestedStoryKeys = Set<StoryKey>()
    private var requestStoryDisposables = DisposableSet()
    
    init(
        context: AccountContext,
        focusedPeerId: EnginePeer.Id?
    ) {
        self.context = context
        if let focusedPeerId {
            self.focusedItem = (focusedPeerId, nil)
        }
        
        self.storySubscriptionsDisposable = (context.engine.messages.storySubscriptions()
        |> deliverOnMainQueue).start(next: { [weak self] storySubscriptions in
            guard let `self` = self else {
                return
            }
            self.storySubscriptions = storySubscriptions
            self.updatePeerContexts()
        })
    }
    
    deinit {
        self.storySubscriptionsDisposable?.dispose()
        self.requestStoryDisposables.dispose()
    }
    
    private func updatePeerContexts() {
        if let currentState = self.currentState {
            let _ = currentState
        } else {
            self.switchToFocusedPeerId()
        }
    }
    
    private func switchToFocusedPeerId() {
        if let storySubscriptions = self.storySubscriptions {
            if self.pendingState == nil {
                let loadIds: ([StoryKey]) -> Void = { [weak self] keys in
                    guard let `self` = self else {
                        return
                    }
                    let missingKeys = Set(keys).subtracting(self.requestedStoryKeys)
                    if !missingKeys.isEmpty {
                        var idsByPeerId: [EnginePeer.Id: [Int32]] = [:]
                        for key in missingKeys {
                            if idsByPeerId[key.peerId] == nil {
                                idsByPeerId[key.peerId] = [key.id]
                            } else {
                                idsByPeerId[key.peerId]?.append(key.id)
                            }
                        }
                        for (peerId, ids) in idsByPeerId {
                            self.requestStoryDisposables.add(self.context.engine.messages.refreshStories(peerId: peerId, ids: ids).start())
                        }
                    }
                }
                
                if let (focusedPeerId, _) = self.focusedItem, focusedPeerId == self.context.account.peerId {
                    let centralPeerContext = PeerContext(context: self.context, peerId: self.context.account.peerId, focusedId: nil, loadIds: loadIds)
                    
                    let pendingState = StateContext(
                        centralPeerContext: centralPeerContext,
                        previousPeerContext: nil,
                        nextPeerContext: nil
                    )
                    self.pendingState = pendingState
                    self.pendingStateReadyDisposable = (pendingState.updated.get()
                    |> deliverOnMainQueue).start(next: { [weak self, weak pendingState] _ in
                        guard let `self` = self, let pendingState, self.pendingState === pendingState, pendingState.isReady else {
                            return
                        }
                        self.pendingState = nil
                        self.pendingStateReadyDisposable?.dispose()
                        self.pendingStateReadyDisposable = nil
                        
                        self.currentState = pendingState
                        
                        self.updateState()
                        
                        self.currentStateUpdatedDisposable?.dispose()
                        self.currentStateUpdatedDisposable = (pendingState.updated.get()
                        |> deliverOnMainQueue).start(next: { [weak self, weak pendingState] _ in
                            guard let `self` = self, let pendingState, self.currentState === pendingState else {
                                return
                            }
                            self.updateState()
                        })
                    })
                } else {
                    var centralIndex: Int?
                    if let (focusedPeerId, _) = self.focusedItem {
                        if let index = storySubscriptions.items.firstIndex(where: { $0.peer.id == focusedPeerId }) {
                            centralIndex = index
                        }
                    }
                    if centralIndex == nil {
                        if !storySubscriptions.items.isEmpty {
                            centralIndex = 0
                        }
                    }
                    
                    if let centralIndex {
                        let centralPeerContext: PeerContext
                        if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: storySubscriptions.items[centralIndex].peer.id) {
                            centralPeerContext = existingContext
                        } else {
                            centralPeerContext = PeerContext(context: self.context, peerId: storySubscriptions.items[centralIndex].peer.id, focusedId: nil, loadIds: loadIds)
                        }
                        
                        var previousPeerContext: PeerContext?
                        if centralIndex != 0 {
                            if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: storySubscriptions.items[centralIndex - 1].peer.id) {
                                previousPeerContext = existingContext
                            } else {
                                previousPeerContext = PeerContext(context: self.context, peerId: storySubscriptions.items[centralIndex - 1].peer.id, focusedId: nil, loadIds: loadIds)
                            }
                        }
                        
                        var nextPeerContext: PeerContext?
                        if centralIndex != storySubscriptions.items.count - 1 {
                            if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: storySubscriptions.items[centralIndex + 1].peer.id) {
                                nextPeerContext = existingContext
                            } else {
                                nextPeerContext = PeerContext(context: self.context, peerId: storySubscriptions.items[centralIndex + 1].peer.id, focusedId: nil, loadIds: loadIds)
                            }
                        }
                        
                        let pendingState = StateContext(
                            centralPeerContext: centralPeerContext,
                            previousPeerContext: previousPeerContext,
                            nextPeerContext: nextPeerContext
                        )
                        self.pendingState = pendingState
                        self.pendingStateReadyDisposable = (pendingState.updated.get()
                        |> deliverOnMainQueue).start(next: { [weak self, weak pendingState] _ in
                            guard let `self` = self, let pendingState, self.pendingState === pendingState, pendingState.isReady else {
                                return
                            }
                            self.pendingState = nil
                            self.pendingStateReadyDisposable?.dispose()
                            self.pendingStateReadyDisposable = nil
                            
                            self.currentState = pendingState
                            
                            self.updateState()
                            
                            self.currentStateUpdatedDisposable?.dispose()
                            self.currentStateUpdatedDisposable = (pendingState.updated.get()
                            |> deliverOnMainQueue).start(next: { [weak self, weak pendingState] _ in
                                guard let `self` = self, let pendingState, self.currentState === pendingState else {
                                    return
                                }
                                self.updateState()
                            })
                        })
                    }
                }
            }
        }
    }
    
    private func updateState() {
        guard let currentState = self.currentState else {
            return
        }
        let stateValue = StoryContentContextState(
            slice: currentState.centralPeerContext.sliceValue,
            previousSlice: currentState.previousPeerContext?.sliceValue,
            nextSlice: currentState.nextPeerContext?.sliceValue
        )
        self.stateValue = stateValue
        self.statePromise.set(.single(stateValue))
        
        self.updatedPromise.set(.single(Void()))
    }
    
    func resetSideStates() {
        guard let currentState = self.currentState else {
            return
        }
        if let previousPeerContext = currentState.previousPeerContext {
            previousPeerContext.currentFocusedId = nil
        }
        if let nextPeerContext = currentState.nextPeerContext {
            nextPeerContext.currentFocusedId = nil
        }
    }
    
    func navigate(navigation: StoryContentContextNavigation) {
        guard let currentState = self.currentState else {
            return
        }
        
        switch navigation {
        case let .peer(direction):
            switch direction {
            case .previous:
                if let previousPeerContext = currentState.previousPeerContext, let previousSlice = previousPeerContext.sliceValue {
                    self.pendingStateReadyDisposable?.dispose()
                    self.pendingState = nil
                    self.focusedItem = (previousSlice.peer.id, nil)
                    self.switchToFocusedPeerId()
                }
            case .next:
                if let nextPeerContext = currentState.nextPeerContext, let nextSlice = nextPeerContext.sliceValue {
                    self.pendingStateReadyDisposable?.dispose()
                    self.pendingState = nil
                    self.focusedItem = (nextSlice.peer.id, nil)
                    self.switchToFocusedPeerId()
                }
            }
        case let .item(direction):
            if let slice = currentState.centralPeerContext.sliceValue {
                switch direction {
                case .previous:
                    if let previousItemId = slice.previousItemId {
                        currentState.centralPeerContext.currentFocusedId = previousItemId
                    }
                case .next:
                    if let nextItemId = slice.nextItemId {
                        currentState.centralPeerContext.currentFocusedId = nextItemId
                    }
                }
            }
        }
    }
}
