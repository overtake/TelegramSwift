//
//  GroupBlackListViewController.swift
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


private final class ChannelBlacklistControllerArguments {
    let account: Account
    
    let removePeer: (PeerId) -> Void
    let restrict:(RenderedChannelParticipant, Bool) -> Void
    let addMember:()->Void
    init(account: Account, removePeer: @escaping (PeerId) -> Void, restrict:@escaping(RenderedChannelParticipant, Bool) -> Void, addMember:@escaping()->Void) {
        self.account = account
        self.removePeer = removePeer
        self.restrict = restrict
        self.addMember = addMember
    }
}

private enum ChannelBlacklistEntryStableId: Hashable {
    case peer(PeerId)
    case empty
    case addMember
    case section(Int32)
    case header(Int32)
    var hashValue: Int {
        switch self {
        case let .peer(peerId):
            return peerId.hashValue
        case .empty:
            return 0
        case .section:
            return 1
        case .header:
            return 2
        case .addMember:
            return 3
        }
    }
    
    static func ==(lhs: ChannelBlacklistEntryStableId, rhs: ChannelBlacklistEntryStableId) -> Bool {
        switch lhs {
        case let .peer(peerId):
            if case .peer(peerId) = rhs {
                return true
            } else {
                return false
            }
        case .empty:
            if case .empty = rhs {
                return true
            } else {
                return false
            }
        case .addMember:
            if case .addMember = rhs {
                return true
            } else {
                return false
            }
        case .section(let section):
            if case .section(section) = rhs {
                return true
            } else {
                return false
            }
        case .header(let index):
            if case .header(index) = rhs {
                return true
            } else {
                return false
            }

        }
    }
}

private enum ChannelBlacklistEntry: Identifiable, Comparable {
    case peerItem(Int32, Int32, RenderedChannelParticipant, ShortPeerDeleting?, Bool)
    case empty(Bool)
    case header(Int32, Int32, String)
    case section(Int32)
    case addMember(Int32, Int32)
    var stableId: ChannelBlacklistEntryStableId {
        switch self {
        case let .peerItem(_, _, participant, _, _):
            return .peer(participant.peer.id)
        case .empty:
            return .empty
        case .section(let section):
            return .section(section)
        case .header(_, let index, _):
            return .header(index)
        case .addMember:
            return .addMember
        }
    }
    
    static func ==(lhs: ChannelBlacklistEntry, rhs: ChannelBlacklistEntry) -> Bool {
        switch lhs {
        case let .peerItem(lhsSectionId, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled):
            if case let .peerItem(rhsSectionId, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsSectionId != rhsSectionId {
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
        case let .empty(loading):
            if case .empty(loading) = rhs {
                return true
            } else {
                return false
            }
        case let .section(id):
            if case .section(id) = rhs {
                return true
            } else {
                return false
            }
        case let .addMember(sectionId, index):
            if case .addMember(sectionId, index) = rhs {
                return true
            } else {
                return false
            }
        case let .header(sectionId, index, text):
            if case .header(sectionId, index, text) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var index:Int32 {
        switch self {
        case let .section(section):
            return (section * 1000) - section
        case let .header(section, index, _):
            return (section * 1000) + index
        case let .addMember(section, index):
            return (section * 1000) + index
        case .empty:
            return 0
        case let .peerItem(section, index, _, _, _):
            return (section * 1000) + index

        }
    }
    
    static func <(lhs: ChannelBlacklistEntry, rhs: ChannelBlacklistEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: ChannelBlacklistControllerArguments, initialSize:NSSize) -> TableRowItem {
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
            
            var string:String = tr(L10n.peerStatusRecently)
            
            if case let .member(_, _, _, banInfo) = participant.participant {
                if let banInfo = banInfo, let peer = participant.peers[banInfo.restrictedBy] {
                    if banInfo.rights.flags.contains(.banReadMessages) {
                        string = tr(L10n.channelBlacklistBlockedBy(peer.displayTitle))
                    } else {
                        string = tr(L10n.channelBlacklistRestrictedBy(peer.displayTitle))
                    }
                } else {
                    if let presence = participant.presences[participant.peer.id] as? TelegramUserPresence {
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        (string,_, _) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
                    } else if let peer = participant.peer as? TelegramUser, let botInfo = peer.botInfo {
                        string = botInfo.flags.contains(.hasAccessToChatHistory) ? tr(L10n.peerInfoBotStatusHasAccess) : tr(L10n.peerInfoBotStatusHasNoAccess)
                    }
                }
            }

            
            
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.account, stableId: stableId, enabled: enabled, height:44, photoSize: NSMakeSize(32, 32), status: string, drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, action: {
                if case .plain = interactionType {
                    arguments.restrict(participant, true)
                }
            })
        case let .empty(progress):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: progress, text: tr(L10n.channelBlacklistEmptyDescrpition))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .header(_, _, let text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .addMember:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.channelBlacklistAddMember), nameStyle: blueActionButton, action: {
                arguments.addMember()
            })
        }
    }
}

