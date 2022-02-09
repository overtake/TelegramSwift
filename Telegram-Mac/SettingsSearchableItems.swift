//
//  SettingsSearchableItems.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.12.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TGUIKit
import SwiftSignalKit
import TelegramCore
import InAppSettings

enum SettingsSearchableItemIcon {
    case profile
    case proxy
    case savedMessages
    case calls
    case stickers
    case notifications
    case privacy
    case data
    case appearance
    case language
    case watch
    case wallet
    case passport
    case support
    case faq
}

extension SettingsSearchableItemIcon {
    var thumb: CGImage? {
        switch self {
        case .profile:
            return theme.icons.settingsProfile
        case .proxy:
            return theme.icons.settingsProxy
        case .stickers:
            return theme.icons.settingsStickers
        case .notifications:
            return theme.icons.settingsNotifications
        case .privacy:
            return theme.icons.settingsSecurity
        case .data:
            return theme.icons.settingsStorage
        case .appearance:
            return theme.icons.settingsAppearance
        case .language:
            return theme.icons.settingsLanguage
        case .support:
            return theme.icons.settingsAskQuestion
        case .faq:
            return theme.icons.settingsFaq
        default:
            return nil
        }
    }
}




enum SettingsSearchableItemId: Hashable {
    case profile(Int32)
    case proxy(Int32)
    case savedMessages(Int32)
    case calls(Int32)
    case stickers(Int32)
    case notifications(Int32)
    case privacy(Int32)
    case data(Int32)
    case appearance(Int32)
    case language(Int32)
    case watch(Int32)
    case passport(Int32)
    case wallet(Int32)
    case support(Int32)
    case faq(Int32)
    
    private var namespace: Int32 {
        switch self {
        case .profile:
            return 1
        case .proxy:
            return 2
        case .savedMessages:
            return 3
        case .calls:
            return 4
        case .stickers:
            return 5
        case .notifications:
            return 6
        case .privacy:
            return 7
        case .data:
            return 8
        case .appearance:
            return 9
        case .language:
            return 10
        case .watch:
            return 11
        case .passport:
            return 12
        case .wallet:
            return 13
        case .support:
            return 14
        case .faq:
            return 15
        }
    }
    
    private var id: Int32 {
        switch self {
        case let .profile(id),
             let .proxy(id),
             let .savedMessages(id),
             let .calls(id),
             let .stickers(id),
             let .notifications(id),
             let .privacy(id),
             let .data(id),
             let .appearance(id),
             let .language(id),
             let .watch(id),
             let .passport(id),
             let .wallet(id),
             let .support(id),
             let .faq(id):
            return id
        }
    }
    
    var index: Int64 {
        return (Int64(self.namespace) << 32) | Int64(self.id)
    }
    
    init?(index: Int64) {
        let namespace = Int32((index >> 32) & 0x7fffffff)
        let id = Int32(bitPattern: UInt32(index & 0xffffffff))
        switch namespace {
        case 1:
            self = .profile(id)
        case 2:
            self = .proxy(id)
        case 3:
            self = .savedMessages(id)
        case 4:
            self = .calls(id)
        case 5:
            self = .stickers(id)
        case 6:
            self = .notifications(id)
        case 7:
            self = .privacy(id)
        case 8:
            self = .data(id)
        case 9:
            self = .appearance(id)
        case 10:
            self = .language(id)
        case 11:
            self = .watch(id)
        case 12:
            self = .passport(id)
        case 13:
            self = .wallet(id)
        case 14:
            self = .support(id)
        case 15:
            self = .faq(id)
        default:
            return nil
        }
    }
}

enum SettingsSearchableItemPresentation {
    case push
    case modal
    case immediate
    case dismiss
}



