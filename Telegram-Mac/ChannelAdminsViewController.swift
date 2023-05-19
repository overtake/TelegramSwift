//
//  GroupAdminsViewController.swift
//  Telegram
//
//  Created by keepcoder on 22/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

import SwiftSignalKit

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
    case eventLogs(sectionId:Int32, GeneralViewType)
    case adminsHeader(sectionId:Int32, String, GeneralViewType)
    case adminPeerItem(sectionId:Int32, Int32, RenderedChannelParticipant, ShortPeerDeleting?, GeneralViewType)
    case addAdmin(sectionId:Int32, GeneralViewType)
    case adminsInfo(sectionId:Int32, String, GeneralViewType)
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
        case let .adminPeerItem(_, _, participant, _, _):
            return .peer(participant.peer.id)
        }
    }

    
    var index:Int32 {
        switch self {
        case .loading:
            return 0
        case let .eventLogs(sectionId, _):
            return (sectionId * 1000) + 1
        case let .adminsHeader(sectionId, _, _):
            return (sectionId * 1000) + 2
        case let .addAdmin(sectionId, _):
            return (sectionId * 1000) + 3
        case let .adminsInfo(sectionId, _, _):
            return (sectionId * 1000) + 4
        case let .adminPeerItem(sectionId, index, _, _, _):
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
    

    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case .group = peer.info {
            isGroup = true
        }
        
        entries.append(.eventLogs(sectionId: sectionId, .singleItem))
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.adminsHeader(sectionId: sectionId, isGroup ? strings().adminsGroupAdmins : strings().adminsChannelAdmins, .textTopItem))
        
        
        if peer.hasPermission(.addAdmins)  {
            entries.append(.addAdmin(sectionId: sectionId, .singleItem))
            entries.append(.adminsInfo(sectionId: sectionId, isGroup ? strings().adminsGroupDescription : strings().adminsChannelDescription, .textBottomItem))
            
            entries.append(.section(sectionId))
            sectionId += 1
        }
        
        
        var index: Int32 = 0
        for (i, participant) in participants.sorted(by: <).enumerated() {
            var editable = true
            switch participant.participant {
            case .creator:
                editable = false
            case let .member(id, _, adminInfo, _, _):
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
            
            entries.append(.adminPeerItem(sectionId: sectionId, index, participant, editing, bestGeneralViewType(participants, for: i)))
            index += 1
        }
        
        if index > 0 {
            entries.append(.section(sectionId))
            sectionId += 1

        }
    } else  if let peer = view.peers[view.peerId] as? TelegramGroup {
        
        entries.append(.adminsHeader(sectionId: sectionId, strings().adminsGroupAdmins, .textTopItem))
        
        
        if case .creator = peer.role {
            entries.append(.addAdmin(sectionId: sectionId, .singleItem))
            entries.append(.adminsInfo(sectionId: sectionId, strings().adminsGroupDescription, .textBottomItem))
            
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
        let participants = combinedParticipants.sorted(by: <).filter {
            !state.removedPeerIds.contains($0.peer.id)
        }
        for (i, participant) in participants.enumerated() {
            var editable = true
            switch participant.participant {
            case .creator:
                editable = false
            case let .member(id, _, adminInfo, _, _):
                if id == accountPeerId {
                    editable = false
                } else if let adminInfo = adminInfo {
                    var creator: Bool = false
                    if case .creator = peer.role {
                        creator = true
                    }
                    if creator || adminInfo.promotedBy == accountPeerId {
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
            entries.append(.adminPeerItem(sectionId: sectionId, index, participant, editing, bestGeneralViewType(participants, for: i)))
            index += 1
        }
        if index > 0 {
            entries.append(.section(sectionId))
            sectionId += 1
        }
    }
    
    return entries.sorted(by: <)
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelAdminsEntry>], right: [AppearanceWrapperEntry<ChannelAdminsEntry>], initialSize:NSSize, arguments:ChannelAdminsControllerArguments, isSupergroup:Bool) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        switch entry.entry {
        case let .adminPeerItem(_, _, participant, editing, viewType):
            let peerText: String
            switch participant.participant {
            case .creator:
                peerText = strings().adminsOwner
            case let .member(_, _, adminInfo, _, _):
                if let adminInfo = adminInfo, let peer = participant.peers[adminInfo.promotedBy] {
                    peerText =  strings().channelAdminsPromotedBy(peer.displayTitle)
                } else {
                    peerText = strings().adminsAdmin
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
            
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.context.account, context: arguments.context, stableId: entry.stableId, status: peerText, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, viewType: viewType, action: {
                if editing == nil {
                    arguments.openAdmin(participant)
                }
            })

        case let .addAdmin(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: strings().adminsAddAdmin,  nameStyle: blueActionButton, type: .next, viewType: viewType, action: arguments.addAdmin)
        case let .eventLogs(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: strings().channelAdminsRecentActions, type: .next, viewType: viewType, action: {
                arguments.eventLogs()
            })
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: entry.stableId, viewType: .separator)
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId, isLoading: true)
        case let .adminsHeader(_, text, viewType):
        return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: text, viewType: viewType)
        case let .adminsInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: text, viewType: viewType)
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
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        let context = self.context
        let peerId = self.peerId
        
        
        var upgradedToSupergroupImpl: ((PeerId, @escaping () -> Void) -> Void)?
        
        let upgradedToSupergroup: (PeerId, @escaping () -> Void) -> Void = { upgradedPeerId, f in
            upgradedToSupergroupImpl?(upgradedPeerId, f)
        }

        
        let adminsPromise = ValuePromise<[RenderedChannelParticipant]?>(nil)

        let updateState: ((ChannelAdminsControllerState) -> ChannelAdminsControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let viewValue:Atomic<PeerView?> = Atomic(value: nil)
        
        
        let arguments = ChannelAdminsControllerArguments(context: context, addAdmin: {
            let behavior = peerId.namespace == Namespaces.Peer.CloudGroup ? SelectGroupMembersBehavior(peerId: peerId, limit: 1) : SelectChannelMembersBehavior(peerId: peerId, peerChannelMemberContextsManager: context.peerChannelMemberCategoriesContextsManager, limit: 1)
            
            _ = (selectModalPeers(window: context.window, context: context, title: strings().adminsAddAdmin, limit: 1, behavior: behavior, confirmation: { peerIds in
                if let _ = behavior.participants[peerId] {
                     return .single(true)
                } else {
                    return .single(true)
                }
            }) |> map {$0.first}).start(next: { adminId in
                if let adminId = adminId {
                    showModal(with: ChannelAdminController(context, peerId: peerId, adminId: adminId, initialParticipant: behavior.participants[adminId]?.participant, updated: { _ in }, upgradedToSupergroup: upgradedToSupergroup), for: context.window)
                }
            })
        
        }, openAdmin: { participant in
            showModal(with: ChannelAdminController(context, peerId: peerId, adminId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in }, upgradedToSupergroup: upgradedToSupergroup), for: context.window)
        }, removeAdmin: { [weak self] adminId in
            
            updateState {
                return $0.withUpdatedRemovingPeerId(adminId)
            }
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                self?.removeAdminDisposable.set((context.engine.peers.removeGroupAdmin(peerId: peerId, adminId: adminId)
                    |> deliverOnMainQueue).start(completed: {
                        updateState {
                            return $0.withUpdatedRemovingPeerId(nil)
                        }
                    }))
            } else {
                self?.removeAdminDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(peerId: peerId, memberId: adminId, adminRights: nil, rank: nil)
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
            membersAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { membersState in
                if case .loading = membersState.loadingState, membersState.list.isEmpty {
                    adminsPromise.set(nil)
                } else {
                    adminsPromise.set(membersState.list)
                }
            })
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
                                result.append(RenderedChannelParticipant(participant: .creator(id: peer.id, adminInfo: nil, rank: nil), peer: peer))
                            case .admin:
                                var peers: [PeerId: Peer] = [:]
                                peers[creator.id] = creator
                                peers[peer.id] = peer
                                result.append(RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(rights: .internal_groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == context.account.peerId), banInfo: nil, rank: nil), peer: peer, peers: peers))
                            case .member:
                                break
                            }
                        }
                    }
                    return result
                }).start(next: { members in
                    adminsPromise.set(members)
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
