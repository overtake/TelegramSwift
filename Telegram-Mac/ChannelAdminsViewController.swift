//
//  GroupAdminsViewController.swift
//  Telegram
//
//  Created by keepcoder on 22/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

fileprivate final class ChannelAdminsControllerArguments {
    let account: Account
    
    let updateCurrentAdministrationType: () -> Void
    let addAdmin: () -> Void
    let openAdmin: (RenderedChannelParticipant) -> Void
    let removeAdmin: (PeerId) -> Void
    let eventLogs:() -> Void
    init(account:Account, updateCurrentAdministrationType:@escaping()->Void, addAdmin:@escaping()->Void, openAdmin:@escaping(RenderedChannelParticipant) -> Void, removeAdmin:@escaping(PeerId)->Void, eventLogs: @escaping()->Void) {
        self.account = account
        self.updateCurrentAdministrationType = updateCurrentAdministrationType
        self.addAdmin = addAdmin
        self.openAdmin = openAdmin
        self.removeAdmin = removeAdmin
        self.eventLogs = eventLogs
    }
}

fileprivate enum ChannelAdminsEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
    var hashValue: Int {
        switch self {
        case let .index(index):
            return index.hashValue
        case let .peer(peerId):
            return peerId.hashValue
        }
    }
    
    static func ==(lhs: ChannelAdminsEntryStableId, rhs: ChannelAdminsEntryStableId) -> Bool {
        switch lhs {
        case let .index(index):
            if case .index(index) = rhs {
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


fileprivate enum ChannelAdminsEntry : Identifiable, Comparable {
    case administrationType(sectionId:Int32, CurrentAdministrationType)
    case administrationInfo(sectionId:Int32, String)
    case eventLogs(sectionId:Int32)
    case adminsHeader(sectionId:Int32, String)
    case adminPeerItem(sectionId:Int32, Int32, RenderedChannelParticipant, ShortPeerDeleting?)
    case addAdmin(sectionId:Int32)
    case adminsInfo(sectionId:Int32, String)
    case section(Int32)
    case loading
    var stableId: ChannelAdminsEntryStableId {
        switch self {
        case .administrationType:
            return .index(0)
        case .administrationInfo:
            return .index(1)
        case .adminsHeader:
            return .index(2)
        case .addAdmin:
            return .index(3)
        case .adminsInfo:
            return .index(4)
        case .eventLogs:
            return .index(5)
        case .loading:
            return .index(6)
        case let .section(sectionId):
            return .index((sectionId + 1) * 1000 - sectionId)
        case let .adminPeerItem(_, _, participant, _):
            return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        switch lhs {
        case let .administrationType(_,type):
            if case .administrationType(_,type) = rhs {
                return true
            } else {
                return false
            }
        case let .administrationInfo(_,text):
            if case .administrationInfo(_,text) = rhs {
                return true
            } else {
                return false
            }
        case let .loading:
            if case .loading = rhs {
                return true
            } else {
                return false
            }
        case let .eventLogs(sectionId):
            if case .eventLogs(sectionId) = rhs {
                return true
            } else {
                return false
            }
        case let .adminsHeader(_,title):
            if case .adminsHeader(_,title) = rhs {
                return true
            } else {
                return false
            }
        case let .adminPeerItem(_,lhsIndex, lhsParticipant, lhsEditing):
            if case let .adminPeerItem(_,rhsIndex, rhsParticipant, rhsEditing) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsParticipant != rhsParticipant {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .adminsInfo(_,text):
            if case .adminsInfo(_,text) = rhs {
                return true
            } else {
                return false
            }
        case .addAdmin:
            if case .addAdmin = rhs {
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
        }
    }
    
    var index:Int32 {
        switch self {
        case .loading:
            return 0
        case let .eventLogs(sectionId):
            return (sectionId * 1000) + 1
        case let .administrationType(sectionId, _):
            return (sectionId * 1000) + 2
        case let .administrationInfo(sectionId, _):
            return (sectionId * 1000) + 3
        case let .adminsHeader(sectionId, _):
            return (sectionId * 1000) + 4
        case let .addAdmin(sectionId):
            return (sectionId * 1000) + 5
        case let .adminsInfo(sectionId, _):
            return (sectionId * 1000) + 6
        case let .adminPeerItem(sectionId, index, _, _):
            return (sectionId * 1000) + index + 20
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        return lhs.index < rhs.index
    }
}

fileprivate enum CurrentAdministrationType {
    case everyoneCanAddMembers
    case adminsCanAddMembers
}

fileprivate struct ChannelAdminsControllerState: Equatable {
    let selectedType: CurrentAdministrationType?
    let editing: Bool
    let removingPeerId: PeerId?
    let removedPeerIds: Set<PeerId>
    let temporaryAdmins: [RenderedChannelParticipant]
    
    init() {
        self.selectedType = nil
        self.editing = false
        self.removingPeerId = nil
        self.removedPeerIds = Set()
        self.temporaryAdmins = []
    }
    
    init(selectedType: CurrentAdministrationType?, editing: Bool, removingPeerId: PeerId?, removedPeerIds: Set<PeerId>, temporaryAdmins: [RenderedChannelParticipant]) {
        self.selectedType = selectedType
        self.editing = editing
        self.removingPeerId = removingPeerId
        self.removedPeerIds = removedPeerIds
        self.temporaryAdmins = temporaryAdmins
    }
    
    static func ==(lhs: ChannelAdminsControllerState, rhs: ChannelAdminsControllerState) -> Bool {
        if lhs.selectedType != rhs.selectedType {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.removingPeerId != rhs.removingPeerId {
            return false
        }
        if lhs.removedPeerIds != rhs.removedPeerIds {
            return false
        }
        if lhs.temporaryAdmins != rhs.temporaryAdmins {
            return false
        }
        
        return true
    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentAdministrationType?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: selectedType, editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, removingPeerId: removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedRemovedPeerIds(_ removedPeerIds: Set<PeerId>) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedTemporaryAdmins(_ temporaryAdmins: [RenderedChannelParticipant]) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(selectedType: self.selectedType, editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: temporaryAdmins)
    }
}

private func ChannelAdminsControllerEntries(view: PeerView, state: ChannelAdminsControllerState, participants: [RenderedChannelParticipant]?, isCreator: Bool) -> [ChannelAdminsEntry] {
    var entries: [ChannelAdminsEntry] = []
    
    guard let participants = participants else {
        return [.loading]
    }
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case let .group(info) = peer.info {
            isGroup = true
            
            if isCreator {
                let selectedType: CurrentAdministrationType
                if let current = state.selectedType {
                    selectedType = current
                } else {
                    if info.flags.contains(.everyMemberCanInviteMembers) {
                        selectedType = .everyoneCanAddMembers
                    } else {
                        selectedType = .adminsCanAddMembers
                    }
                }
                
                entries.append(.administrationType(sectionId: sectionId, selectedType))
                let infoText: String
                switch selectedType {
                case .everyoneCanAddMembers:
                    infoText = tr(.adminsEverbodyCanAddMembers)
                case .adminsCanAddMembers:
                    infoText = tr(.adminsOnlyAdminsCanAddMembers)
                }
                entries.append(.administrationInfo(sectionId: sectionId, infoText))
                
            }
 
        }
        
        entries.append(.eventLogs(sectionId: sectionId))
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.adminsHeader(sectionId: sectionId, isGroup ? tr(.adminsGroupAdmins) : tr(.adminsChannelAdmins)))
        
        var index: Int32 = 0
        for participant in participants.sorted(by: <) {
            var editable = true
            if case .creator = participant.participant {
                editable = false
            }
            
            let editing:ShortPeerDeleting?
            if state.editing {
                editing = ShortPeerDeleting(editable: editable)
            } else {
                editing = nil
            }
            
            entries.append(.adminPeerItem(sectionId: sectionId, index, participant, editing))
            index += 1
        }
        
        
        
        if peer.hasAdminRights(.canAddAdmins)  {
            entries.append(.section(sectionId))
            sectionId += 1
            
            entries.append(.addAdmin(sectionId: sectionId))
            entries.append(.adminsInfo(sectionId: sectionId, isGroup ? tr(.adminsGroupDescription) : tr(.adminsChannelDescription)))
        }
    }
    
    return entries.sorted(by: <)
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelAdminsEntry>], right: [AppearanceWrapperEntry<ChannelAdminsEntry>], initialSize:NSSize, arguments:ChannelAdminsControllerArguments, isSupergroup:Bool) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        switch entry.entry {
        case let .administrationType(_, type):
            let label: String
            switch type {
            case .adminsCanAddMembers:
                label = tr(.adminsWhoCanInviteAdmins)
            case .everyoneCanAddMembers:
                label = tr(.adminsWhoCanInviteEveryone)
            }
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(.adminsWhoCanInviteText), type: .context(stateback: { () -> String in
                return label
            }), action: { 
                arguments.updateCurrentAdministrationType()
            })

        case let .administrationInfo(_, text), let .adminsHeader(_, text), let .adminsInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: text)
        case let .adminPeerItem(_, _, participant, editing):
            let peerText: String
            switch participant.participant {
            case .creator:
                peerText = tr(.adminsCreator)
            case let .member(_, _, adminInfo, _):
                if let adminInfo = adminInfo, let peer = participant.peers[adminInfo.promotedBy] {
                    peerText =  tr(.channelAdminsPromotedBy(peer.displayTitle))
                } else {
                    peerText = tr(.adminsAdmin)
                }
            }
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { adminId in
                    arguments.removeAdmin(adminId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.account, stableId: entry.stableId, status: peerText, drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, action: {
                if editing == nil {
                    arguments.openAdmin(participant)
                }
            })

        case .addAdmin:
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(.adminsAddAdmin),  nameStyle: blueActionButton, type: .next, action: {
                 arguments.addAdmin()
            })
        case .eventLogs:
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(.channelAdminsRecentActions), type: .next, action: {
                arguments.eventLogs()
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: entry.stableId)
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId, isLoading: true)
        }
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ChannelAdminsViewController: EditableViewController<TableView> {
    fileprivate let statePromise = ValuePromise(ChannelAdminsControllerState(), ignoreRepeated: true)
    fileprivate let stateValue = Atomic(value: ChannelAdminsControllerState())

    private let peerId:PeerId
    
    private let addAdminDisposable:MetaDisposable = MetaDisposable()
    private let disposable:MetaDisposable = MetaDisposable()
    private let removeAdminDisposable:MetaDisposable = MetaDisposable()
    private let openPeerDisposable:MetaDisposable = MetaDisposable()
    init(account:Account, peerId:PeerId) {
        self.peerId = peerId
        super.init(account)
    }
    
    let actionsDisposable = DisposableSet()
    
    let updateAdministrationDisposable = MetaDisposable()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let peerId = self.peerId
        
        let adminsPromise = Promise<[RenderedChannelParticipant]?>(nil)

        let updateState: ((ChannelAdminsControllerState) -> ChannelAdminsControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let viewValue:Atomic<PeerView?> = Atomic(value: nil)
        
        let applyAdmin:(RenderedChannelParticipant, PeerId, TelegramChannelAdminRights) -> Void =  { [weak self] participant, adminId, updatedRights in
            
            
            let applyAdmin: Signal<Void, NoError> = combineLatest(adminsPromise.get(), account.postbox.loadedPeerWithId(adminId))
                |> filter { $0.0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { admins, peer -> Signal<Void, NoError> in
                    if let admins = admins {
                        let additionalPeers = viewValue.modify({$0})?.peers ?? [:]
                        var updatedAdmins = admins
                        if updatedRights.isEmpty {
                            for i in 0 ..< updatedAdmins.count {
                                if updatedAdmins[i].peer.id == adminId {
                                    updatedAdmins.remove(at: i)
                                    break
                                }
                            }
                        } else {
                            var found = false
                            for i in 0 ..< updatedAdmins.count {
                                if updatedAdmins[i].peer.id == adminId {
                                    if case let .member(id, date, _, banInfo) = updatedAdmins[i].participant {
                                        updatedAdmins[i] = RenderedChannelParticipant(participant: .member(id: id, invitedAt: date, adminInfo: ChannelParticipantAdminInfo(rights: updatedRights, promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: nil), peer: updatedAdmins[i].peer, peers: participant.peers + additionalPeers)
                                    }
                                    found = true
                                    break
                                }
                            }
                            if !found {
                                updatedAdmins.append(RenderedChannelParticipant(participant: .member(id: adminId, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: updatedRights, promotedBy: account.peerId, canBeEditedByAccountPeer: true), banInfo: nil), peer: peer, peers: participant.peers + additionalPeers))
                            }
                        }
                        adminsPromise.set(.single(updatedAdmins))
                    }
                    
                    return account.context.cachedAdminIds.ids(postbox: account.postbox, network: account.network, peerId: peerId) |> take(1) |> mapToSignal { _ in
                        return Signal<Void, Void>.complete()
                    }
            }
            self?.addAdminDisposable.set(applyAdmin.start())
        }
        
        let arguments = ChannelAdminsControllerArguments(account: account, updateCurrentAdministrationType: { [weak self] in
            
            if let item = self?.genericView.item(stableId: AnyHashable(ChannelAdminsEntryStableId.index(0))) {
                if let view = (self?.genericView.viewNecessary(at: item.index) as? GeneralInteractedRowView)?.textView {
                    let result = ValuePromise<Bool>()
                    
                    let items = [SPopoverItem(tr(.adminsWhoCanInviteEveryone), {
                        result.set(true)
                        
                    }), SPopoverItem(tr(.adminsWhoCanInviteAdmins), {
                        result.set(false)
                    })]
                    
                    let updateSignal = result.get()
                        |> take(1)
                        |> mapToSignal { value -> Signal<Void, NoError> in
                            updateState { state in
                                return state.withUpdatedSelectedType(value ? .everyoneCanAddMembers : .adminsCanAddMembers)
                            }
                            
                            return account.postbox.loadedPeerWithId(peerId)
                                |> mapToSignal { peer -> Signal<Void, NoError> in
                                    if let peer = peer as? TelegramChannel, case let .group(info) = peer.info {
                                        var updatedValue: Bool?
                                        if value && !info.flags.contains(.everyMemberCanInviteMembers) {
                                            updatedValue = true
                                        } else if !value && info.flags.contains(.everyMemberCanInviteMembers) {
                                            updatedValue = false
                                        }
                                        if let updatedValue = updatedValue {
                                            return updateGroupManagementType(account: account, peerId: peerId, type: updatedValue ? .unrestricted : .restrictedToAdmins)
                                        } else {
                                            return .complete()
                                        }
                                    } else {
                                        return .complete()
                                    }
                            }
                    }
                    self?.updateAdministrationDisposable.set(updateSignal.start())
                    
                    showPopover(for: view, with: SPopoverViewController(items: items), edge: .minX, inset: NSMakePoint(0,-30))
                }
            }

        }, addAdmin: {
            let behavior = SelectChannelMembersBehavior(peerId: peerId, limit: 1)
            
            _ = (selectModalPeers(account: account, title: "", limit: 1, behavior: behavior, confirmation: { peerIds in
                if let peerId = peerIds.first, let peerView = viewValue.modify({$0}), let channel = peerViewMainPeer(peerView) as? TelegramChannel {
                    if let participant = behavior.participants[peerId] {
                        switch participant.participant {
                        case .creator:
                            return .single(false)
                        case .member(_, _, let adminInfo, let banInfo):
                            if let adminInfo = adminInfo {
                                //if channel.flags.contains(.isCreator) && adminInfo.promotedBy != account.peerId && !adminInfo.canBeEditedByAccountPeer {
                                    //alert(for: mainWindow, info: tr(.channelAdminsAddAdminError))
                                  //  return .single(false)
                                //}
                                return .single(true)
                            } else {
                                if let _ = channel.adminRights {
                                    if let _ = banInfo {
                                        if !channel.hasAdminRights(.canBanUsers) {
                                            alert(for: mainWindow, info: tr(.channelAdminsPromoteBannedAdminError))
                                            return .single(false)
                                        }
                                    }
                                }
                                
                                return .single(true)
                            }
                        }
                    } else {
                        if !channel.hasAdminRights(.canInviteUsers) {
                            alert(for: mainWindow, info: tr(.channelAdminsPromoteUnmemberAdminError))
                            return .single(false)
                        }
                    }
                }
                return .single(true)
            }) |> map {$0.first}).start(next: { adminId in
                if let adminId = adminId {
                    
                    showModal(with: ChannelAdminController(account: account, peerId: peerId, adminId: adminId, initialParticipant: behavior.participants[adminId]?.participant, updated: { updatedRights in
                        if let participant = behavior.participants[adminId] {
                            applyAdmin(participant, adminId, updatedRights)
                        }
                        
                    }), for: mainWindow)
                }
            })
        
        }, openAdmin: { participant in
            if case let .member(adminId, _, _, _) = participant.participant {
                showModal(with: ChannelAdminController(account: account, peerId: peerId, adminId: participant.peer.id, initialParticipant: participant.participant, updated: { updatedRights in
                    applyAdmin(participant, adminId, updatedRights)
                    
                }), for: mainWindow)
            }
        }, removeAdmin: { [weak self] adminId in
            
            updateState {
                return $0.withUpdatedRemovingPeerId(adminId)
            }
            let applyPeers: Signal<Void, NoError> = adminsPromise.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { peers -> Signal<Void, NoError> in
                    if let peers = peers {
                        var updatedPeers = peers
                        for i in 0 ..< updatedPeers.count {
                            if updatedPeers[i].peer.id == adminId {
                                updatedPeers.remove(at: i)
                                break
                            }
                        }
                        adminsPromise.set(.single(updatedPeers))
                    }
                    
                    return account.context.cachedAdminIds.ids(postbox: account.postbox, network: account.network, peerId: peerId) |> take(1) |> mapToSignal { _ in
                        return Signal<Void, Void>.complete()
                    }
            }
            
            self?.removeAdminDisposable.set((removePeerAdmin(account: account, peerId: peerId, adminId: adminId)
                |> then(applyPeers |> mapError { _ -> RemovePeerAdminError in return .generic }) |> deliverOnMainQueue).start(error: { _ in
                    updateState {
                        return $0.withUpdatedRemovingPeerId(nil)
                    }
                }, completed: {
                    updateState { state in
                        var updatedTemporaryAdmins = state.temporaryAdmins
                        for i in 0 ..< updatedTemporaryAdmins.count {
                            if updatedTemporaryAdmins[i].peer.id == adminId {
                                updatedTemporaryAdmins.remove(at: i)
                                break
                            }
                        }
                        return state.withUpdatedRemovingPeerId(nil).withUpdatedTemporaryAdmins(updatedTemporaryAdmins)
                    }
            }))
        }, eventLogs: { [weak self] in
            self?.navigationController?.push(ChannelEventLogController(account, peerId: peerId))
        })
        
        let peerView = account.viewTracker.peerView(peerId)
        
        
        let adminsSignal: Signal<[RenderedChannelParticipant]?, NoError> = .single(nil) |> then(channelAdmins(account: account, peerId: peerId) |> map { Optional($0) })
        
        adminsPromise.set(adminsSignal)
        
        let initialSize = atomicSize
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelAdminsEntry>]> = Atomic(value: [])
        
        let signal = combineLatest(statePromise.get(), peerView, adminsPromise.get(), appearanceSignal)
            |> map { state, view, admins, appearance -> (TableUpdateTransition, Bool) in
                
                var isCreator = false
                var isSupergroup = false
                if let channel = peerViewMainPeer(view) as? TelegramChannel {
                    isCreator = channel.flags.contains(.isCreator)
                    isSupergroup = channel.isSupergroup
                }
                _ = viewValue.swap(view)
                let entries = ChannelAdminsControllerEntries(view: view, state: state, participants: admins, isCreator: isCreator).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return (prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments, isSupergroup: isSupergroup), isCreator)
        }
        
        disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] transition, isCreator in
            self?.rightBarView.isHidden = !isCreator
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
    deinit {
        addAdminDisposable.dispose()
        disposable.dispose()
        removeAdminDisposable.dispose()
        updateAdministrationDisposable.dispose()
        openPeerDisposable.dispose()
    }
}
