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

struct EmojiSkinModifier : PostboxCoding, Equatable {
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
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(emoji, forKey: "e")
        encoder.encodeString(modifier, forKey: "m")
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
    
    init(decoder: PostboxDecoder) {
         self.emoji = decoder.decodeStringForKey("e", orElse: "")
         self.modifier = decoder.decodeStringForKey("m", orElse: "")
        var bp:Int = 0
        bp += 1
    }
}

class RecentUsedEmoji: PreferencesEntry, Equatable {
    private let _emojies:[String]
    let skinModifiers:[EmojiSkinModifier]
    init(emojies:[String], skinModifiers: [EmojiSkinModifier]) {
        self._emojies = emojies
        self.skinModifiers = skinModifiers
    }
    
    public static var defaultSettings: RecentUsedEmoji {
        return RecentUsedEmoji(emojies: ["😂", "😘", "❤️", "😍", "😊", "🤔", "😁", "👍", "☺️", "😔", "😄", "😭", "💋", "😒", "😳", "😜", "🙈", "😉", "😃", "😢", "😝", "😱", "😡", "😏", "😞", "😅", "😚", "🙊", "😌", "😀", "😋", "😆", "🌚", "😐", "😕", "👎"], skinModifiers: [])
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
                list.append(emoji)
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
    
    public required init(decoder: PostboxDecoder) {
        let emojies = decoder.decodeStringArrayForKey("e")
        self.skinModifiers = (try? decoder.decodeObjectArrayWithCustomDecoderForKey("sm_new", decoder: {EmojiSkinModifier(decoder: $0)})) ?? []

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
    
    
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? RecentUsedEmoji {
            return self == to
        } else {
            return false
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(_emojies, forKey: "e")
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
                if !emoji.isEmpty && emoji.count == 1 {
                    if let index = emojies.firstIndex(of: emoji) {
                        emojies.remove(at: index)
                    }
                    emojies.insert(emoji, at: 0)
                }
            }
            emojies = Array(emojies.filter({$0.containsEmoji}).prefix(35))
            return RecentUsedEmoji(emojies: emojies, skinModifiers: (entry as? RecentUsedEmoji)?.skinModifiers ?? [])
        })
    }
}

func modifySkinEmoji(_ emoji:String, modifier: String?, postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.recentEmoji, { entry in
            let settings = (entry as? RecentUsedEmoji) ?? RecentUsedEmoji.defaultSettings
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
           
            return RecentUsedEmoji(emojies: settings.emojies, skinModifiers: skinModifiers)
            
        })
    }
}

func recentUsedEmoji(postbox: Postbox) -> Signal<RecentUsedEmoji, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.recentEmoji]) |> map { preferences in
        
        return (preferences.values[ApplicationSpecificPreferencesKeys.recentEmoji] as? RecentUsedEmoji) ?? RecentUsedEmoji.defaultSettings
    }
}
