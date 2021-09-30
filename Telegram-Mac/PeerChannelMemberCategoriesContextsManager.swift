//
//  PeerChannelMemberCategoriesContextsManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Foundation
import Postbox
import TelegramCore

import SwiftSignalKit

enum PeerChannelMemberContextKey: Equatable, Hashable {
    case recent
    case recentSearch(String)
    case mentions(threadId: MessageId?, query: String?)
    case admins(String?)
    case contacts(String?)
    case bots(String?)
    case restrictedAndBanned(String?)
    case restricted(String?)
    case banned(String?)
    
}


private final class PeerChannelMembersOnlineContext {
    let subscribers = Bag<(Int32) -> Void>()
    let disposable: Disposable
    var value: Int32?
    var emptyTimer: SwiftSignalKit.Timer?
    
    init(disposable: Disposable) {
        self.disposable = disposable
    }
}


private final class PeerChannelMemberCategoriesContextsManagerImpl {
    fileprivate var contexts: [PeerId: PeerChannelMemberCategoriesContext] = [:]
    fileprivate var onlineContexts: [PeerId: PeerChannelMembersOnlineContext] = [:]
    fileprivate var replyThreadHistoryContexts: [MessageId: ReplyThreadHistoryContext] = [:]

    fileprivate let engine: TelegramEngine
    fileprivate let account: Account
    init(_ engine: TelegramEngine, account: Account) {
        self.engine = engine
        self.account = account
    }

    func getContext(peerId: PeerId, key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl) {
        if let current = self.contexts[peerId] {
            return current.getContext(key: key, requestUpdate: requestUpdate, updated: updated)
        } else {
            var becameEmptyImpl: ((Bool) -> Void)?
            let context = PeerChannelMemberCategoriesContext(engine: engine, account: account, peerId: peerId, becameEmpty: { value in
                becameEmptyImpl?(value)
            })
            becameEmptyImpl = { [weak self, weak context] value in
                assert(Queue.mainQueue().isCurrent())
                if let strongSelf = self {
                    if let current = strongSelf.contexts[peerId], current === context {
                        strongSelf.contexts.removeValue(forKey: peerId)
                    }
                }
            }
            self.contexts[peerId] = context
            return context.getContext(key: key, requestUpdate: requestUpdate, updated: updated)
        }
    }
    
    func recentOnline(peerId: PeerId, updated: @escaping (Int32) -> Void) -> Disposable {
        let context: PeerChannelMembersOnlineContext
        if let current = self.onlineContexts[peerId] {
            context = current
        } else {
            let disposable = MetaDisposable()
            context = PeerChannelMembersOnlineContext(disposable: disposable)
            self.onlineContexts[peerId] = context
            
            let signal = (
                engine.peers.chatOnlineMembers(peerId: peerId)
                    |> then(
                        .complete()
                            |> delay(30.0, queue: .mainQueue())
                )
                ) |> restart
            
            disposable.set(signal.start(next: { [weak context] value in
                guard let context = context else {
                    return
                }
                context.value = value
                for f in context.subscribers.copyItems() {
                    f(value)
                }
            }))
        }
        
        if let emptyTimer = context.emptyTimer {
            emptyTimer.invalidate()
            context.emptyTimer = nil
        }
        
        let index = context.subscribers.add({ next in
            updated(next)
        })
        updated(context.value ?? 0)
        
        return ActionDisposable { [weak self, weak context] in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let current = strongSelf.onlineContexts[peerId], let context = context, current === context {
                    current.subscribers.remove(index)
                    if current.subscribers.isEmpty {
                        if current.emptyTimer == nil {
                            let timer = SwiftSignalKit.Timer(timeout: 60.0, repeat: false, completion: { [weak context] in
                                if let current = strongSelf.onlineContexts[peerId], let context = context, current === context {
                                    if current.subscribers.isEmpty {
                                        strongSelf.onlineContexts.removeValue(forKey: peerId)
                                        current.disposable.dispose()
                                    }
                                }
                                }, queue: Queue.mainQueue())
                            current.emptyTimer = timer
                            timer.start()
                        }
                    }
                }
            }
        }
    }
    

    
    func loadMore(peerId: PeerId, control: PeerChannelMemberCategoryControl) {
        if let context = self.contexts[peerId] {
            context.loadMore(control)
        }
    }
}

