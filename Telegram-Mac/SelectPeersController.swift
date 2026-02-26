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

import Postbox
import SwiftSignalKit
import Localization

enum SelectPeerEntryStableId : Hashable {
    case search
    case peerId(PeerId, Int32)
    case searchEmpty
    case requirements
    case separator(Int32)
    case inviteLink(Int)
    case empty
}

enum SelectPeerEntry : Comparable, Identifiable {
    case peer(SelectPeerValue, Int32, Bool)
    case searchEmpty(GeneralRowItem.Theme, CGImage)
    case empty(GeneralRowItem.Theme, InputDataEquatable?, (NSSize, AnyHashable)->TableRowItem)
    case separator(Int32, GeneralRowItem.Theme, String)
    case actionButton(String, CGImage, Int, GeneralRowItem.Theme, (Int)->Void, Bool, NSColor)
    case requirements(NSAttributedString)
    var stableId: SelectPeerEntryStableId {
        switch self {
        case .searchEmpty:
            return .searchEmpty
        case .requirements:
            return .requirements
        case .empty:
            return .empty
        case .separator(let index, _, _):
            return .separator(index)
        case let .peer(peer, index, _):
            return .peerId(peer.peer.id, index)
        case let .actionButton(_, _, index, _, _, _, _):
            return .inviteLink(index)
        }
    }
    
