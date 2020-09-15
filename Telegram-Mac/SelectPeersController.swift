//
//  SelectPeersController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

enum SelectPeerEntryStableId : Hashable {
    case search
    case peerId(PeerId, Int32)
    case searchEmpty
    case separator(Int32)
    case inviteLink
    var hashValue: Int {
        switch self {
        case .search:
            return 0
        case .searchEmpty:
            return 1
        case .inviteLink:
            return -1
        case .separator(let index):
            return Int(index)
        case let .peerId(peerId, _):
            return peerId.hashValue
        }
    }
}

enum SelectPeerEntry : Comparable, Identifiable {
    case peer(SelectPeerValue, Int32, Bool)
    case searchEmpty
    case separator(Int32, String)
    case inviteLink(()->Void)
    var stableId: SelectPeerEntryStableId {
        switch self {
        case .searchEmpty:
            return .searchEmpty
        case .separator(let index, _):
            return .separator(index)
        case let .peer(peer, index, _):
            return .peerId(peer.peer.id, index)
        case .inviteLink:
            return .inviteLink
        }
    }
    
    static func ==(lhs:SelectPeerEntry, rhs:SelectPeerEntry) -> Bool {
        switch lhs {
        case .searchEmpty:
            if case .searchEmpty = rhs {
                return true
            } else {
                return false
            }
        case .separator(let index, let text):
            if case .separator(index, text) = rhs {
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
        case let .peer(peer, index, enabled):
            switch rhs {
            case .peer(peer, index, enabled):
                return true
            default:
                return false
            }
        }
    }
    
    var index:Int32 {
        switch self {
        case .searchEmpty:
            return 1
        case .inviteLink:
            return -1
        case .separator(let index, _):
            return index
        case .peer(_, let index, _):
            return index
        }
    }
    
    static func <(lhs:SelectPeerEntry, rhs:SelectPeerEntry) -> Bool {
       return lhs.index < rhs.index
    }
}

private extension PeerIndexNameRepresentation {
    func isLessThan(other: PeerIndexNameRepresentation) -> ComparisonResult {
        switch self {
        case let .title(lhsTitle, _):
            switch other {
            case let .title(title, _):
                return lhsTitle.compare(title)
            case let .personName(_, last, _, _):
                let lastResult = lhsTitle.compare(last)
                if lastResult == .orderedSame {
                    return .orderedAscending
                } else {
                    return lastResult
                }
            }
        case let .personName(lhsFirst, lhsLast, _, _):
            switch other {
            case let .title(title, _):
                let lastResult = lhsFirst.compare(title)
                if lastResult == .orderedSame {
                    return .orderedDescending
                } else {
                    return lastResult
                }
            case let .personName(first, last, _, _):
                let lastResult = lhsLast.compare(last)
                
                
                if lastResult == .orderedSame {
                    let f = lhsFirst.prefix(1)
                    if let character = f.first {
                        let characterString = String(character)
                        let scalars = characterString.unicodeScalars
                        
                        if !CharacterSet.letters.contains(scalars[scalars.startIndex]) {
                            return .orderedDescending
                        }
                    }
                    return lhsFirst.compare(first)
                } else {
                    return lastResult
                }
            }
        }
    }
}

struct TemporaryPeer {
    let peer:Peer
    let presence:PeerPresence?
}

func <(lhs:Peer, rhs:Peer) -> Bool {
    return lhs.indexName.isLessThan(other: rhs.indexName) == .orderedAscending
}

struct SelectPeerValue : Equatable {
    
    
    let peer: Peer
    let presence: PeerPresence?
    let subscribers: Int?
    init(peer: Peer, presence: PeerPresence?, subscribers: Int?) {
        self.peer = peer
        self.presence = presence
        self.subscribers = subscribers
    }
    
    static func == (lhs: SelectPeerValue, rhs: SelectPeerValue) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            if !lhsPresence.isEqual(to: rhsPresence) {
                return false
            }
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        
        if lhs.subscribers != rhs.subscribers {
            return false
        }
        
        return true
    }
    
    func status(_ context: AccountContext) -> (String?, NSColor) {
        var color:NSColor = theme.colors.grayText
        var string:String = L10n.peerStatusLongTimeAgo
        
        if let count = subscribers, peer.isGroup || peer.isSupergroup {
            let countValue = L10n.privacySettingsGroupMembersCountCountable(count)
            string = countValue.replacingOccurrences(of: "\(count)", with: count.separatedNumber)
        } else if peer.isGroup || peer.isSupergroup {
            return (nil, color)
        } else if let presence = presence as? TelegramUserPresence {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: context.timeDifference, relativeTo: Int32(timestamp))
        } else {
            if let addressName = peer.addressName {
                color = theme.colors.accent
                string = "@\(addressName)"
            }
        }
        if peer.isBot {
            string = L10n.presenceBot.lowercased()
        }
        return (string, color)
    }
}

private func entriesForView(_ view: ContactPeersView, searchPeers:[PeerId], searchView:MultiplePeersView, excludeIds:[PeerId] = [], linkInvation: (()->Void)? = nil) -> [SelectPeerEntry] {
    var entries: [SelectPeerEntry] = []

    if let linkInvation = linkInvation {
        entries.append(SelectPeerEntry.inviteLink(linkInvation))
    }
    
    //entries.append(.search(false))
    if let accountPeer = view.accountPeer {
        var index:Int32 = 0
        
        let searchPeers = searchView.peers.map({$0.value}).sorted(by: <)
        let peers = view.peers.sorted(by: <)
        
        var isset:[PeerId:PeerId] = [:]
        for peer in searchPeers {
            if isset[peer.id] == nil {
                isset[peer.id] = peer.id
                if let peer = peer as? TelegramUser, let botInfo = peer.botInfo {
                    if !botInfo.flags.contains(.worksWithGroups) {
                        continue
                    }
                }
                
                entries.append(.peer(SelectPeerValue(peer: peer, presence: searchView.presences[peer.id], subscribers: nil), index, !excludeIds.contains(peer.id)))
                index += 1
            }
        }
        
        for peer in peers {
            if !peer.isEqual(accountPeer), isset[peer.id] == nil {
                isset[peer.id] = peer.id
                if let peer = peer as? TelegramUser, let botInfo = peer.botInfo {
                    if !botInfo.flags.contains(.worksWithGroups) {
                        continue
                    }
                }
                
                entries.append(.peer(SelectPeerValue(peer: peer, presence: view.peerPresences[peer.id], subscribers: nil), index, !excludeIds.contains(peer.id)))
                index += 1
                if index == 230 {
                    break
                }
            }
        }
        
        if entries.count == 1 {
            entries.append(.searchEmpty)
        }
    }

    
    return entries
}

