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
import KeyboardKey

public enum VoiceCallDataSaving: Int32 {
    case never
    case cellular
    case always
}

public struct PushToTalkValue : Equatable, Codable {
    
    public struct ModifierFlag : Equatable, Codable {
        public let keyCode: UInt16
        public let flag: UInt
        public init(keyCode: UInt16, flag: UInt) {
            self.keyCode = keyCode
            self.flag = flag
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            try container.encode(Int32(self.keyCode), forKey: "kc")
            try container.encode(Int64(bitPattern: UInt64(flag)), forKey: "f")
        }
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)
            self.keyCode = UInt16(try container.decode(Int32.self, forKey: "kc"))
            self.flag = UInt(bitPattern: Int(try container.decode(Int64.self, forKey: "f")))
        }
        
    }
    
    public var isSpace: Bool {
        return keyCodes == [KeyboardKey.Space.rawValue] && modifierFlags.isEmpty && otherMouse.isEmpty
    }
    
    public var keyCodes: [UInt16]
    public var modifierFlags: [ModifierFlag]
    public var string: String
    public var otherMouse: [Int]
    public init(keyCodes: [UInt16], otherMouse: [Int], modifierFlags: [ModifierFlag], string: String) {
        self.keyCodes = keyCodes
        self.modifierFlags = modifierFlags
        self.string = string
        self.otherMouse = otherMouse
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.modifierFlags, forKey: "mf")
        try container.encode(self.keyCodes.map { Int32($0) }, forKey: "kc")
        try container.encode(string, forKey: "s")
        try container.encode(self.otherMouse.map { Int64($0) }, forKey: "om")

    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.keyCodes = try container.decode([Int32].self, forKey: "kc").map { UInt16($0) }
        self.modifierFlags = try container.decode([ModifierFlag].self, forKey: "mf")
        self.string = try container.decode(String.self, forKey: "s")
        self.otherMouse = try container.decode([Int64].self, forKey: "om").map { Int($0) }
    }
}

public enum VoiceChatInputMode : Int32 {
    case none = 0
    case always = 1
    case pushToTalk = 2
}

public struct VoiceCallSettings: Codable, Equatable {
    
    
    public enum Tooltip : Int32 {
        case camera = 0
    }
    