struct SettingsSearchableItem {
    let id: SettingsSearchableItemId
    let title: String
    let alternate: [String]
    let icon: SettingsSearchableItemIcon
    let breadcrumbs: [String]
    let present: (AccountContext, NavigationViewController?, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void
}



func searchSettingsItems(items: [SettingsSearchableItem], query: String) -> [SettingsSearchableItem] {
    let queryTokens = stringTokens(query.lowercased())
    
    var result: [SettingsSearchableItem] = []
    for item in items {
        var string = item.title
        if !item.alternate.isEmpty {
            for alternate in item.alternate {
                let trimmed = alternate.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    string += " \(trimmed)"
                }
            }
        }
        if item.breadcrumbs.count > 1 {
            string += " \(item.breadcrumbs.suffix(from: 1).joined(separator: " "))"
        }
        
        let tokens = stringTokens(string)
        if matchStringTokens(tokens, with: queryTokens) {
            result.append(item)
        }
    }
    
    return result
}


private func synonyms(_ string: String?) -> [String] {
    if let string = string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return string.components(separatedBy: "\n")
    } else {
        return []
    }
}



private func stringTokens(_ string: String) -> [ValueBoxKey] {
    let nsString = string.folding(options: .diacriticInsensitive, locale: .current).lowercased() as NSString
    
    let flag = UInt(kCFStringTokenizerUnitWord)
    let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, nsString, CFRangeMake(0, nsString.length), flag, CFLocaleCopyCurrent())
    var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    var tokens: [ValueBoxKey] = []
    
    var addedTokens = Set<ValueBoxKey>()
    while tokenType != [] {
        let currentTokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        
        if currentTokenRange.location >= 0 && currentTokenRange.length != 0 {
            let token = ValueBoxKey(length: currentTokenRange.length * 2)
            nsString.getCharacters(token.memory.assumingMemoryBound(to: unichar.self), range: NSMakeRange(currentTokenRange.location, currentTokenRange.length))
            if !addedTokens.contains(token) {
                tokens.append(token)
                addedTokens.insert(token)
            }
        }
        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    }
    
    return tokens
}

private func matchStringTokens(_ tokens: [ValueBoxKey], with other: [ValueBoxKey]) -> Bool {
    if other.isEmpty {
        return false
    } else if other.count == 1 {
        let otherToken = other[0]
        for token in tokens {
            if otherToken.isPrefix(to: token) {
                return true
            }
        }
    } else {
        for otherToken in other {
            var found = false
            for token in tokens {
                if otherToken.isPrefix(to: token) {
                    found = true
                    break
                }
            }
            if !found {
                return false
            }
        }
        return true
    }
    return false
}


private func profileSearchableItems(context: AccountContext, canAddAccount: Bool) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .profile
    
    let presentProfileSettings: (AccountContext, @escaping  (SettingsSearchableItemPresentation, ViewController?) -> Void, EditSettingsEntryTag?) -> Void = { context, present, itemTag in
        EditAccountInfoController(context: context, focusOnItemTag: itemTag, f: { controller in
            present(.push, controller)
        })
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(SettingsSearchableItem(id: .profile(0), title: strings().editAccountTitle, alternate: synonyms(strings().settingsSearchSynonymsEditProfileTitle), icon: icon, breadcrumbs: [], present: { context, _, present in
        presentProfileSettings(context, present, nil)
    }))
    
    items.append(SettingsSearchableItem(id: .profile(1), title: strings().accountSettingsBio, alternate: synonyms(strings().settingsSearchSynonymsEditProfileTitle), icon: icon, breadcrumbs: [strings().editAccountTitle], present: { context, _, present in
        presentProfileSettings(context, present, .bio)
    }))
    items.append(SettingsSearchableItem(id: .profile(2), title: strings().editAccountChangeNumber, alternate: synonyms(strings().settingsSearchSynonymsEditProfilePhoneNumber), icon: icon, breadcrumbs: [strings().editAccountTitle], present: { context, _, present in
        present(.push, PhoneNumberIntroController(context))
    }))
    items.append(SettingsSearchableItem(id: .profile(3), title: strings().editAccountUsername, alternate: synonyms(strings().settingsSearchSynonymsEditProfileUsername), icon: icon, breadcrumbs: [strings().editAccountTitle], present: { context, _, present in
        present(.push, UsernameSettingsViewController(context))
    }))
    if canAddAccount {
        items.append(SettingsSearchableItem(id: .profile(4), title: strings().editAccountAddAccount, alternate: synonyms(strings().settingsSearchSynonymsEditProfileAddAccount), icon: icon, breadcrumbs: [strings().editAccountTitle], present: { context, _, present in
            let isTestingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
            context.sharedContext.beginNewAuth(testingEnvironment: isTestingEnvironment)
        }))
    }
    items.append(SettingsSearchableItem(id: .profile(5), title: strings().editAccountLogout, alternate: synonyms(strings().settingsSearchSynonymsEditProfileLogout), icon: icon, breadcrumbs: [strings().editAccountTitle], present: { context, navigationController, present in
        showModal(with: LogoutViewController(context: context, f: { controller in
            present(.push, controller)
        }), for: context.window)
    }))
    return items
}



