//
//  SelectivePrivacySettingsController.swift
//  Telegram
//
//  Created by keepcoder on 02/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

import Postbox

enum SelectivePrivacySettingsKind {
    case presence
    case groupInvitations
    case voiceCalls
    case profilePhoto
    case forwards
    case phoneNumber
    case voiceMessages
    case bio
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
    let updatePhoneDiscovery:(Bool)->Void
    let uploadPublicPhoto:()->[ContextMenuItem]
    let removePublicPhoto:()->Void
    let toggleHideReadTime:()->Void
    let openPremium:()->Void
    init(context: AccountContext, updateType: @escaping (SelectivePrivacySettingType) -> Void, openEnableFor: @escaping (SelectivePrivacySettingsPeerTarget) -> Void, openDisableFor: @escaping (SelectivePrivacySettingsPeerTarget) -> Void, p2pMode: @escaping(SelectivePrivacySettingType) -> Void, updatePhoneDiscovery:@escaping(Bool)->Void, uploadPublicPhoto:@escaping()->[ContextMenuItem], removePublicPhoto:@escaping()->Void, toggleHideReadTime:@escaping()->Void, openPremium:@escaping()->Void) {
        self.context = context
        self.updateType = updateType
        self.openEnableFor = openEnableFor
        self.openDisableFor = openDisableFor
        self.updatePhoneDiscovery = updatePhoneDiscovery
        self.p2pMode = p2pMode
        self.uploadPublicPhoto = uploadPublicPhoto
        self.removePublicPhoto = removePublicPhoto
        self.toggleHideReadTime = toggleHideReadTime
        self.openPremium = openPremium
    }
}

private enum SelectivePrivacySettingsSection: Int32 {
    case setting
    case peers
}

private func stringForUserCount(_ count: Int) -> String {
    if count == 0 {
        return strings().privacySettingsControllerAddUsers
    } else {
        return strings().privacySettingsControllerUserCountCountable(count)
    }
}

