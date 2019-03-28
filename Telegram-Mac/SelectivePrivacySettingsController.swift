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
    case profilePhoto
    case forwards
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

enum SelectivePrivacySettingsPeerTarget {
    case main
    case callP2P
}


private final class SelectivePrivacySettingsControllerArguments {
    let context: AccountContext
    
    let updateType: (SelectivePrivacySettingType) -> Void
    let openEnableFor: (SelectivePrivacySettingsPeerTarget) -> Void
    let openDisableFor: (SelectivePrivacySettingsPeerTarget) -> Void
    let p2pMode: (SelectivePrivacySettingType) -> Void
    init(context: AccountContext, updateType: @escaping (SelectivePrivacySettingType) -> Void, openEnableFor: @escaping (SelectivePrivacySettingsPeerTarget) -> Void, openDisableFor: @escaping (SelectivePrivacySettingsPeerTarget) -> Void, p2pMode: @escaping(SelectivePrivacySettingType) -> Void) {
        self.context = context
        self.updateType = updateType
        self.openEnableFor = openEnableFor
        self.openDisableFor = openDisableFor
        self.p2pMode = p2pMode
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
    case p2pAlways(Int32, Bool)
    case p2pContacts(Int32, Bool)
    case p2pNever(Int32, Bool)
    case p2pHeader(Int32, String)
    case p2pDesc(Int32, String)
    case settingInfo(Int32, String)
    case disableFor(Int32, String, Int)
    case enableFor(Int32, String, Int)
    case p2pDisableFor(Int32, String, Int)
    case p2pEnableFor(Int32, String, Int)
    case p2pPeersInfo(Int32)
    case peersInfo(Int32)
    case section(Int32)
    
    var stableId: Int32 {
        switch self {
        case .settingHeader: return 0
        case .everybody: return 1
        case .contacts: return 2
        case .nobody: return 3
        case .settingInfo: return 4
        case .disableFor: return 5
        case .enableFor: return 6
        case .peersInfo: return 7
        case .p2pHeader: return 8
        case .p2pAlways: return 9
        case .p2pContacts: return 10
        case .p2pNever: return 11
        case .p2pDesc: return 12
        case .p2pDisableFor: return 13
        case .p2pEnableFor: return 14
        case .p2pPeersInfo: return 15
        case .section(let sectionId): return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case .settingHeader(let sectionId, _): return (sectionId * 1000) + stableId
        case .everybody(let sectionId, _): return (sectionId * 1000) + stableId
        case .contacts(let sectionId, _): return (sectionId * 1000) + stableId
        case .nobody(let sectionId, _): return (sectionId * 1000) + stableId
        case .settingInfo(let sectionId, _): return (sectionId * 1000) + stableId
        case .disableFor(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .enableFor(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .peersInfo(let sectionId):  return (sectionId * 1000) + stableId
        case .p2pAlways(let sectionId, _): return (sectionId * 1000) + stableId
        case .p2pContacts(let sectionId, _): return (sectionId * 1000) + stableId
        case .p2pNever(let sectionId, _): return (sectionId * 1000) + stableId
        case .p2pHeader(let sectionId, _): return (sectionId * 1000) + stableId
        case .p2pDesc(let sectionId, _): return (sectionId * 1000) + stableId
        case .p2pDisableFor(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .p2pEnableFor(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .p2pPeersInfo(let sectionId): return (sectionId * 1000) + stableId
        case .section(let sectionId): return (sectionId + 1) * 1000 - sectionId
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
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsControllerEverbody, type: .selectable(value), action: {
                arguments.updateType(.everybody)
            })

        case let .contacts(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsControllerMyContacts, type: .selectable(value), action: {
                arguments.updateType(.contacts)
            })
        case let .nobody(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsControllerNobody, type: .selectable(value), action: {
                arguments.updateType(.nobody)
            })
        case let .p2pHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .p2pAlways(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsControllerP2pAlways, type: .selectable(value), action: {
                arguments.p2pMode(.everybody)
            })
        case let .p2pContacts(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsControllerP2pContacts, type: .selectable(value), action: {
                arguments.p2pMode(.contacts)
            })
        case let .p2pNever(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsControllerP2pNever, type: .selectable(value), action: {
                arguments.p2pMode(.nobody)
            })
        case let .p2pDesc(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .settingInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .disableFor(_, title, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), action: {
                arguments.openDisableFor(.main)
            })
        case let .enableFor(_, title, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), action: {
                arguments.openEnableFor(.main)
            })
        case .peersInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsControllerPeerInfo)
        case let .p2pDisableFor(_, title, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), action: {
                arguments.openDisableFor(.callP2P)
            })
        case let .p2pEnableFor(_, title, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), action: {
                arguments.openEnableFor(.callP2P)
            })
        case .p2pPeersInfo:
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
    
    let callP2PMode: SelectivePrivacySettingType?
    let callP2PEnableFor: Set<PeerId>
    let callP2PDisableFor: Set<PeerId>

    
    init(setting: SelectivePrivacySettingType, enableFor: Set<PeerId>, disableFor: Set<PeerId>, saving: Bool, callP2PMode: SelectivePrivacySettingType?, callP2PEnableFor: Set<PeerId>, callP2PDisableFor: Set<PeerId>) {
        self.setting = setting
        self.enableFor = enableFor
        self.disableFor = disableFor
        self.saving = saving
        self.callP2PMode = callP2PMode
        self.callP2PEnableFor = callP2PEnableFor
        self.callP2PDisableFor = callP2PDisableFor

    }
    
    func withUpdatedSetting(_ setting: SelectivePrivacySettingType) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor)
    }
    
