//
//  ChatListFilterPreferences.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Postbox
import SwiftSignalKit
import TelegramCore
import Postbox
import Cocoa


public extension ChatListFilter {
   

    var isFullfilled: Bool {
        return self.data.categories == .all && data.includePeers.peers.isEmpty && data.excludePeers.isEmpty && !data.excludeMuted && !data.excludeRead && data.excludeArchived
    }
    var isEmpty: Bool {
        return self.data.categories.isEmpty && data.includePeers.peers.isEmpty && data.excludePeers.isEmpty && !data.excludeMuted && !data.excludeRead
    }
   
    
    static func new(excludeIds: [Int32]) -> ChatListFilter {
        var id:Int32! = nil
        while id == nil {
            let tempId = abs(Int32(bitPattern: arc4random())) % 255
            if tempId != 0 && tempId != 1 && !excludeIds.contains(tempId) {
                id = tempId
            }
        }
        return ChatListFilter(id: id, title: "", emoticon: nil, data: ChatListFilterData(categories: [], excludeMuted: false, excludeRead: false, excludeArchived: false, includePeers: ChatListFilterIncludePeers(), excludePeers: []))
    }
}




public struct ChatListFoldersSettings: Codable {
    
    public let sidebar: Bool
    
    public static var defaultValue: ChatListFoldersSettings {
        return ChatListFoldersSettings(sidebar: false)
    }
    
    public init(sidebar: Bool) {
        self.sidebar = sidebar
    }
    
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.sidebar = try container.decode(Int32.self, forKey: "t") == 1
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(Int32(self.sidebar ? 1 : 0), forKey: "t")
    }
    
    
    public func withUpdatedSidebar(_ sidebar: Bool) -> ChatListFoldersSettings {
        return ChatListFoldersSettings(sidebar: sidebar)
    }
}



public func chatListFolderSettings(_ postbox: Postbox) -> Signal<ChatListFoldersSettings, NoError> {
    return postbox.preferencesView(keys:  [ApplicationSpecificPreferencesKeys.chatListSettings]) |> map { view in
        return view.values[ApplicationSpecificPreferencesKeys.chatListSettings]?.get(ChatListFoldersSettings.self) ?? ChatListFoldersSettings.defaultValue
    }
}

public func updateChatListFolderSettings(_ postbox: Postbox, _ f: @escaping(ChatListFoldersSettings) -> ChatListFoldersSettings) -> Signal<Never, NoError> {
    return postbox.transaction { transaction in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatListSettings, { entry in
            let current = entry?.get(ChatListFoldersSettings.self) ?? ChatListFoldersSettings.defaultValue
            let updated = f(current)
            return PreferencesEntry(updated)
        })
    } |> ignoreValues
}



public struct ChatListFolders : Equatable {
    public let list: [ChatListFilter]
    public let sidebar: Bool
    public init(list: [ChatListFilter], sidebar: Bool) {
        self.list = list
        self.sidebar = sidebar
    }
}

public func chatListFilterPreferences(engine: TelegramEngine) -> Signal<ChatListFolders, NoError> {
    return combineLatest(engine.peers.updatedChatListFilters(), chatListFolderSettings(engine.account.postbox)) |> map {
        return ChatListFolders(list: $0, sidebar: $1.sidebar)
    }
}

public struct ChatListFilterBadge : Equatable {
    public let filter: ChatListFilter
    public let count: Int
    public let hasUnmutedUnread: Bool
}
public struct ChatListFilterBadges : Equatable {
    public let total:Int
    public let filters:[ChatListFilterBadge]
    public init(total: Int, filters: [ChatListFilterBadge]) {
        self.total = total
        self.filters = filters
    }
    public func count(for filter: ChatListFilter?) -> ChatListFilterBadge? {
        return filters.first(where: { $0.filter.id == filter?.id })
    }
}

