//
//  LaunchSettings.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

enum LaunchNavigation : PostboxCoding, Equatable {
    case chat(PeerId, necessary: Bool)
    case settings
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
        case let .chat(peerId, necessary):
            encoder.encodeInt32(0, forKey: "t")
            encoder.encodeInt32(peerId.namespace, forKey: "p.n")
            encoder.encodeInt32(peerId.id, forKey: "p.id")
            encoder.encodeBool(necessary, forKey: "n")
        case .settings:
            encoder.encodeInt32(1, forKey: "t")
        }
    }
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("t", orElse: 0) {
        case 0:
            let peerId = PeerId(namespace: decoder.decodeInt32ForKey("p.n", orElse: 0), id: decoder.decodeInt32ForKey("p.id", orElse: 0))
            self = .chat(peerId, necessary: decoder.decodeBoolForKey("n", orElse: false))
        case 1:
            self = .settings
        default:
            fatalError()
        }
    }
}

struct LaunchSettings: PreferencesEntry, Equatable {

    let navigation: LaunchNavigation?
    let applyText: String?
    
    init(applyText: String?, navigation: LaunchNavigation?) {
        self.applyText = applyText
        self.navigation = navigation
    }
    
    init(decoder: PostboxDecoder) {
        self.applyText = decoder.decodeOptionalStringForKey("at")
        self.navigation = decoder.decodeObjectForKey("n", decoder: { LaunchNavigation(decoder: $0) }) as? LaunchNavigation
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let applyText = applyText {
            encoder.encodeString(applyText, forKey: "at")
        } else {
            encoder.encodeNil(forKey: "at")
        }
        if let navigation = navigation {
            encoder.encodeObject(navigation, forKey: "n")
        } else {
            encoder.encodeNil(forKey: "n")
        }
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? LaunchSettings {
            return self == to
        } else {
            return false
        }
    }
    
    
    func withUpdatedApplyText(_ applyText: String?) -> LaunchSettings {
        return LaunchSettings(applyText: applyText, navigation: self.navigation)
    }
    func withUpdatedNavigation(_ navigation: LaunchNavigation?) -> LaunchSettings {
        return LaunchSettings(applyText: self.applyText, navigation: navigation)
    }

    
    static var defaultSettings: LaunchSettings {
        return LaunchSettings(applyText: nil, navigation: nil)
    }
}


/*
 return postbox.transaction { transaction -> Void in
 transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings, { entry in
 let currentSettings: InAppNotificationSettings
 if let entry = entry as? InAppNotificationSettings {
 currentSettings = entry
 } else {
 currentSettings = InAppNotificationSettings.defaultSettings
 }
 return f(currentSettings)
 })
 }
 */

func addAppUpdateText(_ postbox: Postbox, applyText: String?) -> Signal<Never, NoError>{
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { pref in
            let settings = pref as? LaunchSettings ?? LaunchSettings.defaultSettings
            return settings.withUpdatedApplyText(applyText)
        })
    } |> ignoreValues
}


func updateLaunchSettings(_ postbox: Postbox, _ f: @escaping(LaunchSettings)->LaunchSettings) -> Signal<Never, NoError>{
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { pref in
            let settings = pref as? LaunchSettings ?? LaunchSettings.defaultSettings
            return f(settings)
        })
    } |> ignoreValues |> deliverOnMainQueue
}


func getUpdateNotifySettings(postbox: Postbox) -> Signal<LaunchSettings, NoError> {
    return postbox.transaction { transaction -> LaunchSettings in
        return transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings) as? LaunchSettings ?? LaunchSettings.defaultSettings
    }
}


func applyUpdateTextIfNeeded(_ postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        var applyText: String?
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { pref in
            applyText = (pref as? LaunchSettings)?.applyText
            return (pref as? LaunchSettings)?.withUpdatedApplyText(nil)
        })
        if let applyText = applyText {
            var attributes: [MessageAttribute] = []
            
            let index = applyText.firstIndex(of: "\n")
            if let index = index {
                let boldLine = MessageTextEntity(range: 0 ..< index.encodedOffset, type: .Bold)
                attributes.append(TextEntitiesMessageAttribute(entities: [boldLine]))
            }
            
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)
            let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: nil, groupingKey: nil, timestamp: Int32(Date().timeIntervalSince1970), flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: applyText, attributes: attributes, media: [])
            _ = transaction.addMessages([message], location: .UpperHistoryBlock)
        }
    } |> ignoreValues
}
