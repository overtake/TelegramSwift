//
//  PrivacySettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 10/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

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
    init(context: AccountContext, openBlockedUsers: @escaping () -> Void, openLastSeenPrivacy: @escaping () -> Void, openGroupsPrivacy: @escaping () -> Void, openVoiceCallPrivacy: @escaping () -> Void, openProfilePhotoPrivacy: @escaping () -> Void, openForwardPrivacy: @escaping () -> Void, openPhoneNumberPrivacy: @escaping() -> Void, openPasscode: @escaping () -> Void, openTwoStepVerification: @escaping (TwoStepVeriticationAccessConfiguration?) -> Void, openActiveSessions: @escaping ([RecentAccountSession]?) -> Void, openWebAuthorizations: @escaping() -> Void, setupAccountAutoremove: @escaping () -> Void, openProxySettings:@escaping() ->Void, togglePeerSuggestions:@escaping(Bool)->Void, clearCloudDrafts: @escaping() -> Void) {
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
    }
}


private enum PrivacyAndSecurityEntry: Comparable, Identifiable {
    case privacyHeader(sectionId:Int)
    case blockedPeers(sectionId:Int, Int?)
    case phoneNumberPrivacy(sectionId: Int, String)
    case lastSeenPrivacy(sectionId: Int, String)
    case groupPrivacy(sectionId: Int, String)
    case profilePhotoPrivacy(sectionId: Int, String)
    case forwardPrivacy(sectionId: Int, String)
    case voiceCallPrivacy(sectionId: Int, String)
    case securityHeader(sectionId:Int)
    case passcode(sectionId:Int, enabled: Bool)
    case twoStepVerification(sectionId:Int, configuration: TwoStepVeriticationAccessConfiguration?)
    case activeSessions(sectionId:Int, [RecentAccountSession]?)
    case webAuthorizationsHeader(sectionId: Int)
    case webAuthorizations(sectionId:Int)
    case accountHeader(sectionId:Int)
    case accountTimeout(sectionId: Int, String)
    case accountInfo(sectionId:Int)
    case proxyHeader(sectionId:Int)
    case proxySettings(sectionId:Int, String)
    case togglePeerSuggestions(sectionId: Int, enabled: Bool)
    case togglePeerSuggestionsDesc(sectionId: Int)

    case clearCloudDraftsHeader(sectionId: Int)
    case clearCloudDrafts(sectionId: Int)

    case section(sectionId:Int)

