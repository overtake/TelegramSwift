//
//  ChatUndoManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac


private let queue: Queue = Queue()


enum ChatUndoActionType : Equatable {
    case clearHistory
    case deleteChat
    case deleteChannel
    case leftChat
    case leftChannel
}


enum ChatUndoActionStatus : Equatable {
    case processing
    case success
    case cancelled
    case none
}

private final class ChatUndoActionStatusContext {
    var status: ChatUndoActionStatus? {
        didSet {
            for subscriber in subscribers.copyItems() {
                subscriber(status)
            }
        }
    }
    let subscribers = Bag<(ChatUndoActionStatus?) -> Void>()
}

private struct ChatUndoActionKey : Hashable {
    private let peerId: PeerId
    private let type: ChatUndoActionType
    init(peerId: PeerId, type: ChatUndoActionType) {
        self.peerId = peerId
        self.type = type
    }
    var hashValue: Int {
        return Int(peerId.toInt64())
    }
}

struct ChatUndoAction : Hashable  {
    static func == (lhs: ChatUndoAction, rhs: ChatUndoAction) -> Bool {
        return lhs.peerId == rhs.peerId && lhs.type == rhs.type
    }
    fileprivate let endpoint: Double
    fileprivate let duration: Double
    private let peerId: PeerId
    fileprivate let type: ChatUndoActionType
    fileprivate let action: (ChatUndoActionStatus) -> Void
    init(peerId: PeerId, type: ChatUndoActionType, duration: Double = 5, action: @escaping(ChatUndoActionStatus) -> Void = { _ in}) {
        self.peerId = peerId
        self.type = type
        self.action = action
        self.duration = duration
        self.endpoint = Date().timeIntervalSince1970 + duration
    }
    
    
    func withUpdatedEndpoint(_ endpoint: Double) -> ChatUndoAction {
        return ChatUndoAction.init(peerId: self.peerId, type: self.type, duration: endpoint - Date().timeIntervalSince1970, action: self.action)
    }
    
    func isEqual(with peerId: PeerId, type: ChatUndoActionType) -> Bool {
        return self.peerId == peerId && self.type == type
    }
    
    var hashValue: Int {
        return Int(peerId.toInt64())
    }
}

struct ChatUndoStatuses {
    private let statuses: [ChatUndoAction : ChatUndoActionStatus]
    fileprivate init(_ statuses: [ChatUndoAction : ChatUndoActionStatus]) {
        self.statuses = statuses
    }
    
    func contains(peerId: PeerId, type: ChatUndoActionType) -> Bool {
        return statuses.first(where: { key, _ -> Bool in
            return key.isEqual(with: peerId, type: type)
        }) != nil
    }
    
    func isActive(peerId: PeerId, types: [ChatUndoActionType]) -> Bool {
        for type in types {
            let result = statuses.first(where: { current -> Bool in
                return current.key.isEqual(with: peerId, type: type) && (current.value == .processing || current.value == .success)
            }) != nil
            
            if result {
                return result
            }
        }
        return false
    }
    
    func status(for peerId: PeerId, type: ChatUndoActionType) -> ChatUndoActionStatus? {
        return statuses.first(where: { key, _ -> Bool in
            return key.isEqual(with: peerId, type: type)
        })?.value
    }
    
    var hasProcessingActions: Bool {
        return !statuses.filter ({ _, value in
            return value == .processing
        }).isEmpty
    }
    
    var maximumDuration: Double {
        var max: Double = 0
        for (action, value) in statuses {
            if value == .processing, max < action.duration {
                max = action.duration
            }
        }
        return max
    }
    
    var actionsCount: Int {
        return statuses.filter {$0.value == .processing}.count
    }
    
    var endpoint: Double {
        var max: Double = 0
        for (action, value) in statuses {
            if value == .processing, max < action.duration {
                max = action.endpoint
            }
        }
        return max
    }
    var secondsUntilFinish: Double {
        return endpoint - Date().timeIntervalSince1970
    }
    
