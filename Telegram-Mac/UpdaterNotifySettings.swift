//
//  LaunchSettings.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import Postbox
import SwiftSignalKit
import InAppSettings

enum LaunchNavigation : Equatable {
    case chat(PeerId, necessary: Bool)
    case thread(MessageId, MessageId, necessary: Bool)
    case profile(PeerId, necessary: Bool)
    case settings
}

struct LaunchSettings: Codable, Equatable {

    let navigation: LaunchNavigation?
    let applyText: String?
    let previousText: String?
    init(applyText: String?, previousText: String?, navigation: LaunchNavigation?) {
        self.applyText = applyText
        self.navigation = navigation
        self.previousText = previousText
    }
    
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.navigation = nil
        self.applyText = try container.decodeIfPresent(String.self, forKey: "at")
        self.previousText = try container.decodeIfPresent(String.self, forKey: "pt")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(applyText, forKey: "at")
        try container.encodeIfPresent(previousText, forKey: "pt")
    }
    
    
    func withUpdatedApplyText(_ applyText: String?) -> LaunchSettings {
        return LaunchSettings(applyText: applyText, previousText: self.previousText, navigation: self.navigation)
    }
    func withUpdatedNavigation(_ navigation: LaunchNavigation?) -> LaunchSettings {
        return LaunchSettings(applyText: self.applyText, previousText: self.previousText, navigation: navigation)
    }
    func withUpdatedPreviousText(_ previousText: String?) -> LaunchSettings {
        return LaunchSettings(applyText: self.applyText, previousText: previousText, navigation: self.navigation)
    }
    
    static var defaultSettings: LaunchSettings {
        return LaunchSettings(applyText: nil, previousText: nil, navigation: nil)
    }
}


func addAppUpdateText(_ postbox: Postbox, applyText: String?) -> Signal<Never, NoError>{
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { entry in
            let settings = entry?.get(LaunchSettings.self) ?? LaunchSettings.defaultSettings
            return PreferencesEntry(settings.withUpdatedApplyText(applyText))
        })
    } |> ignoreValues
}


func updateLaunchSettings(_ postbox: Postbox, _ f: @escaping(LaunchSettings)->LaunchSettings) -> Signal<Never, NoError>{
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { entry in
            let settings = entry?.get(LaunchSettings.self) ?? LaunchSettings.defaultSettings
            return PreferencesEntry(f(settings))
        })
    } |> ignoreValues |> deliverOnMainQueue
}


func appLaunchSettings(postbox: Postbox) -> Signal<LaunchSettings, NoError> {
    return postbox.transaction { transaction -> LaunchSettings in
        return transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings)?.get(LaunchSettings.self) ?? LaunchSettings.defaultSettings
    }
}


func applyUpdateTextIfNeeded(_ postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        var applyText: String?
        var previousText: String?
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { pref in
            applyText = pref?.get(LaunchSettings.self)?.applyText
            previousText = pref?.get(LaunchSettings.self)?.previousText
            return PreferencesEntry(pref?.get(LaunchSettings.self)?.withUpdatedApplyText(nil))
        })
        if let applyText = applyText {
            var attributes: [MessageAttribute] = []
            
            let index = applyText.firstIndex(of: "\n")
            if let index = index {
                let boldLine = MessageTextEntity(range: 0 ..< index.encodedOffset, type: .Bold)
                attributes.append(TextEntitiesMessageAttribute(entities: [boldLine]))
                
                 if let previousText = previousText, let prevIndex = previousText.firstIndex(of: "\n") {
                    let apply = String(applyText[index...])
                    let previous = String(previousText[prevIndex...])
                    if apply == previous {
                        return
                    }
                }
            }
            
            
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
            let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: Int32(Date().timeIntervalSince1970), flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: applyText, attributes: attributes, media: [])
            _ = transaction.addMessages([message], location: .UpperHistoryBlock)
            
            transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { pref in
                return PreferencesEntry(pref?.get(LaunchSettings.self)?.withUpdatedPreviousText(applyText))
            })
            
        }
    } |> ignoreValues
}