private func stickerSearchableItems(context: AccountContext, archivedStickerPacks: [ArchivedStickerPackItem]?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .stickers
    
    let presentStickerSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, InstalledStickerPacksEntryTag?) -> Void = { context, present, itemTag in
        present(.push, InstalledStickerPacksController(context, focusOnItemTag: itemTag))
    }
    
    var items: [SettingsSearchableItem] = []
    
    items.append(SettingsSearchableItem(id: .stickers(0), title: strings().accountSettingsStickers, alternate: synonyms(strings().settingsSearchSynonymsStickersTitle), icon: icon, breadcrumbs: [], present: { context, _, present in
        presentStickerSettings(context, present, nil)
    }))
    items.append(SettingsSearchableItem(id: .stickers(1), title: strings().stickersSuggestStickers, alternate: synonyms(strings().settingsSearchSynonymsStickersSuggestStickers), icon: icon, breadcrumbs: [strings().accountSettingsStickers], present: { context, _, present in
        presentStickerSettings(context, present, .suggestOptions)
    }))
    items.append(SettingsSearchableItem(id: .stickers(3), title: strings().installedStickersTranding, alternate: synonyms(strings().settingsSearchSynonymsStickersFeaturedPacks), icon: icon, breadcrumbs: [strings().accountSettingsStickers], present: { context, _, present in
        present(.push, FeaturedStickerPacksController(context))
    }))
    items.append(SettingsSearchableItem(id: .stickers(4), title: strings().installedStickersArchived, alternate: synonyms(strings().settingsSearchSynonymsStickersArchivedPacks), icon: icon, breadcrumbs: [strings().accountSettingsStickers], present: { context, _, present in
        present(.push, ArchivedStickerPacksController(context, archived: nil, updatedPacks: { _ in }))
    }))
    return items
}

private func notificationSearchableItems(context: AccountContext, settings: GlobalNotificationSettingsSet) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .notifications
    
    let presentNotificationSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, NotificationsAndSoundsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, NotificationPreferencesController(context, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(id: .notifications(0), title: strings().accountSettingsNotifications, alternate: synonyms(strings().settingsSearchSynonymsNotificationsTitle), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentNotificationSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .notifications(2), title: strings().notificationSettingsMessagesPreview, alternate: synonyms(strings().settingsSearchSynonymsNotificationsMessageNotificationsPreview), icon: icon, breadcrumbs: [strings().accountSettingsNotifications, strings().notificationSettingsToggleNotificationsHeader], present: { context, _, present in
            presentNotificationSettings(context, present, .messagePreviews)
        }),
//        SettingsSearchableItem(id: .notifications(18), title: strings().notificationSettingsIncludeGroups, alternate: synonyms(strings().settingsSearchSynonymsNotificationsBadgeIncludeMutedPublicGroups), icon: icon, breadcrumbs: [strings().accountSettingsNotifications, strings().notificationSettingsBadgeHeader], present: { context, _, present in
//            presentNotificationSettings(context, present, .includePublicGroups)
//        }),
        SettingsSearchableItem(id: .notifications(19), title: strings().notificationSettingsIncludeChannels, alternate: synonyms(strings().settingsSearchSynonymsNotificationsBadgeIncludeMutedChannels), icon: icon, breadcrumbs: [strings().accountSettingsNotifications, strings().notificationSettingsBadgeHeader], present: { context, _, present in
            presentNotificationSettings(context, present, .includeChannels)
        }),
        SettingsSearchableItem(id: .notifications(20), title: strings().notificationSettingsCountUnreadMessages, alternate: synonyms(strings().settingsSearchSynonymsNotificationsBadgeCountUnreadMessages), icon: icon, breadcrumbs: [strings().accountSettingsNotifications, strings().notificationSettingsBadgeHeader], present: { context, _, present in
            presentNotificationSettings(context, present, .unreadCountCategory)
        }),
        SettingsSearchableItem(id: .notifications(21), title: strings().notificationSettingsContactJoined, alternate: synonyms(strings().settingsSearchSynonymsNotificationsContactJoined), icon: icon, breadcrumbs: [strings().accountSettingsNotifications], present: { context, _, present in
            presentNotificationSettings(context, present, .joinedNotifications)
        }),
        SettingsSearchableItem(id: .notifications(22), title: strings().notificationSettingsResetNotifications, alternate: synonyms(strings().settingsSearchSynonymsNotificationsResetAllNotifications), icon: icon, breadcrumbs: [strings().accountSettingsNotifications], present: { context, _, present in
            presentNotificationSettings(context, present, .reset)
        })
    ]
}

