//
//  InstantViewAppearance.swift
//  Telegram
//
//  Created by keepcoder on 23/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import Postbox
import SwiftSignalKit

public enum InstantPageThemeType: Int32 {
    case light = 0
    case dark = 1
    case sepia = 2
    case gray = 3
}

public enum InstantPagePresentationFontSize: Int32 {
    case small = 0
    case standard = 1
    case large = 2
    case xlarge = 3
    case xxlarge = 4
}




public struct IVReadState : Codable, Equatable {
    let blockId:Int32
    let blockOffset: Int32
    public init(blockId:Int32, blockOffset: Int32) {
        self.blockId = blockId
        self.blockOffset = blockOffset
    }
}

public struct InstantViewAppearance: Codable, Equatable {
    public let fontSerif: Bool
    public let state:[MediaId: IVReadState]
    public static var defaultSettings: InstantViewAppearance {
        return InstantViewAppearance(fontSerif: false, state: [:])
    }
    
    init(fontSerif: Bool, state: [MediaId: IVReadState]) {
        self.fontSerif = fontSerif
        self.state = state
    }
    
    
    public static func ==(lhs: InstantViewAppearance, rhs: InstantViewAppearance) -> Bool {
        return lhs.fontSerif == rhs.fontSerif && lhs.state == rhs.state
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
            if let entry = entry?.get(InstantViewAppearance.self) {
                currentSettings = entry
            } else {
                currentSettings = InstantViewAppearance.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

func ivAppearance(postbox: Postbox) -> Signal<InstantViewAppearance, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.instantViewAppearance]) |> map { preferences in
        return preferences.values[ApplicationSpecificPreferencesKeys.instantViewAppearance]?.get(InstantViewAppearance.self) ?? InstantViewAppearance.defaultSettings
    }
}
