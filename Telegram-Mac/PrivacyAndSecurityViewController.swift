//
//  PrivacySettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 10/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox


struct AutoarchiveConfiguration : Equatable {
    let autoarchive_setting_available: Bool
    init(autoarchive_setting_available: Bool) {
        self.autoarchive_setting_available = autoarchive_setting_available
    }
    static func with(appConfiguration: AppConfiguration) -> AutoarchiveConfiguration {
        return AutoarchiveConfiguration(autoarchive_setting_available: appConfiguration.data?["autoarchive_setting_available"] as? Bool ?? false)
    }
}


enum PrivacyAndSecurityEntryTag: ItemListItemTag {
    case accountTimeout
    case topPeers
    case cloudDraft
    case autoArchive
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? PrivacyAndSecurityEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
    
    fileprivate var stableId: AnyHashable {
        switch self {
        case .accountTimeout:
            return PrivacyAndSecurityEntry.accountTimeout(sectionId: 0, "", viewType: .singleItem).stableId
        case .topPeers:
            return PrivacyAndSecurityEntry.togglePeerSuggestions(sectionId: 0, enabled: false, viewType: .singleItem).stableId
        case .cloudDraft:
            return PrivacyAndSecurityEntry.clearCloudDrafts(sectionId: 0, viewType: .singleItem).stableId
        case .autoArchive:
            return PrivacyAndSecurityEntry.autoArchiveToggle(sectionId: 0, value: false, viewType: .singleItem).stableId
        }
    }
}

private final class PrivacyAndSecurityControllerArguments {
    let context: AccountContext
    let openBlockedUsers: () -> Void
    let openLastSeenPrivacy: () -> Void
    let openGroupsPrivacy: () -> Void
    let openVoiceCallPrivacy: () -> Void
    let openBioPrivacy:()->Void
    let openProfilePhotoPrivacy: () -> Void
    let openForwardPrivacy: () -> Void
    let openPhoneNumberPrivacy: () -> Void
    let openVoicePrivacy: () -> Void
    let openMessagesPrivacy: () -> Void
    let openPasscode: () -> Void
    let openTwoStepVerification: (TwoStepVeriticationAccessConfiguration?) -> Void
    let openActiveSessions: ([RecentAccountSession]?) -> Void
    let openWebAuthorizations: () -> Void
    let setupAccountAutoremove: () -> Void
    let setupGlobalAutoremove: () -> Void
    let openProxySettings:() ->Void
    let togglePeerSuggestions:(Bool)->Void
    let clearCloudDrafts: () -> Void
    let toggleSensitiveContent:(Bool)->Void
    let toggleSecretChatWebPreview: (Bool)->Void
    let toggleAutoArchive: (Bool)->Void
    init(context: AccountContext, openBlockedUsers: @escaping () -> Void, openLastSeenPrivacy: @escaping () -> Void, openGroupsPrivacy: @escaping () -> Void, openVoiceCallPrivacy: @escaping () -> Void, openBioPrivacy: @escaping()->Void, openProfilePhotoPrivacy: @escaping () -> Void, openForwardPrivacy: @escaping () -> Void, openPhoneNumberPrivacy: @escaping() -> Void, openVoicePrivacy: @escaping() -> Void, openMessagesPrivacy: @escaping()->Void, openPasscode: @escaping () -> Void, openTwoStepVerification: @escaping (TwoStepVeriticationAccessConfiguration?) -> Void, openActiveSessions: @escaping ([RecentAccountSession]?) -> Void, openWebAuthorizations: @escaping() -> Void, setupAccountAutoremove: @escaping () -> Void, setupGlobalAutoremove: @escaping()->Void, openProxySettings:@escaping() ->Void, togglePeerSuggestions:@escaping(Bool)->Void, clearCloudDrafts: @escaping() -> Void, toggleSensitiveContent: @escaping(Bool)->Void, toggleSecretChatWebPreview: @escaping(Bool)->Void, toggleAutoArchive: @escaping(Bool)->Void) {
        self.context = context
        self.openBlockedUsers = openBlockedUsers
        self.openLastSeenPrivacy = openLastSeenPrivacy
        self.openGroupsPrivacy = openGroupsPrivacy
        self.openVoiceCallPrivacy = openVoiceCallPrivacy
        self.openBioPrivacy = openBioPrivacy
        self.openPasscode = openPasscode
        self.openTwoStepVerification = openTwoStepVerification
        self.openActiveSessions = openActiveSessions
        self.openWebAuthorizations = openWebAuthorizations
        self.setupAccountAutoremove = setupAccountAutoremove
        self.setupGlobalAutoremove = setupGlobalAutoremove
        self.openProxySettings = openProxySettings
        self.togglePeerSuggestions = togglePeerSuggestions
        self.clearCloudDrafts = clearCloudDrafts
        self.openProfilePhotoPrivacy = openProfilePhotoPrivacy
        self.openForwardPrivacy = openForwardPrivacy
        self.openPhoneNumberPrivacy = openPhoneNumberPrivacy
        self.openVoicePrivacy = openVoicePrivacy
        self.openMessagesPrivacy = openMessagesPrivacy
        self.toggleSensitiveContent = toggleSensitiveContent
        self.toggleSecretChatWebPreview = toggleSecretChatWebPreview
        self.toggleAutoArchive = toggleAutoArchive
    }
}


