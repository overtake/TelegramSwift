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

func iconForSession(_ session: RecentAccountSession) -> (CGImage?, LocalAnimatedSticker?, NSColor?) {
    let platform = session.platform.lowercased()
    let device = session.deviceModel.lowercased()
    let systemVersion = session.systemVersion.lowercased()
    if device.contains("xbox") {
        return (NSImage(named: "Icon_Device_Xbox")?.precomposed(), nil, NSColor(rgb: 0x35c759))
    }
    if device.contains("chrome") && !platform.contains("chromebook") {
        return (NSImage(named: "Icon_Device_Chrome")?.precomposed(), LocalAnimatedSticker.device_chrome, NSColor(rgb: 0x35c759))
    }
    if device.contains("brave") {
        return (NSImage(named: "Icon_Device_Brave")?.precomposed(), nil, NSColor(rgb: 0xff9500))
    }
    if device.contains("vivaldi") {
        return (NSImage(named: "Icon_Device_Vivaldi")?.precomposed(), nil, NSColor(rgb: 0xff3c30))
    }
    if device.contains("safari") {
        return (NSImage(named: "Icon_Device_Safari")?.precomposed(), LocalAnimatedSticker.device_safari, NSColor(rgb: 0x0079ff))
    }
    if device.contains("firefox") {
        return (NSImage(named: "Icon_Device_Firefox")?.precomposed(), LocalAnimatedSticker.device_firefox, NSColor(rgb: 0xff9500))
    }
    if device.contains("opera") {
        return (NSImage(named: "Icon_Device_Opera")?.precomposed(), nil, NSColor(rgb: 0xff3c30))
    }
    if platform.contains("android") {
        return (NSImage(named: "Icon_Device_Android")?.precomposed(), LocalAnimatedSticker.device_android, NSColor(rgb: 0x35c759))
    }
    if (platform.contains("macos") || systemVersion.contains("macos")) && device.contains("mac")  {
        return (NSImage(named: "Icon_Device_Apple")?.precomposed(), LocalAnimatedSticker.device_mac, NSColor(rgb: 0x0079ff))
    }
    if device.contains("ipad") {
        return (NSImage(named: "Icon_Device_Ipad")?.precomposed(), LocalAnimatedSticker.device_ipad, NSColor(rgb: 0x0079ff))
    }
    if platform.contains("ios") || platform.contains("macos") || systemVersion.contains("macos") {
        return (NSImage(named: "Icon_Device_Iphone")?.precomposed(), LocalAnimatedSticker.device_iphone, NSColor(rgb: 0x0079ff))
    }
    if platform.contains("ubuntu") || systemVersion.contains("ubuntu") {
        return (NSImage(named: "Icon_Device_Ubuntu")?.precomposed(), LocalAnimatedSticker.device_ubuntu, NSColor(rgb: 0x0079ff))
    }
    if platform.contains("linux") || systemVersion.contains("linux") {
        return (NSImage(named: "Icon_Device_Linux")?.precomposed(), LocalAnimatedSticker.device_linux, NSColor(rgb: 0x8e8e93))
    }
    if platform.contains("windows") || systemVersion.contains("windows") {
        return (NSImage(named: "Icon_Device_Windows")?.precomposed(), LocalAnimatedSticker.device_windows, NSColor(rgb: 0x0079ff))
    }
    return (nil, nil, nil)
}


private final class RecentSessionsControllerArguments {
    let context: AccountContext
    
