//
//  RecentUsedEmoji.swift
//  Telegram
//
//  Created by keepcoder on 20/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac

struct EmojiSkinModifier : PostboxCoding, Equatable {
    let emoji: String
    let modifier: String
    init(emoji: String, modifier: String) {
        self.emoji = emoji
        self.modifier = modifier
    }
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(emoji, forKey: "e")
        encoder.encodeString(modifier, forKey: "m")
    }
    
    init(decoder: PostboxDecoder) {
         self.emoji = decoder.decodeStringForKey("e", orElse: "")
         self.modifier = decoder.decodeStringForKey("m", orElse: "")
    }
}

class RecentUsedEmoji: PreferencesEntry, Equatable {
    let emojies:[String]
    let skinModifiers:[EmojiSkinModifier]
    init(emojies:[String], skinModifiers: [EmojiSkinModifier]) {
        self.emojies = emojies
        self.skinModifiers = skinModifiers
    }
    
    public static var defaultSettings: RecentUsedEmoji {
        return RecentUsedEmoji(emojies: ["😂", "😘", "❤️", "😍", "😊", "🤔", "😁", "👍", "☺️", "😔", "😄", "😭", "💋", "😒", "😳", "😜", "🙈", "😉", "😃", "😢", "😝", "😱", "😡", "😏", "😞", "😅", "😚", "🙊", "😌", "😀", "😋", "😆", "😐", "😕", "👎"], skinModifiers: [])
    }
    
    public required init(decoder: PostboxDecoder) {
        let emojies = decoder.decodeStringArrayForKey("e")
        
        var isset:[String: String] = [:]
        var list:[String] = []
        for emoji in emojies {
            if isset[emoji] == nil, emoji != "�" {
                list.append(emoji)
                isset[emoji] = emoji
            }
        }
        self.emojies = list
        
        self.skinModifiers = decoder.decodeObjectForKey("sm_new", decoder: {EmojiSkinModifier(decoder: $0)}) as? [EmojiSkinModifier] ?? []
        
    }
    
    
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? RecentUsedEmoji {
            return self == to
        } else {
            return false
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(emojies, forKey: "e")
        encoder.encodeObjectArray(skinModifiers, forKey: "sm_new")
    }
}

func ==(lhs: RecentUsedEmoji, rhs: RecentUsedEmoji) -> Bool {
    return lhs.emojies == rhs.emojies && lhs.skinModifiers == rhs.skinModifiers
}


func saveUsedEmoji(_ list:[String], postbox:Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.recentEmoji, { entry in
            var emojies: [String]
            if let entry = entry as? RecentUsedEmoji {
                emojies = entry.emojies
            } else {
                emojies = RecentUsedEmoji.defaultSettings.emojies
            }
            
            for emoji in list.reversed() {
                let emoji = emoji.emojiString.emojiUnmodified
                if !emoji.isEmpty {
                    if let index = emojies.index(of: emoji) {
                        emojies.remove(at: index)
                    }
                    emojies.insert(emoji, at: 0)
                }
            }
            emojies = Array(emojies.prefix(35))
            return RecentUsedEmoji(emojies: emojies, skinModifiers: (entry as? RecentUsedEmoji)?.skinModifiers ?? [])
        })
    }
}

func modifySkinEmoji(_ emoji:String, postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.recentEmoji, { entry in
            let settings = (entry as? RecentUsedEmoji) ?? RecentUsedEmoji.defaultSettings
            var skinModifiers = settings.skinModifiers
            let index:Int? = skinModifiers.firstIndex(where: {$0.emoji == emoji.emojiUnmodified})
            
            if let index = index {
                skinModifiers[index] = EmojiSkinModifier(emoji: emoji.emojiUnmodified, modifier: emoji.emojiSkin)
            } else {
                skinModifiers.append(EmojiSkinModifier(emoji: emoji.emojiUnmodified, modifier: emoji.emojiSkin))
            }
            return RecentUsedEmoji(emojies: settings.emojies, skinModifiers: skinModifiers)
            
        })
    }
}

func recentUsedEmoji(postbox: Postbox) -> Signal<RecentUsedEmoji, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.recentEmoji]) |> map { preferences in
        return (preferences.values[ApplicationSpecificPreferencesKeys.recentEmoji] as? RecentUsedEmoji) ?? RecentUsedEmoji.defaultSettings
    }
}
