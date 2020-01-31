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
    case groups
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
            self = .groups
        case 4:
            self = .bots
        case 5:
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
        case .groups:
            encoder.encodeInt32(3, forKey: "_t")
        case .bots:
            encoder.encodeInt32(4, forKey: "_t")
        case .unread:
            encoder.encodeInt32(5, forKey: "_t")
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
        case .groups:
            return L10n.chatListFilterGroups
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
        return self.includeCategories.string
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
    static let groups = ChatListFilter(rawValue: 1 << 3)
    static let bots = ChatListFilter(rawValue: 1 << 4)
    static let channels = ChatListFilter(rawValue: 1 << 5)
    static let read = ChatListFilter(rawValue: 1 << 6)
    static let all: ChatListFilter = [
        .muted,
        .privateChats,
        .groups,
        .bots,
        .channels,
        .read
    ]
    static let _workMode: ChatListFilter = [
        .privateChats,
        .groups,
        .bots,
        .channels,
        .read]
    
    static let _unread: ChatListFilter = [
        .muted,
        .privateChats,
        .groups,
        .bots,
        .channels]
    
    static let _channels: ChatListFilter = [
        .muted,
        .channels,
        .read
    ]
    static let _groups: ChatListFilter = [
        .muted,
        .groups,
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
    let current: ChatListFilterPreset?
    let presets: [ChatListFilterPreset]
    let needShowTooltip: Bool
    static var defaultSettings: ChatListFilterPreferences {
        var presets: [ChatListFilterPreset] = []
        
//        presets.append(ChatListFilterPreset(name: .privateChats, includeCategories: ._privateChats, additionallyIncludePeers: [], uniqueId: 0))
//        presets.append(ChatListFilterPreset(name: .channels, includeCategories: ._channels, additionallyIncludePeers: [], uniqueId: 1))
//        presets.append(ChatListFilterPreset(name: .groups, includeCategories: ._groups, additionallyIncludePeers: [], uniqueId: 2))
//        presets.append(ChatListFilterPreset(name: .bots, includeCategories: ._bots, additionallyIncludePeers: [], uniqueId: 3))
        presets.append(ChatListFilterPreset(name: .unread, includeCategories: ._unread, additionallyIncludePeers: [], applyReadMutedForExceptions: false, uniqueId: 4))
        presets.append(ChatListFilterPreset(name: .unmuted, includeCategories: ._workMode, additionallyIncludePeers: [], applyReadMutedForExceptions: false, uniqueId: 5))
        
        return ChatListFilterPreferences(current: nil, presets: presets, needShowTooltip: true)
    }
    
    init(current: ChatListFilterPreset?, presets: [ChatListFilterPreset], needShowTooltip: Bool) {
        self.current = current
        self.presets = presets
        self.needShowTooltip = needShowTooltip
    }
    
    init(decoder: PostboxDecoder) {
        self.current = decoder.decodeObjectForKey("current") as? ChatListFilterPreset
        self.presets = decoder.decodeObjectArrayWithDecoderForKey("presets")
        self.needShowTooltip = decoder.decodeBoolForKey("needShowTooltip", orElse: true)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let current = current {
            encoder.encodeObject(current, forKey: "current")
        } else {
            encoder.encodeNil(forKey: "current")
        }
        encoder.encodeObjectArray(self.presets, forKey: "presets")
        encoder.encodeBool(self.needShowTooltip, forKey: "needShowTooltip")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatListFilterPreferences {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: ChatListFilterPreferences, rhs: ChatListFilterPreferences) -> Bool {
        return lhs.current == rhs.current && lhs.presets == rhs.presets && lhs.needShowTooltip == rhs.needShowTooltip
    }
    
    func withUpdatedCurrentPreset(_ current: ChatListFilterPreset?) -> ChatListFilterPreferences {
        return ChatListFilterPreferences(current: current, presets: self.presets, needShowTooltip: false)
    }
    func withAddedPreset(_ preset: ChatListFilterPreset, onlyReplace: Bool = false) -> ChatListFilterPreferences {
        var presets = self.presets
        if let index = presets.firstIndex(where: {$0.uniqueId == preset.uniqueId}) {
            presets[index] = preset
        } else if !onlyReplace {
            presets.append(preset)
        }
        var current = self.current
        if current?.uniqueId == preset.uniqueId {
            current = preset
        }
        return ChatListFilterPreferences(current: current, presets: presets, needShowTooltip: false)
    }
    
    func withRemovedPreset(_ preset: ChatListFilterPreset) -> ChatListFilterPreferences {
        var presets = self.presets
        presets.removeAll(where: {$0.uniqueId == preset.uniqueId })
        var current = self.current
        if current?.uniqueId == preset.uniqueId {
            current = nil
        }
        return ChatListFilterPreferences(current: current, presets: presets, needShowTooltip: false)
    }
    
    func withMovePreset(_ from: Int, _ to: Int) -> ChatListFilterPreferences {
        var presets = self.presets
        presets.insert(presets.remove(at: from), at: to)
        return ChatListFilterPreferences(current: self.current, presets: presets, needShowTooltip: false)
    }
    func withSelectedAtIndex(_ index: Int) -> ChatListFilterPreferences {
        var current = self.current
        if index < self.presets.count {
            current = self.presets[index]
        }
        return ChatListFilterPreferences(current: current, presets: self.presets, needShowTooltip: false)
    }
    
    func withUpdatedNeedShowTooltip(_ needShowTooltip: Bool) -> ChatListFilterPreferences {
        return ChatListFilterPreferences(current: self.current, presets: self.presets, needShowTooltip: needShowTooltip)
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
