//
//  TelegramMediaProxySettings.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 31/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac

final class TelegramMediaProxySettings: Media, Equatable {
    let settings: ProxyServerSettings
    init(settings: ProxyServerSettings) {
        self.settings = settings
    }
    public var id: MediaId? {
        return nil
    }
    var peerIds: [PeerId] {
        return []
    }
    
    func isLikelyToBeUpdated() -> Bool {
        return false
    }
    
    static func ==(lhs: TelegramMediaProxySettings, rhs: TelegramMediaProxySettings) -> Bool {
        return lhs.settings == rhs.settings
    }
    
    func isEqual(_ other: Media) -> Bool {
        if let other = other as? TelegramMediaProxySettings {
            return other == self
        } else {
            return false
        }
    }
    public init(decoder: PostboxDecoder) {
       self.settings = decoder.decodeObjectForKey("ps") as! ProxyServerSettings
    }
    
    public func encode(_ encoder: PostboxEncoder) {
       encoder.encodeObject(settings, forKey: "ps")
    }
}