private func searchEntriesForPeers(_ peers:[SelectPeerValue], _ global: [SelectPeerValue], context: AccountContext, isLoading: Bool, excludeIds:Set<PeerId> = Set()) -> [SelectPeerEntry] {
    var entries: [SelectPeerEntry] = []
    
    var excludeIds = excludeIds
    var index:Int32 = 0
    for peer in peers {
        if context.account.peerId != peer.peer.id {
            if let peer = peer.peer as? TelegramUser, let botInfo = peer.botInfo {
                if !botInfo.flags.contains(.worksWithGroups) {
                    continue
                }
            }
            
            entries.append(.peer(peer, index, !excludeIds.contains(peer.peer.id)))
            excludeIds.insert(peer.peer.id)
            index += 1
        }
    }
    
    if !global.isEmpty {
       
        let global = global.filter { peer in
            if context.account.peerId != peer.peer.id, !excludeIds.contains(peer.peer.id) {
                if let peer = peer.peer as? TelegramUser, let botInfo = peer.botInfo {
                    if !botInfo.flags.contains(.worksWithGroups) {
                        return false
                    }
                }
                return true
            } else {
                return false
            }
        }
        
        if !global.isEmpty {
            entries.append(.separator(index, L10n.searchSeparatorGlobalPeers))
            index += 1
            
        }
        
        for peer in global {
            entries.append(.peer(peer, index, !excludeIds.contains(peer.peer.id)))
            excludeIds.insert(peer.peer.id)
            index += 1
        }
    }
    
    if entries.isEmpty && !isLoading {
        entries.append(.searchEmpty)
    }
    
    return entries
}

fileprivate func prepareEntries(from:[SelectPeerEntry]?, to:[SelectPeerEntry], context: AccountContext, initialSize:NSSize, animated:Bool, interactions:SelectPeerInteraction, singleAction:((Peer)->Void)? = nil, scroll: TableScrollState = .none(nil)) -> Signal<TableUpdateTransition, NoError> {
    return Signal { subscriber in
        var cancelled = false
        
        func makeItem(_ entry: SelectPeerEntry) -> TableRowItem {
            var item:TableRowItem
            
            switch entry {
            case let .peer(peer, _, enabled):
                
               
                
                let interactionType:ShortPeerItemInteractionType
                if singleAction != nil {
                    interactionType = .plain
                } else {
                    interactionType = .selectable(interactions)
                }
                
                let (status, color) = peer.status(context)
                
                item = ShortPeerRowItem(initialSize, peer: peer.peer, account: context.account, stableId: entry.stableId, enabled: enabled, statusStyle: ControlStyle(foregroundColor: color), status: status, drawLastSeparator: true, inset:NSEdgeInsets(left: 10, right:10), interactionType:interactionType, action: {
                    if let singleAction = singleAction {
                        singleAction(peer.peer)
                    }
                })
            case .searchEmpty:
                return SearchEmptyRowItem(initialSize, stableId: entry.stableId)
            case .separator(_, let text):
                return SeparatorRowItem(initialSize, entry.stableId, string: text.uppercased())
            case let .inviteLink(action):
                return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: L10n.peerSelectInviteViaLink, nameStyle: blueActionButton, type: .none, action: {
                    action()
                    interactions.close()
                }, thumb: GeneralThumbAdditional(thumb: theme.icons.group_invite_via_link, textInset: 39), inset: NSEdgeInsetsMake(0, 16, 0, 10))
            }
            
            let _ = item.makeSize(initialSize.width)
            
            return item
        }
        

        
        if Thread.isMainThread {
            var initialIndex:Int = 0
            var height:CGFloat = 0
            var firstInsertion:[(Int, TableRowItem)] = []
            let entries = Array(to)
            
            let index:Int = 0
            
            for i in index ..< entries.count {
                let item = makeItem(to[i])
                height += item.height
                firstInsertion.append((i, item))
                if initialSize.height < height {
                    break
                }
            }
            
            
            initialIndex = firstInsertion.count
            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: firstInsertion, updated: [], state: scroll))
            
            prepareQueue.async {
                if !cancelled {
                    
                    
                    var insertions:[(Int, TableRowItem)] = []
                    let updates:[(Int, TableRowItem)] = []
                    
                    for i in initialIndex ..< entries.count {
                        let item:TableRowItem
                        item = makeItem(to[i])
                        insertions.append((i, item))
                    }
                    
                    
                    subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: updates, state: scroll))
                    subscriber.putCompletion()
                }
            }
        } else {
            let (deleted,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
                return makeItem(entry)
            })
            
            subscriber.putNext(TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state: scroll))
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            cancelled = true
        }
        
    }
    
}


public struct SelectPeerSettings: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: SelectPeerSettings) {
        var rawValue: UInt32 = 0
        
        if flags.contains(SelectPeerSettings.remote) {
            rawValue |= SelectPeerSettings.remote.rawValue
        }
        
        if flags.contains(SelectPeerSettings.contacts) {
            rawValue |= SelectPeerSettings.contacts.rawValue
        }
        if flags.contains(SelectPeerSettings.excludeBots) {
            rawValue |= SelectPeerSettings.excludeBots.rawValue
        }
        self.rawValue = rawValue
    }
    
    public static let remote = SelectPeerSettings(rawValue: 1 << 1)
    public static let contacts = SelectPeerSettings(rawValue: 1 << 2)
    public static let groups = SelectPeerSettings(rawValue: 1 <<  3)
    public static let excludeBots = SelectPeerSettings(rawValue: 1 <<  4)
}

class SelectPeersBehavior {
    var result:[PeerId:TemporaryPeer] {
        return _peersResult.modify({$0})
    }
    
    fileprivate let _peersResult:Atomic<[PeerId:TemporaryPeer]> = Atomic(value: [:])
    
    var participants:[PeerId:RenderedChannelParticipant] {
        return [:]
    }
    
