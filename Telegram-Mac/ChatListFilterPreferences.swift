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
import SyncCore


extension ChatListFilter {
   

    var isFullfilled: Bool {
        return self.data.categories == .all && !data.excludeMuted && !data.excludeRead
    }

    var icon: CGImage {

        if data.categories == .all && data.excludeMuted && !data.excludeRead {
            return theme.icons.chat_filter_unmuted
        } else if data.categories == .all && !data.excludeMuted && data.excludeRead {
            return theme.icons.chat_filter_unread
        } else if data.categories == .smallGroups {
            return theme.icons.chat_filter_groups
        } else if data.categories == .largeGroups {
            return theme.icons.chat_filter_large_groups
        } else if data.categories == .channels {
            return theme.icons.chat_filter_channels
        } else if data.categories == .contacts {
            return theme.icons.chat_filter_private_chats
        } else if data.categories == .nonContacts {
            return theme.icons.chat_filter_non_contacts
        } else if data.categories == .bots {
            return theme.icons.chat_filter_bots
        }
        return theme.icons.chat_filter_custom
    }
    
    static func new(excludeIds: [Int32]) -> ChatListFilter {
        var id:Int32! = nil
        while id == nil {
            let tempId = abs(Int32(bitPattern: arc4random())) % 255
            if tempId != 0 && tempId != 1 && !excludeIds.contains(tempId) {
                id = tempId
            }
        }
        return ChatListFilter(id: id, title: "", data: ChatListFilterData(categories: [], excludeMuted: false, excludeRead: false, excludeArchived: false, includePeers: [], excludePeers: []))
    }
}


func chatListFilterPreferences(postbox: Postbox) -> Signal<ChatListFiltersState, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.chatListFilters]) |> map { view in
        return view.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState ?? ChatListFiltersState.default
    }
}

func filtersBadgeCounters(context: AccountContext) -> Signal<[(id: Int32, count: Int32)], NoError>  {
    return chatListFilterPreferences(postbox: context.account.postbox) |> map { $0 } |> mapToSignal { settings -> Signal<[(id: Int32, count: Int32)], NoError> in
        
        let filters = settings.filters
        
        var signals:[Signal<(id: Int32, count: Int32), NoError>] = []
        for current in filters {
            
            var unreadCountItems: [UnreadMessageCountsItem] = []
            unreadCountItems.append(.total(nil))
            var keys: [PostboxViewKey] = []
            let unreadKey: PostboxViewKey
            
            if !current.data.includePeers.isEmpty {
                for peerId in current.data.includePeers {
                    unreadCountItems.append(.peer(peerId))
                }
            }
            unreadKey = .unreadCounts(items: unreadCountItems)
            keys.append(unreadKey)
            for peerId in current.data.includePeers {
                keys.append(.basicPeer(peerId))
                
            }
            keys.append(.peerNotificationSettings(peerIds: Set(current.data.includePeers)))
            
            let s:Signal<(id: Int32, count: Int32), NoError> = combineLatest(context.account.postbox.combinedView(keys: keys), appNotificationSettings(accountManager: context.sharedContext.accountManager)) |> map { keysView, inAppSettings -> (id: Int32, count: Int32) in
                
                if let unreadCounts = keysView.views[unreadKey] as? UnreadMessageCountsView, inAppSettings.badgeEnabled {
                    var peerTagAndCount: [PeerId: (PeerSummaryCounterTags, Int)] = [:]
                    var totalState: ChatListTotalUnreadState?
                    for entry in unreadCounts.entries {
                        switch entry {
                        case let .total(_, totalStateValue):
                            totalState = totalStateValue
                        case let .peer(peerId, state):
                            if let state = state, state.isUnread {
                                let notificationSettings = keysView.views[.peerNotificationSettings(peerIds: Set(current.data.includePeers))] as? PeerNotificationSettingsView
                                if let peerView = keysView.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer {
                                    let tag = context.account.postbox.seedConfiguration.peerSummaryCounterTags(peer, peerView.isContact)
                                    var peerCount = Int(state.count)
                                    let isRemoved = notificationSettings?.notificationSettings[peerId]?.isRemovedFromTotalUnreadCount ?? false
                                    var removable = false
                                    switch inAppSettings.totalUnreadCountDisplayStyle {
                                    case .raw:
                                        removable = true
                                    case .filtered:
                                        if !isRemoved {
                                            removable = true
                                        }
                                    }
                                    if current.data.excludeMuted, isRemoved {
                                        removable = false
                                    }
                                    if removable, state.isUnread {
                                        switch inAppSettings.totalUnreadCountDisplayCategory {
                                        case .chats:
                                            peerCount = 1
                                        case .messages:
                                            peerCount = max(1, peerCount)
                                        }
                                        peerTagAndCount[peerId] = (tag, peerCount)
                                    }
                                    
                                }
                            }
                        }
                    }
                    
                    var tags: [PeerSummaryCounterTags] = []
                    if current.data.categories.contains(.contacts) {
                        tags.append(.contact)
                    }
                    if current.data.categories.contains(.nonContacts) {
                        tags.append(.nonContact)
                    }
                    if current.data.categories.contains(.smallGroups) {
                        tags.append(.smallGroup)
                    }
                    if current.data.categories.contains(.largeGroups) {
                        tags.append(.largeGroup)
                    }
                    if current.data.categories.contains(.bots) {
                        tags.append(.bot)
                    }
                    if current.data.categories.contains(.channels) {
                        tags.append(.channel)
                    }
                    
                    var count:Int32 = 0
                    if let totalState = totalState {
                        for tag in tags {
                            let state:[PeerSummaryCounterTags: ChatListTotalUnreadCounters]
                            switch inAppSettings.totalUnreadCountDisplayStyle {
                            case .raw:
                                state = totalState.absoluteCounters
                            case .filtered:
                                state = totalState.filteredCounters
                            }
                            if let value = state[tag] {
                                switch inAppSettings.totalUnreadCountDisplayCategory {
                                case .chats:
                                    count += value.chatCount
                                case .messages:
                                    count += value.messageCount
                                }
                            }
                        }
                    }
                    for peerId in current.data.includePeers {
                        if let (tag, peerCount) = peerTagAndCount[peerId] {
                            if !tags.contains(tag) {
                                count += Int32(peerCount)
                            }
                        }
                    }
                    return (id: current.id, count: count)
                } else {
                    return (id: current.id, count: 0)
                }
            }
            signals.append(s)
        }
        return combineLatest(signals) |> mapToSignal { values in
            return renderedTotalUnreadCount(accountManager: context.sharedContext.accountManager, postbox: context.account.postbox) |> map { total in
                var values = values
                values.append((id: -1, count: total.0))
                return values
            }
        }
    }
}