private enum PrivacyAndSecurityEntry: Comparable, Identifiable {
    case privacyHeader(sectionId:Int)
    case twoStepVerification(sectionId:Int, configuration: TwoStepVeriticationAccessConfiguration?, viewType: GeneralViewType)
    case passcode(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case blockedPeers(sectionId:Int, Int?, viewType: GeneralViewType)
    case phoneNumberPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case lastSeenPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case groupPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case profilePhotoPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case forwardPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case voiceCallPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case voiceMessagesPrivacy(sectionId: Int, String, Bool, viewType: GeneralViewType)
    case messagesPrivacy(sectionId: Int, String, Bool, viewType: GeneralViewType)
    case bioPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case securityHeader(sectionId:Int)
    case globalTimer(sectionId: Int, String, viewType: GeneralViewType)
    case globalTimerInfo(sectionId:Int)
    case activeSessions(sectionId:Int, [RecentAccountSession]?, viewType: GeneralViewType)
    case webAuthorizationsHeader(sectionId: Int)
    case webAuthorizations(sectionId:Int, viewType: GeneralViewType)
    case accountHeader(sectionId:Int)
    case accountTimeout(sectionId: Int, String, viewType: GeneralViewType)
    case accountInfo(sectionId:Int)
    case proxyHeader(sectionId:Int)
    case proxySettings(sectionId:Int, String, viewType: GeneralViewType)
    case togglePeerSuggestions(sectionId: Int, enabled: Bool, viewType: GeneralViewType)
    case togglePeerSuggestionsDesc(sectionId: Int)
    case sensitiveContentHeader(sectionId: Int)
    case autoArchiveToggle(sectionId: Int, value: Bool?, viewType: GeneralViewType)
    case autoArchiveDesc(sectionId: Int)
    case autoArchiveHeader(sectionId: Int)
    case sensitiveContentToggle(sectionId: Int, value: Bool?, viewType: GeneralViewType)
    case sensitiveContentDesc(sectionId: Int)
    case clearCloudDraftsHeader(sectionId: Int)
    case clearCloudDrafts(sectionId: Int, viewType: GeneralViewType)

    case secretChatWebPreviewHeader(sectionId: Int)
    case secretChatWebPreviewToggle(sectionId: Int, value: Bool?, viewType: GeneralViewType)
    case secretChatWebPreviewDesc(sectionId: Int)
    
    case section(sectionId:Int)

    var sectionId: Int {
        switch self {
        case let .privacyHeader(sectionId):
            return sectionId
        case let .blockedPeers(sectionId, _, _):
            return sectionId
        case let .phoneNumberPrivacy(sectionId, _, _):
            return sectionId
        case let .lastSeenPrivacy(sectionId, _, _):
            return sectionId
        case let .groupPrivacy(sectionId, _, _):
            return sectionId
        case let .profilePhotoPrivacy(sectionId, _, _):
            return sectionId
        case let .forwardPrivacy(sectionId, _, _):
            return sectionId
        case let .voiceCallPrivacy(sectionId, _, _):
            return sectionId
        case let .voiceMessagesPrivacy(sectionId, _, _, _):
            return sectionId
        case let .messagesPrivacy(sectionId, _, _, _):
            return sectionId
        case let .bioPrivacy(sectionId, _, _):
            return sectionId
        case let .securityHeader(sectionId):
            return sectionId
        case let .passcode(sectionId, _, _):
            return sectionId
        case let .twoStepVerification(sectionId, _, _):
            return sectionId
        case let .globalTimer(sectionId, _, _):
            return sectionId
        case let .globalTimerInfo(sectionId):
            return sectionId
        case let .activeSessions(sectionId, _, _):
            return sectionId
        case let .webAuthorizationsHeader(sectionId):
            return sectionId
        case let .webAuthorizations(sectionId, _):
            return sectionId
        case let .autoArchiveHeader(sectionId):
            return sectionId
        case let .autoArchiveToggle(sectionId, _, _):
            return sectionId
        case let .autoArchiveDesc(sectionId):
            return sectionId
        case let .accountHeader(sectionId):
            return sectionId
        case let .accountTimeout(sectionId, _, _):
            return sectionId
        case let .accountInfo(sectionId):
            return sectionId
        case let .togglePeerSuggestions(sectionId, _, _):
            return sectionId
        case let .togglePeerSuggestionsDesc(sectionId):
            return sectionId
        case let .clearCloudDraftsHeader(sectionId):
            return sectionId
        case let .clearCloudDrafts(sectionId, _):
            return sectionId
        case let .proxyHeader(sectionId):
            return sectionId
        case let .proxySettings(sectionId, _, _):
            return sectionId
        case let .sensitiveContentHeader(sectionId):
            return sectionId
        case let .sensitiveContentToggle(sectionId, _, _):
            return sectionId
        case let .sensitiveContentDesc(sectionId):
            return sectionId
        case let .secretChatWebPreviewHeader(sectionId):
            return sectionId
        case let .secretChatWebPreviewToggle(sectionId, _, _):
            return sectionId
        case let .secretChatWebPreviewDesc(sectionId):
            return sectionId
        case let .section(sectionId):
            return sectionId
        }
    }
    

    var stableId:Int {
        switch self {
        case .twoStepVerification:
            return 0
        case .passcode:
            return 1
        case .blockedPeers:
            return 2
        case .activeSessions:
            return 3
        case .globalTimer:
            return 4
        case .globalTimerInfo:
            return 5
        case .privacyHeader:
            return 6
        case .phoneNumberPrivacy:
            return 7
        case .lastSeenPrivacy:
            return 8
        case .groupPrivacy:
            return 9
        case .voiceCallPrivacy:
            return 10
        case .forwardPrivacy:
            return 11
        case .profilePhotoPrivacy:
            return 12
        case .voiceMessagesPrivacy:
            return 13
        case .messagesPrivacy:
            return 14
        case .bioPrivacy:
            return 15
        case .securityHeader:
            return 16
        case .autoArchiveHeader:
            return 17
        case .autoArchiveToggle:
            return 18
        case .autoArchiveDesc:
            return 19
        case .accountHeader:
            return 20
        case .accountTimeout:
            return 21
        case .accountInfo:
            return 22
        case .webAuthorizationsHeader:
            return 23
        case .webAuthorizations:
            return 24
        case .proxyHeader:
            return 25
        case .proxySettings:
            return 26
        case .togglePeerSuggestions:
            return 27
        case .togglePeerSuggestionsDesc:
            return 28
        case .clearCloudDraftsHeader:
            return 29
        case .clearCloudDrafts:
            return 30
        case .sensitiveContentHeader:
            return 31
        case .sensitiveContentToggle:
            return 32
        case .sensitiveContentDesc:
            return 33
        case .secretChatWebPreviewHeader:
            return 34
        case .secretChatWebPreviewToggle:
            return 35
        case .secretChatWebPreviewDesc:
            return 36
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }


    private var stableIndex:Int {
        switch self {
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        default:
            return (sectionId * 1000) + stableId
        }

    }

    static func <(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        return lhs.stableIndex < rhs.stableIndex
    }
    func item(_ arguments: PrivacyAndSecurityControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .privacyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsPrivacyHeader, viewType: .textTopItem)
        case let .blockedPeers(_, count, viewType):
            let text: String
            if let count = count, count > 0 {
                text = strings().privacyAndSecurityBlockedUsers("\(count)")
            } else {
                text = ""
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsBlockedUsers, icon: theme.icons.privacySettings_blocked, type: .nextContext(text), viewType: viewType, action: {
                arguments.openBlockedUsers()
            })
        case let .phoneNumberPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsPhoneNumber, type: .nextContext(text), viewType: viewType, action: {
                arguments.openPhoneNumberPrivacy()
            })
        case let .lastSeenPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsLastSeen, type: .nextContext(text), viewType: viewType, action: {
                arguments.openLastSeenPrivacy()
            })
        case let .groupPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsGroups, type: .nextContext(text), viewType: viewType, action: {
                arguments.openGroupsPrivacy()
            })
        case let .profilePhotoPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsProfilePhoto, type: .nextContext(text), viewType: viewType, action: {
                arguments.openProfilePhotoPrivacy()
            })
        case let .forwardPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsForwards, type: .nextContext(text), viewType: viewType, action: {
                arguments.openForwardPrivacy()
            })
        case let .voiceCallPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsVoiceCalls, type: .nextContext(text), viewType: viewType, action: {
                arguments.openVoiceCallPrivacy()
            })
        case let .voiceMessagesPrivacy(_, text, locked, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsVoiceMessages, type: .nextContext(text), viewType: viewType, action: arguments.openVoicePrivacy)
        case let .messagesPrivacy(_, text, locked, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsMessages, type: .nextContext(text), viewType: viewType, action: arguments.openMessagesPrivacy)
        case let .bioPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsBio, type: .nextContext(text), viewType: viewType, action: {
                arguments.openBioPrivacy()
            })
        case .securityHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsSecurityHeader, viewType: .textTopItem)
        case let .passcode(_, enabled, viewType):
            let desc = enabled ? strings().privacyAndSecurityItemOn : strings().privacyAndSecurityItemOff
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsPasscode, icon: theme.icons.privacySettings_passcode, type: .nextContext(desc), viewType: viewType, action: {
                arguments.openPasscode()
            })
        case let .twoStepVerification(_, configuration, viewType):
            let desc: String 
            if let configuration = configuration {
                switch configuration {
                case .set:
                    desc = strings().privacyAndSecurityItemOn
                case .notSet:
                    desc = strings().privacyAndSecurityItemOff
                }
            } else {
                desc = ""
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsTwoStepVerification, icon: theme.icons.privacySettings_twoStep, type: .nextContext(desc), viewType: viewType, action: {
                arguments.openTwoStepVerification(configuration)
            })
        case let .globalTimer(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsGlobalTimer, icon: theme.icons.privacy_settings_autodelete, type: .context(text), viewType: viewType, action: arguments.setupGlobalAutoremove)
        case .globalTimerInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsGlobalTimerInfo, viewType: .textBottomItem)
        case let .activeSessions(_, sessions, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsActiveSessions, icon: theme.icons.privacySettings_activeSessions, type: .nextContext(sessions != nil ? "\(sessions!.count)" : ""), viewType: viewType, action: {
                arguments.openActiveSessions(sessions)
            })
        case .webAuthorizationsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacyAndSecurityWebAuthorizationHeader, viewType: .textTopItem)
        case let .webAuthorizations(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().telegramWebSessionsController, viewType: viewType, action: {
                arguments.openWebAuthorizations()
            })
        case .accountHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsDeleteAccountHeader, viewType: .textTopItem)
        case let .accountTimeout(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsDeleteAccount, type: .context(text), viewType: viewType, action: {
                arguments.setupAccountAutoremove()
            })
        case .accountInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsDeleteAccountDescription, viewType: .textBottomItem)
        case .proxyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsProxyHeader, viewType: .textTopItem)
        case let .proxySettings(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsUseProxy, type: .nextContext(text), viewType: viewType, action: {
                arguments.openProxySettings()
            })
        case let .togglePeerSuggestions(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().suggestFrequentContacts, type: .switchable(enabled), viewType: viewType, action: {
                if enabled {
                    verifyAlert_button(for: arguments.context.window, information: strings().suggestFrequentContactsAlert, successHandler: { _ in
                        arguments.togglePeerSuggestions(!enabled)
                    })
                } else {
                    arguments.togglePeerSuggestions(!enabled)
                }
            }, autoswitch: false)
        case .togglePeerSuggestionsDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().suggestFrequentContactsDesc, viewType: .textBottomItem)
        case .clearCloudDraftsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacyAndSecurityClearCloudDraftsHeader, viewType: .textTopItem)
        case let .clearCloudDrafts(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacyAndSecurityClearCloudDrafts, type: .none, viewType: viewType, action: {
                arguments.clearCloudDrafts()
            })
        case .autoArchiveHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacyAndSecurityAutoArchiveHeader, viewType: .textTopItem)
        case let .autoArchiveToggle(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacyAndSecurityAutoArchiveText, type: enabled != nil ? .switchable(enabled!) : .loading, viewType: viewType, action: {
                if let enabled = enabled {
                    arguments.toggleAutoArchive(!enabled)
                } else {
                    arguments.toggleAutoArchive(true)
                }
            }, autoswitch: true)
        case .autoArchiveDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacyAndSecurityAutoArchiveDesc, viewType: .textBottomItem)
        case .sensitiveContentHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacyAndSecuritySensitiveHeader, viewType: .textTopItem)
        case let .sensitiveContentToggle(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacyAndSecuritySensitiveText, type: enabled != nil ? .switchable(enabled!) : .loading, viewType: viewType, action: {
                if let enabled = enabled {
                    arguments.toggleSensitiveContent(!enabled)
                }
            }, autoswitch: true)
        case .sensitiveContentDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacyAndSecuritySensitiveDesc, viewType: .textBottomItem)
        case .secretChatWebPreviewHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacyAndSecuritySecretChatWebPreviewHeader, viewType: .textTopItem)
        case let .secretChatWebPreviewToggle(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacyAndSecuritySecretChatWebPreviewText, type: enabled != nil ? .switchable(enabled!) : .loading, viewType: viewType, action: {
                if let enabled = enabled {
                    arguments.toggleSecretChatWebPreview(!enabled)
                }
            }, autoswitch: true)
        case .secretChatWebPreviewDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacyAndSecuritySecretChatWebPreviewDesc, viewType: .textBottomItem)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        }
    }
}