    fileprivate let inSearchSelected:Atomic<[PeerId]> = Atomic(value:[])
    
    fileprivate let settings:SelectPeerSettings
    fileprivate let excludePeerIds:[PeerId]
    fileprivate let limit:Int32
    
    init(settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX) {
        self.settings = settings
        self.excludePeerIds = excludePeerIds
        self.limit = limit
    }
    
    
    func start(context: AccountContext, search:Signal<SearchState, NoError>, linkInvation: (()->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        return .complete()
    }

}



class SelectGroupMembersBehavior : SelectPeersBehavior {
    fileprivate let peerId:PeerId
    private let _renderedResult:Atomic<[PeerId:RenderedChannelParticipant]> = Atomic(value: [:])
    override var participants:[PeerId:RenderedChannelParticipant] {
        return _renderedResult.modify({$0})
    }
    
    init(peerId:PeerId, limit: Int32 = .max, settings: SelectPeerSettings = [.remote]) {
        self.peerId = peerId
        super.init(settings: settings, limit: limit)
    }
    
    override func start(context: AccountContext, search: Signal<SearchState, NoError>, linkInvation: (()->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        let peerId = self.peerId
        let _renderedResult = self._renderedResult
        
        let previousSearch =  Atomic<String?>(value: nil)
        
        return search |> map { SearchState(state: .Focus, request: $0.request) } |> distinctUntilChanged |> mapToSignal { search -> Signal<([SelectPeerEntry], Bool), NoError>  in
            
            let participantsPromise: Promise<[RenderedChannelParticipant]> = Promise()
            
            
            let viewKey = PostboxViewKey.peer(peerId: peerId, components: .all)
            
            participantsPromise.set(context.account.postbox.combinedView(keys: [viewKey]) |> map { combinedView in
                let peerView = combinedView.views[viewKey] as? PeerView
                
                if let peerView = peerView {
                    if let cachedData = peerView.cachedData as? CachedGroupData, let participants = cachedData.participants {
                        
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
                            return []
                        }
                        
                        return participants.participants.compactMap { participant in
                            
                            if let peer = peerView.peers[participant.peerId] {
                                
                                let rendered: RenderedChannelParticipant
                                
                                switch participant {
                                case .creator:
                                    rendered = RenderedChannelParticipant(participant: .creator(id: peer.id, adminInfo: nil, rank: nil), peer: peer)
                                case .admin:
                                    var peers: [PeerId: Peer] = [:]
                                    peers[creator.id] = creator
                                    peers[peer.id] = peer
                                    rendered = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(flags: .groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == context.account.peerId), banInfo: nil, rank: nil), peer: peer, peers: peers)
                                case .member:
                                    var peers: [PeerId: Peer] = [:]
                                    peers[creator.id] = creator
                                    peers[peer.id] = peer
                                    rendered = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil), peer: peer, peers: peers)
                                }
                                
                                if search.request.isEmpty {
                                    return rendered
                                } else {
                                    let found = !rendered.peer.displayTitle.lowercased().components(separatedBy: " ").filter {$0.hasPrefix(search.request.lowercased())}.isEmpty
                                    if found {
                                        return rendered
                                    } else {
                                        return nil
                                    }
                                }
                            } else {
                                return nil
                            }
                        }
                        
                    }
                }
                return []
            })
            
            return participantsPromise.get() |> map { participants in
                _ = _renderedResult.swap(participants.toDictionary(with: { $0.peer.id }))
                let updatedSearch = previousSearch.swap(search.request) != search.request
                return (channelMembersEntries(participants, users: [], remote: [], context: context, isLoading: false), updatedSearch)
            }
        }
    }
    
    deinit {
        _ = _renderedResult.swap([:])
        
    }
}

class SelectChannelMembersBehavior : SelectPeersBehavior {
    fileprivate let peerId:PeerId
    private let _renderedResult:Atomic<[PeerId:RenderedChannelParticipant]> = Atomic(value: [:])    
    private let loadDisposable = MetaDisposable()
    override var participants:[PeerId:RenderedChannelParticipant] {
        return _renderedResult.modify({$0})
    }

    init(peerId:PeerId, limit: Int32 = .max, settings: SelectPeerSettings = [.remote]) {
        self.peerId = peerId
        super.init(settings: settings, limit: limit)
    }
    
    override func start(context: AccountContext, search: Signal<SearchState, NoError>, linkInvation: (()->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        let peerId = self.peerId
        let _renderedResult = self._renderedResult
        let _peersResult = self._peersResult
        let settings = self.settings
        let loadDisposable = self.loadDisposable
        let previousSearch = Atomic<String?>(value: nil)
        return search |> mapToSignal { query -> Signal<SearchState, NoError> in
            if query.request.isEmpty {
                return .single(query)
            } else {
                return .single(query) |> delay(0.2, queue: .mainQueue())
            }
        } |> map { SearchState(state: .Focus, request: $0.request) } |> distinctUntilChanged |> mapToSignal { search -> Signal<([SelectPeerEntry], Bool), NoError> in
            
            let participantsPromise: Promise<[RenderedChannelParticipant]> = Promise()
            
            var isListLoading: Bool = false
            
            let value = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: search.request.isEmpty ? nil : search.request, requestUpdate: true, updated: { state in
                
                let applyList: Bool
                
                if case .loading = state.loadingState {
                    isListLoading = true
                    applyList = search.request.isEmpty
                } else {
                    applyList = true
                    isListLoading = false
                }
                if applyList {
                    participantsPromise.set(.single(state.list))
                    _ = _renderedResult.swap(state.list.toDictionary(with: {$0.peer.id}))
                }
            })

            
            loadDisposable.set(value.0)

            let foundLocalPeers = context.account.postbox.searchContacts(query: search.request.lowercased())
            
            let foundRemotePeers:Signal<([Peer], [Peer], Bool), NoError> = searchPeers(account: context.account, query: search.request.lowercased()) |> map {($0.map{$0.peer}, $1.map{$0.peer}, false)}
            
            
            let contactsSearch: Signal<([TemporaryPeer], [TemporaryPeer], Bool), NoError>
            
            if settings.contains(.remote) {
                contactsSearch = combineLatest(foundLocalPeers |> map {$0.0}, foundRemotePeers) |> map { values -> ([Peer], [Peer], Bool) in
                    return (values.0 + values.1.0, values.1.1, values.1.2 && search.request.length >= 5)
                    }
                    |> mapToSignal { values -> Signal<([Peer], [Peer], MultiplePeersView, Bool), NoError> in
                        return context.account.postbox.multiplePeersView(values.0.map {$0.id}) |> take(1) |> map { views in
                            return (values.0, values.1, views, values.2)
                        }
                    }
                    |> map { value -> ([TemporaryPeer], [TemporaryPeer], Bool) in
                        
                        let contacts = value.0.filter {$0.isUser || ($0.isBot && !settings.contains(.excludeBots))}.map({TemporaryPeer(peer: $0, presence: value.2.presences[$0.id])})
                        let global = value.1.filter {$0.isUser || ($0.isBot && !settings.contains(.excludeBots))}.map({TemporaryPeer(peer: $0, presence: value.2.presences[$0.id])})
                        
                        let _ = _peersResult.swap((contacts + global).reduce([:], { current, peer in
                            var current = current
                            current[peer.peer.id] = peer
                            return current
                        }));
                        
                        return (contacts, global, value.3)
                    }
            } else {
                contactsSearch = .single(([], [], false))
            }
            
            
            if !search.request.isEmpty {
                return combineLatest(participantsPromise.get(), contactsSearch) |> map { participants, peers in
                    let updatedSearch = previousSearch.swap(search.request) != search.request
                    return (channelMembersEntries(participants, users: peers.0, remote: peers.1, context: context, isLoading: isListLoading && peers.2), updatedSearch)
                }
            } else {
                return participantsPromise.get() |> map { participants in
                    let updatedSearch = previousSearch.swap(search.request) != search.request
                    return (channelMembersEntries(participants, context: context, isLoading: isListLoading), updatedSearch)
                }
            }
        }
    }
    
