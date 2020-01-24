//
//  ChatListFilterPreferences.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Postbox
import SwiftSignalKit


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
    
    static let all: ChatListFilter = [
        .muted,
        .privateChats,
        .groups,
        .bots,
        .channels
    ]
    static let workMode: ChatListFilter = [
        .privateChats,
        .groups,
        .bots,
        .channels]
}

struct ChatListFilterPreferences: PreferencesEntry, Equatable {
    let filter: ChatListFilter
    
    static var defaultSettings: ChatListFilterPreferences {
        return ChatListFilterPreferences(filter: .all)
    }
    
    init(filter: ChatListFilter) {
        self.filter = filter
    }
    
    init(decoder: PostboxDecoder) {
        self.filter = ChatListFilter(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.filter.rawValue, forKey: "f")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatListFilterPreferences {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: ChatListFilterPreferences, rhs: ChatListFilterPreferences) -> Bool {
        return lhs.filter == rhs.filter
    }
    
    func withUpdatedFilter(_ filter: ChatListFilter) -> ChatListFilterPreferences {
        return ChatListFilterPreferences(filter: filter)
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
