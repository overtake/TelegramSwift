//
//  RecentSessionsController.swift
//  Telegram
//
//  Created by keepcoder on 08/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import Foundation
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac

private final class RecentSessionsControllerArguments {
    let account: Account
    
    let removeSession: (Int64) -> Void
    let terminateOthers:() -> Void
    init(account: Account, removeSession: @escaping (Int64) -> Void, terminateOthers: @escaping()->Void) {
        self.account = account
        self.removeSession = removeSession
        self.terminateOthers = terminateOthers
    }
}


private enum RecentSessionsEntryStableId: Hashable {
    case session(Int64)
    case index(Int32)
    case section(Int)
    var hashValue: Int {
        switch self {
        case let .session(hash):
            return hash.hashValue
        case let .index(index):
            return index.hashValue
        case let .section(section):
            return section.hashValue
        }
    }
    
    static func ==(lhs: RecentSessionsEntryStableId, rhs: RecentSessionsEntryStableId) -> Bool {
        switch lhs {
        case let .session(hash):
            if case .session(hash) = rhs {
                return true
            } else {
                return false
            }
        case let .index(index):
            if case .index(index) = rhs {
                return true
            } else {
                return false
            }
        case let .section(sectionId):
            if case .section(sectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum RecentSessionsEntry: Comparable, Identifiable {
    case loading(sectionId:Int)
    case currentSessionHeader(sectionId:Int)
    case currentSession(sectionId:Int, RecentAccountSession)
    case terminateOtherSessions(sectionId:Int)
    case currentSessionInfo(sectionId:Int)
    
    case otherSessionsHeader(sectionId:Int)
    case session(sectionId:Int, index: Int32, session: RecentAccountSession, enabled: Bool, editing: Bool)
    case section(sectionId:Int)

    
    
    var stableId: RecentSessionsEntryStableId {
        switch self {
        case .loading:
            return .index(0)
        case .currentSessionHeader:
            return .index(1)
        case .currentSession:
            return .index(2)
        case .terminateOtherSessions:
            return .index(3)
        case .currentSessionInfo:
            return .index(4)
        case .otherSessionsHeader:
            return .index(5)
        case let .session(_, _, session, _, _):
            return .session(session.hash)
        case let .section(sectionId):
            return .section(sectionId)
        }
    }
    
    var stableIndex: Int {
        switch self {
        case .loading:
            return 0
        case .currentSessionHeader:
            return 1
        case .currentSession:
            return 2
        case .terminateOtherSessions:
            return 3
        case .currentSessionInfo:
            return 4
        case .otherSessionsHeader:
            return 5
        case let .session(_, _, _, _, _):
            fatalError()
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var sectionId: Int {
        switch self {
        case let .loading(sectionId):
            return sectionId
        case let .currentSessionHeader(sectionId):
            return sectionId
        case let .currentSession(sectionId, _):
            return sectionId
        case let .terminateOtherSessions(sectionId):
            return sectionId
        case let .currentSessionInfo(sectionId):
            return sectionId
        case let .otherSessionsHeader(sectionId):
            return sectionId
        case let .session(sectionId, _, _, _, _):
            return sectionId
        case let .section(sectionId):
            return sectionId
        }
    }
    
    var sortIndex:Int {
        switch self {
        case let .loading(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .currentSessionHeader(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .currentSession(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .terminateOtherSessions(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .currentSessionInfo(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .otherSessionsHeader(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .session(sectionId, index, _, _, _):
            return (sectionId * 1000) + Int(index) + 100
        case let .section(sectionId):
            return (sectionId * 1000) + stableIndex
        }
    }
    
    static func ==(lhs: RecentSessionsEntry, rhs: RecentSessionsEntry) -> Bool {
        switch lhs {
        case .currentSessionHeader, .terminateOtherSessions, .currentSessionInfo, .otherSessionsHeader, .section, .loading:
            return lhs.stableId == rhs.stableId && lhs.sectionId == rhs.sectionId
        case let .currentSession(sectionId, session):
            if case .currentSession(sectionId, session) = rhs {
                return true
            } else {
                return false
            }
        case let .session(sectionId, index, session, enabled, editing):
            if case .session(sectionId, index, session, enabled, editing) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    
    
    static func <(lhs: RecentSessionsEntry, rhs: RecentSessionsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: RecentSessionsControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .currentSessionHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.sessionsCurrentSessionHeader))
        case let .currentSession(_, session):
            return RecentSessionRowItem(initialSize, session: session, stableId: stableId, revoke: {})
        case .terminateOtherSessions:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.sessionsTerminateOthers), nameStyle: redActionButton, type: .none, action: {
                arguments.terminateOthers()
            })
        case .currentSessionInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.sessionsTerminateDescription))
        case .otherSessionsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.sessionsActiveSessionsHeader))
        case let .session(_, _, session, _, _):
            return RecentSessionRowItem(initialSize, session: session, stableId: stableId, revoke: {
                arguments.removeSession(session.hash)
            })
        case .section(sectionId: _):
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        }
    }
}

private struct RecentSessionsControllerState: Equatable {
    let editing: Bool
    let sessionIdWithRevealedOptions: Int64?
    let removingSessionId: Int64?
    
    init() {
        self.editing = false
        self.sessionIdWithRevealedOptions = nil
        self.removingSessionId = nil
    }
    
    init(editing: Bool, sessionIdWithRevealedOptions: Int64?, removingSessionId: Int64?) {
        self.editing = editing
        self.sessionIdWithRevealedOptions = sessionIdWithRevealedOptions
        self.removingSessionId = removingSessionId
    }
    
    static func ==(lhs: RecentSessionsControllerState, rhs: RecentSessionsControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.sessionIdWithRevealedOptions != rhs.sessionIdWithRevealedOptions {
            return false
        }
        if lhs.removingSessionId != rhs.removingSessionId {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> RecentSessionsControllerState {
        return RecentSessionsControllerState(editing: editing, sessionIdWithRevealedOptions: self.sessionIdWithRevealedOptions, removingSessionId: self.removingSessionId)
    }
    
    func withUpdatedSessionIdWithRevealedOptions(_ sessionIdWithRevealedOptions: Int64?) -> RecentSessionsControllerState {
        return RecentSessionsControllerState(editing: self.editing, sessionIdWithRevealedOptions: sessionIdWithRevealedOptions, removingSessionId: self.removingSessionId)
    }
    
    func withUpdatedRemovingSessionId(_ removingSessionId: Int64?) -> RecentSessionsControllerState {
        return RecentSessionsControllerState(editing: self.editing, sessionIdWithRevealedOptions: self.sessionIdWithRevealedOptions, removingSessionId: removingSessionId)
    }
}

private func recentSessionsControllerEntries(state: RecentSessionsControllerState, sessions: [RecentAccountSession]?) -> [RecentSessionsEntry] {
    var entries: [RecentSessionsEntry] = []
    
    if let sessions = sessions {
        
        var sectionId:Int = 1
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        var existingSessionIds = Set<Int64>()
        entries.append(.currentSessionHeader(sectionId: sectionId))
        if let index = sessions.index(where: { $0.hash == 0 }) {
            existingSessionIds.insert(sessions[index].hash)
            entries.append(.currentSession(sectionId: sectionId, sessions[index]))
        }
        entries.append(.terminateOtherSessions(sectionId: sectionId))
        entries.append(.currentSessionInfo(sectionId: sectionId))
        
        if sessions.count > 1 {
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
            
            entries.append(.otherSessionsHeader(sectionId: sectionId))
             
            let filteredSessions: [RecentAccountSession] = sessions.sorted(by: { lhs, rhs in
                return lhs.activityDate > rhs.activityDate
            })
            
            for i in 0 ..< filteredSessions.count {
                if !existingSessionIds.contains(sessions[i].hash) {
                    existingSessionIds.insert(sessions[i].hash)
                    let session = sessions[i]
                    let enabled = state.removingSessionId != sessions[i].hash
                    entries.append(.session(sectionId: sectionId, index: Int32(i), session: session, enabled: enabled, editing: state.editing))
                }
            }
        }
    } else {
        entries.append(.loading(sectionId: 1))
    }
    
    return entries
}


private func prepareSessions(left:[AppearanceWrapperEntry<RecentSessionsEntry>], right: [AppearanceWrapperEntry<RecentSessionsEntry>], arguments: RecentSessionsControllerArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class RecentSessionsController : TableViewController {
    
    override func viewDidLoad() {
        let statePromise = ValuePromise(RecentSessionsControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: RecentSessionsControllerState())
        let updateState: ((RecentSessionsControllerState) -> RecentSessionsControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        let account = self.account
        let initialSize = self.atomicSize
        let actionsDisposable = DisposableSet()
        
        let removeSessionDisposable = MetaDisposable()
        actionsDisposable.add(removeSessionDisposable)
        
        let sessionsPromise = Promise<[RecentAccountSession]?>(nil)
        
        let arguments = RecentSessionsControllerArguments(account: account, removeSession: { sessionId in
            updateState {
                return $0.withUpdatedRemovingSessionId(sessionId)
            }
            
            let applySessions: Signal<Void, TerminateSessionError> = sessionsPromise.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { sessions -> Signal<Void, NoError> in
                    if let sessions = sessions {
                        var updatedSessions = sessions
                        for i in 0 ..< updatedSessions.count {
                            if updatedSessions[i].hash == sessionId {
                                updatedSessions.remove(at: i)
                                break
                            }
                        }
                        sessionsPromise.set(.single(updatedSessions))
                    }
                    
                    return .complete()
                } |> mapError {_ in return .generic}

            
            removeSessionDisposable.set((terminateAccountSession(account: account, hash: sessionId) |> then(applySessions) |> deliverOnMainQueue).start(error: { error in
                switch error {
                case .freshReset:
                    alert(for: mainWindow, info: L10n.recentSessionsErrorFreshReset)
                default:
                    break
                }
                updateState {
                    return $0.withUpdatedRemovingSessionId(nil)
                }
            }, completed: {
                updateState {
                    return $0.withUpdatedRemovingSessionId(nil)
                }
            }))
        }, terminateOthers: {
            _ = (confirmSignal(for: mainWindow, information: tr(L10n.recentSessionsConfirmTerminateOthers)) |> filter {$0} |> map {_ in} |> mapToSignal{terminateOtherAccountSessions(account: account)}).start()
        })
        
        let sessionsSignal: Signal<[RecentAccountSession]?, NoError> = .single(nil) |> then(requestRecentAccountSessions(account: account) |> map { Optional($0) })
        
        sessionsPromise.set(sessionsSignal)
        
        let previousSessions: Atomic<[AppearanceWrapperEntry<RecentSessionsEntry>]> = Atomic(value: [])
        
        let signal = combineLatest(statePromise.get(), sessionsPromise.get(), appearanceSignal)
            |> deliverOnMainQueue
            |> map { state, sessions, appearance -> TableUpdateTransition in
                let entries = recentSessionsControllerEntries(state: state, sessions: sessions).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareSessions(left: previousSessions.swap(entries), right: entries, arguments: arguments, initialSize: initialSize.modify {$0})
            } |> afterDisposed {
                actionsDisposable.dispose()
        }
        
        genericView.merge(with: signal)
        readyOnce()
    }
    
   
}


