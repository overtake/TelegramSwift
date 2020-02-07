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

public enum ChatListFilterPresetName: Equatable, Hashable, PostboxCoding {
    case unmuted
    case unread
    case channels
    case publicGroups
    case privateGroups
    case secretChats
    case privateChats
    case bots
    case custom(String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
        case 0:
            self = .unmuted
        case 1:
            self = .channels
        case 2:
            self = .privateChats
        case 3:
            self = .publicGroups
        case 4:
            self = .privateGroups
        case 5:
            self = .secretChats
        case 6:
            self = .bots
        case 7:
            self = .unread
        case 10:
            self = .custom(decoder.decodeStringForKey("title", orElse: "Preset"))
        default:
            assertionFailure()
            self = .custom("Preset")
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .unmuted:
            encoder.encodeInt32(0, forKey: "_t")
        case .channels:
            encoder.encodeInt32(1, forKey: "_t")
        case .privateChats:
            encoder.encodeInt32(2, forKey: "_t")
        case .publicGroups:
            encoder.encodeInt32(3, forKey: "_t")
        case .privateGroups:
            encoder.encodeInt32(4, forKey: "_t")
        case .secretChats:
            encoder.encodeInt32(5, forKey: "_t")
        case .bots:
            encoder.encodeInt32(6, forKey: "_t")
        case .unread:
            encoder.encodeInt32(7, forKey: "_t")
        case let .custom(title):
            encoder.encodeInt32(10, forKey: "_t")
            encoder.encodeString(title, forKey: "title")
        }
    }

    
    var title: String {
        switch self {
        case .unmuted:
            return L10n.chatListFilterUnmutedChats
        case .channels:
            return L10n.chatListFilterChannels
        case .publicGroups:
            return L10n.chatListFilterPublicGroups
        case .privateGroups:
            return L10n.chatListFilterPrivateGroups
        case .secretChats:
            return L10n.chatListFilterSecretChat
        case .privateChats:
            return L10n.chatListFilterPrivateChats
        case .unread:
            return L10n.chatListFilterUnreadChats
        case .bots:
            return L10n.chatListFilterBots
        case let .custom(name):
            return name
        }
    }
}

struct ChatListFilterPreset: Equatable, PostboxCoding {
    let name: ChatListFilterPresetName
    let includeCategories: ChatListFilter
    let applyReadMutedForExceptions: Bool
    let additionallyIncludePeers: [PeerId]
    let uniqueId: Int32
    init(name: ChatListFilterPresetName, includeCategories: ChatListFilter, additionallyIncludePeers: [PeerId], applyReadMutedForExceptions: Bool, uniqueId: Int32) {
        self.name = name
        self.includeCategories = includeCategories
        self.additionallyIncludePeers = additionallyIncludePeers
        self.uniqueId = uniqueId
        self.applyReadMutedForExceptions = applyReadMutedForExceptions
    }
    
    init(decoder: PostboxDecoder) {
        self.name = decoder.decodeObjectForKey("name", decoder: { ChatListFilterPresetName(decoder: $0) }) as? ChatListFilterPresetName ?? ChatListFilterPresetName.custom("Preset")
        self.includeCategories = ChatListFilter(rawValue: decoder.decodeInt32ForKey("includeCategories", orElse: 0))
        self.additionallyIncludePeers = decoder.decodeInt64ArrayForKey("additionallyIncludePeers").map(PeerId.init)
        self.applyReadMutedForExceptions = decoder.decodeBoolForKey("applyReadMutedForExceptions", orElse: false)
        self.uniqueId = decoder.decodeInt32ForKey("uniqueId", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.name, forKey: "name")
        encoder.encodeInt32(self.includeCategories.rawValue, forKey: "includeCategories")
        encoder.encodeInt64Array(self.additionallyIncludePeers.map { $0.toInt64() }, forKey: "additionallyIncludePeers")
        encoder.encodeInt32(self.uniqueId, forKey: "uniqueId")
        encoder.encodeBool(self.applyReadMutedForExceptions, forKey: "applyReadMutedForExceptions")
    }
    
