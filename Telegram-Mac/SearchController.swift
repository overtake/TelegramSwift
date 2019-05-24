//
//  SearchController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac


enum UnreadSearchBadge : Equatable {
    case none
    case muted(Int32)
    case unmuted(Int32)
}

final class SearchControllerArguments {
    let context: AccountContext
    let removeRecentPeerId:(PeerId)->Void
    let clearRecent:()->Void
    let openTopPeer:(PopularItemType)->Void
    init(context: AccountContext, removeRecentPeerId:@escaping(PeerId)->Void, clearRecent:@escaping()->Void, openTopPeer:@escaping(PopularItemType)->Void) {
        self.context = context
        self.removeRecentPeerId = removeRecentPeerId
        self.clearRecent = clearRecent
        self.openTopPeer = openTopPeer
    }
    
}

enum ChatListSearchEntryStableId: Hashable {
    case localPeerId(PeerId)
    case secretChat(PeerId)
    case savedMessages
    case recentSearchPeerId(PeerId)
    case globalPeerId(PeerId)
    case messageId(MessageId)
    case topPeers
    case separator(Int)
    case emptySearch
    
    var hashValue: Int {
        switch self {
        case let .localPeerId(peerId):
            return peerId.hashValue
        case let .secretChat(peerId):
            return peerId.hashValue
        case let .recentSearchPeerId(peerId):
            return peerId.hashValue
        case let .globalPeerId(peerId):
            return peerId.hashValue
        case .savedMessages:
            return 1000
        case let .messageId(messageId):
            return messageId.hashValue
        case let .separator(index):
            return index
        case .emptySearch:
            return 0
        case .topPeers:
            return -1
        }
    }
}

private struct SearchSecretChatWrapper : Equatable {
    let peerId:PeerId
}


