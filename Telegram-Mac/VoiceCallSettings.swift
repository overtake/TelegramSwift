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
    
    let audioInputDeviceId: String?
    let cameraInputDeviceId: String?
    let audioOutputDeviceId: String?
    
    public static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: nil, cameraInputDeviceId: nil, audioOutputDeviceId: nil)
    }
    
    init(audioInputDeviceId: String?, cameraInputDeviceId: String?, audioOutputDeviceId: String?) {
        self.audioInputDeviceId = audioInputDeviceId
        self.cameraInputDeviceId = cameraInputDeviceId
        self.audioOutputDeviceId = audioOutputDeviceId
    }
    
    public init(decoder: PostboxDecoder) {
        self.audioInputDeviceId = decoder.decodeOptionalStringForKey("ai")
        self.cameraInputDeviceId = decoder.decodeOptionalStringForKey("ci")
        self.audioOutputDeviceId = decoder.decodeOptionalStringForKey("ao")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let audioInputDeviceId = audioInputDeviceId {
            encoder.encodeString(audioInputDeviceId, forKey: "ai")
        } else {
            encoder.encodeNil(forKey: "ai")
        }
        
        if let cameraInputDeviceId = cameraInputDeviceId {
            encoder.encodeString(cameraInputDeviceId, forKey: "ci")
        } else {
            encoder.encodeNil(forKey: "ci")
        }
        
        if let audioOutputDeviceId = audioOutputDeviceId {
            encoder.encodeString(audioOutputDeviceId, forKey: "ao")
        } else {
            encoder.encodeNil(forKey: "ao")
        }
        
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoiceCallSettings {
            return self == to
        } else {
            return false
        }
    }
    

    func withUpdatedAudioInputDeviceId(_ audioInputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId)
    }
    func withUpdatedCameraInputDeviceId(_ cameraInputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId)
    }
    func withUpdatedAudioOutputDeviceId(_ audioOutputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: audioOutputDeviceId)
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