    deinit {
        loadDisposable.dispose()
        _ = _renderedResult.swap([:])
        
    }
}

private func channelMembersEntries(_ participants:[RenderedChannelParticipant], users:[TemporaryPeer]? = nil, remote:[TemporaryPeer] = [], context: AccountContext, isLoading: Bool) -> [SelectPeerEntry] {
    var entries: [SelectPeerEntry] = []
    var peerIds:[PeerId:PeerId] = [:]
    
    let participants = participants.filter({ participant -> Bool in
        let result = peerIds[participant.participant.peerId] == nil
        peerIds[participant.participant.peerId] = participant.participant.peerId
        return result
    })
    
    let users = users?.filter({ peer -> Bool in
        let result = peerIds[peer.peer.id] == nil
        peerIds[peer.peer.id] = peer.peer.id
        return result
    })
    let remote = remote.filter({ peer -> Bool in
        let result = peerIds[peer.peer.id] == nil
        peerIds[peer.peer.id] = peer.peer.id
        return result
    })
    
    var index:Int32 = 0
    if !participants.isEmpty {
        //entries.append(.separator(index, tr(L10n.channelSelectPeersMembers)))
        index += 1
        for participant in participants {
            if context.account.peerId != participant.peer.id {
                
                entries.append(.peer(SelectPeerValue(peer: participant.peer, presence: participant.presences[participant.peer.id], subscribers: nil), index, true))
                index += 1
            }
        }
    }
    if let users = users, !users.isEmpty {
        entries.append(.separator(index, tr(L10n.channelSelectPeersContacts)))
        index += 1
        for peer in users {
            if context.account.peerId != peer.peer.id {
                
                entries.append(.peer(SelectPeerValue(peer: peer.peer, presence: peer.presence, subscribers: nil), index, true))
                index += 1
            }
        }
    }
    
    if !remote.isEmpty {
        entries.append(.separator(index, tr(L10n.channelSelectPeersGlobal)))
        index += 1
        for peer in remote {
            if context.account.peerId != peer.peer.id {
                entries.append(.peer(SelectPeerValue(peer: peer.peer, presence: peer.presence, subscribers: nil), index, true))
                index += 1
            }
        }
    }
    
    if entries.isEmpty && !isLoading {
        entries.append(.searchEmpty)
    }
    
    return entries
}