    var title: String {
        return name.title
    }
    var desc: String {
        var text: String = L10n.chatListFilterDescCustomized
        if includeCategories == [.muted, .read] {
            return "\(self.additionallyIncludePeers.count)"
        } else if includeCategories == ._unmuted {
           text = L10n.chatListFilterDescUnmuted
        } else if includeCategories == ._unread {
            text = L10n.chatListFilterDescUnread
        } else if includeCategories == ._privateChats {
            text = L10n.chatListFilterDescPrivateChats
        } else if includeCategories == ._groups {
            text = L10n.chatListFilterDescGroups
        } else if includeCategories == ._privateGroups {
            text = L10n.chatListFilterDescPrivateGroups
        } else if includeCategories == ._publicGroups {
            text = L10n.chatListFilterDescPublicGroups
        } else if includeCategories == ._channels {
            text = L10n.chatListFilterDescChannels
        } else if includeCategories == ._bots {
            text = L10n.chatListFilterDescBots
        } else if includeCategories == ._secretChats {
            text = L10n.chatListFilterDescSecretChats
        }
        
        if !self.additionallyIncludePeers.isEmpty {
            text = ", +\(self.additionallyIncludePeers.count)"
        }
        return text
    }
    
    var icon: CGImage {
        
        if includeCategories == ._unmuted {
            return theme.icons.chat_filter_unmuted
        } else if includeCategories == ._unread {
            return theme.icons.chat_filter_unread
        } else if includeCategories == ._groups || includeCategories == ._publicGroups || includeCategories == ._privateGroups {
            return theme.icons.chat_filter_groups
        } else if includeCategories == ._channels {
            return theme.icons.chat_filter_channels
        } else if includeCategories == ._privateChats {
            return theme.icons.chat_filter_private_chats
        } else if includeCategories == ._bots {
            return theme.icons.chat_filter_bots
        } else if includeCategories == ._secretChats {
            return theme.icons.chat_filter_secret_chats
        }
        
        return theme.icons.chat_filter_custom
    }
    
    static var new: ChatListFilterPreset {
        return ChatListFilterPreset(name: .custom(L10n.chatListFilterPresetNewName), includeCategories: .all, additionallyIncludePeers: [], applyReadMutedForExceptions: false, uniqueId: Int32(bitPattern: arc4random()))
    }
    
    func withToggleOption(_ option: ChatListFilter) -> ChatListFilterPreset {
        var includeCategories = self.includeCategories
        if includeCategories.contains(option) {
            includeCategories.remove(option)
        } else {
            includeCategories.insert(option)
        }
        return ChatListFilterPreset(name: self.name, includeCategories: includeCategories, additionallyIncludePeers: self.additionallyIncludePeers, applyReadMutedForExceptions: self.applyReadMutedForExceptions, uniqueId: self.uniqueId)
    }
    func withUpdatedName(_ name: ChatListFilterPresetName) -> ChatListFilterPreset {
        return ChatListFilterPreset(name: name, includeCategories: self.includeCategories, additionallyIncludePeers: self.additionallyIncludePeers, applyReadMutedForExceptions: self.applyReadMutedForExceptions, uniqueId: self.uniqueId)
    }
    func withUpdatedApplyReadMutedForExceptions(_ applyReadMutedForExceptions: Bool) -> ChatListFilterPreset {
        return ChatListFilterPreset(name: name, includeCategories: self.includeCategories, additionallyIncludePeers: self.additionallyIncludePeers, applyReadMutedForExceptions: applyReadMutedForExceptions, uniqueId: self.uniqueId)
    }
    func withAddedPeerIds(_ peerIds: [PeerId]) -> ChatListFilterPreset {
        var additionallyIncludePeers = self.additionallyIncludePeers
        additionallyIncludePeers.append(contentsOf: peerIds)
        return ChatListFilterPreset(name: self.name, includeCategories: self.includeCategories, additionallyIncludePeers: additionallyIncludePeers, applyReadMutedForExceptions: self.applyReadMutedForExceptions, uniqueId: self.uniqueId)
    }
    func withRemovedPeerId(_ peerId: PeerId) -> ChatListFilterPreset {
        var additionallyIncludePeers = self.additionallyIncludePeers
        additionallyIncludePeers.removeAll(where: { $0 == peerId })
        return ChatListFilterPreset(name: self.name, includeCategories: self.includeCategories, additionallyIncludePeers: additionallyIncludePeers, applyReadMutedForExceptions: self.applyReadMutedForExceptions, uniqueId: self.uniqueId)
    }
}