    var activeDescription: String {
        let clearingCount = statuses.filter {$0.key.type == .clearHistory && $0.value == .processing}.count
        let deleteCount = statuses.filter {$0.key.type == .deleteChat && $0.value == .processing}.count
        let deleteChannelCount = statuses.filter {$0.key.type == .deleteChannel && $0.value == .processing}.count

        let leftChatCount = statuses.filter {$0.key.type == .leftChat && $0.value == .processing}.count
        let leftChannelCount = statuses.filter {$0.key.type == .leftChannel && $0.value == .processing}.count

        
        var text: String = ""
        
        if leftChatCount > 0 {
            if !text.isEmpty {
                text += ", "
            }
            text = L10n.chatUndoManagerChatLeftCountable(leftChatCount)
        }
        
        if leftChannelCount > 0 {
            if !text.isEmpty {
                text += ", "
            }
            text = L10n.chatUndoManagerChannelLeftCountable(leftChannelCount)
        }
        if deleteCount > 0 {
            if !text.isEmpty {
                text += ", "
            }
            text = L10n.chatUndoManagerChatsDeletedCountable(deleteCount)
        }
        if deleteChannelCount > 0 {
            if !text.isEmpty {
                text += ", "
            }
            text = L10n.chatUndoManagerChannelDeletedCountable(deleteChannelCount)
        }
        if clearingCount > 0 {
            if !text.isEmpty {
                text += ", "
            }
            text += L10n.chatUndoManagerChatsHistoryClearedCountable(clearingCount)
        }
        return text
    }
}

private final class ChatUndoManagerContext {
    private let disposableDict: DisposableDict<ChatUndoAction> = DisposableDict()
    private var actions: Set<ChatUndoAction> = Set()
    private var statuses:[ChatUndoAction : ChatUndoActionStatusContext] = [:]
    private let allSubscribers = Bag<(ChatUndoStatuses) -> Void>()
    init() {
        
    }
    
    deinit {
        disposableDict.dispose()
    }
    
    private func restartProcessingActions(_ except: ChatUndoAction) {
        self.actions = Set(self.actions.map { action in
            if action == except {
                return action
            } else {
                return action.withUpdatedEndpoint(except.endpoint)
            }
        })

        for action in self.actions {
            if except != action {
                run(for: action)
            }
        }
    }
    
    func add(action: ChatUndoAction) {
        if let previous = actions.first(where: { $0 == action }) {
             previous.action(.cancelled)
        }
        
        actions.insert(action)
        if statuses[action] == nil {
            statuses[action] = ChatUndoActionStatusContext()
        }
        
        statuses[action]?.status = .processing

        
        restartProcessingActions(action)
        notifyAllSubscribers()
        run(for: action)
    }
    
    private func run(for action: ChatUndoAction) {
        disposableDict.set((Signal<Never, NoError>.complete() |> delay(action.endpoint - Date().timeIntervalSince1970, queue: queue)).start(completed: { [weak self] in
            self?.statuses[action]?.status = .success
            self?.notifyAllSubscribers()
            action.action(.success)
        }), forKey: action)
    }
    
    
    
    func cancel(action: ChatUndoAction) {
        actions.remove(action)
        statuses[action]?.status = .cancelled
        notifyAllSubscribers()
        action.action(.cancelled)
        disposableDict.set(nil, forKey: action)
    }
    
    private func notifyAllSubscribers() {
        var values:[ChatUndoAction : ChatUndoActionStatus] = [:]
        
        for action in self.actions {
            if let status = self.statuses[action]?.status {
                values[action] = status
            }
        }
        for subscribers in allSubscribers.copyItems() {
            subscribers(ChatUndoStatuses(values))
        }
    }
    
    private func status(for peerId: PeerId, type: ChatUndoActionType) -> ChatUndoAction? {
        return actions.first(where: {$0.isEqual(with: peerId, type: type)})
    }
    
    func status(for peerId: PeerId, type: ChatUndoActionType) -> Signal<ChatUndoActionStatus?, NoError> {
        return Signal { [weak self] subscriber -> Disposable in
            
            let keyAction = ChatUndoAction(peerId: peerId, type: type, action: {_ in})
            
            if self?.statuses[keyAction] == nil {
                self?.statuses[keyAction] = ChatUndoActionStatusContext()
            }
            
            let index = self?.statuses[keyAction]?.subscribers.add { status in
                subscriber.putNext(status)
            }
            subscriber.putNext(self?.statuses[keyAction]?.status)
            
            return ActionDisposable { [weak self] in
                if let index = index, let status = self?.statuses[keyAction] {
                    status.subscribers.remove(index)
                    if status.subscribers.copyItems().count == 0 {
                        self?.statuses.removeValue(forKey: keyAction)
                    }
                }
            }
        }
    }
    
