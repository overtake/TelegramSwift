//
//  NotificationPreferencesController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore

private let modernSoundsNamePaths: [String] = [
    strings().notificationsSoundNote,
    strings().notificationsSoundAurora,
    strings().notificationsSoundBamboo,
    strings().notificationsSoundChord,
    strings().notificationsSoundCircles,
    strings().notificationsSoundComplete,
    strings().notificationsSoundHello,
    strings().notificationsSoundInput,
    strings().notificationsSoundKeys,
    strings().notificationsSoundPopcorn,
    strings().notificationsSoundPulse,
    strings().notificationsSoundSynth
]

private let classicSoundNamePaths: [String] = [
    strings().notificationsSoundTritone,
    strings().notificationsSoundTremolo,
    strings().notificationsSoundAlert,
    strings().notificationsSoundBell,
    strings().notificationsSoundCalypso,
    strings().notificationsSoundChime,
    strings().notificationsSoundGlass,
    strings().notificationsSoundTelegraph
]

private func soundName(sound: PeerMessageSound) -> String {
    switch sound {
        case .none:
            return strings().notificationsSoundNone
        case .default:
            return ""
        case let .bundledModern(id):
            if id >= 0 && Int(id) < modernSoundsNamePaths.count {
                return modernSoundsNamePaths[Int(id)]
            }
            return "Sound \(id)"
        case let .bundledClassic(id):
            if id >= 0 && Int(id) < classicSoundNamePaths.count {
                return classicSoundNamePaths[Int(id)]
            }
            return "Sound \(id)"
    }
}

public func localizedPeerNotificationSoundString(sound: PeerMessageSound, default: PeerMessageSound? = nil) -> String {
    switch sound {
        case .default:
            if let defaultSound = `default` {
                let name = soundName(sound: defaultSound)
                let actualName: String
                if name.isEmpty {
                    actualName = soundName(sound: .bundledModern(id: 0))
                } else {
                    actualName = name
                }
                return strings().peerInfoNotificationsDefaultSound(actualName)
            } else {
                return strings().peerInfoNotificationsDefault
            }
        default:
            return soundName(sound: sound)
    }
}

func fileNameForNotificationSound(_ sound: PeerMessageSound, defaultSound: PeerMessageSound?) -> String {
    switch sound {
        case .none:
            return ""
        case .default:
            if let defaultSound = defaultSound {
                if case .default = defaultSound {
                    return "\(100)"
                } else {
                    return fileNameForNotificationSound(defaultSound, defaultSound: nil)
                }
            } else {
                return "default"
            }
        case let .bundledModern(id):
            return "\(id + 100)"
        case let .bundledClassic(id):
            return "\(id + 2)"
    }
}





enum NotificationsAndSoundsEntryTag: ItemListItemTag {
    case allAccounts
    case messagePreviews
    case includeChannels
    case unreadCountCategory
    case joinedNotifications
    case reset
    