    static func ==(lhs:SelectPeerEntry, rhs:SelectPeerEntry) -> Bool {
        switch lhs {
        case let .searchEmpty(theme, _):
            if case .searchEmpty(theme, _) = rhs {
                return true
            } else {
                return false
            }
        case let .empty(theme, equatable, _):
            if case .empty(theme, equatable, _) = rhs {
                return true
            } else {
                return false
            }
        case let .requirements(string):
            if case .requirements(string) = rhs {
                return true
            } else {
                return false
            }
        case let .separator(index, customTheme, text):
            if case .separator(index, customTheme, text) = rhs {
                return true
            } else {
                return false
            }
        case let .actionButton(text, image, index, customTheme, _, _, _):
            if case .actionButton(text, image, index, customTheme, _, _, _) = rhs {
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
        case .empty:
            return 0
        case .searchEmpty:
            return 1
        case .actionButton:
            return -1
        case .requirements:
            return -2
        case .separator(let index, _, _):
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
    let customTheme: GeneralRowItem.Theme?
    let ignoreStatus: Bool
    let isLookSavedMessage: Bool
    let savedStatus: String?
    let selectLeft: Bool
    let passLeftAction: Bool
    let rightActions:ShortPeerRowItem.RightActions
    init(peer: Peer, presence: PeerPresence?, subscribers: Int?, customTheme: GeneralRowItem.Theme? = nil, ignoreStatus: Bool = false, isLookSavedMessage: Bool = true, savedStatus: String? = nil, selectLeft: Bool = false, passLeftAction: Bool = false, rightActions:ShortPeerRowItem.RightActions = .init()) {
        self.peer = peer
        self.presence = presence
        self.subscribers = subscribers
        self.customTheme = customTheme
        self.ignoreStatus = ignoreStatus
        self.isLookSavedMessage = isLookSavedMessage
        self.savedStatus = savedStatus
        self.selectLeft = selectLeft
        self.passLeftAction = passLeftAction
        self.rightActions = rightActions
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
        if lhs.ignoreStatus != rhs.ignoreStatus {
            return false
        }
        
        if lhs.subscribers != rhs.subscribers {
            return false
        }
        if lhs.customTheme != rhs.customTheme {
            return false
        }
        if lhs.savedStatus != rhs.savedStatus {
            return false
        }
        if lhs.isLookSavedMessage != rhs.isLookSavedMessage {
            return false
        }
        if lhs.selectLeft != rhs.selectLeft {
            return false
        }
        if lhs.passLeftAction != rhs.passLeftAction {
            return false
        }
        if lhs.rightActions != rhs.rightActions {
            return false
        }
        return true
    }
    
    func status(_ account: Account) -> (String?, NSColor) {
        
        let difference: TimeInterval
        if account.network.globalTime > 0 {
            difference =  floor(account.network.globalTime - Date().timeIntervalSince1970)
        } else {
            difference = 0
        }
        
        var color:NSColor = customTheme?.grayTextColor ?? theme.colors.grayText
        var string:String = strings().peerStatusLongTimeAgo
        
        if let count = subscribers, peer.isGroup || peer.isSupergroup {
            let countValue = strings().privacySettingsGroupMembersCountCountable(count)
            string = countValue.replacingOccurrences(of: "\(count)", with: count.separatedNumber)
        } else if peer.isGroup || peer.isSupergroup || peer.isChannel {
            return (nil, color)
        } else if let presence = presence as? TelegramUserPresence {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: difference, relativeTo: Int32(timestamp), customTheme: customTheme)
        } else {
            if let addressName = peer.addressName {
                color = customTheme?.accentColor ?? theme.colors.accent
                string = "@\(addressName)"
            }
        }
        if peer.isBot {
            string = strings().presenceBot.lowercased()
            if let addressName = peer.addressName {
                color = customTheme?.accentColor ?? theme.colors.accent
                string = "@\(addressName)" + " (\(string))"
            }
        }
        if ignoreStatus {
            return (nil, customTheme?.grayTextColor ?? theme.colors.grayText)
        }
        return (string, color)
    }
}

private func entriesForView(_ view: EngineContactList, accountPeer: Peer?, searchPeers:[PeerId], searchView:MultiplePeersView, recentPeers: RecentPeers? = nil, excludeIds:[PeerId] = [], blocks: [SelectPeersBlock] = [], defaultSelected: [PeerId] = [], linkInvation: ((Int)->Void)? = nil, theme: GeneralRowItem.Theme, additionTopItem: SelectPeers_AdditionTopItem? = nil, isLookSavedMessage: Bool = true, savedStatus: String? = nil) -> [SelectPeerEntry] {
    var entries: [SelectPeerEntry] = []
    
    if let linkInvation = linkInvation {
        let icon = NSImage(named: "Icon_InviteViaLink")!.precomposed(theme.accentColor, flipVertical: true)
        entries.append(SelectPeerEntry.actionButton(strings().peerSelectInviteViaLink, icon, 0, theme, linkInvation, true, theme.accentColor))
    }
    if let item = additionTopItem {
        entries.append(SelectPeerEntry.actionButton(item.title, item.icon, 0, theme, { _ in
            item.callback()
        }, false, item.color))
    }
        
    var index:Int32 = 0
    
    if let accountPeer = accountPeer {
        let searchPeers = searchView.peers.map { $0.value }.filter { !$0.isDeleted }.sorted(by: <)
        var peers = view.peers.map { $0._asPeer() }.filter { !$0.isDeleted }.sorted(by: <)
        
        let allPeers = peers + [accountPeer]

        
        var isset:[PeerId:PeerId] = [:]
        for peer in searchPeers {
            if isset[peer.id] == nil {
                isset[peer.id] = peer.id
                if let peer = peer as? TelegramUser, let botInfo = peer.botInfo {
                    if !botInfo.flags.contains(.worksWithGroups) {
                        continue
                    }
                }
                
                entries.append(.peer(SelectPeerValue(peer: peer, presence: searchView.presences[peer.id], subscribers: nil, customTheme: theme, isLookSavedMessage: isLookSavedMessage, savedStatus: savedStatus), index, !excludeIds.contains(peer.id)))
                index += 1
            }
        }
        
        if !blocks.isEmpty {
            for block in blocks {
                let found = allPeers.filter({ block.peerIds.contains($0.id) })
                if !found.isEmpty {
                    entries.append(.separator(index, theme, block.separator))
                    index += 1
                    for peer in found {
                        if isset[peer.id] == nil {
                            isset[peer.id] = peer.id
                            entries.append(.peer(SelectPeerValue(peer: peer, presence: view.presences[peer.id]?._asPresence(), subscribers: nil, customTheme: theme, isLookSavedMessage: isLookSavedMessage, savedStatus: savedStatus), index, !excludeIds.contains(peer.id)))
                            index += 1
                        }
                    }
                }
            }
        }
        
        if !defaultSelected.isEmpty {
            let found = peers.filter({ defaultSelected.contains($0.id) })
            for peer in found {
                if isset[peer.id] == nil {
                    isset[peer.id] = peer.id
                    entries.append(.peer(SelectPeerValue(peer: peer, presence: view.presences[peer.id]?._asPresence(), subscribers: nil, customTheme: theme, isLookSavedMessage: isLookSavedMessage, savedStatus: savedStatus), index, !excludeIds.contains(peer.id)))
                    index += 1
                }
            }
        }
        
        if let recentPeers = recentPeers {
            switch recentPeers {
            case let .peers(recent):
                let recent = recent.filter({
                    isset[$0.id] == nil
                })
                if !recent.isEmpty {
                    entries.append(.separator(index, theme, strings().selectPeersFrequent))
                    for peer in recent {
                        if !peer.isEqual(accountPeer) {
                            isset[peer.id] = peer.id
                            entries.append(.peer(SelectPeerValue(peer: peer, presence: view.presences[peer.id]?._asPresence(), subscribers: nil, customTheme: theme, isLookSavedMessage: isLookSavedMessage, savedStatus: savedStatus), index, !excludeIds.contains(peer.id)))
                            index += 1
                        }
                    }
                    peers = peers.filter({
                        isset[$0.id] == nil
                    })
                    if !peers.isEmpty {
                        entries.append(.separator(index, theme, strings().selectPeersContacts))
                    }
                }
            default:
                break
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
                
                entries.append(.peer(SelectPeerValue(peer: peer, presence: view.presences[peer.id]?._asPresence(), subscribers: nil, customTheme: theme, isLookSavedMessage: isLookSavedMessage, savedStatus: savedStatus), index, !excludeIds.contains(peer.id)))
                index += 1
            }
        }

    }
    
    if entries.isEmpty {
        entries.append(.searchEmpty(.init(), NSImage(named: "Icon_EmptySearchResults")!.precomposed(theme.grayTextColor)))
    }
    
    return entries
}

private func searchEntriesForPeers(_ peers:[SelectPeerValue], _ global: [SelectPeerValue], account: Account, isLoading: Bool, excludeIds:Set<PeerId> = Set()) -> [SelectPeerEntry] {
    var entries: [SelectPeerEntry] = []
    
    var excludeIds = excludeIds
    var index:Int32 = 0
    for peer in peers {
        if account.peerId != peer.peer.id {
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
            if account.peerId != peer.peer.id, !excludeIds.contains(peer.peer.id) {
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
            entries.append(.separator(index, GeneralRowItem.Theme(), strings().searchSeparatorGlobalPeers))
            index += 1
            
        }
        
        for peer in global {
            entries.append(.peer(peer, index, !excludeIds.contains(peer.peer.id)))
            excludeIds.insert(peer.peer.id)
            index += 1
        }
    }
    
    if entries.isEmpty && !isLoading {
        entries.append(.searchEmpty(.init(), theme.icons.emptySearch))
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
                    interactionType = .selectable(interactions, side: peer.selectLeft ? .left : .right)
                }
                
                var (status, color) = peer.status(context.account)
                
                status = peer.peer.id == context.peerId ? peer.savedStatus ?? status : status
                color = peer.peer.id == context.peerId  && peer.savedStatus != nil ? theme.colors.grayText : color
                item = ShortPeerRowItem(initialSize, peer: peer.peer, account: context.account, context: context, stableId: entry.stableId, enabled: enabled, height: 42, photoSize: NSMakeSize(32, 32), titleStyle: ControlStyle(font: .medium(.title), foregroundColor: peer.customTheme?.textColor ?? theme.colors.text, highlightColor: .white), statusStyle: ControlStyle(foregroundColor: color), status: status, isLookSavedMessage: peer.isLookSavedMessage, drawLastSeparator: true, inset: NSEdgeInsets(left: 10, right:10), drawSeparatorIgnoringInset: true, interactionType:interactionType, action: {
                    if let singleAction = singleAction {
                        singleAction(peer.peer)
                    }
                }, highlightVerified: true, customTheme: peer.customTheme, passLeftAction: peer.passLeftAction, rightActions: peer.rightActions)
            case let .searchEmpty(theme, icon):
                return SearchEmptyRowItem(initialSize, stableId: entry.stableId, icon: icon, customTheme: theme)
            case let .empty(_, _, callback):
                return callback(initialSize, entry.stableId)
            case let .separator(_, customTheme, text):
                return SeparatorRowItem(initialSize, entry.stableId, string: text.uppercased(), customTheme: customTheme)
            case let .actionButton(text, image, index, customTheme, action, close, color):
                let style = ControlStyle(font: .normal(.title), foregroundColor: color)
                return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: text, nameStyle: style, type: .none, action: {
                    action(index)
                    if close {
                        interactions.close()
                    }
                }, drawCustomSeparator: false, thumb: GeneralThumbAdditional(thumb: image, textInset: 41), inset: NSEdgeInsetsMake(0, 6, 0, 0), customTheme: customTheme)
            case let .requirements(string):
                return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: string, border: [.Top], inset: NSEdgeInsets(left: 10, right: 10, top: 0, bottom: 4))
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
    
    
    public static let remote = SelectPeerSettings(rawValue: 1 << 1)
    public static let contacts = SelectPeerSettings(rawValue: 1 << 2)
    public static let groups = SelectPeerSettings(rawValue: 1 << 3)
    public static let excludeBots = SelectPeerSettings(rawValue: 1 << 4)
    public static let channels = SelectPeerSettings(rawValue: 1 << 5)
    public static let bots = SelectPeerSettings(rawValue: 1 << 6)
    public static let checkInvite = SelectPeerSettings(rawValue: 1 << 7)
    
}

class SelectPeersBehavior {
    var result:[PeerId:TemporaryPeer] {
        return _peersResult.modify({$0})
    }
    
