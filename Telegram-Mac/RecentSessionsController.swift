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
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore

private final class RecentSessionsControllerArguments {
    let context: AccountContext
    
    let removeSession: (Int64) -> Void
    let terminateOthers:() -> Void
    init(context: AccountContext, removeSession: @escaping (Int64) -> Void, terminateOthers: @escaping()->Void) {
        self.context = context
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
    
}

private enum RecentSessionsEntry: Comparable, Identifiable {
    case loading(sectionId:Int)
    case currentSessionHeader(sectionId:Int, viewType: GeneralViewType)
    case currentSession(sectionId:Int, RecentAccountSession, viewType: GeneralViewType)
    case terminateOtherSessions(sectionId:Int, viewType: GeneralViewType)
    case currentSessionInfo(sectionId:Int, viewType: GeneralViewType)
    
    case otherSessionsHeader(sectionId:Int, viewType: GeneralViewType)
    
    case incompleteHeader(sectionId: Int, viewType: GeneralViewType)
    case incompleteDesc(sectionId: Int, viewType: GeneralViewType)
    
    case session(sectionId:Int, index: Int32, session: RecentAccountSession, enabled: Bool, editing: Bool, viewType: GeneralViewType)
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
        case .incompleteHeader:
            return .index(5)
        case .incompleteDesc:
            return .index(6)
        case .otherSessionsHeader:
            return .index(7)
        case let .session(_, _, session, _, _, _):
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
        case .incompleteHeader:
            return 5
        case .incompleteDesc:
            return 6
        case .otherSessionsHeader:
            return 7
        case .session:
            fatalError()
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var sectionId: Int {
        switch self {
        case let .loading(sectionId):
            return sectionId
        case let .currentSessionHeader(sectionId, _):
            return sectionId
        case let .currentSession(sectionId, _, _):
            return sectionId
        case let .terminateOtherSessions(sectionId, _):
            return sectionId
        case let .currentSessionInfo(sectionIdv):
            return sectionId
        case let .incompleteHeader(sectionId, _):
            return sectionId
        case let .incompleteDesc(sectionId, _):
            return sectionId
        case let .otherSessionsHeader(sectionId, _):
            return sectionId
        case let .session(sectionId, _, _, _, _, _):
            return sectionId
        case let .section(sectionId):
            return sectionId
        }
    }
    
    var sortIndex:Int {
        switch self {
        case let .loading(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .currentSessionHeader(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .currentSession(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .terminateOtherSessions(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .currentSessionInfo(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .incompleteHeader(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .incompleteDesc(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .otherSessionsHeader(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .session(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + Int(index) + 100
        case let .section(sectionId):
            return (sectionId * 1000) + stableIndex
        }
    }
    
    
    static func <(lhs: RecentSessionsEntry, rhs: RecentSessionsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: RecentSessionsControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .currentSessionHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.sessionsCurrentSessionHeader, viewType: viewType)
        case let .currentSession(_, session, viewType):
            return RecentSessionRowItem(initialSize, session: session, stableId: stableId, viewType: viewType, revoke: {})
        case let .terminateOtherSessions(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.sessionsTerminateOthers, nameStyle: redActionButton, type: .none, viewType: viewType, action: {
                arguments.terminateOthers()
            })
        case let .currentSessionInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.sessionsTerminateDescription, viewType: viewType)
        case let .incompleteHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.recentSessionsIncompleteAttemptHeader, viewType: viewType)
        case let .incompleteDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.recentSessionsIncompleteAttemptDesc, viewType: viewType)
        case let .otherSessionsHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.sessionsActiveSessionsHeader, viewType: viewType)
        case let .session(_, _, session, _, _, viewType):
            return RecentSessionRowItem(initialSize, session: session, stableId: stableId, viewType: viewType, revoke: {
                arguments.removeSession(session.hash)
            })
        case .section(sectionId: _):
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
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
        entries.append(.currentSessionHeader(sectionId: sectionId, viewType: .textTopItem))
        if let index = sessions.firstIndex(where: { $0.hash == 0 }) {
            existingSessionIds.insert(sessions[index].hash)
            entries.append(.currentSession(sectionId: sectionId, sessions[index], viewType: .firstItem))
        }
        entries.append(.terminateOtherSessions(sectionId: sectionId, viewType: .lastItem))
        entries.append(.currentSessionInfo(sectionId: sectionId, viewType: .textBottomItem))
        
        if sessions.count > 1 {
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
            
            let filteredSessions: [RecentAccountSession] = sessions.sorted(by: { lhs, rhs in
                return lhs.activityDate > rhs.activityDate
            })
            
            let nonApplied = filteredSessions.filter {$0.flags.contains(.passwordPending)}
            let applied = filteredSessions.filter {!$0.flags.contains(.passwordPending)}
            
            var index: Int32 = 0
            
            if !nonApplied.isEmpty {
                entries.append(.incompleteHeader(sectionId: sectionId, viewType: .textTopItem))
                
                let nonApplied = nonApplied.filter({
                    !existingSessionIds.contains($0.hash)
                })
                for session in nonApplied {
                    existingSessionIds.insert(session.hash)
                    let enabled = state.removingSessionId != session.hash
                    entries.append(.session(sectionId: sectionId, index: index, session: session, enabled: enabled, editing: state.editing, viewType: bestGeneralViewType(nonApplied, for: session)))
                    index += 1
                }
                entries.append(.incompleteDesc(sectionId: sectionId, viewType: .textBottomItem))
                
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
            }
            
            entries.append(.otherSessionsHeader(sectionId: sectionId, viewType: .textTopItem))
            let newApplied = applied.filter({
                !existingSessionIds.contains($0.hash)
            })
            for session in newApplied {
                existingSessionIds.insert(session.hash)
                let enabled = state.removingSessionId != session.hash
                entries.append(.session(sectionId: sectionId, index: index, session: session, enabled: enabled, editing: state.editing, viewType: bestGeneralViewType(newApplied, for: session)))
                index += 1
            }
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
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
    private let activeSessions: [RecentAccountSession]?
    init(_ context: AccountContext, activeSessions: [RecentAccountSession]?) {
        self.activeSessions = activeSessions
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let statePromise = ValuePromise(RecentSessionsControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: RecentSessionsControllerState())
        let updateState: ((RecentSessionsControllerState) -> RecentSessionsControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        let context = self.context
        let initialSize = self.atomicSize
        let actionsDisposable = DisposableSet()
        
        let removeSessionDisposable = MetaDisposable()
        actionsDisposable.add(removeSessionDisposable)
        
        let sessionsPromise = Promise<[RecentAccountSession]?>()
        
        let arguments = RecentSessionsControllerArguments(context: context, removeSession: { sessionId in
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

            
            removeSessionDisposable.set((terminateAccountSession(account: context.account, hash: sessionId) |> then(applySessions) |> deliverOnMainQueue).start(error: { _ in
                updateState {
                    return $0.withUpdatedRemovingSessionId(nil)
                }
            }, completed: {
                updateState {
                    return $0.withUpdatedRemovingSessionId(nil)
                }
            }))
        }, terminateOthers: {
            confirm(for: context.window, information: L10n.recentSessionsConfirmTerminateOthers, successHandler: { _ in
                _ = showModalProgress(signal: terminateOtherAccountSessions(account: context.account), for: context.window).start(error: { error in
                    
                })
            })
        })
        
        let sessionsSignal: Signal<[RecentAccountSession]?, NoError> = .single(self.activeSessions) |> then(requestRecentAccountSessions(account: context.account) |> map { Optional($0) })
        
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


