//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 25.01.2024.
//

import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore



public class DockSettings: Codable, Equatable {
    public static func == (lhs: DockSettings, rhs: DockSettings) -> Bool {
        return lhs.iconSelected == rhs.iconSelected
    }
    
    public let iconSelected: String?
    
    public static var defaultSettings: DockSettings {
        return DockSettings(iconSelected: nil)
    }
    
    init(iconSelected: String?) {
        self.iconSelected = iconSelected
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.iconSelected = try container.decodeIfPresent(String.self, forKey: "is")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.iconSelected, forKey: "is")

    }
    
    public func withUpdatedIcon(_ iconSelected: String?) -> DockSettings {
        return DockSettings(iconSelected: iconSelected)
    }

}

public func dockSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<DockSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.dockSettings]) |> map { prefs in
        return prefs.entries[ApplicationSharedPreferencesKeys.dockSettings]?.get(DockSettings.self) ?? DockSettings.defaultSettings
    }
}

public func updateDockSettings(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (DockSettings) -> DockSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.dockSettings, { entry in
            let currentSettings: DockSettings
            if let entry = entry?.get(DockSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = DockSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
