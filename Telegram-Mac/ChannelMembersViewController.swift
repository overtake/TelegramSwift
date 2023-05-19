//
//  ChannelMembersViewController.swift
//  Telegram
//
//  Created by keepcoder on 01/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

import SwiftSignalKit



private final class ChannelMembersControllerArguments {
    let context: AccountContext
    
    let removePeer: (PeerId) -> Void
    let addMembers:()-> Void
    let inviteLink:()-> Void
    let openInfo:(Peer)->Void
    init(context: AccountContext, removePeer: @escaping (PeerId) -> Void, addMembers:@escaping()->Void, inviteLink:@escaping()->Void, openInfo:@escaping(Peer)->Void) {
        self.context = context
        self.removePeer = removePeer
        self.addMembers = addMembers
        self.inviteLink = inviteLink
        self.openInfo = openInfo
    }
}

private enum ChannelMembersEntryStableId: Hashable {
    case peer(PeerId)
    case addMembers
    case inviteLink
    case membersDesc
    case section(Int)
    case loading
    case contactsHeader
    case otherHeader
    var hashValue: Int {
        switch self {
        case let .peer(peerId):
            return peerId.hashValue
        case .addMembers:
            return 0
        case .inviteLink:
            return 1
        case .membersDesc:
            return 2
        case .loading:
            return 3
        case .contactsHeader:
            return 4
        case .otherHeader:
            return 5
        case let .section(sectionId):
            return -(sectionId)
        }
    }
    
}

private enum ChannelMembersEntry: Identifiable, Comparable {
    case peerItem(sectionId:Int, Int32, RenderedChannelParticipant, ShortPeerDeleting?, Bool, GeneralViewType)
    case addMembers(sectionId:Int, Bool, GeneralViewType)
    case inviteLink(sectionId:Int, GeneralViewType)
    case membersDesc(sectionId:Int, GeneralViewType)
    case contactsHeader(sectionId:Int, GeneralViewType)
    case otherHeader(sectionId:Int, GeneralViewType)
    case section(sectionId:Int)
    case loading(sectionId: Int)
    
    var stableId: ChannelMembersEntryStableId {
        switch self {
        case let .peerItem(_, _, participant, _, _, _):
            return .peer(participant.peer.id)
        case .addMembers:
            return .addMembers
        case .inviteLink:
            return .inviteLink
        case .membersDesc:
            return .membersDesc
        case .contactsHeader:
            return .contactsHeader
        case .otherHeader:
            return .otherHeader
        case .loading:
            return .loading
        case let .section(sectionId):
            return .section(sectionId)
        }
    }
    
    
    var index:Int {
        switch self {
        case let .peerItem(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + Int(index) + 100
        case let .addMembers(sectionId, _, _):
            return (sectionId * 1000) + 0
        case let .inviteLink(sectionId, _):
            return (sectionId * 1000) + 1
        case let .membersDesc(sectionId, _):
            return (sectionId * 1000) + 2
        case let .contactsHeader(sectionId, _):
            return (sectionId * 1000) + 3
        case let .otherHeader(sectionId, _):
            return (sectionId * 1000) + 4
        case let .loading(sectionId):
            return (sectionId * 1000) + 5
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    
    static func <(lhs: ChannelMembersEntry, rhs: ChannelMembersEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: ChannelMembersControllerArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case let .peerItem(_, _, participant, editing, enabled, viewType):
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { peerId in
                    arguments.removePeer(peerId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, enabled: enabled, height:46, photoSize: NSMakeSize(32, 32), drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, viewType: viewType, action: {
            
                if case .plain = interactionType {
                    arguments.openInfo(participant.peer)
                }
            })
        case let .addMembers(_, isChannel, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: isChannel ? strings().channelMembersAddSubscribers : strings().channelMembersAddMembers, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.addMembers()
            })
        case let .inviteLink(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().channelMembersInviteLink, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.inviteLink()
            })
        case let .membersDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().channelMembersMembersListDesc, viewType: viewType)
        case let .contactsHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().channelMembersContacts, viewType: viewType)
        case let .otherHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().channelMembersOtherMembers, viewType: viewType)
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        }
    }
}

private struct ChannelMembersControllerState: Equatable {
    let editing: Bool
    let removingPeerId: PeerId?
    
    init() {
        self.editing = false
        self.removingPeerId = nil
    }
    
    init(editing: Bool, removingPeerId: PeerId?) {
        self.editing = editing
        self.removingPeerId = removingPeerId
    }
    