    func cancelAll() {
        for action in actions.reversed() {
            if let status = statuses[action], status.status == .processing {
                disposableDict.set(nil, forKey: action)
                statuses[action]?.status = .cancelled
                actions.remove(action)
            }
            
        }
        notifyAllSubscribers()
    }
    
    func allStatuses() -> Signal<ChatUndoStatuses, NoError> {
        return Signal { [weak self] subscriber -> Disposable in
            
            guard let `self` = self else { return EmptyDisposable }
            
            var values:[ChatUndoAction : ChatUndoActionStatus] = [:]

            for action in self.actions {
                if let status = self.statuses[action]?.status {
                    values[action] = status
                }
            }
            
            let index = self.allSubscribers.add { statuses in
                subscriber.putNext(statuses)
            }
            
            subscriber.putNext(ChatUndoStatuses(values))
            
            return ActionDisposable { [weak self] in
               self?.allSubscribers.remove(index)
            }
        }
    }
    
    fileprivate func finishAction(for peerId: PeerId, type: ChatUndoActionType) {
        let keyAction = ChatUndoAction(peerId: peerId, type: type)
        statuses[keyAction]?.status = nil
        actions.remove(keyAction)
        disposableDict.set(nil, forKey: keyAction)
        notifyAllSubscribers()
    }
    fileprivate func invokeNow(for peerId: PeerId, type: ChatUndoActionType) {
        let keyAction = ChatUndoAction(peerId: peerId, type: type)
        if let action = actions.first(where: {$0 == keyAction}) {
            statuses[keyAction]?.status = .success
            action.action(.success)
            self.actions.remove(action)
            disposableDict.set(nil, forKey: keyAction)
            notifyAllSubscribers()
        }
    }
}



final class ChatUndoManager  {
    
    private let context: ChatUndoManagerContext
    init() {
        context = ChatUndoManagerContext()
    }
    
    func cancel(action: ChatUndoAction) {
        queue.async { [weak context] in
            context?.cancel(action: action)
        }
    }
    
    func cancelAll() -> Void {
        queue.async { [weak context] in
            context?.cancelAll()
        }
    }
    
    func add(action: ChatUndoAction) {
        queue.async { [weak context] in
            context?.add(action: action)
        }
    }
    
    func allStatuses() -> Signal<ChatUndoStatuses, NoError> {
        var status: Signal<ChatUndoStatuses, NoError> = .complete()
        queue.sync {
            status = context.allStatuses()
        }
        return status
    }
    
    func status(for peerId: PeerId, type: ChatUndoActionType) -> Signal<ChatUndoActionStatus?, NoError> {
        var status: Signal<ChatUndoActionStatus?, NoError> = .complete()
        queue.sync {
            status = context.status(for: peerId, type: type)
        }
        return status
    }
    
    func clearHistoryInteractively(postbox: Postbox, peerId: PeerId, type: InteractiveMessagesDeletionType = .forLocalPeer) {
        _ = TelegramCoreMac.clearHistoryInteractively(postbox: postbox, peerId: peerId, type: type).start(completed: { [weak context] in
            queue.async {
              context?.finishAction(for: peerId, type: .clearHistory)
            }
        })
    }
    func removePeerChat(account: Account, peerId: PeerId, type: ChatUndoActionType, reportChatSpam: Bool, deleteGloballyIfPossible: Bool = false) {
        _ = TelegramCoreMac.removePeerChat(account: account, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: deleteGloballyIfPossible).start(completed: { [weak context] in
            queue.async {
                context?.finishAction(for: peerId, type: type)
            }
        })
    }
    
    func invokeNow(for peerId: PeerId, type: ChatUndoActionType) {
        queue.sync { [weak context] in
            context?.invokeNow(for: peerId, type: .clearHistory)
        }
    }
    
}


func enqueueMessages(context: AccountContext, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {
    context.chatUndoManager.invokeNow(for: peerId, type: .clearHistory)
    return TelegramCoreMac.enqueueMessages(account: context.account, peerId: peerId, messages: messages)
}
