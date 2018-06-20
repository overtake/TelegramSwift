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
    let account: Account
    let openBlockedUsers: ([Peer]?) -> Void
    let openLastSeenPrivacy: () -> Void
    let openGroupsPrivacy: () -> Void
    let openVoiceCallPrivacy: () -> Void
    let openPasscode: () -> Void
    let openTwoStepVerification: () -> Void
    let openActiveSessions: () -> Void
    let openWebAuthorizations: () -> Void
    let setupAccountAutoremove: () -> Void
    let openProxySettings:() ->Void
    let togglePeerSuggestions:(Bool)->Void
    init(account: Account, openBlockedUsers: @escaping ([Peer]?) -> Void, openLastSeenPrivacy: @escaping () -> Void, openGroupsPrivacy: @escaping () -> Void, openVoiceCallPrivacy: @escaping () -> Void, openPasscode: @escaping () -> Void, openTwoStepVerification: @escaping () -> Void, openActiveSessions: @escaping () -> Void, openWebAuthorizations: @escaping() -> Void, setupAccountAutoremove: @escaping () -> Void, openProxySettings:@escaping() ->Void, togglePeerSuggestions:@escaping(Bool)->Void) {
        self.account = account
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
    }
}


private enum PrivacyAndSecurityEntry: Comparable, Identifiable {
    case privacyHeader(sectionId:Int)
    case blockedPeers(sectionId:Int, [Peer]?)
    case lastSeenPrivacy(sectionId: Int, String)
    case groupPrivacy(sectionId: Int, String)
    case voiceCallPrivacy(sectionId: Int, String)
    case securityHeader(sectionId:Int)
    case passcode(sectionId:Int)
    case twoStepVerification(sectionId:Int)
    case activeSessions(sectionId:Int)
    case webAuthorizationsHeader(sectionId: Int)
    case webAuthorizations(sectionId:Int)
    case accountHeader(sectionId:Int)
    case accountTimeout(sectionId: Int, String)
    case accountInfo(sectionId:Int)
    case proxyHeader(sectionId:Int)
    case proxySettings(sectionId:Int, String)
    case togglePeerSuggestions(sectionId: Int, enabled: Bool)
    case togglePeerSuggestionsDesc(sectionId: Int)
    case section(sectionId:Int)
    
    var sectionId: Int {
        switch self {
        case let .privacyHeader(sectionId):
            return sectionId
        case let .blockedPeers(sectionId, _):
            return sectionId
        case let .lastSeenPrivacy(sectionId, _):
            return sectionId
        case let .groupPrivacy(sectionId, _):
            return sectionId
        case let .voiceCallPrivacy(sectionId, _):
            return sectionId
        case let .securityHeader(sectionId):
            return sectionId
        case let .passcode(sectionId):
            return sectionId
        case let .twoStepVerification(sectionId):
            return sectionId
        case let .activeSessions(sectionId):
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
        case let .proxyHeader(sectionId):
            return sectionId
        case let .section(sectionId):
            return sectionId
        }
    }
    
