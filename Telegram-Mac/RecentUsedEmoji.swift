//
//  RecentUsedEmoji.swift
//  Telegram
//
//  Created by keepcoder on 20/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit
import TelegramCore

struct EmojiSkinModifier : Codable, Equatable {
    let emoji: String
    let modifier: String
    init(emoji: String, modifier: String) {
        var emoji = emoji
        for skin in emoji.emojiSkinToneModifiers {
            emoji = emoji.replacingOccurrences(of: skin, with: "")
        }
        self.emoji = emoji
        self.modifier = modifier
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(emoji, forKey: "e")
        try container.encode(modifier, forKey: "m")
    }
    
    var modify: String {
        var e:String = emoji
        if emoji.length == 5 {
            let mutable = NSMutableString()
            mutable.insert(e, at: 0)
            mutable.insert(modifier, at: 2)
            e = mutable as String
        } else {
            e = emoji + modifier
        }
        return e
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.emoji = try container.decode(String.self, forKey: "e")
        self.modifier = try container.decode(String.self, forKey: "m")
    }
}

class RecentUsedEmoji: Codable, Equatable {
    private let _emojies:[String]
    let skinModifiers:[EmojiSkinModifier]
    init(emojies:[String], skinModifiers: [EmojiSkinModifier]) {
        self._emojies = emojies
        self.skinModifiers = skinModifiers
    }
    
    public static var defaultSettings: RecentUsedEmoji {
        return RecentUsedEmoji(emojies: ["😂", "😘", "❤️", "😍", "😊", "🤔", "😁", "👍", "☺️", "😔", "😄", "😭", "💋", "😒", "😳", "😜", "🙈", "😉", "😃", "😢", "😝", "😱", "😡", "😏", "😞", "😅", "😚", "🙊", "😌", "😀", "😋", "😆", "🌚", "😐", "😕", "👎", diceSymbol, dartSymbol], skinModifiers: [])
    }
    
    var emojies: [String] {
        var isset:[String: String] = [:]
        var list:[String] = []
        for emoji in _emojies {
            if isset[emoji] == nil, emoji != "�", !emoji.emojiSkinToneModifiers.contains(emoji), emoji != "️" {
                var emoji = emoji
                isset[emoji] = emoji
                for skin in skinModifiers {
                    if skin.emoji == emoji {
                        emoji = skin.modify
                    }
                }
                list.append(emoji.nsstring.substring(with: NSMakeRange(0, min(emoji.length, 8))))
            }
        }
        return list.reduce([], { current, value in
            var value = value
            if let modifier = value.emojiSkinToneModifiers.first(where: { value.contains($0) }), value.glyphCount > 1 {
                value = value.replacingOccurrences(of: modifier, with: "")
            }
            if let first = value.first {
                return current + [String(first)]
            } else {
                return current
            }
        })
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let emojies = try container.decode([String].self, forKey: "e")
        self.skinModifiers = try container.decode([EmojiSkinModifier].self, forKey: "sm_new")

        var isset:[String: String] = [:]
        var list:[String] = []
        for emoji in emojies {
            if isset[emoji] == nil, emoji != "�", !emoji.emojiSkinToneModifiers.contains(emoji), emoji != "️" {
                var emoji = emoji
                isset[emoji] = emoji
                for skin in skinModifiers {
                    if skin.emoji == emoji {
                        emoji = skin.modify
                    }
                }
                list.append(emoji)
            }
        }
        self._emojies = list
        
        
    }
    
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(_emojies, forKey: "e")
        try container.encode(skinModifiers, forKey: "sm_new")
    }
}

func ==(lhs: RecentUsedEmoji, rhs: RecentUsedEmoji) -> Bool {
    return lhs.emojies == rhs.emojies && lhs.skinModifiers == rhs.skinModifiers
}


func saveUsedEmoji(_ list:[String], postbox:Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.recentEmoji, { entry in
            var emojies: [String]
            if let entry = entry?.get(RecentUsedEmoji.self) {
                emojies = entry.emojies
            } else {
                emojies = RecentUsedEmoji.defaultSettings.emojies
            }
            
            for emoji in list.reversed() {
                if emoji.containsOnlyEmoji {
                    let emoji = emoji.emojiString.emojiUnmodified
                    if !emoji.isEmpty && emoji.count == 1 {
                        if let index = emojies.firstIndex(of: emoji) {
                            emojies.remove(at: index)
                        }
                        emojies.insert(emoji, at: 0)
                    }
                }
            }
            emojies = Array(emojies.filter({$0.containsEmoji}).prefix(35))
            return PreferencesEntry(RecentUsedEmoji(emojies: emojies, skinModifiers: entry?.get(RecentUsedEmoji.self)?.skinModifiers ?? []))
        })
    }
}

func modifySkinEmoji(_ emoji:String, modifier: String?, postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.recentEmoji, { entry in
            let settings = entry?.get(RecentUsedEmoji.self) ?? RecentUsedEmoji.defaultSettings
            var skinModifiers = settings.skinModifiers
            let index:Int? = skinModifiers.firstIndex(where: {$0.emoji == emoji})
            
            if let modifier = modifier {
                if let index = index {
                    skinModifiers[index] = EmojiSkinModifier(emoji: emoji, modifier: modifier)
                } else {
                    skinModifiers.append(EmojiSkinModifier(emoji: emoji, modifier: modifier))
                }
            } else if let index = index {
                skinModifiers.remove(at: index)
            }
           
            return PreferencesEntry(RecentUsedEmoji(emojies: settings.emojies, skinModifiers: skinModifiers))
            
        })
    }
}

func recentUsedEmoji(postbox: Postbox) -> Signal<RecentUsedEmoji, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.recentEmoji]) |> map { preferences in
        return preferences.values[ApplicationSpecificPreferencesKeys.recentEmoji]?.get(RecentUsedEmoji.self) ?? RecentUsedEmoji.defaultSettings
    }
}
