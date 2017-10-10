//
//  BaseApplicationSettings.swift
//  Telegram
//
//  Created by keepcoder on 05/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac
class BaseApplicationSettings: PreferencesEntry, Equatable {
    let fontSize: Int32
    let handleInAppKeys: Bool
    let sidebar: Bool
    
    static var defaultSettings: BaseApplicationSettings {
        return BaseApplicationSettings(fontSize: 13, handleInAppKeys: false, sidebar: true)
    }
    
    init(fontSize:Int32, handleInAppKeys: Bool, sidebar: Bool) {
        self.fontSize = fontSize
        self.handleInAppKeys = handleInAppKeys
        self.sidebar = sidebar
    }
    
    required init(decoder: PostboxDecoder) {
        self.fontSize = decoder.decodeInt32ForKey("f", orElse: 0)
        self.handleInAppKeys = decoder.decodeInt32ForKey("h", orElse: 0) != 0
        self.sidebar = decoder.decodeInt32ForKey("e", orElse: 0) != 0
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.fontSize, forKey: "f")
        encoder.encodeInt32(self.handleInAppKeys ? 1 : 0, forKey: "h")
        encoder.encodeInt32(self.sidebar ? 1 : 0, forKey: "e")
    }
    
    func withUpdatedFontSize(_ fontSize: Int32) -> BaseApplicationSettings {
        return BaseApplicationSettings(fontSize: fontSize, handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar)
    }
    
    func withUpdatedSidebar(_ sidebar: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(fontSize: self.fontSize, handleInAppKeys: self.handleInAppKeys, sidebar: sidebar)
    }
    
    func withUpdatedInAppKeyHandle(_ handleInAppKeys: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(fontSize: self.fontSize, handleInAppKeys: handleInAppKeys, sidebar: self.sidebar)
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? BaseApplicationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: BaseApplicationSettings, rhs: BaseApplicationSettings) -> Bool {
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.handleInAppKeys != rhs.handleInAppKeys {
            return false
        }
        if lhs.sidebar != rhs.sidebar {
            return false
        }
        return true
    }

}


func updateBaseAppSettingsInteractively(postbox: Postbox, _ f: @escaping (BaseApplicationSettings) -> BaseApplicationSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.baseAppSettings, { entry in
            let currentSettings: BaseApplicationSettings
            if let entry = entry as? BaseApplicationSettings {
                currentSettings = entry
            } else {
                currentSettings = BaseApplicationSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