    var stableId: InputDataEntryId {
        switch self {
        case .allAccounts:
            return .general(_id_all_accounts)
        case .messagePreviews:
            return .general(_id_message_preview)
        case .includeChannels:
            return .general(_id_include_channels)
        case .unreadCountCategory:
            return .general(_id_count_unred_messages)
        case .joinedNotifications:
            return .general(_id_new_contacts)
        case .reset:
            return .general(_id_reset)
        }
    }
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? NotificationsAndSoundsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private final class NotificationArguments {
    let resetAllNotifications:() -> Void
    let toggleMessagesPreview:() -> Void
    let toggleNotifications:() -> Void
    let notificationTone:(PeerMessageSound) -> Void
    let toggleIncludeUnreadChats:(Bool) -> Void
    let toggleCountUnreadMessages:(Bool) -> Void
    let toggleIncludeGroups:(Bool) -> Void
    let toggleIncludeChannels:(Bool) -> Void
    let allAcounts: ()-> Void
    let snoof: ()-> Void
    let updateJoinedNotifications: (Bool) -> Void
    let toggleBadge: (Bool)->Void
    let toggleRequestUserAttention: ()->Void
    let toggleInAppSounds:(Bool)->Void
    init(resetAllNotifications: @escaping() -> Void, toggleMessagesPreview:@escaping() -> Void, toggleNotifications:@escaping() -> Void, notificationTone:@escaping(PeerMessageSound) -> Void, toggleIncludeUnreadChats:@escaping(Bool) -> Void, toggleCountUnreadMessages:@escaping(Bool) -> Void, toggleIncludeGroups:@escaping(Bool) -> Void, toggleIncludeChannels:@escaping(Bool) -> Void, allAcounts: @escaping()-> Void, snoof: @escaping()-> Void, updateJoinedNotifications: @escaping(Bool) -> Void, toggleBadge: @escaping(Bool)->Void, toggleRequestUserAttention: @escaping ()->Void, toggleInAppSounds: @escaping(Bool)->Void) {
        self.resetAllNotifications = resetAllNotifications
        self.toggleMessagesPreview = toggleMessagesPreview
        self.toggleNotifications = toggleNotifications
        self.notificationTone = notificationTone
        self.toggleIncludeUnreadChats = toggleIncludeUnreadChats
        self.toggleCountUnreadMessages = toggleCountUnreadMessages
        self.toggleIncludeGroups = toggleIncludeGroups
        self.toggleIncludeChannels = toggleIncludeChannels
        self.allAcounts = allAcounts
        self.snoof = snoof
        self.updateJoinedNotifications = updateJoinedNotifications
        self.toggleBadge = toggleBadge
        self.toggleRequestUserAttention = toggleRequestUserAttention
        self.toggleInAppSounds = toggleInAppSounds
    }
}

private let _id_all_accounts = InputDataIdentifier("_id_all_accounts")
private let _id_notifications = InputDataIdentifier("_id_notifications")
private let _id_message_preview = InputDataIdentifier("_id_message_preview")
private let _id_reset = InputDataIdentifier("_id_reset")

private let _id_badge_enabled = InputDataIdentifier("_badge_enabled")
private let _id_include_muted_chats = InputDataIdentifier("_id_include_muted_chats")
private let _id_include_public_group = InputDataIdentifier("_id_include_public_group")
private let _id_include_channels = InputDataIdentifier("_id_include_channels")
private let _id_count_unred_messages = InputDataIdentifier("_id_count_unred_messages")
private let _id_new_contacts = InputDataIdentifier("_id_new_contacts")
private let _id_snoof = InputDataIdentifier("_id_snoof")
private let _id_tone = InputDataIdentifier("_id_tone")
private let _id_bounce = InputDataIdentifier("_id_bounce")

private let _id_turnon_notifications = InputDataIdentifier("_id_turnon_notifications")
private let _id_turnon_notifications_title = InputDataIdentifier("_id_turnon_notifications_title")

private let _id_message_effect = InputDataIdentifier("_id_message_effect")

private func notificationEntries(settings:InAppNotificationSettings, globalSettings: GlobalNotificationSettingsSet, accounts: [AccountWithInfo], unAuthStatus: UNUserNotifications.AuthorizationStatus, arguments: NotificationArguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    switch unAuthStatus {
    case .denied:
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_turnon_notifications_title, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return TurnOnNotificationsRowItem(initialSize, stableId: stableId, viewType: .firstItem)
        }))
        index += 1
        
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_turnon_notifications, data: InputDataGeneralData(name: strings().notificationSettingsTurnOn, color: theme.colors.text, type: .none, viewType: .lastItem, action: {
            openSystemSettings(.notifications)
        })))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    default:
        break
    }
    
    if accounts.count > 1 {
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSettingsShowNotificationsFrom), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_all_accounts, data: InputDataGeneralData(name: strings().notificationSettingsAllAccounts, color: theme.colors.text, type: .switchable(settings.notifyAllAccounts), viewType: .singleItem, action: {
            arguments.allAcounts()
        })))
        index += 1
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(settings.notifyAllAccounts ? strings().notificationSettingsShowNotificationsFromOn : strings().notificationSettingsShowNotificationsFromOff), data: InputDataGeneralTextData(viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
    }
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSettingsToggleNotificationsHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_notifications, data: InputDataGeneralData(name: strings().notificationSettingsToggleNotifications, color: theme.colors.text, type: .switchable(settings.enabled), viewType: .firstItem, action: {
        arguments.toggleNotifications()
    })))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_message_preview, data: InputDataGeneralData(name: strings().notificationSettingsMessagesPreview, color: theme.colors.text, type: .switchable(settings.displayPreviews), viewType: .innerItem, action: {
        arguments.toggleMessagesPreview()
    })))
    index += 1
    
    var tonesItems:[SPopoverItem] = []
    
    tonesItems.append(SPopoverItem(localizedPeerNotificationSoundString(sound: .default), {
        arguments.notificationTone(.default)
    }))

    tonesItems.append(SPopoverItem(localizedPeerNotificationSoundString(sound: .none), {
        arguments.notificationTone(.none)
    }))
    
    
    for i in 0 ..< 12 {
        let sound: PeerMessageSound = .bundledModern(id: Int32(i))
        tonesItems.append(SPopoverItem(localizedPeerNotificationSoundString(sound: sound), {
            arguments.notificationTone(sound)
        }))
    }
    for i in 0 ..< 8 {
        let sound: PeerMessageSound = .bundledClassic(id: Int32(i))
        tonesItems.append(SPopoverItem(localizedPeerNotificationSoundString(sound: sound), {
            arguments.notificationTone(sound)
        }))
    }
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_tone, data: InputDataGeneralData(name: strings().notificationSettingsNotificationTone, color: theme.colors.text, type: .contextSelector(localizedPeerNotificationSoundString(sound: settings.tone), tonesItems), viewType: .innerItem)))
    index += 1

    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_bounce, data: InputDataGeneralData(name: strings().notificationSettingsBounceDockIcon, color: theme.colors.text, type: .switchable(settings.requestUserAttention), viewType: .innerItem, action: {
        arguments.toggleRequestUserAttention()
    })))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_reset, data: InputDataGeneralData(name: strings().notificationSettingsResetNotifications, color: theme.colors.text, type: .none, viewType: .lastItem, action: {
        arguments.resetAllNotifications()
    })))
    index += 1
    
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSettingsSoundEffects), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1

    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_message_effect, data: InputDataGeneralData(name: strings().notificationSettingsSendMessageEffect, color: theme.colors.text, type: .switchable(FastSettings.inAppSounds), viewType: .singleItem, action: {
        arguments.toggleInAppSounds(!FastSettings.inAppSounds)
    })))
    index += 1
    

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSettingsBadgeHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_badge_enabled, data: InputDataGeneralData(name: strings().notificationSettingsBadgeEnabled, color: theme.colors.text, type: .switchable(settings.badgeEnabled), viewType: .firstItem, action: {
        arguments.toggleBadge(!settings.badgeEnabled)
    })))
    index += 1
    
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_include_public_group, data: InputDataGeneralData(name: strings().notificationSettingsIncludeGroups, color: theme.colors.text, type: .switchable(settings.totalUnreadCountIncludeTags.contains(.group)), viewType: .innerItem, enabled: settings.badgeEnabled, action: {
        arguments.toggleIncludeGroups(!settings.totalUnreadCountIncludeTags.contains(.group))
    })))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_include_channels, data: InputDataGeneralData(name: strings().notificationSettingsIncludeChannels, color: theme.colors.text, type: .switchable(settings.totalUnreadCountIncludeTags.contains(.channel)), viewType: .innerItem, enabled: settings.badgeEnabled, action: {
        arguments.toggleIncludeChannels(!settings.totalUnreadCountIncludeTags.contains(.channel))
    })))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_count_unred_messages, data: InputDataGeneralData(name: strings().notificationSettingsCountUnreadMessages, color: theme.colors.text, type: .switchable(settings.totalUnreadCountDisplayCategory == .messages), viewType: .lastItem, enabled: settings.badgeEnabled, action: {
        arguments.toggleCountUnreadMessages(settings.totalUnreadCountDisplayCategory != .messages)
    })))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSettingsBadgeDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_new_contacts, data: InputDataGeneralData(name: strings().notificationSettingsContactJoined, color: theme.colors.text, type: .switchable(globalSettings.contactsJoined), viewType: .singleItem, action: {
        arguments.updateJoinedNotifications(!globalSettings.contactsJoined)
    })))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSettingsContactJoinedInfo), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSettingsSnoofHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_snoof, data: InputDataGeneralData(name: strings().notificationSettingsSnoof, color: theme.colors.text, type: .switchable(!settings.showNotificationsOutOfFocus), viewType: .singleItem, action: {
        arguments.snoof()
    })))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(!settings.showNotificationsOutOfFocus ? strings().notificationSettingsSnoofOn : strings().notificationSettingsSnoofOff), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1


    return entries
}

