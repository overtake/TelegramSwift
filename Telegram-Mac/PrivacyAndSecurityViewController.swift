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
import SyncCore
import SwiftSignalKit
import Postbox


enum PrivacyAndSecurityEntryTag: ItemListItemTag {
    case accountTimeout
    case topPeers
    case cloudDraft
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
            return 13
        case .topPeers:
            return 19
        case .cloudDraft:
            return 22
        }
    }
}

private final class PrivacyAndSecurityControllerArguments {
    let context: AccountContext
    let openBlockedUsers: () -> Void
    let openLastSeenPrivacy: () -> Void
    let openGroupsPrivacy: () -> Void
    let openVoiceCallPrivacy: () -> Void
    let openProfilePhotoPrivacy: () -> Void
    let openForwardPrivacy: () -> Void
    let openPhoneNumberPrivacy: () -> Void
    let openPasscode: () -> Void
    let openTwoStepVerification: (TwoStepVeriticationAccessConfiguration?) -> Void
    let openActiveSessions: ([RecentAccountSession]?) -> Void
    let openWebAuthorizations: () -> Void
    let setupAccountAutoremove: () -> Void
    let openProxySettings:() ->Void
    let togglePeerSuggestions:(Bool)->Void
    let clearCloudDrafts: () -> Void
    let toggleSensitiveContent:(Bool)->Void
    init(context: AccountContext, openBlockedUsers: @escaping () -> Void, openLastSeenPrivacy: @escaping () -> Void, openGroupsPrivacy: @escaping () -> Void, openVoiceCallPrivacy: @escaping () -> Void, openProfilePhotoPrivacy: @escaping () -> Void, openForwardPrivacy: @escaping () -> Void, openPhoneNumberPrivacy: @escaping() -> Void, openPasscode: @escaping () -> Void, openTwoStepVerification: @escaping (TwoStepVeriticationAccessConfiguration?) -> Void, openActiveSessions: @escaping ([RecentAccountSession]?) -> Void, openWebAuthorizations: @escaping() -> Void, setupAccountAutoremove: @escaping () -> Void, openProxySettings:@escaping() ->Void, togglePeerSuggestions:@escaping(Bool)->Void, clearCloudDrafts: @escaping() -> Void, toggleSensitiveContent: @escaping(Bool)->Void) {
        self.context = context
        self.openBlockedUsers = openBlockedUsers
        self.openLastSeenPrivacy = openLastSeenPrivacy
        self.openGroupsPrivacy = openGroupsPrivacy
        self.openVoiceCallPrivacy = openVoiceCallPrivacy
        self.openPasscode = openPasscode
        self.openTwoStepVerification = openTwoStepVerification
        self.openActiveSessions = openActiveSessions
        self.openWebAuthorizations = openWebAuthorizations
        self.setupAccountAutoremove = setupAccountAutoremove
        self.openProxySettings = openProxySettings
        self.togglePeerSuggestions = togglePeerSuggestions
        self.clearCloudDrafts = clearCloudDrafts
        self.openProfilePhotoPrivacy = openProfilePhotoPrivacy
        self.openForwardPrivacy = openForwardPrivacy
        self.openPhoneNumberPrivacy = openPhoneNumberPrivacy
        self.toggleSensitiveContent = toggleSensitiveContent
    }
}