    static func ==(lhs: ChannelMembersControllerState, rhs: ChannelMembersControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.removingPeerId != rhs.removingPeerId {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: editing, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: self.editing, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: self.editing, removingPeerId: removingPeerId)
    }
}

private func channelMembersControllerEntries(view: PeerView, context: AccountContext, state: ChannelMembersControllerState, participants: [RenderedChannelParticipant]?, contacts: [RenderedChannelParticipant]?) -> [ChannelMembersEntry] {
    
    var entries: [ChannelMembersEntry] = []
    
    var sectionId:Int = 1
    
   
    if let participants = participants, let contacts = contacts {
        
        let participants = participants.filter { value in
            return !contacts.contains(where: { $0.peer.id == value.peer.id })
        }
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        if let peer = peerViewMainPeer(view) as? TelegramChannel {
            
            if peer.hasPermission(.inviteMembers) {
                entries.append(.addMembers(sectionId: sectionId, peer.isChannel, .singleItem))
                entries.append(.membersDesc(sectionId: sectionId, .textBottomItem))
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
            }
            
            if !contacts.isEmpty {
                
                entries.append(.contactsHeader(sectionId: sectionId, .textTopItem))
                
                var index: Int32 = 0
                for (i, participant) in contacts.sorted(by: <).enumerated() {
                    
                    let editable:Bool
                    switch participant.participant {
                    case let .member(_, _, adminInfo, _, _):
                        if let adminInfo = adminInfo {
                            editable = adminInfo.canBeEditedByAccountPeer
                        } else {
                            editable = participant.participant.peerId != context.account.peerId
                        }
                    default:
                        editable = false
                    }
                    
                    var deleting:ShortPeerDeleting? = nil
                    if state.editing {
                        deleting = ShortPeerDeleting(editable: editable)
                    }
                    entries.append(.peerItem(sectionId: sectionId, index, participant, deleting, state.removingPeerId != participant.peer.id, bestGeneralViewType(contacts, for: i)))
                    index += 1
                }
                if !participants.isEmpty {
                    entries.append(.section(sectionId: sectionId))
                    sectionId += 1
                }
            }

            if !contacts.isEmpty && participants.count > 0 {
                entries.append(.otherHeader(sectionId: sectionId, .textTopItem))
            }
           
            var index: Int32 = 0
            for (i, participant) in participants.sorted(by: <).enumerated() {
                
                let editable:Bool
                switch participant.participant {
                case let .member(_, _, adminInfo, _, _):
                    if let adminInfo = adminInfo {
                        editable = adminInfo.canBeEditedByAccountPeer
                    } else {
                        editable = participant.participant.peerId != context.account.peerId
                    }
                default:
                    editable = false
                }
                
                var deleting:ShortPeerDeleting? = nil
                if state.editing {
                    deleting = ShortPeerDeleting(editable: editable)
                }
                entries.append(.peerItem(sectionId: sectionId, index, participant, deleting, state.removingPeerId != participant.peer.id, bestGeneralViewType(participants, for: i)))
                index += 1
            }
            
        }
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
    } else {
        entries.append(.loading(sectionId: sectionId))
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelMembersEntry>], right: [AppearanceWrapperEntry<ChannelMembersEntry>], initialSize:NSSize, arguments:ChannelMembersControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ChannelMembersViewController: EditableViewController<TableView> {
    
    private let peerId:PeerId
    
    private let statePromise = ValuePromise(ChannelMembersControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: ChannelMembersControllerState())
    private let removePeerDisposable:MetaDisposable = MetaDisposable()
    
    private let disposable:MetaDisposable = MetaDisposable()
    init(_ context: AccountContext, peerId:PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    override var defaultBarTitle: String {
        return strings().peerInfoSubscribers
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.searchChannelUsers()
            return .invoked
        }, with: self, for: .F, priority: .low, modifierFlags: [.command])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        let peerId = self.peerId
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        let updateState: ((ChannelMembersControllerState) -> ChannelMembersControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let actionsDisposable = DisposableSet()
        let peersPromise = Promise<[RenderedChannelParticipant]?>(nil)
        let contactsPromise = Promise<[RenderedChannelParticipant]?>(nil)

        let arguments = ChannelMembersControllerArguments(context: context, removePeer: { [weak self] memberId in
            
            updateState {
                return $0.withUpdatedRemovingPeerId(memberId)
            }
            
            self?.removePeerDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(peerId: peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: 0)) |> deliverOnMainQueue).start(completed: {
                updateState {
                    return $0.withUpdatedRemovingPeerId(nil)
                }
                
            }))
        }, addMembers: {
            let signal = selectModalPeers(window: context.window, context: context, title: strings().channelMembersSelectTitle, settings: [.contacts, .remote, .excludeBots]) |> castError(AddChannelMemberError.self) |> mapToSignal { peers -> Signal<[PeerId], AddChannelMemberError> in
                return showModalProgress(signal: context.peerChannelMemberCategoriesContextsManager.addMembers(peerId: peerId, memberIds: peers), for: context.window)
            } |> deliverOnMainQueue
            
            actionsDisposable.add(signal.start(error: { error in
                let text: String
                switch error {
                case .notMutualContact:
                    text = strings().channelInfoAddUserLeftError
                case .limitExceeded:
                    text = strings().channelErrorAddTooMuch
                case .botDoesntSupportGroups:
                    text = strings().channelBotDoesntSupportGroups
                case .tooMuchBots:
                    text = strings().channelTooMuchBots
                case .tooMuchJoined:
                    text = strings().inviteChannelsTooMuch
                case .generic:
                    text = strings().unknownError
                case .kicked:
                    text = strings().channelAddUserKickedError
                case let .bot(memberId):
                    let _ = (context.account.postbox.transaction { transaction in
                        return transaction.getPeer(peerId)
                        }
                        |> deliverOnMainQueue).start(next: { peer in
                            guard let peer = peer as? TelegramChannel else {
                                alert(for: context.window, info: strings().unknownError)
                                return
                            }
                            if peer.hasPermission(.addAdmins) {
                                confirm(for: context.window, information: strings().channelAddBotErrorHaveRights, okTitle: strings().channelAddBotAsAdmin, successHandler: { _ in
                                    showModal(with: ChannelAdminController(context, peerId: peerId, adminId: memberId, initialParticipant: nil, updated: { _ in }, upgradedToSupergroup: { _, f in f() }), for: context.window)
                                })
                            } else {
                                alert(for: context.window, info: strings().channelAddBotErrorHaveRights)
                            }
                        })
                    return
                case .restricted:
                    text = strings().channelErrorAddBlocked
                }
                alert(for: context.window, info: text)
            }, completed: {
                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
            }))
        }, inviteLink: { [weak self] in
            if let strongSelf = self {
                strongSelf.navigationController?.push(LinkInvationController(strongSelf.context, peerId: strongSelf.peerId))
            }
        }, openInfo: { [weak self] peer in
             self?.navigationController?.push(PeerInfoController(context: context, peerId: peer.id))
        })
        
        let peerView = context.account.viewTracker.peerView(peerId)
        

        let (contactsDisposable, _) = context.peerChannelMemberCategoriesContextsManager.contacts(peerId: peerId, updated: { state in
            contactsPromise.set(.single(state.list))
        })
        actionsDisposable.add(contactsDisposable)
                                                                    
        let (disposable, loadMoreControl) = context.peerChannelMemberCategoriesContextsManager.recent(peerId: peerId, updated: { state in
            peersPromise.set(.single(state.list))
        })
        actionsDisposable.add(disposable)
        
        
        
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelMembersEntry>]> = Atomic(value: [])
        
        
        let signal = combineLatest(statePromise.get(), peerView, peersPromise.get(), contactsPromise.get(), appearanceSignal)
            |> deliverOnMainQueue
            |> map { state, view, peers, contacts, appearance -> TableUpdateTransition in
                let entries = channelMembersControllerEntries(view: view, context: context, state: state, participants: peers, contacts: contacts).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
        
        self.disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] transition in
            if let strongSelf = self {
                strongSelf.genericView.merge(with: transition)
                strongSelf.readyOnce()
            }
        }))
        
        genericView.setScrollHandler { position in
            if let loadMoreControl = loadMoreControl {
                switch position.direction {
                case .bottom:
                    context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
                default:
                    break
                }
            }
        }
    }
    
    deinit {
        disposable.dispose()
        removePeerDisposable.dispose()
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
    private func searchChannelUsers() {
        _ = (selectModalPeers(window: context.window, context: context, title: strings().selectPeersTitleSearchMembers, behavior: SelectChannelMembersBehavior(peerId: peerId, peerChannelMemberContextsManager: context.peerChannelMemberCategoriesContextsManager, limit: 1, settings: [])) |> deliverOnMainQueue |> map {$0.first}).start(next: { [weak self] peerId in
            if let peerId = peerId, let context = self?.context {
                self?.navigationController?.push(PeerInfoController(context: context, peerId: peerId))
            }
        })
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return SearchTitleBarView(controller: self, title:.initialize(string: defaultBarTitle, color: theme.colors.text, font: .medium(.title)), handler: { [weak self] in
            self?.searchChannelUsers()
        })
    }
    
}