func NotificationPreferencesController(_ context: AccountContext, focusOnItemTag: NotificationsAndSoundsEntryTag? = nil) -> ViewController {
    let arguments = NotificationArguments(resetAllNotifications: {
        confirm(for: context.window, header: strings().notificationSettingsConfirmReset, information: strings().chatConfirmActionUndonable, successHandler: { _ in
            _ = resetPeerNotificationSettings(network: context.account.network).start()
        })
    }, toggleMessagesPreview: {
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedDisplayPreviews(!$0.displayPreviews)}).start()
    }, toggleNotifications: {
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedEnables(!$0.enabled)}).start()
    }, notificationTone: { tone in
        if tone == .default {
            
        } else if tone != .none {
            let name = fileNameForNotificationSound(tone, defaultSound: nil)
            SoundEffectPlay.play(postbox: context.account.postbox, name: name, type: "m4a")
        }
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedTone(tone)}).start()
    }, toggleIncludeUnreadChats: { enable in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedTotalUnreadCountDisplayStyle(enable ? .raw : .filtered)}).start()
    }, toggleCountUnreadMessages: { enable in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedTotalUnreadCountDisplayCategory(enable ? .messages : .chats)}).start()
    }, toggleIncludeGroups: { enable in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { value in
            var tags: PeerSummaryCounterTags = value.totalUnreadCountIncludeTags
            if enable {
                tags.insert(.group)
            } else {
                tags.remove(.group)
            }
            return value.withUpdatedTotalUnreadCountIncludeTags(tags)
        }).start()
    }, toggleIncludeChannels: { enable in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { value in
            var tags: PeerSummaryCounterTags = value.totalUnreadCountIncludeTags
            if enable {
                tags.insert(.channel)
            } else {
                tags.remove(.channel)
            }
            return value.withUpdatedTotalUnreadCountIncludeTags(tags)
        }).start()
    }, allAcounts: {
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { value in
            return value.withUpdatedNotifyAllAccounts(!value.notifyAllAccounts)
        }).start()
    }, snoof: {
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { value in
            return value.withUpdatedSnoof(!value.showNotificationsOutOfFocus)
        }).start()
    }, updateJoinedNotifications: { value in
        _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.contactsJoined = value
            return settings
        }).start()
    }, toggleBadge: { enabled in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { value in
            return value.withUpdatedBadgeEnabled(enabled)
        }).start()
    }, toggleRequestUserAttention: {
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { value in
            return value.withUpdatedRequestUserAttention(!value.requestUserAttention)
        }).start()
    }, toggleInAppSounds: { value in
        FastSettings.toggleInAppSouds(value)
    })
    
    
    
    let entriesSignal = combineLatest(queue: prepareQueue, appNotificationSettings(accountManager: context.sharedContext.accountManager), globalNotificationSettings(postbox: context.account.postbox), context.sharedContext.activeAccountsWithInfo |> map { $0.accounts }, UNUserNotifications.recurrentAuthorizationStatus(context)) |> map { inAppSettings, globalSettings, accounts, unAuthStatus -> [InputDataEntry] in
        return notificationEntries(settings: inAppSettings, globalSettings: globalSettings, accounts: accounts, unAuthStatus: unAuthStatus, arguments: arguments)
    }

    
    let controller = InputDataController(dataSignal: entriesSignal |> map { InputDataSignalValue(entries: $0) }, title: strings().telegramNotificationSettingsViewController, hasDone: false, identifier: "notification-settings")
    
    
    controller.didLoaded = { controller, _ in
        if let focusOnItemTag = focusOnItemTag {
            controller.genericView.tableView.scroll(to: .center(id: focusOnItemTag.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets())
        }
    }
    
    return controller
}