    var sectionId: Int {
        switch self {
        case let .privacyHeader(sectionId):
            return sectionId
        case let .blockedPeers(sectionId, _):
            return sectionId
        case let .phoneNumberPrivacy(sectionId, _):
            return sectionId
        case let .lastSeenPrivacy(sectionId, _):
            return sectionId
        case let .groupPrivacy(sectionId, _):
            return sectionId
        case let .profilePhotoPrivacy(sectionId, _):
            return sectionId
        case let .forwardPrivacy(sectionId, _):
            return sectionId
        case let .voiceCallPrivacy(sectionId, _):
            return sectionId
        case let .securityHeader(sectionId):
            return sectionId
        case let .passcode(sectionId, _):
            return sectionId
        case let .twoStepVerification(sectionId, _):
            return sectionId
        case let .activeSessions(sectionId, _):
            return sectionId
        case let .webAuthorizationsHeader(sectionId):
            return sectionId
        case let .webAuthorizations(sectionId):
            return sectionId
        case let .accountHeader(sectionId):
            return sectionId
        case let .accountTimeout(sectionId, _):
            return sectionId
        case let .accountInfo(sectionId):
            return sectionId
        case let .proxySettings(sectionId, _):
            return sectionId
        case let .togglePeerSuggestions(sectionId, _):
            return sectionId
        case let .togglePeerSuggestionsDesc(sectionId):
            return sectionId
        case let .clearCloudDraftsHeader(sectionId):
            return sectionId
        case let .clearCloudDrafts(sectionId):
            return sectionId
        case let .proxyHeader(sectionId):
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

//    static func ==(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
//        switch lhs {
//        case .privacyHeader, .securityHeader, .webAuthorizationsHeader, .webAuthorizations, .accountHeader, .accountInfo, .proxyHeader, .section:
//            return lhs.stableId == rhs.stableId && lhs.sectionId == rhs.sectionId
//        case let .passcode(sectionId, enabled):
//            if case .passcode(sectionId, enabled) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .lastSeenPrivacy(sectionId, text):
//            if case .lastSeenPrivacy(sectionId, text) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .twoStepVerification(sectionId, configuration):
//            if case .twoStepVerification(sectionId, configuration) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .activeSessions(sectionId, sessions):
//            if case .activeSessions(sectionId, sessions) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .blockedPeers(sectionId, count):
//            if case .blockedPeers(sectionId, count) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .phoneNumberPrivacy(sectionId, text):
//            if case .phoneNumberPrivacy(sectionId, text) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .groupPrivacy(sectionId, text):
//            if case .groupPrivacy(sectionId, text) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .proxySettings(sectionId, text):
//            if case .proxySettings(sectionId, text) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .togglePeerSuggestions(sectionId, enabled):
//            if case .togglePeerSuggestions(sectionId, enabled) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .togglePeerSuggestionsDesc(sectionId):
//            if case .togglePeerSuggestionsDesc(sectionId) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .clearCloudDraftsHeader(sectionId):
//            if case .clearCloudDraftsHeader(sectionId) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .clearCloudDrafts(sectionId):
//            if case .clearCloudDrafts(sectionId) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .profilePhotoPrivacy(sectionId, text):
//            if case .profilePhotoPrivacy(sectionId, text) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .forwardPrivacy(sectionId, text):
//            if case .forwardPrivacy(sectionId, text) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .voiceCallPrivacy(sectionId, text):
//            if case .voiceCallPrivacy(sectionId, text) = rhs {
//                return true
//            } else {
//                return false
//            }
//        case let .accountTimeout(sectionId, text):
//            if case .accountTimeout(sectionId, text) = rhs {
//                return true
//            } else {
//                return false
//            }
//        }
//    }

    static func <(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        return lhs.stableIndex < rhs.stableIndex
    }
    func item(_ arguments: PrivacyAndSecurityControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .privacyHeader:

            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsPrivacyHeader, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .blockedPeers(_, count):
            let text: String
            if let count = count, count > 0 {
                text = L10n.privacyAndSecurityBlockedUsers("\(count)")
            } else {
                text = ""
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsBlockedUsers, icon: theme.icons.privacySettings_blocked, type: .nextContext(text), action: {
                arguments.openBlockedUsers()
            })
        case let .phoneNumberPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsPhoneNumber, type: .context(text), action: {
                arguments.openPhoneNumberPrivacy()
            })
        case let .lastSeenPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsLastSeen, type: .context(text), action: {
                arguments.openLastSeenPrivacy()
            })
        case let .groupPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsGroups, type: .context(text), action: {
                arguments.openGroupsPrivacy()
            })
        case let .profilePhotoPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsProfilePhoto, type: .context(text), action: {
                arguments.openProfilePhotoPrivacy()
            })
        case let .forwardPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsForwards, type: .context(text), action: {
                arguments.openForwardPrivacy()
            })
        case let .voiceCallPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsVoiceCalls, type: .context(text), action: {
                arguments.openVoiceCallPrivacy()
            })
        case .securityHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsSecurityHeader, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .passcode(_, enabled):
            let desc = enabled ? L10n.privacyAndSecurityItemOn : L10n.privacyAndSecurityItemOff
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsPasscode, icon: theme.icons.privacySettings_passcode, type: .nextContext(desc), action: {
                arguments.openPasscode()
            })
        case let .twoStepVerification(_, configuration):
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
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsTwoStepVerification, icon: theme.icons.privacySettings_twoStep, type: .nextContext(desc), action: {
                arguments.openTwoStepVerification(configuration)
            })
        case let .activeSessions(_, sessions):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsActiveSessions, icon: theme.icons.privacySettings_activeSessions, type: .nextContext(sessions != nil ? "\(sessions!.count)" : ""), action: {
                arguments.openActiveSessions(sessions)
            })
        case .webAuthorizationsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityWebAuthorizationHeader, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .webAuthorizations:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.telegramWebSessionsController, action: {
                arguments.openWebAuthorizations()
            })
        case .accountHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsDeleteAccountHeader, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .accountTimeout(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsDeleteAccount, type: .context(text), action: {
                arguments.setupAccountAutoremove()
            })
        case .accountInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsDeleteAccountDescription)
        case .proxyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsProxyHeader, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .proxySettings(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsUseProxy, type: .context(text), action: {
                arguments.openProxySettings()
            })
        case let .togglePeerSuggestions(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.suggestFrequentContacts, type: .switchable(enabled), action: {
                if enabled {
                    confirm(for: mainWindow, information: L10n.suggestFrequentContactsAlert, successHandler: { _ in
                        arguments.togglePeerSuggestions(!enabled)
                    })
                } else {
                    arguments.togglePeerSuggestions(!enabled)
                }
            }, autoswitch: false)
        case .togglePeerSuggestionsDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.suggestFrequentContactsDesc, drawCustomSeparator: false, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .clearCloudDraftsHeader:
             return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityClearCloudDraftsHeader, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .clearCloudDrafts:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacyAndSecurityClearCloudDrafts, type: .none, action: {
                arguments.clearCloudDrafts()
            })
        case .section :
            return GeneralRowItem(initialSize, height:20, stableId: stableId)
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

