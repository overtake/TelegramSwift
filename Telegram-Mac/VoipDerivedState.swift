//
//  VoipDerivedState.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/06/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

struct VoipDerivedState: Equatable, Codable {
    var data: Data
    
    static var `default`: VoipDerivedState {
        return VoipDerivedState(data: Data())
    }
    
    init(data: Data) {
        self.data = data
    }
    
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.data = try container.decode(Data.self, forKey: "data")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.data, forKey: "data")
    }
    
}

func updateVoipDerivedStateInteractively(postbox: Postbox, _ f: @escaping (VoipDerivedState) -> VoipDerivedState) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.voipDerivedState, { entry in
            let currentSettings: VoipDerivedState
            if let entry = entry?.get(VoipDerivedState.self) {
                currentSettings = entry
            } else {
                currentSettings = .default
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