struct ChatListFilter: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let muted = ChatListFilter(rawValue: 1 << 1)
    static let privateChats = ChatListFilter(rawValue: 1 << 2)
    static let publicGroups = ChatListFilter(rawValue: 1 << 3)
    static let privateGroups = ChatListFilter(rawValue: 1 << 4)
    static let secretChats = ChatListFilter(rawValue: 1 << 5)
    static let bots = ChatListFilter(rawValue: 1 << 6)
    static let channels = ChatListFilter(rawValue: 1 << 7)
    static let read = ChatListFilter(rawValue: 1 << 8)
    static let all: ChatListFilter = [
        .muted,
        .privateChats,
        .privateGroups,
        .publicGroups,
        .secretChats,
        .bots,
        .channels,
        .read
    ]
    static let _unmuted: ChatListFilter = [
        .privateChats,
        .privateGroups,
        .publicGroups,
        .secretChats,
        .bots,
        .channels,
        .read]
    
    static let _unread: ChatListFilter = [
        .muted,
        .privateChats,
        .publicGroups,
        .privateGroups,
        .secretChats,
        .bots,
        .channels]
    
    static let _channels: ChatListFilter = [
        .muted,
        .channels,
        .read
    ]
    static let _groups: ChatListFilter = [
        .muted,
        .publicGroups,
        .privateGroups,
        .read
    ]
    static let _privateGroups: ChatListFilter = [
        .muted,
        .privateGroups,
        .read
    ]
    static let _publicGroups: ChatListFilter = [
        .muted,
        .publicGroups,
        .read
    ]
    static let _secretChats: ChatListFilter = [
        .muted,
        .secretChats,
        .read
    ]
    static let _privateChats: ChatListFilter = [
        .muted,
        .privateChats,
        .read
    ]
    static let _bots: ChatListFilter = [
        .muted,
        .bots,
        .read
    ]
    var string: String {
        return ""
    }
}

struct ChatListFilterPreferences: PreferencesEntry, Equatable {
    let presets: [ChatListFilterPreset]
    let needShowTooltip: Bool
    let tabsIsEnabled: Bool
    static var defaultSettings: ChatListFilterPreferences {
        var presets: [ChatListFilterPreset] = []
        
//        presets.append(ChatListFilterPreset(name: .privateChats, includeCategories: ._privateChats, additionallyIncludePeers: [], uniqueId: 0))
//        presets.append(ChatListFilterPreset(name: .channels, includeCategories: ._channels, additionallyIncludePeers: [], uniqueId: 1))
//        presets.append(ChatListFilterPreset(name: .groups, includeCategories: ._groups, additionallyIncludePeers: [], uniqueId: 2))
//        presets.append(ChatListFilterPreset(name: .bots, includeCategories: ._bots, additionallyIncludePeers: [], uniqueId: 3))
        presets.append(ChatListFilterPreset(name: .unread, includeCategories: ._unread, additionallyIncludePeers: [], applyReadMutedForExceptions: false, uniqueId: 4))
        presets.append(ChatListFilterPreset(name: .unmuted, includeCategories: ._unmuted, additionallyIncludePeers: [], applyReadMutedForExceptions: false, uniqueId: 5))
        
        return ChatListFilterPreferences(presets: presets, needShowTooltip: true, tabsIsEnabled: false)
    }
    