    var stableId:Int {
        switch self {
        case .privacyHeader:
            return 0
        case .blockedPeers:
            return 1
        case .lastSeenPrivacy:
            return 2
        case .groupPrivacy:
            return 3
        case .voiceCallPrivacy:
            return 4
        case .securityHeader:
            return 5
        case .passcode:
            return 6
        case .twoStepVerification:
            return 7
        case .activeSessions:
            return 8
        case .accountHeader:
            return 9
        case .accountTimeout:
            return 10
        case .accountInfo:
            return 11
        case .webAuthorizationsHeader:
            return 12
        case .webAuthorizations:
            return 13
        case .proxyHeader:
            return 14
        case .proxySettings:
            return 15
        case .togglePeerSuggestions:
            return 16
        case .togglePeerSuggestionsDesc:
            return 17
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
    
    static func ==(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        switch lhs {
        case .privacyHeader, .securityHeader, .passcode, .twoStepVerification, .activeSessions, .webAuthorizationsHeader, .webAuthorizations, .accountHeader, .accountInfo, .proxyHeader, .section:
            return lhs.stableId == rhs.stableId && lhs.sectionId == rhs.sectionId
        case let .lastSeenPrivacy(sectionId, text):
            if case .lastSeenPrivacy(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
            
        case let .blockedPeers(lhsSectionId, lhsBlockedPeers):
            if case let .blockedPeers(rhsSectionId, rhsBlockedPeers) = rhs {
                if let lhsBlockedPeers = lhsBlockedPeers, let rhsBlockedPeers = rhsBlockedPeers {
                    if lhsBlockedPeers.count != rhsBlockedPeers.count {
                        return false
                    }
                    for i in 0 ..< lhsBlockedPeers.count {
                        if !lhsBlockedPeers[i].isEqual(rhsBlockedPeers[i]) {
                            return false
                        }
                    }
                } else if (lhsBlockedPeers != nil) != (rhsBlockedPeers != nil) {
                    return false
                }
                return lhsSectionId == rhsSectionId
            } else {
                return false
            }
        case let .groupPrivacy(sectionId, text):
            if case .groupPrivacy(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .proxySettings(sectionId, text):
            if case .proxySettings(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .togglePeerSuggestions(sectionId, enabled):
            if case .togglePeerSuggestions(sectionId, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .togglePeerSuggestionsDesc(sectionId):
            if case .togglePeerSuggestionsDesc(sectionId) = rhs {
                return true
            } else {
                return false
            }
        case let .voiceCallPrivacy(sectionId, text):
            if case .voiceCallPrivacy(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .accountTimeout(sectionId, text):
            if case .accountTimeout(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        return lhs.stableIndex < rhs.stableIndex
    }
    func item(_ arguments: PrivacyAndSecurityControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .privacyHeader:
            
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.privacySettingsPrivacyHeader), drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .blockedPeers(_, blockedPeers):
            let text: String
            if let blockedPeers = blockedPeers {
                if !blockedPeers.isEmpty {
                    text = L10n.privacyAndSecurityBlockedUsers("\(blockedPeers.count)")
                } else {
                    text = ""
                }
            } else {
                text = ""
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsBlockedUsers), type: .nextContext(text), action: {
                arguments.openBlockedUsers(blockedPeers)
            })
        case let .lastSeenPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsLastSeen), type: .context(text), action: {
                arguments.openLastSeenPrivacy()
            })
        case let .groupPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsGroups), type: .context(text), action: {
                arguments.openGroupsPrivacy()
            })
        case let .voiceCallPrivacy(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsVoiceCalls), type: .context(text), action: {
                arguments.openVoiceCallPrivacy()
            })
        case .securityHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.privacySettingsSecurityHeader), drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .passcode:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsPasscode), action: {
                arguments.openPasscode()
            })
        case .twoStepVerification:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsTwoStepVerification), action: {
                arguments.openTwoStepVerification()
            })
        case .activeSessions:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsActiveSessions), action: {
                arguments.openActiveSessions()
            })
        case .webAuthorizationsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityWebAuthorizationHeader, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .webAuthorizations:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.telegramWebSessionsController, action: {
                arguments.openWebAuthorizations()
            })
        case .accountHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.privacySettingsDeleteAccountHeader), drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .accountTimeout(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsDeleteAccount), type: .context(text), action: {
                arguments.setupAccountAutoremove()
            })
        case .accountInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.privacySettingsDeleteAccountDescription))
        case .proxyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.privacySettingsProxyHeader), drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .proxySettings(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsUseProxy), type: .context(text), action: {
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
        case .section :
            return GeneralRowItem(initialSize, height:20, stableId: stableId)
        }
    }
}

