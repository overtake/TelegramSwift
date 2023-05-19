import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

public enum EmojiStickerSuggestionMode: Int32 {
    case none
    case all
    case installed
}

public struct StickerSettings: Codable, Equatable {
    public var emojiStickerSuggestionMode: EmojiStickerSuggestionMode
    public var trendingClosedOn: Int64?
    public static var defaultSettings: StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: .all, trendingClosedOn: nil)
    }
    
    public init(emojiStickerSuggestionMode: EmojiStickerSuggestionMode, trendingClosedOn: Int64?) {
        self.emojiStickerSuggestionMode = emojiStickerSuggestionMode
        self.trendingClosedOn = trendingClosedOn
    }
    
    public init(decoder: PostboxDecoder) {
        self.emojiStickerSuggestionMode = EmojiStickerSuggestionMode(rawValue: decoder.decodeInt32ForKey("emojiStickerSuggestionMode", orElse: 0))!
        self.trendingClosedOn = decoder.decodeOptionalInt64ForKey("t.c.o")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.emojiStickerSuggestionMode.rawValue, forKey: "emojiStickerSuggestionMode")
        if let trendingClosedOn = self.trendingClosedOn {
            encoder.encodeInt64(trendingClosedOn, forKey: "t.c.o")
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        let emoji = try container.decode(Int32.self, forKey: "emojiStickerSuggestionMode")
        
        self.emojiStickerSuggestionMode = EmojiStickerSuggestionMode(rawValue: emoji)!
        self.trendingClosedOn = try container.decodeIfPresent(Int64.self, forKey: "t.c.o")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(emojiStickerSuggestionMode.rawValue, forKey: "emojiStickerSuggestionMode")
        try container.encodeIfPresent(self.trendingClosedOn, forKey: "t.c.o")
    }
    
    public func withUpdatedEmojiStickerSuggestionMode(_ emojiStickerSuggestionMode: EmojiStickerSuggestionMode) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: emojiStickerSuggestionMode, trendingClosedOn: self.trendingClosedOn)
    }
    public func withUpdatedTrendingClosedOn(_ trendingClosedOn: Int64?) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: self.emojiStickerSuggestionMode, trendingClosedOn: trendingClosedOn)
    }
}

public func updateStickerSettingsInteractively(postbox: Postbox, _ f: @escaping (StickerSettings) -> StickerSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.stickerSettings, { entry in
            let currentSettings: StickerSettings
            if let entry = entry?.get(StickerSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = StickerSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

public func stickerSettings(postbox: Postbox) -> Signal<StickerSettings, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.stickerSettings]) |> map { preferencesView in
        var stickerSettings = StickerSettings.defaultSettings
        if let value = preferencesView.values[ApplicationSpecificPreferencesKeys.stickerSettings]?.get(StickerSettings.self) {
            stickerSettings = value
        }
        return stickerSettings
    }
}