    init(presets: [ChatListFilterPreset], needShowTooltip: Bool, tabsIsEnabled: Bool) {
        self.presets = presets
        self.needShowTooltip = needShowTooltip
        self.tabsIsEnabled = tabsIsEnabled
    }
    
    init(decoder: PostboxDecoder) {
        self.presets = decoder.decodeObjectArrayWithDecoderForKey("presets")
        self.needShowTooltip = decoder.decodeBoolForKey("needShowTooltip", orElse: true)
        self.tabsIsEnabled = decoder.decodeBoolForKey("tabsIsEnabled", orElse: true)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.presets, forKey: "presets")
        encoder.encodeBool(self.needShowTooltip, forKey: "needShowTooltip")
        encoder.encodeBool(self.tabsIsEnabled, forKey: "tabsIsEnabled")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatListFilterPreferences {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: ChatListFilterPreferences, rhs: ChatListFilterPreferences) -> Bool {
        return lhs.presets == rhs.presets && lhs.needShowTooltip == rhs.needShowTooltip && lhs.tabsIsEnabled == rhs.tabsIsEnabled
    }
    
    func withAddedPreset(_ preset: ChatListFilterPreset, onlyReplace: Bool = false) -> ChatListFilterPreferences {
        var presets = self.presets
        if let index = presets.firstIndex(where: {$0.uniqueId == preset.uniqueId}) {
            presets[index] = preset
        } else if !onlyReplace {
            presets.append(preset)
        }
        return ChatListFilterPreferences(presets: presets, needShowTooltip: false, tabsIsEnabled: self.tabsIsEnabled)
    }
    
    func withRemovedPreset(_ preset: ChatListFilterPreset) -> ChatListFilterPreferences {
        var presets = self.presets
        presets.removeAll(where: {$0.uniqueId == preset.uniqueId })
        return ChatListFilterPreferences(presets: presets, needShowTooltip: false, tabsIsEnabled: self.tabsIsEnabled)
    }
    
    func withMovePreset(_ from: Int, _ to: Int) -> ChatListFilterPreferences {
        var presets = self.presets
        presets.insert(presets.remove(at: from), at: to)
        return ChatListFilterPreferences(presets: presets, needShowTooltip: false, tabsIsEnabled: self.tabsIsEnabled)
    }
    func withSelectedAtIndex(_ index: Int) -> ChatListFilterPreferences {
        return ChatListFilterPreferences(presets: self.presets, needShowTooltip: false, tabsIsEnabled: self.tabsIsEnabled)
    }
    
    func withUpdatedNeedShowTooltip(_ needShowTooltip: Bool) -> ChatListFilterPreferences {
        return ChatListFilterPreferences(presets: self.presets, needShowTooltip: needShowTooltip, tabsIsEnabled: self.tabsIsEnabled)
    }
    func withUpdatedTabEnable(_ tabsIsEnabled: Bool) -> ChatListFilterPreferences {
        return ChatListFilterPreferences(presets: self.presets, needShowTooltip: self.needShowTooltip, tabsIsEnabled: tabsIsEnabled)
    }
    func shortcut(for preset: ChatListFilterPreset?) -> String {
        if let preset = preset {
            for (i, value) in self.presets.enumerated() {
                if preset.uniqueId == value.uniqueId {
                    var shortcut: String = "⌃⌘\(i + 2)"
                    if i + 2 == 11 {
                        shortcut = "⌃⌘-"
                    }
                    return shortcut
                }
            }
        } else {
            return "⌃⌘1"
        }
        
        return ""
    }
}

func chatListFilterPreferences(postbox: Postbox) -> Signal<ChatListFilterPreferences, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.chatListSettings]) |> map { view in
        return view.values[ApplicationSpecificPreferencesKeys.chatListSettings] as? ChatListFilterPreferences ?? ChatListFilterPreferences.defaultSettings
    }
}