    fileprivate let _peersResult:Atomic<[PeerId:TemporaryPeer]> = Atomic(value: [:])
    
    var participants:[PeerId:RenderedChannelParticipant] {
        return [:]
    }
    
    var okTitle: String? {
        return nil
    }
    
    fileprivate let inSearchSelected:Atomic<[PeerId]> = Atomic(value:[])
    
    fileprivate let settings:SelectPeerSettings
    fileprivate let excludePeerIds:[PeerId]
    let limit:Int32
    let customTheme:()->GeneralRowItem.Theme
    init(settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX, customTheme: @escaping()->GeneralRowItem.Theme = { GeneralRowItem.Theme() }) {
        self.settings = settings
        self.excludePeerIds = excludePeerIds
        self.limit = limit
        self.customTheme = customTheme
    }
    
    func limitReached() {
        NSSound.beep()
    }
    
    func filterPeer(_ peer: Peer) -> Bool {
        
        if excludePeerIds.contains(peer.id) {
            return false
        }
        if peer.isGroup || peer.isSupergroup || peer.isGigagroup {
            if settings.contains(.groups) {
                return !settings.contains(.checkInvite) || peer.canInviteUsers
            }
        }
        
        if peer.isUser, !peer.isBot {
            if settings.contains(.contacts) {
                return true
            }
            
        }
        if peer.isChannel {
            if settings.contains(.channels) {
                return !settings.contains(.checkInvite) || peer.canInviteUsers
            }
        }
        if peer.isBot {
            if settings.contains(.bots) {
                return true
            }
        }
        return false
    }
    
