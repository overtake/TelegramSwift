//
//  ChannelPermissionsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore

private final class ChannelPermissionsControllerArguments {
    let context: AccountContext
    
    let updatePermission: (TelegramChatBannedRightsFlags, Bool) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addPeer: () -> Void
    let removePeer: (PeerId) -> Void
    let openPeer: (ChannelParticipant) -> Void
    let openPeerInfo: (Peer) -> Void
    let openKicked: () -> Void
    let presentRestrictedPublicGroupPermissionsAlert: () -> Void
    let updateSlowMode:(Int32)->Void
    init(context: AccountContext, updatePermission: @escaping (TelegramChatBannedRightsFlags, Bool) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addPeer: @escaping  () -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (ChannelParticipant) -> Void, openPeerInfo: @escaping (Peer) -> Void, openKicked: @escaping () -> Void, presentRestrictedPublicGroupPermissionsAlert: @escaping() -> Void, updateSlowMode:@escaping(Int32)->Void) {
        self.context = context
        self.updatePermission = updatePermission
        self.addPeer = addPeer
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.openPeer = openPeer
        self.openPeerInfo = openPeerInfo
        self.openKicked = openKicked
        self.presentRestrictedPublicGroupPermissionsAlert = presentRestrictedPublicGroupPermissionsAlert
        self.updateSlowMode = updateSlowMode
    }
}

private enum ChannelPermissionsSection: Int32 {
    case permissions
    case kicked
    case exceptions
}

private enum ChannelPermissionsEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
    case section(Int32)
    case permission(Int32)
}

private enum ChannelPermissionsEntry: TableItemListNodeEntry {
    case section(Int32)
    case permissionsHeader(Int32, Int32, String, GeneralViewType)
    case permission(Int32, Int32, String, Bool, TelegramChatBannedRightsFlags, Bool?, GeneralViewType)
    case kicked(Int32, Int32, String, String, GeneralViewType)
    case exceptionsHeader(Int32, Int32, String, GeneralViewType)
    case add(Int32, Int32, String, GeneralViewType)
    case peerItem(Int32, Int32, RenderedChannelParticipant, ShortPeerDeleting?, Bool, Bool, TelegramChatBannedRightsFlags, GeneralViewType)
    case slowModeHeader(Int32, GeneralViewType)
    case slowMode(Int32, Int32?, GeneralViewType)
    case slowDesc(Int32, Int32?, GeneralViewType)
    var stableId: ChannelPermissionsEntryStableId {
        switch self {
        case .permissionsHeader:
            return .index(0)
        case let .permission(_, index, _, _, _, _, _):
            return .permission(1 + index)
        case .kicked:
            return .index(1000)
        case .slowModeHeader:
            return .index(1001)
        case .slowMode:
            return .index(1003)
        case .slowDesc:
            return .index(1004)
        case .exceptionsHeader:
            return .index(1005)
        case .add:
            return .index(1006)
        case let .section(section):
            return .section(section)
        case let .peerItem( _, _, participant, _, _, _, _, _):
            return .peer(participant.peer.id)
        }
    }
    
    var index: Int32 {
        switch self {
        case let .permissionsHeader(section, index, _, _):
            return (section * 1000) + index
        case let .permission(section, index, _, _, _, _, _):
             return (section * 1000) + index
        case let .kicked(section, index, _, _, _):
             return (section * 1000) + index
        case let .slowMode(section, _, _):
            return (section * 1000) + 0
        case let .slowModeHeader(section, _):
            return (section * 1000) + 1
        case let .slowDesc(section, _, _):
            return (section * 1000) + 1
        case let .exceptionsHeader(section, index, _, _):
            return (section * 1000) + index
        case let .add(section, index, _, _):
            return (section * 1000) + index
        case let .section(section):
            return (section + 1) * 1000 - section
        case let .peerItem(section, index, _, _, _, _, _, _):
             return (section * 1000) + index
        }
    }
    