private func privacySearchableItems(context: AccountContext, privacySettings: AccountPrivacySettings?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .privacy
    
    let presentPrivacySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, PrivacyAndSecurityEntryTag?) -> Void = { context, present, itemTag in
        present(.push, PrivacyAndSecurityViewController(context, initialSettings: nil, focusOnItemTag: itemTag))
    }
    
    let presentSelectivePrivacySettings: (AccountContext, SelectivePrivacySettingsKind, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { context, kind, present in
        let privacySignal: Signal<AccountPrivacySettings, NoError>
        if let privacySettings = privacySettings {
            privacySignal = .single(privacySettings)
        } else {
            privacySignal = context.engine.privacy.requestAccountPrivacySettings()
        }
        let callsSignal: Signal<(VoiceCallSettings, VoipConfiguration)?, NoError>
        if case .voiceCalls = kind {
            callsSignal = combineLatest(context.sharedContext.accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.voiceCallSettings]), context.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration]))
                |> take(1)
                |> map { sharedData, view -> (VoiceCallSettings, VoipConfiguration)? in
                    let voiceCallSettings: VoiceCallSettings = sharedData.entries[ApplicationSharedPreferencesKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? .defaultSettings
                    let voipConfiguration = view.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
                    return (voiceCallSettings, voipConfiguration)
            }
        } else {
            callsSignal = .single(nil)
        }
        
        let _ = (combineLatest(privacySignal, callsSignal)
            |> deliverOnMainQueue).start(next: { info, callSettings in
                let current: SelectivePrivacySettings
                switch kind {
                case .presence:
                    current = info.presence
                case .groupInvitations:
                    current = info.groupInvitations
                case .voiceCalls:
                    current = info.voiceCalls
                case .profilePhoto:
                    current = info.profilePhoto
                case .forwards:
                    current = info.forwards
                case .phoneNumber:
                    current = info.phoneNumber
                }
                
                present(.push, SelectivePrivacySettingsController(context, kind: kind, current: current, callSettings: kind == .voiceCalls ? info.voiceCallsP2P : nil, phoneDiscoveryEnabled: nil, updated: { updated, updatedCallSettings, _ in }))
            })
    }
    

    
    let passcodeTitle: String = strings().privacySettingsPasscode

    
    return [
        SettingsSearchableItem(id: .privacy(0), title: strings().accountSettingsPrivacyAndSecurity, alternate: synonyms(strings().settingsSearchSynonymsPrivacyTitle), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentPrivacySettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .privacy(1), title: strings().privacySettingsBlockedUsers, alternate: synonyms(strings().settingsSearchSynonymsPrivacyBlockedUsers), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            present(.push, BlockedPeersViewController(context))
        }),
        SettingsSearchableItem(id: .privacy(2), title: strings().privacySettingsLastSeen, alternate: synonyms(strings().settingsSearchSynonymsPrivacyLastSeen), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            presentSelectivePrivacySettings(context, .presence, present)
        }),
        SettingsSearchableItem(id: .privacy(3), title: strings().privacySettingsProfilePhoto, alternate: synonyms(strings().settingsSearchSynonymsPrivacyProfilePhoto), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            presentSelectivePrivacySettings(context, .profilePhoto, present)
        }),
        SettingsSearchableItem(id: .privacy(4), title: strings().privacySettingsForwards, alternate: synonyms(strings().settingsSearchSynonymsPrivacyForwards), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            presentSelectivePrivacySettings(context, .forwards, present)
        }),
        SettingsSearchableItem(id: .privacy(5), title: strings().privacySettingsVoiceCalls, alternate: synonyms(strings().settingsSearchSynonymsPrivacyCalls), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            presentSelectivePrivacySettings(context, .voiceCalls, present)
        }),
        SettingsSearchableItem(id: .privacy(6), title: strings().privacySettingsGroups, alternate: synonyms(strings().settingsSearchSynonymsPrivacyGroupsAndChannels), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            presentSelectivePrivacySettings(context, .groupInvitations, present)
        }),
        SettingsSearchableItem(id: .privacy(7), title: passcodeTitle, alternate: [], icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            present(.push, PasscodeSettingsViewController(context))
        }),
        SettingsSearchableItem(id: .privacy(8), title: strings().privacySettingsTwoStepVerification, alternate: synonyms(strings().settingsSearchSynonymsPrivacyTwoStepAuth), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, navigation, present in
            present(.push, twoStepVerificationUnlockController(context: context, mode: .access(nil), presentController: { controller, root, animated in
                guard let navigation = navigation else {return}
                if root {
                    navigation.removeUntil(PrivacyAndSecurityViewController.self)
                }
                if !animated {
                    navigation.stackInsert(controller, at: navigation.stackCount)
                } else {
                    navigation.push(controller)
                }
            }))
        }),
        SettingsSearchableItem(id: .privacy(9), title: strings().privacySettingsActiveSessions, alternate: synonyms(strings().settingsSearchSynonymsPrivacyAuthSessions), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            present(.push, RecentSessionsController(context))
        }),
        SettingsSearchableItem(id: .privacy(10), title: strings().privacySettingsDeleteAccountHeader, alternate: synonyms(strings().settingsSearchSynonymsPrivacyDeleteAccountIfAwayFor), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            presentPrivacySettings(context, present, .accountTimeout)
        }),
        SettingsSearchableItem(id: .privacy(14), title: strings().suggestFrequentContacts, alternate: synonyms(strings().settingsSearchSynonymsPrivacyDataTopPeers), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            presentPrivacySettings(context, present, .topPeers)
        }),
        SettingsSearchableItem(id: .privacy(15), title: strings().privacyAndSecurityClearCloudDrafts, alternate: synonyms(strings().settingsSearchSynonymsPrivacyDataDeleteDrafts), icon: icon, breadcrumbs: [strings().accountSettingsPrivacyAndSecurity], present: { context, _, present in
            presentPrivacySettings(context, present, .cloudDraft)
        })
    ]
}

