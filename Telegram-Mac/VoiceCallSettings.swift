//
//  VoiceCallSettings.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac

public enum VoiceCallDataSaving: Int32 {
    case never
    case cellular
    case always
}

public struct VoiceCallSettings: PreferencesEntry, Equatable {
    public let dataSaving: VoiceCallDataSaving
    public let p2pMode: VoiceCallP2PMode?
    public static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(dataSaving: .never, p2pMode: nil)
    }
    
    init(dataSaving: VoiceCallDataSaving, p2pMode: VoiceCallP2PMode?) {
        self.dataSaving = dataSaving
        self.p2pMode = p2pMode
    }
    
    public init(decoder: PostboxDecoder) {
        self.dataSaving = VoiceCallDataSaving(rawValue: decoder.decodeInt32ForKey("ds", orElse: 0))!
        if let mode = decoder.decodeOptionalInt32ForKey("defaultP2PMode") {
            self.p2pMode = VoiceCallP2PMode(rawValue: mode) ?? .contacts
        } else {
            self.p2pMode = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.dataSaving.rawValue, forKey: "ds")
        if let mode = self.p2pMode {
            encoder.encodeInt32(mode.rawValue, forKey: "defaultP2PMode")
        } else {
            encoder.encodeNil(forKey: "defaultP2PMode")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoiceCallSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: VoiceCallSettings, rhs: VoiceCallSettings) -> Bool {
        return lhs.dataSaving == rhs.dataSaving && lhs.p2pMode == rhs.p2pMode
    }
    
    func withUpdatedDataSaving(_ dataSaving: VoiceCallDataSaving) -> VoiceCallSettings {
        return VoiceCallSettings(dataSaving: dataSaving, p2pMode: self.p2pMode)
    }
    
    func withUpdatedP2pCallMode(_ mode: VoiceCallP2PMode?) -> VoiceCallSettings {
        return VoiceCallSettings(dataSaving: self.dataSaving, p2pMode: mode)
    }
}

func updateVoiceCallSettingsSettingsInteractively(postbox: Postbox, _ f: @escaping (VoiceCallSettings) -> VoiceCallSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.voiceCallSettings, { entry in
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


func p2pCallMode(transaction: Transaction) -> VoiceCallP2PMode {
    if let prefs = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.voiceCallSettings) as? VoiceCallSettings {
        if let mode = prefs.p2pMode {
            return mode
        } else {
            return currentVoipConfiguration(transaction: transaction).defaultP2PMode
        }
    } else {
        return currentVoipConfiguration(transaction: transaction).defaultP2PMode
    }
}
