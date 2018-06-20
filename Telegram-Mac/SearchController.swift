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


final class SearchControllerArguments {
    let account: Account
    let removeRecentPeerId:(PeerId)->Void
    let clearRecent:()->Void
    init(account: Account, removeRecentPeerId:@escaping(PeerId)->Void, clearRecent:@escaping()->Void) {
        self.account = account
        self.removeRecentPeerId = removeRecentPeerId
        self.clearRecent = clearRecent
    }
    
}

enum ChatListSearchEntryStableId: Hashable {
    case localPeerId(PeerId)
    case secretChat(PeerId)
    case savedMessages
    case recentSearchPeerId(PeerId)
    case globalPeerId(PeerId)
    case messageId(MessageId)
    case separator(Int)
    case emptySearch
    static func ==(lhs: ChatListSearchEntryStableId, rhs: ChatListSearchEntryStableId) -> Bool {
        switch lhs {
        case let .localPeerId(lhsPeerId):
            if case let .localPeerId(rhsPeerId) = rhs {
                return lhsPeerId == rhsPeerId
            } else {
                return false
            }
        case let .secretChat(peerId):
            if case .secretChat(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .recentSearchPeerId(lhsPeerId):
            if case let .recentSearchPeerId(rhsPeerId) = rhs {
                return lhsPeerId == rhsPeerId
            } else {
                return false
            }
        case let .globalPeerId(lhsPeerId):
            if case let .globalPeerId(rhsPeerId) = rhs {
                return lhsPeerId == rhsPeerId
            } else {
                return false
            }
        case .savedMessages:
            if case .savedMessages = rhs {
                return true
            } else {
                return false
            }
        case let .messageId(lhsMessageId):
            if case let .messageId(rhsMessageId) = rhs {
                return lhsMessageId == rhsMessageId
            } else {
                return false
            }
        case let .separator(lhsIndex):
            if case let .separator(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case .emptySearch:
            if case .emptySearch = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
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
        }
    }
}

private struct SearchSecretChatWrapper : Equatable {
    let peerId:PeerId
    static func ==(lhs: SearchSecretChatWrapper, rhs: SearchSecretChatWrapper) -> Bool {
        return lhs.peerId == rhs.peerId
    }
}


fileprivate enum ChatListSearchEntry: Comparable, Identifiable {
    case localPeer(Peer, Int, SearchSecretChatWrapper?, Bool)
    case recentlySearch(Peer, Int, SearchSecretChatWrapper?, Bool)
    case globalPeer(FoundPeer, Int)
    case savedMessages(Peer)
    case message(Message,Int)
    case separator(text: String, index:Int, state:SeparatorBlockState)
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
        case let .message(message,_):
            return .messageId(message.id)
        case .savedMessages:
            return .savedMessages
        case let .separator(_,index, _):
            return .separator(index)
        case let .recentlySearch(peer, _, secretChat, _):
            if let secretChat = secretChat {
                return .secretChat(secretChat.peerId)
            }
            return .recentSearchPeerId(peer.id)
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
        case let .message(_,index):
            return index
        case .savedMessages:
            return -1
        case let .separator(_,index, _):
            return index
        case let .recentlySearch(_,index, _, _):
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
        case let .recentlySearch(lhsPeer, lhsIndex, lhsSecretChat, lhsDrawBorder):
            if case let .recentlySearch(rhsPeer, rhsIndex, rhsSecretChat, rhsDrawBorder) = rhs, lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex && lhsSecretChat == rhsSecretChat && lhsDrawBorder == rhsDrawBorder {
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
        case let .message(lhsMessage, lhsIndex):
            if case let .message(rhsMessage, rhsIndex) = rhs {
                
                if lhsIndex != rhsIndex {
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
        }
    }
    
    static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
}


fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ChatListSearchEntry>]?, to:[AppearanceWrapperEntry<ChatListSearchEntry>], arguments:SearchControllerArguments, initialSize:NSSize) -> TableEntriesTransition<[AppearanceWrapperEntry<ChatListSearchEntry>]> {
    
    let (deleted,inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
        switch entry.entry {
        case let .message(message,_):
            let item = ChatListMessageRowItem(initialSize, account: arguments.account, message: message, renderedPeer: RenderedPeer(message: message))
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
            return RecentPeerRowItem(initialSize, peer: foundPeer.peer, account: arguments.account, stableId: entry.stableId, statusStyle:ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status: status, borderType: [.Right], contextMenuItems: {
                return []
            })
        case let .localPeer(peer, _, secretChat, drawBorder), let .recentlySearch(peer, _, secretChat, drawBorder):
            
            var canRemoveFromRecent: Bool = false
            if case .recentlySearch = entry.entry {
                canRemoveFromRecent = true
            }
            
            let item = RecentPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: entry.stableId, titleStyle: ControlStyle(font: .medium(.text), foregroundColor: secretChat != nil ? theme.colors.blueUI : theme.colors.text, highlightColor:.white), borderType: [.Right], drawCustomSeparator: drawBorder, isLookSavedMessage: true, drawLastSeparator: true, canRemoveFromRecent: canRemoveFromRecent, removeAction: {
                arguments.removeRecentPeerId(peer.id)
            })
            return item
        case let .savedMessages(peer):
            return RecentPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: entry.stableId, titleStyle: ControlStyle(font: .medium(.text), foregroundColor: theme.colors.text, highlightColor:.white), borderType: [.Right], drawCustomSeparator: false, isLookSavedMessage: true)
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
        }
    })
    
    return TableEntriesTransition(deleted: deleted, inserted: inserted, updated:updated, entries: to, animated: false, state: .none(nil))

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
    
    
    
    private let account:Account
    private let arguments:SearchControllerArguments
    private var open:(PeerId, Message?, Bool) -> Void = {_,_,_  in}
    private let groupId: PeerGroupId?
    private let searchQuery:Promise = Promise<String?>()
    private let openPeerDisposable:MetaDisposable = MetaDisposable()
    private let statePromise:Promise<(SeparatorBlockState,SeparatorBlockState)> = Promise((SeparatorBlockState.short, SeparatorBlockState.short))
    private let disposable:MetaDisposable = MetaDisposable()
    let isLoading = Promise<Bool>(false)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.delegate = self
        genericView.needUpdateVisibleAfterScroll = true
        genericView.border = [.Right]
        
        let account = self.account
        let options = self.options

      
        let arguments = self.arguments
        let statePromise = self.statePromise.get()
        let atomicSize = self.atomicSize
        let previousSearchItems = Atomic<[AppearanceWrapperEntry<ChatListSearchEntry>]>(value: [])
        let groupId: PeerGroupId? = self.groupId
        let searchItems = searchQuery.get() |> mapToSignal { (query) -> Signal<([ChatListSearchEntry], Bool, Bool), Void> in
            if let query = query, !query.isEmpty {
                var ids:[PeerId:PeerId] = [:]
                
                let foundLocalPeers: Signal<[ChatListSearchEntry], Void> = query.hasPrefix("#") || !options.contains(.chats) ? .single([]) : combineLatest(account.postbox.searchPeers(query: query.lowercased(), groupId: groupId), account.postbox.loadedPeerWithId(account.peerId))
                    |> map { peers, accountPeer -> [ChatListSearchEntry] in
                        var entries: [ChatListSearchEntry] = []
                        
                        
                        if tr(L10n.peerSavedMessages).lowercased().hasPrefix(query.lowercased()) {
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
                if let groupId = groupId {
                    location = .group(groupId)
                    foundRemotePeers = .single(([], [], false))
                } else if query.hasPrefix("#") || !options.contains(.chats) {
                    location = .general
                    foundRemotePeers = .single(([], [], false))
                } else {
                    location = .general
                    foundRemotePeers = .single(([], [], true)) |> then(searchPeers(account: account, query: query)
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
                
                let foundRemoteMessages: Signal<([ChatListSearchEntry], Bool), NoError> = !options.contains(.messages) ? .single(([], false)) : .single(([], true)) |> then(searchMessages(account: account, location: location , query: query)
                    |> delay(0.2, queue: prepareQueue)
                    |> map { messages -> ([ChatListSearchEntry], Bool) in
                        
                        
                        var entries: [ChatListSearchEntry] = []
                        var index = 20001
                        for message in messages {
                            entries.append(.message(message, index))
                            index += 1
                        }
                        
                        return (entries, false)
                    })
                
                return combineLatest(foundLocalPeers, foundRemotePeers, foundRemoteMessages)
                    |> map { localPeers, remotePeers, remoteMessages -> ([ChatListSearchEntry], Bool) in
                        
                        var entries:[ChatListSearchEntry] = []
                        if !localPeers.isEmpty || !remotePeers.0.isEmpty {
                            entries.append(.separator(text: tr(L10n.searchSeparatorChatsAndContacts), index: 0, state: .none))
                            entries += localPeers
                            entries += remotePeers.0
                        }
                        if !remotePeers.1.isEmpty {
                            entries.append(.separator(text: tr(L10n.searchSeparatorGlobalPeers), index: 10000, state: .none))
                            entries += remotePeers.1
                        }
                        if !remoteMessages.0.isEmpty {
                            entries.append(.separator(text: tr(L10n.searchSeparatorMessages), index: 20000, state: .none))
                            entries += remoteMessages.0
                        }
                        if entries.isEmpty && !remotePeers.2 && !remoteMessages.1 {
                            entries.append(.emptySearch)
                        }
                        return (entries, remotePeers.2 || remoteMessages.1)
                    } |> map { value in
                        return (value.0, value.1, false)
                    }
                
            } else {
                
                return combineLatest(account.postbox.loadedPeerWithId(account.peerId), recentPeers(account: account), recentlySearchedPeers(postbox: account.postbox), statePromise) |> map { user, top, recent, state -> ([ChatListSearchEntry], Bool) in
                    var entries:[ChatListSearchEntry] = [.savedMessages(user)]
                    var i:Int = 0
                    var ids:[PeerId:PeerId] = [:]

                    ids[account.peerId] = account.peerId
                    
                    var topIds:[PeerId:PeerId] = [:]
                    var topPeers:[Peer] = []
                    switch top {
                    case let .peers(peers):
                        topPeers = peers
                    default:
                        break
                    }
                    for t in topPeers {
                        topIds[t.id] = t.id
                    }
                    var recent = recent.filter({ rendered in
                        for i in 0 ..< topPeers.count {
                            if i <= 4 {
                                return topPeers[i].id != rendered.peerId
                            }
                        }
                        return true
                    })

                    if topPeers.count > 0 {
                        entries.append(.separator(text: tr(L10n.searchSeparatorPopular), index: i, state: recent.isEmpty ? .none : state.0))
                    }
                    
                    for peer in topPeers {
                        if ids[peer.id] == nil {
                            ids[peer.id] = peer.id
                            var stop:Bool = false
                            recent = recent.filter({ids[$0.peerId] == nil})
                            if case .short = state.0, (i == 4 && recent.count > 0) {
                                stop = true
                            }
                            entries.append(.localPeer(peer, i, nil, true))
                            i += 1
                            if stop {
                                break
                            }
                        }
                        
                    }
                    
                    if recent.count > 0 {
                        entries.append(.separator(text: tr(L10n.searchSeparatorRecent), index: i, state: .clear))
                        i += 1
                        for rendered in recent {
                            if ids[rendered.peerId] == nil {
                                ids[rendered.peerId] = rendered.peerId
                                if let peer = rendered.chatMainPeer {
                                    var wrapper:SearchSecretChatWrapper? = nil
                                    if rendered.peers[rendered.peerId] is TelegramSecretChat {
                                        wrapper = SearchSecretChatWrapper(peerId: rendered.peerId)
                                    }
                                    entries.append(.recentlySearch(peer, i, wrapper, true))
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
                    return (value.0, value.1, true)
                }
            }
        }
        
        
        let transition = combineLatest(searchItems |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, globalPeerHandler.get() |> deliverOnPrepareQueue |> distinctUntilChanged) |> map { value, appearance, location in
            return (value.0.map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}, value.1, value.2 ? nil : location)
        }
        |> map { entries, loading, location -> (TableUpdateTransition, Bool, ChatLocation?) in
            let transition = prepareEntries(from: previousSearchItems.swap(entries) , to: entries, arguments: arguments, initialSize:atomicSize.modify { $0 })
            return (transition, loading, location)
        } |> deliverOnMainQueue
        
        disposable.set((transition).start(next: { [weak self] (transition, loading, location) in
            self?.genericView.merge(with: transition)
            self?.isLoading.set(.single(loading))
            if let location = location {
                switch location {
                case let .peer(peerId):
                    let item = self?.genericView.item(stableId: ChatListSearchEntryStableId.globalPeerId(peerId)) ?? self?.genericView.item(stableId: ChatListSearchEntryStableId.localPeerId(peerId))
                    if let item = item {
                        _ = self?.genericView.select(item: item, notify: false, byClick: false)
                    }
                default:
                    self?.genericView.cancelSelection()
                }
            } else {
                self?.genericView.cancelSelection()
            }
        }))

        
        ready.set(.single(true))
        
    }
    
    override func initializer() -> TableView {
        let vz = TableView.self
        //controller.bar.height
        return vz.init(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), drawBorder: true);
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
            if let item = self?.genericView.selectedItem(), item.index > 0 {
                self?.genericView.selectPrev()
                if self?.genericView.selectedItem() is SeparatorRowItem {
                    self?.genericView.selectPrev()
                }
            }
            return .invoked
        }, with: self, for: .UpArrow, priority: .modal, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.selectNext()
            if self?.genericView.selectedItem() is SeparatorRowItem {
                self?.genericView.selectNext()
            }
            return .invoked
        }, with: self, for: .DownArrow, priority: .modal, modifierFlags: [.command])
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
    
    init(account: Account, open:@escaping(PeerId,Message?, Bool) ->Void, options: AppSearchOptions = [.chats, .messages], frame:NSRect = NSZeroRect, groupId: PeerGroupId? = nil) {
        self.account = account
        self.open = open
        self.options = options
        self.groupId = groupId
        self.arguments = SearchControllerArguments(account: account, removeRecentPeerId: { peerId in
            _ = removeRecentlySearchedPeer(postbox: account.postbox, peerId: peerId).start()
        }, clearRecent: {
            _ = (recentlySearchedPeers(postbox: account.postbox) |> take(1) |> mapToSignal {
                return combineLatest($0.map {removeRecentlySearchedPeer(postbox: account.postbox, peerId: $0.peerId)})
            }).start()
        })
        super.init(frame:frame)
        self.bar = .init(height: 0)
        
        globalDisposable.set(globalPeerHandler.get().start(next: { [weak self] peerId in
            if peerId == nil {
                self?.genericView.cancelSelection()
            }
        }))
    }
    
    func request(with query:String?) -> Void {
        if let query = query, !query.isEmpty {
            searchQuery.set(.single(query))
        } else {
            searchQuery.set(.single(nil))
        }
    }
    
    
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        var peer:Peer!
        var peerId:PeerId!
        var message:Message?
        if let item = item as? ChatListMessageRowItem {
            peer = item.peer
            message = item.message
            peerId = item.message!.id.peerId
        } else if let item = item as? ShortPeerRowItem {
            if let stableId = item.stableId.base as? ChatListSearchEntryStableId {
                switch stableId {
                case let .localPeerId(pId), let .recentSearchPeerId(pId), let .secretChat(pId), let .globalPeerId(pId):
                    peerId = pId
                case .savedMessages:
                    peerId = account.peerId
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
        }
        
        let storedPeer: Signal<Void, Void>
        if let peer = peer {
             storedPeer = account.postbox.transaction { transaction -> Void in
                if transaction.getPeer(peer.id) == nil {
                    updatePeers(transaction: transaction, peers: [peer], update: { (previous, updated) -> Peer? in
                        return updated
                    })
                }
                
            }
        } else {
            storedPeer = .complete()
        }
        
        
        
        let recently = (searchQuery.get() |> take(1)) |> mapToSignal { [weak self] query -> Signal<Void, Void> in
            if let _ = query, let account = self?.account, !(item is ChatListMessageRowItem) {
                return addRecentlySearchedPeer(postbox: account.postbox, peerId: peerId)
            }
            return .complete()
        }
        
        openPeerDisposable.set((combineLatest(storedPeer, recently) |> deliverOnMainQueue).start( completed: { [weak self] in
            //!(item is ChatListMessageRowItem) && byClick
            self?.open(peerId, message, false)
        }))
        
    }
    
    func selectionWillChange(row: Int, item: TableRowItem) -> Bool {
        
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
                if peer.id == account.peerId {
                    _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, account: account, peerId: account.peerId).start()
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