final class SelectChatsBehavior: SelectPeersBehavior {
    override func start(context: AccountContext, search: Signal<SearchState, NoError>, linkInvation: (()->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        
        let previousSearch = Atomic<String?>(value: nil)
        
        return search |> distinctUntilChanged |> mapToSignal { search -> Signal<([SelectPeerEntry], Bool), NoError> in
            
            if search.request.isEmpty {
                
                return context.account.viewTracker.tailChatListView(groupId: .root, count: 200) |> deliverOn(prepareQueue) |> mapToQueue {  value -> Signal<([SelectPeerEntry], Bool), NoError> in
                    var entries:[Peer] = []
                    

                    for entry in value.0.entries.reversed() {
                        switch entry {
                        case let .MessageEntry(_, _, _, _, _, renderedPeer, _, _, _, _):
                            if let peer = renderedPeer.chatMainPeer, peer.canSendMessage(false), peer.canInviteUsers, peer.isSupergroup || peer.isGroup {
                                entries.append(peer)
                            }
                        default:
                            break
                        }
                    }
                    
                    
                    let updatedSearch = previousSearch.swap(search.request) != search.request

                    if entries.isEmpty {
                        return .single(([.searchEmpty], updatedSearch))
                    } else {
                        var common:[SelectPeerEntry] = []
                        var index:Int32 = 0
                        for value in entries {
                            common.append(.peer(SelectPeerValue(peer: value, presence: nil, subscribers: nil), index, true))
                            index += 1
                        }
                        return .single((common, updatedSearch))
                    }
                }
            } else {
                return context.account.postbox.searchPeers(query: search.request.lowercased()) |> map {
                    return $0.compactMap({$0.chatMainPeer}).filter {($0.isSupergroup || $0.isGroup) && $0.canInviteUsers}
                } |> deliverOn(prepareQueue) |> map { entries -> ([SelectPeerEntry], Bool) in
                    var common:[SelectPeerEntry] = []
                    
                    let updatedSearch = previousSearch.swap(search.request) != search.request

                    
                    if entries.isEmpty {
                        common.append(.searchEmpty)
                    } else {
                        var index:Int32 = 0
                        for peer in entries {
                            common.append(.peer(SelectPeerValue(peer: peer, presence: nil, subscribers: nil), index, true))
                            index += 1
                        }
                        
                    }
                    return (common, updatedSearch)
                }
            }
            
        }

    }
}


class SelectUsersAndGroupsBehavior : SelectPeersBehavior {
    
    
    override func start(context: AccountContext, search:Signal<SearchState, NoError>, linkInvation: (()->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        
        let previousSearch = Atomic<String?>(value: nil)
        
        return search |> mapToSignal { [weak self] search -> Signal<([SelectPeerEntry], Bool), NoError> in
            
            let settings = self?.settings ?? SelectPeerSettings()
            let excludePeerIds = (self?.excludePeerIds ?? [])
            
            if search.request.isEmpty {
                let inSearch:[PeerId] = self?.inSearchSelected.modify({$0}) ?? []
                
                
                return context.account.viewTracker.tailChatListView(groupId: .root, count: 200) |> take(1) |> mapToSignal { view in
                    let entries = view.0.entries
                    var peers:[Peer] = []
                    var presences:[PeerId : PeerPresence] = [:]
                    for entry in entries.reversed() {
                        switch entry {
                        case let .MessageEntry(_, _, _, _, _, peer, presence, _, _, _):
                            if let peer = peer.chatMainPeer, !peer.isChannel && !peer.isBot {
                                peers.append(peer)
                                if let presence = presence {
                                    presences[peer.id] = presence
                                }
                            }
                        default:
                            break
                        }
                    }
                    
                    return context.account.postbox.transaction { transaction -> [PeerId: CachedPeerData] in
                        var cachedData:[PeerId: CachedPeerData] = [:]
                        for peer in peers {
                            if peer.isSupergroup, let data = transaction.getPeerCachedData(peerId: peer.id) {
                                cachedData[peer.id] = data
                            }
                        }
                        return cachedData
                    } |> map { cachedData in
                        let local = peers.map { peer -> SelectPeerValue in
                            if let cachedData = cachedData[peer.id] as? CachedChannelData {
                                let subscribers: Int?
                                if let count = cachedData.participantsSummary.memberCount {
                                    subscribers = Int(count)
                                } else {
                                    subscribers = nil
                                }
                                return SelectPeerValue(peer: peer, presence: nil, subscribers: subscribers)
                            } else if let peer = peer as? TelegramGroup {
                                return SelectPeerValue(peer: peer, presence: nil, subscribers: peer.participantCount)
                            } else {
                                return SelectPeerValue(peer: peer, presence: presences[peer.id], subscribers: nil)
                            }
                        }
                        let updatedSearch = previousSearch.swap(search.request) != search.request

                        return (searchEntriesForPeers(local, [], context: context, isLoading: false), updatedSearch)
                    }
                }
                
            } else  {
                
                let foundLocalPeers = context.account.postbox.searchPeers(query: search.request.lowercased())
                
                let foundRemotePeers:Signal<([Peer], [Peer], Bool), NoError> = settings.contains(.remote) ? .single(([], [], true)) |> then ( searchPeers(account: context.account, query: search.request.lowercased()) |> map {($0.map{$0.peer}, $1.map{$0.peer}, false)} ) : .single(([], [], false))
                
                return combineLatest(foundLocalPeers |> map {$0.compactMap( {$0.chatMainPeer })}, foundRemotePeers) |> map { values -> ([Peer], [Peer], Bool) in
                    return (uniquePeers(from: values.0), values.1.0 + values.1.1, values.1.2 && search.request.length >= 5)
                    }
                    |> runOn(prepareQueue)
                    |> mapToSignal { values -> Signal<([SelectPeerEntry], Bool), NoError> in
                        
                        var values = values
                        if settings.contains(.excludeBots) {
                            values.0 = values.0.filter {!$0.isBot}
                        }
                        values.0 = values.0.filter { !$0.isChannel }
                        values.1 = values.1.filter { !$0.isChannel }
                        
                        let local = uniquePeers(from: values.0 + values.1)
                        
                        return context.account.postbox.transaction { transaction -> ([PeerId : PeerPresence], [PeerId : CachedPeerData]) in
                            var presences: [PeerId : PeerPresence] = [:]
                            var cachedData: [PeerId : CachedPeerData] = [:]
                            for peer in local {
                                if peer.isSupergroup {
                                    if let data = transaction.getPeerCachedData(peerId: peer.id) {
                                        cachedData[peer.id] = data
                                    }
                                } else {
                                    if let presence = transaction.getPeerPresence(peerId: peer.id) {
                                        presences[peer.id] = presence
                                    }
                                }
                            }
                            return (presences, cachedData)
                        } |> map { (presences, cachedData) -> ([SelectPeerEntry], Bool) in
                            let local:[SelectPeerValue] = local.map { peer in
                                if let cachedData = cachedData[peer.id] as? CachedChannelData {
                                    let subscribers: Int?
                                    if let count = cachedData.participantsSummary.memberCount {
                                        subscribers = Int(count)
                                    } else {
                                        subscribers = nil
                                    }
                                    return SelectPeerValue(peer: peer, presence: nil, subscribers: subscribers)
                                } else if let peer = peer as? TelegramGroup {
                                    return SelectPeerValue(peer: peer, presence: nil, subscribers: peer.participantCount)
                                } else {
                                    return SelectPeerValue(peer: peer, presence: presences[peer.id], subscribers: nil)
                                }
                            }
                            let updatedSearch = previousSearch.swap(search.request) != search.request

                            return (searchEntriesForPeers(local, [], context: context, isLoading: values.2), updatedSearch)
                        }
                        
                }
            }
            
        }
        
    }
    
}


fileprivate class SelectContactsBehavior : SelectPeersBehavior {
    fileprivate let index: PeerNameIndex = .lastNameFirst
    private var previousGlobal:Atomic<[SelectPeerValue]> = Atomic(value: [])
   
    deinit {
        var bp:Int = 0
        bp += 1
        _ = previousGlobal.swap([])
    }
    override func start(context: AccountContext, search:Signal<SearchState, NoError>, linkInvation: (()->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        
        let previousGlobal = self.previousGlobal
        let previousSearch = Atomic<String?>(value: nil)
        return search |> mapToSignal { [weak self] search -> Signal<([SelectPeerEntry], Bool), NoError> in
            
            let settings = self?.settings ?? SelectPeerSettings()
            let excludePeerIds = (self?.excludePeerIds ?? [])
            
            if search.request.isEmpty {
                let inSearch:[PeerId] = self?.inSearchSelected.modify({$0}) ?? []
                return combineLatest(context.account.postbox.contactPeersView(accountPeerId: context.account.peerId, includePresences: true), context.account.postbox.multiplePeersView(inSearch))
                    |> deliverOn(prepareQueue)
                    |> map { view, searchView -> ([SelectPeerEntry], Bool) in
                        let updatedSearch = previousSearch.swap(search.request) != search.request
                        return (entriesForView(view, searchPeers: inSearch, searchView: searchView, excludeIds: excludePeerIds, linkInvation: linkInvation), updatedSearch)
                }
                
            } else  {
                
                let foundLocalPeers = context.account.postbox.searchContacts(query: search.request.lowercased())
                
                let foundRemotePeers:Signal<([Peer], [Peer], Bool), NoError> = settings.contains(.remote) ? .single(([], [], true)) |> then ( searchPeers(account: context.account, query: search.request.lowercased()) |> map {($0.map{$0.peer}, $1.map{$0.peer}, false)} ) : .single(([], [], false))
                
                return combineLatest(foundLocalPeers |> map {$0.0}, foundRemotePeers) |> map { values -> ([Peer], [Peer], Bool) in
                    return (uniquePeers(from: values.0), values.1.0 + values.1.1, values.1.2 && search.request.length >= 5)
                }
                    |> runOn(prepareQueue)
                    |> mapToSignal { values -> Signal<([SelectPeerEntry], Bool), NoError> in
                        var values = values
                        if settings.contains(.excludeBots) {
                            values.0 = values.0.filter {!$0.isBot}
                        }
                        values.0 = values.0.filter {!$0.isChannel && (settings.contains(.groups) || (!$0.isSupergroup && !$0.isGroup))}
                        values.1 = values.1.filter {!$0.isChannel && (settings.contains(.groups) || (!$0.isSupergroup && !$0.isGroup))}
                        let local = values.0
                        let global = values.1
                        
                        return context.account.postbox.transaction { transaction -> [PeerId : PeerPresence] in
                            var presences: [PeerId : PeerPresence] = [:]
                            for peer in local {
                                if let presence = transaction.getPeerPresence(peerId: peer.id) {
                                    presences[peer.id] = presence
                                }
                            }
                            return presences
                            } |> map { presences -> ([SelectPeerEntry], Bool) in
                                let local:[SelectPeerValue] = local.map { peer in
                                    return SelectPeerValue(peer: peer, presence: presences[peer.id], subscribers: nil)
                                }
                                
                                var filteredLocal:[SelectPeerValue] = []
                                var excludeIds = Set<PeerId>()
                                for peer in local {
                                    if context.account.peerId != peer.peer.id {
                                        if let peer = peer.peer as? TelegramUser, let botInfo = peer.botInfo {
                                            if !botInfo.flags.contains(.worksWithGroups) {
                                                continue
                                            }
                                        }
                                        excludeIds.insert(peer.peer.id)
                                        filteredLocal.append(peer)
                                    }
                                }
                                
                                var global:[SelectPeerValue] = global.map { peer in
                                    return SelectPeerValue(peer: peer, presence: presences[peer.id], subscribers: nil)
                                }.filter { peer in
                                    if context.account.peerId != peer.peer.id, !excludeIds.contains(peer.peer.id) {
                                        if let peer = peer.peer as? TelegramUser, let botInfo = peer.botInfo {
                                            if !botInfo.flags.contains(.worksWithGroups) {
                                                return false
                                            }
                                        }
                                        return true
                                    } else {
                                        return false
                                    }
                                }
                                
                                
                                if !global.isEmpty {
                                    _ = previousGlobal.swap(global)
                                } else {
                                    global = previousGlobal.with { $0 }
                                }
                                let updatedSearch = previousSearch.swap(search.request) != search.request
                                return (searchEntriesForPeers(local, global, context: context, isLoading: values.2), updatedSearch)
                        }
                }
            }
            
        }
        
    }
    
}

final class SelectPeersControllerView: View, TokenizedProtocol {
    let tableView: TableView = TableView()
    let tokenView: TokenizedView
    private let separatorView: View = View()
    required init(frame frameRect: NSRect) {
        tokenView = TokenizedView(frame: NSMakeRect(0, 0, frameRect.width - 20, 30), localizationFunc: { key in
            return translate(key: key, [])
        }, placeholderKey: "Compose.SelectGroupUsers.Placeholder")
        
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(tokenView)
        addSubview(separatorView)
        tokenView.delegate = self
        needsLayout = true
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.background
        separatorView.backgroundColor = theme.colors.border
    }
    
    func tokenizedViewDidChangedHeight(_ view: TokenizedView, height: CGFloat, animated: Bool) {
        tokenView._change(pos: NSMakePoint(tokenView.frame.minX, 10), animated: animated)
        tableView.change(size: NSMakeSize(frame.width, frame.height - height - 20), animated: animated)
        tableView.change(pos: NSMakePoint(0, height + 20), animated: animated)
        separatorView.change(pos: NSMakePoint(0, tokenView.frame.maxY + 10), animated: animated)
    }
    
    override func layout() {
        super.layout()
        tokenView.frame = NSMakeRect(0, 10, frame.width - 20, 30)
        tokenView.centerX()
        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 50)
        separatorView.frame = NSMakeRect(0, tokenView.frame.maxY + 10, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SelectPeersController: ComposeViewController<[PeerId], Void, SelectPeersControllerView>, Notifable {
    
    private let behavior:SelectContactsBehavior
    private let search:Promise<String> = Promise()
    private let disposable:MetaDisposable = MetaDisposable()
    let interactions:SelectPeerInteraction = SelectPeerInteraction()
    private var previous:Atomic<[SelectPeerEntry]?> = Atomic(value:nil)
    private let tokenDisposable: MetaDisposable = MetaDisposable()
    private let isNewGroup: Bool
    private var limitsConfiguration: LimitsConfiguration? {
        didSet {
            if oldValue == nil {
                requestUpdateCenterBar()
                return
            }
            if let limitsConfiguration = limitsConfiguration {
                self.interactions.update({$0.withUpdateLimit(limitsConfiguration.maxGroupMemberCount)})
                if limitsConfiguration.isEqual(to: oldValue!) == false  {
                    requestUpdateCenterBar()
                }
            }
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            
            let added = value.selected.subtracting(oldValue.selected)
            let removed = oldValue.selected.subtracting(value.selected)
            
            if added.count == 0 && value.isLimitReached {
                alert(for: mainWindow, info: L10n.composeCreateGroupLimitError)
            }
            
            let tokens = added.map {
                return SearchToken(name: value.peers[$0]?.compactDisplayTitle ?? L10n.peerDeletedUser, uniqueId: $0.toInt64())
            }
            genericView.tokenView.addTokens(tokens: tokens, animated: animated)
            
            let idsToRemove:[Int64] = removed.map {
                $0.toInt64()
            }
            genericView.tokenView.removeTokens(uniqueIds: idsToRemove, animated: animated)
            
            self.nextEnabled(!value.selected.isEmpty)
            
            
            
            if let limits = limitsConfiguration {
                let attributed = NSMutableAttributedString()
                _ = attributed.append(string: L10n.telegramSelectPeersController, color: theme.colors.text, font: .medium(.title))
                _ = attributed.append(string: "   ")
                _ = attributed.append(string: "\(interactions.presentation.selected.count.formattedWithSeparator)/\(limits.maxSupergroupMemberCount.formattedWithSeparator)", color: theme.colors.grayText, font: .normal(.title))
                self.centerBarView.text = attributed
            } else {
                setCenterTitle(defaultBarTitle)
            }
            
        }
    }
    
    override func requestUpdateCenterBar() {
        notify(with: interactions.presentation, oldValue: interactions.presentation, animated: false)
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if  other is SelectPeersController {
            return true
        }
        return false
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if !self.interactions.presentation.selected.isEmpty {
            return super.returnKeyAction()
        }
        return .rejected
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.nextEnabled(false)

        let context = self.context
        let interactions = self.interactions
        
        interactions.add(observer: self)
        
        search.set(genericView.tokenView.textUpdater)
        
        tokenDisposable.set(genericView.tokenView.tokensUpdater.start(next: { tokens in
            let ids = Set(tokens.map({PeerId($0.uniqueId)}))
            let unselected = interactions.presentation.selected.symmetricDifference(ids)
            
            interactions.update( { unselected.reduce($0, { current, value in
                return current.deselect(peerId: value)
            })})
        }))
        
        let previous = self.previous
        let initialSize = atomicSize
        
        let limitsSignal:Signal<LimitsConfiguration?, NoError> = isNewGroup ? context.account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration]) |> map { values -> LimitsConfiguration? in
            return values.values[PreferencesKeys.limitsConfiguration] as? LimitsConfiguration
        } : .single(nil)
        
        let first: Atomic<Bool> = Atomic(value: true)
        
        let transition = combineLatest(queue: prepareQueue, behavior.start(context: context, search: search.get() |> distinctUntilChanged |> map {SearchState(state: .None, request: $0)}), limitsSignal) |> mapToQueue { entries, limits -> Signal<(TableUpdateTransition, LimitsConfiguration?), NoError> in
            return prepareEntries(from: previous.swap(entries.0), to: entries.0, context: context, initialSize: initialSize.modify({$0}), animated: false, interactions: interactions, scroll: entries.1 ? .up(false) : .none(nil)) |> runOn(first.swap(false) ? .mainQueue() : prepareQueue) |> map { ($0, limits) }
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition, limits in
            self?.readyOnce()
            self?.genericView.tableView.merge(with: transition)
            self?.limitsConfiguration = limits
        }))
    }
    
    
    