private func dataSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .data
    
    let presentDataSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, DataAndStorageEntryTag?) -> Void = { context, present, itemTag in
        present(.push, DataAndStorageViewController(context, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(id: .data(0), title: strings().accountSettingsDataAndStorage, alternate: synonyms(strings().settingsSearchSynonymsDataTitle), icon: icon, breadcrumbs: [], present: { context, _, present in
           presentDataSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .data(1), title: strings().dataAndStorageStorageUsage, alternate: synonyms(strings().settingsSearchSynonymsDataStorageTitle), icon: icon, breadcrumbs: [strings().accountSettingsDataAndStorage], present: { context, _, present in
            present(.push, StorageUsageController(context))
        }),
        SettingsSearchableItem(id: .data(2), title: strings().storageUsageKeepMedia, alternate: synonyms(strings().settingsSearchSynonymsDataStorageKeepMedia), icon: icon, breadcrumbs: [strings().accountSettingsDataAndStorage, strings().dataAndStorageStorageUsage], present: { context, _, present in
            present(.push, StorageUsageController(context))
        }),
        SettingsSearchableItem(id: .data(3), title: strings().logoutOptionsClearCacheTitle, alternate: synonyms(strings().settingsSearchSynonymsDataStorageClearCache), icon: icon, breadcrumbs: [strings().accountSettingsDataAndStorage, strings().dataAndStorageStorageUsage], present: { context, _, present in
            present(.push, StorageUsageController(context))
        }),
        SettingsSearchableItem(id: .data(4), title: strings().dataAndStorageNetworkUsage, alternate: synonyms(strings().settingsSearchSynonymsDataNetworkUsage), icon: icon, breadcrumbs: [strings().accountSettingsDataAndStorage], present: { context, _, present in
            present(.push, networkUsageStatsController(context: context))
        }),
        SettingsSearchableItem(id: .data(7), title: strings().dataAndStorageAutomaticDownloadReset, alternate: synonyms(strings().settingsSearchSynonymsDataAutoDownloadReset), icon: icon, breadcrumbs: [strings().accountSettingsDataAndStorage], present: { context, _, present in
            presentDataSettings(context, present, .automaticDownloadReset)
        }),
        SettingsSearchableItem(id: .data(8), title: strings().dataAndStorageAutoplayGIFs, alternate: synonyms(strings().settingsSearchSynonymsDataAutoplayGifs), icon: icon, breadcrumbs: [strings().accountSettingsDataAndStorage, strings().dataAndStorageAutoplayHeader], present: { context, _, present in
            presentDataSettings(context, present, .autoplayGifs)
        }),
        SettingsSearchableItem(id: .data(9), title: strings().dataAndStorageAutoplayVideos, alternate: synonyms(strings().settingsSearchSynonymsDataAutoplayVideos), icon: icon, breadcrumbs: [strings().accountSettingsDataAndStorage, strings().dataAndStorageAutoplayHeader], present: { context, _, present in
            presentDataSettings(context, present, .autoplayVideos)
        })
    ]
}

private func proxySearchableItems(context: AccountContext, servers: [ProxyServerSettings]) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .proxy
    
    let presentProxySettings: (AccountContext, @escaping(SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { context, present in
        let controller = proxyListController(accountManager: context.sharedContext.accountManager, network: context.account.network, share: { servers in
            var message: String = ""
            for server in servers {
                message += server.link + "\n\n"
            }
            message = message.trimmed
            
            showModal(with: ShareModalController(ShareLinkObject(context, link: message)), for: context.window)
        }, pushController: { controller in
            present(.push, controller)
        })
        present(.push, controller)
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(SettingsSearchableItem(id: .proxy(0), title: strings().accountSettingsProxy, alternate: synonyms(strings().settingsSearchSynonymsProxyTitle), icon: icon, breadcrumbs: [], present: { context, _, present in
        presentProxySettings(context, present)
    }))
    items.append(SettingsSearchableItem(id: .proxy(1), title: strings().proxySettingsAddProxy, alternate: synonyms(strings().settingsSearchSynonymsProxyAddProxy), icon: icon, breadcrumbs: [strings().accountSettingsProxy], present: { context, _, present in
        presentProxySettings(context, present)
    }))
    
    var hasSocksServers = false
    for server in servers {
        if case .socks5 = server.connection {
            hasSocksServers = true
            break
        }
    }
    if hasSocksServers {
        items.append(SettingsSearchableItem(id: .proxy(2), title: strings().proxySettingsUseForCalls, alternate: synonyms(strings().settingsSearchSynonymsProxyUseForCalls), icon: icon, breadcrumbs: [strings().accountSettingsProxy], present: { context, _, present in
            presentProxySettings(context, present)
        }))
    }
    return items
}

private func appearanceSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .appearance
    
    let presentAppearanceSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, ThemeSettingsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, AppAppearanceViewController(context: context, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(id: .appearance(0), title: strings().accountSettingsTheme, alternate: synonyms(strings().settingsSearchSynonymsAppearanceTitle), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentAppearanceSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .appearance(1), title: strings().appearanceSettingsTextSizeHeader, alternate: synonyms(strings().settingsSearchSynonymsAppearanceTextSize), icon: icon, breadcrumbs: [strings().accountSettingsTheme], present: { context, _, present in
            presentAppearanceSettings(context, present, .fontSize)
        }),
        SettingsSearchableItem(id: .appearance(2), title: strings().generalSettingsChatBackground, alternate: synonyms(strings().settingsSearchSynonymsAppearanceChatBackground), icon: icon, breadcrumbs: [strings().accountSettingsTheme], present: { context, _, present in
            showModal(with: ChatWallpaperModalController(context), for: context.window)
        }),
        SettingsSearchableItem(id: .appearance(5), title: strings().appearanceSettingsAutoNight, alternate: synonyms(strings().settingsSearchSynonymsAppearanceAutoNightTheme), icon: icon, breadcrumbs: [strings().accountSettingsTheme], present: { context, _, present in
            present(.push, AutoNightSettingsController(context: context))
        }),
        SettingsSearchableItem(id: .appearance(6), title: strings().appearanceSettingsColorThemeHeader, alternate: synonyms(strings().settingsSearchSynonymsAppearanceColorTheme), icon: icon, breadcrumbs: [strings().accountSettingsTheme], present: { context, _, present in
            presentAppearanceSettings(context, present, .accentColor)
        }),
        SettingsSearchableItem(id: .appearance(6), title: strings().appearanceSettingsChatViewHeader, alternate: synonyms(strings().settingsSearchSynonymsAppearanceChatMode), icon: icon, breadcrumbs: [strings().accountSettingsTheme], present: { context, _, present in
            presentAppearanceSettings(context, present, .chatMode)
        }),
    ]
}

private func languageSearchableItems(context: AccountContext, localizations: [LocalizationInfo]) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .language
    
    let applyLocalization: (AccountContext, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void, String) -> Void = { context, present, languageCode in
        _ = showModalProgress(signal: context.engine.localization.downloadAndApplyLocalization(accountManager: context.sharedContext.accountManager, languageCode: languageCode), for: context.window).start()
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(SettingsSearchableItem(id: .language(0), title: strings().accountSettingsLanguage, alternate: synonyms(strings().settingsSearchSynonymsAppLanguage), icon: icon, breadcrumbs: [], present: { context, _, present in
        present(.push, LanguageViewController(context))
    }))
    var index: Int32 = 1
    for localization in localizations {
        items.append(SettingsSearchableItem(id: .language(index), title: localization.localizedTitle, alternate: [localization.title], icon: icon, breadcrumbs: [strings().accountSettingsLanguage], present: { context, _, present in
            applyLocalization(context, present, localization.languageCode)
        }))
        index += 1
    }
    return items
}

func settingsSearchableItems(context: AccountContext, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>) -> Signal<[SettingsSearchableItem], NoError> {
    
    let canAddAccount = activeAccountsAndPeers(context: context)
        |> take(1)
        |> map { accountsAndPeers -> Bool in
            return accountsAndPeers.1.count + 1 < maximumNumberOfAccounts
    }
    
    let notificationSettings = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
        |> take(1)
        |> map { view -> GlobalNotificationSettingsSet in
            let viewSettings: GlobalNotificationSettingsSet
            if let settings = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
                viewSettings = settings.effective
            } else {
                viewSettings = GlobalNotificationSettingsSet.defaultSettings
            }
            return viewSettings
    }
    
    let archivedStickerPacks = archivedStickerPacks
        |> take(1)
    
    let privacySettings = privacySettings
        |> take(1)
    
    let proxyServers = context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> map { sharedData -> ProxySettings in
            if let value = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
                return value
            } else {
                return ProxySettings.defaultSettings
            }
        }
        |> map { settings -> [ProxyServerSettings] in
            return settings.servers
    }
    
    let localizationPreferencesKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.localizationListState]))
    let localizations = combineLatest(context.account.postbox.combinedView(keys: [localizationPreferencesKey]), context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.localizationSettings]))
        |> map { view, sharedData -> [LocalizationInfo] in
            if let localizationListState = (view.views[localizationPreferencesKey] as? PreferencesView)?.values[PreferencesKeys.localizationListState]?.get(LocalizationListState.self), !localizationListState.availableOfficialLocalizations.isEmpty {
                
                var existingIds = Set<String>()
                let availableSavedLocalizations = localizationListState.availableSavedLocalizations.filter({ info in !localizationListState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) })
                
                var activeLanguageCode: String?
                if let localizationSettings = sharedData.entries[SharedDataKeys.localizationSettings]?.get(LocalizationSettings.self) {
                    activeLanguageCode = localizationSettings.primaryComponent.languageCode
                }
                
                var localizationItems: [LocalizationInfo] = []
                if !availableSavedLocalizations.isEmpty {
                    for info in availableSavedLocalizations {
                        if existingIds.contains(info.languageCode) || info.languageCode == activeLanguageCode {
                            continue
                        }
                        existingIds.insert(info.languageCode)
                        localizationItems.append(info)
                    }
                }
                for info in localizationListState.availableOfficialLocalizations {
                    if existingIds.contains(info.languageCode) || info.languageCode == activeLanguageCode {
                        continue
                    }
                    existingIds.insert(info.languageCode)
                    localizationItems.append(info)
                }
                
                return localizationItems
            } else {
                return []
            }
    }
    
    return combineLatest(canAddAccount, localizations, notificationSettings, archivedStickerPacks, proxyServers, privacySettings)
        |> map { canAddAccount, localizations, notificationSettings, archivedStickerPacks, proxyServers, privacySettings in
            
            var allItems: [SettingsSearchableItem] = []
            
            let profileItems = profileSearchableItems(context: context, canAddAccount: canAddAccount)
            allItems.append(contentsOf: profileItems)
            
            
            let stickerItems = stickerSearchableItems(context: context, archivedStickerPacks: archivedStickerPacks)
            allItems.append(contentsOf: stickerItems)
            
            let notificationItems = notificationSearchableItems(context: context, settings: notificationSettings)
            allItems.append(contentsOf: notificationItems)
            
            let privacyItems = privacySearchableItems(context: context, privacySettings: privacySettings)
            allItems.append(contentsOf: privacyItems)
            
            let dataItems = dataSearchableItems(context: context)
            allItems.append(contentsOf: dataItems)
            
            let proxyItems = proxySearchableItems(context: context, servers: proxyServers)
            allItems.append(contentsOf: proxyItems)
            
            let appearanceItems = appearanceSearchableItems(context: context)
            allItems.append(contentsOf: appearanceItems)
            
            let languageItems = languageSearchableItems(context: context, localizations: localizations)
            allItems.append(contentsOf: languageItems)
            

            let support = SettingsSearchableItem(id: .support(0), title: strings().accountSettingsAskQuestion, alternate: synonyms(strings().settingsSearchSynonymsSupport), icon: .support, breadcrumbs: [], present: { context, _, present in
                confirm(for: context.window, information: strings().accountConfirmAskQuestion, thridTitle: strings().accountConfirmGoToFaq, successHandler: {  result in
                    switch result {
                    case .basic:
                        _ = showModalProgress(signal: context.engine.peers.supportPeerId(), for: context.window).start(next: {  peerId in
                            if let peerId = peerId {
                                present(.push, ChatController(context: context, chatLocation: .peer(peerId)))
                            }
                        })
                    case .thrid:
                        let _ = (cachedFaqInstantPage(context: context) |> deliverOnMainQueue).start(next: { resolvedUrl in
                            execute(inapp: resolvedUrl)
                        })
                    }
                })
            })
            allItems.append(support)
            
            let faq = SettingsSearchableItem(id: .faq(0), title: strings().accountSettingsFAQ, alternate: synonyms(strings().settingsSearchSynonymsFAQ), icon: .faq, breadcrumbs: [], present: { context, navigationController, present in
                let _ = (cachedFaqInstantPage(context: context) |> deliverOnMainQueue).start(next: { resolvedUrl in
                    execute(inapp: resolvedUrl)
                })
            })
            allItems.append(faq)
            
            return allItems
    }
}




