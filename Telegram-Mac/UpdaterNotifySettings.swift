//
//  LaunchSettings.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import SyncCore
enum LaunchNavigation : PostboxCoding, Equatable {
    case chat(PeerId, necessary: Bool)
    case thread(MessageId, MessageId, necessary: Bool)
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
        case let .thread(threadId, fromId, necessary):
            encoder.encodeInt32(2, forKey: "t")
            
            encoder.encodeInt32(threadId.peerId.namespace, forKey: "t.p.n")
            encoder.encodeInt32(threadId.peerId.id, forKey: "t.p.id")
            encoder.encodeInt32(threadId.id, forKey: "t.m.id")
            encoder.encodeInt32(threadId.namespace, forKey: "t.m.n")
            
            encoder.encodeInt32(fromId.peerId.namespace, forKey: "f.p.n")
            encoder.encodeInt32(fromId.peerId.id, forKey: "f.p.id")
            encoder.encodeInt32(fromId.id, forKey: "f.m.id")
            encoder.encodeInt32(fromId.namespace, forKey: "f.m.n")
            
            encoder.encodeBool(necessary, forKey: "n")
        }
    }
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("t", orElse: 0) {
        case 0:
            let peerId = PeerId(namespace: decoder.decodeInt32ForKey("p.n", orElse: 0), id: decoder.decodeInt32ForKey("p.id", orElse: 0))
            self = .chat(peerId, necessary: decoder.decodeBoolForKey("n", orElse: false))
        case 1:
            self = .settings
        case 2:
            let threadPeerId = PeerId(namespace: decoder.decodeInt32ForKey("t.p.n", orElse: 0), id: decoder.decodeInt32ForKey("t.p.id", orElse: 0))
            let threadId = MessageId(peerId: threadPeerId, namespace: decoder.decodeInt32ForKey("t.m.id", orElse: 0), id: decoder.decodeInt32ForKey("t.m.n", orElse: 0))
            
            
            let fromPeerId = PeerId(namespace: decoder.decodeInt32ForKey("f.p.n", orElse: 0), id: decoder.decodeInt32ForKey("f.p.id", orElse: 0))
            let fromId = MessageId(peerId: fromPeerId, namespace: decoder.decodeInt32ForKey("f.m.id", orElse: 0), id: decoder.decodeInt32ForKey("f.m.n", orElse: 0))

            
            self = .thread(threadId, fromId, necessary: decoder.decodeBoolForKey("n", orElse: false))
        default:
            fatalError()
        }
    }
}

struct LaunchSettings: PreferencesEntry, Equatable {

    let navigation: LaunchNavigation?
    let applyText: String?
    let previousText: String?
    let openAtLaunch: Bool
    init(applyText: String?, previousText: String?, navigation: LaunchNavigation?, openAtLaunch: Bool) {
        self.applyText = applyText
        self.navigation = navigation
        self.previousText = previousText
        self.openAtLaunch = openAtLaunch
    }
    
    init(decoder: PostboxDecoder) {
        self.applyText = decoder.decodeOptionalStringForKey("at")
        self.navigation = decoder.decodeObjectForKey("n1", decoder: { LaunchNavigation(decoder: $0) }) as? LaunchNavigation
        self.previousText = decoder.decodeOptionalStringForKey("pt")
        self.openAtLaunch = decoder.decodeBoolForKey("oat", orElse: true)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let applyText = applyText {
            encoder.encodeString(applyText, forKey: "at")
        } else {
            encoder.encodeNil(forKey: "at")
        }
        if let navigation = navigation {
            encoder.encodeObject(navigation, forKey: "n1")
        } else {
            encoder.encodeNil(forKey: "n1")
        }
        if let previousText = previousText {
            encoder.encodeString(previousText, forKey: "pt")
        } else {
            encoder.encodeNil(forKey: "pt")
        }
        encoder.encodeBool(self.openAtLaunch, forKey: "oat")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? LaunchSettings {
            return self == to
        } else {
            return false
        }
    }
    
    
    func withUpdatedApplyText(_ applyText: String?) -> LaunchSettings {
        return LaunchSettings(applyText: applyText, previousText: self.previousText, navigation: self.navigation, openAtLaunch: self.openAtLaunch)
    }
    func withUpdatedNavigation(_ navigation: LaunchNavigation?) -> LaunchSettings {
        return LaunchSettings(applyText: self.applyText, previousText: self.previousText, navigation: navigation, openAtLaunch: self.openAtLaunch)
    }
    func withUpdatedPreviousText(_ previousText: String?) -> LaunchSettings {
        return LaunchSettings(applyText: self.applyText, previousText: previousText, navigation: self.navigation, openAtLaunch: self.openAtLaunch)
    }
    func withUpdatedOpenAtLaunch(_ openAtLaunch: Bool) -> LaunchSettings {
        return LaunchSettings(applyText: self.applyText, previousText: self.previousText, navigation: self.navigation, openAtLaunch: openAtLaunch)
    }
    
    static var defaultSettings: LaunchSettings {
        return LaunchSettings(applyText: nil, previousText: nil, navigation: nil, openAtLaunch: true)
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


func appLaunchSettings(postbox: Postbox) -> Signal<LaunchSettings, NoError> {
    return postbox.transaction { transaction -> LaunchSettings in
        return transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings) as? LaunchSettings ?? LaunchSettings.defaultSettings
    }
}


func applyUpdateTextIfNeeded(_ postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        var applyText: String?
        var previousText: String?
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { pref in
            applyText = (pref as? LaunchSettings)?.applyText
            previousText = (pref as? LaunchSettings)?.previousText
            return (pref as? LaunchSettings)?.withUpdatedApplyText(nil)
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
            
            
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)
            let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: Int32(Date().timeIntervalSince1970), flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: applyText, attributes: attributes, media: [])
            _ = transaction.addMessages([message], location: .UpperHistoryBlock)
            
            transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings, { pref in
                return (pref as? LaunchSettings)?.withUpdatedPreviousText(applyText)
            })
            
        }
    } |> ignoreValues
}
