//
//  GroupCallInv.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore

private final class InvitationArguments {
    let account: Account
    let copyLink: (String)->Void
    let inviteGroupMember:(PeerId)->Void
    let inviteContact:(PeerId)->Void
    init(account: Account, copyLink: @escaping(String)->Void, inviteGroupMember:@escaping(PeerId)->Void, inviteContact:@escaping(PeerId)->Void) {
        self.account = account
        self.copyLink = copyLink
        self.inviteGroupMember = inviteGroupMember
        self.inviteContact = inviteContact
    }
}

private struct InvitationPeer : Equatable {
    let peer: Peer
    let presence: PeerPresence?
    let contact: Bool
    static func ==(lhs:InvitationPeer, rhs: InvitationPeer) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            return lhsPresence.isEqual(to: rhsPresence)
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        return true
    }
}

private struct InvitationState : Equatable {
    var inviteLink: String?
    var groupMembers:[InvitationPeer]
    var contacts:[InvitationPeer]
}

private func invitationEntries(state: InvitationState, arguments: InvitationArguments) -> [InputDataEntry] {
    
    
    let theme = InputDataGeneralData.Theme(backgroundColor: GroupCallTheme.windowBackground,
                                           highlightColor: GroupCallTheme.windowBackground.withAlphaComponent(0.7),
                                           borderColor: GroupCallTheme.memberSeparatorColor,
                                           accentColor: GroupCallTheme.blueStatusColor,
                                           secondaryColor: GroupCallTheme.grayStatusColor,
                                           textColor: .white,
                                           appearance: darkPalette.appearance)
    
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("_id_copy_link"), data: InputDataGeneralData(name: "Copy Invite Link", color: GroupCallTheme.blueStatusColor, icon: NSImage(named: "Icon_InviteViaLink")!.precomposed(GroupCallTheme.blueStatusColor), type: .none, viewType: .legacy, enabled: true, action: {
        
    }, theme: theme)))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    return entries
}


//
//func GroupCallInvitation(_ data: GroupCallUIController.UIData) -> InputDataModalController {
//
//
//
//
//    let initialState = InvitationState(inviteLink: nil, groupMembers: [], contacts: [])
//    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
//    let stateValue = Atomic(value: initialState)
//    let updateState: ((InvitationState) -> InvitationState) -> Void = { f in
//        statePromise.set(stateValue.modify { f($0) })
//    }
//
//    let arguments = InvitationArguments(account: data.call.account, copyLink: { link in
//
//    }, inviteGroupMember: { peerId in
//
//    }, inviteContact: { peerId in
//
//    })
//
//    let actionsDisposable = DisposableSet()
//
//
//    var loadMoreControl: PeerChannelMemberCategoryControl?
//
//    let groupMembersPromise = Promise<[RenderedChannelParticipant]>()
//    let (disposable, control) = data.peerMemberContextsManager.recent(postbox: data.call.account.postbox, network: data.call.account.network, accountPeerId: data.call.account.peerId, peerId: data.call.peerId, updated:  { state in
//        groupMembersPromise.set(.single(state.list))
//    })
//    loadMoreControl = control
//    actionsDisposable.add(disposable)
//
//    let members = data.call.members |> filter { $0 != nil } |> map { $0! }
//
//    let groupMembers: Signal<([InvitationPeer], [InvitationPeer]), NoError> = combineLatest(groupMembersPromise.get(), members, data.call.account.postbox.contactPeersView(accountPeerId: data.call.account.peerId, includePresences: true)) |> map { recent, participants, contacts in
//        let membersList = recent.filter { value in
//            if participants.participants.contains(where: { $0.peer.id == value.peer.id }) {
//                return false
//            }
//            return true
//        }.map {
//            InvitationPeer(peer: $0.peer, presence: $0.presences[$0.peer.id])
//        }
//        var contactList:[InvitationPeer] = []
//        for contact in contacts.peers {
//            let containsInCall = participants.participants.contains(where: { $0.peer.id == contact.id })
//            let containsInMembers = membersList.contains(where: { $0.peer.id == contact.id })
//            if !containsInMembers && !containsInCall {
//                contactList.append(InvitationPeer(peer: contact, presence: contacts.peerPresences[contact.id]))
//            }
//        }
//        return (membersList, contactList)
//    }
//
//    let inviteLink: Signal<String?, NoError> = data.call.account.viewTracker.peerView(data.call.peerId) |> map { peerView in
//        if let peer = peerViewMainPeer(peerView), let cachedData = peerView.cachedData as? CachedChannelData {
//            if let addressName = peer.addressName, !addressName.isEmpty {
//                return "https://t.me/@\(addressName)"
//            } else if let privateLink = cachedData.exportedInvitation {
//                return privateLink.link
//            }
//        }
//        return nil
//    }
//
//    actionsDisposable.add(combineLatest(groupMembers, inviteLink).start(next: { members, inviteLink in
//        updateState { value in
//            var value = value
//            value.contacts = members.1
//            value.groupMembers = members.0
//            value.inviteLink = inviteLink
//            return value
//        }
//    }))
//
//    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
//        return InputDataSignalValue(entries: invitationEntries(state: state, arguments: arguments))
//    }
//
//    let controller = InputDataController(dataSignal: signal, title: "Invite Members")
//
//    var close: (()->Void)? = nil
//
//
//    controller.leftModalHeader = ModalHeaderData(image: NSImage.init(named: "Icon_ChatSearchCancel")!.precomposed(.white), handler: {
//        close?()
//    })
//
//    controller.afterDisappear = {
//        actionsDisposable.dispose()
//    }
//
//    controller.updateDatas = { data in
//
//        return .none
//    }
//
//    controller.validateData = { data in
//        return .success(.custom({
//            close?()
//        }))
//    }
//
//    let modalController = InputDataModalController(controller, modalInteractions: nil, closeHandler: { f in f() }, size: NSMakeSize(300, 300))
//
//    close = { [weak modalController] in
//        modalController?.close()
//    }
//
//    controller.getBackgroundColor = {
//        GroupCallTheme.windowBackground
//    }
//
//    modalController.backgroundColor = GroupCallTheme.windowBackground
//
//    modalController.getHeaderColor = {
//        GroupCallTheme.windowBackground
//    }
//    modalController.getModalTheme = {
//        return ModalViewController.Theme(text: .white, grayText: GroupCallTheme.grayStatusColor, background: GroupCallTheme.windowBackground, border: GroupCallTheme.memberSeparatorColor)
//    }
//
//
//    return modalController
//
//}


