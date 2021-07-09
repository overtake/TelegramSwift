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
    let enabled: Bool
    static func ==(lhs:InvitationPeer, rhs: InvitationPeer) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            return lhsPresence.isEqual(to: rhsPresence)
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        if lhs.contact != rhs.contact {
            return false
        }
        if lhs.enabled != rhs.enabled {
            return false
        }
        return true
    }
}


final class GroupCallAddMembersBehaviour : SelectPeersBehavior {
    fileprivate let data: GroupCallUIController.UIData
    private let disposable = MetaDisposable()
    private let window: Window
    init(data: GroupCallUIController.UIData, window: Window) {
        self.data = data
        self.window = window
        super.init(settings: [], excludePeerIds: [], limit: 1, customTheme: { GroupCallTheme.customTheme })
    }
    
    private let cachedContacts:Atomic<[PeerId]> = Atomic(value: [])
    func isContact(_ peerId: PeerId) -> Bool {
        return cachedContacts.with {
            $0.contains(peerId)
        }
    }
    
    override func start(context: AccountContext, search: Signal<SearchState, NoError>, linkInvation: ((Int) -> Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        
        
        let peerMemberContextsManager = data.peerMemberContextsManager
        let account = data.call.account
        let peerId = data.call.peerId
        let engine = data.call.engine
        let customTheme = self.customTheme
        let cachedContacts = self.cachedContacts
        let members = data.call.members |> filter { $0 != nil } |> map { $0! }
        let invited = data.call.invitedPeers
        let peer = data.call.peer
        let isUnmutedForAll: Signal<Bool, NoError> = data.call.state |> take(1) |> map { value in
            if let muteState = value.defaultParticipantMuteState {
                switch muteState {
                case .muted:
                    return false
                case .unmuted:
                    return true
                }
            }
            return false
        }
        return search |> mapToSignal { search in
            var contacts:Signal<([Peer], [PeerId : PeerPresence]), NoError>
            if search.request.isEmpty {
                contacts = account.postbox.contactPeersView(accountPeerId: account.peerId, includePresences: true) |> map {
                    return ($0.peers, $0.peerPresences)
                }
            } else {
                contacts = account.postbox.searchContacts(query: search.request)
            }
            contacts = combineLatest(account.postbox.peerView(id: peerId), contacts) |> map { peerView, contacts in
                if let peer = peerViewMainPeer(peerView) {
                    if peer.groupAccess.canAddMembers {
                        return contacts
                    } else {
                        return ([], [:])
                    }
                } else {
                    return ([], [:])
                }
            }
            
            let globalSearch: Signal<[Peer], NoError>
            if search.request.isEmpty {
                globalSearch = .single([])
            } else if let peer = peer, peer.groupAccess.canAddMembers {
                globalSearch = engine.peers.searchPeers(query: search.request.lowercased()) |> map {
                    return $0.0.map {
                        $0.peer
                    } + $0.1.map {
                        $0.peer
                    }
                }
            } else {
                globalSearch = .single([])
            }

            struct Participant {
                let peer: Peer
                let presence: PeerPresence?
            }

            let groupMembers:Signal<[Participant], NoError> = Signal { subscriber in
                let disposable: Disposable
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    (disposable, _) = peerMemberContextsManager.recent(peerId: peerId, searchQuery: search.request.isEmpty ? nil : search.request, updated:  { state in
                        if case .ready = state.loadingState {
                            subscriber.putNext(state.list.map {
                                return Participant(peer: $0.peer, presence: $0.presences[$0.peer.id])
                            })
                            subscriber.putCompletion()
                        }
                    })
                } else {
                    let signal: Signal<[Participant], NoError> = account.postbox.peerView(id: peerId) |> map { peerView in
                        let participants = (peerView.cachedData as? CachedGroupData)?.participants
                        let list:[Participant] = participants?.participants.compactMap { value in
                            if let peer = peerView.peers[value.peerId] {
                                return Participant(peer: peer, presence: peerView.peerPresences[value.peerId])
                            } else {
                                return nil
                            }
                        } ?? []
                        return list
                    }
                    disposable = signal.start(next: { list in
                        subscriber.putNext(list)
                    })
                }
                return disposable
            }
            
            
            let allMembers: Signal<([InvitationPeer], [InvitationPeer], [InvitationPeer]), NoError> = combineLatest(groupMembers, members, contacts, globalSearch, invited) |> map { recent, participants, contacts, global, invited in
                let membersList = recent.filter { value in
                    if participants.participants.contains(where: { $0.peer.id == value.peer.id }) {
                        return false
                    }
                    return !value.peer.isBot
                }.map {
                    InvitationPeer(peer: $0.peer, presence: $0.presence, contact: false, enabled: !invited.contains($0.peer.id))
                }
                var contactList:[InvitationPeer] = []
                for contact in contacts.0 {
                    let containsInCall = participants.participants.contains(where: { $0.peer.id == contact.id })
                    let containsInMembers = membersList.contains(where: { $0.peer.id == contact.id })
                    if !containsInMembers && !containsInCall {
                        contactList.append(InvitationPeer(peer: contact, presence: contacts.1[contact.id], contact: true, enabled: !invited.contains(contact.id)))
                    }
                }
                
                var globalList:[InvitationPeer] = []
                
                for peer in global {
                    let containsInCall = participants.participants.contains(where: { $0.peer.id == peer.id })
                    let containsInMembers = membersList.contains(where: { $0.peer.id == peer.id })
                    let containsInContacts = contactList.contains(where: { $0.peer.id == peer.id })
                    
                    if !containsInMembers && !containsInCall && !containsInContacts {
                        if !peer.isBot && peer.isUser {
                            globalList.append(.init(peer: peer, presence: nil, contact: false, enabled: !invited.contains(peer.id)))
                        }
                    }
                }
                
                _ = cachedContacts.swap(contactList.map { $0.peer.id } + globalList.map { $0.peer.id })
                return (membersList, contactList, globalList)
            }
            
            let previousSearch: Atomic<String> = Atomic<String>(value: "")
            return combineLatest(queue: .mainQueue(), allMembers, isUnmutedForAll) |> map { members, isUnmutedForAll in
                var entries:[SelectPeerEntry] = []
                var index:Int32 = 0
                if search.request.isEmpty {
                    if let linkInvation = linkInvation, let peer = peer {
                        if peer.groupAccess.canMakeVoiceChat {
                            if peer.isSupergroup, isUnmutedForAll {
                                entries.append(.inviteLink(L10n.voiceChatInviteCopyInviteLink, GroupCallTheme.invite_link, 0, customTheme(), linkInvation))
                            } else {
                                entries.append(.inviteLink(L10n.voiceChatInviteCopyListenersLink, GroupCallTheme.invite_listener, 0, customTheme(), linkInvation))
                                entries.append(.inviteLink(L10n.voiceChatInviteCopySpeakersLink, GroupCallTheme.invite_speaker, 1, customTheme(), linkInvation))
                            }
                        } else {
                            entries.append(.inviteLink(L10n.voiceChatInviteCopyInviteLink, GroupCallTheme.invite_link, 0, customTheme(), linkInvation))
                        }
                    }
                }
                
                if !members.0.isEmpty  {
                    entries.append(.separator(index, customTheme(), L10n.voiceChatInviteGroupMembers))
                    index += 1
                }
                
                
                for member in members.0 {
                    entries.append(.peer(SelectPeerValue(peer: member.peer, presence: member.presence, subscribers: nil, customTheme: customTheme()), index, member.enabled))
                    index += 1
                }
                
                if !members.1.isEmpty {
                    entries.append(.separator(index, customTheme(), L10n.voiceChatInviteContacts))
                    index += 1
                }
                
                for member in members.1 {
                    entries.append(.peer(SelectPeerValue(peer: member.peer, presence: member.presence, subscribers: nil, customTheme: customTheme()), index, member.enabled))
                    index += 1
                }
                
                if !members.2.isEmpty {
                    entries.append(.separator(index, customTheme(), L10n.voiceChatInviteGlobalSearch))
                    index += 1
                }
                
                
                for member in members.2 {
                    entries.append(.peer(SelectPeerValue(peer: member.peer, presence: member.presence, subscribers: nil, customTheme: customTheme()), index, member.enabled))
                    index += 1
                }
                
                
                
                let updatedSearch = previousSearch.swap(search.request) != search.request
                
                if entries.isEmpty {
                    entries.append(.searchEmpty(customTheme(), NSImage(named: "Icon_EmptySearchResults")!.precomposed(customTheme().grayTextColor)))
                }
                
                return (entries, updatedSearch)
            }
        }
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

final class GroupCallInviteMembersBehaviour : SelectPeersBehavior {
    fileprivate let data: GroupCallUIController.UIData
    private let disposable = MetaDisposable()
    private let window: Window
    init(data: GroupCallUIController.UIData, window: Window) {
        self.data = data
        self.window = window
        super.init(settings: [], excludePeerIds: [], limit: 100, customTheme: { GroupCallTheme.customTheme })
    }
    
    override var okTitle: String? {
        return L10n.voiceChatInviteInvite
    }
    
    private let cachedContacts:Atomic<[PeerId]> = Atomic(value: [])
    func isContact(_ peerId: PeerId) -> Bool {
        return cachedContacts.with {
            $0.contains(peerId)
        }
    }
    
    override func start(context: AccountContext, search: Signal<SearchState, NoError>, linkInvation: ((Int) -> Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        
        let account = data.call.account
        let peerId = data.call.peerId
        let engine = data.call.engine
        let customTheme = self.customTheme
        let cachedContacts = self.cachedContacts
        let members = data.call.members |> filter { $0 != nil } |> map { $0! }
        let invited = data.call.invitedPeers
        let peer = data.call.peer
        let isUnmutedForAll: Signal<Bool, NoError> = data.call.state |> take(1) |> map { value in
            if let muteState = value.defaultParticipantMuteState {
                switch muteState {
                case .muted:
                    return false
                case .unmuted:
                    return true
                }
            }
            return false
        }
        return search |> mapToSignal { search in
            var dialogs:Signal<([Peer]), NoError>
            if search.request.isEmpty {
                dialogs = account.viewTracker.tailChatListView(groupId: .root, count: 100) |> map { value in
                    var entries:[Peer] = []
                    for entry in value.0.entries.reversed() {
                        switch entry {
                        case let .MessageEntry(_, _, _, _, _, renderedPeer, _, _, _, _):
                            if let peer = renderedPeer.chatMainPeer, peer.canSendMessage() {
                                entries.append(peer)
                            }
                        default:
                            break
                        }
                    }
                    return entries
                }
            } else {
                dialogs = .single([])
            }
            
            let globalSearch: Signal<[Peer], NoError>
            if search.request.isEmpty {
                globalSearch = .single([])
            } else {
                globalSearch = engine.peers.searchPeers(query: search.request.lowercased()) |> map {
                    return $0.0.map {
                        $0.peer
                    } + $0.1.map {
                        $0.peer
                    }
                }
            }

            struct Participant {
                let peer: Peer
                let presence: PeerPresence?
            }
            
            
            let allMembers: Signal<([InvitationPeer], [InvitationPeer]), NoError> = combineLatest(members, dialogs, globalSearch, invited) |> map { recent, contacts, global, invited in
                let membersList = recent.participants.map {
                    InvitationPeer(peer: $0.peer, presence: nil, contact: false, enabled: !invited.contains($0.peer.id))
                }
                var contactList:[InvitationPeer] = []
                for contact in contacts {
                    let containsInMembers = membersList.contains(where: { $0.peer.id == contact.id })
                    if !containsInMembers {
                        contactList.append(InvitationPeer(peer: contact, presence: nil, contact: true, enabled: !invited.contains(contact.id)))
                    }
                }
                
                var globalList:[InvitationPeer] = []
                
                for peer in global {
                    let containsInMembers = membersList.contains(where: { $0.peer.id == peer.id })
                    let containsInContacts = contactList.contains(where: { $0.peer.id == peer.id })
                    
                    if !containsInMembers && !containsInContacts {
                        if peer.canSendMessage() {
                            globalList.append(.init(peer: peer, presence: nil, contact: false, enabled: !invited.contains(peer.id)))
                        }
                    }
                }
                
                _ = cachedContacts.swap(contactList.map { $0.peer.id } + globalList.map { $0.peer.id })
                return (contactList, globalList)
            }
            
            let inviteLink: Signal<Bool, NoError> = account.viewTracker.peerView(peerId) |> map { peerView in
                if let peer = peerViewMainPeer(peerView) {
                    return peer.groupAccess.canMakeVoiceChat
                }
                return (false)
            }
            
            let previousSearch: Atomic<String> = Atomic<String>(value: "")
            return combineLatest(allMembers, inviteLink, isUnmutedForAll) |> map { members, inviteLink, isUnmutedForAll in
                var entries:[SelectPeerEntry] = []
                var index:Int32 = 0
                if search.request.isEmpty {
                    if let linkInvation = linkInvation, let peer = peer {
                        if peer.addressName != nil {
                            if peer.groupAccess.canMakeVoiceChat {
                                if peer.isSupergroup, isUnmutedForAll {
                                    entries.append(.inviteLink(L10n.voiceChatInviteCopyInviteLink, GroupCallTheme.invite_link, 0, customTheme(), linkInvation))
                                } else {
                                    entries.append(.inviteLink(L10n.voiceChatInviteCopyListenersLink, GroupCallTheme.invite_listener, 0, customTheme(), linkInvation))
                                    entries.append(.inviteLink(L10n.voiceChatInviteCopySpeakersLink, GroupCallTheme.invite_speaker, 1, customTheme(), linkInvation))
                                }
                            } else {
                                entries.append(.inviteLink(L10n.voiceChatInviteCopyInviteLink, GroupCallTheme.invite_link, 0, customTheme(), linkInvation))
                            }
                        } else {
                            entries.append(.inviteLink(L10n.voiceChatInviteCopyInviteLink, GroupCallTheme.invite_link, 0, customTheme(), linkInvation))
                        }
                    }
                }
                
                if !members.0.isEmpty {
                    entries.append(.separator(index, customTheme(), L10n.voiceChatInviteChats))
                    index += 1
                }
                
                for member in members.0 {
                    entries.append(.peer(SelectPeerValue(peer: member.peer, presence: member.presence, subscribers: nil, customTheme: customTheme(), ignoreStatus: true), index, member.enabled))
                    index += 1
                }
                
                if !members.1.isEmpty {
                    entries.append(.separator(index, customTheme(), L10n.voiceChatInviteGlobalSearch))
                    index += 1
                }
                
                
                for member in members.1 {
                    entries.append(.peer(SelectPeerValue(peer: member.peer, presence: nil, subscribers: nil, customTheme: customTheme(), ignoreStatus: true), index, member.enabled))
                    index += 1
                }
                            
                let updatedSearch = previousSearch.swap(search.request) != search.request
                
                if entries.isEmpty {
                    entries.append(.searchEmpty(customTheme(), NSImage(named: "Icon_EmptySearchResults")!.precomposed(customTheme().grayTextColor)))
                }
                
                return (entries, updatedSearch)
            }
        }
    }
}

func GroupCallAddmembers(_ data: GroupCallUIController.UIData, window: Window) -> Signal<[PeerId], NoError> {
    
    let behaviour: SelectPeersBehavior
    let title: String
    if let peer = data.call.peer, peer.isChannel {
        title = L10n.voiceChatInviteChannelsTitle
        behaviour = GroupCallInviteMembersBehaviour(data: data, window: window)
    } else {
        title = L10n.voiceChatInviteTitle
        behaviour = GroupCallAddMembersBehaviour(data: data, window: window)
    }
    let account = data.call.account
    let context = data.call.accountContext
    let callPeerId = data.call.peerId
    let peerMemberContextsManager = data.peerMemberContextsManager

    let peer = data.call.peer
    let links = data.call.inviteLinks
    return selectModalPeers(window: window, context: data.call.accountContext, title: title, settings: [], excludePeerIds: [], limit: behaviour is GroupCallAddMembersBehaviour ? 1 : 100, behavior: behaviour, confirmation: { [weak behaviour, weak window, weak data] peerIds in
        

        if let behaviour = behaviour as? GroupCallAddMembersBehaviour {
            guard let peerId = peerIds.first else {
                return .single(false)
            }
            if behaviour.isContact(peerId) {
                return account.postbox.transaction {
                    return (user: $0.getPeer(peerId), chat: $0.getPeer(callPeerId))
                } |> mapToSignal { [weak window] values in
                    if let window = window {
                        return confirmSignal(for: window, information: L10n.voiceChatInviteMemberToGroupFirstText(values.user?.displayTitle ?? "", values.chat?.displayTitle ?? ""), okTitle: L10n.voiceChatInviteMemberToGroupFirstAdd, appearance: darkPalette.appearance) |> filter { $0 }
                            |> take(1)
                        |> mapToSignal { _ in
                            if peerId.namespace == Namespaces.Peer.CloudChannel {
                                return peerMemberContextsManager.addMember(peerId: callPeerId, memberId: peerId) |> map { _ in
                                    return true
                                }
                            } else {
                                return context.engine.peers.addGroupMember(peerId: callPeerId, memberId: peerId)
                                |> map {
                                    return true
                                } |> `catch` { _ in
                                    return .single(false)
                                }
                            }

                        } |> deliverOnMainQueue
                    } else {
                        return .single(false)
                    }
                }
            } else {
                return .single(true)
            }
        } else if let call = data?.call {
            
            let isUnmutedForAll: Signal<Bool, NoError> = call.state |> take(1) |> map { value in
                if let muteState = value.defaultParticipantMuteState {
                    switch muteState {
                    case .muted:
                        return false
                    case .unmuted:
                        return true
                    }
                }
                return false
            }
            
            return combineLatest(queue: .mainQueue(), links, isUnmutedForAll) |> mapToSignal { [weak window] links, isUnmutedForAll in
                return Signal { [weak window] subscriber in
                    if let window = window, let links = links, let peer = peer {
                        let third: String?
                        if peer.groupAccess.canMakeVoiceChat, peer.addressName != nil {
                            if peer.isSupergroup && isUnmutedForAll {
                                third = nil
                            } else {
                                third = L10n.voiceChatInviteConfirmThird
                            }
                        } else {
                            third = nil
                        }
                        
                        if let third = third {
                            modernConfirm(for: window, header: L10n.voiceChatInviteConfirmHeader, information: L10n.voiceChatInviteConfirmText, okTitle: L10n.voiceChatInviteConfirmOK, cancelTitle: L10n.modalCancel, thridTitle: third, successHandler: { result in
                                
                                let link: String
                                switch result {
                                case .basic:
                                    link = links.listenerLink
                                case .thrid:
                                    link = links.speakerLink ?? links.listenerLink
                                }
                                for peerId in peerIds {
                                    _ = enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: link, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)]).start()
                                }
                                
                                subscriber.putNext(true)
                                subscriber.putCompletion()
                                
                            }, appearance: GroupCallTheme.customTheme.appearance)
                        } else {
                            for peerId in peerIds {
                                _ = enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: links.listenerLink, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)]).start()
                            }
                            subscriber.putNext(true)
                            subscriber.putCompletion()
                        }
                        
                    } else {
                        subscriber.putNext(false)
                        subscriber.putCompletion()
                    }
                    
                    return EmptyDisposable
                }
            }
        } else {
            return .single(false)
        }
        
    }, linkInvation: { [weak window] index in
        
        if let peer = peer {
            if let window = window {
                if peer.addressName != nil {
                    _ = showModalProgress(signal: links, for: window).start(next: { [weak window] links in
                        if let links = links, let window = window {
                            if index == 0 {
                                copyToClipboard(links.listenerLink)
                            } else if let speakerLink = links.speakerLink  {
                                copyToClipboard(speakerLink)
                            }
                            showModalText(for: window, text: L10n.shareLinkCopied)
                        }
                    })
                } else {
                    _ = showModalProgress(signal: permanentExportedInvitation(account: account, peerId: callPeerId), for: window).start(next: { [weak window] link in
                        if let link = link, let window = window {
                            copyToClipboard(link.link)
                            showModalText(for: window, text: L10n.shareLinkCopied)
                        }
                    })
                }
            }
        }
    })
    
}
