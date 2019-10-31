//
//  AutoNightThemePreferences.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/08/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac
import TGUIKit



enum AutoNightSchedule : Equatable {
    case sunrise(latitude: Double, longitude: Double, localizedGeo: String?)
    case timeSensitive(from: Int32, to: Int32)
    
    fileprivate var typeValue: Int32 {
        switch self {
        case .sunrise:
            return 1
        case .timeSensitive:
            return 2
        }
    }
}

struct AutoNightThemePreferences: PreferencesEntry, Equatable {
    let schedule: AutoNightSchedule?
    let systemBased: Bool
    let theme: DefaultTheme
    static var defaultSettings: AutoNightThemePreferences {
        return AutoNightThemePreferences()
    }
    
    init() {
        self.schedule = nil
        self.theme = DefaultTheme(local: .tintedNight, cloud: nil)
        if #available(OSX 10.14, *) {
            self.systemBased = true
        } else {
            self.systemBased = false
        }
    }
    
    init(schedule: AutoNightSchedule?, theme: DefaultTheme, systemBased: Bool) {
        self.schedule = schedule
        self.theme = theme
        self.systemBased = systemBased
    }
    
    init(decoder: PostboxDecoder) {
        let type = decoder.decodeInt32ForKey("t", orElse: 0)
        
        let defaultTheme = DefaultTheme(local: .tintedNight, cloud: nil)
        
        self.theme = decoder.decodeObjectForKey("defTheme", decoder: { DefaultTheme(decoder: $0) }) as? DefaultTheme ?? defaultTheme
        self.systemBased = decoder.decodeBoolForKey("sb", orElse: false)
        switch type {
        case 1:
            let latitude = decoder.decodeDoubleForKey("la", orElse: 0)
            let longitude = decoder.decodeDoubleForKey("lo", orElse: 0)
            let localizedGeo = decoder.decodeOptionalStringForKey("lg")
            self.schedule = .sunrise(latitude: latitude, longitude: longitude, localizedGeo: localizedGeo)
        case 2:
            let from = decoder.decodeInt32ForKey("from", orElse: 22)
            let to = decoder.decodeInt32ForKey("to", orElse: 9)
            self.schedule = .timeSensitive(from: from, to: to)
        default:
            self.schedule = nil
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.theme, forKey: "defTheme")
        encoder.encodeBool(self.systemBased, forKey: "sb")
        if let schedule = schedule {
            encoder.encodeInt32(schedule.typeValue, forKey: "t")
            switch schedule {
            case let .sunrise(location):
                encoder.encodeDouble(location.latitude, forKey: "la")
                encoder.encodeDouble(location.longitude, forKey: "lo")
                if let localizedGeo = location.localizedGeo {
                    encoder.encodeString(localizedGeo, forKey: "lg")
                } else {
                    encoder.encodeNil(forKey: "lg")
                }
            case let .timeSensitive(from, to):
                encoder.encodeInt32(from, forKey: "from")
                encoder.encodeInt32(to, forKey: "to")
            }
        } else {
            encoder.encodeInt32(0, forKey: "t")
        }
    }
    

    func withUpdatedSchedule(_ schedule: AutoNightSchedule?) -> AutoNightThemePreferences {
        return AutoNightThemePreferences(schedule: schedule, theme: self.theme, systemBased: self.systemBased)
    }
    
    func withUpdatedTheme(_ theme: DefaultTheme) -> AutoNightThemePreferences {
        return AutoNightThemePreferences(schedule: self.schedule, theme: theme, systemBased: self.systemBased)
    }
    func withUpdatedSystemBased(_ systemBased: Bool) -> AutoNightThemePreferences {
        return AutoNightThemePreferences(schedule: self.schedule, theme: self.theme, systemBased: systemBased)
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AutoNightThemePreferences {
            return self == to
        } else {
            return false
        }
    }
    
}


func autoNightSettings(accountManager: AccountManager) -> Signal<AutoNightThemePreferences, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.autoNight]) |> map { $0.entries[ApplicationSharedPreferencesKeys.autoNight] as? AutoNightThemePreferences ?? AutoNightThemePreferences.defaultSettings }
}

func updateAutoNightSettingsInteractively(accountManager: AccountManager, _ f: @escaping (AutoNightThemePreferences) -> AutoNightThemePreferences) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.autoNight, { entry in
            let currentSettings: AutoNightThemePreferences
            if let entry = entry as? AutoNightThemePreferences {
                currentSettings = entry
            } else {
                currentSettings = AutoNightThemePreferences.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