private enum SelectivePrivacySettingsEntry: TableItemListNodeEntry {
    case settingHeader(Int32, String, GeneralViewType)
    case everybody(Int32, Bool, GeneralViewType)
    case contacts(Int32, Bool, Bool, GeneralViewType)
    case nobody(Int32, Bool, Bool, GeneralViewType)
    case p2pAlways(Int32, Bool, GeneralViewType)
    case p2pContacts(Int32, Bool, GeneralViewType)
    case p2pNever(Int32, Bool, GeneralViewType)
    case p2pHeader(Int32, String, GeneralViewType)
    case p2pDesc(Int32, String, GeneralViewType)
    case settingInfo(Int32, String, GeneralViewType)
    case disableFor(Int32, String, Int, GeneralViewType)
    case enableFor(Int32, String, Int, GeneralViewType)
    case p2pDisableFor(Int32, String, Int, GeneralViewType)
    case p2pEnableFor(Int32, String, Int, GeneralViewType)
    case p2pPeersInfo(Int32, GeneralViewType)
    case phoneDiscoveryHeader(Int32, String, GeneralViewType)
    case phoneDiscoveryEverybody(Int32, String, Bool, GeneralViewType)
    case phoneDiscoveryMyContacts(Int32, String, Bool, GeneralViewType)
    case phoneDiscoveryInfo(Int32, String, GeneralViewType)
    case peersInfo(Int32, GeneralViewType)
    case publicPhoto(Int32, String, PeerInfoUpdatingPhotoState?, GeneralViewType)
    case removePublicPhoto(Int32, TelegramUser, TelegramMediaImage, GeneralViewType)
    case publicPhotoInfo(Int32, GeneralViewType)
    case hideReadTime(Int32, Bool, GeneralViewType)
    case hideReadTimeInfo(Int32, String, GeneralViewType)
    case premium(Int32, GeneralViewType)
    case premiumInfo(Int32, GeneralViewType)
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
        case .phoneDiscoveryHeader: return 16
        case .phoneDiscoveryEverybody: return 17
        case .phoneDiscoveryMyContacts: return 18
        case .phoneDiscoveryInfo: return 19
        case .publicPhoto: return 20
        case .removePublicPhoto: return 21
        case .publicPhotoInfo: return 22
        case .hideReadTime: return 23
        case .hideReadTimeInfo: return 24
        case .premium: return 25
        case .premiumInfo: return 26
        case .section(let sectionId): return (sectionId + 1) * 1000 - sectionId
        }
    }

    var index:Int32 {
        switch self {
        case .settingHeader(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .everybody(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .contacts(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .nobody(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .publicPhoto(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .removePublicPhoto(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .publicPhotoInfo(let sectionId, _): return (sectionId * 1000) + stableId
        case .settingInfo(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .disableFor(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .enableFor(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .peersInfo(let sectionId, _):  return (sectionId * 1000) + stableId
        case .p2pAlways(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .p2pContacts(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .p2pNever(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .p2pHeader(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .p2pDesc(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .p2pDisableFor(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .p2pEnableFor(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .p2pPeersInfo(let sectionId, _): return (sectionId * 1000) + stableId
        case .phoneDiscoveryHeader(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .phoneDiscoveryEverybody(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .phoneDiscoveryMyContacts(let sectionId, _, _, _): return (sectionId * 1000) + stableId
        case .phoneDiscoveryInfo(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .hideReadTime(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .hideReadTimeInfo(let sectionId, _, _): return (sectionId * 1000) + stableId
        case .premium(let sectionId, _): return (sectionId * 1000) + stableId
        case .premiumInfo(let sectionId, _): return (sectionId * 1000) + stableId
        case .section(let sectionId): return (sectionId + 1) * 1000 - sectionId
        }
    }


    static func <(lhs: SelectivePrivacySettingsEntry, rhs: SelectivePrivacySettingsEntry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(_ arguments: SelectivePrivacySettingsControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .settingHeader(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .everybody(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsControllerEverbody, type: .selectable(value), viewType: viewType, action: {
                arguments.updateType(.everybody)
            })

        case let .contacts(_, value, locked, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsControllerMyContacts, type: .selectable(value), viewType: viewType, action: {
                arguments.updateType(.contacts)
            }, rightIcon: locked ? theme.icons.premium_lock_gray : nil)
        case let .nobody(_, value, locked, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsControllerNobody, type: .selectable(value), viewType: viewType, action: {
                arguments.updateType(.nobody)
            }, rightIcon: locked ? theme.icons.premium_lock_gray : nil)
        case let .publicPhoto(_, string, uploading, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: string, icon: theme.icons.contact_set_photo, nameStyle: blueActionButton, type: uploading != nil ? .loading : .contextSelector("", arguments.uploadPublicPhoto()), viewType: viewType)
        case let .removePublicPhoto(_, user, image, viewType):
            return UserInfoResetPhotoItem(initialSize, stableId: stableId, context: arguments.context, string: strings().privacySettingsControllerRemovePublicPhoto, style: redActionButton, user: user, image: image, viewType: viewType, action: arguments.removePublicPhoto)
        case let .publicPhotoInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsControllerSetPublicPhotoInfo, viewType: viewType)
        case let .p2pHeader(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .p2pAlways(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsControllerP2pAlways, type: .selectable(value), viewType: viewType, action: {
                arguments.p2pMode(.everybody)
            })
        case let .p2pContacts(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsControllerP2pContacts, type: .selectable(value), viewType: viewType, action: {
                arguments.p2pMode(.contacts)
            })
        case let .p2pNever(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsControllerP2pNever, type: .selectable(value), viewType: viewType, action: {
                arguments.p2pMode(.nobody)
            })
        case let .p2pDesc(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .settingInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: { _ in
                arguments.openPremium()
            }), viewType: viewType)
        case let .disableFor(_, title, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), viewType: viewType, action: {
                arguments.openDisableFor(.main)
            })
        case let .enableFor(_, title, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), viewType: viewType, action: {
                arguments.openEnableFor(.main)
            })
        case let .peersInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsControllerPeerInfo, viewType: viewType)
        case let .p2pDisableFor(_, title, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), viewType: viewType, action: {
                arguments.openDisableFor(.callP2P)
            })
        case let .p2pEnableFor(_, title, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .context(stringForUserCount(count)), viewType: viewType, action: {
                arguments.openEnableFor(.callP2P)
            })
        case let .p2pPeersInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsControllerPeerInfo, viewType: viewType)
        case let .phoneDiscoveryHeader(_, title, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: title, viewType: viewType)
        case let .phoneDiscoveryEverybody(_, title, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .selectable(selected), viewType: viewType, action: {
                arguments.updatePhoneDiscovery(true)
            })
        case let .phoneDiscoveryMyContacts(_, title, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .selectable(selected), viewType: viewType, action: {
                arguments.updatePhoneDiscovery(false)
            })
        case let .phoneDiscoveryInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .hideReadTime(_, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsHideReadTime, type: .switchable(selected), viewType: viewType, action: arguments.toggleHideReadTime)
        case let .hideReadTimeInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .premium(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsPremium, nameStyle: blueActionButton, type: .none, viewType: viewType, action: arguments.openPremium)
        case let .premiumInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsPremiumInfo, viewType: viewType)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        }
    }
}

private struct SelectivePrivacySettingsControllerState: Equatable {
    var setting: SelectivePrivacySettingType
    var enableFor: [PeerId: SelectivePrivacyPeer]
    var disableFor: [PeerId: SelectivePrivacyPeer]


    var saving: Bool

    var callP2PMode: SelectivePrivacySettingType?
    var callP2PEnableFor: [PeerId: SelectivePrivacyPeer]
    var callP2PDisableFor: [PeerId: SelectivePrivacyPeer]
    var phoneDiscoveryEnabled: Bool?
    var fallbackPhoto: TelegramMediaImage?
    var updatePhotoState: PeerInfoUpdatingPhotoState?
    var hideReadTime: Bool?

    init(setting: SelectivePrivacySettingType, enableFor: [PeerId: SelectivePrivacyPeer], disableFor: [PeerId: SelectivePrivacyPeer], saving: Bool, callP2PMode: SelectivePrivacySettingType?, callP2PEnableFor: [PeerId: SelectivePrivacyPeer], callP2PDisableFor: [PeerId: SelectivePrivacyPeer], phoneDiscoveryEnabled: Bool?, fallbackPhoto: TelegramMediaImage?, updatePhotoState: PeerInfoUpdatingPhotoState?, hideReadTime: Bool?) {
        self.setting = setting
        self.enableFor = enableFor
        self.disableFor = disableFor
        self.saving = saving
        self.callP2PMode = callP2PMode
        self.callP2PEnableFor = callP2PEnableFor
        self.callP2PDisableFor = callP2PDisableFor
        self.phoneDiscoveryEnabled = phoneDiscoveryEnabled
        self.fallbackPhoto = fallbackPhoto
        self.updatePhotoState = updatePhotoState
        self.hideReadTime = hideReadTime

    }
}

private func selectivePrivacySettingsControllerEntries(context: AccountContext, kind: SelectivePrivacySettingsKind, state: SelectivePrivacySettingsControllerState) -> [SelectivePrivacySettingsEntry] {
    var entries: [SelectivePrivacySettingsEntry] = []

    var sectionId:Int32 = 1
    entries.append(.section(sectionId))
    sectionId += 1

    let settingTitle: String
    let settingInfoText: String?
    let disableForText: String
    let enableForText: String
    switch kind {
    case .presence:
        settingTitle = strings().privacySettingsControllerLastSeenHeader
        settingInfoText = strings().privacySettingsControllerLastSeenDescription
        disableForText = strings().privacySettingsControllerNeverShareWith
        enableForText = strings().privacySettingsControllerAlwaysShareWith
    case .groupInvitations:
        settingTitle = strings().privacySettingsControllerGroupHeader
        settingInfoText = strings().privacySettingsControllerGroupDescription
        disableForText = strings().privacySettingsControllerNeverAllow
        enableForText = strings().privacySettingsControllerAlwaysAllow
    case .voiceCalls:
        settingTitle = strings().privacySettingsControllerPhoneCallHeader
        settingInfoText = strings().privacySettingsControllerPhoneCallDescription
        disableForText = strings().privacySettingsControllerNeverAllow
        enableForText = strings().privacySettingsControllerAlwaysAllow
    case .voiceMessages:
        settingTitle = strings().privacySettingsControllerVoiceMessagesHeader
        if context.isPremium {
            settingInfoText = strings().privacySettingsControllerVoiceMessagesDescription
        } else {
            settingInfoText = strings().privacySettingsControllerVoiceMessagesDescriptionNonPremium
        }
        disableForText = strings().privacySettingsControllerNeverAllow
        enableForText = strings().privacySettingsControllerAlwaysAllow
    case .profilePhoto:
        settingTitle = strings().privacySettingsControllerProfilePhotoWhoCanSeeMyPhoto
        settingInfoText = strings().privacySettingsControllerProfilePhotoCustomHelp
        disableForText = strings().privacySettingsControllerNeverShareWith
        enableForText = strings().privacySettingsControllerAlwaysShareWith
    case .bio:
        settingTitle = strings().privacySettingsControllerBioWhoCanSee
        settingInfoText = strings().privacySettingsControllerBioCustomHelp
        disableForText = strings().privacySettingsControllerNeverShareWith
        enableForText = strings().privacySettingsControllerAlwaysShareWith
    case .forwards:
        settingTitle = strings().privacySettingsControllerForwardsWhoCanForward
        settingInfoText = strings().privacySettingsControllerForwardsCustomHelp
        disableForText = strings().privacySettingsControllerNeverAllow
        enableForText = strings().privacySettingsControllerAlwaysAllow
    case .phoneNumber:
        if state.setting == .nobody {
            settingInfoText = nil
        } else {
            settingInfoText = strings().privacySettingsControllerPhoneNumberCustomHelp
        }
        settingTitle = strings().privacySettingsControllerPhoneNumberWhoCanSeePhoneNumber
        disableForText = strings().privacySettingsControllerNeverShareWith
        enableForText = strings().privacySettingsControllerAlwaysShareWith

    }

    entries.append(.settingHeader(sectionId, settingTitle, .textTopItem))

    entries.append(.everybody(sectionId, state.setting == .everybody, .firstItem))
    
    entries.append(.contacts(sectionId, state.setting == .contacts, kind == .voiceMessages && !context.isPremium, .innerItem))
    entries.append(.nobody(sectionId, state.setting == .nobody, kind == .voiceMessages && !context.isPremium, .lastItem))

    if let settingInfoText = settingInfoText {
        entries.append(.settingInfo(sectionId, settingInfoText, .textBottomItem))
    }

    
    entries.append(.section(sectionId))
    sectionId += 1
    
  
    if case .phoneNumber = kind, state.setting == .nobody {
        entries.append(.phoneDiscoveryHeader(sectionId, strings().privacyPhoneNumberSettingsDiscoveryHeader, .textTopItem))
        entries.append(.phoneDiscoveryEverybody(sectionId, strings().privacySettingsControllerEverbody, state.phoneDiscoveryEnabled != false, .firstItem))
        entries.append(.phoneDiscoveryMyContacts(sectionId, strings().privacySettingsControllerMyContacts, state.phoneDiscoveryEnabled == false, .lastItem))
        entries.append(.phoneDiscoveryInfo(sectionId, strings().privacyPhoneNumberSettingsCustomDisabledHelp, .textBottomItem))
        
        entries.append(.section(sectionId))
        sectionId += 1
    }
    

    if kind != .voiceMessages || context.isPremium {
        switch state.setting {
        case .everybody:
            entries.append(.disableFor(sectionId, disableForText, countForSelectivePeers(state.disableFor), .singleItem))
        case .contacts:
            entries.append(.disableFor(sectionId, disableForText, countForSelectivePeers(state.disableFor), .firstItem))
            entries.append(.enableFor(sectionId, enableForText, countForSelectivePeers(state.enableFor), .lastItem))
        case .nobody:
            entries.append(.enableFor(sectionId, enableForText, countForSelectivePeers(state.enableFor), .singleItem))
        }
        entries.append(.peersInfo(sectionId, .textBottomItem))
    }


    if let callSettings = state.callP2PMode {
        switch kind {
        case .voiceCalls:
            entries.append(.section(sectionId))
            sectionId += 1
            entries.append(.p2pHeader(sectionId, strings().privacySettingsControllerP2pHeader, .textTopItem))
            entries.append(.p2pAlways(sectionId, callSettings == .everybody, .firstItem))
            entries.append(.p2pContacts(sectionId, callSettings == .contacts, .innerItem))
            entries.append(.p2pNever(sectionId, callSettings == .nobody, .lastItem))
            entries.append(.p2pDesc(sectionId, strings().privacySettingsControllerP2pDesc, .textBottomItem))

            entries.append(.section(sectionId))
            sectionId += 1

            switch callSettings {
            case .everybody:
                entries.append(.p2pDisableFor(sectionId, disableForText, countForSelectivePeers(state.callP2PDisableFor), .singleItem))
            case .contacts:
                entries.append(.p2pDisableFor(sectionId, disableForText, countForSelectivePeers(state.callP2PDisableFor), .firstItem))
                entries.append(.p2pEnableFor(sectionId, enableForText, countForSelectivePeers(state.callP2PEnableFor), .lastItem))
            case .nobody:
                entries.append(.p2pEnableFor(sectionId, enableForText, countForSelectivePeers(state.callP2PEnableFor), .singleItem))
            }
            entries.append(.p2pPeersInfo(sectionId, .textBottomItem))

        default:
            break
        }
    }
    
    if case .profilePhoto = kind, state.setting == .contacts || state.setting == .nobody || !state.disableFor.isEmpty {
        
        entries.append(.section(sectionId))
        sectionId += 1

        
        entries.append(.publicPhoto(sectionId, state.fallbackPhoto != nil ? strings().privacySettingsControllerUpdatePublicPhoto : strings().privacySettingsControllerSetPublicPhoto, state.updatePhotoState, state.fallbackPhoto != nil ? .firstItem : .singleItem))
        if let image = state.fallbackPhoto, let peer = context.myPeer as? TelegramUser {
            entries.append(.removePublicPhoto(sectionId, peer, image, .lastItem))
        }
        entries.append(.publicPhotoInfo(sectionId, .textBottomItem))
        
    }
    
    if let hideReadTime = state.hideReadTime {
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.hideReadTime(sectionId, hideReadTime, .singleItem))
        entries.append(.hideReadTimeInfo(sectionId, strings().privacySettingsHideReadTimeInfo, .textBottomItem))
        
        if !context.isPremium {
            entries.append(.section(sectionId))
            sectionId += 1
            entries.append(.premium(sectionId, .singleItem))
            entries.append(.premiumInfo(sectionId, .textBottomItem))

        }
    }
    

    entries.append(.section(sectionId))
    sectionId += 1

    return entries
}

fileprivate func prepareTransition(left:[SelectivePrivacySettingsEntry], right: [SelectivePrivacySettingsEntry], initialSize:NSSize, arguments:SelectivePrivacySettingsControllerArguments) -> TableUpdateTransition {

    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.item(arguments, initialSize: initialSize)
    }

    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class SelectivePrivacySettingsController: TableViewController {
    private let kind: SelectivePrivacySettingsKind
    private let current: SelectivePrivacySettings
    private let updated: (SelectivePrivacySettings, SelectivePrivacySettings?, Bool?, GlobalPrivacySettings?) -> Void
    private var savePressed:(()->Void)?
    private let callSettings: SelectivePrivacySettings?
    private let phoneDiscoveryEnabled: Bool?
    private let globalSettings: GlobalPrivacySettings?
    init(_ context: AccountContext, kind: SelectivePrivacySettingsKind, current: SelectivePrivacySettings, callSettings: SelectivePrivacySettings? = nil, phoneDiscoveryEnabled: Bool?, globalSettings: GlobalPrivacySettings? = nil, updated: @escaping (SelectivePrivacySettings, SelectivePrivacySettings?, Bool?, GlobalPrivacySettings?) -> Void) {
        self.kind = kind
        self.current = current
        self.updated = updated
        self.phoneDiscoveryEnabled = phoneDiscoveryEnabled
        self.callSettings = callSettings
        self.globalSettings = globalSettings
        super.init(context)
    }



    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let kind = self.kind
        let current = self.current
        let updated = self.updated

        let initialSize = self.atomicSize
        let previous:Atomic<[SelectivePrivacySettingsEntry]> = Atomic(value: [])

        var initialEnableFor: [PeerId: SelectivePrivacyPeer] = [:]
        var initialDisableFor: [PeerId: SelectivePrivacyPeer] = [:]

        switch current {
        case let .disableEveryone(enableFor, enableForCloseFriends):
            initialEnableFor = enableFor
        case let .enableContacts(enableFor, disableFor):
            initialEnableFor = enableFor
            initialDisableFor = disableFor
        case let .enableEveryone(disableFor):
            initialDisableFor = disableFor
        }

        var initialCallP2PEnableFor: [PeerId: SelectivePrivacyPeer] = [:]
        var initialCallP2PDisableFor: [PeerId: SelectivePrivacyPeer] = [:]

        if let callCurrent = callSettings {
            switch callCurrent {
            case let .disableEveryone(enableFor, enableForCloseFriends):
                initialCallP2PEnableFor = enableFor
                initialCallP2PDisableFor = [:]
            case let .enableContacts(enableFor, disableFor):
                initialCallP2PEnableFor = enableFor
                initialCallP2PDisableFor = disableFor
            case let .enableEveryone(disableFor):
                initialCallP2PEnableFor = [:]
                initialCallP2PDisableFor = disableFor
            }

        }


        let initialState = SelectivePrivacySettingsControllerState(setting: SelectivePrivacySettingType(current), enableFor: initialEnableFor, disableFor: initialDisableFor, saving: false, callP2PMode: callSettings != nil ? SelectivePrivacySettingType(callSettings!) : nil, callP2PEnableFor: initialCallP2PEnableFor, callP2PDisableFor: initialCallP2PDisableFor, phoneDiscoveryEnabled: phoneDiscoveryEnabled, fallbackPhoto: nil, updatePhotoState: nil, hideReadTime: self.globalSettings?.hideReadTime)

        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((SelectivePrivacySettingsControllerState) -> SelectivePrivacySettingsControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }

        var dismissImpl: (() -> Void)?
        var pushControllerImpl: ((ViewController) -> Void)?

        let actionsDisposable = DisposableSet()
        let updatePhotoDisposable = MetaDisposable()
        let updateSettingsDisposable = MetaDisposable()

        actionsDisposable.add(updatePhotoDisposable)
        
        
        let globalSettings = self.globalSettings
      //  actionsDisposable.add(updateSettingsDisposable)
        
        func _updatePhoto(_ path:String) -> Void {
            
            let cancel = {
                updatePhotoDisposable.set(nil)
                updateState { current in
                    var current = current
                    current.updatePhotoState = nil
                    return current
                }
            }
            
            let updateSignal = Signal<String, NoError>.single(path) |> map { path -> TelegramMediaResource in
                return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
                } |> beforeNext { resource in
                    updateState { current in
                        var current = current
                        current.updatePhotoState = PeerInfoUpdatingPhotoState(progress: 0, image: NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil), cancel: cancel)
                        return current
                    }
                } |> castError(UploadPeerPhotoError.self) |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                    return context.engine.accountData.updateFallbackPhoto(resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                    })
            }
            
            updatePhotoDisposable.set((updateSignal |> deliverOnMainQueue).start(next: { status in
                updateState { current in
                    var current = current
                    switch status {
                    case .complete:
                        return current
                    case let .progress(progress):
                        current.updatePhotoState = current.updatePhotoState?.withUpdatedProgress(progress)
                    }
                    return current
                }
            }, error: { error in
                updateState { current in
                    var current = current
                    current.updatePhotoState = nil
                    return current
                }
            }, completed: {
                updateState { current in
                    var current = current
                    current.updatePhotoState = nil
                    return current
                }
            }))
        }
        
        func _updateVideo(_ signal:Signal<VideoAvatarGeneratorState, NoError>) -> Void {

            let cancel = { [weak self] in
                updatePhotoDisposable.set(nil)
                updateState { current in
                    var current = current
                    current.updatePhotoState = nil
                    return current
                }
            }
            
            
            let updateSignal: Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> = signal
                |> castError(UploadPeerPhotoError.self)
                |> mapToSignal { state in
                    switch state {
                    case .error:
                        return .fail(.generic)
                    case let .start(path):
                        updateState { current in
                            var current = current
                            current.updatePhotoState = PeerInfoUpdatingPhotoState(progress: 0, image: NSImage(contentsOfFile: path)?._cgImage, cancel: cancel)
                            return current
                        }
                        return .next(.progress(0))
                    case let .progress(value):
                        return .next(.progress(value * 0.2))
                    case let .complete(thumb, video, keyFrame):
                        
                        updateState { current in
                            var current = current
                            current.updatePhotoState = PeerInfoUpdatingPhotoState(progress: 0.2, image: NSImage(contentsOfFile: thumb)?._cgImage, cancel: cancel)
                            return current
                        }
                        
                        let (thumbResource, videoResource) = (LocalFileReferenceMediaResource(localFilePath: thumb, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true),
                                                              LocalFileReferenceMediaResource(localFilePath: video, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true))
                                            
                        return context.engine.accountData.updateFallbackPhoto(resource: thumbResource, videoResource: videoResource, videoStartTimestamp: keyFrame, markup: nil, mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                        }) |> mapToSignal { result in
                            switch result {
                            case let .progress(current):
                                if current == 1.0 {
                                    return .single(.complete([]))
                                } else {
                                    return .next(.progress(0.2 + (current * 0.8)))
                                }
                            default:
                                return .complete()
                            }
                        }
                    }
            }
            
            updatePhotoDisposable.set((updateSignal |> deliverOnMainQueue).start(next: { status in
                updateState { current in
                    var current = current
                                    
                    switch status {
                    case .complete:
                        current.updatePhotoState = nil
                    case let .progress(progress):
                        current.updatePhotoState = current.updatePhotoState?.withUpdatedProgress(progress)
                    }
                    return current
                }
            }, error: { error in
                updateState { current in
                    var current = current
                    current.updatePhotoState = nil
                    return current
                }
            }, completed: {
                updateState { current in
                    var current = current
                    current.updatePhotoState = nil
                    return current
                }
            }))
        }
        
        func makeUpdatePhotoItems() -> [ContextMenuItem] {
            
            let updatePhoto:(Signal<NSImage, NoError>) -> Void = { [weak self] image in
                let signal = image |> mapToSignal { image in
                    return putToTemp(image: image, compress: true)
                } |> deliverOnMainQueue
                _ = signal.start(next: { [weak self] path in
                    let controller = EditImageModalController(URL(fileURLWithPath: path), context: context, settings: .disableSizes(dimensions: .square))
                    showModal(with: controller, for: context.window, animationType: .scaleCenter)
                    _ = controller.result.start(next: { [weak self] url, _ in
                        DispatchQueue.main.async {
                            _updatePhoto(url.path)
                        }
                    })
                })
            }
            let context = self.context
            
            let makeVideo:(MediaObjectToAvatar)->Void = { object in
                
                switch object.object.foreground.type {
                case .emoji:
                    updatePhoto(object.start() |> mapToSignal { value in
                        if let result = value.result {
                            switch result {
                            case let .image(image):
                                return .single(image)
                            default:
                                return .never()
                            }
                        } else {
                            return .never()
                        }
                    })
                default:
                    let signal:Signal<VideoAvatarGeneratorState, NoError> = object.start() |> map { value in
                        if let result = value.result {
                            switch result {
                            case let .video(path, thumb):
                                return .complete(thumb: thumb, video: path, keyFrame: nil)
                            default:
                                return .error
                            }
                        } else if let status = value.status {
                            switch status {
                            case let .initializing(thumb):
                                return .start(thumb: thumb)
                            case let .converting(progress):
                                return .progress(progress)
                            default:
                                return .error
                            }
                        } else {
                            return .error
                        }
                    }
                    _updateVideo(signal)
                }
            }
            
            
            var items:[ContextMenuItem] = []
            
            items.append(.init(strings().editAvatarPhotoOrVideo, handler: {
                filePanel(with: photoExts + videoExts, allowMultiple: false, canChooseDirectories: false, for: context.window, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        updatePhoto(.single(image))
                    } else if let path = paths?.first {
                        selectVideoAvatar(context: context, path: path, localize: "", signal: { signal in
                            _updateVideo(signal)
                        })
                    }
                })
            }, itemImage: MenuAnimation.menu_shared_media.value))

            items.append(.init(strings().editAvatarCustomize, handler: {
                showModal(with: AvatarConstructorController(context, target: .avatar, videoSignal: makeVideo), for: context.window)
            }, itemImage: MenuAnimation.menu_view_sticker_set.value))
            
            return items
        }



        let arguments = SelectivePrivacySettingsControllerArguments(context: context, updateType: { type in
            if kind == .voiceMessages, !context.isPremium {
                showModalText(for: context.window, text: strings().privacySettingsVoicePremiumError, button: strings().alertLearnMore, callback: { _ in
                    showModal(with: PremiumBoardingController(context: context), for: context.window)
                })
                return
            }
            updateState { current in
                var current = current
                current.setting = type
                return current
            }
        }, openEnableFor: { target in
            let title: String
            switch kind {
            case .presence:
                title = strings().privacySettingsControllerAlwaysShare
            case .groupInvitations:
                title = strings().privacySettingsControllerAlwaysAllow
            case .voiceCalls:
                title = strings().privacySettingsControllerAlwaysAllow
            case .profilePhoto:
                title = strings().privacySettingsControllerAlwaysShare
            case .forwards:
                title = strings().privacySettingsControllerAlwaysAllow
            case .phoneNumber:
                title = strings().privacySettingsControllerAlwaysShareWith
            case .voiceMessages:
                title = strings().privacySettingsControllerAlwaysAllow
            case .bio:
                title = strings().privacySettingsControllerAlwaysShare

            }
            var peerIds:[PeerId: SelectivePrivacyPeer] = [:]
            updateState { state in
                peerIds = state.enableFor
                return state
            }
            pushControllerImpl?(SelectivePrivacySettingsPeersController(context, title: title, initialPeers: peerIds, updated: { updatedPeerIds in
                updateState { current in
                    var current = current
                    switch target {
                    case .main:
                        var disableFor = current.disableFor
                        for (key, _) in updatedPeerIds {
                            disableFor.removeValue(forKey: key)
                        }
                        current.enableFor = updatedPeerIds
                        current.disableFor = disableFor
                    case .callP2P:
                        var callP2PDisableFor = current.callP2PDisableFor
                        //var disableFor = state.disableFor
                        for (key, _) in updatedPeerIds {
                            callP2PDisableFor.removeValue(forKey: key)
                        }
                        current.callP2PEnableFor = updatedPeerIds
                        current.callP2PDisableFor = callP2PDisableFor
                    }
                    return current
                }
            }))
        }, openDisableFor: { target in
            let title: String
            switch kind {
            case .presence:
                title = strings().privacySettingsControllerNeverShareWith
            case .groupInvitations:
                title = strings().privacySettingsControllerNeverAllow
            case .voiceCalls:
                title = strings().privacySettingsControllerNeverAllow
            case .voiceMessages:
                title = strings().privacySettingsControllerNeverAllow
            case .profilePhoto:
                title = strings().privacySettingsControllerNeverShareWith
            case .forwards:
                title = strings().privacySettingsControllerNeverAllow
            case .phoneNumber:
                title = strings().privacySettingsControllerNeverShareWith
            case .bio:
                title = strings().privacySettingsControllerNeverShareWith
            }
            var peerIds:[PeerId: SelectivePrivacyPeer] = [:]
            updateState { state in
                peerIds = state.disableFor
                return state
            }
            pushControllerImpl?(SelectivePrivacySettingsPeersController(context, title: title, initialPeers: peerIds, updated: { updatedPeerIds in
                updateState { current in
                    var current = current
                    switch target {
                    case .main:
                        var enableFor = current.enableFor
                        for (key, _) in updatedPeerIds {
                            enableFor.removeValue(forKey: key)
                        }
                        current.disableFor = updatedPeerIds
                        current.enableFor = enableFor
                    case .callP2P:
                        var callP2PEnableFor = current.callP2PEnableFor
                        for (key, _) in updatedPeerIds {
                            callP2PEnableFor.removeValue(forKey: key)
                        }
                        current.callP2PDisableFor = updatedPeerIds
                        current.callP2PEnableFor = callP2PEnableFor
                    }
                    return current
                }
            }))
        }, p2pMode: { mode in
            updateState { current in
                var current = current
                current.callP2PMode = mode
                return current
            }
        }, updatePhoneDiscovery: { value in
            updateState { current in
                var current = current
                current.phoneDiscoveryEnabled = value
                return current
            }
        }, uploadPublicPhoto: {
            return makeUpdatePhotoItems()
            
        }, removePublicPhoto: {
            verifyAlert_button(for: context.window, information: strings().privacyResetPhotoConfirm, ok: strings().modalRemove, successHandler: { _ in
                
                let signal = context.engine.accountData.removeFallbackPhoto(reference: nil)
                |> castError(UploadPeerPhotoError.self)

                _ = showModalProgress(signal: signal, for: context.window).start()
            })
        }, toggleHideReadTime: {
            updateState { current in
                var current = current
                if let value = current.hideReadTime {
                    current.hideReadTime = !value
                }
                return current
            }
        }, openPremium: {
            showModal(with: PremiumBoardingController(context: context, source: .last_seen, openFeatures: true), for: context.window)
        })


        savePressed = {
            var wasSaving = false
            var settings: SelectivePrivacySettings?
            var callSettings: SelectivePrivacySettings?
            var phoneDiscoveryEnabled: Bool? = nil
            updateState { current in
                var current = current
                phoneDiscoveryEnabled = current.phoneDiscoveryEnabled
                wasSaving = current.saving
                switch current.setting {
                case .everybody:
                    settings = SelectivePrivacySettings.enableEveryone(disableFor: current.disableFor)
                case .contacts:
                    settings = SelectivePrivacySettings.enableContacts(enableFor: current.enableFor, disableFor: current.disableFor)
                case .nobody:
                    settings = SelectivePrivacySettings.disableEveryone(enableFor: current.enableFor, enableForCloseFriends: false)
                }

                if let mode = current.callP2PMode {
                    switch mode {
                    case .everybody:
                        callSettings = SelectivePrivacySettings.enableEveryone(disableFor: current.callP2PDisableFor)
                    case .contacts:
                        callSettings = SelectivePrivacySettings.enableContacts(enableFor: current.callP2PEnableFor, disableFor: current.callP2PDisableFor)
                    case .nobody:
                        callSettings = SelectivePrivacySettings.disableEveryone(enableFor: current.callP2PEnableFor, enableForCloseFriends: false)
                    }
                }
                current.saving = true
                return current
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
                case .phoneNumber:
                    type = .phoneNumber
                case .voiceMessages:
                    type = .voiceMessages
                case .bio:
                    type = .bio
                }
                
                var updatePhoneDiscoverySignal: Signal<Void, NoError> = Signal.complete()
                if let phoneDiscoveryEnabled = phoneDiscoveryEnabled {
                    updatePhoneDiscoverySignal = context.engine.privacy.updatePhoneNumberDiscovery(value: phoneDiscoveryEnabled)
                }
                
                let basic = context.engine.privacy.updateSelectiveAccountPrivacySettings(type: type, settings: settings)
                let global: Signal<Never, NoError>
                var gSettings: GlobalPrivacySettings? = globalSettings
                if var globalSettings = globalSettings {
                    globalSettings.hideReadTime = stateValue.with { $0.hideReadTime ?? false }
                    global = context.engine.privacy.updateGlobalPrivacySettings(settings: globalSettings)
                    gSettings = globalSettings
                } else {
                    global = .complete()
                }

                updateSettingsDisposable.set(combineLatest(queue: .mainQueue(), updatePhoneDiscoverySignal, basic, global).start(completed: {
                    updateState { current in
                        var current = current
                        current.saving = false
                        return current
                    }
                    updated(settings, callSettings, phoneDiscoveryEnabled, gSettings)
                    dismissImpl?()
                }))
            }
        }

        let signal = statePromise.get() |> deliverOnMainQueue
            |> map { [weak self] state -> TableUpdateTransition in


                let title: String
                switch kind {
                case .presence:
                    title = strings().privacySettingsLastSeen
                case .groupInvitations:
                    title = strings().privacySettingsGroups
                case .voiceCalls:
                    title = strings().privacySettingsVoiceCalls
                case .profilePhoto:
                    title = strings().privacySettingsProfilePhoto
                case .forwards:
                    title = strings().privacySettingsForwards
                case .phoneNumber:
                    title = strings().privacySettingsPhoneNumber
                case .voiceMessages:
                    title = strings().privacySettingsVoiceMessages
                case .bio:
                    title = strings().privacySettingsBio
                }

                self?.setCenterTitle(title)

                let entries = selectivePrivacySettingsControllerEntries(context: context, kind: kind, state: state)
                return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
            } |> afterDisposed {
                actionsDisposable.dispose()
        }
        
        actionsDisposable.add(getCachedDataView(peerId: context.peerId, postbox: context.account.postbox).start(next: { cachedData in
            updateState { current in
                var current = current
                current.fallbackPhoto = cachedData?.fallbackPhoto
                return current
            }
        }))

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
    }

    override func didRemovedFromStack() {
        super.didRemovedFromStack()
        savePressed?()
    }
}