    static func <(lhs: ChannelPermissionsEntry, rhs: ChannelPermissionsEntry) -> Bool {
        return lhs.index < rhs.index
    }
    

    
    func item(_ arguments: ChannelPermissionsControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .permissionsHeader(_, _, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .permission(_, _, title, value, rights, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .switchable(value), viewType: viewType, action: {
                if let _ = enabled {
                    arguments.updatePermission(rights, !value)
                } else {
                    arguments.presentRestrictedPublicGroupPermissionsAlert()
                }
            }, enabled: enabled ?? true, switchAppearance: SwitchViewAppearance(backgroundColor: theme.colors.background, stateOnColor: enabled == true ? theme.colors.accent : theme.colors.accent.withAlphaComponent(0.6), stateOffColor: enabled == true ? theme.colors.redUI : theme.colors.redUI.withAlphaComponent(0.6), disabledColor: .grayBackground, borderColor: .clear), autoswitch: false)
        case let .kicked(_, _, text, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .nextContext(value), viewType: viewType, action: {
                arguments.openKicked()
            })
//            return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
//                arguments.openKicked()
//            })
        case let .exceptionsHeader(_, _, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .add(_, _, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: text, nameStyle: blueActionButton, type: .none, viewType: viewType, action: { () in
                arguments.addPeer()
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 52, thumbInset: 5))
          
        case let .peerItem(_, _, participant, _, enabled, canOpen, defaultBannedRights, viewType):
            var text: String?
            switch participant.participant {
            case let .member(_, _, _, banInfo, _):
                var exceptionsString = ""
                if let banInfo = banInfo {
                    for rights in allGroupPermissionList {
                        if !defaultBannedRights.contains(rights) && banInfo.rights.flags.contains(rights) {
                            if !exceptionsString.isEmpty {
                                exceptionsString.append(", ")
                            }
                            exceptionsString.append(compactStringForGroupPermission(right: rights))
                        }
                    }
                    text = exceptionsString
                }
            default:
                break
            }
            
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.context.account, stableId: stableId, enabled: enabled, status: text, inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: viewType, action: {
                if canOpen {
                    arguments.openPeer(participant.participant)
                } else {
                    arguments.openPeerInfo(participant.peer)
                }
            })
        case let .slowModeHeader(_, viewType):
            return GeneralTextRowItem(initialSize, text: L10n.channelPermissionsSlowModeHeader, viewType: viewType)
        case let .slowMode(_, timeout, viewType):
            let list:[Int32] = [0, 10, 30, 60, 300, 900, 3600]
            let titles: [String] = [L10n.channelPermissionsSlowModeTimeoutOff,
                                    L10n.channelPermissionsSlowModeTimeout10s,
                                    L10n.channelPermissionsSlowModeTimeout30s,
                                    L10n.channelPermissionsSlowModeTimeout1m, L10n.channelPermissionsSlowModeTimeout5m,
                                    L10n.channelPermissionsSlowModeTimeout15m,
                                    L10n.channelPermissionsSlowModeTimeout1h]
            return SelectSizeRowItem(initialSize, stableId: stableId, current: timeout ?? 0, sizes: list, hasMarkers: false, titles: titles, viewType: viewType, selectAction: { index in
               arguments.updateSlowMode(list[index])
            })
        case let .slowDesc(_, timeout, viewType):
            let text: String
            if let timeout = timeout, timeout > 0 {
                text = L10n.channelPermissionsSlowModeTextSelected(autoremoveLocalized(Int(timeout)))
            } else {
                text = L10n.channelPermissionsSlowModeTextOff
            }
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        }
    }
}

private struct ChannelPermissionsControllerState: Equatable {
    var peerIdWithRevealedOptions: PeerId?
    var removingPeerId: PeerId?
    var searchingMembers: Bool = false
    var modifiedRightsFlags: TelegramChatBannedRightsFlags?
}