private enum PrivacyAndSecurityEntry: Comparable, Identifiable {
    case privacyHeader(sectionId:Int)
    case blockedPeers(sectionId:Int, Int?, viewType: GeneralViewType)
    case phoneNumberPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case lastSeenPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case groupPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case profilePhotoPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case forwardPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case voiceCallPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case securityHeader(sectionId:Int)
    case passcode(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case twoStepVerification(sectionId:Int, configuration: TwoStepVeriticationAccessConfiguration?, viewType: GeneralViewType)
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
    case sensitiveContentToggle(sectionId: Int, value: Bool?, viewType: GeneralViewType)
    case sensitiveContentDesc(sectionId: Int)
    case clearCloudDraftsHeader(sectionId: Int)
    case clearCloudDrafts(sectionId: Int, viewType: GeneralViewType)

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
        case let .securityHeader(sectionId):
            return sectionId
        case let .passcode(sectionId, _, _):
            return sectionId
        case let .twoStepVerification(sectionId, _, _):
            return sectionId
        case let .activeSessions(sectionId, _, _):
            return sectionId
        case let .webAuthorizationsHeader(sectionId):
            return sectionId
        case let .webAuthorizations(sectionId, _):
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
        case let .section(sectionId):
            return sectionId
        }
    }

    var stableId:Int {
        switch self {
        case .blockedPeers:
            return 0
        case .activeSessions:
            return 1
        case .passcode:
            return 2
        case .twoStepVerification:
            return 3
        case .privacyHeader:
            return 4
        case .phoneNumberPrivacy:
            return 5
        case .lastSeenPrivacy:
            return 6
        case .groupPrivacy:
            return 7
        case .voiceCallPrivacy:
            return 8
        case .forwardPrivacy:
            return 9
        case .profilePhotoPrivacy:
            return 10
        case .securityHeader:
            return 11
        case .accountHeader:
            return 12
        case .accountTimeout:
            return 13
        case .accountInfo:
            return 14
        case .webAuthorizationsHeader:
            return 15
        case .webAuthorizations:
            return 16
        case .proxyHeader:
            return 17
        case .proxySettings:
            return 18
        case .togglePeerSuggestions:
            return 19
        case .togglePeerSuggestionsDesc:
            return 20
        case .clearCloudDraftsHeader:
            return 21
        case .clearCloudDrafts:
            return 22
        case .sensitiveContentHeader:
            return 23
        case .sensitiveContentToggle:
            return 24
        case .sensitiveContentDesc:
            return 25
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
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsPrivacyHeader, viewType: .textTopItem)
        case let .blockedPeers(_, count, viewType):
            let text: String
            if let count = count, count > 0 {
                text = L10n.privacyAndSecurityBlockedUsers("\(count)")
            } else {
                text = ""
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsBlockedUsers, icon: theme.icons.privacySettings_blocked, type: .nextContext(text), viewType: viewType, action: {
                arguments.openBlockedUsers()
            })
        case let .phoneNumberPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsPhoneNumber, type: .nextContext(text), viewType: viewType, action: {
                arguments.openPhoneNumberPrivacy()
            })
        case let .lastSeenPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsLastSeen, type: .nextContext(text), viewType: viewType, action: {
                arguments.openLastSeenPrivacy()
            })
        case let .groupPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsGroups, type: .nextContext(text), viewType: viewType, action: {
                arguments.openGroupsPrivacy()
            })
        case let .profilePhotoPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsProfilePhoto, type: .nextContext(text), viewType: viewType, action: {
                arguments.openProfilePhotoPrivacy()
            })
        case let .forwardPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsForwards, type: .nextContext(text), viewType: viewType, action: {
                arguments.openForwardPrivacy()
            })
        case let .voiceCallPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsVoiceCalls, type: .nextContext(text), viewType: viewType, action: {
                arguments.openVoiceCallPrivacy()
            })
        case .securityHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsSecurityHeader, viewType: .textTopItem)
        case let .passcode(_, enabled, viewType):
            let desc = enabled ? L10n.privacyAndSecurityItemOn : L10n.privacyAndSecurityItemOff
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsPasscode, icon: theme.icons.privacySettings_passcode, type: .nextContext(desc), viewType: viewType, action: {
                arguments.openPasscode()
            })
        case let .twoStepVerification(_, configuration, viewType):
            let desc: String 
            if let configuration = configuration {
                switch configuration {
                case .set:
                    desc = L10n.privacyAndSecurityItemOn
                case .notSet:
                    desc = L10n.privacyAndSecurityItemOff
                }
            } else {
                desc = ""
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsTwoStepVerification, icon: theme.icons.privacySettings_twoStep, type: .nextContext(desc), viewType: viewType, action: {
                arguments.openTwoStepVerification(configuration)
            })
        case let .activeSessions(_, sessions, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsActiveSessions, icon: theme.icons.privacySettings_activeSessions, type: .nextContext(sessions != nil ? "\(sessions!.count)" : ""), viewType: viewType, action: {
                arguments.openActiveSessions(sessions)
            })
        case .webAuthorizationsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityWebAuthorizationHeader, viewType: .textTopItem)
        case let .webAuthorizations(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.telegramWebSessionsController, viewType: viewType, action: {
                arguments.openWebAuthorizations()
            })
        case .accountHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsDeleteAccountHeader, viewType: .textTopItem)
        case let .accountTimeout(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsDeleteAccount, type: .context(text), viewType: viewType, action: {
                arguments.setupAccountAutoremove()
            })
        case .accountInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsDeleteAccountDescription, viewType: .textBottomItem)
        case .proxyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsProxyHeader, viewType: .textTopItem)
        case let .proxySettings(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsUseProxy, type: .nextContext(text), viewType: viewType, action: {
                arguments.openProxySettings()
            })
        case let .togglePeerSuggestions(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.suggestFrequentContacts, type: .switchable(enabled), viewType: viewType, action: {
                if enabled {
                    confirm(for: mainWindow, information: L10n.suggestFrequentContactsAlert, successHandler: { _ in
                        arguments.togglePeerSuggestions(!enabled)
                    })
                } else {
                    arguments.togglePeerSuggestions(!enabled)
                }
            }, autoswitch: false)
        case .togglePeerSuggestionsDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.suggestFrequentContactsDesc, viewType: .textBottomItem)
        case .clearCloudDraftsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityClearCloudDraftsHeader, viewType: .textTopItem)
        case let .clearCloudDrafts(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacyAndSecurityClearCloudDrafts, type: .none, viewType: viewType, action: {
                arguments.clearCloudDrafts()
            })
        case .sensitiveContentHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecuritySensitiveHeader, viewType: .textTopItem)
        case let .sensitiveContentToggle(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacyAndSecuritySensitiveText, type: enabled != nil ? .switchable(enabled!) : .loading, viewType: viewType, action: {
                if let enabled = enabled {
                    arguments.toggleSensitiveContent(!enabled)
                }
            }, autoswitch: true)
        case .sensitiveContentDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecuritySensitiveDesc, viewType: .textBottomItem)
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
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
    case let .disableEveryone(enableFor):
        if enableFor.isEmpty {
            return L10n.privacySettingsControllerNobody
        } else {
            return L10n.privacySettingsLastSeenNobodyPlus("\(countForSelectivePeers(enableFor))")
        }
    case let .enableEveryone(disableFor):
        if disableFor.isEmpty {
            return L10n.privacySettingsControllerEverbody
        } else {
            return L10n.privacySettingsLastSeenEverybodyMinus("\(countForSelectivePeers(disableFor))")
        }
    case let .enableContacts(enableFor, disableFor):
        if !enableFor.isEmpty && !disableFor.isEmpty {
            return L10n.privacySettingsLastSeenContactsMinusPlus("\(countForSelectivePeers(enableFor))", "\(countForSelectivePeers(disableFor))")
        } else if !enableFor.isEmpty {
            return L10n.privacySettingsLastSeenContactsPlus("\(countForSelectivePeers(enableFor))")
        } else if !disableFor.isEmpty {
            return L10n.privacySettingsLastSeenContactsMinus("\(countForSelectivePeers(disableFor))")
        } else {
            return L10n.privacySettingsControllerMyContacts
        }
    }
}