func updateChatListFilterPreferencesInteractively(postbox: Postbox, _ f: @escaping (ChatListFilterPreferences) -> ChatListFilterPreferences) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatListSettings, { entry in
            let currentSettings: ChatListFilterPreferences
            if let entry = entry as? ChatListFilterPreferences {
                currentSettings = entry
            } else {
                currentSettings = ChatListFilterPreferences.defaultSettings
            }
            return f(currentSettings)
        })
    }
}



func filtersBadgeCounters(context: AccountContext) -> Signal<[(id: Int32, count: Int32)], NoError>  {
    return chatListFilterPreferences(postbox: context.account.postbox) |> map { $0.presets } |> mapToSignal { filters -> Signal<[(id: Int32, count: Int32)], NoError> in
        
        var signals:[Signal<(id: Int32, count: Int32), NoError>] = []
        for current in filters {
            
            var unreadCountItems: [UnreadMessageCountsItem] = []
            unreadCountItems.append(.total(nil))
            var keys: [PostboxViewKey] = []
            let unreadKey: PostboxViewKey
            
            if !current.additionallyIncludePeers.isEmpty {
                for peerId in current.additionallyIncludePeers {
                    unreadCountItems.append(.peer(peerId))
                }
            }
            unreadKey = .unreadCounts(items: unreadCountItems)
            keys.append(unreadKey)
            for peerId in current.additionallyIncludePeers {
                keys.append(.basicPeer(peerId))
                
            }
            keys.append(.peerNotificationSettings(peerIds: Set(current.additionallyIncludePeers)))
            
            let s:Signal<(id: Int32, count: Int32), NoError> = combineLatest(context.account.postbox.combinedView(keys: keys), appNotificationSettings(accountManager: context.sharedContext.accountManager)) |> map { keysView, inAppSettings -> (id: Int32, count: Int32) in
                
                if let unreadCounts = keysView.views[unreadKey] as? UnreadMessageCountsView {
                    var peerTagAndCount: [PeerId: (PeerSummaryCounterTags, Int)] = [:]
                    var totalState: ChatListTotalUnreadState?
                    for entry in unreadCounts.entries {
                        switch entry {
                        case let .total(_, totalStateValue):
                            totalState = totalStateValue
                        case let .peer(peerId, state):
                            if let state = state, state.isUnread {
                                let notificationSettings = keysView.views[.peerNotificationSettings(peerIds: Set(current.additionallyIncludePeers))] as? PeerNotificationSettingsView
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
                                    if !current.includeCategories.contains(.muted), isRemoved {
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
                    if current.includeCategories.contains(.privateChats) {
                        tags.append(.privateChat)
                    }
                    
                    if current.includeCategories.contains(.publicGroups) {
                        tags.append(.publicGroup)
                    }
                    if current.includeCategories.contains(.privateGroups) {
                        tags.append(.privateGroup)
                    }
                    if current.includeCategories.contains(.secretChats) {
                        tags.append(.secretChat)
                    }
                    if current.includeCategories.contains(.bots) {
                        tags.append(.bot)
                    }
                    if current.includeCategories.contains(.channels) {
                        tags.append(.channel)
                    }
                    
                    var count:Int32 = 0
                    if let totalState = totalState {
                        for tag in tags {
                            
                            if let value = totalState.filteredCounters[tag] {
                                var removable = false
                                switch inAppSettings.totalUnreadCountDisplayStyle {
                                case .raw:
                                    removable = true
                                case .filtered:
                                    removable = true
                                }
                                if removable {
                                    switch inAppSettings.totalUnreadCountDisplayCategory {
                                    case .chats:
                                        count += value.chatCount
                                    case .messages:
                                        count += value.messageCount
                                    }
                                }
                            }
                        }
                    }
                    for peerId in current.additionallyIncludePeers {
                        if let (tag, peerCount) = peerTagAndCount[peerId] {
                            if !tags.contains(tag) {
                                count += Int32(peerCount)
                            }
                        }
                    }
                    return (id: current.uniqueId, count: count)
                } else {
                    return (id: current.uniqueId, count: 0)
                }
            }
            signals.append(s)
        }
        return combineLatest(signals)
    }
}