fileprivate enum ChatListSearchEntry: Comparable, Identifiable {
    case localPeer(Peer, Int, SearchSecretChatWrapper?, Bool)
    case recentlySearch(Peer, Int, SearchSecretChatWrapper?, PeerStatusStringResult, UnreadSearchBadge, Bool)
    case globalPeer(FoundPeer, Int)
    case savedMessages(Peer)
    case message(Message, String,Int)
    case separator(text: String, index:Int, state:SeparatorBlockState)
    case topPeers(Int, articlesEnabled: Bool, unreadArticles: Int32, selfPeer: Peer, peers: [Peer], unread: [PeerId: UnreadSearchBadge], online: [PeerId : Bool])
    case emptySearch
    var stableId: ChatListSearchEntryStableId {
        switch self {
        case let .localPeer(peer, _, secretChat, _):
            if let secretChat = secretChat {
                return .secretChat(secretChat.peerId)
            }
            return .localPeerId(peer.id)
        case let .globalPeer(found, _):
            return .globalPeerId(found.peer.id)
        case let .message(message, _, _):
            return .messageId(message.id)
        case .savedMessages:
            return .savedMessages
        case let .separator(_,index, _):
            return .separator(index)
        case let .recentlySearch(peer, _, secretChat, _, _, _):
            if let secretChat = secretChat {
                return .secretChat(secretChat.peerId)
            }
            return .recentSearchPeerId(peer.id)
        case .topPeers:
            return .topPeers
        case .emptySearch:
            return .emptySearch
        }
    }
    
    var index:Int {
        switch self {
        case let .localPeer(_,index, _, _):
            return index
        case let .globalPeer(_,index):
            return index
        case let .message(_, _, index):
            return index
        case .savedMessages:
            return -1
        case let .separator(_,index, _):
            return index
        case let .recentlySearch(_,index, _, _, _, _):
            return index
        case let .topPeers(index, _, _, _, _, _, _):
            return index
        case .emptySearch:
            return 0
        }
    }
    
    static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
        case let .localPeer(lhsPeer, lhsIndex, lhsSecretChat, lhsDrawBorder):
            if case let .localPeer(rhsPeer, rhsIndex, rhsSecretChat, rhsDrawBorder) = rhs, lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex && lhsSecretChat == rhsSecretChat && lhsDrawBorder == rhsDrawBorder {
                return true
            } else {
                return false
            }
        case let .recentlySearch(lhsPeer, lhsIndex, lhsSecretChat, lhsStatus, lhsBadge, lhsDrawBorder):
            if case let .recentlySearch(rhsPeer, rhsIndex, rhsSecretChat, rhsStatus, rhsBadge, rhsDrawBorder) = rhs, lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex && lhsSecretChat == rhsSecretChat && lhsDrawBorder == rhsDrawBorder && lhsStatus == rhsStatus && lhsBadge == rhsBadge {
                return true
            } else {
                return false
            }
        case let .globalPeer(lhsPeer, lhsIndex):
            if case let .globalPeer(rhsPeer, rhsIndex) = rhs, lhsPeer.peer.isEqual(rhsPeer.peer) && lhsIndex == rhsIndex && lhsPeer.subscribers == rhsPeer.subscribers {
                return true
            } else {
                return false
            }
        case .savedMessages:
            if case .savedMessages = rhs {
                return true
            } else {
                return false
            }
        case let .message(lhsMessage, lhsSearchText, lhsIndex):
            if case let .message(rhsMessage, rhsSearchText, rhsIndex) = rhs {
                
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsSearchText != rhsSearchText {
                    return false
                }
                if lhsMessage.id != rhsMessage.id {
                    return false
                }
                if lhsMessage.stableVersion != rhsMessage.stableVersion {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .separator(lhsText, lhsIndex, lhsState):
            if case let .separator(rhsText,rhsIndex, rhsState) = rhs {
                if lhsText != rhsText || lhsIndex != rhsIndex {
                    return false
                }
                return lhsState == rhsState
                
            } else {
                return false
            }
        case .emptySearch:
            if case .emptySearch = rhs {
                return true
            } else {
                return false
            }
        case let .topPeers(index, articlesEnabled, unreadArticles, lhsSelfPeer, lhsPeers, lhsUnread, online):
            if case .topPeers(index, articlesEnabled, unreadArticles, let rhsSelfPeer, let rhsPeers, let rhsUnread, online) = rhs {
                if !lhsSelfPeer.isEqual(rhsSelfPeer) {
                    return false
                }
                
                if lhsUnread != rhsUnread {
                    return false
                }
                
                if lhsPeers.count != rhsPeers.count {
                    return false
                } else {
                    for i in 0 ..< lhsPeers.count {
                        if !lhsPeers[i].isEqual(lhsPeers[i]) {
                            return false
                        }
                    }
                    return true
                }
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
}


fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ChatListSearchEntry>]?, to:[AppearanceWrapperEntry<ChatListSearchEntry>], arguments:SearchControllerArguments, pinnedItems:[PinnedItemId], initialSize:NSSize, animated: Bool) -> TableEntriesTransition<[AppearanceWrapperEntry<ChatListSearchEntry>]> {
    
    let togglePin:(Peer) -> Void = { peer in
        let updatePeer = arguments.context.account.postbox.transaction { transaction -> Void in
            updatePeers(transaction: transaction, peers: [peer], update: { (_, updated) -> Peer? in
                return updated
            })
        } |> mapToSignal { _ -> Signal<TogglePeerChatPinnedResult, NoError> in
            return toggleItemPinned(postbox: arguments.context.account.postbox, groupId: .root, itemId: .peer(peer.id))
        } |> deliverOnMainQueue
        
        _ = updatePeer.start(next: { result in
            switch result {
            case .limitExceeded:
                alert(for: mainWindow, info: L10n.chatListContextPinErrorNew)
            default:
                break
            }
        })
    }
    
    let (deleted,inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
        switch entry.entry {
        case let .message(message, query, _):
            let item = ChatListMessageRowItem(initialSize, context: arguments.context, message: message, query: query, renderedPeer: RenderedPeer(message: message))
            return item
        case let .globalPeer(foundPeer,_):
            var status: String? = nil
            if let addressName = foundPeer.peer.addressName {
                status = "@\(addressName)"
            }
            if let subscribers = foundPeer.subscribers, let username = status {
                if foundPeer.peer.isChannel {
                    status = tr(L10n.searchGlobalChannel1Countable(username, Int(subscribers)))
                } else if foundPeer.peer.isSupergroup || foundPeer.peer.isGroup {
                    status = tr(L10n.searchGlobalGroup1Countable(username, Int(subscribers)))
                }
            }
            
            
            
            return RecentPeerRowItem(initialSize, peer: foundPeer.peer, account: arguments.context.account, stableId: entry.stableId, statusStyle:ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status: status, borderType: [.Right], contextMenuItems: {
                var items:[ContextMenuItem] = []
                
                var isPinned: Bool = false
                for item in pinnedItems {
                    switch item {
                    case let .peer(peerId):
                        if peerId == foundPeer.peer.id {
                            isPinned = true
                            break
                        }
                    default:
                        break
                    }
                }
                
                items.append(ContextMenuItem(isPinned ? L10n.chatListContextUnpin : L10n.chatListContextPin, handler: {
                    togglePin(foundPeer.peer)
                }))
                
                return items
            })
        case let .localPeer(peer, _, secretChat, drawBorder):
            return RecentPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: entry.stableId, titleStyle: ControlStyle(font: .medium(.text), foregroundColor: secretChat != nil ? theme.colors.blueUI : theme.colors.text, highlightColor:.white), borderType: [.Right], drawCustomSeparator: drawBorder, isLookSavedMessage: true, drawLastSeparator: true, canRemoveFromRecent: false, contextMenuItems: {
                var items:[ContextMenuItem] = []
                
                var isPinned: Bool = false
                for item in pinnedItems {
                    switch item {
                    case let .peer(peerId):
                        if peerId == peer.id {
                            isPinned = true
                            break
                        }
                    default:
                        break
                    }
                }
                
                items.append(ContextMenuItem(isPinned ? L10n.chatListContextUnpin : L10n.chatListContextPin, handler: {
                    togglePin(peer)
                }))
                
                return items
            })
        case let .recentlySearch(peer, _, secretChat, status, badge, drawBorder):
            return RecentPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: entry.stableId, titleStyle: ControlStyle(font: .medium(.text), foregroundColor: secretChat != nil ? theme.colors.blueUI : theme.colors.text, highlightColor:.white), statusStyle: ControlStyle(font:.normal(.text), foregroundColor: status.status.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: nil) as? NSColor ?? theme.colors.grayText, highlightColor:.white), status: status.status.string, borderType: [.Right], drawCustomSeparator: drawBorder, isLookSavedMessage: true, drawLastSeparator: true, canRemoveFromRecent: true, removeAction: {
                arguments.removeRecentPeerId(peer.id)
            }, contextMenuItems: {
                var items:[ContextMenuItem] = []
                
                var isPinned: Bool = false
                for item in pinnedItems {
                    switch item {
                    case let .peer(peerId):
                        if peerId == peer.id {
                            isPinned = true
                            break
                        }
                    default:
                        break
                    }
                }
                
                items.append(ContextMenuItem(isPinned ? L10n.chatListContextUnpin : L10n.chatListContextPin, handler: {
                    togglePin(peer)
                }))
                
                return items
            }, unreadBadge: badge)
        case let .savedMessages(peer):
            return RecentPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: entry.stableId, titleStyle: ControlStyle(font: .medium(.text), foregroundColor: theme.colors.text, highlightColor:.white), borderType: [.Right], drawCustomSeparator: false, isLookSavedMessage: true, contextMenuItems: {
                var items:[ContextMenuItem] = []
                
                var isPinned: Bool = false
                for item in pinnedItems {
                    switch item {
                    case let .peer(peerId):
                        if peerId == peer.id {
                            isPinned = true
                            break
                        }
                    default:
                        break
                    }
                }
                
                items.append(ContextMenuItem(isPinned ? L10n.chatListContextUnpin : L10n.chatListContextPin, handler: {
                    togglePin(peer)
                }))
                
                return items
            })
        case let .separator(text, index, state):
            let right:String?
            switch state {
            case .short:
                right = tr(L10n.separatorShowMore)
            case .all:
                right = tr(L10n.separatorShowLess)
            case .clear:
                right = tr(L10n.separatorClear)
                
            default:
                right = nil
            }
            return SeparatorRowItem(initialSize, ChatListSearchEntryStableId.separator(index), string: text.uppercased(), right: right?.lowercased(), state: state)
        case .emptySearch:
            return SearchEmptyRowItem(initialSize, stableId: ChatListSearchEntryStableId.emptySearch, border: [.Right])
        case let .topPeers(_, articlesEnabled, unreadArticles, selfPeer, peers, unread, online):
            return PopularPeersRowItem(initialSize, stableId: entry.stableId, account: arguments.context.account, selfPeer: selfPeer, articlesEnabled: articlesEnabled, unreadArticles: unreadArticles, peers: peers, unread: unread, online: online, action: { type in
                arguments.openTopPeer(type)
            })
        }
    })
    
    return TableEntriesTransition(deleted: deleted, inserted: inserted, updated:updated, entries: to, animated: animated, state: .none(nil))

}