private struct PrivacyAndSecurityControllerState: Equatable {
    let updatingAccountTimeoutValue: Int32?

    init() {
        self.updatingAccountTimeoutValue = nil
    }

    init(updatingAccountTimeoutValue: Int32?) {
        self.updatingAccountTimeoutValue = updatingAccountTimeoutValue
    }

    static func ==(lhs: PrivacyAndSecurityControllerState, rhs: PrivacyAndSecurityControllerState) -> Bool {
        if lhs.updatingAccountTimeoutValue != rhs.updatingAccountTimeoutValue {
            return false
        }

        return true
    }

    func withUpdatedUpdatingAccountTimeoutValue(_ updatingAccountTimeoutValue: Int32?) -> PrivacyAndSecurityControllerState {
        return PrivacyAndSecurityControllerState(updatingAccountTimeoutValue: updatingAccountTimeoutValue)
    }
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PrivacyAndSecurityEntry>], right: [AppearanceWrapperEntry<PrivacyAndSecurityEntry>], initialSize:NSSize, arguments:PrivacyAndSecurityControllerArguments) -> TableUpdateTransition {

    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }

    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private func privacyAndSecurityControllerEntries(state: PrivacyAndSecurityControllerState, contentConfiguration: ContentSettingsConfiguration?, privacySettings: AccountPrivacySettings?, webSessions: ([WebAuthorization], [PeerId : Peer])?, blockedState: BlockedPeersContextState, proxy: ProxySettings, recentPeers: RecentPeers, configuration: TwoStepVeriticationAccessConfiguration?, activeSessions: [RecentAccountSession]?, passcodeData: PostboxAccessChallengeData) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []

    var sectionId:Int = 1
    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    entries.append(.blockedPeers(sectionId: sectionId, blockedState.totalCount, viewType: .firstItem))
    entries.append(.activeSessions(sectionId: sectionId, activeSessions, viewType: .innerItem))
    
    let hasPasscode: Bool
    switch passcodeData {
    case .none:
        hasPasscode = false
    default:
        hasPasscode = true
    }
    
    entries.append(.passcode(sectionId: sectionId, enabled: hasPasscode, viewType: .innerItem))
    entries.append(.twoStepVerification(sectionId: sectionId, configuration: configuration, viewType: .lastItem))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.privacyHeader(sectionId: sectionId))
    if let privacySettings = privacySettings {
        entries.append(.phoneNumberPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.phoneNumber), viewType: .firstItem))
        entries.append(.lastSeenPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.presence), viewType: .innerItem))
        entries.append(.groupPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.groupInvitations), viewType: .innerItem))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.voiceCalls), viewType: .innerItem))
        entries.append(.profilePhotoPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.profilePhoto), viewType: .innerItem))
        entries.append(.forwardPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.forwards), viewType: .lastItem))
    } else {
        entries.append(.phoneNumberPrivacy(sectionId: sectionId, "", viewType: .firstItem))
        entries.append(.lastSeenPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.groupPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.profilePhotoPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.forwardPrivacy(sectionId: sectionId, "", viewType: .lastItem))
    }


    entries.append(.section(sectionId: sectionId))
    sectionId += 1

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

    if let webSessions = webSessions, !webSessions.0.isEmpty {
        entries.append(.webAuthorizationsHeader(sectionId: sectionId))
        entries.append(.webAuthorizations(sectionId: sectionId, viewType: .singleItem))
    }


    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    return entries
}





