//
//  SelectPeersController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

enum SelectPeerEntryStableId : Hashable {
    case search
    case peerId(PeerId)
    case searchEmpty
    case separator(Int32)
    var hashValue: Int {
        switch self {
        case .search:
            return 0
        case .searchEmpty:
            return 1
        case .separator(let index):
            return Int(index)
        case let .peerId(peerId):
            return peerId.hashValue
        }
    }
    
    static func ==(lhs:SelectPeerEntryStableId, rhs:SelectPeerEntryStableId) -> Bool {
        switch lhs {
        case .search:
            if case .search = rhs {
                return true
            } else {
                return false
            }
        case .searchEmpty:
            if case .searchEmpty = rhs {
                return true
            } else {
                return false
            }
        case let .peerId(peerId):
            if case .peerId(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .separator(index):
            if case .separator(index) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

enum SelectPeerEntry : Comparable, Identifiable {
    case peer(Peer, Int32, PeerPresence?, Bool)
    case searchEmpty
    case separator(Int32, String)
    var stableId: SelectPeerEntryStableId {
        switch self {
        case .searchEmpty:
            return .searchEmpty
        case .separator(let index, _):
            return .separator(index)
        case let .peer(peer, _, _, _):
            return .peerId(peer.id)
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
        case let .peer(lhsPeer, lhsIndex, lhsPresence, lhsEnabled):
            switch rhs {
            case let .peer(rhsPeer, rhsIndex, rhsPresence, rhsEnabled) where lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex && lhsEnabled == rhsEnabled:
                if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                    return lhsPresence.isEqual(to: rhsPresence)
                } else if (lhsPresence != nil) != (rhsPresence != nil) {
                    return false
                }
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
        case .separator(let index, _):
            return index
        case .peer(_, let index, _, _):
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
                    if let character = f.characters.first {
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

private func entriesForView(_ view: ContactPeersView, searchPeers:[PeerId], searchView:MultiplePeersView, excludeIds:[PeerId] = []) -> [SelectPeerEntry] {
    var entries: [SelectPeerEntry] = []
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
                entries.append(.peer(peer,index,searchView.presences[peer.id], !excludeIds.contains(peer.id)))
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
                entries.append(.peer(peer,index,view.peerPresences[peer.id], !excludeIds.contains(peer.id)))
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

private func searchEntriesForPeers(_ peers:[Peer], account:Account, view:MultiplePeersView, isLoading: Bool, excludeIds:[PeerId] = []) -> [SelectPeerEntry] {
    var entries: [SelectPeerEntry] = []
    
    var index:Int32 = 0
    for peer in peers {
        if account.peerId != peer.id {
            if let peer = peer as? TelegramUser, let botInfo = peer.botInfo {
                if !botInfo.flags.contains(.worksWithGroups) {
                    continue
                }
            }
            entries.append(.peer(peer,index,view.presences[peer.id], !excludeIds.contains(peer.id)))
            index += 1
        }
    }
    
    if entries.count == 1 && !isLoading {
        entries.append(.searchEmpty)
    }

    return entries
}

fileprivate func prepareEntries(from:[SelectPeerEntry]?, to:[SelectPeerEntry], account:Account, initialSize:NSSize, animated:Bool, interactions:SelectPeerInteraction, singleAction:((Peer)->Void)? = nil) -> TableUpdateTransition {
    let (deleted,inserted,updated) =  proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
        
        var item:TableRowItem
        
        switch entry {
        case let .peer(peer, _, presence, enabled):
            
            var color:NSColor = theme.colors.grayText
            var string:String = tr(L10n.peerStatusRecently)
            if let presence = presence as? TelegramUserPresence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string, _, color) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
            }
            if peer.isBot {
                string = L10n.presenceBot.lowercased()
            }
            
            let interactionType:ShortPeerItemInteractionType
            if singleAction != nil {
                interactionType = .plain
            } else {
                interactionType = .selectable(interactions)
            }
            
            item = ShortPeerRowItem(initialSize, peer: peer, account: account, stableId: entry.stableId, enabled: enabled, statusStyle: ControlStyle(foregroundColor:color), status: string, inset:NSEdgeInsets(left: 10, right:10), interactionType:interactionType, action: {
                if let singleAction = singleAction {
                    singleAction(peer)
                }
            })
        case .searchEmpty:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId)
        case .separator(_, let text):
            return SeparatorRowItem(initialSize, entry.stableId, string: text.uppercased())
        }
        
        let _ = item.makeSize(initialSize.width)
        
        return item
  
    })
    
    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated)
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
    
    public static let remote = SelectPeerSettings(rawValue: 1)
    public static let contacts = SelectPeerSettings(rawValue: 2)
    public static let excludeBots = SelectPeerSettings(rawValue: 4)
}

class SelectPeersBehavior {
    var result:[PeerId:TemporaryPeer] {
        return _peersResult.modify({$0})
    }
    
    fileprivate let _peersResult:Atomic<[PeerId:TemporaryPeer]> = Atomic(value: [:])
    
    
    fileprivate let inSearchSelected:Atomic<[PeerId]> = Atomic(value:[])
    
    fileprivate let settings:SelectPeerSettings
    fileprivate let excludePeerIds:[PeerId]
    fileprivate let limit:Int32
    
    init(settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX) {
        self.settings = settings
        self.excludePeerIds = excludePeerIds
        self.limit = limit
    }
    
    
    func start(account: Account, search:Signal<SearchState, Void>) -> Signal<[SelectPeerEntry], Void> {
        return .complete()
    }

}

class SelectChannelMembersBehavior : SelectPeersBehavior {
    fileprivate let peerId:PeerId
    private let _renderedResult:Atomic<[PeerId:RenderedChannelParticipant]> = Atomic(value: [:])    

    var participants:[PeerId:RenderedChannelParticipant] {
        return _renderedResult.modify({$0})
    }

    init(peerId:PeerId, limit: Int32 = .max, settings: SelectPeerSettings = [.remote]) {
        self.peerId = peerId
        super.init(settings: settings, limit: limit)
    }
    
    override func start(account: Account, search: Signal<SearchState, Void>) -> Signal<[SelectPeerEntry], Void> {
        let peerId = self.peerId
        let _renderedResult = self._renderedResult
        let _peersResult = self._peersResult
        let settings = self.settings
        return search |> map {SearchState(state: .Focus, request: $0.request)} |> distinctUntilChanged |> mapToSignal { search -> Signal<[SelectPeerEntry], Void> in
            
            let filter:ChannelMembersCategoryFilter
            
            if !search.request.isEmpty {
                filter = .search(search.request)
            } else {
                filter = .all
            }
            
            let participantsSignal:Signal<[RenderedChannelParticipant]?, Void> = channelMembers(postbox: account.postbox, network: account.network, peerId: peerId, category: .recent(filter)) |> map {_ = _renderedResult.swap(($0 ?? []).reduce([:], { current, participant in
                var current = current
                current[participant.peer.id] = participant
                return current
            })); return $0}
            
            let foundLocalPeers = account.postbox.searchContacts(query: search.request.lowercased())
            
            let foundRemotePeers:Signal<([Peer], [Peer], Bool), Void> = .single(([], [], true)) |> then ( searchPeers(account: account, query: search.request.lowercased()) |> map {($0.map{$0.peer}, $1.map{$0.peer}, false)} )
            
            
            let contactsSearch: Signal<([TemporaryPeer], [TemporaryPeer], Bool), Void>
            
            if settings.contains(.remote) {
                contactsSearch = combineLatest(foundLocalPeers, foundRemotePeers) |> map { values -> ([Peer], [Peer], Bool) in
                    return (values.0 + values.1.0, values.1.1, values.1.2 && search.request.length >= 5)
                    }
                    |> mapToSignal { values -> Signal<([Peer], [Peer], MultiplePeersView, Bool), Void> in
                        return account.postbox.multiplePeersView(values.0.map {$0.id}) |> take(1) |> map { views in
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
                return combineLatest(participantsSignal, contactsSearch) |> map { participants, peers in
                    return channelMembersEntries(participants ?? [], users: peers.0, remote: peers.1, account: account, isLoading: participants == nil && peers.2)
                }
            } else {
                return participantsSignal |> map { participants in
                    return channelMembersEntries(participants ?? [], account: account, isLoading: participants == nil)
                }
            }
        }
    }
    
    deinit {
        _ = _renderedResult.swap([:])
    }
}

private func channelMembersEntries(_ participants:[RenderedChannelParticipant], users:[TemporaryPeer]? = nil, remote:[TemporaryPeer] = [], account:Account, isLoading: Bool) -> [SelectPeerEntry] {
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
            if account.peerId != participant.peer.id {
                entries.append(.peer(participant.peer, index, participant.presences[participant.peer.id], true))
                index += 1
            }
        }
    }
    if let users = users, !users.isEmpty {
        entries.append(.separator(index, tr(L10n.channelSelectPeersContacts)))
        index += 1
        for peer in users {
            if account.peerId != peer.peer.id {
                entries.append(.peer(peer.peer, index, peer.presence, true))
                index += 1
            }
        }
    }
    
    if !remote.isEmpty {
        entries.append(.separator(index, tr(L10n.channelSelectPeersGlobal)))
        index += 1
        for peer in remote {
            if account.peerId != peer.peer.id {
                entries.append(.peer(peer.peer, index, peer.presence, true))
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
    override func start(account: Account, search: Signal<SearchState, Void>) -> Signal<[SelectPeerEntry], Void> {
        return search |> distinctUntilChanged |> mapToSignal { search -> Signal<[SelectPeerEntry], Void> in
            
            if search.request.isEmpty {
                return account.viewTracker.tailChatListView(groupId: nil, count: 200) |> deliverOn(prepareQueue) |> mapToQueue {  value -> Signal<[SelectPeerEntry], Void> in
                    var entries:[Peer] = []
                    

                    for entry in value.0.entries.reversed() {
                        switch entry {
                        case let .MessageEntry(_, _, _, _, _, renderedPeer, _):
                            if let peer = renderedPeer.chatMainPeer, peer.canSendMessage, peer.canInviteUsers, peer.isSupergroup || peer.isGroup {
                                entries.append(peer)
                            }
                        default:
                            break
                        }
                    }
                    
                    var common:[SelectPeerEntry] = []
                    
                    if entries.isEmpty {
                        common.append(.searchEmpty)
                    } else {
                        var index:Int32 = 0
                        for peer in entries {
                            common.append(.peer(peer, index, nil, true))
                            index += 1
                        }
                        
                    }
                    return .single(common)
                }
            } else {
                return  account.postbox.searchPeers(query: search.request.lowercased(), groupId: nil) |> map {
                    return $0.compactMap({$0.chatMainPeer}).filter {($0.isSupergroup || $0.isGroup) && $0.canInviteUsers}
                } |> deliverOn(prepareQueue) |> map { entries -> [SelectPeerEntry] in
                    var common:[SelectPeerEntry] = []
                    
                    if entries.isEmpty {
                        common.append(.searchEmpty)
                    } else {
                        var index:Int32 = 0
                        for peer in entries {
                            common.append(.peer(peer, index, nil, true))
                            index += 1
                        }
                        
                    }
                    return common
                }
            }
            
        }

    }
}

fileprivate class SelectContactsBehavior : SelectPeersBehavior {
    fileprivate let index: PeerNameIndex = .lastNameFirst
    
   
    override func start(account: Account, search:Signal<SearchState, Void>) -> Signal<[SelectPeerEntry], Void> {
        
        return search |> mapToSignal { [weak self] search -> Signal<[SelectPeerEntry], Void> in
            
            let settings = self?.settings ?? SelectPeerSettings()
            let excludePeerIds = (self?.excludePeerIds ?? [])
            
            if search.request.isEmpty {
                let inSearch:[PeerId] = self?.inSearchSelected.modify({$0}) ?? []
                return combineLatest(account.postbox.contactPeersView(accountPeerId: account.peerId, includePresences: true), account.postbox.multiplePeersView(inSearch))
                    |> deliverOn(prepareQueue)
                    |> mapToQueue { view, searchView -> Signal<[SelectPeerEntry], Void> in
                        return .single(entriesForView(view, searchPeers: inSearch, searchView: searchView, excludeIds: excludePeerIds))
                }
                
            } else  {
                
                let foundLocalPeers = account.postbox.searchContacts(query: search.request.lowercased())
                
                let foundRemotePeers:Signal<([Peer], [Peer], Bool), Void> = settings.contains(.remote) ? .single(([], [], true)) |> then ( searchPeers(account: account, query: search.request.lowercased()) |> map {($0.map{$0.peer}, $1.map{$0.peer}, false)} ) : .single(([], [], false))
                
                return combineLatest(foundLocalPeers, foundRemotePeers) |> map { values -> ([Peer], Bool) in
                    return (uniquePeers(from: (values.0 + values.1.0 + values.1.1)), values.1.2 && search.request.length >= 5)
                }
                    |> runOn(prepareQueue)
                    |> mapToSignal { values -> Signal<[SelectPeerEntry], Void> in
                        var values = values
                        if settings.contains(.excludeBots) {
                            values.0 = values.0.filter {!$0.isBot}
                        }
                        values.0 = values.0.filter {!$0.isChannel && !$0.isSupergroup && !$0.isGroup}
                        return account.postbox.multiplePeersView(values.0.map {$0.id}) |> take(1) |> map { view -> [SelectPeerEntry] in
                            return searchEntriesForPeers(values.0, account: account, view: view, isLoading: values.1, excludeIds: excludePeerIds)
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
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
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
            
            for item in added {
                genericView.tokenView.addToken(token: SearchToken(name: value.peers[item]?.compactDisplayTitle ?? tr(L10n.peerDeletedUser), uniqueId: item.toInt64()), animated: animated)
            }
            
            for item in removed {
                genericView.tokenView.removeToken(uniqueId: item.toInt64(), animated: animated)
            }
            
            self.nextEnabled(!value.selected.isEmpty)
            
            
            
            if let limits = limitsConfiguration {
                let attributed = NSMutableAttributedString()
                _ = attributed.append(string: L10n.telegramSelectPeersController, color: theme.colors.text, font: .medium(.title))
                _ = attributed.append(string: "   ")
                _ = attributed.append(string: "\(interactions.presentation.selected.count)/\(limits.maxSupergroupMemberCount)", color: theme.colors.grayText, font: .normal(.title))
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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.nextEnabled(false)

        let account = self.account
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
        
        let limitsSignal:Signal<LimitsConfiguration?, Void> = isNewGroup ? account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration]) |> map { values -> LimitsConfiguration? in
            return values.values[PreferencesKeys.limitsConfiguration] as? LimitsConfiguration
        } : .single(nil)
        
        
        let transition = combineLatest(behavior.start(account: account, search: search.get() |> distinctUntilChanged |> map {SearchState(state: .None, request: $0)}) |> deliverOn(prepareQueue), limitsSignal |> deliverOnPrepareQueue) |> map { entries, limits -> (TableUpdateTransition, LimitsConfiguration?) in
            return (prepareEntries(from: previous.swap(entries), to: entries, account: account, initialSize: initialSize.modify({$0}), animated: true, interactions:interactions), limits)
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition, limits in
            self?.genericView.tableView.merge(with: transition)
            self?.limitsConfiguration = limits
            self?.readyOnce()
        }))
    }
    
    
    
    var tokenView:TokenizedView {
        return genericView.tokenView
    }
    
    
    init(titles: ComposeTitles, account: Account, settings:SelectPeerSettings = [.contacts], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX, isNewGroup: Bool = false) {
        self.behavior = SelectContactsBehavior(settings: settings, excludePeerIds: excludePeerIds, limit: limit)
        self.isNewGroup = isNewGroup
        super.init(titles: titles, account: account)
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
        needsLayout = true
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        separatorView.backgroundColor = theme.colors.border
    }
    
    
    fileprivate override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 50, frame.width  , frame.height - 50)
        tokenView.frame = NSMakeRect(10, 10, frame.width - 20, frame.height - 50)
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
    private let account:Account
    private let defaultTitle:String
    private let confirmation:([PeerId])->Signal<Bool,Void>
    fileprivate let onComplete:Promise<[PeerId]> = Promise()
    private let completeDisposable = MetaDisposable()
    private let tokenDisposable = MetaDisposable()
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            if behavior.limit > 1 {
                
                let added = value.selected.subtracting(oldValue.selected)
                let removed = oldValue.selected.subtracting(value.selected)
                
                for item in added {
                    genericView.tokenView.addToken(token: SearchToken(name: value.peers[item]?.compactDisplayTitle ?? tr(L10n.peerDeletedUser), uniqueId: item.toInt64()), animated: animated)
                }
                
                for item in removed {
                    genericView.tokenView.removeToken(uniqueId: item.toInt64(), animated: animated)
                }
                
                
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
        
        let account = self.account
        let interactions = self.interactions
        let initialSize = atomicSize
        
        
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
                
                _ = (self?.account.postbox.transaction { transaction -> Void in
                    updatePeers(transaction: transaction, peers: [peer], update: { _, updated -> Peer? in
                        return updated
                    })
                })?.start()
                self?.confirmSelected([peer.id], [peer])
            }
        }
        
        let transition = behavior.start(account: account, search: search.get() |> distinctUntilChanged) |> deliverOn(prepareQueue) |> map { entries -> TableUpdateTransition in
            return prepareEntries(from: previous.swap(entries), to: entries, account: account, initialSize: initialSize.modify({$0}), animated: true, interactions:interactions, singleAction: singleAction)
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            self?.readyOnce()
        }))
    }
    
    
    init(account: Account, title:String, settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX, confirmation:@escaping([PeerId])->Signal<Bool,Void>, behavior: SelectPeersBehavior? = nil) {
        self.account = account
        self.defaultTitle = title
        self.confirmation = confirmation
        self.behavior = behavior ?? SelectContactsBehavior(settings: settings, excludePeerIds: excludePeerIds, limit: limit)
        
        super.init(frame: NSMakeRect(0, 0, 360, 380))
        bar = .init(height: 0)
        completeDisposable.set((onComplete.get() |> take(1) |> deliverOnMainQueue).start(completed: { [weak self] in
            self?.close()
        }))
    }
    
    func confirmSelected(_ peerIds:[PeerId], _ peers:[Peer]) {
        let signal = account.postbox.transaction { transaction -> Void in
            updatePeers(transaction: transaction, peers: peers, update: { (_, updated) -> Peer? in
                return updated
            })
        } |> deliverOnMainQueue |> mapToSignal { [weak self] () -> Signal<[PeerId], Void> in
            if let strongSelf = self {
                return strongSelf.confirmation(peerIds) |> filter {$0} |> map {  _ -> [PeerId] in
                    return peerIds
                }
            }
            return .complete()
        }
        onComplete.set(signal)
    }
    
    override var modalInteractions: ModalInteractions? {
        if behavior.limit == 1 {
            return ModalInteractions(acceptTitle: tr(L10n.modalCancel), drawBorder: true, height: 40)
        } else {
            return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
                if let interactions = self?.interactions {
                   self?.confirmSelected(Array(interactions.presentation.selected), Array(interactions.presentation.peers.values))
                }
            }, cancelTitle: tr(L10n.modalCancel), drawBorder: true, height: 40)
        }
    }
    

    deinit {
        disposable.dispose()
        interactions.remove(observer: self)
        completeDisposable.dispose()
        tokenDisposable.dispose()
    }
    
}


func selectModalPeers(account:Account, title:String , settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT_MAX, behavior: SelectPeersBehavior? = nil, confirmation:@escaping ([PeerId]) -> Signal<Bool,Void> = {_ in return .single(true) }) -> Signal<[PeerId], Void> {
    
    let modal = SelectPeersModalController(account: account, title: title, settings: settings, excludePeerIds: excludePeerIds, limit: limit, confirmation: confirmation, behavior: behavior)
    
    showModal(with: modal, for: mainWindow)
    
    
    return modal.onComplete.get() |> take(1)
    
}


