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
    let context: AccountContext
    let addAdmin: () -> Void
    let openAdmin: (RenderedChannelParticipant) -> Void
    let removeAdmin: (PeerId) -> Void
    let eventLogs:() -> Void
    init(context: AccountContext, addAdmin:@escaping()->Void, openAdmin:@escaping(RenderedChannelParticipant) -> Void, removeAdmin:@escaping(PeerId)->Void, eventLogs: @escaping()->Void) {
        self.context = context
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
}


fileprivate enum ChannelAdminsEntry : Identifiable, Comparable {
    case eventLogs(sectionId:Int32)
    case adminsHeader(sectionId:Int32, String)
    case adminPeerItem(sectionId:Int32, Int32, RenderedChannelParticipant, ShortPeerDeleting?)
    case addAdmin(sectionId:Int32)
    case adminsInfo(sectionId:Int32, String)
    case section(Int32)
    case loading
    var stableId: ChannelAdminsEntryStableId {
        switch self {
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

    
    var index:Int32 {
        switch self {
        case .loading:
            return 0
        case let .eventLogs(sectionId):
            return (sectionId * 1000) + 1
        case let .adminsHeader(sectionId, _):
            return (sectionId * 1000) + 2
        case let .addAdmin(sectionId):
            return (sectionId * 1000) + 3
        case let .adminsInfo(sectionId, _):
            return (sectionId * 1000) + 4
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


fileprivate struct ChannelAdminsControllerState: Equatable {
    let editing: Bool
    let removingPeerId: PeerId?
    let removedPeerIds: Set<PeerId>
    let temporaryAdmins: [RenderedChannelParticipant]
    
    init() {
        self.editing = false
        self.removingPeerId = nil
        self.removedPeerIds = Set()
        self.temporaryAdmins = []
    }
    
    init(editing: Bool, removingPeerId: PeerId?, removedPeerIds: Set<PeerId>, temporaryAdmins: [RenderedChannelParticipant]) {
        self.editing = editing
        self.removingPeerId = removingPeerId
        self.removedPeerIds = removedPeerIds
        self.temporaryAdmins = temporaryAdmins
    }
    
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, removingPeerId: removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedRemovedPeerIds(_ removedPeerIds: Set<PeerId>) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: removedPeerIds, temporaryAdmins: self.temporaryAdmins)
    }
    
    func withUpdatedTemporaryAdmins(_ temporaryAdmins: [RenderedChannelParticipant]) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: temporaryAdmins)
    }
}

private func channelAdminsControllerEntries(accountPeerId: PeerId, view: PeerView, state: ChannelAdminsControllerState, participants: [RenderedChannelParticipant]?, isCreator: Bool) -> [ChannelAdminsEntry] {
    var entries: [ChannelAdminsEntry] = []
    
    let participants = participants ?? []
    
//    guard let participants = participants else {
//        return [.loading]
//    }
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case .group = peer.info {
            isGroup = true
        }
        
        entries.append(.eventLogs(sectionId: sectionId))
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.adminsHeader(sectionId: sectionId, isGroup ? L10n.adminsGroupAdmins : L10n.adminsChannelAdmins))
        
        
        if peer.hasPermission(.addAdmins)  {
            entries.append(.addAdmin(sectionId: sectionId))
            entries.append(.adminsInfo(sectionId: sectionId, isGroup ? L10n.adminsGroupDescription : L10n.adminsChannelDescription))
            
            entries.append(.section(sectionId))
            sectionId += 1
        }
        
        
        var index: Int32 = 0
        for participant in participants.sorted(by: <) {
            var editable = true
            switch participant.participant {
            case .creator:
                editable = false
            case let .member(id, _, adminInfo, _):
                if id == accountPeerId {
                    editable = false
                } else if let adminInfo = adminInfo {
                    if peer.flags.contains(.isCreator) || adminInfo.promotedBy == accountPeerId {
                        editable = true
                    } else {
                        editable = false
                    }
                } else {
                    editable = false
                }
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
    } else  if let peer = view.peers[view.peerId] as? TelegramGroup {
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.adminsHeader(sectionId: sectionId, L10n.adminsGroupAdmins))
        
        
        if peer.role == .creator {
            entries.append(.addAdmin(sectionId: sectionId))
            entries.append(.adminsInfo(sectionId: sectionId, L10n.adminsGroupDescription))
            
            entries.append(.section(sectionId))
            sectionId += 1
        }
        
        
        var combinedParticipants: [RenderedChannelParticipant] = participants
        var existingParticipantIds = Set<PeerId>()
        for participant in participants {
            existingParticipantIds.insert(participant.peer.id)
        }
        
        for participant in state.temporaryAdmins {
            if !existingParticipantIds.contains(participant.peer.id) {
                combinedParticipants.append(participant)
            }
        }
        
        var index: Int32 = 0
        for participant in combinedParticipants.sorted(by: <) {
            if !state.removedPeerIds.contains(participant.peer.id) {
                var editable = true
                switch participant.participant {
                case .creator:
                    editable = false
                case let .member(id, _, adminInfo, _):
                    if id == accountPeerId {
                        editable = false
                    } else if let adminInfo = adminInfo {
                        if peer.role == .creator || adminInfo.promotedBy == accountPeerId {
                            editable = true
                        } else {
                            editable = false
                        }
                    } else {
                        editable = false
                    }
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
        }
    }
    
    return entries.sorted(by: <)
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelAdminsEntry>], right: [AppearanceWrapperEntry<ChannelAdminsEntry>], initialSize:NSSize, arguments:ChannelAdminsControllerArguments, isSupergroup:Bool) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        switch entry.entry {
        case let .adminPeerItem(_, _, participant, editing):
            let peerText: String
            switch participant.participant {
            case .creator:
                peerText = L10n.adminsCreator
            case let .member(_, _, adminInfo, _):
                if let adminInfo = adminInfo, let peer = participant.peers[adminInfo.promotedBy] {
                    peerText =  L10n.channelAdminsPromotedBy(peer.displayTitle)
                } else {
                    peerText = L10n.adminsAdmin
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
            
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.context.account, stableId: entry.stableId, status: peerText, drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, action: {
                if editing == nil {
                    arguments.openAdmin(participant)
                }
            })

        case .addAdmin:
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(L10n.adminsAddAdmin),  nameStyle: blueActionButton, type: .next, action: {
                 arguments.addAdmin()
            })
        case .eventLogs:
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(L10n.channelAdminsRecentActions), type: .next, action: {
                arguments.eventLogs()
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: entry.stableId)
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId, isLoading: true)
        case let .adminsHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: text)
        case let .adminsInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: text)
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
    init( _ context:AccountContext, peerId:PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    let actionsDisposable = DisposableSet()
    
    let updateAdministrationDisposable = MetaDisposable()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = self.peerId
        
        
        var upgradedToSupergroupImpl: ((PeerId, @escaping () -> Void) -> Void)?
        
        let upgradedToSupergroup: (PeerId, @escaping () -> Void) -> Void = { upgradedPeerId, f in
            upgradedToSupergroupImpl?(upgradedPeerId, f)
        }

        
        let adminsPromise = Promise<[RenderedChannelParticipant]?>(nil)

        let updateState: ((ChannelAdminsControllerState) -> ChannelAdminsControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let viewValue:Atomic<PeerView?> = Atomic(value: nil)
        
        
        let arguments = ChannelAdminsControllerArguments(context: context, addAdmin: {
            let behavior = peerId.namespace == Namespaces.Peer.CloudGroup ? SelectGroupMembersBehavior(peerId: peerId, limit: 1) : SelectChannelMembersBehavior(peerId: peerId, limit: 1)
            
            _ = (selectModalPeers(context: context, title: "", limit: 1, behavior: behavior, confirmation: { peerIds in
                if let participant = behavior.participants[peerId] {
                    switch participant.participant {
                    case .creator:
                        return .single(false)
                    case .member:
                        return .single(true)
                    }
                } else {
                    return .single(true)
                }
            }) |> map {$0.first}).start(next: { adminId in
                if let adminId = adminId {
                    
                    showModal(with: ChannelAdminController(context, peerId: peerId, adminId: adminId, initialParticipant: behavior.participants[adminId]?.participant, updated: { _ in }, upgradedToSupergroup: upgradedToSupergroup), for: mainWindow)
                }
            })
        
        }, openAdmin: { participant in
            if participant.peer.id != context.peerId {
                showModal(with: ChannelAdminController(context, peerId: peerId, adminId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in }, upgradedToSupergroup: upgradedToSupergroup), for: mainWindow)
            }
        }, removeAdmin: { [weak self] adminId in
            
            updateState {
                return $0.withUpdatedRemovingPeerId(adminId)
            }
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                self?.removeAdminDisposable.set((removeGroupAdmin(account: context.account, peerId: peerId, adminId: adminId)
                    |> deliverOnMainQueue).start(completed: {
                        updateState {
                            return $0.withUpdatedRemovingPeerId(nil)
                        }
                    }))
            } else {
                self?.removeAdminDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: []))
                    |> deliverOnMainQueue).start(completed: {
                        updateState {
                            return $0.withUpdatedRemovingPeerId(nil)
                        }
                    }))
            }

        }, eventLogs: { [weak self] in
            self?.navigationController?.push(ChannelEventLogController(context, peerId: peerId))
        })
        
        let peerView = Promise<PeerView>()
        peerView.set(context.account.viewTracker.peerView(peerId))

       

        let membersAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?)
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            membersAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.admins(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId) { membersState in
                if case .loading = membersState.loadingState, membersState.list.isEmpty {
                    adminsPromise.set(.single(nil))
                } else {
                    adminsPromise.set(.single(membersState.list))
                }
            }
        } else {
            let membersDisposable = (peerView.get()
                |> map { peerView -> [RenderedChannelParticipant]? in
                    guard let cachedData = peerView.cachedData as? CachedGroupData, let participants = cachedData.participants else {
                        return nil
                    }
                    var result: [RenderedChannelParticipant] = []
                    var creatorPeer: Peer?
                    for participant in participants.participants {
                        if let peer = peerView.peers[participant.peerId] {
                            switch participant {
                            case .creator:
                                creatorPeer = peer
                            default:
                                break
                            }
                        }
                    }
                    guard let creator = creatorPeer else {
                        return nil
                    }
                    for participant in participants.participants {
                        if let peer = peerView.peers[participant.peerId] {
                            switch participant {
                            case .creator:
                                result.append(RenderedChannelParticipant(participant: .creator(id: peer.id), peer: peer))
                            case .admin:
                                var peers: [PeerId: Peer] = [:]
                                peers[creator.id] = creator
                                peers[peer.id] = peer
                                result.append(RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(flags: .groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == context.account.peerId), banInfo: nil), peer: peer, peers: peers))
                            case .member:
                                break
                            }
                        }
                    }
                    return result
                }).start(next: { members in
                    adminsPromise.set(.single(members))
                })
            membersAndLoadMoreControl = (membersDisposable, nil)
        }
        
        let (membersDisposable, _) = membersAndLoadMoreControl
        actionsDisposable.add(membersDisposable)
        

        
        let initialSize = atomicSize
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelAdminsEntry>]> = Atomic(value: [])
        
        let signal = combineLatest(statePromise.get(), peerView.get(), adminsPromise.get(), appearanceSignal)
            |> map { state, view, admins, appearance -> (TableUpdateTransition, Bool) in
                
                var isCreator = false
                var isSupergroup = false
                if let channel = peerViewMainPeer(view) as? TelegramChannel {
                    isCreator = channel.flags.contains(.isCreator)
                    isSupergroup = channel.isSupergroup
                }
                _ = viewValue.swap(view)
                let entries = channelAdminsControllerEntries(accountPeerId: context.peerId, view: view, state: state, participants: admins, isCreator: isCreator).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return (prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments, isSupergroup: isSupergroup), isCreator)
        }
        
        disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] transition, isCreator in
            self?.rightBarView.isHidden = !isCreator
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
        upgradedToSupergroupImpl = { [weak self] upgradedPeerId, f in
            guard let `self` = self, let navigationController = self.navigationController else {
                return
            }

            let chatController = ChatController(context: context, chatLocation: .peer(upgradedPeerId))
            
            navigationController.removeAll()
            navigationController.push(chatController, false, style: .none)
            let signal = chatController.ready.get() |> filter {$0} |> take(1) |> deliverOnMainQueue |> ignoreValues
            
            _ = signal.start(completed: { [weak navigationController] in
                navigationController?.push(ChannelAdminsViewController(context, peerId: upgradedPeerId), false, style: .none)
                f()
            })
            
        }

        
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
        actionsDisposable.dispose()
    }
}
