//
//  AutoplayPreferences.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit
import TelegramCore


public class AutoplayMediaPreferences : Codable, Equatable {
    public let gifs: Bool
    public let videos: Bool
    public let soundOnHover: Bool
    public let preloadVideos: Bool
    public let loopAnimatedStickers: Bool
    init(gifs: Bool, videos: Bool, soundOnHover: Bool, preloadVideos: Bool, loopAnimatedStickers: Bool ) {
        self.gifs = gifs
        self.videos = videos
        self.soundOnHover = soundOnHover
        self.preloadVideos = preloadVideos
        self.loopAnimatedStickers = loopAnimatedStickers
    }
    
    public static var defaultSettings: AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: true, videos: true, soundOnHover: true, preloadVideos: true, loopAnimatedStickers: true)
    }
    
    public required init(decoder: PostboxDecoder) {
        self.gifs = decoder.decodeInt32ForKey("g", orElse: 0) == 1
        self.videos = decoder.decodeInt32ForKey("v", orElse: 0) == 1
        self.soundOnHover = decoder.decodeInt32ForKey("soh", orElse: 0) == 1
        self.preloadVideos = decoder.decodeInt32ForKey("pv", orElse: 0) == 1
        self.loopAnimatedStickers = decoder.decodeInt32ForKey("las", orElse: 0) == 1
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(gifs ? 1 : 0, forKey: "g")
        encoder.encodeInt32(videos ? 1 : 0, forKey: "v")
        encoder.encodeInt32(soundOnHover ? 1 : 0, forKey: "soh")
        encoder.encodeInt32(preloadVideos ? 1 : 0, forKey: "pv")
        encoder.encodeInt32(loopAnimatedStickers ? 1 : 0, forKey: "las")
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.gifs = try container.decode(Int32.self, forKey: "g") == 1
        self.videos = try container.decode(Int32.self, forKey: "v") == 1
        self.soundOnHover = try container.decode(Int32.self, forKey: "soh") == 1
        self.preloadVideos = try container.decode(Int32.self, forKey: "pv") == 1
        self.loopAnimatedStickers = try container.decode(Int32.self, forKey: "las") == 1

    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(Int32(self.gifs ? 1 : 0), forKey: "g")
        try container.encode(Int32(self.videos ? 1 : 0), forKey: "v")
        try container.encode(Int32(self.soundOnHover ? 1 : 0), forKey: "soh")
        try container.encode(Int32(self.preloadVideos ? 1 : 0), forKey: "pv")
        try container.encode(Int32(self.loopAnimatedStickers ? 1 : 0), forKey: "las")
    }
    
    public static func == (lhs: AutoplayMediaPreferences, rhs: AutoplayMediaPreferences) -> Bool {
        return lhs.gifs == rhs.gifs && lhs.videos == rhs.videos && lhs.soundOnHover == rhs.soundOnHover && lhs.preloadVideos == rhs.preloadVideos && lhs.loopAnimatedStickers == rhs.loopAnimatedStickers
    }
    
    public func withUpdatedAutoplayGifs(_ gifs: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: gifs, videos: self.videos, soundOnHover: self.soundOnHover, preloadVideos: self.preloadVideos, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    public func withUpdatedAutoplayVideos(_ videos: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: self.gifs, videos: videos, soundOnHover: self.soundOnHover, preloadVideos: self.preloadVideos, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    public func withUpdatedAutoplaySoundOnHover(_ soundOnHover: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: self.gifs, videos: self.videos, soundOnHover: soundOnHover, preloadVideos: self.preloadVideos, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    public func withUpdatedAutoplayPreloadVideos(_ preloadVideos: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: self.gifs, videos: self.videos, soundOnHover: self.soundOnHover, preloadVideos: preloadVideos, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    public func withUpdatedLoopAnimatedStickers(_ loopAnimatedStickers: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: self.gifs, videos: self.videos, soundOnHover: self.soundOnHover, preloadVideos: self.preloadVideos, loopAnimatedStickers: loopAnimatedStickers)
    }
}


public func updateAutoplayMediaSettingsInteractively(postbox: Postbox, _ f: @escaping (AutoplayMediaPreferences) -> AutoplayMediaPreferences) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.autoplayMedia, { entry in
            let currentSettings: AutoplayMediaPreferences
            if let entry = entry?.get(AutoplayMediaPreferences.self) {
                currentSettings = entry
            } else {
                currentSettings = AutoplayMediaPreferences.defaultSettings
            }
            
            return PreferencesEntry(f(currentSettings))
        })
    }
}


public func autoplayMediaSettings(postbox: Postbox) -> Signal<AutoplayMediaPreferences, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.autoplayMedia]) |> map { views in
        return views.values[ApplicationSpecificPreferencesKeys.autoplayMedia]?.get(AutoplayMediaPreferences.self) ?? AutoplayMediaPreferences.defaultSettings
    }
}
