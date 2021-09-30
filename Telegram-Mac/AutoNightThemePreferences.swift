//
//  AutoNightThemePreferences.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/08/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit
import TGUIKit
import TelegramCore


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

struct AutoNightThemePreferences: Codable, Equatable {
    let schedule: AutoNightSchedule?
    let systemBased: Bool
    let theme: DefaultTheme
    static var defaultSettings: AutoNightThemePreferences {
        return AutoNightThemePreferences()
    }
    
    init() {
        self.schedule = nil
        self.theme = DefaultTheme(local: .nightAccent, cloud: nil)
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        let type = try container.decode(Int32.self, forKey: "t")
        
        let defaultTheme = DefaultTheme(local: .nightAccent, cloud: nil)
        
        self.theme = try container.decodeIfPresent(DefaultTheme.self, forKey: "defTheme") ?? defaultTheme
        self.systemBased = try container.decode(Bool.self, forKey: "sb")
        switch type {
        case 1:
            let latitude = try container.decode(Double.self, forKey: "la")
            let longitude = try container.decode(Double.self, forKey: "lo")
            let localizedGeo = try container.decodeIfPresent(String.self, forKey: "lg")
            self.schedule = .sunrise(latitude: latitude, longitude: longitude, localizedGeo: localizedGeo)
        case 2:
            let from = try container.decodeIfPresent(Int32.self, forKey: "from") ?? 22
            let to = try container.decodeIfPresent(Int32.self, forKey: "to") ?? 9
            self.schedule = .timeSensitive(from: from, to: to)
        default:
            self.schedule = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.theme, forKey: "defTheme")
        try container.encode(self.systemBased, forKey: "sb")
        if let schedule = schedule {
            try container.encode(schedule.typeValue, forKey: "t")
            switch schedule {
            case let .sunrise(latitude, longitude, localizedGeo):
                try container.encode(latitude, forKey: "la")
                try container.encode(longitude, forKey: "lo")
                if let localizedGeo = localizedGeo {
                    try container.encode(localizedGeo, forKey: "lg")
                } else {
                    try container.encodeNil(forKey: "lg")
                }
            case let .timeSensitive(from, to):
                try container.encode(from, forKey: "from")
                try container.encode(to, forKey: "to")
            }
        } else {
            try container.encode(0, forKey: "t")
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
    
}


func autoNightSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<AutoNightThemePreferences, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.autoNight]) |> map { $0.entries[ApplicationSharedPreferencesKeys.autoNight]?.get(AutoNightThemePreferences.self) ?? AutoNightThemePreferences.defaultSettings }
}

func updateAutoNightSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (AutoNightThemePreferences) -> AutoNightThemePreferences) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.autoNight, { entry in
            let currentSettings: AutoNightThemePreferences
            if let entry = entry?.get(AutoNightThemePreferences.self) {
                currentSettings = entry
            } else {
                currentSettings = AutoNightThemePreferences.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