private struct ChannelBlacklistControllerState: Equatable {
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
    
    static func ==(lhs: ChannelBlacklistControllerState, rhs: ChannelBlacklistControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.removingPeerId != rhs.removingPeerId {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: editing, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: self.editing, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelBlacklistControllerState {
        return ChannelBlacklistControllerState(editing: self.editing, removingPeerId: removingPeerId)
    }
}

private func channelBlacklistControllerEntries(view: PeerView, state: ChannelBlacklistControllerState, participants: ChannelBlacklist?) -> [ChannelBlacklistEntry] {
    
    var entries: [ChannelBlacklistEntry] = []
    
    var index:Int32 = 0
    var sectionId:Int32 = 1
    
    
    
    if let peer = peerViewMainPeer(view) as? TelegramChannel {
        if peer.hasAdminRights(.canBanUsers) {
            
            entries.append(.section(sectionId))
            sectionId += 1
            
            entries.append(.addMember(sectionId, index))
            index += 1
        }
    
        if let participants = participants {
            if !participants.isEmpty {
                entries.append(.section(sectionId))
                sectionId += 1
            }
            
            if !participants.restricted.isEmpty {
                entries.append(.header(sectionId, index, tr(L10n.channelBlacklistRestricted)))
                index += 1
                for participant in participants.restricted.sorted(by: <) {
                    
                    let editable = peer.hasAdminRights(.canBanUsers)
                    
                    var deleting:ShortPeerDeleting? = nil
                    if state.editing {
                        deleting = ShortPeerDeleting(editable: editable)
                    }
                    
                    entries.append(.peerItem(sectionId, index, participant, deleting, state.removingPeerId != participant.peer.id))
                    index += 1
                }
            }
            
            
            
            if !participants.banned.isEmpty {
                
                if !participants.restricted.isEmpty {
                    entries.append(.section(sectionId))
                    sectionId += 1
                }
                
                entries.append(.header(sectionId, index, tr(L10n.channelBlacklistBlocked)))
                index += 1
                for participant in participants.banned.sorted(by: <) {
                    
                    var editable = true
                    if case .creator = participant.participant {
                        editable = false
                    }
                    
                    var deleting:ShortPeerDeleting? = nil
                    if state.editing {
                        deleting = ShortPeerDeleting(editable: editable)
                    }
                    
                    entries.append(.peerItem(sectionId, index, participant, deleting, state.removingPeerId != participant.peer.id))
                    index += 1
                }
            }
        }
    }
    if entries.isEmpty {
        entries.append(.empty(participants == nil))
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelBlacklistEntry>], right: [AppearanceWrapperEntry<ChannelBlacklistEntry>], initialSize:NSSize, arguments:ChannelBlacklistControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ChannelBlacklistViewController: EditableViewController<TableView> {

    private let peerId:PeerId
    
    private let statePromise = ValuePromise(ChannelBlacklistControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: ChannelBlacklistControllerState())
    private let removePeerDisposable:MetaDisposable = MetaDisposable()
    private let updatePeerDisposable = MetaDisposable()
    private let disposable:MetaDisposable = MetaDisposable()
    
    init(account:Account, peerId:PeerId) {
        self.peerId = peerId
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let account = self.account
        let peerId = self.peerId
        
        let updateState: ((ChannelBlacklistControllerState) -> ChannelBlacklistControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let peersPromise = Promise<ChannelBlacklist?>(nil)
        let viewValue:Atomic<PeerView?> = Atomic(value: nil)
        
        let restrict:(RenderedChannelParticipant, Bool) -> Void = { [weak self] participant, unban in
            let strongSelf = self
            showModal(with: RestrictedModalViewController(account: account, peerId: peerId, participant: participant, unban: unban, updated: { [weak strongSelf] updatedRights in
                let additional = viewValue.modify({$0})?.peers ?? [:]
                switch participant.participant {
                case let .member(memberId, _, _, _):
                    //if banInfo != updatedRights {
                        
                        let applyPeer: Signal<Void, NoError> = peersPromise.get()
                            |> filter { $0 != nil }
                            |> map {$0!}
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { peers -> Signal<Void, NoError> in
                                peersPromise.set(.single(peers.withRemovedParticipant(participant.withUpdatedBannedRights(ChannelParticipantBannedInfo(rights: updatedRights, restrictedBy: account.peerId, isMember: true)).withUpdatedAdditionalPeers(additional))))
                                return .complete()
                        }
                        
                        let peerUpdate = account.postbox.transaction { transaction -> Void in
                            updatePeers(transaction: transaction, peers: [participant.peer], update: { (_, updated) -> Peer? in
                                return updated
                            })
                        }
                        
                        strongSelf?.updatePeerDisposable.set(showModalProgress(signal: peerUpdate |> then(updateChannelMemberBannedRights(account: account, peerId: peerId, memberId: memberId, rights: updatedRights) |> map {_ in return}) |> then(applyPeer), for: mainWindow).start())
                   // }
                default:
                    break
                }
                
                
            }), for: mainWindow)
        }
        
        let arguments = ChannelBlacklistControllerArguments(account: account, removePeer: { [weak self] memberId in
            
            updateState {
                return $0.withUpdatedRemovingPeerId(memberId)
            }
            
            let applyPeers: Signal<Void, NoError> = peersPromise.get()
                |> filter { $0 != nil }
                |> map {$0!}
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { peers -> Signal<Void, NoError> in
                    peersPromise.set(.single(peers.withRemovedPeerId(memberId)))
                    return .complete()
                }
            
            self?.removePeerDisposable.set((updateChannelMemberBannedRights(account: account, peerId: peerId, memberId: memberId, rights: TelegramChannelBannedRights(flags: [], untilDate: 0)) |> map {_ in return} |> then(applyPeers) |> deliverOnMainQueue).start(error: { _ in
                updateState {
                    return $0.withUpdatedRemovingPeerId(nil)
                }
            }, completed: {
                updateState {
                    return $0.withUpdatedRemovingPeerId(nil)
                }
                
            }))
        }, restrict: restrict, addMember: {
            let behavior = SelectChannelMembersBehavior(peerId: peerId, limit: 1)
            
            _ = (selectModalPeers(account: account, title: tr(L10n.channelBlacklistSelectNewUserTitle), limit: 1, behavior: behavior, confirmation: { peerIds in
                if let peerId = peerIds.first {
                    var adminError:Bool = false
                    if let participant = behavior.participants[peerId] {
                        if case let .member(_, _, adminInfo, _) = participant.participant {
                            if let adminInfo = adminInfo {
                                if !adminInfo.canBeEditedByAccountPeer && adminInfo.promotedBy != account.peerId {
                                    adminError = true
                                }
                            }
                        } else {
                            adminError = true
                        }
                    }
                    if adminError {
                        alert(for: mainWindow, info: tr(L10n.channelBlacklistDemoteAdminError))
                        return .single(false)
                    }
                }
                return .single(true)
            }) |> map {$0.first} |> filter {$0 != nil} |> map {$0!}).start(next: { memberId in
                var participant:RenderedChannelParticipant?
                if let p = behavior.participants[memberId] {
                    participant = p
                } else if let temporary = behavior.result[memberId] {
                    participant = RenderedChannelParticipant(participant: ChannelParticipant.member(id: memberId, invitedAt: 0, adminInfo: nil, banInfo: nil), peer: temporary.peer, peers: [memberId: temporary.peer], presences: temporary.presence != nil ? [memberId: temporary.presence!] : [:])
                }
                if let participant = participant {
                    if case .member(_, _, _, let banInfo) = participant.participant {
                        let info = ChannelParticipantBannedInfo(rights: TelegramChannelBannedRights(flags: [.banSendMessages, .banReadMessages, .banSendMedia, .banSendStickers, .banEmbedLinks], untilDate: .max), restrictedBy: account.peerId, isMember: true)
                        restrict(participant.withUpdatedBannedRights(info), !(banInfo == nil || !banInfo!.rights.flags.isEmpty))
                    }
                }
            })
        })
        
        let peerView = account.viewTracker.peerView(peerId)
        
        
        
        let peersSignal: Signal<ChannelBlacklist?, NoError> = .single(nil) |> then(channelBlacklistParticipants(account: account, peerId: peerId) |> map { Optional($0) })
        
        peersPromise.set(peersSignal)
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelBlacklistEntry>]> = Atomic(value: [])

        
        let signal = combineLatest(statePromise.get(), peerView, peersPromise.get(), appearanceSignal)
            |> deliverOnMainQueue
            |> map { state, view, blacklist, appearance -> (TableUpdateTransition, PeerView) in
                _ = viewValue.swap(view)
                let entries = channelBlacklistControllerEntries(view: view, state: state, participants: blacklist).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return (prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), view)
        }
        
        disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] transition, peerView in
            if let strongSelf = self {
                strongSelf.genericView.merge(with: transition)
                strongSelf.readyOnce()
                strongSelf.rightBarView.isHidden = strongSelf.genericView.item(at: 0) is SearchEmptyRowItem
                if let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                    strongSelf.rightBarView.isHidden = strongSelf.rightBarView.isHidden || !peer.hasAdminRights(.canBanUsers)
                }
            }
        }))
    }
    
    deinit {
        disposable.dispose()
        removePeerDisposable.dispose()
        updatePeerDisposable.dispose()
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
}