    let removeSession: (Int64) -> Void
    let terminateOthers:() -> Void
    let toggleTtl:(Int)->Void
    let preview:(RecentAccountSession)->Void
    init(context: AccountContext, removeSession: @escaping (Int64) -> Void, terminateOthers: @escaping()->Void, toggleTtl:@escaping(Int)->Void, preview:@escaping(RecentAccountSession)->Void) {
        self.context = context
        self.removeSession = removeSession
        self.terminateOthers = terminateOthers
        self.toggleTtl = toggleTtl
        self.preview = preview
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
    
    case revokeOldHeader(sectionId:Int, viewType: GeneralViewType)
    case revokeOld(sectionId:Int, Int32, viewType: GeneralViewType)

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
        case .revokeOldHeader:
            return .index(8)
        case .revokeOld:
            return .index(9)
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
        case .revokeOldHeader:
            return 8
        case .revokeOld:
            return 9
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
        case let .currentSessionInfo(sectionId, _):
            return sectionId
        case let .incompleteHeader(sectionId, _):
            return sectionId
        case let .incompleteDesc(sectionId, _):
            return sectionId
        case let .otherSessionsHeader(sectionId, _):
            return sectionId
        case let .revokeOldHeader(sectionId, _):
            return sectionId
        case let .revokeOld(sectionId, _, _):
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
        case let .revokeOldHeader(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .revokeOld(sectionId, _, _):
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
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().sessionsCurrentSessionHeader, viewType: viewType)
        case let .currentSession(_, session, viewType):
            return RecentSessionRowItem(initialSize, session: session, stableId: stableId, viewType: viewType, icon: iconForSession(session), handler: {})
        case let .terminateOtherSessions(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().sessionsTerminateOthers, nameStyle: redActionButton, type: .none, viewType: viewType, action: {
                arguments.terminateOthers()
            })
        case let .currentSessionInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().sessionsTerminateDescription, viewType: viewType)
        case let .incompleteHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().recentSessionsIncompleteAttemptHeader, viewType: viewType)
        case let .incompleteDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().recentSessionsIncompleteAttemptDesc, viewType: viewType)
        case let .otherSessionsHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().sessionsActiveSessionsHeader, viewType: viewType)
        case let .session(_, _, session, _, _, viewType):
            return RecentSessionRowItem(initialSize, session: session, stableId: stableId, viewType: viewType, icon: iconForSession(session), handler: {
                arguments.preview(session)
            })
        case let .revokeOldHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().recentSessionsTTLHeader, viewType: viewType)
        case let .revokeOld(_, ttl, viewType):
            
            var items:[SPopoverItem] = []
            items.append(.init(strings().timerWeeksCountable(1), {
                arguments.toggleTtl(7)
            }))
            
            items.append(.init(strings().timerMonthsCountable(1), {
                arguments.toggleTtl(31)
            }))
            items.append(.init(strings().timerMonthsCountable(3), {
                arguments.toggleTtl(31 * 3)
            }))
            items.append(.init(strings().timerMonthsCountable(6), {
                arguments.toggleTtl(31 * 6)
            }))
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().recentSessionsTTLText, type: .contextSelector(autoremoveLocalized(Int(ttl * 24 * 60 * 60)), items), viewType: viewType)
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

private func recentSessionsControllerEntries(state: RecentSessionsControllerState, sessions: ActiveSessionsContextState) -> [RecentSessionsEntry] {
    var entries: [RecentSessionsEntry] = []
    
    
    var sectionId:Int = 1
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    var existingSessionIds = Set<Int64>()
    entries.append(.currentSessionHeader(sectionId: sectionId, viewType: .textTopItem))
    if let index = sessions.sessions.firstIndex(where: { $0.hash == 0 }) {
        existingSessionIds.insert(sessions.sessions[index].hash)
        entries.append(.currentSession(sectionId: sectionId, sessions.sessions[index], viewType: .firstItem))
    }
    entries.append(.terminateOtherSessions(sectionId: sectionId, viewType: existingSessionIds.isEmpty ? .singleItem : .lastItem))
    entries.append(.currentSessionInfo(sectionId: sectionId, viewType: .textBottomItem))
    
    if sessions.sessions.count > 1 {
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        let filteredSessions: [RecentAccountSession] = sessions.sessions.sorted(by: { lhs, rhs in
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
        
        entries.append(.revokeOldHeader(sectionId: sectionId, viewType: .textTopItem))
        entries.append(.revokeOld(sectionId: sectionId, sessions.ttlDays, viewType: .singleItem))
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
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
        
        let sessionsPromise = Promise<ActiveSessionsContextState>()
        
        let arguments = RecentSessionsControllerArguments(context: context, removeSession: { sessionId in
            updateState {
                return $0.withUpdatedRemovingSessionId(sessionId)
            }
            
            removeSessionDisposable.set((context.activeSessionsContext.remove(hash: sessionId) |> deliverOnMainQueue).start(error: { _ in
                updateState {
                    return $0.withUpdatedRemovingSessionId(nil)
                }
            }, completed: {
                updateState {
                    return $0.withUpdatedRemovingSessionId(nil)
                }
            }))
        }, terminateOthers: {
            confirm(for: context.window, information: strings().recentSessionsConfirmTerminateOthers, successHandler: { _ in
                _ = showModalProgress(signal: context.activeSessionsContext.removeOther(), for: context.window).start(error: { error in
                    
                })
            })
        }, toggleTtl: { ttl in
            _ = context.activeSessionsContext.updateAuthorizationTTL(days: Int32(ttl)).start()
        }, preview: { session in
            showModal(with: SessionModalController(context: context, session: session), for: context.window)
        })
        
        let sessionsSignal: Signal<ActiveSessionsContextState, NoError> = context.activeSessionsContext.state
        
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
        
        genericView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                context.activeSessionsContext.loadMore()
            default:
                break
            }
        }
        
        readyOnce()
    }
    
   
}