private func privacyAndSecurityControllerEntries(state: PrivacyAndSecurityControllerState, privacySettings: AccountPrivacySettings?, webSessions: ([WebAuthorization], [PeerId : Peer])?, blockedState: BlockedPeersContextState, proxy: ProxySettings, recentPeers: RecentPeers, configuration: TwoStepVeriticationAccessConfiguration?, activeSessions: [RecentAccountSession]?, passcodeData: PostboxAccessChallengeData) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []

    var sectionId:Int = 1
    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    entries.append(.blockedPeers(sectionId: sectionId, blockedState.totalCount))
    entries.append(.activeSessions(sectionId: sectionId, activeSessions))
    
    let hasPasscode: Bool
    switch passcodeData {
    case .none:
        hasPasscode = false
    default:
        hasPasscode = true
    }
    
    entries.append(.passcode(sectionId: sectionId, enabled: hasPasscode))
    entries.append(.twoStepVerification(sectionId: sectionId, configuration: configuration))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.privacyHeader(sectionId: sectionId))
    if let privacySettings = privacySettings {
        entries.append(.phoneNumberPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.phoneNumber)))
        entries.append(.lastSeenPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.presence)))
        entries.append(.groupPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.groupInvitations)))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.voiceCalls)))
        entries.append(.profilePhotoPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.profilePhoto)))
        entries.append(.forwardPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.forwards)))
    } else {
        entries.append(.lastSeenPrivacy(sectionId: sectionId, ""))
        entries.append(.groupPrivacy(sectionId: sectionId, ""))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, ""))
    }


    entries.append(.section(sectionId: sectionId))
    sectionId += 1


    entries.append(.proxyHeader(sectionId: sectionId))
    let text: String
    if let active = proxy.activeServer, proxy.enabled {
        switch active.connection {
        case .socks5:
            text = L10n.proxySettingsSocks5
        case .mtp:
            text = L10n.proxySettingsMTP
        }
    } else {
        text = L10n.proxySettingsDisabled
    }
    entries.append(.proxySettings(sectionId: sectionId, text))


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
        entries.append(.accountTimeout(sectionId: sectionId, timeIntervalString(Int(value))))

    } else {
        entries.append(.accountTimeout(sectionId: sectionId, ""))
    }
    entries.append(.accountInfo(sectionId: sectionId))


    entries.append(.section(sectionId: sectionId))
    sectionId += 1


    let enabled: Bool
    switch recentPeers {
    case .disabled:
        enabled = false
    case .peers:
        enabled = true
    }

    entries.append(.togglePeerSuggestions(sectionId: sectionId, enabled: enabled))
    entries.append(.togglePeerSuggestionsDesc(sectionId: sectionId))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    entries.append(.clearCloudDraftsHeader(sectionId: sectionId))
    entries.append(.clearCloudDrafts(sectionId: sectionId))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    if let webSessions = webSessions, !webSessions.0.isEmpty {
        entries.append(.webAuthorizationsHeader(sectionId: sectionId))
        entries.append(.webAuthorizations(sectionId: sectionId))
    }


    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    return entries
}





class PrivacyAndSecurityViewController: TableViewController {
    private let privacySettingsPromise = Promise<(AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?)>()

//    override var removeAfterDisapper: Bool {
//        return true
//    }


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
                self?.navigationController?.push(RecentSessionsController(context, activeSessions: sessions))
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

                        if let index = strongSelf.genericView.index(hash: PrivacyAndSecurityEntry.accountTimeout(sectionId: 0, "").stableId) {
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
                _ = showModalProgress(signal: clearCloudDraftsInteractively(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId), for: mainWindow).start()
            })
        })


        let previous:Atomic<[AppearanceWrapperEntry<PrivacyAndSecurityEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize


        genericView.merge(with: combineLatest(queue: .mainQueue(), statePromise.get(), appearanceSignal, settings, privacySettingsPromise.get(), combineLatest(queue: .mainQueue(), recentPeers(account: context.account), twoStepAccessConfiguration.get(), activeSessions.get(), context.sharedContext.accountManager.accessChallengeData()), context.blockedPeersContext.state)
            |> map { state, appearance, proxy, values, additional, blockedState -> TableUpdateTransition in
                let entries = privacyAndSecurityControllerEntries(state: state, privacySettings: values.0, webSessions: values.1, blockedState: blockedState, proxy: proxy, recentPeers: additional.0, configuration: additional.1, activeSessions: additional.2, passcodeData: additional.3.data).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify {$0}, arguments: arguments)
            } |> beforeNext { [weak self] _ in
                self?.readyOnce()
            } |> afterDisposed {
                actionsDisposable.dispose()
            })

    }
    

    init(_ context: AccountContext, initialSettings: (AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?)) {
        super.init(context)
        self.privacySettingsPromise.set(.single(initialSettings))
    }
}

