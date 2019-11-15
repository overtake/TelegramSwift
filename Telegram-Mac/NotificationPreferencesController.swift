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
import SyncCore

private final class NotificationArguments {
    let resetAllNotifications:() -> Void
    let toggleMessagesPreview:() -> Void
    let toggleNotifications:() -> Void
    let notificationTone:(String) -> Void
    let toggleIncludeUnreadChats:(Bool) -> Void
    let toggleCountUnreadMessages:(Bool) -> Void
    let toggleIncludePublicGroups:(Bool) -> Void
    let toggleIncludeChannels:(Bool) -> Void
    let allAcounts: ()-> Void
    let snoof: ()-> Void
    let updateJoinedNotifications: (Bool) -> Void
    let toggleBadge: (Bool)->Void
    init(resetAllNotifications: @escaping() -> Void, toggleMessagesPreview:@escaping() -> Void, toggleNotifications:@escaping() -> Void, notificationTone:@escaping(String) -> Void, toggleIncludeUnreadChats:@escaping(Bool) -> Void, toggleCountUnreadMessages:@escaping(Bool) -> Void, toggleIncludePublicGroups:@escaping(Bool) -> Void, toggleIncludeChannels:@escaping(Bool) -> Void, allAcounts: @escaping()-> Void, snoof: @escaping()-> Void, updateJoinedNotifications: @escaping(Bool) -> Void, toggleBadge: @escaping(Bool)->Void) {
        self.resetAllNotifications = resetAllNotifications
        self.toggleMessagesPreview = toggleMessagesPreview
        self.toggleNotifications = toggleNotifications
        self.notificationTone = notificationTone
        self.toggleIncludeUnreadChats = toggleIncludeUnreadChats
        self.toggleCountUnreadMessages = toggleCountUnreadMessages
        self.toggleIncludePublicGroups = toggleIncludePublicGroups
        self.toggleIncludeChannels = toggleIncludeChannels
        self.allAcounts = allAcounts
        self.snoof = snoof
        self.updateJoinedNotifications = updateJoinedNotifications
        self.toggleBadge = toggleBadge
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

private func notificationEntries(settings:InAppNotificationSettings, globalSettings: GlobalNotificationSettingsSet, accounts: [AccountWithInfo], arguments: NotificationArguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if accounts.count > 1 {
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.notificationSettingsShowNotificationsFrom), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_all_accounts, data: InputDataGeneralData(name: L10n.notificationSettingsAllAccounts, color: theme.colors.text, type: .switchable(settings.notifyAllAccounts), viewType: .singleItem, action: {
            arguments.allAcounts()
        })))
        index += 1
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(settings.notifyAllAccounts ? L10n.notificationSettingsShowNotificationsFromOn : L10n.notificationSettingsShowNotificationsFromOff), data: InputDataGeneralTextData(viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
    }
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.notificationSettingsToggleNotificationsHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_notifications, data: InputDataGeneralData(name: L10n.notificationSettingsToggleNotifications, color: theme.colors.text, type: .switchable(settings.enabled), viewType: .firstItem, action: {
        arguments.toggleNotifications()
    })))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_message_preview, data: InputDataGeneralData(name: L10n.notificationSettingsMessagesPreview, color: theme.colors.text, type: .switchable(settings.displayPreviews), viewType: .innerItem, action: {
        arguments.toggleMessagesPreview()
    })))
    index += 1
    
    
    let tones = ObjcUtils.notificationTones("Default")
    var tonesItems:[SPopoverItem] = []
    for tone in tones {
        tonesItems.append(SPopoverItem(localizedString(tone), {
            arguments.notificationTone(tone)
        }))
    }
 
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_tone, data: InputDataGeneralData(name: L10n.notificationSettingsNotificationTone, color: theme.colors.text, type: .contextSelector(settings.tone.isEmpty ? L10n.notificationSettingsToneDefault : localizedString(settings.tone), tonesItems), viewType: .innerItem)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_reset, data: InputDataGeneralData(name: L10n.notificationSettingsResetNotifications, color: theme.colors.text, type: .none, viewType: .lastItem, action: {
        arguments.resetAllNotifications()
    })))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.notificationSettingsResetNotificationsText), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.notificationSettingsBadgeHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_badge_enabled, data: InputDataGeneralData(name: L10n.notificationSettingsBadgeEnabled, color: theme.colors.text, type: .switchable(settings.badgeEnabled), viewType: .firstItem, action: {
        arguments.toggleBadge(!settings.badgeEnabled)
    })))
    index += 1
    
    
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_include_muted_chats, data: InputDataGeneralData(name: L10n.notificationSettingsIncludeMutedChats, color: theme.colors.text, type: .switchable(settings.totalUnreadCountDisplayStyle == .raw), viewType: .innerItem, enabled: settings.badgeEnabled, action: {
        arguments.toggleIncludeUnreadChats(settings.totalUnreadCountDisplayStyle != .raw)
    })))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_include_public_group, data: InputDataGeneralData(name: L10n.notificationSettingsIncludePublicGroups, color: theme.colors.text, type: .switchable(settings.totalUnreadCountIncludeTags.contains(.publicGroups)), viewType: .innerItem, enabled: settings.badgeEnabled, action: {
        arguments.toggleIncludePublicGroups(!settings.totalUnreadCountIncludeTags.contains(.publicGroups))
    })))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_include_channels, data: InputDataGeneralData(name: L10n.notificationSettingsIncludeChannels, color: theme.colors.text, type: .switchable(settings.totalUnreadCountIncludeTags.contains(.channels)), viewType: .innerItem, enabled: settings.badgeEnabled, action: {
        arguments.toggleIncludeChannels(!settings.totalUnreadCountIncludeTags.contains(.channels))
    })))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_count_unred_messages, data: InputDataGeneralData(name: L10n.notificationSettingsCountUnreadMessages, color: theme.colors.text, type: .switchable(settings.totalUnreadCountDisplayCategory == .messages), viewType: .lastItem, enabled: settings.badgeEnabled, action: {
        arguments.toggleCountUnreadMessages(settings.totalUnreadCountDisplayCategory != .messages)
    })))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.notificationSettingsBadgeDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_new_contacts, data: InputDataGeneralData(name: L10n.notificationSettingsContactJoined, color: theme.colors.text, type: .switchable(globalSettings.contactsJoined), viewType: .singleItem, action: {
        arguments.updateJoinedNotifications(!globalSettings.contactsJoined)
    })))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.notificationSettingsContactJoinedInfo), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.notificationSettingsSnoofHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_snoof, data: InputDataGeneralData(name: L10n.notificationSettingsSnoof, color: theme.colors.text, type: .switchable(!settings.showNotificationsOutOfFocus), viewType: .singleItem, action: {
        arguments.snoof()
    })))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(!settings.showNotificationsOutOfFocus ? L10n.notificationSettingsSnoofOn : L10n.notificationSettingsSnoofOff), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1


    return entries
}