    func withUpdatedEnableFor(_ enableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: enableFor, disableFor: self.disableFor, saving: self.saving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor)
    }
    
    func withUpdatedDisableFor(_ disableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: disableFor, saving: self.saving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor)
    }
    
    func withUpdatedSaving(_ saving: Bool) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: saving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor)
    }
    
    func withUpdatedCallP2PMode(_ mode: SelectivePrivacySettingType) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving,  callP2PMode: mode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor)
    }
    
    func withUpdatedCallP2PEnableFor(_ enableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callP2PMode: self.callP2PMode, callP2PEnableFor: enableFor, callP2PDisableFor: self.callP2PDisableFor)
    }
    
    func withUpdatedCallP2PDisableFor(_ disableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: disableFor)
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
        settingTitle = L10n.privacySettingsControllerLastSeenHeader
        settingInfoText = L10n.privacySettingsControllerLastSeenDescription
        disableForText = L10n.privacySettingsControllerNeverShareWith
        enableForText = L10n.privacySettingsControllerAlwaysShareWith
    case .groupInvitations:
        settingTitle = L10n.privacySettingsControllerGroupHeader
        settingInfoText = L10n.privacySettingsControllerGroupDescription
        disableForText = L10n.privacySettingsControllerNeverAllow
        enableForText = L10n.privacySettingsControllerAlwaysAllow
    case .voiceCalls:
        settingTitle = L10n.privacySettingsControllerPhoneCallHeader
        settingInfoText = L10n.privacySettingsControllerPhoneCallDescription
        disableForText = L10n.privacySettingsControllerNeverAllow
        enableForText = L10n.privacySettingsControllerAlwaysAllow
    case .profilePhoto:
        settingTitle = L10n.privacySettingsControllerProfilePhotoWhoCanSeeMyPhoto
        settingInfoText = L10n.privacySettingsControllerProfilePhotoCustomHelp
        disableForText = L10n.privacySettingsControllerNeverShareWith
        enableForText = L10n.privacySettingsControllerAlwaysShareWith
    case .forwards:
        settingTitle = L10n.privacySettingsControllerForwardsWhoCanForward
        settingInfoText = L10n.privacySettingsControllerForwardsCustomHelp
        disableForText = L10n.privacySettingsControllerNeverAllow
        enableForText = L10n.privacySettingsControllerAlwaysAllow

    }
    
    entries.append(.settingHeader(sectionId, settingTitle))
    
    entries.append(.everybody(sectionId, state.setting == .everybody))
    entries.append(.contacts(sectionId, state.setting == .contacts))
    switch kind {
    case .presence, .voiceCalls, .forwards:
        entries.append(.nobody(sectionId, state.setting == .nobody))
    case .groupInvitations, .profilePhoto:
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
    
    if let callSettings = state.callP2PMode {
        switch kind {
        case .voiceCalls:
            entries.append(.section(sectionId))
            sectionId += 1
            entries.append(.p2pHeader(sectionId, L10n.privacySettingsControllerP2pHeader))
            entries.append(.p2pAlways(sectionId, callSettings == .everybody))
            entries.append(.p2pContacts(sectionId, callSettings == .contacts))
            entries.append(.p2pNever(sectionId, callSettings == .nobody))
            entries.append(.p2pDesc(sectionId, L10n.privacySettingsControllerP2pDesc))
            
            entries.append(.section(sectionId))
            sectionId += 1
            
            switch callSettings {
            case .everybody:
                entries.append(.p2pDisableFor(sectionId, disableForText, state.callP2PDisableFor.count))
            case .contacts:
                entries.append(.p2pDisableFor(sectionId, disableForText, state.callP2PDisableFor.count))
                entries.append(.p2pEnableFor(sectionId, enableForText, state.callP2PEnableFor.count))
            case .nobody:
                entries.append(.p2pEnableFor(sectionId, enableForText, state.callP2PEnableFor.count))
            }
            entries.append(.p2pPeersInfo(sectionId))
            
        default:
            break
        }
    }
    
    
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
    private let updated: (SelectivePrivacySettings, SelectivePrivacySettings?) -> Void
    private var savePressed:(()->Void)?
    private let callSettings: SelectivePrivacySettings?
    init(_ context: AccountContext, kind: SelectivePrivacySettingsKind, current: SelectivePrivacySettings, callSettings: SelectivePrivacySettings? = nil, updated: @escaping (SelectivePrivacySettings, SelectivePrivacySettings?) -> Void) {
        self.kind = kind
        self.current = current
        self.updated = updated
        self.callSettings = callSettings
        super.init(context)
    }
    
    override func changeState() {
        super.changeState()
        savePressed?()
    }
   
    override var normalString:String {
        return ""
    }

    
    override func viewDidLoad() {
        let context = self.context
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
        
        var initialCallP2PEnableFor: Set<PeerId> = Set<PeerId>()
        var initialCallP2PDisableFor: Set<PeerId> = Set<PeerId>()
        if let callCurrent = callSettings {
            switch callCurrent {
            case let .disableEveryone(enableFor):
                initialCallP2PEnableFor = enableFor
                initialCallP2PDisableFor = Set<PeerId>()
            case let .enableContacts(enableFor, disableFor):
                initialCallP2PEnableFor = enableFor
                initialCallP2PDisableFor = disableFor
            case let .enableEveryone(disableFor):
                initialCallP2PEnableFor = Set<PeerId>()
                initialCallP2PDisableFor = disableFor
            }
        }

        
        let initialState = SelectivePrivacySettingsControllerState(setting: SelectivePrivacySettingType(current), enableFor: initialEnableFor, disableFor: initialDisableFor, saving: false, callP2PMode: callSettings != nil ? SelectivePrivacySettingType(callSettings!) : nil, callP2PEnableFor: initialCallP2PEnableFor, callP2PDisableFor: initialCallP2PDisableFor)
        
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
        
        
        let arguments = SelectivePrivacySettingsControllerArguments(context: context, updateType: { type in
            updateState {
                $0.withUpdatedSetting(type)
            }
        }, openEnableFor: { target in
            let title: String
            switch kind {
            case .presence:
                title = L10n.privacySettingsControllerAlwaysShare
            case .groupInvitations:
                title = L10n.privacySettingsControllerAlwaysAllow
            case .voiceCalls:
                title = L10n.privacySettingsControllerAlwaysAllow
            case .profilePhoto:
                title = L10n.privacySettingsControllerAlwaysShare
            case .forwards:
                title = L10n.privacySettingsControllerAlwaysAllow

            }
            var peerIds = Set<PeerId>()
            updateState { state in
                peerIds = state.enableFor
                return state
            }
            pushControllerImpl?(SelectivePrivacySettingsPeersController(context, title: title, initialPeerIds: Array(peerIds), updated: { updatedPeerIds in
                updateState { state in
                    switch target {
                    case .main:
                        return state.withUpdatedEnableFor(Set(updatedPeerIds)).withUpdatedDisableFor(state.disableFor.subtracting(Set(updatedPeerIds)))
                    case .callP2P:
                        return state.withUpdatedCallP2PEnableFor(Set(updatedPeerIds)).withUpdatedCallP2PDisableFor(state.disableFor.subtracting(Set(updatedPeerIds)))
                    }
                }
            }))
        }, openDisableFor: { target in
            let title: String
            switch kind {
            case .presence:
                title = L10n.privacySettingsControllerNeverShareWith
            case .groupInvitations:
                title = L10n.privacySettingsControllerNeverAllow
            case .voiceCalls:
                title = L10n.privacySettingsControllerNeverAllow
            case .profilePhoto:
                title = L10n.privacySettingsControllerNeverShareWith
            case .forwards:
                title = L10n.privacySettingsControllerNeverAllow

            }
            var peerIds = Set<PeerId>()
            updateState { state in
                peerIds = state.disableFor
                return state
            }
            pushControllerImpl?(SelectivePrivacySettingsPeersController(context, title: title, initialPeerIds: Array(peerIds), updated: { updatedPeerIds in
                updateState { state in
                    switch target {
                    case .main:
                        return state.withUpdatedDisableFor(Set(updatedPeerIds)).withUpdatedEnableFor(state.enableFor.subtracting(Set(updatedPeerIds)))
                    case .callP2P:
                        return state.withUpdatedCallP2PDisableFor(Set(updatedPeerIds)).withUpdatedCallP2PEnableFor(state.enableFor.subtracting(Set(updatedPeerIds)))
                    }
                }
            }))
        }, p2pMode: { mode in
            updateState { state in
                return state.withUpdatedCallP2PMode(mode)
            }
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
                        var callSettings: SelectivePrivacySettings?
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
                            
                            if let mode = state.callP2PMode {
                                switch mode {
                                case .everybody:
                                    callSettings = SelectivePrivacySettings.enableEveryone(disableFor: state.callP2PDisableFor)
                                case .contacts:
                                    callSettings = SelectivePrivacySettings.enableContacts(enableFor: state.callP2PEnableFor, disableFor: state.callP2PDisableFor)
                                case .nobody:
                                    callSettings = SelectivePrivacySettings.disableEveryone(enableFor: state.callP2PEnableFor)
                                }
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
                            case .profilePhoto:
                                type = .profilePhoto
                            case .forwards:
                                type = .forwards
                            }
                            
                            updateSettingsDisposable.set((updateSelectiveAccountPrivacySettings(account: context.account, type: type, settings: settings) |> deliverOnMainQueue).start(completed: {
                                updateState { state in
                                    return state.withUpdatedSaving(false)
                                }
                                updated(settings, callSettings)
                                dismissImpl?()
                            }))
                        }
                    }
                }
                
                let title: String
                switch kind {
                case .presence:
                    title = L10n.privacySettingsLastSeen
                case .groupInvitations:
                    title = L10n.privacySettingsGroups
                case .voiceCalls:
                    title = L10n.privacySettingsVoiceCalls
                case .profilePhoto:
                    title = L10n.privacySettingsProfilePhoto
                case .forwards:
                    title = L10n.privacySettingsForwards
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
