//
//  GroupAdminsController.swift
//  Telegram
//
//  Created by keepcoder on 13/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


private final class GroupAdminsControllerArguments {
    let account: Account
    
    let updateAllAreAdmins: (Bool) -> Void
    let updatePeerIsAdmin: (PeerId, Bool) -> Void
    
    init(account: Account, updateAllAreAdmins: @escaping (Bool) -> Void, updatePeerIsAdmin: @escaping (PeerId, Bool) -> Void) {
        self.account = account
        self.updateAllAreAdmins = updateAllAreAdmins
        self.updatePeerIsAdmin = updatePeerIsAdmin
    }
}

private enum GroupAdminsSection: Int32 {
    case allAdmins
    case peers
}

private enum GroupAdminsEntryStableId: Hashable {
    case index(Int32)
    case section(Int)
    case peer(PeerId)
    
    var hashValue: Int {
        switch self {
        case let .section(index):
            return index.hashValue
        case let .index(index):
            return index.hashValue
        case let .peer(peerId):
            return peerId.hashValue
        }
    }
    
    static func ==(lhs: GroupAdminsEntryStableId, rhs: GroupAdminsEntryStableId) -> Bool {
        switch lhs {
        case let .index(index):
            if case .index(index) = rhs {
                return true
            } else {
                return false
            }
        case let .section(index):
            if case .section(index) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(peerId):
            if case .peer(peerId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum GroupAdminsEntry: Comparable, Identifiable {
    case allAdmins(sectionId:Int, Bool)
    case allAdminsInfo(sectionId:Int, String)
    case peerItem(sectionId:Int, Int32, Peer, PeerPresence?, Bool, Bool)
    case section(sectionId:Int)
    var stableId: GroupAdminsEntryStableId {
        switch self {
        case .allAdmins:
            return .index(0)
        case .allAdminsInfo:
            return .index(1)
        case let .section(sectionId):
            return .section(sectionId)
        case let .peerItem(_, _, peer, _, _, _):
            return .peer(peer.id)
        }
    }
    
    var stableIndex: Int {
        switch self {
        case .allAdmins:
            return 0
        case .allAdminsInfo:
            return 1
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        case .peerItem:
            fatalError()
        }
    }
    
    static func ==(lhs: GroupAdminsEntry, rhs: GroupAdminsEntry) -> Bool {
        switch lhs {
        case let .allAdmins(sectionId, value):
            if case .allAdmins(sectionId, value) = rhs {
                return true
            } else {
                return false
            }
        case let .allAdminsInfo(sectionId, text):
            if case .allAdminsInfo(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .section(section):
            if case .section(section) = rhs {
                return true
            } else {
                return false
            }
        case let .peerItem(lhsSectionId, lhsIndex, lhsPeer, lhsPresence, lhsToggled, lhsEnabled):
            if case let .peerItem(rhsSectionId, rhsIndex, rhsPeer, rhsPresence, rhsToggled, rhsEnabled) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                    if !lhsPresence.isEqual(to: rhsPresence) {
                        return false
                    }
                } else if (lhsPresence != nil) != (rhsPresence != nil) {
                    return false
                }
                if lhsToggled != rhsToggled {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
    
    var sortIndex:Int {
        switch self {
        case let .allAdmins(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .allAdminsInfo(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .peerItem(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + Int(index) + 100
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: GroupAdminsEntry, rhs: GroupAdminsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: GroupAdminsControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .allAdmins(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.groupAdminsAllMembersAdmins, type: .switchable(value), action: {
                arguments.updateAllAreAdmins(!value)
            })
            
        case let .allAdminsInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .peerItem(_, _, peer, presence, toggled, enabled):
            
            var string:String = tr(L10n.peerStatusRecently)
            var color:NSColor = theme.colors.grayText
            
            if let presence = presence as? TelegramUserPresence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string, _, color) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
            } else if let peer = peer as? TelegramUser, let botInfo = peer.botInfo {
                string = botInfo.flags.contains(.hasAccessToChatHistory) ? tr(L10n.peerInfoBotStatusHasAccess) : tr(L10n.peerInfoBotStatusHasNoAccess)
            }
            
            
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: stableId, enabled: enabled, height: 46, photoSize: NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(12.5)), statusStyle: ControlStyle(font: NSFont.normal(12.5), foregroundColor:color), status: string, drawLastSeparator: true, inset:NSEdgeInsets(left:30.0,right:30.0), generalType: .switchable(toggled), action: { 
                arguments.updatePeerIsAdmin(peer.id, !toggled)
            })
            
        }
    }
}

private struct GroupAdminsControllerState: Equatable {
    let updatingAllAdminsValue: Bool?
    let updatedAllAdminsValue: Bool?
    
    let updatingAdminValue: [PeerId: Bool]
    
    init() {
        self.updatingAllAdminsValue = nil
        self.updatedAllAdminsValue = nil
        self.updatingAdminValue = [:]
    }
    
    init(updatingAllAdminsValue: Bool?, updatedAllAdminsValue: Bool?, updatingAdminValue: [PeerId: Bool]) {
        self.updatingAllAdminsValue = updatingAllAdminsValue
        self.updatedAllAdminsValue = updatedAllAdminsValue
        self.updatingAdminValue = updatingAdminValue
    }
    
    static func ==(lhs: GroupAdminsControllerState, rhs: GroupAdminsControllerState) -> Bool {
        if lhs.updatingAllAdminsValue != rhs.updatingAllAdminsValue {
            return false
        }
        if lhs.updatedAllAdminsValue != rhs.updatedAllAdminsValue {
            return false
        }
        if lhs.updatingAdminValue != rhs.updatingAdminValue {
            return false
        }
        
        return true
    }
    
    func withUpdatedUpdatingAllAdminsValue(_ updatingAllAdminsValue: Bool?) -> GroupAdminsControllerState {
        return GroupAdminsControllerState(updatingAllAdminsValue: updatingAllAdminsValue, updatedAllAdminsValue: self.updatedAllAdminsValue, updatingAdminValue: self.updatingAdminValue)
    }
    
    func withUpdatedUpdatedAllAdminsValue(_ updatedAllAdminsValue: Bool?) -> GroupAdminsControllerState {
        return GroupAdminsControllerState(updatingAllAdminsValue: self.updatingAllAdminsValue, updatedAllAdminsValue: updatedAllAdminsValue, updatingAdminValue: self.updatingAdminValue)
    }
    
    func withUpdatedUpdatingAdminValue(_ updatingAdminValue: [PeerId: Bool]) -> GroupAdminsControllerState {
        return GroupAdminsControllerState(updatingAllAdminsValue: self.updatingAllAdminsValue, updatedAllAdminsValue: self.updatedAllAdminsValue, updatingAdminValue: updatingAdminValue)
    }
}

private func groupAdminsControllerEntries(account: Account, view: PeerView, state: GroupAdminsControllerState) -> [GroupAdminsEntry] {
    var entries: [GroupAdminsEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramGroup, let cachedData = view.cachedData as? CachedGroupData, let participants = cachedData.participants {
        
        var sectionId:Int = 1
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        let effectiveAdminsEnabled: Bool
        if let updatingAllAdminsValue = state.updatingAllAdminsValue {
            effectiveAdminsEnabled = updatingAllAdminsValue
        } else {
            effectiveAdminsEnabled = peer.flags.contains(.adminsEnabled)
        }
        
        entries.append(.allAdmins(sectionId: sectionId, !effectiveAdminsEnabled))
        if effectiveAdminsEnabled {
            entries.append(.allAdminsInfo(sectionId: sectionId, tr(L10n.groupAdminsDescAdminInvites)))
        } else {
            entries.append(.allAdminsInfo(sectionId: sectionId, tr(L10n.groupAdminsDescAllInvites)))
        }
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        
        var index: Int32 = 0
        for participant in participants.participants.sorted(by: <) {
            if let peer = view.peers[participant.peerId] {
                var isAdmin = false
                var isEnabled = true
                if !effectiveAdminsEnabled {
                    isAdmin = true
                    isEnabled = false
                } else {
                    switch participant {
                    case .creator:
                        isAdmin = true
                        isEnabled = false
                    case .admin:
                        if let value = state.updatingAdminValue[peer.id] {
                            isAdmin = value
                        } else {
                            isAdmin = true
                        }
                    case .member:
                        if let value = state.updatingAdminValue[peer.id] {
                            isAdmin = value
                        } else {
                            isAdmin = false
                        }
                    }
                }
                entries.append(.peerItem(sectionId: sectionId, index, peer, view.peerPresences[participant.peerId], isAdmin, isEnabled))
                index += 1
            }
        }
    }
    
    return entries
}

private func prepareTransition(left:[AppearanceWrapperEntry<GroupAdminsEntry>], right:[AppearanceWrapperEntry<GroupAdminsEntry>], arguments: GroupAdminsControllerArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class GroupAdminsController : TableViewController {
    private let peerId:PeerId
    init(account:Account, peerId:PeerId) {
        self.peerId = peerId
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let peerId = self.peerId
        
        let statePromise = ValuePromise(GroupAdminsControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: GroupAdminsControllerState())
        let updateState: ((GroupAdminsControllerState) -> GroupAdminsControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let actionsDisposable = DisposableSet()
        
        let toggleAllAdminsDisposable = MetaDisposable()
        actionsDisposable.add(toggleAllAdminsDisposable)
        
        let toggleAdminsDisposables = DisposableDict<PeerId>()
        actionsDisposable.add(toggleAdminsDisposables)
        
        let arguments = GroupAdminsControllerArguments(account: account, updateAllAreAdmins: { value in
            updateState { state in
                return state.withUpdatedUpdatingAllAdminsValue(value)
            }
            toggleAllAdminsDisposable.set((updateGroupManagementType(account: account, peerId: peerId, type: value ? .unrestricted : .restrictedToAdmins) |> deliverOnMainQueue).start(error: {
                updateState { state in
                    return state.withUpdatedUpdatingAllAdminsValue(nil)
                }
            }, completed: {
                updateState { state in
                    return state.withUpdatedUpdatingAllAdminsValue(nil).withUpdatedUpdatedAllAdminsValue(value)
                }
            }))
        }, updatePeerIsAdmin: { memberId, value in
            updateState { state in
                var updatingAdminValue = state.updatingAdminValue
                updatingAdminValue[memberId] = value
                return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
            }
            
            if value {
                toggleAdminsDisposables.set((addPeerAdmin(account: account, peerId: peerId, adminId: memberId) |> deliverOnMainQueue).start(error: { _ in
                    updateState { state in
                        var updatingAdminValue = state.updatingAdminValue
                        updatingAdminValue.removeValue(forKey: memberId)
                        return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
                    }
                }, completed: {
                    updateState { state in
                        var updatingAdminValue = state.updatingAdminValue
                        updatingAdminValue.removeValue(forKey: memberId)
                        return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
                    }
                }), forKey: memberId)
            } else {
                toggleAdminsDisposables.set((removePeerAdmin(account: account, peerId: peerId, adminId: memberId) |> deliverOnMainQueue).start(error: { _ in
                    updateState { state in
                        var updatingAdminValue = state.updatingAdminValue
                        updatingAdminValue.removeValue(forKey: memberId)
                        return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
                    }
                }, completed: {
                    updateState { state in
                        var updatingAdminValue = state.updatingAdminValue
                        updatingAdminValue.removeValue(forKey: memberId)
                        return state.withUpdatedUpdatingAdminValue(updatingAdminValue)
                    }
                }), forKey: memberId)
            }
        })
        
        let peerView = account.viewTracker.peerView(peerId)
        let previous:Atomic<[AppearanceWrapperEntry<GroupAdminsEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        genericView.merge(with: combineLatest(statePromise.get(), peerView, appearanceSignal) |> deliverOnMainQueue
            |> map { state, view, appearance -> TableUpdateTransition in
                let entries = groupAdminsControllerEntries(account: account, view: view, state: state).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previous.swap(entries), right: entries, arguments: arguments, initialSize: initialSize.modify({$0}))
                
            } |> afterDisposed {
                actionsDisposable.dispose()
        })
        readyOnce()

    }
}

