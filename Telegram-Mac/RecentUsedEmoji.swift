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

class RecentUsedEmoji: PreferencesEntry, Equatable {
    let emojies:[String]
    let skinModifiers:[String]
    init(emojies:[String], skinModifiers: [String]) {
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
            if isset[emoji] == nil {
                list.append(emoji)
                isset[emoji] = emoji
            }
        }
        self.emojies = list
        
        self.skinModifiers = decoder.decodeStringArrayForKey("sm")
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
        encoder.encodeStringArray(skinModifiers, forKey: "sm")
    }
}

func ==(lhs: RecentUsedEmoji, rhs: RecentUsedEmoji) -> Bool {
    return lhs.emojies == rhs.emojies && lhs.skinModifiers == rhs.skinModifiers
}


func saveUsedEmoji(_ list:[String], postbox:Postbox) -> Signal<Void, Void> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.recentEmoji, { entry in
            var emojies: [String]
            if let entry = entry as? RecentUsedEmoji {
                emojies = entry.emojies
            } else {
                emojies = RecentUsedEmoji.defaultSettings.emojies
            }
            
            for emoji in list.reversed() {
                let emoji = emoji.emojiString
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

func modifySkinEmoji(_ emoji:String, postbox: Postbox) -> Signal<Void, Void> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.recentEmoji, { entry in
            if let settings = (entry as? RecentUsedEmoji) {
                var skinModifiers = settings.skinModifiers
                var index:Int? = nil
                for i in 0 ..< skinModifiers.count {
                    let local = skinModifiers[i]
                    if emoji.emojiUnmodified == local.emojiUnmodified {
                        index = i
                    }
                }
                
                if let index = index {
                    skinModifiers[index] = emoji
                } else {
                    skinModifiers.append(emoji)
                }
                return RecentUsedEmoji(emojies: settings.emojies, skinModifiers: skinModifiers)
            }
            
            return entry
        })
    }
}

func recentUsedEmoji(postbox: Postbox) -> Signal<RecentUsedEmoji, Void> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.recentEmoji]) |> map { preferences in
        return (preferences.values[ApplicationSpecificPreferencesKeys.recentEmoji] as? RecentUsedEmoji) ?? RecentUsedEmoji.defaultSettings
    }
}
