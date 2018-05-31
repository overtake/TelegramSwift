//
//  ChannelMembersViewController.swift
//  Telegram
//
//  Created by keepcoder on 01/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac



private final class ChannelMembersControllerArguments {
    let account: Account
    
    let removePeer: (PeerId) -> Void
    let addMembers:()-> Void
    let inviteLink:()-> Void
    let openInfo:(Peer)->Void
    init(account: Account, removePeer: @escaping (PeerId) -> Void, addMembers:@escaping()->Void, inviteLink:@escaping()->Void, openInfo:@escaping(Peer)->Void) {
        self.account = account
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
        case let .section(sectionId):
            return -(sectionId)
        }
    }
    
    static func ==(lhs: ChannelMembersEntryStableId, rhs: ChannelMembersEntryStableId) -> Bool {
        switch lhs {
        case let .peer(peerId):
            if case .peer(peerId) = rhs {
                return true
            } else {
                return false
            }
        case .addMembers:
            if case .addMembers = rhs {
                return true
            } else {
                return false
            }
        case .membersDesc:
            if case .membersDesc = rhs {
                return true
            } else {
                return false
            }
        case .inviteLink:
            if case .inviteLink = rhs {
                return true
            } else {
                return false
            }
        case .loading:
            if case .loading = rhs {
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

private enum ChannelMembersEntry: Identifiable, Comparable {
    case peerItem(sectionId:Int, Int32, RenderedChannelParticipant, ShortPeerDeleting?, Bool)
    case addMembers(sectionId:Int)
    case inviteLink(sectionId:Int)
    case membersDesc(sectionId:Int)
    case section(sectionId:Int)
    case loading(sectionId: Int)
    
    var stableId: ChannelMembersEntryStableId {
        switch self {
        case let .peerItem(_, _, participant, _, _):
            return .peer(participant.peer.id)
        case .addMembers:
            return .addMembers
        case .inviteLink:
            return .inviteLink
        case .membersDesc:
            return .membersDesc
        case .loading:
            return .loading
        case let .section(sectionId):
            return .section(sectionId)
        }
    }
    
    
    var index:Int {
        switch self {
        case let .peerItem(sectionId, index, _, _, _):
            return (sectionId * 1000) + Int(index) + 100
        case let .addMembers(sectionId):
            return (sectionId * 1000) + 0
        case let .inviteLink(sectionId):
            return (sectionId * 1000) + 1
        case let .membersDesc(sectionId):
            return (sectionId * 1000) + 2
        case let .loading(sectionId):
            return (sectionId * 1000) + 4
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func ==(lhs: ChannelMembersEntry, rhs: ChannelMembersEntry) -> Bool {
        switch lhs {
        case let .peerItem(_, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled):
            if case let .peerItem(_, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsParticipant != rhsParticipant {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        case .addMembers:
            if case .addMembers = rhs {
                return true
            } else {
                return false
            }
        case .loading:
            if case .loading = rhs {
                return true
            } else {
                return false
            }
        case .inviteLink:
            if case .inviteLink = rhs {
                return true
            } else {
                return false
            }
        case .membersDesc:
            if case .membersDesc = rhs {
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
    
    static func <(lhs: ChannelMembersEntry, rhs: ChannelMembersEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: ChannelMembersControllerArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case let .peerItem(_, _, participant, editing, enabled):
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { peerId in
                    arguments.removePeer(peerId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.account, stableId: stableId, enabled: enabled, height:44, photoSize: NSMakeSize(32, 32), drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, action: {
            
                if case .plain = interactionType {
                    arguments.openInfo(participant.peer)
                }
            })
        case .addMembers:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.channelMembersAddMembers), nameStyle: blueActionButton, type: .none, action: {
                arguments.addMembers()
            })
        case .inviteLink:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.channelMembersInviteLink), nameStyle: blueActionButton, type: .none, action: {
                arguments.inviteLink()
            })
        case .membersDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.channelMembersMembersListDesc))
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
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

private func channelMembersControllerEntries(view: PeerView, account:Account, state: ChannelMembersControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelMembersEntry] {
    
    var entries: [ChannelMembersEntry] = []
    
    var sectionId:Int = 1

    if let participants = participants {
        
        if !participants.isEmpty {
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
        }
        
        if let peer = peerViewMainPeer(view) as? TelegramChannel {
            
            var usersManage:Bool = false
            if peer.hasAdminRights(.canInviteUsers) {
                entries.append(.addMembers(sectionId: sectionId))
                usersManage = true
            }
            if peer.hasAdminRights(.canChangeInviteLink) {
                entries.append(.inviteLink(sectionId: sectionId))
                usersManage = true
            }
            
            if usersManage {
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
                entries.append(.membersDesc(sectionId: sectionId))
            }
            
           
            var index: Int32 = 0
            for participant in participants.sorted(by: <) {
                
                let editable:Bool
                switch participant.participant {
                case let .member(_, _, adminInfo, _):
                    if let adminInfo = adminInfo {
                        editable = adminInfo.canBeEditedByAccountPeer
                    } else {
                        editable = participant.participant.peerId != account.peerId
                    }
                default:
                    editable = false
                }
                
                var deleting:ShortPeerDeleting? = nil
                if state.editing {
                    deleting = ShortPeerDeleting(editable: editable)
                }
                
                entries.append(.peerItem(sectionId: sectionId, index, participant, deleting, state.removingPeerId != participant.peer.id))
                index += 1
            }
            
        }

        
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
    
    init(account:Account, peerId:PeerId) {
        self.peerId = peerId
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let account = self.account
        let peerId = self.peerId
        
        let updateState: ((ChannelMembersControllerState) -> ChannelMembersControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let peersPromise = Promise<[RenderedChannelParticipant]?>(nil)
        
        let arguments = ChannelMembersControllerArguments(account: account, removePeer: { [weak self] memberId in
            
            updateState {
                return $0.withUpdatedRemovingPeerId(memberId)
            }
            
            let applyPeers: Signal<Void, NoError> = peersPromise.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { peers -> Signal<Void, NoError> in
                    if let peers = peers {
                        var updatedPeers = peers
                        for i in 0 ..< updatedPeers.count {
                            if updatedPeers[i].peer.id == memberId {
                                updatedPeers.remove(at: i)
                                break
                            }
                        }
                        peersPromise.set(.single(updatedPeers))
                    }
                    
                    return .complete()
            }
            
            self?.removePeerDisposable.set((removePeerMember(account: account, peerId: peerId, memberId: memberId) |> then(applyPeers) |> deliverOnMainQueue).start(error: { _ in
                updateState {
                    return $0.withUpdatedRemovingPeerId(nil)
                }
            }, completed: {
                updateState {
                    return $0.withUpdatedRemovingPeerId(nil)
                }
                
            }))
        }, addMembers: {
            peersPromise.set(selectModalPeers(account: account, title: tr(L10n.channelMembersSelectTitle), settings: [.contacts, .remote, .excludeBots]) |> mapToSignal { peers -> Signal<[RenderedChannelParticipant]?, Void> in
                return showModalProgress(signal: addChannelMembers(account: account, peerId: peerId, memberIds: peers) |> mapToSignal {
                    return channelMembers(postbox: account.postbox, network: account.network, peerId: peerId)
                }, for: mainWindow)
            })
        }, inviteLink: { [weak self] in
            if let strongSelf = self {
                strongSelf.navigationController?.push(LinkInvationController(account: strongSelf.account, peerId: strongSelf.peerId))
            }
        }, openInfo: { [weak self] peer in
             self?.navigationController?.push(PeerInfoController(account: account, peer: peer))
        })
        
        let peerView = account.viewTracker.peerView(peerId)
        
        let peersSignal: Signal<[RenderedChannelParticipant]?, NoError> = .single(nil) |> then(channelMembers(postbox: account.postbox, network: account.network, peerId: peerId))
        
        peersPromise.set(peersSignal)
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelMembersEntry>]> = Atomic(value: [])
        
        
        let signal = combineLatest(statePromise.get(), peerView, peersPromise.get(), appearanceSignal)
            |> deliverOnMainQueue
            |> map { state, view, peers, appearance -> TableUpdateTransition in
                let entries = channelMembersControllerEntries(view: view, account: account, state: state, participants: peers).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
        }
        
        disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] transition in
            if let strongSelf = self {
                strongSelf.genericView.merge(with: transition)
                strongSelf.readyOnce()
            }
        }))
    }
    
    deinit {
        disposable.dispose()
        removePeerDisposable.dispose()
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
}