func stringForGroupPermission(right: TelegramChatBannedRightsFlags) -> String {
    if right.contains(.banSendMessages) {
        return L10n.channelBanUserPermissionSendMessages
    } else if right.contains(.banSendMedia) {
        return L10n.channelBanUserPermissionSendMedia
    } else if right.contains(.banSendGifs) {
        return L10n.channelBanUserPermissionSendStickersAndGifs
    } else if right.contains(.banEmbedLinks) {
        return L10n.channelBanUserPermissionEmbedLinks
    } else if right.contains(.banSendPolls) {
        return L10n.channelBanUserPermissionSendPolls
    } else if right.contains(.banChangeInfo) {
        return L10n.channelBanUserPermissionChangeGroupInfo
    } else if right.contains(.banAddMembers) {
        return L10n.channelBanUserPermissionAddMembers
    } else if right.contains(.banPinMessages) {
        return L10n.channelEditAdminPermissionPinMessages
    } else {
        return ""
    }
}

func compactStringForGroupPermission(right: TelegramChatBannedRightsFlags) -> String {
    if right.contains(.banSendMessages) {
        return L10n.groupPermissionNoSendMessages
    } else if right.contains(.banSendMedia) {
        return L10n.groupPermissionNoSendMedia
    } else if right.contains(.banSendGifs) {
        return L10n.groupPermissionNoSendGifs
    } else if right.contains(.banEmbedLinks) {
        return L10n.groupPermissionNoSendLinks
    } else if right.contains(.banSendPolls) {
        return L10n.groupPermissionNoSendPolls
    } else if right.contains(.banChangeInfo) {
        return L10n.groupPermissionNoChangeInfo
    } else if right.contains(.banAddMembers) {
        return L10n.groupPermissionNoAddMembers
    } else if right.contains(.banPinMessages) {
        return L10n.groupPermissionNoPinMessages
    } else {
        return ""
    }
}

let allGroupPermissionList: [TelegramChatBannedRightsFlags] = [
    .banSendMessages,
    .banSendMedia,
    .banSendGifs,
    .banEmbedLinks,
    .banSendPolls,
    .banAddMembers,
    .banPinMessages,
    .banChangeInfo
]

let publicGroupRestrictedPermissions: TelegramChatBannedRightsFlags = [
    .banPinMessages,
    .banChangeInfo
]


func groupPermissionDependencies(_ right: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    if right.contains(.banSendMedia) {
        return [.banSendMessages]
    } else if right.contains(.banSendGifs) {
        return [.banSendMessages]
    } else if right.contains(.banEmbedLinks) {
        return [.banSendMessages]
    } else if right.contains(.banSendPolls) {
        return [.banSendMessages]
    } else if right.contains(.banChangeInfo) {
        return []
    } else if right.contains(.banAddMembers) {
        return []
    } else if right.contains(.banPinMessages) {
        return []
    } else {
        return []
    }
}

private func completeRights(_ flags: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    var result = flags
    result.remove(.banReadMessages)
    if result.contains(.banSendGifs) {
        result.insert(.banSendStickers)
        result.insert(.banSendGifs)
        result.insert(.banSendGames)
        result.insert(.banSendInline)
    } else {
        result.remove(.banSendStickers)
        result.remove(.banSendGifs)
        result.remove(.banSendGames)
        result.remove(.banSendInline)
    }
    return result
}

