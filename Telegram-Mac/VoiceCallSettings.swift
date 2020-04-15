//
//  VoiceCallSettings.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore

public enum VoiceCallDataSaving: Int32 {
    case never
    case cellular
    case always
}

public struct VoiceCallSettings: PreferencesEntry, Equatable {
    
    let inputDeviceId: String?
    let outputDeviceId: String?
    let muteSounds: Bool
    
    
    public static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(inputDeviceId: nil, outputDeviceId: nil, muteSounds: true)
    }
    
    init(inputDeviceId: String?, outputDeviceId: String?, muteSounds: Bool) {
        self.inputDeviceId = inputDeviceId
        self.outputDeviceId = outputDeviceId
        self.muteSounds = muteSounds
    }
    
    public init(decoder: PostboxDecoder) {
        self.inputDeviceId = decoder.decodeOptionalStringForKey("i")
        self.outputDeviceId = decoder.decodeOptionalStringForKey("o")
        self.muteSounds = decoder.decodeInt32ForKey("m", orElse: 1) == 1
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let inputDeviceId = inputDeviceId {
            encoder.encodeString(inputDeviceId, forKey: "i")
        } else {
            encoder.encodeNil(forKey: "i")
        }
        
        if let outputDeviceId = outputDeviceId {
            encoder.encodeString(outputDeviceId, forKey: "o")
        } else {
            encoder.encodeNil(forKey: "o")
        }
        
        encoder.encodeInt32(muteSounds ? 1 : 0, forKey: "m")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoiceCallSettings {
            return self == to
        } else {
            return false
        }
    }
    

    func withUpdatedInputDeviceId(_ inputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(inputDeviceId: inputDeviceId, outputDeviceId: self.outputDeviceId, muteSounds: self.muteSounds)
    }
    
    func withUpdatedOutputDeviceId(_ outputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(inputDeviceId: self.inputDeviceId, outputDeviceId: outputDeviceId, muteSounds: self.muteSounds)
    }
    
    func withUpdatedMuteSounds(_ muteSounds: Bool) -> VoiceCallSettings {
        return VoiceCallSettings(inputDeviceId: self.inputDeviceId, outputDeviceId: self.outputDeviceId, muteSounds: muteSounds)
    }
}

func updateVoiceCallSettingsSettingsInteractively(accountManager: AccountManager, _ f: @escaping (VoiceCallSettings) -> VoiceCallSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.voiceCallSettings, { entry in
            let currentSettings: VoiceCallSettings
            if let entry = entry as? VoiceCallSettings {
                currentSettings = entry
            } else {
                currentSettings = VoiceCallSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}


func voiceCallSettings(_ accountManager: AccountManager) -> Signal<VoiceCallSettings, NoError>  {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.voiceCallSettings]) |> map { view in
        return view.entries[ApplicationSharedPreferencesKeys.voiceCallSettings] as? VoiceCallSettings ?? VoiceCallSettings.defaultSettings
    }
}