func countForSelectivePeers(_ peers: [PeerId: SelectivePrivacyPeer]) -> Int {
    var result = 0
    for (_, peer) in peers {
        result += peer.userCount
    }
    return result
}


private func stringForSelectiveSettings(settings: SelectivePrivacySettings) -> String {
    switch settings {
    case let .disableEveryone(enableFor, disableFor):
        if enableFor.isEmpty {
            return strings().privacySettingsControllerNobody
        } else {
            return strings().privacySettingsLastSeenNobodyPlus("\(countForSelectivePeers(enableFor))")
        }
    case let .enableEveryone(disableFor):
        if disableFor.isEmpty {
            return strings().privacySettingsControllerEverbody
        } else {
            return strings().privacySettingsLastSeenEverybodyMinus("\(countForSelectivePeers(disableFor))")
        }
    case let .enableContacts(enableFor, disableFor):
        if !enableFor.isEmpty && !disableFor.isEmpty {
            return strings().privacySettingsLastSeenContactsMinusPlus("\(countForSelectivePeers(disableFor))", "\(countForSelectivePeers(enableFor))")
        } else if !enableFor.isEmpty {
            return strings().privacySettingsLastSeenContactsPlus("\(countForSelectivePeers(enableFor))")
        } else if !disableFor.isEmpty {
            return strings().privacySettingsLastSeenContactsMinus("\(countForSelectivePeers(disableFor))")
        } else {
            return strings().privacySettingsControllerMyContacts
        }
    }
}

