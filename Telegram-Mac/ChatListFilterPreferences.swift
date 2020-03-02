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
    var desc: String {
        var text: String = L10n.chatListFilterDescCustomized
        if data.categories.isEmpty && !data.excludeRead && !data.excludeMuted {
            return "\(self.data.includePeers.count)"
        } else if data.categories.isEmpty && data.excludeMuted && !data.excludeRead {
           text = L10n.chatListFilterDescUnmuted
        } else if data.categories.isEmpty && !data.excludeMuted && data.excludeRead {
            text = L10n.chatListFilterDescUnread
        } else if data.categories == .privateChats {
            text = L10n.chatListFilterDescPrivateChats
        } else if data.categories == [.publicGroups, .privateGroups] {
            text = L10n.chatListFilterDescGroups
        } else if data.categories == .privateGroups {
            text = L10n.chatListFilterDescPrivateGroups
        } else if data.categories == .publicGroups {
            text = L10n.chatListFilterDescPublicGroups
        } else if data.categories == .channels {
            text = L10n.chatListFilterDescChannels
        } else if data.categories == .bots {
            text = L10n.chatListFilterDescBots
        } else if data.categories == .secretChats {
            text = L10n.chatListFilterDescSecretChats
        }

        if !self.data.includePeers.isEmpty {
            text += ", +\(self.data.includePeers.count)"
        }
        return text
    }

    var isFullfilled: Bool {
        return self.data.categories == .all && !data.excludeMuted && !data.excludeRead
    }

    var icon: CGImage {

        if data.categories == .all && data.excludeMuted && !data.excludeRead {
            return theme.icons.chat_filter_unmuted
        } else if data.categories == .all && !data.excludeMuted && data.excludeRead {
            return theme.icons.chat_filter_unread
        } else if data.categories == .publicGroups || data.categories == .privateGroups  || data.categories == [.privateGroups, .publicGroups] {
            return theme.icons.chat_filter_groups
        } else if data.categories == .channels {
            return theme.icons.chat_filter_channels
        } else if data.categories == .privateChats {
            return theme.icons.chat_filter_private_chats
        } else if data.categories == .bots {
            return theme.icons.chat_filter_bots
        } else if data.categories == .secretChats {
            return theme.icons.chat_filter_secret_chats
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
        return ChatListFilter(id: id, title: "", data: ChatListFilterData(categories: .all, excludeMuted: false, excludeRead: false, includePeers: []))
    }
}

