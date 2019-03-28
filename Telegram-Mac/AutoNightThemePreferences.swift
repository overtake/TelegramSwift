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
    case sunrise(latitude: Double, longitude: Double)
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

class AutoNightThemePreferences: PreferencesEntry, Equatable {
    let schedule: AutoNightSchedule?
    let themeName: String
    static var defaultSettings: AutoNightThemePreferences {
        return AutoNightThemePreferences()
    }
    
    init(schedule: AutoNightSchedule? = nil, themeName: String = nightBluePalette.name) {
        self.schedule = schedule
        self.themeName = themeName
    }
    
    required init(decoder: PostboxDecoder) {
        let type = decoder.decodeInt32ForKey("t", orElse: 0)
        self.themeName = decoder.decodeStringForKey("tn", orElse: nightBluePalette.name)
        switch type {
        case 1:
            let latitude = decoder.decodeDoubleForKey("la", orElse: 0)
            let longitude = decoder.decodeDoubleForKey("lo", orElse: 0)
            self.schedule = .sunrise(latitude: latitude, longitude: longitude)
        case 2:
            let from = decoder.decodeInt32ForKey("from", orElse: 22)
            let to = decoder.decodeInt32ForKey("to", orElse: 9)
            self.schedule = .timeSensitive(from: from, to: to)
        default:
            self.schedule = nil
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(themeName, forKey: "tn")
        if let schedule = schedule {
            encoder.encodeInt32(schedule.typeValue, forKey: "t")
            switch schedule {
            case let .sunrise(location):
                encoder.encodeDouble(location.latitude, forKey: "la")
                encoder.encodeDouble(location.longitude, forKey: "lo")
            case let .timeSensitive(from, to):
                encoder.encodeInt32(from, forKey: "from")
                encoder.encodeInt32(to, forKey: "to")
            }
        } else {
            encoder.encodeInt32(0, forKey: "t")
        }
    }
    

    func withUpdatedSchedule(_ schedule: AutoNightSchedule?) -> AutoNightThemePreferences {
        return AutoNightThemePreferences(schedule: schedule, themeName: self.themeName)
    }
    
    func withUpdatedName(_ themeName: String) -> AutoNightThemePreferences {
        return AutoNightThemePreferences(schedule: self.schedule, themeName: themeName)
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AutoNightThemePreferences {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: AutoNightThemePreferences, rhs: AutoNightThemePreferences) -> Bool {
        if lhs.schedule != rhs.schedule {
            return false
        }
        if lhs.themeName != rhs.themeName {
            return false
        }
        return true
    }
    
}


func autoNightSettings(accountManager: AccountManager) -> Signal<AutoNightThemePreferences, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.autoNight]) |> map { $0.entries[ApplicationSharedPreferencesKeys.autoNight] as? AutoNightThemePreferences ?? AutoNightThemePreferences.defaultSettings }
}

func updateAutoNightSettingsInteractively(accountManager: AccountManager, _ f: @escaping (AutoNightThemePreferences) -> AutoNightThemePreferences) -> Signal<AutoNightThemePreferences, NoError> {
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
    } |> mapToSignal {
        return autoNightSettings(accountManager: accountManager)
    }
}
