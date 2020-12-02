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

enum VoiceCallDataSaving: Int32 {
    case never
    case cellular
    case always
}

struct PTTSettings : Equatable, PostboxCoding {
    var keyCode: UInt16
    var modifierFlags: UInt
    
    init(keyCode: UInt16, modifierFlags: UInt) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(Int64(Int(bitPattern: self.modifierFlags)), forKey: "mf")
        encoder.encodeInt32(Int32(self.keyCode), forKey: "kc")
    }
    init(decoder: PostboxDecoder) {
        self.keyCode = UInt16(decoder.decodeInt32ForKey("kc", orElse: 0))
        self.modifierFlags = UInt(bitPattern: Int(decoder.decodeInt64ForKey("mf", orElse: 0)))
    }
}

enum VoiceChatInputMode : Int32 {
    case always = 0
    case pushToTalk = 1
}

struct VoiceCallSettings: PreferencesEntry, Equatable {
    
    let audioInputDeviceId: String?
    let cameraInputDeviceId: String?
    let audioOutputDeviceId: String?
    let mode: VoiceChatInputMode
    let pushToTalk: PTTSettings?
    
    static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: nil, cameraInputDeviceId: nil, audioOutputDeviceId: nil, mode: .always, pushToTalk: nil)
    }
    
    init(audioInputDeviceId: String?, cameraInputDeviceId: String?, audioOutputDeviceId: String?, mode: VoiceChatInputMode, pushToTalk: PTTSettings?) {
        self.audioInputDeviceId = audioInputDeviceId
        self.cameraInputDeviceId = cameraInputDeviceId
        self.audioOutputDeviceId = audioOutputDeviceId
        self.pushToTalk = pushToTalk
        self.mode = mode
    }
    
    init(decoder: PostboxDecoder) {
        self.audioInputDeviceId = decoder.decodeOptionalStringForKey("ai")
        self.cameraInputDeviceId = decoder.decodeOptionalStringForKey("ci")
        self.audioOutputDeviceId = decoder.decodeOptionalStringForKey("ao")
        self.pushToTalk = decoder.decodeObjectForKey("ptt") as? PTTSettings
        self.mode = VoiceChatInputMode(rawValue: decoder.decodeInt32ForKey("m", orElse: 0)) ?? .always
    }
    
    func encode(_ encoder: PostboxEncoder) {
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
        
        if let pushToTalk = pushToTalk {
            encoder.encodeObject(pushToTalk, forKey: "ptt")
        } else {
            encoder.encodeNil(forKey: "ptt")
        }
        encoder.encodeInt32(self.mode.rawValue, forKey: "m")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoiceCallSettings {
            return self == to
        } else {
            return false
        }
    }
    

    func withUpdatedAudioInputDeviceId(_ audioInputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk)
    }
    func withUpdatedCameraInputDeviceId(_ cameraInputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk)
    }
    func withUpdatedAudioOutputDeviceId(_ audioOutputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk)
    }
    func withUpdatedPushToTalk(_ pushToTalk: PTTSettings?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: pushToTalk)
    }
    func withUpdatedMode(_ mode: VoiceChatInputMode) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: mode, pushToTalk: self.pushToTalk)
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