    public let audioInputDeviceId: String?
    public let cameraInputDeviceId: String?
    public let audioOutputDeviceId: String?
    public let mode: VoiceChatInputMode
    public let pushToTalk: PushToTalkValue?
    public let pushToTalkSoundEffects: Bool
    public let noiseSuppression: Bool
    public let tooltips:[Tooltip]
    public static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: nil, cameraInputDeviceId: nil, audioOutputDeviceId: nil, mode: .none, pushToTalk: nil, pushToTalkSoundEffects: false, noiseSuppression: true, tooltips: [.camera])
    }
    
    public init(audioInputDeviceId: String?, cameraInputDeviceId: String?, audioOutputDeviceId: String?, mode: VoiceChatInputMode, pushToTalk: PushToTalkValue?, pushToTalkSoundEffects: Bool, noiseSuppression: Bool, tooltips: [Tooltip]) {
        self.audioInputDeviceId = audioInputDeviceId
        self.cameraInputDeviceId = cameraInputDeviceId
        self.audioOutputDeviceId = audioOutputDeviceId
        self.pushToTalk = pushToTalk
        self.mode = mode
        self.pushToTalkSoundEffects = pushToTalkSoundEffects
        self.noiseSuppression = noiseSuppression
        self.tooltips = tooltips
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.audioInputDeviceId = try container.decodeIfPresent(String.self, forKey: "ai")
        self.cameraInputDeviceId = try container.decodeIfPresent(String.self, forKey: "ci")
        self.audioOutputDeviceId = try container.decodeIfPresent(String.self, forKey: "ao")
        self.pushToTalk = try container.decodeIfPresent(PushToTalkValue.self, forKey: "ptt4")
        self.mode = VoiceChatInputMode(rawValue: try container.decodeIfPresent(Int32.self, forKey: "m2") ?? 0) ?? .none
        self.pushToTalkSoundEffects = try container.decodeIfPresent(Bool.self, forKey: "se") ?? false
        self.noiseSuppression = try container.decodeIfPresent(Bool.self, forKey: "ns") ?? false
        self.tooltips = try container.decode([Int32].self, forKey: "tt").compactMap { Tooltip(rawValue: $0) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        if let audioInputDeviceId = audioInputDeviceId {
            try container.encode(audioInputDeviceId, forKey: "ai")
        } else {
            try container.encodeNil(forKey: "ai")
        }
        
        if let cameraInputDeviceId = cameraInputDeviceId {
            try container.encode(cameraInputDeviceId, forKey: "ci")
        } else {
            try container.encodeNil(forKey: "ci")
        }
        
        if let audioOutputDeviceId = audioOutputDeviceId {
            try container.encode(audioOutputDeviceId, forKey: "ao")
        } else {
            try container.encodeNil(forKey: "ao")
        }
        
        if let pushToTalk = pushToTalk {
            try container.encode(pushToTalk, forKey: "ptt4")
        } else {
            try container.encodeNil(forKey: "ptt4")
        }
        try container.encode(self.mode.rawValue, forKey: "m2")
        
        try container.encode(pushToTalkSoundEffects, forKey: "se")
        
        try container.encode(noiseSuppression, forKey: "ns")
        try container.encode(self.tooltips.map { $0.rawValue }, forKey: "tt")

    }
    
    public func withUpdatedAudioInputDeviceId(_ audioInputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects, noiseSuppression: self.noiseSuppression, tooltips: self.tooltips)
    }
    public func withUpdatedCameraInputDeviceId(_ cameraInputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects, noiseSuppression: self.noiseSuppression, tooltips: self.tooltips)
    }
    public func withUpdatedAudioOutputDeviceId(_ audioOutputDeviceId: String?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects, noiseSuppression: self.noiseSuppression, tooltips: self.tooltips)
    }
    public func withUpdatedPushToTalk(_ pushToTalk: PushToTalkValue?) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects, noiseSuppression: self.noiseSuppression, tooltips: self.tooltips)
    }
    public func withUpdatedMode(_ mode: VoiceChatInputMode) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects, noiseSuppression: self.noiseSuppression, tooltips: self.tooltips)
    }
    public func withUpdatedSoundEffects(_ pushToTalkSoundEffects: Bool) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: pushToTalkSoundEffects, noiseSuppression: self.noiseSuppression, tooltips: self.tooltips)
    }
    
    public func withUpdatedNoiseSuppression(_ noiseSuppression: Bool) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects, noiseSuppression: noiseSuppression, tooltips: self.tooltips)
    }
    public func withRemovedTooltip(_ tooltip: Tooltip) -> VoiceCallSettings {
        
        var tooltips = self.tooltips
        tooltips.removeAll(where: { $0 == tooltip })
        
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects, noiseSuppression: self.noiseSuppression, tooltips: tooltips)
    }
    
    public func withUpdatedVisualEffects(_ visualEffects: Bool) -> VoiceCallSettings {
        return VoiceCallSettings(audioInputDeviceId: self.audioInputDeviceId, cameraInputDeviceId: self.cameraInputDeviceId, audioOutputDeviceId: self.audioOutputDeviceId, mode: self.mode, pushToTalk: self.pushToTalk, pushToTalkSoundEffects: self.pushToTalkSoundEffects, noiseSuppression: self.noiseSuppression, tooltips: tooltips)
    }

}

public func updateVoiceCallSettingsSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (VoiceCallSettings) -> VoiceCallSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.voiceCallSettings, { entry in
            let currentSettings: VoiceCallSettings
            if let entry = entry?.get(VoiceCallSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = VoiceCallSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}


public func voiceCallSettings(_ accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<VoiceCallSettings, NoError>  {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.voiceCallSettings]) |> map { view in
        return view.entries[ApplicationSharedPreferencesKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? VoiceCallSettings.defaultSettings
    }
}