private func channelPermissionsControllerEntries(view: PeerView, state: ChannelPermissionsControllerState, participants: [RenderedChannelParticipant]?) -> [ChannelPermissionsEntry] {
    var entries: [ChannelPermissionsEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    
    if let channel = view.peers[view.peerId] as? TelegramChannel, let participants = participants, let cachedData = view.cachedData as? CachedChannelData, let defaultBannedRights = channel.defaultBannedRights {
        
        
        let effectiveRightsFlags: TelegramChatBannedRightsFlags
        if let modifiedRightsFlags = state.modifiedRightsFlags {
            effectiveRightsFlags = modifiedRightsFlags
        } else {
            effectiveRightsFlags = defaultBannedRights.flags
        }

        
        entries.append(.permissionsHeader(sectionId, index, L10n.groupInfoPermissionsSectionTitle, .textTopItem))
        index += 1
        for (i, rights) in allGroupPermissionList.enumerated() {
            var enabled: Bool? = true
            if channel.addressName != nil && publicGroupRestrictedPermissions.contains(rights) {
                enabled = nil
            }
            entries.append(.permission(sectionId, index, stringForGroupPermission(right: rights), !effectiveRightsFlags.contains(rights), rights, enabled, bestGeneralViewType(allGroupPermissionList, for: i)))
            index += 1
        }
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        
        entries.append(.slowModeHeader(sectionId, .textTopItem))
        entries.append(.slowMode(sectionId, cachedData.slowModeTimeout, .singleItem))
        entries.append(.slowDesc(sectionId, cachedData.slowModeTimeout, .textBottomItem))
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.kicked(sectionId, index, L10n.groupInfoPermissionsRemoved, cachedData.participantsSummary.kickedCount.flatMap({ "\($0 > 0 ? "\($0)" : "")" }) ?? "", .singleItem))
        index += 1
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.exceptionsHeader(sectionId, index, L10n.groupInfoPermissionsExceptions, .textTopItem))
        index += 1
        
        
        
        
        
        entries.append(.add(sectionId, index, L10n.groupInfoPermissionsAddException, participants.isEmpty ? .singleItem : .firstItem))
        index += 1
        for (i, participant) in participants.enumerated() {
            entries.append(.peerItem(sectionId, index, participant, ShortPeerDeleting(editable: true), state.removingPeerId != participant.peer.id, true, effectiveRightsFlags, i == 0 ? .innerItem : bestGeneralViewType(participants, for: i)))
            index += 1
        }
    } else if let group = view.peers[view.peerId] as? TelegramGroup, let _ = view.cachedData as? CachedGroupData, let defaultBannedRights = group.defaultBannedRights {
        let effectiveRightsFlags: TelegramChatBannedRightsFlags
        if let modifiedRightsFlags = state.modifiedRightsFlags {
            effectiveRightsFlags = modifiedRightsFlags
        } else {
            effectiveRightsFlags = defaultBannedRights.flags
        }
        
        entries.append(.permissionsHeader(sectionId, index, L10n.groupInfoPermissionsSectionTitle, .textTopItem))
        index += 1
        
        for (i, rights) in allGroupPermissionList.enumerated() {
            entries.append(.permission(sectionId, index, stringForGroupPermission(right: rights), !effectiveRightsFlags.contains(rights), rights, true, bestGeneralViewType(allGroupPermissionList, for: i)))
            index += 1
        }
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.slowModeHeader(sectionId, .textTopItem))
        entries.append(.slowMode(sectionId, nil, .singleItem))
        entries.append(.slowDesc(sectionId, nil, .textBottomItem))
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.exceptionsHeader(sectionId, index, L10n.groupInfoPermissionsExceptions, .textTopItem))
        index += 1
        entries.append(.add(sectionId, index, L10n.groupInfoPermissionsAddException, .singleItem))
        index += 1
        
        entries.append(.section(sectionId))
        sectionId += 1
    }
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    return entries
}
fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelPermissionsEntry>], right: [AppearanceWrapperEntry<ChannelPermissionsEntry>], initialSize:NSSize, arguments:ChannelPermissionsControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


final class ChannelPermissionsController : TableViewController {
    
