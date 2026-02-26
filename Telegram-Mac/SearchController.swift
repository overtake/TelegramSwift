//
//  SearchController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import InAppSettings

extension SearchMessagesLocation {
    func withUpdatedSouce(_ source: SearchController.MessaagesSourceValue) -> SearchMessagesLocation {
        switch self {
        case let .general(_, tags, minDate, maxDate):
            return .general(scope: source.scope, tags: tags, minDate: minDate, maxDate: maxDate)
        default:
            return self
        }
    }
}


private final class SearchCacheData {
    
    fileprivate struct MessageCacheKey : Hashable {
        let query: String
        let tags: SearchTags?
        init(query: String, tags: SearchTags? = nil) {
            self.query = query
            self.tags = tags
        }
        
        static func key(query: String, tags: SearchTags? = nil) -> MessageCacheKey {
            return .init(query: query, tags: tags)
        }
    }
    
    private var previousMessages:[ChatListSearchEntry] = []
    private var previousLocalPeers:[ChatListSearchEntry] = []
    private var previousRemotePeers:[ChatListSearchEntry] = []

    private var messages: [MessageCacheKey: [ChatListSearchEntry]] = [:]
    private var remotePeers: [String:  [ChatListSearchEntry]] = [:]
    private var localPeers: [String:  [ChatListSearchEntry]] = [:]

    func cacheMessages(_ messages:[ChatListSearchEntry], for key: MessageCacheKey) -> Void {
        self.messages[key] = messages
        previousMessages = messages
    }
    func cacheRemotePeers(_ peers:[ChatListSearchEntry], for key: String) -> Void {
        self.remotePeers[key] = peers
        previousRemotePeers = peers
        
        var stableIds:Set<ChatListSearchEntryStableId> = Set()
        for peer in peers {
            assert(!stableIds.contains(peer.stableId))
            stableIds.insert(peer.stableId)
        }
        
    }
    func cacheLocalPeers(_ peers:[ChatListSearchEntry], for key: String) -> Void {
        self.localPeers[key] = peers
        previousLocalPeers = peers
        
        var stableIds:Set<ChatListSearchEntryStableId> = Set()
        for peer in peers {
            assert(!stableIds.contains(peer.stableId))
            stableIds.insert(peer.stableId)
        }
        
    }
    func cachedMessages(for key: MessageCacheKey) -> [ChatListSearchEntry] {
        let value = self.messages[key] ?? previousMessages
        return value
    }
    func cachedRemotePeers(for key: String) -> [ChatListSearchEntry] {
        let value = self.remotePeers[key] ?? previousRemotePeers
        return value
    }
    func cachedLocalPeers(for key: String) -> [ChatListSearchEntry] {
        let value = self.localPeers[key] ?? previousLocalPeers
        return value
    }
}


struct ExternalSearchMessages {
    let messages:[Message]
    let count: Int32
    let tags: MessageTags?
    init(messages: [Message] = [], count: Int32 = 0, tags: MessageTags? = nil) {
        self.messages = messages
        self.count = count
        self.tags = tags
    }
    func withUpdatedTags(_ tags: MessageTags?) -> ExternalSearchMessages {
        return ExternalSearchMessages(messages: self.messages, count: self.count, tags: tags)
    }
    var title: String? {
        let text: String?
        if tags == .photoOrVideo {
            text = strings().peerMediaTitleSearchMediaCountable(Int(count))
        } else if tags == .photo {
            text = strings().peerMediaTitleSearchPhotosCountable(Int(count))
        } else if tags == .video {
            text = strings().peerMediaTitleSearchVideosCountable(Int(count))
        } else if tags == .gif {
            text = strings().peerMediaTitleSearchGIFsCountable(Int(count))
        } else if tags == .file {
            text = strings().peerMediaTitleSearchFilesCountable(Int(count))
        } else if tags == .webPage {
            text = strings().peerMediaTitleSearchLinksCountable(Int(count))
        } else if tags == .music {
            text = strings().peerMediaTitleSearchMusicCountable(Int(count))
        } else {
            text = nil
        }
        if let text = text {
            return text.replacingOccurrences(of: "\(count)", with: count.formattedWithSeparator)
        }
        return text
    }
}

enum UnreadSearchBadge : Equatable {
    case none
    case muted(Int32)
    case unmuted(Int32)
}

final class SearchControllerArguments {
    let context: AccountContext
    let target: SearchController.Target
    let removeRecentPeerId:(PeerId)->Void
    let clearRecent:()->Void
    let openTopPeer:(PopularItemType)->Void
    let setPeerAsTag:(Peer)->Void
    let openStory:(StoryInitialIndex?)->Void
    let openStorySearch:(SearchStoryListContext.State)->Void
    let toggleMessageSourceValue:(SearchController.MessaagesSourceValue)->Void
    let removeAd:(AdPeer, Bool)->Void
    init(context: AccountContext, target: SearchController.Target, removeRecentPeerId:@escaping(PeerId)->Void, clearRecent:@escaping()->Void, openTopPeer:@escaping(PopularItemType)->Void, setPeerAsTag: @escaping(Peer)->Void, openStory:@escaping(StoryInitialIndex?)->Void, openStorySearch:@escaping(SearchStoryListContext.State)->Void, toggleMessageSourceValue:@escaping(SearchController.MessaagesSourceValue)->Void, removeAd:@escaping(AdPeer, Bool)->Void) {
        self.context = context
        self.target = target
        self.removeRecentPeerId = removeRecentPeerId
        self.clearRecent = clearRecent
        self.openTopPeer = openTopPeer
        self.setPeerAsTag = setPeerAsTag
        self.openStory = openStory
        self.openStorySearch = openStorySearch
        self.toggleMessageSourceValue = toggleMessageSourceValue
        self.removeAd = removeAd
    }
    
}

enum ChatListSearchEntryStableId: Hashable {
    case localPeerId(PeerId)
    case topic(EngineChatList.Item.Index)
    case secretChat(PeerId)
    case savedMessages
    case recentSearchPeerId(PeerId)
    case globalPeerId(PeerId)
    case messageId(MessageId)
    case topPeers
    case separator(Int)
    case emptySearch
    case foundStories
    case disclaimer
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .localPeerId(peerId):
            hasher.combine("localPeerId")
            hasher.combine(peerId.hashValue)
        case let .topic(index):
            hasher.combine("topic")
            switch index {
            case let .forum(_, _, threadId, _, _):
                hasher.combine(threadId)
            default:
                break
            }
        case let .secretChat(peerId):
            hasher.combine("secretChat")
            hasher.combine(peerId.hashValue)
        case let .recentSearchPeerId(peerId):
            hasher.combine("recentSearchPeerId")
            hasher.combine(peerId.hashValue)
        case let .globalPeerId(peerId):
            hasher.combine("globalPeerId")
            hasher.combine(peerId.hashValue)
        case .savedMessages:
            hasher.combine("savedMessages")
            hasher.combine(1000)
        case let .messageId(messageId):
            hasher.combine("messageId")
            hasher.combine(messageId.hashValue)
        case let .separator(index):
            hasher.combine("separator")
            hasher.combine(index)
        case .emptySearch:
            hasher.combine("emptySearch")
            hasher.combine(0)
        case .topPeers:
            hasher.combine("topPeers")
            hasher.combine(-1)
        case .foundStories:
            hasher.combine("foundStories")
        case .disclaimer:
            hasher.combine("disclaimer")
        }
    }
}

private struct SearchSecretChatWrapper : Equatable {
    let peerId:PeerId
}