struct AppSearchOptions : OptionSet {
    public var rawValue: UInt32
    
    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    init() {
        self.rawValue = 0
    }
    
    init(_ flags: AppSearchOptions) {
        var rawValue: UInt32 = 0
        
        if flags.contains(AppSearchOptions.messages) {
            rawValue |= AppSearchOptions.messages.rawValue
        }
        
        if flags.contains(AppSearchOptions.chats) {
            rawValue |= AppSearchOptions.chats.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    static let messages = AppSearchOptions(rawValue: 1)
    static let chats = AppSearchOptions(rawValue: 2)
}

class SearchController: GenericViewController<TableView>,TableViewDelegate {
    
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    
    private let context:AccountContext
    private var marked: Bool = false
    private let arguments:SearchControllerArguments
    private var open:(PeerId?, MessageId?, Bool) -> Void = {_,_,_  in}
    private let groupId: PeerGroupId
    private let searchQuery:Promise = Promise<String?>()
    private var query: String? = nil
    private let openPeerDisposable:MetaDisposable = MetaDisposable()
    private let statePromise:Promise<(SeparatorBlockState,SeparatorBlockState)> = Promise((SeparatorBlockState.short, SeparatorBlockState.short))
    private let disposable:MetaDisposable = MetaDisposable()
    private let pinnedPromise: ValuePromise<[PinnedItemId]> = ValuePromise([], ignoreRepeated: true)
    var pinnedItems:[PinnedItemId] = [] {
        didSet {
            pinnedPromise.set(pinnedItems)
        }
    }
    
    let isLoading = Promise<Bool>(false)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.delegate = self
        genericView.needUpdateVisibleAfterScroll = true
        genericView.border = [.Right]
        
        let context = self.context
        let options = self.options

        let searchMessagesState: ValuePromise<SearchMessagesState?> = ValuePromise()
        let searchMessagesStateValue: Atomic<SearchMessagesState?> = Atomic(value: nil)

        
        let arguments = self.arguments
        let statePromise = self.statePromise.get()
        let atomicSize = self.atomicSize
        let previousSearchItems = Atomic<[AppearanceWrapperEntry<ChatListSearchEntry>]>(value: [])
        let groupId: PeerGroupId = self.groupId
        let searchItems = searchQuery.get() |> mapToSignal { query -> Signal<([ChatListSearchEntry], Bool, Bool, SearchMessagesState?), NoError> in
            if let query = query, !query.isEmpty {
                var ids:[PeerId:PeerId] = [:]
                
                let foundLocalPeers: Signal<[ChatListSearchEntry], NoError> = query.hasPrefix("#") || !options.contains(.chats) ? .single([]) : combineLatest(context.account.postbox.searchPeers(query: query.lowercased()), context.account.postbox.loadedPeerWithId(context.peerId))
                    |> map { peers, accountPeer -> [ChatListSearchEntry] in
                        var entries: [ChatListSearchEntry] = []
                        
                        
                        if L10n.peerSavedMessages.lowercased().hasPrefix(query.lowercased()) || NSLocalizedString("Peer.SavedMessages", comment: "nil").lowercased().hasPrefix(query.lowercased()) {
                            entries.append(.savedMessages(accountPeer))
                        }
                        
                        var index = 1
                        for rendered in peers {
                            if ids[rendered.peerId] == nil {
                                ids[rendered.peerId] = rendered.peerId
                                if let peer = rendered.chatMainPeer {
                                    var wrapper:SearchSecretChatWrapper? = nil
                                    if rendered.peers[rendered.peerId] is TelegramSecretChat {
                                        wrapper = SearchSecretChatWrapper(peerId: rendered.peerId)
                                    }
                                    entries.append(.localPeer(peer, index, wrapper, true))
                                    index += 1
                                }
                                
                            }
                            
                        }
                        return entries
                }
                
                let foundRemotePeers: Signal<([ChatListSearchEntry], [ChatListSearchEntry], Bool), NoError>
                
                let location: SearchMessagesLocation
                if groupId != .root {
                    location = .group(groupId)
                    foundRemotePeers = .single(([], [], false))
                } else if query.hasPrefix("#") || !options.contains(.chats) {
                    location = .general
                    foundRemotePeers = .single(([], [], false))
                } else {
                    location = .general
                    foundRemotePeers = .single(([], [], true)) |> then(searchPeers(account: context.account, query: query)
                            |> delay(0.2, queue: prepareQueue)
                            |> map { founds -> ([FoundPeer], [FoundPeer]) in
                                
                                return (founds.0.filter { found -> Bool in
                                    let first = ids[found.peer.id] == nil
                                    ids[found.peer.id] = found.peer.id
                                    return first
                                    }, founds.1.filter { found -> Bool in
                                        let first = ids[found.peer.id] == nil
                                        ids[found.peer.id] = found.peer.id
                                        return first
                                })
                                
                            }
                            |> map { _local, _remote -> ([ChatListSearchEntry], [ChatListSearchEntry], Bool) in
                                var local: [ChatListSearchEntry] = []
                                var index = 1000
                                for peer in _local {
                                    local.append(.localPeer(peer.peer, index, nil, true))
                                    index += 1
                                }
                                
                                var remote: [ChatListSearchEntry] = []
                                index = 10001
                                for peer in _remote {
                                    remote.append(.globalPeer(peer, index))
                                    index += 1
                                }
                                return (local, remote, false)
                            })
                }
                
                searchMessagesState.set(nil)
                
                
                let remoteSearch = searchMessagesState.get() |> mapToSignal { state in
                    return searchMessages(account: context.account, location: location , query: query, state: state)
                        |> delay(0.2, queue: prepareQueue)
                        |> map { result -> ([ChatListSearchEntry], Bool, SearchMessagesState?) in
                            
                            var entries: [ChatListSearchEntry] = []
                            var index = 20001
                            for message in result.0.messages {
                                entries.append(.message(message, query, index))
                                index += 1
                            }
                            
                            return (entries, false, result.1)
                    }
                }
                
                
                let foundRemoteMessages: Signal<([ChatListSearchEntry], Bool, SearchMessagesState?), NoError> = !options.contains(.messages) ? .single(([], false, nil)) : .single(([], true, nil)) |> then(remoteSearch)
                
                return combineLatest(foundLocalPeers |> deliverOnPrepareQueue, foundRemotePeers |> deliverOnPrepareQueue, foundRemoteMessages |> deliverOnPrepareQueue)
                    |> map { localPeers, remotePeers, remoteMessages -> ([ChatListSearchEntry], Bool, SearchMessagesState?) in
                        
                        var entries:[ChatListSearchEntry] = []
                        if !localPeers.isEmpty || !remotePeers.0.isEmpty {
                            entries.append(.separator(text: L10n.searchSeparatorChatsAndContacts, index: 0, state: .none))
                            entries += localPeers
                            entries += remotePeers.0
                        }
                        if !remotePeers.1.isEmpty {
                            entries.append(.separator(text: L10n.searchSeparatorGlobalPeers, index: 10000, state: .none))
                            entries += remotePeers.1
                        }
                        if !remoteMessages.0.isEmpty {
                            entries.append(.separator(text: L10n.searchSeparatorMessages, index: 20000, state: .none))
                            entries += remoteMessages.0
                        }
                        if entries.isEmpty && !remotePeers.2 && !remoteMessages.1 {
                            entries.append(.emptySearch)
                        }
                        return (entries, remotePeers.2 || remoteMessages.1, remoteMessages.2)
                    } |> map { value in
                        return (value.0, value.1, false, value.2)
                    }
                
            } else {

                let recently = recentlySearchedPeers(postbox: context.account.postbox) |> mapToSignal { recently -> Signal<[PeerView], NoError> in
                    return combineLatest(recently.map {context.account.viewTracker.peerView($0.peer.peerId)})
                    
                    } |> mapToSignal { peerViews -> Signal<([PeerView], [PeerId: UnreadSearchBadge]), NoError> in
                        return context.account.postbox.unreadMessageCountsView(items: peerViews.map {.peer($0.peerId)}) |> map { values in
                            
                            var unread:[PeerId: UnreadSearchBadge] = [:]
                            for peerView in peerViews {
                                let isMuted = peerView.isMuted
                                let unreadCount = values.count(for: .peer(peerView.peerId))
                                if let unreadCount = unreadCount, unreadCount > 0 {
                                    unread[peerView.peerId] = isMuted ? .muted(unreadCount) : .unmuted(unreadCount)
                                }
                            }
                            return (peerViews, unread)
                        }
                    
                } |> deliverOnPrepareQueue
                
                let top: Signal<([Peer], [PeerId : UnreadSearchBadge], [PeerId : Bool]), NoError> = recentPeers(account: context.account) |> mapToSignal { recent in
                    switch recent {
                    case .disabled:
                        return .single(([], [:], [:]))
                    case let .peers(peers):
                        return combineLatest(peers.map {context.account.viewTracker.peerView($0.id)}) |> mapToSignal { peerViews -> Signal<([Peer], [PeerId: UnreadSearchBadge], [PeerId : Bool]), NoError> in
                                return context.account.postbox.unreadMessageCountsView(items: peerViews.map {.peer($0.peerId)}) |> map { values in
                                    
                                    var peers:[Peer] = []
                                    var unread:[PeerId: UnreadSearchBadge] = [:]
                                    var online: [PeerId : Bool] = [:]
                                    for peerView in peerViews {
                                        if let peer = peerViewMainPeer(peerView) {
                                            var isActive:Bool = false
                                            if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence {
                                                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                                                (_, isActive, _) = stringAndActivityForUserPresence(presence, timeDifference: context.timeDifference, relativeTo: Int32(timestamp))
                                            }
                                            let isMuted = peerView.isMuted
                                            let unreadCount = values.count(for: .peer(peerView.peerId))
                                            if let unreadCount = unreadCount, unreadCount > 0 {
                                                unread[peerView.peerId] = isMuted ? .muted(unreadCount) : .unmuted(unreadCount)
                                            }
                                           
                                            online[peer.id] = isActive
                                            peers.append(peer)
                                        }
                                    }
                                    return (peers, unread, online)
                                }
                        }
                    }
                } |> deliverOnPrepareQueue
                
                return combineLatest(context.account.postbox.loadedPeerWithId(context.peerId) |> deliverOnPrepareQueue, top, recently, statePromise |> deliverOnPrepareQueue) |> map { user, top, recent, state -> ([ChatListSearchEntry], Bool) in
                    var entries:[ChatListSearchEntry] = []
                    var i:Int = 0
                    var ids:[PeerId:PeerId] = [:]

                    ids[context.peerId] = context.peerId
                    
                    
                    entries.append(ChatListSearchEntry.topPeers(i, articlesEnabled: false, unreadArticles: 0, selfPeer: user, peers: top.0, unread: top.1, online: top.2))
                    
                    if recent.0.count > 0 {
                        entries.append(.separator(text: L10n.searchSeparatorRecent, index: i, state: .clear))
                        i += 1
                        for peerView in recent.0 {
                            if ids[peerView.peerId] == nil {
                                ids[peerView.peerId] = peerView.peerId
                                if let peer = peerViewMainPeer(peerView) {
                                    var wrapper:SearchSecretChatWrapper? = nil
                                    if peerView.peers[peerView.peerId] is TelegramSecretChat {
                                        wrapper = SearchSecretChatWrapper(peerId: peerView.peerId)
                                    }
                                    let result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.title)))

                                    entries.append(.recentlySearch(peer, i, wrapper, result, recent.1[peerView.peerId] ?? .none, true))
                                    i += 1
                                }

                            }
                        }
                    }
                    
                    if entries.isEmpty {
                        entries.append(.emptySearch)
                    }
                    
                    return (entries.sorted(by: <), false)
                } |> map {value in
                    return (value.0, value.1, true, nil)
                }
            }
        }
        
        
        let transition = combineLatest(searchItems |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, context.globalPeerHandler.get() |> deliverOnPrepareQueue |> distinctUntilChanged, pinnedPromise.get() |> deliverOnPrepareQueue) |> map { value, appearance, location, pinnedItems in
            return (value.0.map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}, value.1, value.2 ? nil : location, value.2, pinnedItems, value.3)
        }
        |> map { entries, loading, location, animated, pinnedItems, searchMessagesState -> (TableUpdateTransition, Bool, ChatLocation?, SearchMessagesState?) in
            let transition = prepareEntries(from: previousSearchItems.swap(entries) , to: entries, arguments: arguments, pinnedItems: pinnedItems, initialSize: atomicSize.modify { $0 }, animated: animated)
            return (transition, loading, location, searchMessagesState)
        } |> deliverOnMainQueue
        
        
        disposable.set(transition.start(next: { [weak self] (transition, loading, location, searchMessagesState) in
            guard let `self` = self else {return}
            self.genericView.merge(with: transition)
            self.isLoading.set(.single(loading))
            
            _ = searchMessagesStateValue.swap(searchMessagesState)
            
            if let location = location {
                if !(self.genericView.selectedItem() is ChatListMessageRowItem) {
                    switch location {
                    case let .peer(peerId):
                        let item = self.genericView.item(stableId: ChatListSearchEntryStableId.globalPeerId(peerId)) ?? self.genericView.item(stableId: ChatListSearchEntryStableId.localPeerId(peerId))
                        if let item = item {
                            _ = self.genericView.select(item: item, notify: false, byClick: false)
                        }
                    default:
                        self.genericView.cancelSelection()
                    }
                }
            } else {
                self.genericView.cancelSelection()
            }
        }))

        
        genericView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                searchMessagesState.set(searchMessagesStateValue.swap(nil))
            default:
                break
            }
        }
        
        ready.set(.single(true))
        
    }
    
    override func initializer() -> TableView {
        let vz = TableView.self
        //controller.bar.height
        return TableView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), drawBorder: true);
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isLoading.set(.single(false))
        self.window?.remove(object: self, for: .UpArrow)
        self.window?.remove(object: self, for: .DownArrow)
        openPeerDisposable.set(nil)
        globalDisposable.set(nil)
        disposable.set(nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
       
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            if self.window?.firstResponder?.className != "TGUIKit.SearchTextField" {
                return .rejected
            }
            
            if let highlighted = self.genericView.highlightedItem() {
                _ = self.genericView.select(item: highlighted)
                self.closeNext = true

            } else if !self.marked {
                self.genericView.cancelSelection()
                self.genericView.selectNext()
                self.closeNext = true
            }
            
            return .rejected
        }, with: self, for: .Return, priority: .low)
        
        
        setHighlightEvents()
        
    }
    
    func updateHighlightEvents(_ hasChat: Bool) {
        if !hasChat {
            setHighlightEvents()
        } else {
            removeHighlightEvents()
        }
    }
    
    private func setHighlightEvents() {
        
        removeHighlightEvents()
        
      
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.window?.firstResponder?.className != "TGUIKit.SearchTextField" {
                return .rejected
            }
            if let item = self?.genericView.highlightedItem(), item.index > 0 {
                self?.genericView.highlightPrev(turnDirection: false)
                while self?.genericView.highlightedItem() is PopularPeersRowItem || self?.genericView.highlightedItem() is SeparatorRowItem {
                    self?.genericView.highlightNext(turnDirection: false)
                }
            }
            return .invoked
        }, with: self, for: .UpArrow, priority: .modal)
        
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.window?.firstResponder?.className != "TGUIKit.SearchTextField" {
                return .rejected
            }
            self?.genericView.highlightNext(turnDirection: false)
            
            while self?.genericView.highlightedItem() is PopularPeersRowItem || self?.genericView.highlightedItem() is SeparatorRowItem {
                self?.genericView.highlightNext(turnDirection: false)
            }
            
            return .invoked
        }, with: self, for: .DownArrow, priority: .modal)
        
        
        self.window?.set(handler: { () -> KeyHandlerResult in
            return .rejected
        }, with: self, for: .UpArrow, priority: .modal, modifierFlags: [.command])
        
        self.window?.set(handler: { () -> KeyHandlerResult in
            return .rejected
        }, with: self, for: .DownArrow, priority: .modal, modifierFlags: [.command])
        
        
    }
    
    private func removeHighlightEvents() {
        genericView.cancelHighlight()
        self.window?.remove(object: self, for: .DownArrow)
        self.window?.remove(object: self, for: .UpArrow)
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        request(with: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    private let globalDisposable = MetaDisposable()
    private let options: AppSearchOptions
    
    deinit {
        openPeerDisposable.dispose()
        globalDisposable.dispose()
        disposable.dispose()
    }
    
    init(context: AccountContext, open:@escaping(PeerId?, MessageId?, Bool) ->Void, options: AppSearchOptions = [.chats, .messages], frame:NSRect = NSZeroRect, groupId: PeerGroupId = .root) {
        self.context = context
        self.open = open
        self.options = options
        self.groupId = groupId
        self.arguments = SearchControllerArguments(context: context, removeRecentPeerId: { peerId in
            _ = removeRecentlySearchedPeer(postbox: context.account.postbox, peerId: peerId).start()
        }, clearRecent: {
            _ = (recentlySearchedPeers(postbox: context.account.postbox) |> take(1) |> mapToSignal {
                return combineLatest($0.map {removeRecentlySearchedPeer(postbox: context.account.postbox, peerId: $0.peer.peerId)})
            }).start()
        }, openTopPeer: { type in
            switch type {
            case let .peer(peer, _, _):
                open(peer.id, nil, false)
            case let .savedMessages(peer):
                open(peer.id, nil, false)
            case .articles:
                break
            }
        })
        super.init(frame:frame)
        self.bar = .init(height: 0)
        
        globalDisposable.set(context.globalPeerHandler.get().start(next: { [weak self] peerId in
            if peerId == nil {
                self?.genericView.cancelSelection()
            }
        }))
    }
    
    func request(with query:String?) -> Void {
        setHighlightEvents()
        self.query = query
        if let query = query, !query.isEmpty {
            searchQuery.set(.single(query))
        } else {
            searchQuery.set(.single(nil))
        }
    }
    
    private var closeNext: Bool = false
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        var peer:Peer?
        var peerId:PeerId?
        var messageId:MessageId?
        
        let context = self.context
        
        if let item = item as? ChatListMessageRowItem {
            peer = item.peer
            messageId = item.message?.id
            peerId = item.message!.id.peerId
        } else if let item = item as? ShortPeerRowItem {
            if let stableId = item.stableId.base as? ChatListSearchEntryStableId {
                switch stableId {
                case let .localPeerId(pId), let .recentSearchPeerId(pId), let .secretChat(pId), let .globalPeerId(pId):
                    peerId = pId
                case .savedMessages:
                    peerId = context.peerId
                default:
                    break
                }
            }
            peer = item.peer
        } else if let item = item as? SeparatorRowItem {
            switch item.state {
            case .short:
                statePromise.set(.single((.all, .short)))
            case .all:
                statePromise.set(.single((.short, .short)))
            case .clear:
                arguments.clearRecent()
            default:
                break
            }

            return
        } else if item is PopularPeersRowItem {
            peerId = context.peerId
        }
        
        var storedPeer: Signal<PeerId, NoError>
        if let peer = peer {
             storedPeer = context.account.postbox.transaction { transaction -> Void in
                if transaction.getPeer(peer.id) == nil {
                    updatePeers(transaction: transaction, peers: [peer], update: { (previous, updated) -> Peer? in
                        return updated
                    })
                }
                
            } |> mapToSignal {
                return storedMessageFromSearchPeer(account: context.account, peer: peer)
            }
        } else if let peerId = peerId {
            storedPeer = .single(peerId)
        } else {
            storedPeer = .complete()
        }
        
        if let query = query, let peerId = peerId {
            let link = inApp(for: query as NSString, context: context, peerId: peerId, openInfo: { _, _, _, _ in }, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
            switch link {
            case let .followResolvedName(_, _, postId, _, _, _):
                if let postId = postId {
                    messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: postId)
                }
            default:
                break
            }
        }

        
        let recently: Signal<Void, NoError>
        if let peerId = peerId {
            recently = (searchQuery.get() |> take(1)) |> mapToSignal { [weak self] query -> Signal<Void, NoError> in
                if let context = self?.context, !(item is ChatListMessageRowItem) {
                    return addRecentlySearchedPeer(postbox: context.account.postbox, peerId: peerId)
                }
                return .single(Void())
            }
        } else {
            recently = .single(Void())
        }
        
        _ = combineLatest(storedPeer, recently).start()
        
        removeHighlightEvents()

        marked = true
        
        if let peerId = peerId {
            self.open(peerId, messageId, self.closeNext)
        }
        
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        
        
        
        var peer: Peer? = nil
        if let item = item as? ChatListMessageRowItem {
            peer = item.peer
        } else if let item = item as? ShortPeerRowItem {
            peer = item.peer
        } else if let item = item as? SeparatorRowItem {
            switch item.state {
            case .none:
                return false
            default:
                return true
            }
        }
        
        if let peer = peer, let modalAction = navigationController?.modalAction {
            
            if !modalAction.isInvokable(for: peer) {
                modalAction.alertError(for: peer, with:window!)
                return false
            }
            modalAction.afterInvoke()
            
            if let modalAction = modalAction as? FWDNavigationAction {
                if peer.id == context.peerId {
                    _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId).start()
                    _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
                    navigationController?.removeModalAction()
                    return false
                }
            }
            
        }
        
        return !(item is SearchEmptyRowItem)
    }
    
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    
}