private struct PrivacyAndSecurityControllerState: Equatable {
    var updatingAccountTimeoutValue: Int32?
    var updatingGlobalTimeoutValue: Int32?
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PrivacyAndSecurityEntry>], right: [AppearanceWrapperEntry<PrivacyAndSecurityEntry>], initialSize:NSSize, arguments:PrivacyAndSecurityControllerArguments) -> TableUpdateTransition {

    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }

    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private func privacyAndSecurityControllerEntries(state: PrivacyAndSecurityControllerState, contentConfiguration: ContentSettingsConfiguration?, privacySettings: AccountPrivacySettings?, webSessions: WebSessionsContextState, blockedState: BlockedPeersContextState, proxy: ProxySettings, recentPeers: RecentPeers, configuration: TwoStepVeriticationAccessConfiguration?, activeSessions: ActiveSessionsContextState, passcodeData: PostboxAccessChallengeData, context: AccountContext) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []

    var sectionId:Int = 1
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    let hasPasscode: Bool
    switch passcodeData {
    case .none:
        hasPasscode = false
    default:
        hasPasscode = context.sharedContext.appEncryptionValue.hasPasscode()
    }
    entries.append(.twoStepVerification(sectionId: sectionId, configuration: configuration, viewType: .firstItem))
    entries.append(.passcode(sectionId: sectionId, enabled: hasPasscode, viewType: .innerItem))


    entries.append(.blockedPeers(sectionId: sectionId, blockedState.totalCount, viewType: .innerItem))
   // entries.append(.activeSessions(sectionId: sectionId, activeSessions, viewType: .innerItem))
    
    
    if let privacySettings = privacySettings {
        let value: Int32
        if let updatingAccountTimeoutValue = state.updatingGlobalTimeoutValue {
            value = updatingAccountTimeoutValue
        } else {
            value = privacySettings.messageAutoremoveTimeout ?? 0
        }
        if value != 0 {
            entries.append(.globalTimer(sectionId: sectionId, timeIntervalString(Int(value)), viewType: .lastItem))
        } else {
            entries.append(.globalTimer(sectionId: sectionId, strings().privacySettingsGlobalTimerNever, viewType: .lastItem))
        }

    } else {
        entries.append(.globalTimer(sectionId: sectionId, "", viewType: .lastItem))
    }
    entries.append(.globalTimerInfo(sectionId: sectionId))
    


    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.privacyHeader(sectionId: sectionId))
    if let privacySettings = privacySettings {
        entries.append(.phoneNumberPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.phoneNumber), viewType: .firstItem))
        entries.append(.lastSeenPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.presence), viewType: .innerItem))
        entries.append(.groupPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.groupInvitations), viewType: .innerItem))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.voiceCalls), viewType: .innerItem))
        entries.append(.profilePhotoPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.profilePhoto), viewType: .innerItem))
        entries.append(.forwardPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.forwards), viewType: .innerItem))
        entries.append(.voiceMessagesPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.voiceMessages), !context.isPremium, viewType: .innerItem))
        entries.append(.messagesPrivacy(sectionId: sectionId, privacySettings.globalSettings.nonContactChatsRequirePremium ? strings().privacySettingsMessagesMyContacts : strings().privacySettingsMessagesAll, false, viewType: .innerItem))

        entries.append(.bioPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.bio), viewType: .lastItem))

        
    } else {
        entries.append(.phoneNumberPrivacy(sectionId: sectionId, "", viewType: .firstItem))
        entries.append(.lastSeenPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.groupPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.profilePhotoPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.forwardPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.voiceMessagesPrivacy(sectionId: sectionId, "", !context.isPremium, viewType: .lastItem))
    }


    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