//
//public enum ChatListFilterPresetName: Equatable, Hashable, PostboxCoding {
//    case unmuted
//    case unread
//    case channels
//    case publicGroups
//    case privateGroups
//    case secretChats
//    case privateChats
//    case bots
//    case custom(String)
//
//    public init(decoder: PostboxDecoder) {
//        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
//        case 0:
//            self = .unmuted
//        case 1:
//            self = .channels
//        case 2:
//            self = .privateChats
//        case 3:
//            self = .publicGroups
//        case 4:
//            self = .privateGroups
//        case 5:
//            self = .secretChats
//        case 6:
//            self = .bots
//        case 7:
//            self = .unread
//        case 10:
//            self = .custom(decoder.decodeStringForKey("title", orElse: "Preset"))
//        default:
//            assertionFailure()
//            self = .custom("Preset")
//        }
//    }
//
//    public func encode(_ encoder: PostboxEncoder) {
//        switch self {
//        case .unmuted:
//            encoder.encodeInt32(0, forKey: "_t")
//        case .channels:
//            encoder.encodeInt32(1, forKey: "_t")
//        case .privateChats:
//            encoder.encodeInt32(2, forKey: "_t")
//        case .publicGroups:
//            encoder.encodeInt32(3, forKey: "_t")
//        case .privateGroups:
//            encoder.encodeInt32(4, forKey: "_t")
//        case .secretChats:
//            encoder.encodeInt32(5, forKey: "_t")
//        case .bots:
//            encoder.encodeInt32(6, forKey: "_t")
//        case .unread:
//            encoder.encodeInt32(7, forKey: "_t")
//        case let .custom(title):
//            encoder.encodeInt32(10, forKey: "_t")
//            encoder.encodeString(title, forKey: "title")
//        }
//    }
//
//
//    var title: String {
//        switch self {
//        case .unmuted:
//            return L10n.chatListFilterUnmutedChats
//        case .channels:
//            return L10n.chatListFilterChannels
//        case .publicGroups:
//            return L10n.chatListFilterPublicGroups
//        case .privateGroups:
//            return L10n.chatListFilterPrivateGroups
//        case .secretChats:
//            return L10n.chatListFilterSecretChat
//        case .privateChats:
//            return L10n.chatListFilterPrivateChats
//        case .unread:
//            return L10n.chatListFilterUnreadChats
//        case .bots:
//            return L10n.chatListFilterBots
//        case let .custom(name):
//            return name
//        }
//    }
//}
//
//struct ChatListFilter: Equatable, PostboxCoding {
//    let name: ChatListFilterPresetName
//    let includedata.categories: ChatListFilter
//    let applyReadMutedForExceptions: Bool
//    let additionallyIncludePeers: [PeerId]
//    let uniqueId: Int32
//    init(name: ChatListFilterPresetName, includedata.categories: ChatListFilter, additionallyIncludePeers: [PeerId], applyReadMutedForExceptions: Bool, uniqueId: Int32) {
//        self.name = name
//        self.includedata.categories = includedata.categories
//        self.additionallyIncludePeers = additionallyIncludePeers
//        self.uniqueId = uniqueId
//        self.applyReadMutedForExceptions = applyReadMutedForExceptions
//    }
//
//    init(decoder: PostboxDecoder) {
//        self.name = decoder.decodeObjectForKey("name", decoder: { ChatListFilterPresetName(decoder: $0) }) as? ChatListFilterPresetName ?? ChatListFilterPresetName.custom("Preset")
//        self.includedata.categories = ChatListFilter(rawValue: decoder.decodeInt32ForKey("includedata.categories", orElse: 0))
//        self.additionallyIncludePeers = decoder.decodeInt64ArrayForKey("additionallyIncludePeers").map(PeerId.init)
//        self.applyReadMutedForExceptions = decoder.decodeBoolForKey("applyReadMutedForExceptions", orElse: false)
//        self.uniqueId = decoder.decodeInt32ForKey("uniqueId", orElse: 0)
//    }
//
//    func encode(_ encoder: PostboxEncoder) {
//        encoder.encodeObject(self.name, forKey: "name")
//        encoder.encodeInt32(self.includedata.categories.rawValue, forKey: "includedata.categories")
//        encoder.encodeInt64Array(self.additionallyIncludePeers.map { $0.toInt64() }, forKey: "additionallyIncludePeers")
//        encoder.encodeInt32(self.uniqueId, forKey: "uniqueId")
//        encoder.encodeBool(self.applyReadMutedForExceptions, forKey: "applyReadMutedForExceptions")
//    }
//
//    var title: String {
//        return name.title
//    }
//    var desc: String {
//        var text: String = L10n.chatListFilterDescCustomized
//        if includedata.categories == [.muted, .read] {
//            return "\(self.additionallyIncludePeers.count)"
//        } else if includedata.categories == ._unmuted {
//           text = L10n.chatListFilterDescUnmuted
//        } else if includedata.categories == ._unread {
//            text = L10n.chatListFilterDescUnread
//        } else if includedata.categories == ._privateChats {
//            text = L10n.chatListFilterDescPrivateChats
//        } else if includedata.categories == ._groups {
//            text = L10n.chatListFilterDescGroups
//        } else if includedata.categories == ._privateGroups {
//            text = L10n.chatListFilterDescPrivateGroups
//        } else if includedata.categories == ._publicGroups {
//            text = L10n.chatListFilterDescPublicGroups
//        } else if includedata.categories == ._channels {
//            text = L10n.chatListFilterDescChannels
//        } else if includedata.categories == ._bots {
//            text = L10n.chatListFilterDescBots
//        } else if includedata.categories == ._secretChats {
//            text = L10n.chatListFilterDescSecretChats
//        }
//
//        if !self.additionallyIncludePeers.isEmpty {
//            text += ", +\(self.additionallyIncludePeers.count)"
//        }
//        return text
//    }
//
//    var icon: CGImage {
//
//        if includedata.categories == ._unmuted {
//            return theme.icons.chat_filter_unmuted
//        } else if includedata.categories == ._unread {
//            return theme.icons.chat_filter_unread
//        } else if includedata.categories == ._groups || includedata.categories == ._publicGroups || includedata.categories == ._privateGroups {
//            return theme.icons.chat_filter_groups
//        } else if includedata.categories == ._channels {
//            return theme.icons.chat_filter_channels
//        } else if includedata.categories == ._privateChats {
//            return theme.icons.chat_filter_private_chats
//        } else if includedata.categories == ._bots {
//            return theme.icons.chat_filter_bots
//        } else if includedata.categories == ._secretChats {
//            return theme.icons.chat_filter_secret_chats
//        }
//
//        return theme.icons.chat_filter_custom
//    }
//
//    static var new: ChatListFilter {
//        return ChatListFilter(name: .custom(""), includedata.categories: .all, additionallyIncludePeers: [], applyReadMutedForExceptions: false, uniqueId: Int32(bitPattern: arc4random()))
//    }
//
//    func withToggleOption(_ option: ChatListFilter) -> ChatListFilter {
//        var includedata.categories = self.includedata.categories
//        if includedata.categories.contains(option) {
//            includedata.categories.remove(option)
//        } else {
//            includedata.categories.insert(option)
//        }
//        return ChatListFilter(name: self.name, includedata.categories: includedata.categories, additionallyIncludePeers: self.additionallyIncludePeers, applyReadMutedForExceptions: self.applyReadMutedForExceptions, uniqueId: self.uniqueId)
//    }
//    func withUpdatedName(_ name: ChatListFilterPresetName) -> ChatListFilter {
//        return ChatListFilter(name: name, includedata.categories: self.includedata.categories, additionallyIncludePeers: self.additionallyIncludePeers, applyReadMutedForExceptions: self.applyReadMutedForExceptions, uniqueId: self.uniqueId)
//    }
//    func withUpdatedApplyReadMutedForExceptions(_ applyReadMutedForExceptions: Bool) -> ChatListFilter {
//        return ChatListFilter(name: name, includedata.categories: self.includedata.categories, additionallyIncludePeers: self.additionallyIncludePeers, applyReadMutedForExceptions: applyReadMutedForExceptions, uniqueId: self.uniqueId)
//    }
//    func withAddedPeerIds(_ peerIds: [PeerId]) -> ChatListFilter {
//        var additionallyIncludePeers = self.additionallyIncludePeers
//        additionallyIncludePeers.append(contentsOf: peerIds)
//        return ChatListFilter(name: self.name, includedata.categories: self.includedata.categories, additionallyIncludePeers: additionallyIncludePeers, applyReadMutedForExceptions: self.applyReadMutedForExceptions, uniqueId: self.uniqueId)
//    }
//    func withRemovedPeerId(_ peerId: PeerId) -> ChatListFilter {
//        var additionallyIncludePeers = self.additionallyIncludePeers
//        additionallyIncludePeers.removeAll(where: { $0 == peerId })
//        return ChatListFilter(name: self.name, includedata.categories: self.includedata.categories, additionallyIncludePeers: additionallyIncludePeers, applyReadMutedForExceptions: self.applyReadMutedForExceptions, uniqueId: self.uniqueId)
//    }
//}
//
//
//
//struct ChatListFilter: OptionSet {
//    var rawValue: Int32
//
//    init(rawValue: Int32) {
//        self.rawValue = rawValue
//    }
//
//    static let muted = ChatListFilter(rawValue: 1 << 1)
//    static let privateChats = ChatListFilter(rawValue: 1 << 2)
//    static let publicGroups = ChatListFilter(rawValue: 1 << 3)
//    static let privateGroups = ChatListFilter(rawValue: 1 << 4)
//    static let secretChats = ChatListFilter(rawValue: 1 << 5)
//    static let bots = ChatListFilter(rawValue: 1 << 6)
//    static let channels = ChatListFilter(rawValue: 1 << 7)
//    static let read = ChatListFilter(rawValue: 1 << 8)
//    static let all: ChatListFilter = [
//        .muted,
//        .privateChats,
//        .privateGroups,
//        .publicGroups,
//        .secretChats,
//        .bots,
//        .channels,
//        .read
//    ]
//    static let _unmuted: ChatListFilter = [
//        .privateChats,
//        .privateGroups,
//        .publicGroups,
//        .secretChats,
//        .bots,
//        .channels,
//        .read]
//
//    static let _unread: ChatListFilter = [
//        .muted,
//        .privateChats,
//        .publicGroups,
//        .privateGroups,
//        .secretChats,
//        .bots,
//        .channels]
//
//    static let _channels: ChatListFilter = [
//        .muted,
//        .channels,
//        .read
//    ]
//    static let _groups: ChatListFilter = [
//        .muted,
//        .publicGroups,
//        .privateGroups,
//        .read
//    ]
//    static let _privateGroups: ChatListFilter = [
//        .muted,
//        .privateGroups,
//        .read
//    ]
//    static let _publicGroups: ChatListFilter = [
//        .muted,
//        .publicGroups,
//        .read
//    ]
//    static let _secretChats: ChatListFilter = [
//        .muted,
//        .secretChats,
//        .read
//    ]
//    static let _privateChats: ChatListFilter = [
//        .muted,
//        .privateChats,
//        .read
//    ]
//    static let _bots: ChatListFilter = [
//        .muted,
//        .bots,
//        .read
//    ]
//    var string: String {
//        return ""
//    }
//}
//private var defaultFiltersIsEnabled: Bool {
//    #if BETA || ALPHA || DEBUG
//        return true
//    #else
//        return false
//    #endif
//}
//
//struct ChatListFilterPreferences: PreferencesEntry, Equatable {
//    let presets: [ChatListFilter]
//    let needShowTooltip: Bool
//    let tabsIsEnabled: Bool
//    let badge: Bool
//    let isEnabled: Bool
//    static var defaultSettings: ChatListFilterPreferences {
//        var presets: [ChatListFilter] = []
//
////        presets.append(ChatListFilter(name: .privateChats, includedata.categories: ._privateChats, additionallyIncludePeers: [], uniqueId: 0))
////        presets.append(ChatListFilter(name: .channels, includedata.categories: ._channels, additionallyIncludePeers: [], uniqueId: 1))
////        presets.append(ChatListFilter(name: .groups, includedata.categories: ._groups, additionallyIncludePeers: [], uniqueId: 2))
////        presets.append(ChatListFilter(name: .bots, includedata.categories: ._bots, additionallyIncludePeers: [], uniqueId: 3))
//        presets.append(ChatListFilter(name: .unread, includedata.categories: ._unread, additionallyIncludePeers: [], applyReadMutedForExceptions: false, uniqueId: 4))
//        presets.append(ChatListFilter(name: .unmuted, includedata.categories: ._unmuted, additionallyIncludePeers: [], applyReadMutedForExceptions: false, uniqueId: 5))
//
//        return ChatListFilterPreferences(presets: presets, needShowTooltip: true, tabsIsEnabled: false, isEnabled: defaultFiltersIsEnabled, badge: true)
//    }
//
//    init(presets: [ChatListFilter], needShowTooltip: Bool, tabsIsEnabled: Bool, isEnabled: Bool, badge: Bool) {
//        self.presets = presets
//        self.needShowTooltip = needShowTooltip
//        self.tabsIsEnabled = tabsIsEnabled
//        self.isEnabled = isEnabled
//        self.badge = badge
//    }
//
//    init(decoder: PostboxDecoder) {
//        self.presets = decoder.decodeObjectArrayWithDecoderForKey("presets")
//        self.needShowTooltip = decoder.decodeBoolForKey("needShowTooltip", orElse: true)
//        self.tabsIsEnabled = decoder.decodeBoolForKey("tabsIsEnabled", orElse: true)
//        self.isEnabled = decoder.decodeBoolForKey("isEnabled", orElse: defaultFiltersIsEnabled)
//        self.badge = decoder.decodeBoolForKey("badge", orElse: true)
//
//    }
//
//    func encode(_ encoder: PostboxEncoder) {
//        encoder.encodeObjectArray(self.presets, forKey: "presets")
//        encoder.encodeBool(self.needShowTooltip, forKey: "needShowTooltip")
//        encoder.encodeBool(self.tabsIsEnabled, forKey: "tabsIsEnabled")
//        encoder.encodeBool(self.isEnabled, forKey: "isEnabled")
//        encoder.encodeBool(self.badge, forKey: "badge")
//    }
//
//    func isEqual(to: PreferencesEntry) -> Bool {
//        if let to = to as? ChatListFilterPreferences {
//            return self == to
//        } else {
//            return false
//        }
//    }
//
//    static func ==(lhs: ChatListFilterPreferences, rhs: ChatListFilterPreferences) -> Bool {
//        return lhs.presets == rhs.presets && lhs.needShowTooltip == rhs.needShowTooltip && lhs.tabsIsEnabled == rhs.tabsIsEnabled && lhs.isEnabled == rhs.isEnabled && lhs.badge == rhs.badge
//    }
//
//    func withAddedPreset(_ preset: ChatListFilter, onlyReplace: Bool = false) -> ChatListFilterPreferences {
//        var presets = self.presets
//        if let index = presets.firstIndex(where: {$0.uniqueId == preset.uniqueId}) {
//            presets[index] = preset
//        } else if !onlyReplace {
//            presets.append(preset)
//        }
//        return ChatListFilterPreferences(presets: presets, needShowTooltip: false, tabsIsEnabled: self.tabsIsEnabled, isEnabled: self.isEnabled, badge: self.badge)
//    }
//
//    func withRemovedPreset(_ preset: ChatListFilter) -> ChatListFilterPreferences {
//        var presets = self.presets
//        presets.removeAll(where: {$0.uniqueId == preset.uniqueId })
//        return ChatListFilterPreferences(presets: presets, needShowTooltip: false, tabsIsEnabled: self.tabsIsEnabled, isEnabled: self.isEnabled, badge: self.badge)
//    }
//
//    func withMovePreset(_ from: Int, _ to: Int) -> ChatListFilterPreferences {
//        var presets = self.presets
//        presets.insert(presets.remove(at: from), at: to)
//        return ChatListFilterPreferences(presets: presets, needShowTooltip: false, tabsIsEnabled: self.tabsIsEnabled, isEnabled: self.isEnabled, badge: self.badge)
//    }
//    func withSelectedAtIndex(_ index: Int) -> ChatListFilterPreferences {
//        return ChatListFilterPreferences(presets: self.presets, needShowTooltip: false, tabsIsEnabled: self.tabsIsEnabled, isEnabled: self.isEnabled, badge: self.badge)
//    }
//
//    func withUpdatedNeedShowTooltip(_ needShowTooltip: Bool) -> ChatListFilterPreferences {
//        return ChatListFilterPreferences(presets: self.presets, needShowTooltip: needShowTooltip, tabsIsEnabled: self.tabsIsEnabled, isEnabled: self.isEnabled, badge: self.badge)
//    }
//    func withUpdatedTabEnable(_ tabsIsEnabled: Bool) -> ChatListFilterPreferences {
//        return ChatListFilterPreferences(presets: self.presets, needShowTooltip: self.needShowTooltip, tabsIsEnabled: tabsIsEnabled, isEnabled: self.isEnabled, badge: self.badge)
//    }
//    func withUpdatedEnabled(_ isEnabled: Bool) -> ChatListFilterPreferences {
//        return ChatListFilterPreferences(presets: self.presets, needShowTooltip: self.needShowTooltip, tabsIsEnabled: isEnabled ? self.tabsIsEnabled : false, isEnabled: isEnabled, badge: self.badge)
//    }
//    func withUpdatedBadge(_ badge: Bool) -> ChatListFilterPreferences {
//        return ChatListFilterPreferences(presets: self.presets, needShowTooltip: self.needShowTooltip, tabsIsEnabled: self.tabsIsEnabled, isEnabled: self.isEnabled, badge: badge)
//    }
//    func shortcut(for preset: ChatListFilter?) -> String {
//        if let preset = preset {
//            for (i, value) in self.presets.enumerated() {
//                if preset.uniqueId == value.uniqueId {
//                    var shortcut: String = "⌃⌘\(i + 2)"
//                    if i + 2 == 11 {
//                        shortcut = "⌃⌘-"
//                    }
//                    return shortcut
//                }
//            }
//        } else {
//            return "⌃⌘1"
//        }
//
//        return ""
//    }
//}
//
//
//


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
                                    let tag = context.account.postbox.seedConfiguration.peerSummaryCounterTags(peer)
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
                    if current.data.categories.contains(.privateChats) {
                        tags.append(.privateChat)
                    }
                    
                    if current.data.categories.contains(.publicGroups) {
                        tags.append(.publicGroup)
                    }
                    if current.data.categories.contains(.privateGroups) {
                        tags.append(.privateGroup)
                    }
                    if current.data.categories.contains(.secretChats) {
                        tags.append(.secretChat)
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
