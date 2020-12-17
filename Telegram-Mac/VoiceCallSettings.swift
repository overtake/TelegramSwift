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
import TGUIKit

enum VoiceCallDataSaving: Int32 {
    case never
    case cellular
    case always
}

struct PushToTalkValue : Equatable, PostboxCoding {
    
    struct ModifierFlag : Equatable, PostboxCoding {
        let keyCode: UInt16
        let flag: UInt
        init(keyCode: UInt16, flag: UInt) {
            self.keyCode = keyCode
            self.flag = flag
        }
        func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(Int32(self.keyCode), forKey: "kc")
            encoder.encodeInt64(Int64(bitPattern: UInt64(flag)), forKey: "f")
        }
        init(decoder: PostboxDecoder) {
            self.keyCode = UInt16(decoder.decodeInt32ForKey("kc", orElse: 0))
            self.flag = UInt(bitPattern: Int(decoder.decodeInt64ForKey("f", orElse: 0)))
        }
        
    }
    
    var isSpace: Bool {
        return keyCodes == [KeyboardKey.Space.rawValue] && modifierFlags.isEmpty
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
    case none = 0
    case always = 1
    case pushToTalk = 2
}

struct VoiceCallSettings: PreferencesEntry, Equatable {
    
    let audioInputDeviceId: String?
    let cameraInputDeviceId: String?
    let audioOutputDeviceId: String?
    let mode: VoiceChatInputMode
    let pushToTalk: PushToTalkValue?
    let pushToTalkSoundEffects: Bool
    static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: nil, cameraInputDeviceId: nil, audioOutputDeviceId: nil, mode: .always, pushToTalk: nil, pushToTalkSoundEffects: false)
    }
    
    init(audioInputDeviceId: String?, cameraInputDeviceId: String?, audioOutputDeviceId: String?, mode: VoiceChatInputMode, pushToTalk: PushToTalkValue?, pushToTalkSoundEffects: Bool) {
        self.audioInputDeviceId = audioInputDeviceId
        self.cameraInputDeviceId = cameraInputDeviceId
        self.audioOutputDeviceId = audioOutputDeviceId
        self.pushToTalk = pushToTalk
        self.mode = mode
        self.pushToTalkSoundEffects = pushToTalkSoundEffects
    }
    
    init(decoder: PostboxDecoder) {
        self.audioInputDeviceId = decoder.decodeOptionalStringForKey("ai")
        self.cameraInputDeviceId = decoder.decodeOptionalStringForKey("ci")
        self.audioOutputDeviceId = decoder.decodeOptionalStringForKey("ao")
        self.pushToTalk = decoder.decodeObjectForKey("ptt3") as? PushToTalkValue
        self.mode = VoiceChatInputMode(rawValue: decoder.decodeInt32ForKey("m1", orElse: 0)) ?? .none
        self.pushToTalkSoundEffects = decoder.decodeBoolForKey("se", orElse: false)
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
            encoder.encodeObject(pushToTalk, forKey: "ptt3")
        } else {
            encoder.encodeNil(forKey: "ptt3")
        }
        encoder.encodeInt32(self.mode.rawValue, forKey: "m1")
        
        encoder.encodeBool(pushToTalkSoundEffects, forKey: "se")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoiceCallSettings {
            return self == to
        } else {
            return false
        }
    }
    

    func withUpdatedAudioInputDeviceId(_ audioInputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects)
    }
    func withUpdatedCameraInputDeviceId(_ cameraInputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects)
    }
    func withUpdatedAudioOutputDeviceId(_ audioOutputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects)
    }
    func withUpdatedPushToTalk(_ pushToTalk: PushToTalkValue?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects)
    }
    func withUpdatedMode(_ mode: VoiceChatInputMode) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects)
    }
    func withUpdatedSoundEffects(_ pushToTalkSoundEffects: Bool) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: pushToTalkSoundEffects)
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