//    
//    let autoarchiveConfiguration = AutoarchiveConfiguration.with(appConfiguration: context.appConfiguration)
//
//    
//    if autoarchiveConfiguration.autoarchive_setting_available {
//        entries.append(.autoArchiveHeader(sectionId: sectionId))
//        entries.append(.autoArchiveToggle(sectionId: sectionId, value: privacySettings?.globalSettings.automaticallyArchiveAndMuteNonContacts, viewType: .singleItem))
//        entries.append(.autoArchiveDesc(sectionId: sectionId))
//        
//        entries.append(.section(sectionId: sectionId))
//        sectionId += 1
//    }

    entries.append(.accountHeader(sectionId: sectionId))


    if let privacySettings = privacySettings {
        let value: Int32
        if let updatingAccountTimeoutValue = state.updatingAccountTimeoutValue {
            value = updatingAccountTimeoutValue
        } else {
            value = privacySettings.accountRemovalTimeout
        }
        entries.append(.accountTimeout(sectionId: sectionId, timeIntervalString(Int(value)), viewType: .singleItem))

    } else {
        entries.append(.accountTimeout(sectionId: sectionId, "", viewType: .singleItem))
    }
    entries.append(.accountInfo(sectionId: sectionId))

    

    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    if let contentConfiguration = contentConfiguration, contentConfiguration.canAdjustSensitiveContent {
        #if !APP_STORE
        entries.append(.sensitiveContentHeader(sectionId: sectionId))
        entries.append(.sensitiveContentToggle(sectionId: sectionId, value: contentConfiguration.sensitiveContentEnabled, viewType: .singleItem))
        entries.append(.sensitiveContentDesc(sectionId: sectionId))
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        #endif
    }
    

    let enabled: Bool
    switch recentPeers {
    case .disabled:
        enabled = false
    case .peers:
        enabled = true
    }

    entries.append(.togglePeerSuggestions(sectionId: sectionId, enabled: enabled, viewType: .singleItem))
    entries.append(.togglePeerSuggestionsDesc(sectionId: sectionId))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    entries.append(.clearCloudDraftsHeader(sectionId: sectionId))
    entries.append(.clearCloudDrafts(sectionId: sectionId, viewType: .singleItem))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    

    if !webSessions.sessions.isEmpty {
        entries.append(.webAuthorizationsHeader(sectionId: sectionId))
        entries.append(.webAuthorizations(sectionId: sectionId, viewType: .singleItem))
        
        if FastSettings.isSecretChatWebPreviewAvailable(for: context.account.id.int64) != nil {
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
        }
    }
    
    if let value = FastSettings.isSecretChatWebPreviewAvailable(for: context.account.id.int64) {
        entries.append(.secretChatWebPreviewHeader(sectionId: sectionId))
        entries.append(.secretChatWebPreviewToggle(sectionId: sectionId, value: value, viewType: .singleItem))
        entries.append(.secretChatWebPreviewDesc(sectionId: sectionId))
    }

    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    return entries
}