    private let peerId: PeerId
    private let disposable = MetaDisposable()
    init(_ context: AccountContext, peerId: PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    fileprivate let interfaceFullReady: Promise<Bool> = Promise()
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let peerId = self.peerId
        let context = self.context
        
        let statePromise = ValuePromise(ChannelPermissionsControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: ChannelPermissionsControllerState())
        let updateState: ((ChannelPermissionsControllerState) -> ChannelPermissionsControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        var stopMerging: Bool = false
        
        let actionsDisposable = DisposableSet()
        
        let updateBannedDisposable = MetaDisposable()
        actionsDisposable.add(updateBannedDisposable)
        
        let removePeerDisposable = MetaDisposable()
        actionsDisposable.add(removePeerDisposable)
        
        
        var upgradedToSupergroupImpl: ((PeerId, @escaping () -> Void) -> Void)?
        
        let upgradedToSupergroup: (PeerId, @escaping () -> Void) -> Void = { upgradedPeerId, f in
            upgradedToSupergroupImpl?(upgradedPeerId, f)
        }

        
        let restrict:(ChannelParticipant, Bool) -> Void = { participant, unban in
            showModal(with: RestrictedModalViewController(context, peerId: peerId, memberId: participant.peerId, initialParticipant: participant, updated: { updatedRights in
                switch participant {
                case let .member(memberId, _, _, _, _):
                    
                    
                    let signal: Signal<PeerId?, ConvertGroupToSupergroupError>
                    
                    if peerId.namespace == Namespaces.Peer.CloudGroup {
                        stopMerging = true
                        signal = convertGroupToSupergroup(account: context.account, peerId: peerId)
                            |> map(Optional.init)
                            |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                guard let upgradedPeerId = upgradedPeerId else {
                                    return .single(nil)
                                }
                                return context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: upgradedPeerId, memberId: memberId, bannedRights: updatedRights)
                                    |> castError(ConvertGroupToSupergroupError.self)
                                    |> mapToSignal { _ -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                        return .complete()
                                    }
                                    |> then(.single(upgradedPeerId) |> castError(ConvertGroupToSupergroupError.self))
                            }
                            |> deliverOnMainQueue
                    } else {
                        signal = context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: peerId, memberId: memberId, bannedRights: updatedRights)
                            |> map {_ in return nil}
                            |> castError(ConvertGroupToSupergroupError.self)
                            |> deliverOnMainQueue
                    }
                    
                    updateBannedDisposable.set(showModalProgress(signal: signal, for: context.window).start(next: { upgradedPeerId in
                        if let upgradedPeerId = upgradedPeerId {
                            upgradedToSupergroup(upgradedPeerId, {
                                
                            })
                        }
                    }, error: { error in
                        switch error {
                        case .tooManyChannels:
                            showInactiveChannels(context: context, source: .upgrade)
                        case .generic:
                            alert(for: context.window, info: L10n.unknownError)
                        }
                    }))
                default:
                    break
                }
                
                
            }), for: context.window)
        }
        
        let peersPromise = Promise<[RenderedChannelParticipant]?>(nil)
        let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.restricted(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { state in
            peersPromise.set(.single(state.list))
        })
        actionsDisposable.add(disposable)
        
        let updateDefaultRightsDisposable = MetaDisposable()
        actionsDisposable.add(updateDefaultRightsDisposable)
        
        let peerView = Promise<PeerView>()
        peerView.set(context.account.viewTracker.peerView(peerId))
        
        let arguments = ChannelPermissionsControllerArguments(context: context, updatePermission: { rights, value in
            let _ = (peerView.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { view in
                    if let channel = view.peers[peerId] as? TelegramChannel, let _ = view.cachedData as? CachedChannelData {
                        updateState { state in
                            var state = state
                            var effectiveRightsFlags: TelegramChatBannedRightsFlags
                            if let modifiedRightsFlags = state.modifiedRightsFlags {
                                effectiveRightsFlags = modifiedRightsFlags
                            } else if let defaultBannedRightsFlags = channel.defaultBannedRights?.flags {
                                effectiveRightsFlags = defaultBannedRightsFlags
                            } else {
                                effectiveRightsFlags = TelegramChatBannedRightsFlags()
                            }
                            if value {
                                effectiveRightsFlags.remove(rights)
                                effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                            } else {
                                effectiveRightsFlags.insert(rights)
                                for right in allGroupPermissionList {
                                    if groupPermissionDependencies(right).contains(rights) {
                                        effectiveRightsFlags.insert(right)
                                    }
                                }
                            }
                            state.modifiedRightsFlags = effectiveRightsFlags
                            return state
                        }
                        let state = stateValue.with { $0 }
                        if let modifiedRightsFlags = state.modifiedRightsFlags {
                            updateDefaultRightsDisposable.set((updateDefaultChannelMemberBannedRights(account: context.account, peerId: peerId, rights: TelegramChatBannedRights(flags: completeRights(modifiedRightsFlags), untilDate: Int32.max))
                                |> deliverOnMainQueue).start())
                        }
                    } else if let group = view.peers[peerId] as? TelegramGroup, let _ = view.cachedData as? CachedGroupData {
                        updateState { state in
                            var state = state
                            var effectiveRightsFlags: TelegramChatBannedRightsFlags
                            if let modifiedRightsFlags = state.modifiedRightsFlags {
                                effectiveRightsFlags = modifiedRightsFlags
                            } else if let defaultBannedRightsFlags = group.defaultBannedRights?.flags {
                                effectiveRightsFlags = defaultBannedRightsFlags
                            } else {
                                effectiveRightsFlags = TelegramChatBannedRightsFlags()
                            }
                            if value {
                                effectiveRightsFlags.remove(rights)
                                effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                            } else {
                                effectiveRightsFlags.insert(rights)
                                for right in allGroupPermissionList {
                                    if groupPermissionDependencies(right).contains(rights) {
                                        effectiveRightsFlags.insert(right)
                                    }
                                }
                            }
                            state.modifiedRightsFlags = effectiveRightsFlags
                            return state
                        }
                        let state = stateValue.with { $0 }
                        if let modifiedRightsFlags = state.modifiedRightsFlags {
                            updateDefaultRightsDisposable.set((updateDefaultChannelMemberBannedRights(account: context.account, peerId: peerId, rights: TelegramChatBannedRights(flags: completeRights(modifiedRightsFlags), untilDate: Int32.max))
                                |> deliverOnMainQueue).start())
                        }
                    }
                })
        }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
            updateState { state in
                var state = state
                if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                    state.peerIdWithRevealedOptions = peerId
                }
                return state
            }
        }, addPeer: {
            let behavior = peerId.namespace == Namespaces.Peer.CloudGroup ? SelectGroupMembersBehavior(peerId: peerId, limit: 1) : SelectChannelMembersBehavior(peerId: peerId, limit: 1)
            
            _ = (selectModalPeers(context: context, title: L10n.channelBlacklistSelectNewUserTitle, limit: 1, behavior: behavior, confirmation: { peerIds in
                if let peerId = peerIds.first {
                    var adminError:Bool = false
                    if let participant = behavior.participants[peerId] {
                        if case let .member(_, _, adminInfo, _, _) = participant.participant {
                            if let adminInfo = adminInfo {
                                if !adminInfo.canBeEditedByAccountPeer && adminInfo.promotedBy != context.account.peerId {
                                    adminError = true
                                }
                            }
                        } else {
                            adminError = true
                        }
                    }
                    if adminError {
                        alert(for: mainWindow, info: L10n.channelBlacklistDemoteAdminError)
                        return .single(false)
                    }
                }
                return .single(true)
            }) |> map {$0.first} |> filter {$0 != nil} |> map {$0!}).start(next: { memberId in
                
                var participant:RenderedChannelParticipant?
                if let p = behavior.participants[memberId] {
                    participant = p
                } else if let temporary = behavior.result[memberId] {
                    participant = RenderedChannelParticipant(participant: .member(id: memberId, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil), peer: temporary.peer, peers: [memberId: temporary.peer], presences: temporary.presence != nil ? [memberId: temporary.presence!] : [:])
                }
                if let participant = participant {
                    restrict(participant.participant, false)
                }
            })
            
        }, removePeer: { memberId in
            updateState { state in
                var state = state
                state.removingPeerId = memberId
                return state
            }
            
            removePeerDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: peerId, memberId: memberId, bannedRights: nil)
                |> deliverOnMainQueue).start(error: { _ in
                    updateState { state in
                        var state = state
                        state.removingPeerId = nil
                        return state
                    }
                }, completed: {
                    updateState { state in
                        var state = state
                        state.removingPeerId = nil
                        return state
                    }
                }))
        }, openPeer: { participant in
            restrict(participant, true)
        }, openPeerInfo: { [weak self] peer in
            self?.navigationController?.push(PeerInfoController(context: context, peerId: peer.id))
        }, openKicked: { [weak self] in
            self?.navigationController?.push(ChannelBlacklistViewController(context, peerId: peerId))
        }, presentRestrictedPublicGroupPermissionsAlert: {
                alert(for: mainWindow, info: L10n.groupPermissionNotAvailableInPublicGroups)
        }, updateSlowMode: { value in
            let signal: Signal<PeerId?, ConvertGroupToSupergroupError>
            
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                stopMerging = true
                signal = convertGroupToSupergroup(account: context.account, peerId: peerId)
                    |> map(Optional.init)
                    |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                        guard let upgradedPeerId = upgradedPeerId else {
                            return .fail(.generic)
                        }
                        return updateChannelSlowModeInteractively(postbox: context.account.postbox, network: context.account.network, accountStateManager: context.account.stateManager, peerId: upgradedPeerId, timeout: value)
                            |> map { _ in return Optional(upgradedPeerId) }
                            |> mapError { _ in
                                return ConvertGroupToSupergroupError.generic
                            }
                    }
                
            } else {
                signal = updateChannelSlowModeInteractively(postbox: context.account.postbox, network: context.account.network, accountStateManager: context.account.stateManager, peerId: peerId, timeout: value)
                    |> mapError { _ in return ConvertGroupToSupergroupError.generic }
                    |> map { _ in return nil }
            }
            
            _ = showModalProgress(signal: signal |> deliverOnMainQueue, for: context.window).start(next: { upgradedPeerId in
                if let upgradedPeerId = upgradedPeerId {
                    upgradedToSupergroup(upgradedPeerId, {
                        
                    })
                }
            }, error: { error in
                switch error {
                case .tooManyChannels:
                    showInactiveChannels(context: context, source: .upgrade)
                case .generic:
                    alert(for: context.window, info: L10n.unknownError)
                }
            })
            
        })
        
        let previous = Atomic<[AppearanceWrapperEntry<ChannelPermissionsEntry>]>(value: [])
        let initialSize = self.atomicSize
        
        let signal = combineLatest(queue: .mainQueue(), appearanceSignal, statePromise.get(), peerView.get(), peersPromise.get())
        |> deliverOnMainQueue
        |> map { appearance, state, view, participants -> TableUpdateTransition in
            let entries = channelPermissionsControllerEntries(view: view, state: state, participants: participants).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.with { $0 }, arguments: arguments)
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
        
        interfaceFullReady.set(combineLatest(queue: .mainQueue(), peerView.get(), peersPromise.get()) |> map { view, participants in
            return view.cachedData != nil && (participants != nil)
        })
        
        
        upgradedToSupergroupImpl = { [weak self] upgradedPeerId, f in
            guard let `self` = self, let navigationController = self.navigationController else {
                return
            }
            
            var chatController: ChatController? = ChatController(context: context, chatLocation: .peer(upgradedPeerId))
            
            
            chatController!.navigationController = navigationController
            chatController!.loadViewIfNeeded(navigationController.bounds)
            
            var signal = chatController!.ready.get() |> filter {$0} |> take(1) |> ignoreValues
            
            var controller: ChannelPermissionsController? = ChannelPermissionsController(context, peerId: upgradedPeerId)
            
            controller!.navigationController = navigationController
            controller!.loadViewIfNeeded(navigationController.bounds)
            
            let mainSignal = combineLatest(controller!.ready.get(), controller!.interfaceFullReady.get()) |> map { $0 && $1 } |> filter {$0} |> take(1) |> ignoreValues
            
            signal = combineLatest(queue: .mainQueue(), signal, mainSignal) |> ignoreValues
            
            _ = signal.start(completed: { [weak navigationController] in
                navigationController?.removeAll()
                navigationController?.push(chatController!, false, style: .none)
                navigationController?.push(controller!, false, style: .none)
                
                chatController = nil
                controller = nil
            })
            
        }
        
        self.disposable.set(signal.start(next: { [weak self] transition in
            guard let `self` = self, !stopMerging else { return }
            self.genericView.merge(with: transition)
            self.readyOnce()
        }))
        
    }
}

