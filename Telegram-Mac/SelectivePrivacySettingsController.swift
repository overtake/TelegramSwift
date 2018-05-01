//
//  SelectivePrivacySettingsController.swift
//  Telegram
//
//  Created by keepcoder on 02/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

enum SelectivePrivacySettingsKind {
    case presence
    case groupInvitations
    case voiceCalls
}

private enum SelectivePrivacySettingType {
    case everybody
    case contacts
    case nobody
    
    init(_ setting: SelectivePrivacySettings) {
        switch setting {
        case .disableEveryone:
            self = .nobody
        case .enableContacts:
            self = .contacts
        case .enableEveryone:
            self = .everybody
        }
    }
}

private final class SelectivePrivacySettingsControllerArguments {
    let account: Account
    
    let updateType: (SelectivePrivacySettingType) -> Void
    let openEnableFor: () -> Void
    let openDisableFor: () -> Void
    
    init(account: Account, updateType: @escaping (SelectivePrivacySettingType) -> Void, openEnableFor: @escaping () -> Void, openDisableFor: @escaping () -> Void) {
        self.account = account
        self.updateType = updateType
        self.openEnableFor = openEnableFor
        self.openDisableFor = openDisableFor
    }
}

private enum SelectivePrivacySettingsSection: Int32 {
    case setting
    case peers
}

private func stringForUserCount(_ count: Int) -> String {
    if count == 0 {
        return tr(L10n.privacySettingsControllerAddUsers)
    } else {
        return tr(L10n.privacySettingsControllerUserCountCountable(count))
    }
}

private enum SelectivePrivacySettingsEntry: TableItemListNodeEntry {
    case settingHeader(Int32, String)
    case everybody(Int32, Bool)
    case contacts(Int32, Bool)
    case nobody(Int32, Bool)
    case settingInfo(Int32, String)
    case disableFor(Int32, String, Int)
    case enableFor(Int32, String, Int)
    case peersInfo(Int32)
    case section(Int32)
    