func NotificationPreferencesController(_ context: AccountContext) -> ViewController {

    
    let arguments = NotificationArguments(resetAllNotifications: {
        confirm(for: context.window, header: L10n.notificationSettingsConfirmReset, information: tr(L10n.chatConfirmActionUndonable), successHandler: { _ in
            _ = resetPeerNotificationSettings(network: context.account.network).start()
        })
    }, toggleMessagesPreview: {
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedDisplayPreviews(!$0.displayPreviews)}).start()
    }, toggleNotifications: {
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedEnables(!$0.enabled)}).start()
    }, notificationTone: { tone in
        _ = NSSound(named: tone)?.play()
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedTone(tone)}).start()
    }, toggleIncludeUnreadChats: { enable in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedTotalUnreadCountDisplayStyle(enable ? .raw : .filtered)}).start()
    }, toggleCountUnreadMessages: { enable in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedTotalUnreadCountDisplayCategory(enable ? .messages : .chats)}).start()
    }, toggleIncludePublicGroups: { enable in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { value in
            var tags: PeerSummaryCounterTags = value.totalUnreadCountIncludeTags
            if enable {
                tags.insert(.publicGroups)
            } else {
                tags.remove(.publicGroups)
            }
            return value.withUpdatedTotalUnreadCountIncludeTags(tags)
        }).start()
    }, toggleIncludeChannels: { enable in
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { value in
            var tags: PeerSummaryCounterTags = value.totalUnreadCountIncludeTags
            if enable {
                tags.insert(.channels)
            } else {
                tags.remove(.channels)
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
    })
    
    let entriesSignal = combineLatest(queue: prepareQueue, appNotificationSettings(accountManager: context.sharedContext.accountManager), globalNotificationSettings(postbox: context.account.postbox), context.sharedContext.activeAccountsWithInfo |> map { $0.accounts }) |> map { inAppSettings, globalSettings, accounts -> [InputDataEntry] in
            return notificationEntries(settings: inAppSettings, globalSettings: globalSettings, accounts: accounts, arguments: arguments)
    }

    
    return InputDataController(dataSignal: entriesSignal |> map { InputDataSignalValue(entries: $0) }, title: L10n.telegramNotificationSettingsViewController, hasDone: false, identifier: "notification-settings")
    
}