final class GroupCallAddMembersBehaviour : SelectPeersBehavior {
    fileprivate let data: GroupCallUIController.UIData
    private let disposable = MetaDisposable()
    init(data: GroupCallUIController.UIData) {
        self.data = data
        super.init(settings: [], excludePeerIds: [], limit: 1)
    }
    
    override func start(account: Account, search: Signal<SearchState, NoError>, linkInvation: (() -> Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        
        
        let peerMemberContextsManager = data.peerMemberContextsManager
        let account = data.call.account
        let peerId = data.call.peerId
                        
        let members = data.call.members |> filter { $0 != nil } |> map { $0! }
        
        return search |> mapToSignal { search in
            let contacts:Signal<([Peer], [PeerId : PeerPresence]), NoError>
            if search.request.isEmpty {
                contacts = account.postbox.contactPeersView(accountPeerId: account.peerId, includePresences: true) |> map {
                    return ($0.peers, $0.peerPresences)
                }
            } else {
                contacts = account.postbox.searchContacts(query: search.request)
            }
            let groupMembers:Signal<[RenderedChannelParticipant], NoError> = Signal { subscriber in
                let (disposable, _) = peerMemberContextsManager.recent(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, searchQuery: search.request.isEmpty ? nil : search.request, updated:  { state in
                    subscriber.putNext(state.list)
                    subscriber.putCompletion()
                })
                return disposable
            }
            
            
            let allMembers: Signal<([InvitationPeer], [InvitationPeer]), NoError> = combineLatest(groupMembers, members, contacts) |> map { recent, participants, contacts in
                let membersList = recent.filter { value in
                    if participants.participants.contains(where: { $0.peer.id == value.peer.id }) {
                        return false
                    }
                    return true
                }.map {
                    InvitationPeer(peer: $0.peer, presence: $0.presences[$0.peer.id], contact: false)
                }
                var contactList:[InvitationPeer] = []
                for contact in contacts.0 {
                    let containsInCall = participants.participants.contains(where: { $0.peer.id == contact.id })
                    let containsInMembers = membersList.contains(where: { $0.peer.id == contact.id })
                    if !containsInMembers && !containsInCall {
                        contactList.append(InvitationPeer(peer: contact, presence: contacts.1[contact.id], contact: true))
                    }
                }
                return (membersList, contactList)
            }
            
            let inviteLink: Signal<String?, NoError> = account.viewTracker.peerView(peerId) |> map { peerView in
                if let peer = peerViewMainPeer(peerView), let cachedData = peerView.cachedData as? CachedChannelData {
                    if let addressName = peer.addressName, !addressName.isEmpty {
                        return "https://t.me/@\(addressName)"
                    } else if let privateLink = cachedData.exportedInvitation {
                        return privateLink.link
                    }
                }
                return nil
            }
            
            let previousSearch: Atomic<String> = Atomic<String>(value: "")
            return combineLatest(allMembers, inviteLink) |> map { members, inviteLink in
                var entries:[SelectPeerEntry] = []
                var index:Int32 = 0
                if let inviteLink = inviteLink {
                    entries.append(.inviteLink({
                        copyToClipboard(inviteLink)
                    }))
                    if !members.0.isEmpty  {
                        entries.append(.separator(index, "group members"))
                        index += 1
                    }
                }
                
                for member in members.0 {
                    entries.append(.peer(SelectPeerValue(peer: member.peer, presence: member.presence, subscribers: nil), index, true))
                    index += 1
                }
                
                if !members.0.isEmpty || !members.1.isEmpty {
                    entries.append(.separator(index, "contacts"))
                    index += 1
                }
                
                for member in members.1 {
                    entries.append(.peer(SelectPeerValue(peer: member.peer, presence: member.presence, subscribers: nil), index, true))
                    index += 1
                }
                
                let updatedSearch = previousSearch.swap(search.request) != search.request
                
                return (entries, updatedSearch)
            }
        }
        
        
    }
    
    
}

func GroupCallAddmembers(_ data: GroupCallUIController.UIData, window: Window) -> Signal<[PeerId], NoError> {
        
    return selectModalPeers(window: window, account: data.call.account, title: "Add Members", settings: [], excludePeerIds: [], limit: 1, behavior: GroupCallAddMembersBehaviour(data: data), confirmation: { peerIds in
        
        return .single(true)
        
    })
    
}