    var stableId: Int32 {
        switch self {
        case .settingHeader:
            return 0
        case .everybody:
            return 1
        case .contacts:
            return 2
        case .nobody:
            return 3
        case .settingInfo:
            return 4
        case .disableFor:
            return 5
        case .enableFor:
            return 6
        case .peersInfo:
            return 7
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case .settingHeader(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .everybody(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .contacts(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .nobody(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .settingInfo(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .disableFor(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .enableFor(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .peersInfo(let sectionId):
            return (sectionId * 1000) + stableId
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func ==(lhs: SelectivePrivacySettingsEntry, rhs: SelectivePrivacySettingsEntry) -> Bool {
        switch lhs {
        case let .settingHeader(sectionId, text):
            if case .settingHeader(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .everybody(sectionId, value):
            if case .everybody(sectionId, value) = rhs {
                return true
            } else {
                return false
            }
        case let .contacts(sectionId, value):
            if case .contacts(sectionId, value) = rhs {
                return true
            } else {
                return false
            }
        case let .nobody(sectionId, value):
            if case .nobody(sectionId, value) = rhs {
                return true
            } else {
                return false
            }
        case let .settingInfo(sectionId, text):
            if case .settingInfo(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .disableFor(sectionId, title, count):
            if case .disableFor(sectionId, title, count) = rhs {
                return true
            } else {
                return false
            }
        case let .enableFor(sectionId, title, count):
            if case .enableFor(sectionId, title, count) = rhs {
                return true
            } else {
                return false
            }
        case .peersInfo(let sectionId):
            if case .peersInfo(sectionId) = rhs {
                return true
            } else {
                return false
            }
        case .section(let sectionId):
            if case .section(sectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: SelectivePrivacySettingsEntry, rhs: SelectivePrivacySettingsEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: SelectivePrivacySettingsControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .settingHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .everybody(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsControllerEverbody), type: .selectable(value), action: {
                arguments.updateType(.everybody)
            })

        case let .contacts(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsControllerMyContacts), type: .selectable(value), action: {
                arguments.updateType(.contacts)
            })
        case let .nobody(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsControllerNobody), type: .selectable(value), action: {
                arguments.updateType(.nobody)
            })
        case let .settingInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .disableFor(_, title, count):
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), action: {
                arguments.openDisableFor()
            })

        case let .enableFor(_, title, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), action: {
                arguments.openEnableFor()
            })
        case .peersInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsControllerPeerInfo)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

private struct SelectivePrivacySettingsControllerState: Equatable {
    let setting: SelectivePrivacySettingType
    let enableFor: Set<PeerId>
    let disableFor: Set<PeerId>
    
    let saving: Bool
    
    init(setting: SelectivePrivacySettingType, enableFor: Set<PeerId>, disableFor: Set<PeerId>, saving: Bool) {
        self.setting = setting
        self.enableFor = enableFor
        self.disableFor = disableFor
        self.saving = saving
    }
    
    static func ==(lhs: SelectivePrivacySettingsControllerState, rhs: SelectivePrivacySettingsControllerState) -> Bool {
        if lhs.setting != rhs.setting {
            return false
        }
        if lhs.enableFor != rhs.enableFor {
            return false
        }
        if lhs.disableFor != rhs.disableFor {
            return false
        }
        if lhs.saving != rhs.saving {
            return false
        }
        
        return true
    }
    
    func withUpdatedSetting(_ setting: SelectivePrivacySettingType) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving)
    }
    
    func withUpdatedEnableFor(_ enableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: enableFor, disableFor: self.disableFor, saving: self.saving)
    }
    
    func withUpdatedDisableFor(_ disableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: disableFor, saving: self.saving)
    }
    
    func withUpdatedSaving(_ saving: Bool) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: saving)
    }
}

private func selectivePrivacySettingsControllerEntries(kind: SelectivePrivacySettingsKind, state: SelectivePrivacySettingsControllerState) -> [SelectivePrivacySettingsEntry] {
    var entries: [SelectivePrivacySettingsEntry] = []
    
    var sectionId:Int32 = 1
    entries.append(.section(sectionId))
    sectionId += 1
    
    let settingTitle: String
    let settingInfoText: String
    let disableForText: String
    let enableForText: String
    switch kind {
    case .presence:
        settingTitle = tr(L10n.privacySettingsControllerLastSeenHeader)
        settingInfoText = tr(L10n.privacySettingsControllerLastSeenDescription)
        disableForText = tr(L10n.privacySettingsControllerNeverShareWith)
        enableForText = tr(L10n.privacySettingsControllerAlwaysShareWith)
    case .groupInvitations:
        settingTitle = tr(L10n.privacySettingsControllerGroupHeader)
        settingInfoText = tr(L10n.privacySettingsControllerGroupDescription)
        disableForText = tr(L10n.privacySettingsControllerNeverAllow)
        enableForText = tr(L10n.privacySettingsControllerAlwaysAllow)
    case .voiceCalls:
        settingTitle = tr(L10n.privacySettingsControllerPhoneCallHeader)
        settingInfoText = tr(L10n.privacySettingsControllerPhoneCallDescription)
        disableForText = tr(L10n.privacySettingsControllerNeverAllow)
        enableForText = tr(L10n.privacySettingsControllerAlwaysAllow)
    }
    
    entries.append(.settingHeader(sectionId, settingTitle))
    
    entries.append(.everybody(sectionId, state.setting == .everybody))
    entries.append(.contacts(sectionId, state.setting == .contacts))
    switch kind {
    case .presence, .voiceCalls:
        entries.append(.nobody(sectionId, state.setting == .nobody))
    case .groupInvitations:
        break
    }
    entries.append(.settingInfo(sectionId, settingInfoText))
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    switch state.setting {
    case .everybody:
        entries.append(.disableFor(sectionId, disableForText, state.disableFor.count))
    case .contacts:
        entries.append(.disableFor(sectionId, disableForText, state.disableFor.count))
        entries.append(.enableFor(sectionId, enableForText, state.enableFor.count))
    case .nobody:
        entries.append(.enableFor(sectionId, enableForText, state.enableFor.count))
    }
    entries.append(.peersInfo(sectionId))
    
    return entries
}

fileprivate func prepareTransition(left:[SelectivePrivacySettingsEntry], right: [SelectivePrivacySettingsEntry], initialSize:NSSize, arguments:SelectivePrivacySettingsControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class SelectivePrivacySettingsController: EditableViewController<TableView> {
    private let kind: SelectivePrivacySettingsKind
    private let current: SelectivePrivacySettings
    private let updated: (SelectivePrivacySettings) -> Void
    private var savePressed:(()->Void)?
    init(account: Account, kind: SelectivePrivacySettingsKind, current: SelectivePrivacySettings, updated: @escaping (SelectivePrivacySettings) -> Void) {
        self.kind = kind
        self.current = current
        self.updated = updated
        super.init(account)
    }
    
    override func changeState() {
        super.changeState()
        savePressed?()
    }
   
    override var normalString:String {
        return ""
    }

    
    override func viewDidLoad() {
        let account = self.account
        let kind = self.kind
        let current = self.current
        let updated = self.updated
        
        let initialSize = self.atomicSize
        let previous:Atomic<[SelectivePrivacySettingsEntry]> = Atomic(value: [])
        
        var initialEnableFor = Set<PeerId>()
        var initialDisableFor = Set<PeerId>()
        switch current {
        case let .disableEveryone(enableFor):
            initialEnableFor = enableFor
        case let .enableContacts(enableFor, disableFor):
            initialEnableFor = enableFor
            initialDisableFor = disableFor
        case let .enableEveryone(disableFor):
            initialDisableFor = disableFor
        }
        let initialState = SelectivePrivacySettingsControllerState(setting: SelectivePrivacySettingType(current), enableFor: initialEnableFor, disableFor: initialDisableFor, saving: false)
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((SelectivePrivacySettingsControllerState) -> SelectivePrivacySettingsControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        var dismissImpl: (() -> Void)?
        var pushControllerImpl: ((ViewController) -> Void)?
        
        let actionsDisposable = DisposableSet()
        
        let updateSettingsDisposable = MetaDisposable()
        actionsDisposable.add(updateSettingsDisposable)
        
        let arguments = SelectivePrivacySettingsControllerArguments(account: account, updateType: { type in
            updateState {
                $0.withUpdatedSetting(type)
            }
        }, openEnableFor: {
            let title: String
            switch kind {
            case .presence:
                title = tr(L10n.privacySettingsControllerAlwaysShare)
            case .groupInvitations:
                title = tr(L10n.privacySettingsControllerAlwaysAllow)
            case .voiceCalls:
                title = tr(L10n.privacySettingsControllerAlwaysAllow)
            }
            var peerIds = Set<PeerId>()
            updateState { state in
                peerIds = state.enableFor
                return state
            }
            
            
            pushControllerImpl?(SelectivePrivacySettingsPeersController(account: account, title: title, initialPeerIds: Array(peerIds), updated: { updatedPeerIds in
                updateState { state in
                    return state.withUpdatedEnableFor(Set(updatedPeerIds)).withUpdatedDisableFor(state.disableFor.subtracting(Set(updatedPeerIds)))
                }
            }))
        }, openDisableFor: {
            let title: String
            switch kind {
            case .presence:
                title = tr(L10n.privacySettingsControllerNeverShareWith)
            case .groupInvitations:
                title = tr(L10n.privacySettingsControllerNeverAllow)
            case .voiceCalls:
                title = tr(L10n.privacySettingsControllerNeverAllow)
            }
            var peerIds = Set<PeerId>()
            updateState { state in
                peerIds = state.disableFor
                return state
            }
            pushControllerImpl?(SelectivePrivacySettingsPeersController(account: account, title: title, initialPeerIds: Array(peerIds), updated: { updatedPeerIds in
                updateState { state in
                    return state.withUpdatedDisableFor(Set(updatedPeerIds)).withUpdatedEnableFor(state.enableFor.subtracting(Set(updatedPeerIds)))
                }
            }))
        })
        
        let signal = statePromise.get() |> deliverOnMainQueue
            |> map { [weak self] state -> TableUpdateTransition in
                
                if state.saving {
                    self?.state = .Edit
                } else {
                    self?.state = initialState == state ? .Normal : .Edit
                    
                    self?.savePressed = {
                        var wasSaving = false
                        var settings: SelectivePrivacySettings?
                        updateState { state in
                            wasSaving = state.saving
                            switch state.setting {
                            case .everybody:
                                settings = SelectivePrivacySettings.enableEveryone(disableFor: state.disableFor)
                            case .contacts:
                                settings = SelectivePrivacySettings.enableContacts(enableFor: state.enableFor, disableFor: state.disableFor)
                            case .nobody:
                                settings = SelectivePrivacySettings.disableEveryone(enableFor: state.enableFor)
                            }
                            return state.withUpdatedSaving(true)
                        }
                        
                        if let settings = settings, !wasSaving {
                            let type: UpdateSelectiveAccountPrivacySettingsType
                            switch kind {
                            case .presence:
                                type = .presence
                            case .groupInvitations:
                                type = .groupInvitations
                            case .voiceCalls:
                                type = .voiceCalls
                            }
                            
                            updateSettingsDisposable.set((updateSelectiveAccountPrivacySettings(account: account, type: type, settings: settings) |> deliverOnMainQueue).start(completed: {
                                updateState { state in
                                    return state.withUpdatedSaving(false)
                                }
                                updated(settings)
                                dismissImpl?()
                            }))
                        }
                    }
                }
                
                let title: String
                switch kind {
                case .presence:
                    title = tr(L10n.privacySettingsLastSeen)
                case .groupInvitations:
                    title = tr(L10n.privacySettingsGroups)
                case .voiceCalls:
                    title = tr(L10n.privacySettingsVoiceCalls)
                }
                
                self?.setCenterTitle(title)
                
                let entries = selectivePrivacySettingsControllerEntries(kind: kind, state: state)
                return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
            } |> afterDisposed {
                actionsDisposable.dispose()
        }
        
        genericView.merge(with: signal)
        readyOnce()
        
        pushControllerImpl = { [weak self] c in
            self?.navigationController?.push(c)
        }

        dismissImpl = { [weak self] in
            if self?.navigationController?.controller == self {
                self?.navigationController?.back()
            }
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePressed?()
    }
    
    override func didRemovedFromStack() {
        super.didRemovedFromStack()
        
    }
}