public func chatListFilterItems(engine: TelegramEngine, accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<ChatListFilterBadges, NoError> {
    
    let settings = appNotificationSettings(accountManager: accountManager) |> distinctUntilChanged(isEqual: { lhs, rhs in
        return lhs.badgeEnabled == rhs.badgeEnabled
    })
    return combineLatest(engine.peers.updatedChatListFilters(), settings)
        |> mapToSignal { filters, inAppSettings -> Signal<(Int, [(ChatListFilter, Int, Bool)]), NoError> in
            
            if !inAppSettings.badgeEnabled {
                return .single((0, []))
            }
            
            var unreadCountItems: [UnreadMessageCountsItem] = []
            unreadCountItems.append(.totalInGroup(.root))
            var additionalPeerIds = Set<PeerId>()
            var additionalGroupIds = Set<PeerGroupId>()
            for filter in filters {
                additionalPeerIds.formUnion(filter.data.includePeers.peers)
                additionalPeerIds.formUnion(filter.data.excludePeers)
                if !filter.data.excludeArchived {
                    additionalGroupIds.insert(Namespaces.PeerGroup.archive)
                }
            }
            if !additionalPeerIds.isEmpty {
                for peerId in additionalPeerIds {
                    unreadCountItems.append(.peer(peerId))
                }
            }
            for groupId in additionalGroupIds {
                unreadCountItems.append(.totalInGroup(groupId))
            }
            let unreadKey: PostboxViewKey = .unreadCounts(items: unreadCountItems)
            var keys: [PostboxViewKey] = []
            keys.append(unreadKey)
            for peerId in additionalPeerIds {
                keys.append(.basicPeer(peerId))
            }
            
            return combineLatest(queue: Queue(),
                                 engine.account.postbox.combinedView(keys: keys),
                                 Signal<Bool, NoError>.single(true)
                )
                |> map { view, _ -> (Int, [(ChatListFilter, Int, Bool)]) in
                    guard let unreadCounts = view.views[unreadKey] as? UnreadMessageCountsView else {
                        return (0, [])
                    }
                    
                    var result: [(ChatListFilter, Int, Bool)] = []
                    
                    var peerTagAndCount: [PeerId: (PeerSummaryCounterTags, Int, Bool)] = [:]
                    
                    var totalStates: [PeerGroupId: ChatListTotalUnreadState] = [:]
                    for entry in unreadCounts.entries {
                        switch entry {
                        case let .total(_, state):
                            totalStates[.root] = state
                        case let .totalInGroup(groupId, state):
                            totalStates[groupId] = state
                        case let .peer(peerId, state):
                            if let state = state, state.isUnread {
                                if let peerView = view.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer {
                                    let tag = engine.account.postbox.seedConfiguration.peerSummaryCounterTags(peer, peerView.isContact)
                                    
                                    var peerCount = Int(state.count)
                                    if state.isUnread {
                                        peerCount = max(1, peerCount)
                                    }
                                    
                                    if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings, case .muted = notificationSettings.muteState {
                                        peerTagAndCount[peerId] = (tag, peerCount, false)
                                    } else {
                                        peerTagAndCount[peerId] = (tag, peerCount, true)
                                    }
                                }
                            }
                        }
                    }
                    
                    let totalBadge = 0
                    
                    for filter in filters {
                        var tags: [PeerSummaryCounterTags] = []
                        if filter.data.categories.contains(.contacts) {
                            tags.append(.contact)
                        }
                        if filter.data.categories.contains(.nonContacts) {
                            tags.append(.nonContact)
                        }
                        if filter.data.categories.contains(.groups) {
                            tags.append(.group)
                        }
                        if filter.data.categories.contains(.bots) {
                            tags.append(.bot)
                        }
                        if filter.data.categories.contains(.channels) {
                            tags.append(.channel)
                        }
                        
                        var count = 0
                        var hasUnmutedUnread = false
                        if let totalState = totalStates[.root] {
                            for tag in tags {
                                if filter.data.excludeMuted {
                                    if let value = totalState.filteredCounters[tag] {
                                        if value.chatCount != 0 {
                                            count += Int(value.chatCount)
                                            hasUnmutedUnread = true
                                        }
                                    }
                                } else {
                                    if let value = totalState.absoluteCounters[tag] {
                                        count += Int(value.chatCount)
                                    }
                                    if let value = totalState.filteredCounters[tag] {
                                        if value.chatCount != 0 {
                                            hasUnmutedUnread = true
                                        }
                                    }
                                }
                            }
                        }
                        if !filter.data.excludeArchived {
                            if let totalState = totalStates[Namespaces.PeerGroup.archive] {
                                for tag in tags {
                                    if filter.data.excludeMuted {
                                        if let value = totalState.filteredCounters[tag] {
                                            if value.chatCount != 0 {
                                                count += Int(value.chatCount)
                                                hasUnmutedUnread = true
                                            }
                                        }
                                    } else {
                                        if let value = totalState.absoluteCounters[tag] {
                                            count += Int(value.chatCount)
                                        }
                                        if let value = totalState.filteredCounters[tag] {
                                            if value.chatCount != 0 {
                                                hasUnmutedUnread = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        for peerId in filter.data.includePeers.peers {
                            if let (tag, peerCount, hasUnmuted) = peerTagAndCount[peerId] {
                                if !tags.contains(tag) {
                                    if peerCount != 0 {
                                        count += 1
                                        if hasUnmuted {
                                            hasUnmutedUnread = true
                                        }
                                    }
                                }
                            }
                        }
                        for peerId in filter.data.excludePeers {
                            if let (tag, peerCount, _) = peerTagAndCount[peerId] {
                                if tags.contains(tag) {
                                    if peerCount != 0 {
                                        count -= 1
                                    }
                                }
                            }
                        }
                        result.append((filter, count, hasUnmutedUnread))
                    }
                    
                    return (totalBadge, result)
            }
        } |> map { value -> ChatListFilterBadges in
            return ChatListFilterBadges(total: value.0, filters: value.1.map { ChatListFilterBadge(filter: $0.0, count: max(0, $0.1), hasUnmutedUnread: $0.2) })
        } |> mapToSignal { badges -> Signal<ChatListFilterBadges, NoError> in
            return renderedTotalUnreadCount(accountManager: accountManager, postbox: engine.account.postbox) |> map {
                return ChatListFilterBadges(total: Int(max($0.0, 0)), filters: badges.filters)
            }
        }
}
