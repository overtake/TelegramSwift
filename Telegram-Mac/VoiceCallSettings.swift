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

struct PushToTalkValue : Equatable, PostboxCoding {
    
    struct ModifierFlag : Equatable, PostboxCoding {
        let keyCode: UInt16
        
        init(keyCode: UInt16) {
            self.keyCode = keyCode
        }
        func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(Int32(self.keyCode), forKey: "kc")
        }
        init(decoder: PostboxDecoder) {
            self.keyCode = UInt16(decoder.decodeInt32ForKey("kc", orElse: 0) )
        }
        
    }
    
    var keyCodes: [UInt16]
    var modifierFlags: [ModifierFlag]
    var string: String
    init(keyCodes: [UInt16], modifierFlags: [ModifierFlag], string: String) {
        self.keyCodes = keyCodes
        self.modifierFlags = modifierFlags
        self.string = string
    }
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.modifierFlags, forKey: "mf")
        encoder.encodeInt32Array(self.keyCodes.map { Int32($0) }, forKey: "kc")
        encoder.encodeString(string, forKey: "s")
    }
    init(decoder: PostboxDecoder) {
        self.keyCodes = decoder.decodeInt32ArrayForKey("kc").map { UInt16($0) }
        self.modifierFlags = decoder.decodeObjectArrayForKey("mf").compactMap { $0 as? ModifierFlag }
        self.string = decoder.decodeStringForKey("s", orElse: "")
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
    let pushToTalk: PushToTalkValue?
    
    static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: nil, cameraInputDeviceId: nil, audioOutputDeviceId: nil, mode: .always, pushToTalk: nil)
    }
    
    init(audioInputDeviceId: String?, cameraInputDeviceId: String?, audioOutputDeviceId: String?, mode: VoiceChatInputMode, pushToTalk: PushToTalkValue?) {
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
        self.pushToTalk = decoder.decodeObjectForKey("ptt2") as? PushToTalkValue
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
            encoder.encodeObject(pushToTalk, forKey: "ptt2")
        } else {
            encoder.encodeNil(forKey: "ptt2")
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
    func withUpdatedPushToTalk(_ pushToTalk: PushToTalkValue?) -> VoiceCallSettings {
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