private func stringForSelectiveSettings(settings: SelectivePrivacySettings) -> String {
    switch settings {
    case let .disableEveryone(enableFor):
        if enableFor.isEmpty {
            return tr(L10n.privacySettingsControllerNobody)
        } else {
            return tr(L10n.privacySettingsLastSeenNobodyPlus("\(enableFor.count)"))
        }
    case let .enableEveryone(disableFor):
        if disableFor.isEmpty {
            return tr(L10n.privacySettingsControllerEverbody)
        } else {
            return tr(L10n.privacySettingsLastSeenEverybodyMinus("\(disableFor.count)"))
        }
    case let .enableContacts(enableFor, disableFor):
        if !enableFor.isEmpty && !disableFor.isEmpty {
            return tr(L10n.privacySettingsLastSeenContactsMinusPlus("\(enableFor.count)", "\(disableFor.count)"))
        } else if !enableFor.isEmpty {
            return tr(L10n.privacySettingsLastSeenContactsPlus("\(enableFor.count)"))
        } else if !disableFor.isEmpty {
            return tr(L10n.privacySettingsLastSeenContactsMinus("\(disableFor.count)"))
        } else {
            return tr(L10n.privacySettingsControllerMyContacts)
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

private func privacyAndSecurityControllerEntries(state: PrivacyAndSecurityControllerState, privacySettings: AccountPrivacySettings?, webSessions: ([WebAuthorization], [PeerId : Peer])?, blockedPeers: [Peer]?, proxy: ProxySettings, recentPeers: RecentPeers) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []
    
    var sectionId:Int = 1
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.privacyHeader(sectionId: sectionId))
    entries.append(.blockedPeers(sectionId: sectionId, blockedPeers))
    if let privacySettings = privacySettings {
        entries.append(.lastSeenPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.presence)))
        entries.append(.groupPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.groupInvitations)))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.voiceCalls)))
    } else {
        entries.append(.lastSeenPrivacy(sectionId: sectionId, ""))
        entries.append(.groupPrivacy(sectionId: sectionId, ""))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, ""))
    }
    
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.securityHeader(sectionId: sectionId))
    entries.append(.passcode(sectionId: sectionId))
    entries.append(.twoStepVerification(sectionId: sectionId))
    entries.append(.activeSessions(sectionId: sectionId))
    
    
    
    
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
    
    if let webSessions = webSessions, !webSessions.0.isEmpty {
        entries.append(.webAuthorizationsHeader(sectionId: sectionId))
        entries.append(.webAuthorizations(sectionId: sectionId))
    }
    
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    return entries
}





