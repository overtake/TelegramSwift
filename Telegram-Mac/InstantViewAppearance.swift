//
//  InstantViewAppearance.swift
//  Telegram
//
//  Created by keepcoder on 23/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import PostboxMac
import SwiftSignalKitMac

public struct IVReadState : PostboxCoding {
    let blockId:Int32
    let blockOffset: Int32
    public init(blockId:Int32, blockOffset: Int32) {
        self.blockId = blockId
        self.blockOffset = blockOffset
    }
    public init(decoder: PostboxDecoder) {
        self.blockId = decoder.decodeInt32ForKey("bi", orElse: 0)
        self.blockOffset = decoder.decodeInt32ForKey("bo", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(blockId, forKey: "bi")
        encoder.encodeInt32(blockOffset, forKey: "bo")
    }
    
}

public struct InstantViewAppearance: PreferencesEntry, Equatable {
    public let fontSerif: Bool
    public let state:[MediaId: IVReadState]
    public static var defaultSettings: InstantViewAppearance {
        return InstantViewAppearance(fontSerif: false, state: [:])
    }
    
    init(fontSerif: Bool, state: [MediaId: IVReadState]) {
        self.fontSerif = fontSerif
        self.state = state
    }
    
    public init(decoder: PostboxDecoder) {
        self.fontSerif = decoder.decodeBoolForKey("f", orElse: false)
        self.state = decoder.decodeObjectDictionaryForKey("ip") as [MediaId: IVReadState]
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBool(fontSerif, forKey: "f")
        encoder.encodeObjectDictionary(state, forKey: "ip")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? InstantViewAppearance {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: InstantViewAppearance, rhs: InstantViewAppearance) -> Bool {
        return lhs.fontSerif == rhs.fontSerif
    }
    
    func withUpdatedFontSerif(_ fontSerif: Bool) -> InstantViewAppearance {
        return InstantViewAppearance(fontSerif: fontSerif, state: self.state)
    }
    
    func withUpdatedIVState(_ state: IVReadState, for mediaId:MediaId) -> InstantViewAppearance {
        var iv = self.state
        iv[mediaId] = state
        return InstantViewAppearance(fontSerif: fontSerif, state: iv)
    }
}

func updateInstantViewAppearanceSettingsInteractively(postbox: Postbox, _ f: @escaping (InstantViewAppearance) -> InstantViewAppearance) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.instantViewAppearance, { entry in
            let currentSettings: InstantViewAppearance
            if let entry = entry as? InstantViewAppearance {
                currentSettings = entry
            } else {
                currentSettings = InstantViewAppearance.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

func ivAppearance(postbox: Postbox) -> Signal<InstantViewAppearance, Void> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.instantViewAppearance]) |> map { preferences in
        return (preferences.values[ApplicationSpecificPreferencesKeys.instantViewAppearance] as? InstantViewAppearance) ?? InstantViewAppearance.defaultSettings
    }
}