fileprivate enum ChatListSearchEntry: Comparable, Identifiable {
    case localPeer(RenderedPeer, Int, SearchSecretChatWrapper?, UnreadSearchBadge, Bool, Bool, PeerStoryStats?)
    case topic(EngineChatList.Item, Int, UnreadSearchBadge, Bool, Bool)
    case recentlySearch(RenderedPeer, Int, SearchSecretChatWrapper?, PeerStatusStringResult, UnreadSearchBadge, Bool, PeerStoryStats?, Bool, isGrossingApp: Bool, isRecentApp: Bool)
    case globalPeer(FoundPeer, UnreadSearchBadge, Int, AdPeer?)
    case savedMessages(Peer)
    case message(Message, String, CombinedPeerReadState?, MessageHistoryThreadData?, Int)
    case separator(text: String, index:Int, state:SeparatorBlockState)
    case topPeers(Int, articlesEnabled: Bool, unreadArticles: Int32, selfPeer: Peer, peers: [Peer], unread: [PeerId: UnreadSearchBadge], online: [PeerId : Bool])
    case foundStories(StoryListContext.State, index: Int, query: String)
    case emptySearch(isLoading: Bool)
    case emptyList(listType: SearchTags.ListType)
    case disclaimer(String)
    var stableId: ChatListSearchEntryStableId {
        switch self {
        case let .localPeer(peer, _, secretChat, _, _, _, _):
            if let secretChat = secretChat {
                return .secretChat(secretChat.peerId)
            }
            return .localPeerId(peer.peerId)
        case let .topic(item, _, _, _, _):
            return .topic(item.index)
        case let .globalPeer(found, _, _, _):
            return .globalPeerId(found.peer.id)
        case let .message(message, _, _, _, _):
            return .messageId(message.id)
        case .savedMessages:
            return .savedMessages
        case let .separator(_,index, _):
            return .separator(index)
        case let .recentlySearch(peer, _, secretChat, _, _, _, _, _, _, _):
            if let secretChat = secretChat {
                return .secretChat(secretChat.peerId)
            }
            return .recentSearchPeerId(peer.peerId)
        case .topPeers:
            return .topPeers
        case .emptySearch:
            return .emptySearch
        case .emptyList:
            return .emptySearch
        case .foundStories:
            return .foundStories
        case .disclaimer:
            return .disclaimer
        }
    }
    
    var index:Int {
        switch self {
        case let .localPeer(_,index, _, _, _, _, _):
            return index
        case let .topic(_,index, _, _, _):
            return index
        case let .globalPeer(_, _,index, _):
            return index
        case let .message(_, _, _, _, index):
            return index
        case .savedMessages:
            return -1
        case let .separator(_,index, _):
            return index
        case let .recentlySearch(_,index, _, _, _, _, _, _, _, _):
            return index
        case let .topPeers(index, _, _, _, _, _, _):
            return index
        case .emptySearch:
            return 0
        case .emptyList:
            return 0
        case .foundStories:
            return 0
        case .disclaimer:
            return 100000000
        }
    }
    
    static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
        case let .localPeer(peer, index, isSecretChat, badge, drawBorder, canAddAsTag, peerStoryStats):
            if case .localPeer(peer, index, isSecretChat, badge, drawBorder, canAddAsTag, peerStoryStats) = rhs {
                return true
            } else {
                return false
            }
        case let .topic(item, index, badge, drawBorder, canAddAsTag):
            if case .topic(item, index, badge, drawBorder, canAddAsTag) = rhs {
                return true
            } else {
                return false
            }
        case let .recentlySearch(peer, index, isSecretChat, status, badge, drawBorder, storyStats, canRemoveRecent, isGrossingApp, isRecentApp):
            if case .recentlySearch(peer, index, isSecretChat, status, badge, drawBorder, storyStats, canRemoveRecent, isGrossingApp, isRecentApp) = rhs {
                return true
            } else {
                return false
            }
        case let .globalPeer(lhsPeer, badge, index, adPeer):
            if case .globalPeer(let rhsPeer, badge, index, adPeer) = rhs, lhsPeer.peer.isEqual(rhsPeer.peer) && lhsPeer.subscribers == rhsPeer.subscribers {
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
        case let .message(lhsMessage, text, combinedState, threadInfo, index):
            if case .message(let rhsMessage, text, combinedState, threadInfo, index) = rhs {

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
        case let .emptySearch(isLoading):
            if case .emptySearch(isLoading) = rhs {
                return true
            } else {
                return false
            }
        case .emptyList:
            if case .emptyList = rhs {
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
        case let .foundStories(state, index, query):
            if case .foundStories(state, index, query) = rhs {
                return true
            } else {
                return false
            }
        case let .disclaimer(text):
            if case .disclaimer(text) = rhs {
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


private func peerContextMenuItems(peer: Peer, pinnedItems:[PinnedItemId], arguments: SearchControllerArguments, isRecent: Bool) -> Signal<[ContextMenuItem], NoError> {
    var items:[ContextMenuItem] = []
    
    let togglePin:(Peer) -> Void = { peer in
        let updatePeer = arguments.context.account.postbox.transaction { transaction -> Void in
            updatePeersCustom(transaction: transaction, peers: [peer], update: { (_, updated) -> Peer? in
                return updated
            })
            } |> mapToSignal { _ -> Signal<TogglePeerChatPinnedResult, NoError> in
                return arguments.context.engine.peers.toggleItemPinned(location: .group(.root), itemId: .peer(peer.id))
            } |> deliverOnMainQueue
        
        _ = updatePeer.start(next: { result in
            switch result {
            case .limitExceeded:
                verifyAlert_button(for: arguments.context.window, information: strings().chatListContextPinErrorNew2, ok: strings().alertOK, cancel: "", option: strings().chatListContextPinErrorNewSetupFolders, successHandler: { result in
                    switch result {
                    case .thrid:
                        arguments.context.bindings.rootNavigation().push(ChatListFiltersListController(context: arguments.context))
                    default:
                        break
                    }
                })
            default:
                break
            }
        })
    }
    
    var isPinned: Bool = false
    for item in pinnedItems {
        switch item {
        case let .peer(peerId):
            if peerId == peer.id {
                isPinned = true
                break
            }
        }
    }
    
    items.append(ContextMenuItem(isPinned ? strings().chatListContextUnpin : strings().chatListContextPin, handler: {
        togglePin(peer)
    }, itemImage: isPinned ? MenuAnimation.menu_unpin.value : MenuAnimation.menu_pin.value))
    
    let peerId = peer.id
    
    return .single(items) |> mapToSignal { items in
        return chatListFilterPreferences(engine: arguments.context.engine) |> deliverOnMainQueue |> take(1) |> map { filters -> [ContextMenuItem] in
            var items = items
            var submenu: [ContextMenuItem] = []
            if peerId.namespace != Namespaces.Peer.SecretChat {
                for item in filters.list {
                    loop: switch item {
                    case .allChats:
                        break loop
                    case let .filter(_, _, _, data):
                        submenu.append(ContextMenuItem(item.title, handler: {
                            _ = arguments.context.engine.peers.updateChatListFiltersInteractively({ list in
                                var list = list
                                for (i, folder) in list.enumerated() {
                                    if folder.id == item.id, var folderData = folder.data {
                                        if data.includePeers.peers.contains(peerId) {
                                            var peers = folderData.includePeers.peers
                                            peers.removeAll(where: { $0 == peerId })
                                            folderData.includePeers.setPeers(peers)
                                        } else {
                                            folderData.includePeers.setPeers(folderData.includePeers.peers + [peerId])
                                        }
                                        list[i] = list[i].withUpdatedData(folderData)
                                    }
                                }
                                return list
                            }).start()
                        }, state: data.includePeers.peers.contains(peerId) ? NSControl.StateValue.on : nil))
                    }
                    
                }
            }
            
            if !submenu.isEmpty {
                items.append(ContextSeparatorItem())
                let item = ContextMenuItem(strings().chatListFilterAddToFolder, itemImage: MenuAnimation.menu_add_to_folder.value)
                let menu = ContextMenu()
                for item in submenu {
                    menu.addItem(item)
                }
                item.submenu = menu
                items.append(item)
            }
            
            if isRecent {
                items.append(ContextSeparatorItem())
                
                items.append(ContextMenuItem(strings().searchRemoveFromRecent, handler: {
                    arguments.removeRecentPeerId(peer.id)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
            }
            
            return items
        }
    }
}


fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ChatListSearchEntry>]?, to:[AppearanceWrapperEntry<ChatListSearchEntry>], arguments:SearchControllerArguments, pinnedItems:[PinnedItemId], initialSize:NSSize, animated: Bool, target: SearchController.Target) -> TableEntriesTransition<[AppearanceWrapperEntry<ChatListSearchEntry>]> {
    
    let (deleted, inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
        switch entry.entry {
        case let .message(message, query, combinedState, threadInfo, _):
            var peer = RenderedPeer(message: message)
            if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                if let channelPeer = message.peers[migrationReference.peerId] {
                    peer = RenderedPeer(peer: channelPeer)
                }
            }
            let mode: ChatListRowItem.Mode
            let titleMode: ChatListRowItem.TitleMode
            let id: EngineChatList.Item.Id
            if let data = threadInfo, let threadId = message.replyAttribute?.threadMessageId {
                let threadId = Int64(threadId.id)
                mode = .topic(threadId, data)
                id = .forum(threadId)
            } else if case .savedMessages = target {
                if let sourceReference = message.sourceReference {
                    id = .chatList(sourceReference.messageId.peerId)
                    mode = .savedMessages(sourceReference.messageId.peerId.toInt64())
                    if let value = message.peers[sourceReference.messageId.peerId] {
                        peer = RenderedPeer(peer: value)
                    }
                } else {
                    id = .chatList(.init(anonymousSavedMessagesId))
                    mode = .savedMessages(anonymousSavedMessagesId)
                    peer = RenderedPeer(peer: TelegramUser(id: .init(anonymousSavedMessagesId), accessHash: nil, firstName: nil, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
                }
            } else {
                id = .chatList(message.id.peerId)
                mode = .chat
            }
            switch arguments.target {
            case .forum, .savedMessages:
                titleMode = .normal
            case .common:
                titleMode = .forumInfo
            }
            let item = ChatListMessageRowItem(initialSize, context: arguments.context, message: message, id: id, query: query, renderedPeer: peer, readState: combinedState, mode: mode, titleMode: titleMode)
            return item
        case let .globalPeer(foundPeer, badge, _, adPeer):
            var status: String? = nil
            if let addressName = foundPeer.peer.addressName {
                status = "@\(addressName)"
            }
            if let subscribers = foundPeer.subscribers, let username = status {
                if foundPeer.peer.isChannel {
                    status = strings().searchGlobalChannel1Countable(username, Int(subscribers))
                } else if foundPeer.peer.isSupergroup || foundPeer.peer.isGroup {
                    status = strings().searchGlobalGroup1Countable(username, Int(subscribers))
                }
            }
            return RecentPeerRowItem(initialSize, peer: foundPeer.peer, account: arguments.context.account, context: arguments.context, stableId: entry.stableId, statusStyle:ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status: status, borderType: [.Right], contextMenuItems: {
                return peerContextMenuItems(peer: foundPeer.peer, pinnedItems: pinnedItems, arguments: arguments, isRecent: false)
            }, unreadBadge: badge, adPeer: adPeer, removeAd: arguments.removeAd)
        case let .localPeer(renderedPeer, _, secretChat, badge, drawBorder, canAddAsTag, storyStats):
            
            
            guard let peer = renderedPeer.peer else {
                return .init(initialSize)
            }
            
            guard let chatOrMonoforum = renderedPeer.chatOrMonoforumMainPeer else {
                return .init(initialSize)
            }
            
            var customAction: ShortPeerRowItem.CustomAction?
            if peer.botInfo?.flags.contains(.hasWebApp) == true {
                customAction = .init(title: strings().chatListOpenMiniApp, callback: {
                    BrowserStateContext.get(arguments.context).open(tab: .mainapp(bot: .init(peer), source: .generic))
                    _ = arguments.context.engine.peers.addRecentlySearchedPeer(peerId: peer.id).start()
                })
            } else {
                customAction = nil
            }
            
            return RecentPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: entry.stableId, titleStyle: ControlStyle(font: .medium(.text), foregroundColor: secretChat != nil ? theme.colors.accent : theme.colors.text, highlightColor:.white), borderType: [.Right], drawCustomSeparator: drawBorder, isLookSavedMessage: true, drawLastSeparator: true, canRemoveFromRecent: false, controlAction: {
                arguments.setPeerAsTag(peer)
            }, contextMenuItems: {
                return peerContextMenuItems(peer: peer, pinnedItems: pinnedItems, arguments: arguments, isRecent: false)
            }, unreadBadge: badge, canAddAsTag: canAddAsTag, storyStats: storyStats, openStory: arguments.openStory, customAction: customAction, monoforumPeer: chatOrMonoforum)
        case let .topic(item, _, _, _, _):
            return SearchTopicRowItem(initialSize, stableId: entry.stableId, item: item, context: arguments.context)
        case let .recentlySearch(renderedPeer, _, secretChat, status, badge, drawBorder, storyStats, canRemoveRecent, isGrossingApp, isRecentApp):
            
            guard let peer = renderedPeer.peer else {
                return .init(initialSize)
            }
            
            guard let chatOrMonoforum = renderedPeer.chatOrMonoforumMainPeer else {
                return .init(initialSize)
            }
            
            var customAction: ShortPeerRowItem.CustomAction?
            if peer.botInfo?.flags.contains(.hasWebApp) == true {
                customAction = .init(title: strings().chatListOpenMiniApp, callback: {
                    BrowserStateContext.get(arguments.context).open(tab: .mainapp(bot: .init(peer), source: .generic))
                    _ = arguments.context.engine.peers.addRecentlySearchedPeer(peerId: peer.id).start()
                })
            } else {
                customAction = nil
            }
            
            return RecentPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: entry.stableId, photoSize: isGrossingApp ? NSMakeSize(30, 36) : NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(.text), foregroundColor: secretChat != nil ? theme.colors.accent : theme.colors.text, highlightColor:.white), statusStyle: ControlStyle(font:.normal(.text), foregroundColor: status.status.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: nil) as? NSColor ?? theme.colors.grayText, highlightColor:.white), status: status.status.string, borderType: [.Right], drawCustomSeparator: drawBorder, isLookSavedMessage: true, drawLastSeparator: true, canRemoveFromRecent: canRemoveRecent, controlAction: {
                if let secretChat = secretChat {
                    arguments.removeRecentPeerId(secretChat.peerId)
                } else {
                    arguments.removeRecentPeerId(peer.id)
                }
            }, contextMenuItems: {
                return peerContextMenuItems(peer: peer, pinnedItems: pinnedItems, arguments: arguments, isRecent: true)
            }, unreadBadge: badge, storyStats: storyStats, openStory: arguments.openStory, customAction: customAction, isGrossingApp: isGrossingApp, isRecentApp: isRecentApp, monoforumPeer: chatOrMonoforum)
        case let .savedMessages(peer):
            return RecentPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: entry.stableId, titleStyle: ControlStyle(font: .medium(.text), foregroundColor: theme.colors.text, highlightColor:.white), borderType: [.Right], drawCustomSeparator: true, isLookSavedMessage: true, contextMenuItems: {
                return peerContextMenuItems(peer: peer, pinnedItems: pinnedItems, arguments: arguments, isRecent: false)
            })
        case let .separator(text, index, state):
            let right:String?
            switch state {
            case .short:
                right = strings().separatorShowMore
            case .all:
                right = strings().separatorShowLess
            case .clear:
                right = strings().separatorClear
            case let .custom(text, _):
                right = text
            case let .dropdown(text, _):
                right = text
            default:
                right = nil
            }
            return SeparatorRowItem(initialSize, ChatListSearchEntryStableId.separator(index), string: text.uppercased(), right: right, state: state, border: [.Right], menuItems: {
                var items: [ContextMenuItem] = []
                
                switch state {
                case let .dropdown(_, _items):
                    for item in _items {
                        items.append(ContextMenuItem(item.title, handler: item.action, state: item.selected ? .on : nil))
                    }
                default:
                    break
                }
                return items
            })
        case let .emptySearch(isLoading):
            return SearchEmptyRowItem(initialSize, stableId: ChatListSearchEntryStableId.emptySearch, isLoading: isLoading, border: [.Right])
        case let .emptyList(listType):
            let attr = NSMutableAttributedString()
            
            let text1: String
            let text2: String
            switch listType {
            case .bots:
                text1 = strings().chatListAppsSearchEmptyTitle
                text2 = strings().chatListAppsSearchEmptyInfo
            case .channels:
                text1 = strings().chatListChannelSearchEmptyTitle
                text2 = strings().chatListChannelSearchEmptyInfo
            }
            
            attr.append(string: text1, color: theme.colors.darkGrayText, font: .medium(.header))
            attr.append(string: "\n")
            attr.append(string: text2, color: theme.colors.darkGrayText, font: .normal(.text))
            return AnimatedStickerHeaderItem(initialSize, stableId: ChatListSearchEntryStableId.emptySearch, context: arguments.context, sticker: LocalAnimatedSticker.duck_empty, text: attr, bgColor: theme.colors.background, isFullView: true)
        case let .topPeers(_, articlesEnabled, unreadArticles, selfPeer, peers, unread, online):
            return PopularPeersRowItem(initialSize, stableId: entry.stableId, context: arguments.context, selfPeer: selfPeer, articlesEnabled: articlesEnabled, unreadArticles: unreadArticles, peers: peers, unread: unread, online: online, action: { type in
                arguments.openTopPeer(type)
            })
        case let .foundStories(state, _, query):
            return SearchStoryFoundItem(initialSize, stableId: entry.stableId, list: state, context: arguments.context, query: query, action: {
                arguments.openStorySearch(state)
            })
        case let .disclaimer(text):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, height: 50, text: .markdown(text, linkHandler: { link in
                if link == "grossing" {
                    alert(for: arguments.context.window, header: strings().botGrossingDisclaimerAlertHeader, info: strings().botGrossingDisclaimerAlertText, ok: strings().botGrossingDisclaimerAlertOk)
                }
            }), alignment: .center, centerViewAlignment: true)
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


struct SearchTags : Hashable {
    
    enum ListType : Equatable {
        case channels
        case bots
    }
    
    let messageTags:MessageTags?
    let peerTag: PeerId?
    let listType: ListType?
    let text: String?
    let publicPosts: Bool
    let myMessages: Bool
    init(messageTags: MessageTags?, peerTag: PeerId?, listType: ListType? = nil, text: String? = nil, publicPosts: Bool = false, myMessages: Bool = false) {
        self.messageTags = messageTags
        self.peerTag = peerTag
        self.listType = listType
        self.text = text
        self.publicPosts = publicPosts
        self.myMessages = myMessages
    }
    
    func withUpdatedPeerTag(_ peerTag: PeerId?) -> SearchTags {
        return .init(messageTags: self.messageTags, peerTag: peerTag, listType: self.listType, text: self.text, publicPosts: self.publicPosts, myMessages: self.myMessages)
    }
    
    var isEmpty: Bool {
        return messageTags == nil && peerTag == nil && text == nil
    }
    
    func scope(_ value: SearchController.MessaagesSourceValue) -> TelegramSearchPeersScope {
        if let listType {
            switch listType {
            case .channels:
                return .channels
            case .bots:
                return .everywhere
            }
        } else {
            return value.scope
        }
        
    }
    
    func location(_ value: SearchController.MessaagesSourceValue) -> SearchMessagesLocation {
        if let peerTag = peerTag {
            return .peer(peerId: peerTag, fromId: nil, tags: messageTags, reactions: nil, threadId: nil, minDate: nil, maxDate: nil)
        } else {
            return .general(scope: scope(value), tags: messageTags, minDate: nil, maxDate: nil)
        }
    }
    
}

private struct SearchAdState : Equatable {
    var exclude: Set<Data> = Set()
    var excludeAll: Bool = false
}



class SearchController: GenericViewController<TableView>,TableViewDelegate {
    
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    
    var defaultQuery: String? = nil
    
    private let context:AccountContext
    private var marked: Bool = false
    private var arguments:SearchControllerArguments!
    private var open:(UIChatListEntryId?, MessageId?, Bool) -> Void = {_,_,_  in}
    private let target: Target
    private let searchQuery:ValuePromise<String?> = ValuePromise(nil, ignoreRepeated: true)
    private var query: String? = nil
    private let openPeerDisposable:MetaDisposable = MetaDisposable()
    private let statePromise:Promise<(SeparatorBlockState,SeparatorBlockState)> = Promise((SeparatorBlockState.short, SeparatorBlockState.short))
    private let disposable:MetaDisposable = MetaDisposable()
    private let pinnedPromise: ValuePromise<[PinnedItemId]> = ValuePromise([], ignoreRepeated: true)
    
    private let isRevealed: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    private let isChannelsRevealed: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)

    private let globalTagsValue: ValuePromise<SearchTags> = ValuePromise(ignoreRepeated: true)

    
    enum MessaagesSourceValue {
        case allChats
        case privateChats
        case groupChats
        case channels
        
        var string: String {
            switch self {
            case .allChats:
                return strings().searchFilterAllChats
            case .privateChats:
                return strings().searchFilterPrivateChats
            case .groupChats:
                return strings().searchFilterGroupChats
            case .channels:
                return strings().searchFilterChannels
            }
        }
        
        var scope: TelegramSearchPeersScope {
            switch self {
            case .allChats:
                return .everywhere
            case .privateChats:
                return .privateChats
            case .groupChats:
                return .groups
            case .channels:
                return .channels
            }
        }
        
    }
    private let messagesSourceValue: ValuePromise<MessaagesSourceValue> = ValuePromise(.allChats, ignoreRepeated: true)

    private let searchAdState = ValuePromise<SearchAdState>(.init(), ignoreRepeated: true)
    

    
    
    private var globalStorySearchContext: SearchStoryListContext?
    private let globalStorySearchState:Promise<StoryListContext.State?> = Promise(nil)
    
    let searchMessagesState: ValuePromise<CachedSearchMessages?> = ValuePromise(nil)
    let searchMessagesStateValue: Atomic<CachedSearchMessages?> = Atomic(value: nil)

    
    var setPeerAsTag: ((Peer?)->Void)? = nil
    
    var pinnedItems:[PinnedItemId] = [] {
        didSet {
            pinnedPromise.set(pinnedItems)
        }
    }
    
    let isLoading = Promise<Bool>(false)
    private(set) var searchTags: SearchTags?
    
    public func updateSearchTags(_ globalTags: SearchTags) {
       // self.query = search
        self._messagesValue.set(.single((ExternalSearchMessages(), false)))
        self.globalTagsValue.set(globalTags)
        self.searchTags = globalTags
    }
    
    func setCachedMessages(_ cached: CachedSearchMessages) {
        self.searchMessagesState.set(cached)
        _ = self.searchMessagesStateValue.modify({ _ in return cached })
    }
    
    private var _messagesValue:Promise<(ExternalSearchMessages?, Bool)> = Promise()
    
    var externalSearchMessages:Signal<ExternalSearchMessages?, NoError> {
        return combineLatest(self._messagesValue.get() |> filter { $0.1 } |> map { $0.0 }, self.globalTagsValue.get() |> map { $0.messageTags }) |> map {
            return $0.0?.withUpdatedTags($0.1)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.delegate = self
        genericView.needUpdateVisibleAfterScroll = true
        //genericView.border = [.Right]
        
        request(with: self.defaultQuery)

        
        
        genericView.getBackgroundColor = {
            theme.colors.background
        }
        
        let context = self.context
        let options = self.options
        let target = self.target
        
        let searchMessagesState = self.searchMessagesState
        let searchMessagesStateValue = self.searchMessagesStateValue
        
        let messagesSourceValue = messagesSourceValue.get()
        let searchAdState = self.searchAdState.get()


        let isRevealed = self.isRevealed.get()
        let isChannelsRevealed = self.isChannelsRevealed.get()

        let cachedData: Atomic<SearchCacheData> = Atomic(value: SearchCacheData())
        
        let arguments = self.arguments!
        let statePromise = self.statePromise.get()
        let atomicSize = self.atomicSize
        let previousSearchItems = Atomic<[AppearanceWrapperEntry<ChatListSearchEntry>]>(value: [])
        let globalStorySearchState = self.globalStorySearchState.get()

        
        let searchItems = combineLatest(globalTagsValue.get(), searchQuery.get(), viewOnStage |> filter { $0 } |> distinctUntilChanged) |> mapToSignal { globalTags, query, _ -> Signal<([ChatListSearchEntry], Bool, Bool, SearchMessagesState?, SearchMessagesResult?), NoError> in
            let query = query ?? ""
            var ids:[PeerId:PeerId] = [:]
            if !query.isEmpty || !globalTags.isEmpty {
                

                
                let foundQueryPeers: Promise<Peer?> = Promise()
                
                let callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void = { peerId, _, _, _ in }
                
                let link = inApp(for: query as NSString, context: context, peerId: nil, openInfo: callback, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
                
                switch link {
                case let .followResolvedName(_, username, _, _, context, _, _):
                    foundQueryPeers.set(resolveUsername(username: username, context: context))
                default:
                    foundQueryPeers.set(.single(nil))
                }
                
                var all = query.transformKeyboard
                all.insert(query.lowercased(), at: 0)
                all = all.uniqueElements
                let localPeers:Signal<([RenderedPeer], [PeerId: UnreadSearchBadge], EngineDataMap<TelegramEngine.EngineData.Item.Peer.StoryStats>.Result), NoError> = combineLatest(all.map {
                    return context.account.postbox.searchPeers(query: $0) |> map {
                        $0.filter { peer in
                            if let listType = globalTags.listType {
                                switch listType {
                                case .channels:
                                    return peer.peer?.isChannel == true
                                case .bots:
                                    return peer.peer?.botInfo?.flags.contains(.hasWebApp) == true
                                }
                            } else {
                                return true
                            }
                        }
                    }
                }) |> map { result in
                    return Array(result.joined())
                } |> mapToSignal { peers in
                    return combineLatest(peers.map { context.account.postbox.peerView(id: $0.peerId) |> take(1) }) |> map { ($0, peers) }
                } |> mapToSignal { peerViews, peers in
                    
                    let items: [UnreadMessageCountsItem] = peers.map { peer in
                        return .peer(id: peer.peerId, handleThreads: peer.peer?.isForum == true)
                    }
                    
                    return context.account.postbox.unreadMessageCountsView(items: items) |> take(1) |> map { values -> ([RenderedPeer], [PeerId: UnreadSearchBadge]) in
                        var unread:[PeerId: UnreadSearchBadge] = [:]
                        for peerView in peerViews {
                            let isMuted = peerView.isMuted
                            let unreadCount = values.count(for: .peer(id: peerView.peerId, handleThreads: peerViewMainPeer(peerView)?.isForum == true))
                            if let unreadCount = unreadCount, unreadCount > 0 {
                                unread[peerView.peerId] = isMuted ? .muted(unreadCount) : .unmuted(unreadCount)
                            }
                        }
                        return (peers, unread)
                    } |> mapToSignal { peers, unread in
                        
                        return context.engine.data.subscribe(
                            EngineDataMap(
                                peers.map { $0.peerId }.map(TelegramEngine.EngineData.Item.Peer.StoryStats.init(id:))
                            )
                        ) |> map { stats in
                            return (peers, unread, stats)
                        }
                    }
                }
                
                
                let foundLocalPeers: Signal<[ChatListSearchEntry], NoError>
                let foundRemotePeers: Signal<([ChatListSearchEntry], [ChatListSearchEntry], Bool), NoError>
                
                
                
                let location: SearchMessagesLocation
                switch target {
                case let .common(groupId):
                    foundLocalPeers = query.hasPrefix("#") || query.hasPrefix("$") || !options.contains(.chats) || !globalTags.isEmpty ? .single([]) : combineLatest(localPeers, context.account.postbox.loadedPeerWithId(context.peerId), foundQueryPeers.get())
                        |> map { peers, accountPeer, inLinkPeer -> [ChatListSearchEntry] in
                            var entries: [ChatListSearchEntry] = []
                            
                            
                            if query.isSavedMessagesText {
                                entries.append(.savedMessages(accountPeer))
                                ids[accountPeer.id] = accountPeer.id
                            }
                            
                            var index = 1
                            
                            if let peer = inLinkPeer {
                                if ids[peer.id] == nil {
                                    ids[peer.id] = peer.id
                                    entries.append(.localPeer(.init(peer: peer), index, nil, .none, true, false, nil))
                                    index += 1
                                }
                            }
                            
                            for rendered in peers.0 {
                                if ids[rendered.peerId] == nil {
                                    ids[rendered.peerId] = rendered.peerId
                                    if let peer = rendered.chatMainPeer {
                                        var wrapper:SearchSecretChatWrapper? = nil
                                        if rendered.peers[rendered.peerId] is TelegramSecretChat {
                                            wrapper = SearchSecretChatWrapper(peerId: rendered.peerId)
                                        }
                                        entries.append(.localPeer(rendered, index, wrapper, peers.1[rendered.peerId] ?? .none, true, true, peers.2[peer.id] ?? nil))
                                        index += 1
                                    }
                                    
                                }
                                
                            }
                            return entries
                    }
                    
                    if groupId != .root {
                        location = .group(groupId: groupId, tags: nil, minDate: nil, maxDate: nil)
                        foundRemotePeers = .single(([], [], false))
                    } else {
                        location = globalTags.location(.allChats)
                        if globalTags.isEmpty {
                        
                            let adPeers: Signal<[AdPeer], NoError>
                            
                            if query.length >= 4 {
                                adPeers = combineLatest(context.engine.peers.searchAdPeers(query: query), searchAdState) |> map { peers, state in
                                    let peers = peers.filter({
                                        !state.exclude.contains($0.opaqueId) && !state.excludeAll
                                    })
                                    return peers
                                }
                            } else {
                                adPeers = .single([])
                            }
                            
                            foundRemotePeers = query.hasPrefix("#") || query.hasPrefix("$") || !options.contains(.chats) || !globalTags.isEmpty || globalTags.listType == .bots ? .single(([], [], false)) : .single(([], [], true)) |> then(combineLatest(context.engine.contacts.searchRemotePeers(query: query, scope: globalTags.scope(.allChats)), adPeers)
                                |> delay(0.2, queue: prepareQueue)
                                |> map { (founds, adPeers) -> ([FoundPeer], [FoundPeer], [AdPeer]) in
                                    return (founds.0.filter { found -> Bool in
                                        let first = ids[found.peer.id] == nil
                                        ids[found.peer.id] = found.peer.id
                                        return first
                                    }, founds.1.filter { found -> Bool in
                                        let first = ids[found.peer.id] == nil
                                        ids[found.peer.id] = found.peer.id
                                        return first
                                    }, adPeers)
                                
                                 }
                                |> mapToSignal { peers -> Signal<([FoundPeer], [FoundPeer], [PeerId : UnreadSearchBadge], [AdPeer]), NoError> in
                                    let all = peers.0 + peers.1
                                    return combineLatest(all.map { context.account.postbox.peerView(id: $0.peer.id) |> take(1) }) |> mapToSignal { peerViews in
                                        return context.account.postbox.unreadMessageCountsView(items: all.map {.peer(id: $0.peer.id, handleThreads: $0.peer.isForum)}) |> take(1) |> map { values in
                                            var unread:[PeerId: UnreadSearchBadge] = [:]
                                            outer: for peerView in peerViews {
                                                let isMuted = peerView.isMuted
                                                let unreadCount = values.count(for: .peer(id: peerView.peerId, handleThreads: peerViewMainPeer(peerView)?.isForum == true))
                                                if let unreadCount = unreadCount, unreadCount > 0 {
                                                    if let peer = peerViewMainPeer(peerView) {
                                                        if let peer = peer as? TelegramChannel {
                                                            inner: switch peer.participationStatus {
                                                            case .member:
                                                                break inner
                                                            default:
                                                                continue outer
                                                            }
                                                        }
                                                        if let peer = peer as? TelegramGroup {
                                                            inner: switch peer.membership {
                                                            case .Member:
                                                                break inner
                                                            default:
                                                                continue outer
                                                            }
                                                        }
                                                    }
                                                    unread[peerView.peerId] = isMuted ? .muted(unreadCount) : .unmuted(unreadCount)
                                                }
                                            }
                                            return (peers.0, peers.1, unread, peers.2)
                                        }
                                    }
                                }
                                |> map { _local, _remote, unread, adPeers -> ([ChatListSearchEntry], [ChatListSearchEntry], Bool) in
                                    var local: [ChatListSearchEntry] = []
                                    var index = 1000
                                    for peer in _local {
                                        local.append(.localPeer(.init(peer), index, nil, unread[peer.peer.id] ?? .none, true, true, nil))
                                        index += 1
                                    }
                                    
                                    var remote: [ChatListSearchEntry] = []
                                    index = 10001
                                    if !adPeers.isEmpty {
                                        for adPeer in adPeers {
                                            remote.append(.globalPeer(.init(peer: adPeer.peer._asPeer(), subscribers: nil), .none, index, adPeer))
                                            index += 1
                                        }
                                    }
                                
                                    for peer in _remote {
                                        remote.append(.globalPeer(peer, unread[peer.peer.id] ?? .none, index, nil))
                                        index += 1
                                    }
                                    return (local, remote, false)
                                })
                        } else {
                            foundRemotePeers = .single(([], [], false))
                        }
                    }
                case .savedMessages:
                    foundRemotePeers = context.engine.messages.searchLocalSavedMessagesPeers(query: query, indexNameMapping: [:]) |> map { peers in
                        var local: [ChatListSearchEntry] = []
                        var index = 1000
                        for item in peers {
                            
                            local.append(.localPeer(.init(peer: item._asPeer()), index, nil, .none, false, false, nil))
                            index += 1
                        }
                        return ([], local, false)
                    }
                    foundLocalPeers = .single([])
//                    location = .general(tags: nil, minDate: nil, maxDate: nil)
                    location = .peer(peerId: context.peerId, fromId: nil, tags: globalTags.messageTags, reactions: nil, threadId: nil, minDate: nil, maxDate: nil)
                case let .forum(peerId):
                    location = .peer(peerId: peerId, fromId: nil, tags: globalTags.messageTags, reactions: nil, threadId: nil, minDate: nil, maxDate: nil)
                    foundRemotePeers = .single(([], [], false))
                    
                    let topics: Signal<[EngineChatList.Item], NoError> = chatListViewForLocation(chatListLocation: .forum(peerId: peerId), location: .Initial(0, nil), filter: nil, account: context.account) |> filter { view in
                        return !view.list.isLoading
                    } |> take(1) |> map { view in
                        
                        return view.list.items.reversed().filter { item in
                            let string = item.threadData?.info.title ?? ""
                            
                            var all = query.lowercased().transformKeyboard
                            all.insert(query.lowercased(), at: 0)
                            all = all.uniqueElements
                            
                            return all.contains(where: { value in
                                return string.lowercased().contains(value)
                            })
                        }
                    }
                    foundLocalPeers = topics |> map { items in
                        var local: [ChatListSearchEntry] = []
                        var index = 1000
                        for item in items {
                            let badge: UnreadSearchBadge
                            if let count = item.readCounters?.count, count > 0 {
                                if item.isMuted {
                                    badge = .muted(count)
                                } else {
                                    badge = .unmuted(count)
                                }
                            } else {
                                badge = .none
                            }
                            local.append(.topic(item, index, badge, true, false))
                            index += 1
                        }
                        return local
                    }
                }
                
                
                let remoteSearch = combineLatest(searchMessagesState.get(), messagesSourceValue) |> mapToSignal { state, messagesSourceValue -> Signal<([ChatListSearchEntry], Bool, SearchMessagesState?, SearchMessagesResult?), NoError> in
                    
                    var signal: Signal<(SearchMessagesResult, SearchMessagesState), NoError>
                    
                    if globalTags.publicPosts {
                        let text = (globalTags.text ?? query)
                        signal = context.engine.messages.searchHashtagPosts(hashtag: text.replacingOccurrences(of: "[#$]", with: "", options: .regularExpression), state: state?.state, limit: 100)
                        |> delay(0.2, queue: prepareQueue)
                    } else {
                        signal = context.engine.messages.searchMessages(location: location.withUpdatedSouce(messagesSourceValue), query: globalTags.text ?? query, state: state?.state)
                        |> delay(0.2, queue: prepareQueue)
                    }
                    
                    if let state {
                        signal = .single((state.result, state.state)) |> then(signal)
                    }
                    
                    return signal
                        |> map { result -> ([ChatListSearchEntry], Bool, SearchMessagesState?, SearchMessagesResult?) in
                            
                            var entries: [ChatListSearchEntry] = []
                            var index = 20001
                            for message in result.0.messages {
                                switch target {
                                case .forum:
                                    if let threadInfo = result.0.threadInfo[message.id] {
                                        entries.append(.message(message, query, result.0.readStates[message.id.peerId], threadInfo, index))
                                        index += 1
                                    }
                                case .common:
                                    entries.append(.message(message, query, result.0.readStates[message.id.peerId], result.0.threadInfo[message.id], index))
                                    index += 1
                                case .savedMessages:
                                    entries.append(.message(message, query, result.0.readStates[message.id.peerId], result.0.threadInfo[message.id], index))
                                    index += 1
                                }
                                
                            }
                            
                            return (entries, false, result.1, result.0)
                    }
                }
                
                let foundRemoteMessages: Signal<([ChatListSearchEntry], Bool, SearchMessagesState?, SearchMessagesResult?), NoError>
                
                foundRemoteMessages = !options.contains(.messages) ? .single(([], false, nil, nil)) : .single(([], true, nil, nil)) |> then(remoteSearch)

                
                
                let hashtagSearch: Signal<([ChatListSearchEntry], Bool, CachedSearchMessages?), NoError>
                if globalTags.isEmpty, query.hasPrefix("#") || query.hasPrefix("$") {
                    hashtagSearch = .single(([], false, nil)) |> then(context.engine.messages.searchHashtagPosts(hashtag: query.replacingOccurrences(of: "[#$]", with: "", options: .regularExpression), state: nil, limit: 100) |> map { result in
                        var entries: [ChatListSearchEntry] = []
                        var index = 20001
                        for message in result.0.messages {
                            switch target {
                            case .forum:
                                if let threadInfo = result.0.threadInfo[message.id] {
                                    entries.append(.message(message, query, result.0.readStates[message.id.peerId], threadInfo, index))
                                    index += 1
                                }
                            case .common:
                                entries.append(.message(message, query, result.0.readStates[message.id.peerId], result.0.threadInfo[message.id], index))
                                index += 1
                            case .savedMessages:
                                entries.append(.message(message, query, result.0.readStates[message.id.peerId], result.0.threadInfo[message.id], index))
                                index += 1
                            }
                            
                        }
                        return (entries, result.0.totalCount > 3, CachedSearchMessages(result: result.0, state: result.1))
                    } |> delay(0.2, queue: .mainQueue()))
                } else {
                    hashtagSearch = .single(([], false, nil))
                }
                
                return combineLatest(queue: prepareQueue, foundLocalPeers, foundRemotePeers, foundRemoteMessages, isRevealed, globalStorySearchState, hashtagSearch, messagesSourceValue)
                    |> map { localPeers, remotePeers, remoteMessages, isRevealed, storySearchState, hashtagSearch, messagesSourceValue -> ([ChatListSearchEntry], Bool, SearchMessagesState?, SearchMessagesResult?) in
                        
                        cachedData.with { value -> Void in
                            value.cacheMessages(remoteMessages.0, for: .key(query: query, tags: globalTags))
                            value.cacheLocalPeers(remotePeers.0, for: query)
                            value.cacheRemotePeers(remotePeers.1, for: query)
                        }
                        
                       
                        var entries:[ChatListSearchEntry] = []
                        
                        if let storySearchState, !storySearchState.items.isEmpty, globalTags.publicPosts || query.hasPrefix("#") || query.hasPrefix("$") {
                            entries.append(.foundStories(storySearchState, index: 0, query: query))
                        }
                        
                        
                   
                        
                        
                        if !localPeers.isEmpty || !remotePeers.0.isEmpty {
                            
                            let peers = (localPeers + remotePeers.0)

                            switch target {
                            case .forum:
                                entries.append(.separator(text: strings().searchSeparatorTopics, index: 0, state: .none))
                            default:
                                entries.append(.separator(text: strings().searchSeparatorChatsAndContacts, index: 0, state: .none))
                            }
                            if !remoteMessages.0.isEmpty {
                                entries += peers
                            } else {
                                entries += peers
                            }
                        }
                        if !remotePeers.1.isEmpty {
                            
                            let state: SeparatorBlockState
                            if remotePeers.1.count > 5 {
                                if isRevealed {
                                    state = .all
                                } else {
                                    state = .short
                                }
                            } else {
                                state = .none
                            }

                            entries.append(.separator(text: strings().searchSeparatorGlobalPeers, index: 10000, state: state))
                            
                            if !isRevealed {
                                entries += remotePeers.1.prefix(5)
                            } else {
                                entries += remotePeers.1
                            }
                        }
                        
                        if !hashtagSearch.0.isEmpty, let cached = hashtagSearch.2 {
                            entries.append(.separator(text: strings().chatHashtagPublicPosts, index: 15000, state: hashtagSearch.1 ? .custom(strings().separatorShowMore, .showPublicPosts(cached)) : .none))
                            entries += hashtagSearch.0.prefix(3)
                        }
                        
                        
                        if !remoteMessages.0.isEmpty {
                            let blockState: SeparatorBlockState
                            if globalTags.publicPosts || globalTags.myMessages {
                                blockState = .custom(strings().searchSeparatorShowAsMessages, .showAsMessages(onlyMy: globalTags.myMessages))
                            } else {
                                blockState = .dropdown(strings().searchFilterFrom(messagesSourceValue.string), [.init(title: MessaagesSourceValue.allChats.string, selected: messagesSourceValue == .allChats, action: {
                                    arguments.toggleMessageSourceValue(.allChats)
                                }),
                                .init(title: MessaagesSourceValue.privateChats.string, selected: messagesSourceValue == .privateChats, action: {
                                    arguments.toggleMessageSourceValue(.privateChats)
                                }),
                                .init(title: MessaagesSourceValue.groupChats.string, selected: messagesSourceValue == .groupChats, action: {
                                    arguments.toggleMessageSourceValue(.groupChats)
                                }),
                                .init(title: MessaagesSourceValue.channels.string, selected: messagesSourceValue == .channels, action: {
                                    arguments.toggleMessageSourceValue(.channels)
                                })])
                            }
                            entries.append(.separator(text: strings().searchSeparatorMessages, index: 20000, state: blockState))
                            entries += remoteMessages.0
                        }
                        if entries.isEmpty && !remotePeers.2 && !remoteMessages.1 {
                            entries.append(.emptySearch(isLoading: false))
                        } else if remotePeers.2 || remoteMessages.1 {
                            entries.append(.emptySearch(isLoading: true))
                        }

                        return (entries, remotePeers.2 || remoteMessages.1, remoteMessages.2, remoteMessages.3)
                    } |> map { value in
                        return (value.0, value.1, false, value.2, value.3)
                    }
                
            } else if query.isEmpty, let listType = globalTags.listType {
                let channels: Signal<[FoundPeer], NoError> = context.engine.peers.recommendedChannels(peerId: nil) |> map {
                    $0?.channels.map {
                        .init(peer: $0.peer._asPeer(), subscribers: $0.subscribers)
                    } ?? []
                }
                
                let recentApps = context.engine.peers.recentApps() |> mapToSignal { recentAppIds in
                    return context.engine.data.subscribe(
                        EngineDataMap(
                            recentAppIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                            }
                        )) |> map  {
                            (recentAppIds, $0)
                        }
                }
                
                let recommendedApps = context.engine.peers.recommendedAppPeerIds() |> mapToSignal { allRecommendedAppIds in
                    if let allRecommendedAppIds {
                        return context.engine.data.subscribe(
                            EngineDataMap(
                                allRecommendedAppIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                    return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                                }
                            )) |> map  {
                                (allRecommendedAppIds, $0)
                            }
                    } else {
                        return .single(([], [:]))
                    }
                }
                
                let localChannels = context.engine.messages.getAllLocalChannels(count: 100) |> mapToSignal { allChannelIds in
                    return context.engine.data.subscribe(
                        EngineDataMap(
                            allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.NotificationSettings in
                                return TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerUnreadCount in
                                return TelegramEngine.EngineData.Item.Messages.PeerUnreadCount(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.ParticipantCount in
                                return TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.StoryStats in
                                return TelegramEngine.EngineData.Item.Peer.StoryStats(id: peerId)
                            }
                        )
                    ) |> map { (allChannelIds, $0) }

                }
                     

                
                
                return combineLatest(queue: prepareQueue, channels, isChannelsRevealed, localChannels, recommendedApps, recentApps) |> map { channels, isChannelsRevealed, localChannels, recommendedApps, recentApps -> ([ChatListSearchEntry], Bool) in
                    var entries:[ChatListSearchEntry] = []
                    var i:Int = 0
                    var ids:[PeerId:PeerId] = [:]
                    
                    
                    let header: String
                    let popularText: String
                    switch listType {
                    case .bots:
                        header = strings().searchSeparatorAppsYouUse
                        popularText = strings().searchSeparatorAppsPopular
                        
                        if !recentApps.0.isEmpty {
                            let list = isChannelsRevealed ? recentApps.0 : Array(recentApps.0.prefix(5))
                            
                            if recentApps.0.count > 5 {
                                entries.append(.separator(text: header, index: -1, state: !isChannelsRevealed ? .short : .all))
                                
                                for botId in list {
                                    let peer = recentApps.1[botId] ?? nil

                                    if let peer = peer?._asPeer() as? TelegramUser {
                                        if ids[botId] == nil {
                                            ids[botId] = botId
                                            let stringTheme = PeerStatusStringTheme(titleFont: .medium(.title))
                                            let subCount = Int(peer.subscriberCount ?? 0)
                                            let status = peer.subscriberCount == nil ? strings().presenceBot : strings().peerStatusUsersCountable(subCount).replacingOccurrences(of: "\(subCount)", with: subCount.formattedWithSeparator)
                                            let result = PeerStatusStringResult(.initialize(string: peer.displayTitle, color: stringTheme.titleColor, font: stringTheme.titleFont), .initialize(string: status))

                                            entries.append(.recentlySearch(.init(peer: peer), i, nil, result, .none, true, nil, false, isGrossingApp: false, isRecentApp: true))
                                            i += 1

                                        }
                                    }
                                }
                            }
                        }
                        
                        if recommendedApps.0.count > 0 {
                            entries.append(.separator(text: popularText, index: i, state: .none))
                            i += 1
                            for botId in recommendedApps.0 {
                                let peer = recommendedApps.1[botId] ?? nil

                                if let peer = peer?._asPeer() as? TelegramUser {
                                    if ids[botId] == nil {
                                        ids[botId] = botId
                                        let stringTheme = PeerStatusStringTheme(titleFont: .medium(.title))
                                        let subCount = Int(peer.subscriberCount ?? 0)
                                        let status = peer.subscriberCount == nil ? strings().presenceBot : strings().peerStatusUsersCountable(subCount).replacingOccurrences(of: "\(subCount)", with: subCount.formattedWithSeparator)
                                        let result = PeerStatusStringResult(.initialize(string: peer.displayTitle, color: stringTheme.titleColor, font: stringTheme.titleFont), .initialize(string: status))

                                        entries.append(.recentlySearch(.init(peer: peer), i, nil, result, .none, true, nil, false, isGrossingApp: true, isRecentApp: false))
                                        i += 1

                                    }
                                }
                            }
                        }
                        
                        if entries.isEmpty {
                            entries.append(.emptyList(listType: listType))
                        } else {
                            entries.append(.disclaimer(strings().botGrossingDisclaimer))
                        }
                        
                    case .channels:
                        header = strings().searchSeparatorChannelsJoined
                        popularText = strings().searchSeparatorRecommended
                        
                        if !localChannels.0.isEmpty {
                            
                            let list = isChannelsRevealed ? localChannels.0 : Array(localChannels.0.prefix(upTo: 5))
                            
                            if localChannels.0.count > 5 {
                                entries.append(.separator(text: header, index: -1, state: !isChannelsRevealed ? .short : .all))
                            }
                            
                            for channelId in list {
                                let subscribers = localChannels.1.3[channelId] ?? 0
                                let peer = localChannels.1.0[channelId] ?? nil

                                let storyStats = localChannels.1.4[channelId] ?? nil

                                if let peer = peer {
                                    if ids[channelId] == nil {
                                        ids[channelId] = channelId
                                        let stringTheme = PeerStatusStringTheme(titleFont: .medium(.title))
                                        let subCount = Int(subscribers ?? 0)
                                        let status = subscribers == nil ? strings().peerStatusChannel : strings().peerStatusSubscribersCountable(subCount).replacingOccurrences(of: "\(subCount)", with: subCount.formattedWithSeparator)
                                        let result = PeerStatusStringResult(.initialize(string: peer._asPeer().displayTitle, color: stringTheme.titleColor, font: stringTheme.titleFont), .initialize(string: status))

                                        entries.append(.recentlySearch(.init(peer: peer._asPeer()), i, nil, result, .none, true, storyStats, false, isGrossingApp: false, isRecentApp: false))
                                        i += 1

                                    }
                                }
                            }
                        }
                                                                
                        if channels.count > 0 {
                            entries.append(.separator(text: popularText, index: i, state: .none))
                            i += 1
                            for channel in channels {
                                if ids[channel.peer.id] == nil {
                                    ids[channel.peer.id] = channel.peer.id
                                    let stringTheme = PeerStatusStringTheme(titleFont: .medium(.title))
                                    let subCount = Int(channel.subscribers ?? 0)
                                    let status = channel.subscribers == nil ? strings().peerStatusChannel : strings().peerStatusSubscribersCountable(subCount).replacingOccurrences(of: "\(subCount)", with: subCount.formattedWithSeparator)
                                    let result = PeerStatusStringResult(.initialize(string: channel.peer.displayTitle, color: stringTheme.titleColor, font: stringTheme.titleFont), .initialize(string: status))

                                    entries.append(.recentlySearch(.init(channel), i, nil, result, .none, true, nil, false, isGrossingApp: false, isRecentApp: false))
                                    i += 1

                                }
                            }
                        }
                        
                        if entries.isEmpty {
                            entries.append(.emptyList(listType: listType))
                        }
                    }
                    
                    
                    
                    return (entries.sorted(by: <), false)
                } |> map {value in
                    return (value.0, value.1, true, nil, nil)
                }
                
            } else if options.contains(.chats), target.isCommon {

                let recently = context.engine.peers.recentlySearchedPeers() |> mapToSignal { recently -> Signal<[PeerView], NoError> in
                    return combineLatest(recently.map {context.account.postbox.peerView(id: $0.peer.peerId)})
                } |> map { peerViews -> [PeerView] in
                    return peerViews.filter { peerView in
                        if let group = peerViewMainPeer(peerView) as? TelegramGroup, group.migrationReference != nil {
                            return false
                        }
                        return true
                    }
                } |> mapToSignal { peerViews -> Signal<([PeerView], [PeerId: UnreadSearchBadge], EngineDataMap<TelegramEngine.EngineData.Item.Peer.StoryStats>.Result), NoError> in
                    return context.account.postbox.unreadMessageCountsView(items: peerViews.map {.peer(id: $0.peerId, handleThreads: peerViewMainPeer($0)?.isForum == true)}) |> map { values -> ([PeerView], [PeerId: UnreadSearchBadge]) in
                            
                            var unread:[PeerId: UnreadSearchBadge] = [:]
                            for peerView in peerViews {
                                let isMuted = peerView.isMuted
                                let unreadCount = values.count(for: .peer(id: peerView.peerId, handleThreads: peerViewMainPeer(peerView)?.isForum == true))
                                if let unreadCount = unreadCount, unreadCount > 0 {
                                    unread[peerView.peerId] = isMuted ? .muted(unreadCount) : .unmuted(unreadCount)
                                }
                            }
                            return (peerViews, unread)
                    } |> mapToSignal { peerViews, unread in
                        return context.engine.data.subscribe(
                            EngineDataMap(
                                peerViews.map { $0.peerId }.map(TelegramEngine.EngineData.Item.Peer.StoryStats.init(id:))
                            )
                        ) |> map { stats in
                            return (peerViews, unread, stats)
                        }
                    }
                    
                } |> deliverOnPrepareQueue
                
                let top: Signal<([Peer], [PeerId : UnreadSearchBadge], [PeerId : Bool]), NoError> = context.engine.peers.recentPeers() |> mapToSignal { recent in
                    switch recent {
                    case .disabled:
                        return .single(([], [:], [:]))
                    case let .peers(peers):
                        return combineLatest(peers.map {context.account.postbox.peerView(id: $0.id)}) |> mapToSignal { peerViews -> Signal<([Peer], [PeerId: UnreadSearchBadge], [PeerId : Bool]), NoError> in
                            return context.account.postbox.unreadMessageCountsView(items: peerViews.map {.peer(id: $0.peerId, handleThreads: peerViewMainPeer($0)?.isForum == true)}) |> map { values in
                                    
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
                                            let unreadCount = values.count(for: .peer(id: peerView.peerId, handleThreads: peerViewMainPeer(peerView)?.isForum == true))
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
                
                return combineLatest(queue: prepareQueue, context.account.postbox.loadedPeerWithId(context.peerId), top, recently, statePromise) |> map { user, top, recent, state -> ([ChatListSearchEntry], Bool) in
                    var entries:[ChatListSearchEntry] = []
                    var i:Int = 0
                    var ids:[PeerId:PeerId] = [:]

                    ids[context.peerId] = context.peerId
                    
                    
                    entries.append(ChatListSearchEntry.topPeers(i, articlesEnabled: false, unreadArticles: 0, selfPeer: user, peers: top.0, unread: top.1, online: top.2))
                    
                    if recent.0.count > 0 {
                        entries.append(.separator(text: strings().searchSeparatorRecent, index: i, state: .clear))
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

                                    let dict: SimpleDictionary<PeerId, Peer> = .init(peerView.peers)
                                    
                                    let renderedPeer = RenderedPeer(peerId: peerView.peerId, peers: dict, associatedMedia: peerView.media)
                                    
                                    entries.append(.recentlySearch(renderedPeer, i, wrapper, result, recent.1[peerView.peerId] ?? .none, true, recent.2[peerView.peerId] ?? nil, true, isGrossingApp: false, isRecentApp: false))
                                    i += 1
                                }

                            }
                        }
                    }
                    
                    if entries.isEmpty {
                        entries.append(.emptySearch(isLoading: false))
                    }
                    
                    return (entries.sorted(by: <), false)
                } |> map { value in
                    return (value.0, value.1, true, nil, nil)
                }
            } else {
                switch target {
                case let .forum(peerId):
                    let topics: Signal<[EngineChatList.Item], NoError> = chatListViewForLocation(chatListLocation: .forum(peerId: peerId), location: .Initial(0, nil), filter: nil, account: context.account) |> filter { view in
                        return !view.list.isLoading
                    } |> map { view in
                        return view.list.items.reversed()
                    } |> take(1)
                    let foundLocalPeers: Signal<[ChatListSearchEntry], NoError> = topics |> map { items in
                        var local: [ChatListSearchEntry] = []
                        var index = 1000
                        for item in items {
                            let badge: UnreadSearchBadge
                            if let count = item.readCounters?.count, count > 0 {
                                if item.isMuted {
                                    badge = .muted(count)
                                } else {
                                    badge = .unmuted(count)
                                }
                            } else {
                                badge = .none
                            }
                            local.append(.topic(item, index, badge, true, false))
                            index += 1
                        }
                        return local
                    }
                    
                    return foundLocalPeers |> map {
                        return ($0, false, true, nil, nil)
                    }
                default:
                    return .single(([], false, true, nil, nil))
                }
            }
        }
        
        
        let transition = combineLatest(queue: prepareQueue, searchItems, appearanceSignal, context.globalPeerHandler.get() |> distinctUntilChanged, pinnedPromise.get()) |> map { value, appearance, location, pinnedItems in
            return (value.0.map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}, value.1, value.2 ? nil : location, value.2, pinnedItems, value.3, value.4)
        }
        |> map { entries, loading, location, animated, pinnedItems, searchMessagesState, searchMessagesResult -> (TableUpdateTransition, Bool, ChatLocation?, SearchMessagesState?, SearchMessagesResult?) in
            let transition = prepareEntries(from: previousSearchItems.swap(entries) , to: entries, arguments: arguments, pinnedItems: pinnedItems, initialSize: atomicSize.modify { $0 }, animated: animated, target: target)
            return (transition, loading, location, searchMessagesState, searchMessagesResult)
        } |> deliverOnMainQueue
        
        
        disposable.set(transition.start(next: { [weak self] (transition, loading, location, searchMessagesState, searchMessagesResult) in
            guard let `self` = self else {return}
            self.genericView.merge(with: transition)
            self.isLoading.set(.single(loading))
            if self.scrollupOnNextTransition {
                self.scrollup()
            }
            
            
            self.scrollupOnNextTransition = false
            if let searchMessagesResult, let searchMessagesState {
                _ = searchMessagesStateValue.swap(.init(result: searchMessagesResult, state: searchMessagesState))
            }
            
            if let searchMessagesState, let searchMessagesResult {
                self.currentMessagesSearchState = (searchMessagesResult, searchMessagesState)
            } else {
                self.currentMessagesSearchState = nil
            }
            
            self._messagesValue.set(.single((ExternalSearchMessages(messages: searchMessagesResult?.messages ?? [], count: searchMessagesResult?.totalCount ?? 0), searchMessagesResult != nil)))
            
            if let location = location {
                if !(self.genericView.selectedItem() is ChatListMessageRowItem) {
                    switch location {
                    case let .peer(peerId):
                        let item = self.genericView.item(stableId: ChatListSearchEntryStableId.globalPeerId(peerId)) ?? self.genericView.item(stableId: ChatListSearchEntryStableId.localPeerId(peerId))
                        if let item = item {
                            _ = self.genericView.select(item: item, notify: false, byClick: false)
                        }
                    case .thread:
                        break
                    }
                }
            } else if self.searchTags?.listType == nil || self.searchTags == nil {
                self.genericView.cancelSelection()
            }
            self.readyOnce()
        }))

        
        genericView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                if !target.isForum {
                    searchMessagesState.set(searchMessagesStateValue.swap(nil))
                }
            default:
                break
            }
        }
        
        
    }
    
    override func initializer() -> TableView {
        return TableView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), drawBorder: true);
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isLoading.set(.single(false))
        self.window?.remove(object: self, for: .UpArrow)
        self.window?.remove(object: self, for: .DownArrow)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
       
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            if self.window?.firstResponder?.className != "TGUIKit.SearchTextField" {
                return .rejected
            }
            
            if let highlighted = self.genericView.highlightedItem() {
                _ = self.genericView.select(item: highlighted)
                self.closeNext = true
                return .invoked
            } else if !self.marked {
                self.genericView.cancelSelection()
                self.genericView.selectNext()
                self.closeNext = true
                return .invoked
            }
            
            return .rejected
        }, with: self, for: .Return, priority: .modal)
        
        
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
        
      
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
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
        
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.window?.firstResponder?.className != "TGUIKit.SearchTextField" {
                return .rejected
            }
            self?.genericView.highlightNext(turnDirection: false)
            
            while self?.genericView.highlightedItem() is PopularPeersRowItem || self?.genericView.highlightedItem() is SeparatorRowItem {
                self?.genericView.highlightNext(turnDirection: false)
            }
            
            return .invoked
        }, with: self, for: .DownArrow, priority: .modal)
        
        
        self.window?.set(handler: { _ -> KeyHandlerResult in
            return .rejected
        }, with: self, for: .UpArrow, priority: .modal, modifierFlags: [.command])
        
        self.window?.set(handler: { _ -> KeyHandlerResult in
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
    
    enum Target {
        case common(PeerGroupId)
        case forum(PeerId)
        case savedMessages(PeerId)
        var isCommon: Bool {
            switch self {
            case .common:
                return true
            case .forum:
                return false
            case .savedMessages:
                return false
            }
        }
        var isForum: Bool {
            switch self {
            case .common:
                return false
            case .forum:
                return true
            case .savedMessages:
                return true
            }
        }
    }
    
    init(context: AccountContext, open:@escaping(UIChatListEntryId?, MessageId?, Bool) ->Void, options: AppSearchOptions = [.chats, .messages], frame:NSRect = NSZeroRect, target: Target = .common(.root), tags: SearchTags = .init(messageTags: nil, peerTag: nil)) {
        self.context = context
        self.open = open
        self.options = options
        self.target = target
        
        super.init(frame:frame)
        self.bar = .init(height: 0)
        
        var setPeerAsTag:((Peer?)->Void)? = nil

        
        let searchAdState = Atomic(value: SearchAdState())
        let updateSearchState: ((SearchAdState) -> SearchAdState) -> Void = { [weak self] f in
            self?.searchAdState.set(searchAdState.modify (f))
        }
        
        self.arguments = SearchControllerArguments(context: context, target: target, removeRecentPeerId: { peerId in
            _ = context.engine.peers.removeRecentlySearchedPeer(peerId: peerId).start()
        }, clearRecent: {
            verifyAlert_button(for: context.window, information: strings().searchConfirmClearHistory, successHandler: { _ in
                _ = (context.engine.peers.recentlySearchedPeers() |> take(1) |> mapToSignal {
                    return combineLatest($0.map {context.engine.peers.removeRecentlySearchedPeer(peerId: $0.peer.peerId)})
                }).start()
            })
           
        }, openTopPeer: { type in
            switch type {
            case let .peer(peer, _, _):
                open(.chatId(.chatList(peer.id), peer.id, -1), nil, false)
                _ = context.engine.peers.addRecentlySearchedPeer(peerId: peer.id).start()
            case let .savedMessages(peer):
                open(.chatId(.chatList(peer.id), peer.id, -1), nil, false)
            case .articles:
                break
            }
        }, setPeerAsTag: { peer in
            setPeerAsTag?(peer)
        }, openStory: { index in
            StoryModalController.ShowStories(context: context, isHidden: false, initialId: index, singlePeer: true)
        }, openStorySearch: { [weak self] state in
            if let query = self?.query {
                showModal(with: StoryFoundListController(context: context, source: .hashtag(self?.searchTags?.peerTag, query), presentation: theme, existingsContext: self?.globalStorySearchContext), for: context.window)
            }
        }, toggleMessageSourceValue: { [weak self] value in
            self?.messagesSourceValue.set(value)
        }, removeAd: { ad, all in
            updateSearchState { current in
                var current = current
                current.exclude.insert(ad.opaqueId)
                current.excludeAll = all
                return current
            }
        })
        
        setPeerAsTag = { [weak self] peer in
            self?.setPeerAsTag?(peer)
        }
        
        globalDisposable.set(context.globalPeerHandler.get().start(next: { [weak self] peerId in
            if peerId == nil {
                self?.genericView.cancelSelection()
            }
        }))
        
        self.globalTagsValue.set(tags)

    }
    
    private var scrollupOnNextTransition: Bool = false
    private var currentMessagesSearchState: (SearchMessagesResult, SearchMessagesState)?
    
    func request(with query:String?) -> Void {
        
        let prev = self.query
        if query == self.query {
            return
        }
        
        setHighlightEvents()
        
        self.query = query
        if prev == nil && query == "" {
        } else {
            self.scrollupOnNextTransition = true
        }
        
        
        if let query = query, !query.isEmpty {
            searchQuery.set(query)
            searchMessagesState.set(nil)
        } else {
            searchQuery.set(nil)
        }
        
        if let query, query.hasPrefix("#") || query.hasPrefix("$"), query.length > 1, self.searchTags?.publicPosts == true || self.searchTags?.peerTag != nil {
            let globalStorySearchContext = SearchStoryListContext(account: context.account, source: .hashtag(self.searchTags?.peerTag, query))
            
            self.globalStorySearchContext = globalStorySearchContext
            self.globalStorySearchState.set(globalStorySearchContext.state |> map(Optional.init))
        } else {
            self.globalStorySearchState.set(.single(nil))
            self.globalStorySearchContext = nil
        }
    }
    
    override func scrollup(force: Bool = false) {
        genericView.clipView.scroll(to: NSMakePoint(0, 0), animated: false)
    }
    
    private var closeNext: Bool = false
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        var peer:Peer?
        var peerId:PeerId?
        var messageId:MessageId?
        var message: Message?
        var isGlobal = false
        let context = self.context
        var id: UIChatListEntryId?
        
        if let item = item as? SearchTopicRowItem {
            id = .chatId(item.item.id, item.item.renderedPeer.peerId, -1)
        } else if let item = item as? ChatListMessageRowItem {
            peer = item.peer
            messageId = item.message?.id
            message = item.message
            peerId = item.peerId
            id = item.entryId
            
            if let message = item.message {
                context.engine.messages.ensureMessagesAreLocallyAvailable(messages: [.init(message)])
            }
        } else if let item = item as? ShortPeerRowItem {
            if let stableId = item.stableId.base as? ChatListSearchEntryStableId {
                switch stableId {
                case let .localPeerId(pId), let .recentSearchPeerId(pId), let .secretChat(pId):
                    peerId = pId
                case let .globalPeerId(pId):
                    isGlobal = true
                    peerId = pId
                case .savedMessages:
                    peerId = context.peerId
                default:
                    break
                }
            }
            peer = item.peer
            
            if let peer = peer {
                if peer.isForum {
                    id = .forum(peer.id)
                } else if let peerId = peerId {
                    id = .chatId(.chatList(peerId), peerId, -1)
                }
            }else if let peerId = peerId {
                id = .chatId(.chatList(peerId), peerId, -1)
            }
        } else if let item = item as? SeparatorRowItem {
            if item.stableId == AnyHashable(ChatListSearchEntryStableId.separator(-1)) {
                switch item.state {
                case .short:
                    self.isChannelsRevealed.set(true)
                case .all:
                    self.isChannelsRevealed.set(false)
                default:
                    break
                }
            } else if item.stableId == AnyHashable(ChatListSearchEntryStableId.separator(10000)) {
                switch item.state {
                case .short:
                    self.isRevealed.set(true)
                case .all:
                    self.isRevealed.set(false)
                default:
                    break
                }
            } else if item.stableId == AnyHashable(ChatListSearchEntryStableId.separator(15000)) {
                switch item.state {
                case let .custom(_, action):
                    switch action {
                    case let .showPublicPosts(cached):
                        let query = self.query ?? ""
                        context.bindings.globalSearch(query, nil, cached)
                    default:
                        break
                    }
                default:
                    break
                }
            } else if item.stableId == AnyHashable(ChatListSearchEntryStableId.separator(20000)) {
                switch item.state {
                case let .custom(_, action):
                    switch action {
                    case let .showAsMessages(onlyMy):
                        let query = (self.query ?? "").replacingOccurrences(of: "[#$]", with: "", options: .regularExpression)
                        
                        let customChatContents = HashtagSearchGlobalChatContents(context: context, kind: .searchHashtag(hashtag: query, onlyMy: onlyMy), query: query, onlyMy: onlyMy, initialState: self.currentMessagesSearchState)
                        let current = context.bindings.rootNavigation().controller as? ChatController
                        if case .searchHashtag(query, onlyMy) = current?.mode.customChatContents?.kind {
                            current?.navigationController?.view.shake()
                        } else {
                            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(context.peerId), mode: .customChatContents(contents: customChatContents)))
                        }
                    default:
                        break
                    }
                default:
                    break
                }
            } else {
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
            }
            

            return
        } else if item is PopularPeersRowItem {
            peerId = context.peerId
            id = .chatId(.chatList(context.peerId), context.peerId, -1)
        }
        
        var storedPeer: Signal<PeerId, NoError>
        if let peer = peer {
             storedPeer = storedMessageFromSearchPeer(account: context.account, peer: peer)
        } else if let peerId = peerId {
            storedPeer = .single(peerId)
        } else {
            storedPeer = .complete()
        }
        
        if let query = query, let peerId = peerId, messageId == nil {
            let link = inApp(for: query as NSString, context: context, peerId: peerId, openInfo: { _, _, _, _ in }, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
            switch link {
            case let .followResolvedName(_, _, postId, _, _, _, _):
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
                    return context.engine.peers.addRecentlySearchedPeer(peerId: peerId)
                }
                return .single(Void())
            }
        } else {
            recently = .single(Void())
        }
        
        _ = combineLatest(storedPeer, recently).start()
        
        removeHighlightEvents()
        
        marked = true
        
       
        
        let hasScope = searchTags?.listType != nil
        let close = self.closeNext || (messageId == nil && !isGlobal && !hasScope)

        if let message, let tags = self.searchTags {
            let current = context.bindings.rootNavigation().controller as? ChatController
            let query = (self.query ?? "").replacingOccurrences(of: "[#$]", with: "", options: .regularExpression)
            
            if case .searchHashtag(query, tags.myMessages) = current?.mode.customChatContents?.kind, tags.publicPosts || tags.myMessages {
                current?.focusExistingMessage(message)
                return
            }
        }
     
        if let peerId, let tags = self.searchTags, tags.listType == .bots {
            if let item = item as? RecentPeerRowItem {
                if !item.isRecentApp {
                    PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
                    return
                }
            }
        }
        
        if let item = item as? RecentPeerRowItem, let adPeer = item.adPeer {
            context.engine.messages.markAdAction(opaqueId: adPeer.opaqueId, media: false, fullscreen: false)
        }
        
        if let id = id {
            self.open(id, messageId, close)
        }
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        
        
        
        var peer: Peer? = nil
        if let item = item as? ChatListMessageRowItem {
            peer = item.peer
        } else if let item = item as? ShortPeerRowItem {
            peer = item.peer
        } else if let item = item as? SeparatorRowItem {
            if byClick {
                switch item.state {
                case .none:
                    return false
                default:
                    return true
                }
            } else {
                return false
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
                    _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId, replyId: nil, threadId: nil).start()
                    _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
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
    
    override var supportSwipes: Bool {
        if let location = window?.mouseLocationOutsideOfEventStream {
            let point = self.genericView.convert(location, from: nil)
            let row = self.genericView.row(at: point)
            if row != -1 {
                let item = self.genericView.item(at: row)
                if item is PopularPeersRowItem {
                    return false
                }
                return true
            }
        }
        return true
    }
    
}