class PrivacyAndSecurityViewController: TableViewController {
    private let privacySettingsPromise = Promise<(AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?, [Peer]?)>()

//    override var removeAfterDisapper: Bool {
//        return true
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let statePromise = ValuePromise(PrivacyAndSecurityControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: PrivacyAndSecurityControllerState())
        let updateState: ((PrivacyAndSecurityControllerState) -> PrivacyAndSecurityControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let actionsDisposable = DisposableSet()
        let account = self.account
        
        let pushControllerImpl: (ViewController) -> Void = { [weak self] c in
            self?.navigationController?.push(c)
        }
        

        let proxySettings:Signal<ProxySettings, Void> = proxySettingsSignal(account.postbox)

        let currentInfoDisposable = MetaDisposable()
        actionsDisposable.add(currentInfoDisposable)
        
        let updateAccountTimeoutDisposable = MetaDisposable()
        actionsDisposable.add(updateAccountTimeoutDisposable)

        let privacySettingsPromise = self.privacySettingsPromise
        
        let arguments = PrivacyAndSecurityControllerArguments(account: account, openBlockedUsers: { [weak self] blockedPeers in
            
            if let account = self?.account {
                pushControllerImpl(BlockedPeersViewController(account, blockedPeers, updated: { updated in
                    let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { privacy, webSessions, blockedPeers -> Signal<Void, NoError> in
                            privacySettingsPromise.set(.single((privacy, webSessions, updated)))
                            return .complete()
                    }
                    currentInfoDisposable.set(applySetting.start())
                }))
            }
        }, openLastSeenPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(account: account, kind: .presence, current: info.presence, updated: { updated in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions, blockedPeers -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: updated, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, accountRemovalTimeout: value.accountRemovalTimeout), sessions, blockedPeers)))
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
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(account: account, kind: .groupInvitations, current: info.groupInvitations, updated: { updated in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions, blockedPeers -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: updated, voiceCalls: value.voiceCalls, accountRemovalTimeout: value.accountRemovalTimeout), sessions, blockedPeers)))
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
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(account: account, kind: .voiceCalls, current: info.voiceCalls, updated: { updated in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions, blockedPeers -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: updated, accountRemovalTimeout: value.accountRemovalTimeout), sessions, blockedPeers)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openPasscode: { [weak self] in
            if let account = self?.account {
                self?.navigationController?.push(PasscodeSettingsViewController(account))
            }
        }, openTwoStepVerification: { [weak self] in
            if let account = self?.account {
                self?.navigationController?.push(TwoStepVerificationUnlockController(account: account, mode: .access))
            }
        }, openActiveSessions: { [weak self] in
            if let account = self?.account {
                self?.navigationController?.push(RecentSessionsController(account))
            }
        }, openWebAuthorizations: {
            
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] _, sessions, _ in
                pushControllerImpl(WebSessionsController(account, sessions, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { privacy, _, blockedPeers -> Signal<Void, NoError> in
                                privacySettingsPromise.set(.single((privacy, updated, blockedPeers)))
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
                updateAccountTimeoutDisposable.set(signal.start(next: { [weak updateAccountTimeoutDisposable, weak strongSelf] privacySettingsValue, _, _ in
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
                                    |> mapToSignal { value, sessions, blockedPeers -> Signal<Void, NoError> in
                                        if let value = value {
                                            privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, accountRemovalTimeout: timeout), sessions, blockedPeers)))
                                        }
                                        return .complete()
                                }
                                updateAccountTimeoutDisposable.set((updateAccountRemovalTimeout(account: account, timeout: timeout)
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
            if let account = self?.account {
                
                proxyListController(postbox: account.postbox, network: account.network, share: { servers in
                    var message: String = ""
                    for server in servers {
                        message += server.link + "\n\n"
                    }
                    message = message.trimmed
                    
                    showModal(with: ShareModalController(ShareLinkObject(account, link: message)), for: mainWindow)
                }) ({ controller in
                    pushControllerImpl(controller)
                })
                //pushControllerImpl(proxyListController(postbox: account.postbox, network: account.network))
                
//                pushControllerImpl(controller)
            }
        }, togglePeerSuggestions: { enabled in
            _ = (updateRecentPeersEnabled(postbox: account.postbox, network: account.network, enabled: enabled) |> then(enabled ? managedUpdatedRecentPeers(postbox: account.postbox, network: account.network) : Signal<Void, Void>.complete())).start()
        })
        
        
        let previous:Atomic<[AppearanceWrapperEntry<PrivacyAndSecurityEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
                
      
        
        genericView.merge(with: combineLatest(statePromise.get() |> deliverOnMainQueue, appearanceSignal, proxySettings, privacySettingsPromise.get() |> deliverOnMainQueue, recentPeers(account: account) |> deliverOnMainQueue)
            |> map { state, appearance, proxy, values, recentPeers -> TableUpdateTransition in
                let entries = privacyAndSecurityControllerEntries(state: state, privacySettings: values.0, webSessions: values.1, blockedPeers: values.2, proxy: proxy, recentPeers: recentPeers).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify {$0}, arguments: arguments)
            } |> afterDisposed {
                actionsDisposable.dispose()
        })
        
        
        readyOnce()
    }
    
    init(_ account:Account, initialSettings: Signal<(AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?, [Peer]?), NoError>) {
        super.init(account)
        self.privacySettingsPromise.set(initialSettings)
    }
}