class PrivacyAndSecurityViewController: TableViewController {
    private let privacySettingsPromise = Promise<AccountPrivacySettings?>()


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    private let twoStepAccessConfiguration: Promise<TwoStepVeriticationAccessConfiguration?> = Promise(nil)

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        twoStepAccessConfiguration.set(context.engine.auth.twoStepVerificationConfiguration() |> map { .init(configuration: $0, password: nil) })
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        
        let statePromise = ValuePromise(PrivacyAndSecurityControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: PrivacyAndSecurityControllerState())
        let updateState: ((PrivacyAndSecurityControllerState) -> PrivacyAndSecurityControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }

        let actionsDisposable = DisposableSet()
        let context = self.context

        let pushControllerImpl: (ViewController) -> Void = { [weak self] c in
            self?.navigationController?.push(c)
        }


        let settings:Signal<ProxySettings, NoError> = proxySettings(accountManager: context.sharedContext.accountManager)

        let currentInfoDisposable = MetaDisposable()
        actionsDisposable.add(currentInfoDisposable)

        let updateAccountTimeoutDisposable = MetaDisposable()
        actionsDisposable.add(updateAccountTimeoutDisposable)

        let privacySettingsPromise = self.privacySettingsPromise

        let arguments = PrivacyAndSecurityControllerArguments(context: context, openBlockedUsers: { [weak self] in
            if let context = self?.context {
                pushControllerImpl(BlockedPeersViewController(context))
            }
        }, openLastSeenPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .presence, current: info.presence, callSettings: nil, phoneDiscoveryEnabled: nil, globalSettings: info.globalSettings, updated: { updated, _, _, globalSettings in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: updated, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, globalSettings: globalSettings ?? value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openGroupsPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .groupInvitations, current: info.groupInvitations, callSettings: nil, phoneDiscoveryEnabled: nil, updated: { updated, _, _, globalSettings in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: updated, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, globalSettings: globalSettings ?? value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openVoiceCallPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .voiceCalls, current: info.voiceCalls, callSettings: info.voiceCallsP2P, phoneDiscoveryEnabled: nil, updated: { updated, p2pUpdated, _, globalSettings in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: updated, voiceCallsP2P: p2pUpdated ?? value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, globalSettings: globalSettings ?? value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openBioPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .bio, current: info.bio, callSettings: nil, phoneDiscoveryEnabled: nil, updated: { updated, p2pUpdated, _, globalSettings in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: p2pUpdated ?? value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: updated, globalSettings: globalSettings ?? value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openProfilePhotoPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .profilePhoto, current: info.profilePhoto, phoneDiscoveryEnabled: nil, updated: { updated, _, _, globalSettings in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: updated, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, globalSettings: globalSettings ?? value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openForwardPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .forwards, current: info.forwards, phoneDiscoveryEnabled: nil, updated: { updated, _, _, globalSettings in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: updated, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, globalSettings: globalSettings ?? value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openPhoneNumberPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .phoneNumber, current: info.phoneNumber, phoneDiscoveryEnabled: info.phoneDiscoveryEnabled, updated: { updated, _, phoneDiscoveryEnabled, globalSettings in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: updated, phoneDiscoveryEnabled: phoneDiscoveryEnabled!, voiceMessages: value.voiceMessages, bio: value.bio, globalSettings: globalSettings ?? value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openVoicePrivacy: {
            
//            if !context.isPremium {
//                showModalText(for: context.window, text: strings().privacySettingsVoicePremiumError, button: strings().alertLearnMore, callback: { _ in
//                    showModal(with: PremiumBoardingController(context: context), for: context.window)
//                })
//                return
//            }
//            
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .voiceMessages, current: info.voiceMessages, callSettings: info.voiceCallsP2P, phoneDiscoveryEnabled: nil, updated: { updated, p2pUpdated, _, globalSettings in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: p2pUpdated ?? value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: updated, bio: value.bio, globalSettings: globalSettings ?? value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openMessagesPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { info in
                if let info = info {
                    pushControllerImpl(MessagesPrivacyController(context: context, globalSettings: info.globalSettings, updated: { updated in
                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: info.presence, groupInvitations: info.groupInvitations, voiceCalls: info.voiceCalls, voiceCallsP2P: info.voiceCallsP2P, profilePhoto: info.profilePhoto, forwards: info.forwards, phoneNumber: info.phoneNumber, phoneDiscoveryEnabled: info.phoneDiscoveryEnabled, voiceMessages: info.voiceMessages, bio: info.bio, globalSettings: updated, accountRemovalTimeout: info.accountRemovalTimeout, messageAutoremoveTimeout: info.messageAutoremoveTimeout)))
                    }))
                }
            }))
        }, openPasscode: { [weak self] in
            if let context = self?.context {
                self?.navigationController?.push(PasscodeSettingsViewController(context))
            }
        }, openTwoStepVerification: { [weak self] configuration in
            if let context = self?.context, let `self` = self {
                self.navigationController?.push(twoStepVerificationUnlockController(context: context, mode: .access(configuration), presentController: { [weak self] controller, isRoot, animated in
                    guard let `self` = self, let navigation = self.navigationController else {return}
                    if isRoot {
                        navigation.removeUntil(PrivacyAndSecurityViewController.self)
                    }

                    if !animated {
                        navigation.stackInsert(controller, at: navigation.stackCount)
                    } else {
                        navigation.push(controller)
                    }
                }))
            }
        }, openActiveSessions: { [weak self] sessions in
            if let context = self?.context {
                self?.navigationController?.push(RecentSessionsController(context))
            }
        }, openWebAuthorizations: {
            pushControllerImpl(WebSessionsController(context))
        }, setupAccountAutoremove: { [weak self] in

            if let strongSelf = self {
                let signal = privacySettingsPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue
                updateAccountTimeoutDisposable.set(signal.start(next: { [weak updateAccountTimeoutDisposable, weak strongSelf] privacySettingsValue in
                    if let _ = privacySettingsValue, let strongSelf = strongSelf {

                        let timeoutAction: (Int32) -> Void = { timeout in
                            if let updateAccountTimeoutDisposable = updateAccountTimeoutDisposable {
                                updateState { current in
                                    var current = current
                                    current.updatingAccountTimeoutValue = timeout
                                    return current
                                }
                                let applyTimeout: Signal<Void, NoError> = privacySettingsPromise.get()
                                    |> filter { $0 != nil }
                                    |> take(1)
                                    |> deliverOnMainQueue
                                    |> mapToSignal { value -> Signal<Void, NoError> in
                                        if let value = value {
                                            privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, globalSettings: value.globalSettings, accountRemovalTimeout: timeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                                        }
                                        return .complete()
                                }
                                updateAccountTimeoutDisposable.set((context.engine.privacy.updateAccountRemovalTimeout(timeout: timeout)
                                    |> then(applyTimeout)
                                    |> deliverOnMainQueue).start())
                            }
                        }
                        let timeoutValues: [Int32] = [
                            1 * 30 * 24 * 60 * 60,
                            3 * 30 * 24 * 60 * 60,
                            180 * 24 * 60 * 60,
                            365 * 24 * 60 * 60
                        ]
                        var items: [ContextMenuItem] = []

                        items.append(ContextMenuItem(strings().timerMonthsCountable(1), handler: {
                            timeoutAction(timeoutValues[0])
                        }))
                        items.append(ContextMenuItem(strings().timerMonthsCountable(3), handler: {
                            timeoutAction(timeoutValues[1])
                        }))
                        items.append(ContextMenuItem(strings().timerMonthsCountable(6), handler: {
                            timeoutAction(timeoutValues[2])
                        }))
                        items.append(ContextMenuItem(strings().timerYearsCountable(1), handler: {
                            timeoutAction(timeoutValues[3])
                        }))

                        let stableId = PrivacyAndSecurityEntry.accountTimeout(sectionId: 0, "", viewType: .singleItem).stableId
                        
                        if let index = strongSelf.genericView.index(hash: stableId) {
                            if let view = (strongSelf.genericView.viewNecessary(at: index) as? GeneralInteractedRowView)?.textView {
                                if let event = NSApp.currentEvent {
                                    let menu = ContextMenu()
                                    for item in items {
                                        menu.addItem(item)
                                    }
                                    let value = AppMenu(menu: menu)
                                    value.show(event: event, view: view)
                                }
                            }
                        }
                    }
                }))
            }
        }, setupGlobalAutoremove: { [weak self] in
            if let strongSelf = self {
                let signal = privacySettingsPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue
                updateAccountTimeoutDisposable.set(signal.start(next: { [weak updateAccountTimeoutDisposable, weak strongSelf] privacySettingsValue in
                    if let value = privacySettingsValue, let strongSelf = strongSelf {

                        let timeoutAction: (Int32, Bool) -> Void = { timeout, save in
                            if let updateAccountTimeoutDisposable = updateAccountTimeoutDisposable {
                                updateState { current in
                                    var current = current
                                    current.updatingGlobalTimeoutValue = timeout
                                    return current
                                }
                                let applyTimeout: Signal<Void, NoError> = privacySettingsPromise.get()
                                    |> filter { $0 != nil }
                                    |> take(1)
                                    |> deliverOnMainQueue
                                    |> mapToSignal { value -> Signal<Void, NoError> in
                                        if let value = value {
                                            privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, globalSettings: value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: timeout)))
                                        }
                                        return .complete()
                                }
                                updateAccountTimeoutDisposable.set((context.engine.privacy.updateGlobalMessageRemovalTimeout(timeout: timeout == 0 ? nil : timeout)
                                    |> then(applyTimeout)
                                    |> deliverOnMainQueue).start())
                            }
                        }
                        strongSelf.navigationController?.push(GlobalAutoremoveMessagesController(context: context, privacy: privacySettingsValue, updated: timeoutAction))
                    }
                }))
            }
            
        }, openProxySettings: { [weak self] in
            if let context = self?.context {

                let controller = proxyListController(accountManager: context.sharedContext.accountManager, network: context.account.network, share: { servers in
                    var message: String = ""
                    for server in servers {
                        message += server.link + "\n\n"
                    }
                    message = message.trimmed

                    showModal(with: ShareModalController(ShareLinkObject(context, link: message)), for: context.window)
                }, pushController: { controller in
                    pushControllerImpl(controller)
                })
                pushControllerImpl(controller)
            }
        }, togglePeerSuggestions: { enabled in
            _ = (context.engine.peers.updateRecentPeersEnabled(enabled: enabled) |> then(enabled ? context.engine.peers.managedUpdatedRecentPeers() : Signal<Void, NoError>.complete())).start()
        }, clearCloudDrafts: {
            verifyAlert_button(for: context.window, information: strings().privacyAndSecurityConfirmClearCloudDrafts, successHandler: { _ in
                _ = showModalProgress(signal: context.engine.messages.clearCloudDraftsInteractively(), for: context.window).start()
            })
        }, toggleSensitiveContent: { value in
            _ = updateRemoteContentSettingsConfiguration(postbox: context.account.postbox, network: context.account.network, sensitiveContentEnabled: value).start()
        }, toggleSecretChatWebPreview: { value in
            FastSettings.setSecretChatWebPreviewAvailable(for: context.account.id.int64, value: value)
        }, toggleAutoArchive: { value in
            _ = showModalProgress(signal: context.engine.privacy.updateAccountAutoArchiveChats(value: value), for: context.window).start()
        })