    func makeEntries(_ peers: [Peer], _ presence: [PeerId: PeerPresence], isSearch: Bool) -> [SelectPeerEntry] {
        var entries: [SelectPeerEntry] = []
       
        var index:Int32 = 0
        for value in peers {
            if filterPeer(value) {
                entries.append(.peer(SelectPeerValue(peer: value, presence: presence[value.id], subscribers: nil, ignoreStatus: true), index, true))
                index += 1
            }
        }
        
        if entries.isEmpty {
            entries.append(.searchEmpty(.init(), theme.icons.emptySearch))
        }
        return entries
    }
    
    
    func start(context: AccountContext, search:Signal<SearchState, NoError>, linkInvation: ((Int)->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
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
    
    override func start(context: AccountContext, search: Signal<SearchState, NoError>, linkInvation: ((Int)->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        let peerId = self.peerId
        let _renderedResult = self._renderedResult
        let account = context.account

        let previousSearch =  Atomic<String?>(value: nil)
        
        return search |> map { SearchState(state: .Focus, request: $0.request) } |> distinctUntilChanged |> mapToSignal { search -> Signal<([SelectPeerEntry], Bool), NoError>  in
            
            let participantsPromise: Promise<[RenderedChannelParticipant]> = Promise()
            
            
            let viewKey = PostboxViewKey.peer(peerId: peerId, components: .all)
            
            participantsPromise.set(account.postbox.combinedView(keys: [viewKey]) |> map { combinedView in
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
                                    rendered = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(rights: .internal_groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == account.peerId), banInfo: nil, rank: nil, subscriptionUntilDate: nil), peer: peer, peers: peers)
                                case .member:
                                    var peers: [PeerId: Peer] = [:]
                                    peers[creator.id] = creator
                                    peers[peer.id] = peer
                                    rendered = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil, subscriptionUntilDate: nil), peer: peer, peers: peers)
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
                return (channelMembersEntries(participants, users: [], remote: [], account: account, isLoading: false), updatedSearch)
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
    private let peerChannelMemberContextsManager: PeerChannelMemberCategoriesContextsManager
    private let loadDisposable = MetaDisposable()
    var additionTopItem:SelectPeers_AdditionTopItem?

    override var participants:[PeerId:RenderedChannelParticipant] {
        return _renderedResult.modify({$0})
    }

    init(peerId:PeerId, peerChannelMemberContextsManager: PeerChannelMemberCategoriesContextsManager, limit: Int32 = .max, settings: SelectPeerSettings = [.remote], additionTopItem:SelectPeers_AdditionTopItem? = nil) {
        self.peerId = peerId
        self.peerChannelMemberContextsManager = peerChannelMemberContextsManager
        self.additionTopItem = additionTopItem
        super.init(settings: settings, limit: limit)
    }
    
    override func start(context: AccountContext, search: Signal<SearchState, NoError>, linkInvation: ((Int)->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        let peerId = self.peerId
        let _renderedResult = self._renderedResult
        let _peersResult = self._peersResult
        let settings = self.settings
        let loadDisposable = self.loadDisposable
        let account = context.account
        let peerChannelMemberContextsManager = self.peerChannelMemberContextsManager
        let previousSearch = Atomic<String?>(value: nil)
        let additionTopItem = self.additionTopItem

        return search |> mapToSignal { query -> Signal<SearchState, NoError> in
            if query.request.isEmpty {
                return .single(query)
            } else {
                return .single(query) |> delay(0.2, queue: .mainQueue())
            }
        } |> map { SearchState(state: .Focus, request: $0.request) } |> distinctUntilChanged |> mapToSignal { search -> Signal<([SelectPeerEntry], Bool), NoError> in
            
            let participantsPromise: Promise<[RenderedChannelParticipant]> = Promise()
            
            var isListLoading: Bool = false
            
            let value = peerChannelMemberContextsManager.recent(peerId: peerId, searchQuery: search.request.isEmpty ? nil : search.request, requestUpdate: true, updated: { state in
                
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

            let foundLocalPeers = account.postbox.searchContacts(query: search.request.lowercased())
            
            let foundRemotePeers:Signal<([Peer], [Peer], Bool), NoError> = context.engine.contacts.searchRemotePeers(query: search.request.lowercased()) |> map {($0.map{$0.peer}, $1.map{$0.peer}, false)}
            
            
            let contactsSearch: Signal<([TemporaryPeer], [TemporaryPeer], Bool), NoError>
            
            if settings.contains(.remote) {
                contactsSearch = combineLatest(foundLocalPeers |> map {$0.0}, foundRemotePeers) |> map { values -> ([Peer], [Peer], Bool) in
                    return (values.0 + values.1.0, values.1.1, values.1.2 && search.request.length >= 5)
                    }
                    |> mapToSignal { values -> Signal<([Peer], [Peer], MultiplePeersView, Bool), NoError> in
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
                return combineLatest(participantsPromise.get(), contactsSearch) |> map { participants, peers in
                    let updatedSearch = previousSearch.swap(search.request) != search.request
                    return (channelMembersEntries(participants, users: peers.0, remote: peers.1, account: account, isLoading: isListLoading && peers.2, additionTopItem: additionTopItem), updatedSearch)
                }
            } else {
                return participantsPromise.get() |> map { participants in
                    let updatedSearch = previousSearch.swap(search.request) != search.request
                    return (channelMembersEntries(participants, account: account, isLoading: isListLoading, additionTopItem: additionTopItem), updatedSearch)
                }
            }
        }
    }
    
    deinit {
        loadDisposable.dispose()
        _ = _renderedResult.swap([:])
        
    }
}

private func channelMembersEntries(_ participants:[RenderedChannelParticipant], users:[TemporaryPeer]? = nil, remote:[TemporaryPeer] = [], account: Account, isLoading: Bool, additionTopItem: SelectPeers_AdditionTopItem? = nil) -> [SelectPeerEntry] {
    var entries: [SelectPeerEntry] = []
    var peerIds:[PeerId:PeerId] = [:]
    
    if let item = additionTopItem {
        entries.append(SelectPeerEntry.actionButton(item.title, item.icon, 0, .initialize(theme), { _ in
            item.callback()
        }, false, item.color))
    }
    
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
        //entries.append(.separator(index, strings().channelSelectPeersMembers))
        index += 1
        for participant in participants {
            if account.peerId != participant.peer.id {
                
                entries.append(.peer(SelectPeerValue(peer: participant.peer, presence: participant.presences[participant.peer.id], subscribers: nil), index, true))
                index += 1
            }
        }
    }
    if let users = users, !users.isEmpty {
        entries.append(.separator(index, GeneralRowItem.Theme(), strings().channelSelectPeersContacts))
        index += 1
        for peer in users {
            if account.peerId != peer.peer.id {
                
                entries.append(.peer(SelectPeerValue(peer: peer.peer, presence: peer.presence, subscribers: nil), index, true))
                index += 1
            }
        }
    }
    
    if !remote.isEmpty {
        entries.append(.separator(index, GeneralRowItem.Theme(), strings().channelSelectPeersGlobal))
        index += 1
        for peer in remote {
            if account.peerId != peer.peer.id {
                entries.append(.peer(SelectPeerValue(peer: peer.peer, presence: peer.presence, subscribers: nil), index, true))
                index += 1
            }
        }
    }
    
    if entries.isEmpty && !isLoading {
        entries.append(.searchEmpty(.init(), theme.icons.emptySearch))
    }
    
    return entries
}


class SelectChatsBehavior: SelectPeersBehavior {
    

    
    var premiumBlock: Bool
    var miniappsBlock: Bool
    var additionTopItem: SelectPeers_AdditionTopItem?
    init(settings: SelectPeerSettings = [.contacts, .remote], excludePeerIds: [PeerId] = [], limit: Int32 = INT32_MAX, customTheme: @escaping () -> GeneralRowItem.Theme = { GeneralRowItem.Theme() }, premiumBlock: Bool = false, miniappsBlock: Bool = false, additionTopItem: SelectPeers_AdditionTopItem? = nil) {
        self.premiumBlock = premiumBlock
        self.miniappsBlock = miniappsBlock
        self.additionTopItem = additionTopItem
        super.init(settings: settings, excludePeerIds: excludePeerIds, limit: limit, customTheme: customTheme)
    }
    
    func makeChatEntries(_ peers: [Peer], _ presence: [PeerId: PeerPresence], isSearch: Bool) -> [SelectPeerEntry] {
        var entries: [SelectPeerEntry] = []
       
        var index:Int32 = 0
        
        if let item = additionTopItem {
            entries.append(SelectPeerEntry.actionButton(item.title, item.icon, 0, customTheme(), { _ in
                item.callback()
            }, false, item.color))
        }

        if premiumBlock {
            entries.append(.separator(index, customTheme(), strings().selectPeersUserTypes))
            index += 1

            entries.append(.peer(SelectPeerValue(peer: TelegramFilterCategory(category: .premiumUsers), presence: nil, subscribers: nil, ignoreStatus: true), index, true))
            index += 1
            
            entries.append(.separator(index, customTheme(), strings().selectPeersChats))
            index += 1

        }
        
        if miniappsBlock {
            entries.append(.separator(index, customTheme(), strings().selectPeersUserTypes))
            index += 1

            entries.append(.peer(SelectPeerValue(peer: TelegramFilterCategory(category: .miniApps), presence: nil, subscribers: nil, ignoreStatus: true), index, true))
            index += 1
            
            entries.append(.separator(index, customTheme(), strings().selectPeersChats))
            index += 1

        }
        
        for value in peers {
            if filterPeer(value) {
                entries.append(.peer(SelectPeerValue(peer: value, presence: presence[value.id], subscribers: nil, ignoreStatus: true), index, true))
                index += 1
            }
        }
        
        if entries.isEmpty {
            entries.append(.searchEmpty(.init(), theme.icons.emptySearch))
        }
        return entries
    }
    
    override func start(context: AccountContext, search: Signal<SearchState, NoError>, linkInvation: ((Int)->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        
        let previousSearch = Atomic<String?>(value: nil)
        let account = context.account
        let makeEntries = self.makeChatEntries
        
        
        return search |> distinctUntilChanged |> mapToSignal { search -> Signal<([SelectPeerEntry], Bool), NoError> in
            
            if search.request.isEmpty {
                return account.viewTracker.tailChatListView(groupId: .root, count: 100) |> deliverOn(prepareQueue) |> mapToQueue {  value -> Signal<([SelectPeerEntry], Bool), NoError> in
                    var entries:[Peer] = []
                    
                    for entry in value.0.entries.reversed() {
                        switch entry {
                        case let .MessageEntry(data):
                            if let peer = data.renderedPeer.chatMainPeer {
                                entries.append(peer)
                            }
                        default:
                            break
                        }
                    }
                    
                    let updatedSearch = previousSearch.swap(search.request) != search.request
                    return .single((makeEntries(entries, [:], !search.request.isEmpty), updatedSearch))
                }
            } else {
                return account.postbox.searchPeers(query: search.request.lowercased()) |> map {
                    return $0.compactMap({$0.chatMainPeer})
                } |> deliverOn(prepareQueue) |> map { entries -> ([SelectPeerEntry], Bool) in
                    let updatedSearch = previousSearch.swap(search.request) != search.request
                    return (makeEntries(entries, [:], false), updatedSearch)
                }
            }
            
        }
    }
}

struct SelectPeersBlock {
    let separator: String
    let peerIds: [PeerId]
}

struct SelectPeers_AdditionTopItem {
    var title: String
    var color: NSColor
    var icon: CGImage
    var callback:()->Void
}

class SelectContactsBehavior : SelectPeersBehavior {
    
  
    
    fileprivate let index: PeerNameIndex = .lastNameFirst
    private var previousGlobal:Atomic<[SelectPeerValue]> = Atomic(value: [])
   
    var defaultSelected: [PeerId] = []
    var blocks: [SelectPeersBlock] = []
    var additionTopItem:SelectPeers_AdditionTopItem?
    let isLookSavedMessage: Bool
    let savedStatus: String?
    
    init(settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX, blocks: [SelectPeersBlock] = [], additionTopItem: SelectPeers_AdditionTopItem? = nil, defaultSelected: [PeerId] = [], customTheme: @escaping()->GeneralRowItem.Theme = { GeneralRowItem.Theme() }, isLookSavedMessage: Bool = true, savedStatus: String? = nil) {
        self.defaultSelected = defaultSelected
        self.blocks = blocks
        self.additionTopItem = additionTopItem
        self.isLookSavedMessage = isLookSavedMessage
        self.savedStatus = savedStatus
        super.init(settings: settings, excludePeerIds: excludePeerIds, limit: limit, customTheme: customTheme)
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
        _ = previousGlobal.swap([])
    }
    override func start(context: AccountContext, search:Signal<SearchState, NoError>, linkInvation: ((Int)->Void)? = nil) -> Signal<([SelectPeerEntry], Bool), NoError> {
        
        let previousGlobal = self.previousGlobal
        let previousSearch = Atomic<String?>(value: nil)
        let account = context.account
        let theme = self.customTheme()
        let settings = self.settings
        let excludePeerIds = self.excludePeerIds
        let defaultSelected = self.defaultSelected
        let blocks = self.blocks
        let additionTopItem = self.additionTopItem
        let isLookSavedMessage = self.isLookSavedMessage
        let savedStatus = self.savedStatus
        
        return search |> mapToSignal { [weak self] search -> Signal<([SelectPeerEntry], Bool), NoError> in
            
            
            if search.request.isEmpty {
                let inSearch:[PeerId] = self?.inSearchSelected.modify({$0}) ?? []
                
                let accountPeer = context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: context.peerId)
                )
                
                return combineLatest(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Contacts.List(includePresences: true)), account.postbox.multiplePeersView(inSearch), accountPeer, context.engine.peers.recentPeers())
                    |> deliverOn(prepareQueue)
                    |> map { view, searchView, accountPeer, recentPeers -> ([SelectPeerEntry], Bool) in
                        let updatedSearch = previousSearch.swap(search.request) != search.request
                        return (entriesForView(view, accountPeer: accountPeer?._asPeer(), searchPeers: inSearch, searchView: searchView, recentPeers: recentPeers, excludeIds: excludePeerIds, blocks: blocks, defaultSelected: defaultSelected, linkInvation: linkInvation, theme: theme, additionTopItem: additionTopItem, isLookSavedMessage: isLookSavedMessage, savedStatus: savedStatus), updatedSearch)
                }
                
            } else  {
                
                let foundLocalPeers = account.postbox.searchContacts(query: search.request.lowercased())
                let foundRemotePeers:Signal<([Peer], [Peer], Bool), NoError> = settings.contains(.remote) ? .single(([], [], true)) |> then (context.engine.contacts.searchRemotePeers(query: search.request.lowercased()) |> map {($0.map{$0.peer}, $1.map{$0.peer}, false)} ) : .single(([], [], false))
                
                return combineLatest(foundLocalPeers |> map {$0.0}, foundRemotePeers) |> map { values -> ([Peer], [Peer], Bool) in
                    return (uniquePeers(from: values.0), values.1.0 + values.1.1, values.1.2 && search.request.length >= 5)
                }
                    |> runOn(prepareQueue)
                    |> mapToSignal { values -> Signal<([SelectPeerEntry], Bool), NoError> in
                        var values = values
                        if settings.contains(.excludeBots) {
                            values.0 = values.0.filter {!$0.isBot}
                        }
                        values.0 = values.0.filter {(!$0.isChannel || settings.contains(.channels)) && (settings.contains(.groups) || (!$0.isSupergroup && !$0.isGroup))}
                        values.1 = values.1.filter {(!$0.isChannel || settings.contains(.channels)) && (settings.contains(.groups) || (!$0.isSupergroup && !$0.isGroup))}
                        
                        let local = values.0.filter { !$0.isDeleted }
                        let global = values.1.filter { !$0.isDeleted }
                        
                        return account.postbox.transaction { transaction -> [PeerId : PeerPresence] in
                            var presences: [PeerId : PeerPresence] = [:]
                            for peer in local {
                                if let presence = transaction.getPeerPresence(peerId: peer.id) {
                                    presences[peer.id] = presence
                                }
                            }
                            return presences
                            } |> map { presences -> ([SelectPeerEntry], Bool) in
                                let local:[SelectPeerValue] = local.map { peer in
                                    return SelectPeerValue(peer: peer, presence: presences[peer.id], subscribers: nil, isLookSavedMessage: isLookSavedMessage, savedStatus: savedStatus)
                                }
                                
                                var filteredLocal:[SelectPeerValue] = []
                                var excludeIds = Set<PeerId>()
                                for peer in local {
                                    if account.peerId != peer.peer.id {
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
                                    return SelectPeerValue(peer: peer, presence: presences[peer.id], subscribers: nil, isLookSavedMessage: isLookSavedMessage, savedStatus: savedStatus)
                                }.filter { peer in
                                    if account.peerId != peer.peer.id, !excludeIds.contains(peer.peer.id) {
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
                                return (searchEntriesForPeers(local, global, account: account, isLoading: values.2), updatedSearch)
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

class SelectPeersMainController<T,I,R>: GenericViewController<R> where R:NSView {
    let onChange:Promise<T> = Promise()
    let onComplete:Promise<T> = Promise()
    let onCancel:Promise<Void> = Promise()
    var previousResult:ComposeState<I>? = nil
    func restart(with result:ComposeState<I>) {
        self.previousResult = result
    }
    
    let titles:ComposeTitles
    fileprivate(set) var enableNext:Bool = true
    
    override func getRightBarViewOnce() -> BarView {
        return TextButtonBarView(controller: self, text: titles.done, style: navigationButtonStyle, alignment:.Right)
    }
    
    override func executeReturn() -> Void {
        onCancel.set(Signal<Void, NoError>.single(Void()))
        super.executeReturn()
    }
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        rightBarView.style = navigationButtonStyle
    }

    public override func returnKeyAction() -> KeyHandlerResult {
         self.executeNext()
         return .invoked
    }

    func nextEnabled(_ enable:Bool) {
        self.enableNext = enable
        rightBarView.isEnabled = enable
    }
    
    func executeNext() -> Void {
        
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func loadView() {
        super.loadView()
        
        setCenterTitle(titles.center)
        self.rightBarView.set(handler:{ [weak self] _ in
            self?.executeNext()
        }, for: .Click)
    }
    
    let context: AccountContext
    
    public init(titles:ComposeTitles, context: AccountContext) {
        self.titles = titles
        self.context = context
        super.init()
    }
    
}

class SelectPeersController: SelectPeersMainController<[PeerId], Void, SelectPeersControllerView>, Notifable {
    
    
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
                if limitsConfiguration != oldValue  {
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
                alert(for: context.window, info: strings().composeCreateGroupLimitError)
            }
            
            let tokens = added.map {
                return SearchToken(name: value.peers[$0]?.compactDisplayTitle ?? strings().peerDeletedUser, uniqueId: $0.toInt64())
            }
            genericView.tokenView.addTokens(tokens: tokens, animated: animated)
            
            let idsToRemove:[Int64] = removed.map {
                $0.toInt64()
            }
            genericView.tokenView.removeTokens(uniqueIds: idsToRemove, animated: animated)
            
            self.nextEnabled(!value.selected.isEmpty || isNewGroup)
            
            
            
            if let limits = limitsConfiguration {
                let attributed = NSMutableAttributedString()
                _ = attributed.append(string: strings().telegramSelectPeersController, color: theme.colors.text, font: .medium(.title))
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
        return super.returnKeyAction()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.nextEnabled(false)

        let context = self.context
        let account = self.context.account
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
        
        let limitsSignal:Signal<LimitsConfiguration?, NoError> = isNewGroup ? account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration]) |> map { values -> LimitsConfiguration? in
            return values.values[PreferencesKeys.limitsConfiguration]?.get(LimitsConfiguration.self)
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
    
    
    init(titles: ComposeTitles, context: AccountContext, settings:SelectPeerSettings = [.contacts], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX, isNewGroup: Bool = false, selectedPeers:Set<PeerId> = Set()) {
        let behavior = SelectContactsBehavior(settings: settings, excludePeerIds: excludePeerIds, limit: limit)
        self.behavior = behavior
        self.isNewGroup = isNewGroup
        super.init(titles: titles, context: context)
        
        let peers = context.account.postbox.transaction { transaction in
            return selectedPeers.map {
                transaction.getPeer($0)
            }.compactMap { $0 }
        } |> deliverOnMainQueue
        
        _ = peers.start(next: { [weak self] peers in
            self?.interactions.update { state in
                var state = state
                for peer in peers  {
                    state = state.withToggledSelected(peer.id, peer: peer)
                }
                return state
            }
        })
        
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
    
    var customTheme: (()->GeneralRowItem.Theme)? = nil {
        didSet {
            updateLocalizationAndTheme(theme: theme)
        }
    }
    
    required init(frame frameRect: NSRect) {
        
        var makeTheme:()->TokenizedView.Theme = { TokenizedView.Theme() }
        
        tokenView = TokenizedView(frame: NSMakeRect(0, 0, frameRect.width - 20, 30), localizationFunc: { key in
            return translate(key: key, [])
        }, placeholderKey: "SearchField.Search", customTheme: {
            return makeTheme()
        })
        super.init(frame: frameRect)
        addSubview(tokenView)
        addSubview(tableView)
        addSubview(separatorView)
        tokenView.delegate = self
        
        makeTheme = { [weak self] in
            if let custom = self?.customTheme?() {
                return TokenizedView.Theme(background: custom.backgroundColor,
                                           grayBackground: custom.grayBackground,
                                           textColor: custom.textColor,
                                           grayTextColor: custom.grayTextColor,
                                           underSelectColor: custom.underSelectedColor, accentColor: custom.accentColor,
                                           accentSelectColor: custom.accentSelectColor,
                                           redColor: custom.redColor)
            } else {
                return TokenizedView.Theme()
            }
        }
               
        tableView.getBackgroundColor = { [weak self] in
            return self?.customTheme?().backgroundColor ?? theme.colors.background
        }
        
        updateLocalizationAndTheme(theme: theme)
        layout()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        separatorView.backgroundColor = customTheme?().backgroundColor ?? theme.colors.border
        backgroundColor = customTheme?().backgroundColor ?? theme.colors.background
        
        
    }
    
    
    fileprivate override func layout() {
        super.layout()
        tokenView.frame = NSMakeRect(10, 10, frame.width - 20, tokenView.frame.height)
        tableView.frame = NSMakeRect(0, tokenView.frame.height + 20, frame.width, frame.height - (tokenView.frame.height + 20))
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


class SelectPeersModalController : ModalViewController, Notifable {
    
    private let behavior:SelectPeersBehavior
    private let search:Promise<SearchState> = Promise()
    private let disposable:MetaDisposable = MetaDisposable()
    let interactions:SelectPeerInteraction = SelectPeerInteraction()
    private var previous:Atomic<[SelectPeerEntry]?> = Atomic(value:nil)
    private let context: AccountContext
    private let defaultTitle:String
    private let confirmation:([PeerId])->Signal<Bool,NoError>
    fileprivate let onComplete:Promise<[PeerId]> = Promise()
    private let completeDisposable = MetaDisposable()
    private let tokenDisposable = MetaDisposable()
    private let selectedPeerIds: Set<PeerId>
    private let okTitle: String
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            if behavior.limit > 1 {
                
                let added = value.selected.subtracting(oldValue.selected)
                let removed = oldValue.selected.subtracting(value.selected)
                
                
                
                if value.selected.count > behavior.limit, let first = added.first {
                    behavior.limitReached()
                    DispatchQueue.main.async {
                        if let peer = value.peers[first] {
                            self.interactions.toggleSelection(peer)
                        }
                    }
                } else {
                    
                    let tokens = added.map {
                        return SearchToken(name: value.peers[$0]?.compactDisplayTitle ?? strings().peerDeletedUser, uniqueId: $0.toInt64())
                    }
                    
                    genericView.tokenView.addTokens(tokens: tokens, animated: animated)
                    
                    let idsToRemove:[Int64] = removed.map {
                        $0.toInt64()
                    }
                    genericView.tokenView.removeTokens(uniqueIds: idsToRemove, animated: animated)
                    
                    modal?.interactions?.updateEnables(true)
                }
                
               
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
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 120, max(genericView.tableView.listHeight + 50, 400))), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 120, max(genericView.tableView.listHeight + 50, 400))), animated: animated)
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
        let account = context.account
        genericView.customTheme = behavior.customTheme
        
        
        let selectedPeerIds = self.selectedPeerIds
        
        let peers: Signal<[Peer], NoError> = context.account.postbox.transaction { transaction in
            var peers:[Peer] = []
            for peerId in selectedPeerIds {
                if let peer = transaction.getPeer(peerId) {
                    peers.append(peer)
                } else if peerId.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace {
                    peers.append(TelegramFilterCategory(category: .init(rawValue: Int32(peerId.id._internalGetInt64Value()))))
                }
            }
            return peers
        } |> deliverOnMainQueue
        
        _ = peers.start(next: { peers in
            interactions.update { current in
                var current = current
                for peer in peers {
                    current = current.withToggledSelected(peer.id, peer: peer)
                }
                return current
            }
        })
         
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
                
                _ = (account.postbox.transaction { transaction -> Void in
                    updatePeersCustom(transaction: transaction, peers: [peer], update: { _, updated -> Peer? in
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
    
    private let linkInvation: ((Int)->Void)?
    
    init(context: AccountContext, title:String, settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT32_MAX, confirmation:@escaping([PeerId])->Signal<Bool,NoError>, behavior: SelectPeersBehavior? = nil, linkInvation:((Int)->Void)? = nil, selectedPeerIds: Set<PeerId> = Set(), okTitle: String = strings().modalOK) {
        self.context = context
        self.defaultTitle = title
        self.confirmation = confirmation
        self.linkInvation = linkInvation
        self.behavior = behavior ?? SelectContactsBehavior(settings: settings, excludePeerIds: excludePeerIds, limit: limit)
        self.selectedPeerIds = selectedPeerIds
        self.okTitle = okTitle
        super.init(frame: NSMakeRect(0, 0, 360, 380))
        bar = .init(height: 0)
        completeDisposable.set((onComplete.get() |> take(1) |> deliverOnMainQueue).start(completed: { [weak self] in
            self?.close()
        }))
    }
    
    func confirmSelected(_ peerIds:[PeerId], _ peers:[Peer]) {
        let signal = context.account.postbox.transaction { transaction -> Void in
            updatePeersCustom(transaction: transaction, peers: peers.filter { $0.id.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace }, update: { (_, updated) -> Peer? in
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
        return (left: ModalHeaderData(image: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(behavior.customTheme().accentColor), handler: {  [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: self.defaultTitle), right: nil)
    }
    
    override var modalTheme: ModalViewController.Theme {
        let customTheme = behavior.customTheme()
        return .init(text: customTheme.textColor, grayText: customTheme.grayTextColor, background: customTheme.backgroundColor, border: customTheme.borderColor, accent: customTheme.accentColor, grayForeground: customTheme.grayBackground)
    }
    
    override var containerBackground: NSColor {
        return behavior.customTheme().backgroundColor
    }
    
    override var modalInteractions: ModalInteractions? {
        if behavior.limit == 1 {
            return nil
        } else {
            return ModalInteractions(acceptTitle: behavior.okTitle ?? self.okTitle, accept: { [weak self] in
                if let interactions = self?.interactions {
                   self?.confirmSelected(Array(interactions.presentation.selected), Array(interactions.presentation.peers.values))
                }
            }, drawBorder: true, height: 50, singleButton: false, customTheme: { [weak self] in
                return self?.modalTheme ?? .init()
            })
            
            
        }
    }
    

    deinit {
        disposable.dispose()
        interactions.remove(observer: self)
        completeDisposable.dispose()
        tokenDisposable.dispose()
    }
    
}


func selectModalPeers(window: Window, context: AccountContext, title:String , settings:SelectPeerSettings = [.contacts, .remote], excludePeerIds:[PeerId] = [], limit: Int32 = INT_MAX, behavior: SelectPeersBehavior? = nil, confirmation:@escaping ([PeerId]) -> Signal<Bool,NoError> = {_ in return .single(true) }, linkInvation:((Int)->Void)? = nil, selectedPeerIds: Set<PeerId> = Set(), okTitle: String = strings().modalOK) -> Signal<[PeerId], NoError> {
    
    let modal = SelectPeersModalController(context: context, title: title, settings: settings, excludePeerIds: excludePeerIds, limit: limit, confirmation: confirmation, behavior: behavior, linkInvation: linkInvation, selectedPeerIds: selectedPeerIds, okTitle: okTitle)
    
    showModal(with: modal, for: window)
    
    
    return modal.onComplete.get() |> take(1)
    
}