final class PeerChannelMemberCategoriesContextsManager {
    private let impl: QueueLocalObject<PeerChannelMemberCategoriesContextsManagerImpl>
    
    private let engine: TelegramEngine
    private let account: Account
    init(_ engine: TelegramEngine, account: Account) {
        self.engine = engine
        self.account = account
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return PeerChannelMemberCategoriesContextsManagerImpl(engine, account: account)
        })
    }
    
    func loadMore(peerId: PeerId, control: PeerChannelMemberCategoryControl?) {
        if let control = control {
            self.impl.with { impl in
                impl.loadMore(peerId: peerId, control: control)
            }
        }
    }
    
    private func getContext(peerId: PeerId, key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        assert(Queue.mainQueue().isCurrent())
        
        return self.impl.syncWith({ impl in
            return impl.getContext(peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
        })

    }
    
    func transferOwnership(peerId: PeerId, memberId: PeerId, password: String) -> Signal<Void, ChannelOwnershipTransferError> {
        return engine.peers.updateChannelOwnership(channelId: peerId, memberId: memberId, password: password)
            |> map(Optional.init)
            |> deliverOnMainQueue
            |> beforeNext { [weak self] results in
                if let strongSelf = self, let results = results {
                    strongSelf.impl.with { impl in
                        for (contextPeerId, context) in impl.contexts {
                            if peerId == contextPeerId {
                                context.replayUpdates(results.map { ($0.0, $0.1, nil) })
                            }
                        }
                    }
                }
            }
            |> mapToSignal { _ -> Signal<Void, ChannelOwnershipTransferError> in
                return .complete()
        }
    }

    
    func externallyAdded(peerId: PeerId, participant: RenderedChannelParticipant) {
        self.impl.with { impl in
            for (contextPeerId, context) in impl.contexts {
                if contextPeerId == peerId {
                    context.replayUpdates([(nil, participant, nil)])
                }
            }
        }
    }
    
    func mentions(peerId: PeerId, threadMessageId: MessageId?, searchQuery: String? = nil, requestUpdate: Bool = true, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        let key: PeerChannelMemberContextKey = .mentions(threadId: threadMessageId, query: searchQuery)
        return self.getContext(peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
    }
    
    func recent(peerId: PeerId, searchQuery: String? = nil, requestUpdate: Bool = true, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        let key: PeerChannelMemberContextKey
        if let searchQuery = searchQuery {
            key = .recentSearch(searchQuery)
        } else {
            key = .recent
        }
        return self.getContext(peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
    }
    
    func recentOnline(peerId: PeerId) -> Signal<Int32, NoError> {
        return Signal { [weak self] subscriber in
            guard let strongSelf = self else {
                subscriber.putNext(0)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let disposable = strongSelf.impl.syncWith({ impl -> Disposable in
                return impl.recentOnline(peerId: peerId, updated: { value in
                    subscriber.putNext(value)
                })
            })
            return disposable ?? EmptyDisposable
            }
            |> runOn(Queue.mainQueue())
    }

    
    func recentOnlineSmall(peerId: PeerId) -> Signal<Int32, NoError> {
        let account = self.account
        return Signal { [weak self] subscriber in
            guard let strongSelf = self else {
                return EmptyDisposable
            }
            var previousIds: Set<PeerId>?
            let statusesDisposable = MetaDisposable()
            let disposableAndControl = self?.recent(peerId: peerId, updated: { state in
                var idList: [PeerId] = []
                for item in state.list {
                    idList.append(item.peer.id)
                    if idList.count >= 200 {
                        break
                    }
                }
                let updatedIds = Set(idList)
                if previousIds != updatedIds {
                    previousIds = updatedIds
                    let key: PostboxViewKey = .peerPresences(peerIds: updatedIds)
                    statusesDisposable.set((strongSelf.account.postbox.combinedView(keys: [key])
                        |> map { view -> Int32 in
                            var count: Int32 = 0
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                            if let presences = (view.views[key] as? PeerPresencesView)?.presences {
                                for (_, presence) in presences {
                                    if let presence = presence as? TelegramUserPresence {
                                        let networkTime = account.network.globalTime > 0 ? account.network.globalTime - timestamp : 0
                                        
                                        let relativeStatus = relativeUserPresenceStatus(presence, timeDifference: networkTime, relativeTo: Int32(timestamp))
                                        sw: switch relativeStatus {
                                        case let .online(at: until):
                                            if until > Int32(timestamp) {
                                                count += 1
                                            }
                                        default:
                                            break sw
                                        }
                                    }
                                }
                            }
                            return count
                        }
                        |> distinctUntilChanged
                        |> deliverOnMainQueue).start(next: { count in
                            subscriber.putNext(count)
                        }))
                }
            })
            return ActionDisposable {
                disposableAndControl?.0.dispose()
                statusesDisposable.dispose()
            }
            }
            |> runOn(Queue.mainQueue())
        
    }
    
    func admins(peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(peerId: peerId, key: .admins(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func restricted(peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(peerId: peerId, key: .restricted(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func banned(peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(peerId: peerId, key: .banned(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func restrictedAndBanned(peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(peerId: peerId, key: .restrictedAndBanned(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func updateMemberBannedRights(peerId: PeerId, memberId: PeerId, bannedRights: TelegramChatBannedRights?) -> Signal<Void, NoError> {
        return engine.peers.updateChannelMemberBannedRights(peerId: peerId, memberId: memberId, rights: bannedRights)
            |> deliverOnMainQueue
            |> beforeNext { [weak self] (previous, updated, isMember) in
                if let strongSelf = self {
                    strongSelf.impl.with { impl in
                        for (contextPeerId, context) in impl.contexts {
                            if peerId == contextPeerId {
                                context.replayUpdates([(previous, updated, isMember)])
                            }
                        }
                    }
                }
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
        }
    }
    
    func updateMemberAdminRights(peerId: PeerId, memberId: PeerId, adminRights: TelegramChatAdminRights?, rank: String?) -> Signal<Void, NoError> {
        return engine.peers.updateChannelAdminRights(peerId: peerId, adminId: memberId, rights: adminRights, rank: rank)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, NoError> in
                return .single(nil)
            }
            |> deliverOnMainQueue
            |> beforeNext { [weak self] result in
                if let strongSelf = self, let (previous, updated) = result {
                    strongSelf.impl.with { impl in
                        for (contextPeerId, context) in impl.contexts {
                            if peerId == contextPeerId {
                                context.replayUpdates([(previous, updated, nil)])
                            }
                        }
                    }
                }
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
        }
    }
    
    func addMember(peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
        return engine.peers.addChannelMember(peerId: peerId, memberId: memberId)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, NoError> in
                return .single(nil)
            }
            |> deliverOnMainQueue
            |> beforeNext { [weak self] result in
                if let strongSelf = self, let (previous, updated) = result {
                    strongSelf.impl.with { impl in
                        for (contextPeerId, context) in impl.contexts {
                            if peerId == contextPeerId {
                                context.replayUpdates([(previous, updated, nil)])
                            }
                        }
                    }
                }
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
        }
    }
    
    func addMembers(peerId: PeerId, memberIds: [PeerId]) -> Signal<Void, AddChannelMemberError> {
        let signals: [Signal<(ChannelParticipant?, RenderedChannelParticipant)?, AddChannelMemberError>] = memberIds.map({ memberId in
            return engine.peers.addChannelMember(peerId: peerId, memberId: memberId)
                |> map(Optional.init)
                |> `catch` { error -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, AddChannelMemberError> in
                    if memberIds.count == 1 {
                        return .fail(error)
                    } else {
                        return .single(nil)
                    }
            }
        })
        return combineLatest(signals)
            |> deliverOnMainQueue
            |> beforeNext { [weak self] results in
                if let strongSelf = self {
                    strongSelf.impl.with { impl in
                        for result in results {
                            if let (previous, updated) = result {
                                for (contextPeerId, context) in impl.contexts {
                                    if peerId == contextPeerId {
                                        context.replayUpdates([(previous, updated, nil)])
                                    }
                                }
                            }
                        }
                    }
                }
            }
            |> mapToSignal { _ -> Signal<Void, AddChannelMemberError> in
                return .complete()
        }
    }
    
    func replyThread(account: Account, messageId: MessageId) -> Signal<MessageHistoryViewExternalInput, NoError> {
        return .complete()
    }


}