    var tokenView:TokenizedView {
        return genericView.tokenView
    }
    
    
    init(titles: ComposeTitles, context: AccountContext, settings:SelectPeerSettings = [.contacts], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX, isNewGroup: Bool = false) {
        self.behavior = SelectContactsBehavior(settings: settings, excludePeerIds: excludePeerIds, limit: limit)
        self.isNewGroup = isNewGroup
        super.init(titles: titles, context: context)
    }

    override func firstResponder() -> NSResponder? {
        return genericView.tokenView
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }

    override func executeNext() {
        onComplete.set(.single(Array(interactions.presentation.selected)))
    }

    deinit {
        disposable.dispose()
        tokenDisposable.dispose()
        interactions.remove(observer: self)
    }
    
}

fileprivate class SelectPeersView : View, TokenizedProtocol {
    let tableView:TableView = TableView()
    let tokenView: TokenizedView
    let separatorView: View = View()
    required init(frame frameRect: NSRect) {
        tokenView = TokenizedView(frame: NSMakeRect(0, 0, frameRect.width - 20, 30), localizationFunc: { key in
            return translate(key: key, [])
        }, placeholderKey: "SearchField.Search")
        super.init(frame: frameRect)
        addSubview(tokenView)
        addSubview(tableView)
        addSubview(separatorView)
        tokenView.delegate = self
        backgroundColor = theme.colors.background
       
        updateLocalizationAndTheme(theme: theme)
        layout()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        separatorView.backgroundColor = theme.colors.border
    }
    
    
    fileprivate override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 50, frame.width  , frame.height - 50)
        tokenView.frame = NSMakeRect(10, 10, frame.width - 20, 50)
    }
    
    func tokenizedViewDidChangedHeight(_ view: TokenizedView, height: CGFloat, animated: Bool) {
        tokenView._change(pos: NSMakePoint(tokenView.frame.minX, 10), animated: animated)
        tableView.change(size: NSMakeSize(frame.width, frame.height - height - 20), animated: animated)
        tableView.change(pos: NSMakePoint(0, height + 20), animated: animated)
        separatorView.change(pos: NSMakePoint(0, tokenView.frame.maxY + 10), animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


private class SelectPeersModalController : ModalViewController, Notifable {
    
    private let behavior:SelectPeersBehavior
    private let search:Promise<SearchState> = Promise()
    private let disposable:MetaDisposable = MetaDisposable()
    let interactions:SelectPeerInteraction = SelectPeerInteraction()
    private var previous:Atomic<[SelectPeerEntry]?> = Atomic(value:nil)
    private let context:AccountContext
    private let defaultTitle:String
    private let confirmation:([PeerId])->Signal<Bool,NoError>
    fileprivate let onComplete:Promise<[PeerId]> = Promise()
    private let completeDisposable = MetaDisposable()
    private let tokenDisposable = MetaDisposable()
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            if behavior.limit > 1 {
                
                let added = value.selected.subtracting(oldValue.selected)
                let removed = oldValue.selected.subtracting(value.selected)
                
                let tokens = added.map {
                    return SearchToken(name: value.peers[$0]?.compactDisplayTitle ?? L10n.peerDeletedUser, uniqueId: $0.toInt64())
                }
                genericView.tokenView.addTokens(tokens: tokens, animated: animated)
                
                let idsToRemove:[Int64] = removed.map {
                    $0.toInt64()
                }
                genericView.tokenView.removeTokens(uniqueIds: idsToRemove, animated: animated)                
                
                modal?.interactions?.updateEnables(!value.selected.isEmpty)
            }
        }
    }
    
    var tokenView:TokenizedView {
        return genericView.tokenView
    }
    
    override func firstResponder() -> NSResponder? {
        return tokenView
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override open func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 120, max(genericView.tableView.listHeight, 350))), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 120, max(genericView.tableView.listHeight, 350))), animated: animated)
        }
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ModalViewController {
            return other == self
        }
        return false
    }
    
    fileprivate var genericView:SelectPeersView {
        return self.view as! SelectPeersView
    }
    
    override func viewClass() -> AnyClass {
        return SelectPeersView.self
    }
    
    override var modal: Modal? {
        didSet {
            if behavior.limit > 1 {
                modal?.interactions?.updateEnables(false)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let interactions = self.interactions
        let initialSize = atomicSize
        
        interactions.close = { [weak self] in
            self?.close()
        }
        
        interactions.add(observer: self)
        
        search.set(genericView.tokenView.textUpdater |> map {SearchState(state: .None, request: $0)})
        
        tokenDisposable.set(genericView.tokenView.tokensUpdater.start(next: { tokens in
            let ids = Set(tokens.map({PeerId($0.uniqueId)}))
            let unselected = interactions.presentation.selected.symmetricDifference(ids)
            
            interactions.update( { unselected.reduce($0, { current, value in
                return current.deselect(peerId: value)
            })})
        }))
        
        let previous = self.previous
        
        var singleAction:((Peer)->Void)? = nil
        if behavior.limit == 1 {
            singleAction = { [weak self] peer in
                
                _ = (context.account.postbox.transaction { transaction -> Void in
                    updatePeers(transaction: transaction, peers: [peer], update: { _, updated -> Peer? in
                        return updated
                    })
                }).start()
            self?.confirmSelected([peer.id], [peer])
            }
        }
        
        let first: Atomic<Bool> = Atomic(value: true)

        
        let transition = behavior.start(context: context, search: search.get() |> distinctUntilChanged, linkInvation: linkInvation) |> mapToQueue { entries, updateSearch -> Signal<TableUpdateTransition, NoError> in
            return prepareEntries(from: previous.swap(entries), to: entries, context: context, initialSize: initialSize.modify({$0}), animated: false, interactions:interactions, singleAction: singleAction, scroll: updateSearch ? .up(false) : .none(nil)) |> runOn(first.swap(false) ? .mainQueue() : prepareQueue)
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            self?.readyOnce()
        }))
    }
    
    private let linkInvation: (()->Void)?
    
    init(context: AccountContext, title:String, settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX, confirmation:@escaping([PeerId])->Signal<Bool,NoError>, behavior: SelectPeersBehavior? = nil, linkInvation:(()->Void)? = nil) {
        self.context = context
        self.defaultTitle = title
        self.confirmation = confirmation
        self.linkInvation = linkInvation
        self.behavior = behavior ?? SelectContactsBehavior(settings: settings, excludePeerIds: excludePeerIds, limit: limit)
        
        super.init(frame: NSMakeRect(0, 0, 360, 380))
        bar = .init(height: 0)
        completeDisposable.set((onComplete.get() |> take(1) |> deliverOnMainQueue).start(completed: { [weak self] in
            self?.close()
        }))
    }
    
    func confirmSelected(_ peerIds:[PeerId], _ peers:[Peer]) {
        let signal = context.account.postbox.transaction { transaction -> Void in
            updatePeers(transaction: transaction, peers: peers, update: { (_, updated) -> Peer? in
                return updated
            })
        } |> deliverOnMainQueue |> mapToSignal { [weak self] () -> Signal<[PeerId], NoError> in
            if let strongSelf = self {
                return strongSelf.confirmation(peerIds) |> filter {$0} |> map {  _ -> [PeerId] in
                    return peerIds
                }
            }
            return .complete()
        }
        onComplete.set(signal)
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if !interactions.presentation.peers.values.isEmpty {
            self.confirmSelected(Array(interactions.presentation.selected), Array(interactions.presentation.peers.values))
        }
        
        return .invoked
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: ModalHeaderData(image: theme.icons.modalClose, handler: {  [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: self.defaultTitle), right: nil)
    }
    
    override var modalInteractions: ModalInteractions? {
        if behavior.limit == 1 {
            return nil
        } else {
            return ModalInteractions(acceptTitle: L10n.modalOK, accept: { [weak self] in
                if let interactions = self?.interactions {
                   self?.confirmSelected(Array(interactions.presentation.selected), Array(interactions.presentation.peers.values))
                }
            }, drawBorder: true, height: 50, singleButton: true)
        }
    }
    

    deinit {
        disposable.dispose()
        interactions.remove(observer: self)
        completeDisposable.dispose()
        tokenDisposable.dispose()
    }
    
}


func selectModalPeers(context: AccountContext, title:String , settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT_MAX, behavior: SelectPeersBehavior? = nil, confirmation:@escaping ([PeerId]) -> Signal<Bool,NoError> = {_ in return .single(true) }, linkInvation:(()->Void)? = nil) -> Signal<[PeerId], NoError> {
    
    let modal = SelectPeersModalController(context: context, title: title, settings: settings, excludePeerIds: excludePeerIds, limit: limit, confirmation: confirmation, behavior: behavior, linkInvation: linkInvation)
    
    showModal(with: modal, for: context.window)
    
    
    return modal.onComplete.get() |> take(1)
    
}