class PrivacyAndSecurityViewController: TableViewController {
    private let privacySettingsPromise = Promise<(AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?)>()


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        twoStepAccessConfiguration.set(twoStepVerificationConfiguration(account: context.account) |> map { TwoStepVeriticationAccessConfiguration(configuration: $0, password: nil)})
        activeSessions.set(requestRecentAccountSessions(account: context.account) |> map(Optional.init))
    }

    private let twoStepAccessConfiguration: Promise<TwoStepVeriticationAccessConfiguration?> = Promise(nil)
    private let activeSessions: Promise<[RecentAccountSession]?> = Promise(nil)

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
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .presence, current: info.presence, callSettings: nil, phoneDiscoveryEnabled: nil, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: updated, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
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
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .groupInvitations, current: info.groupInvitations, callSettings: nil, phoneDiscoveryEnabled: nil, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: updated, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
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
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .voiceCalls, current: info.voiceCalls, callSettings: info.voiceCallsP2P, phoneDiscoveryEnabled: nil, updated: { updated, p2pUpdated, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: updated, voiceCallsP2P: p2pUpdated ?? value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
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
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .profilePhoto, current: info.profilePhoto, phoneDiscoveryEnabled: nil, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: updated, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
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
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .forwards, current: info.forwards, phoneDiscoveryEnabled: nil, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: updated, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
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
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .phoneNumber, current: info.phoneNumber, phoneDiscoveryEnabled: info.phoneDiscoveryEnabled, updated: { updated, _, phoneDiscoveryEnabled in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: updated, phoneDiscoveryEnabled: phoneDiscoveryEnabled!, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
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

            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] _, sessions in
                pushControllerImpl(WebSessionsController(context, sessions, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { privacy, _ -> Signal<Void, NoError> in
                                privacySettingsPromise.set(.single((privacy, updated)))
                                return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }))
            }))

        }, setupAccountAutoremove: { [weak self] in

            if let strongSelf = self {

                let signal = privacySettingsPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue
                updateAccountTimeoutDisposable.set(signal.start(next: { [weak updateAccountTimeoutDisposable, weak strongSelf] privacySettingsValue, _ in
                    if let _ = privacySettingsValue, let strongSelf = strongSelf {

                        let timeoutAction: (Int32) -> Void = { timeout in
                            if let updateAccountTimeoutDisposable = updateAccountTimeoutDisposable {
                                updateState {
                                    return $0.withUpdatedUpdatingAccountTimeoutValue(timeout)
                                }
                                let applyTimeout: Signal<Void, NoError> = privacySettingsPromise.get()
                                    |> filter { $0.0 != nil }
                                    |> take(1)
                                    |> deliverOnMainQueue
                                    |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                        if let value = value {
                                            privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, accountRemovalTimeout: timeout), sessions)))
                                        }
                                        return .complete()
                                }
                                updateAccountTimeoutDisposable.set((updateAccountRemovalTimeout(account: context.account, timeout: timeout)
                                    |> then(applyTimeout)
                                    |> deliverOnMainQueue).start(completed: {
//                                        updateState {
//                                            return $0.withUpdatedUpdatingAccountTimeoutValue(nil)
//                                        }
                                    }))
                            }
                        }
                        let timeoutValues: [Int32] = [
                            1 * 30 * 24 * 60 * 60,
                            3 * 30 * 24 * 60 * 60,
                            180 * 24 * 60 * 60,
                            365 * 24 * 60 * 60
                        ]
                        var items: [SPopoverItem] = []

                        items.append(SPopoverItem(tr(L10n.timerMonthsCountable(1)), {
                            timeoutAction(timeoutValues[0])
                        }))
                        items.append(SPopoverItem(tr(L10n.timerMonthsCountable(3)), {
                            timeoutAction(timeoutValues[1])
                        }))
                        items.append(SPopoverItem(tr(L10n.timerMonthsCountable(6)), {
                            timeoutAction(timeoutValues[2])
                        }))
                        items.append(SPopoverItem(tr(L10n.timerYearsCountable(1)), {
                            timeoutAction(timeoutValues[3])
                        }))

                        if let index = strongSelf.genericView.index(hash: PrivacyAndSecurityEntry.accountTimeout(sectionId: 0, "", viewType: .singleItem).stableId) {
                            if let view = (strongSelf.genericView.viewNecessary(at: index) as? GeneralInteractedRowView)?.textView {
                                showPopover(for: view, with: SPopoverViewController(items: items))
                            }
                        }
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

                    showModal(with: ShareModalController(ShareLinkObject(context, link: message)), for: mainWindow)
                }, pushController: { controller in
                    pushControllerImpl(controller)
                })
                pushControllerImpl(controller)
            }
        }, togglePeerSuggestions: { enabled in
            _ = (updateRecentPeersEnabled(postbox: context.account.postbox, network: context.account.network, enabled: enabled) |> then(enabled ? managedUpdatedRecentPeers(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network) : Signal<Void, NoError>.complete())).start()
        }, clearCloudDrafts: {
            confirm(for: context.window, information: L10n.privacyAndSecurityConfirmClearCloudDrafts, successHandler: { _ in
                _ = showModalProgress(signal: clearCloudDraftsInteractively(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId), for: context.window).start()
            })
        }, toggleSensitiveContent: { value in
            _ = updateRemoteContentSettingsConfiguration(postbox: context.account.postbox, network: context.account.network, sensitiveContentEnabled: value).start()
        })


        let previous:Atomic<[AppearanceWrapperEntry<PrivacyAndSecurityEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize

        let contentConfiguration: Signal<ContentSettingsConfiguration?, NoError> = .single(nil) |> then(contentSettingsConfiguration(network: context.account.network) |> map(Optional.init))

        
        let signal = combineLatest(queue: .mainQueue(), statePromise.get(), contentConfiguration, appearanceSignal, settings, privacySettingsPromise.get(), combineLatest(queue: .mainQueue(), recentPeers(account: context.account), twoStepAccessConfiguration.get(), activeSessions.get(), context.sharedContext.accountManager.accessChallengeData()), context.blockedPeersContext.state)
        |> map { state, contentConfiguration, appearance, proxy, values, additional, blockedState -> TableUpdateTransition in
            let entries = privacyAndSecurityControllerEntries(state: state, contentConfiguration: contentConfiguration, privacySettings: values.0, webSessions: values.1, blockedState: blockedState, proxy: proxy, recentPeers: additional.0, configuration: additional.1, activeSessions: additional.2, passcodeData: additional.3.data).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
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
    init(_ context: AccountContext, initialSettings: (AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?), focusOnItemTag: PrivacyAndSecurityEntryTag? = nil) {
        self.focusOnItemTag = focusOnItemTag
        super.init(context)
        self.privacySettingsPromise.set(.single(initialSettings))
    }
}