        let previous:Atomic<[AppearanceWrapperEntry<PrivacyAndSecurityEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize

        let contentConfiguration: Signal<ContentSettingsConfiguration?, NoError> = .single(nil) |> then(contentSettingsConfiguration(network: context.account.network) |> map(Optional.init))

        
        let signal = combineLatest(queue: .mainQueue(), statePromise.get(), contentConfiguration, appearanceSignal, settings, privacySettingsPromise.get(), context.webSessions.state, combineLatest(queue: .mainQueue(), context.engine.peers.recentPeers(), twoStepAccessConfiguration.get(), context.activeSessionsContext.state, context.sharedContext.accountManager.accessChallengeData()), context.blockedPeersContext.state)
        |> map { state, contentConfiguration, appearance, proxy, privacySettings, webSessions, additional, blockedState -> TableUpdateTransition in
            let entries = privacyAndSecurityControllerEntries(state: state, contentConfiguration: contentConfiguration, privacySettings: privacySettings, webSessions: webSessions, blockedState: blockedState, proxy: proxy, recentPeers: additional.0, configuration: additional.1, activeSessions: additional.2, passcodeData: additional.3.data, context: context).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify {$0}, arguments: arguments)
        } |> afterDisposed {
            actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
            if let focusOnItemTag = self?.focusOnItemTag {
                self?.genericView.scroll(to: .center(id: focusOnItemTag.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets())
                self?.focusOnItemTag = nil
            }
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    private var focusOnItemTag: PrivacyAndSecurityEntryTag?
    private let disposable = MetaDisposable()
    init(_ context: AccountContext, initialSettings: AccountPrivacySettings?, focusOnItemTag: PrivacyAndSecurityEntryTag? = nil, twoStepVerificationConfiguration: TwoStepVeriticationAccessConfiguration?) {
        self.focusOnItemTag = focusOnItemTag
        self.twoStepAccessConfiguration.set(.single(twoStepVerificationConfiguration))
        super.init(context)
        
        let thenSignal:Signal<AccountPrivacySettings?, NoError> = context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)
        
        self.privacySettingsPromise.set(.single(initialSettings) |> then(thenSignal))
    }
}

