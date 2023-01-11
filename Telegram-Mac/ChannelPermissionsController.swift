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


private final class Arguments {
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
    let convert:()->Void
    let toggleReveal:(TelegramChatBannedRightsFlags)->Void
    init(context: AccountContext, updatePermission: @escaping (TelegramChatBannedRightsFlags, Bool) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addPeer: @escaping  () -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (ChannelParticipant) -> Void, openPeerInfo: @escaping (Peer) -> Void, openKicked: @escaping () -> Void, presentRestrictedPublicGroupPermissionsAlert: @escaping() -> Void, updateSlowMode:@escaping(Int32)->Void, convert: @escaping()->Void, toggleReveal:@escaping(TelegramChatBannedRightsFlags)->Void) {
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
        self.convert = convert
        self.toggleReveal = toggleReveal
    }
}

private struct State: Equatable {
    var peerIdWithRevealedOptions: PeerId?
    var removingPeerId: PeerId?
    var searchingMembers: Bool = false
    var modifiedRightsFlags: TelegramChatBannedRightsFlags?
    var participants: [RenderedChannelParticipant]?
    var revealed: [TelegramChatBannedRightsFlags: Bool] = [:]
    var peer: PeerEquatable?
    var cachedData: CachedDataEquatable?
}

func stringForGroupPermission(right: TelegramChatBannedRightsFlags, channel: TelegramChannel?) -> String {
    if right.contains(.banSendMessages) {
        return strings().channelBanUserPermissionSendMessages
    } else if right.contains(.banSendMedia) {
        return strings().channelBanUserPermissionSendMedia
    } else if right.contains(.banSendGifs) {
        return strings().channelBanUserPermissionSendStickersAndGifs
    } else if right.contains(.banEmbedLinks) {
        return strings().channelBanUserPermissionEmbedLinks
    } else if right.contains(.banSendPolls) {
        return strings().channelBanUserPermissionSendPolls
    } else if right.contains(.banChangeInfo) {
        return strings().channelBanUserPermissionChangeGroupInfo
    } else if right.contains(.banAddMembers) {
        return strings().channelBanUserPermissionAddMembers
    } else if right.contains(.banPinMessages) {
        return strings().channelEditAdminPermissionPinMessages
    } else if right.contains(.banManageTopics) {
        return strings().channelEditAdminPermissionCreateTopics
    } else if right.contains(.banSendPhotos) {
        return strings().channelEditAdminPermissionSendPhotos
    } else if right.contains(.banSendVideos) {
        return strings().channelEditAdminPermissionSendVideos
    } else if right.contains(.banSendStickers) {
        return strings().channelBanUserPermissionSendStickersAndGifs
    } else if right.contains(.banSendMusic) {
        return strings().channelEditAdminPermissionSendMusic
    } else if right.contains(.banSendFiles) {
        return strings().channelEditAdminPermissionSendFiles
    } else if right.contains(.banSendVoice) {
        return strings().channelEditAdminPermissionSendVoice
    } else if right.contains(.banSendInstantVideos) {
        return strings().channelEditAdminPermissionSendInstantVideo
    } else {
        return ""
    }

}

func compactStringForGroupPermission(right: TelegramChatBannedRightsFlags, channel: TelegramChannel?) -> String {
    if right.contains(.banSendMessages) {
        return strings().groupPermissionNoSendMessages
    } else if right.contains(.banSendMedia) {
        return strings().groupPermissionNoSendMedia
    } else if right.contains(.banSendGifs) {
        return strings().groupPermissionNoSendGifs
    } else if right.contains(.banEmbedLinks) {
        return strings().groupPermissionNoSendLinks
    } else if right.contains(.banSendPolls) {
        return strings().groupPermissionNoSendPolls
    } else if right.contains(.banChangeInfo) {
        return strings().groupPermissionNoChangeInfo
    } else if right.contains(.banAddMembers) {
        return strings().groupPermissionNoAddMembers
    } else if right.contains(.banPinMessages) {
        return strings().groupPermissionNoPinMessages
    } else if right.contains(.banManageTopics) {
        return strings().groupPermissionNoTopics
    } else {
        return ""
    }
}

private let internal_allPossibleGroupPermissionList: [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] = [
    (.banSendMessages, .banMembers),
    (.banSendMedia, .banMembers),
    (.banSendPhotos, .banMembers),
    (.banSendVideos, .banMembers),
    (.banSendGifs, .banMembers),
    (.banSendMusic, .banMembers),
    (.banSendFiles, .banMembers),
    (.banSendVoice, .banMembers),
    (.banSendInstantVideos, .banMembers),
    (.banEmbedLinks, .banMembers),
    (.banSendPolls, .banMembers),
    (.banAddMembers, .banMembers),
    (.banPinMessages, .pinMessages),
    (.banManageTopics, .manageTopics),
    (.banChangeInfo, .changeInfo)
]



public func allGroupPermissionList(peer: Peer) -> [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] {
    if let channel = peer as? TelegramChannel, channel.flags.contains(.isForum) {
        return [
            (.banSendMessages, .banMembers),
            (.banSendMedia, .banMembers),
            (.banSendPolls, .banMembers),
            (.banAddMembers, .banMembers),
            (.banPinMessages, .pinMessages),
            (.banManageTopics, .manageTopics),
            (.banChangeInfo, .changeInfo)
        ]
    } else {
        return [
            (.banSendMessages, .banMembers),
            (.banSendMedia, .banMembers),
            (.banSendPolls, .banMembers),
            (.banAddMembers, .banMembers),
            (.banPinMessages, .pinMessages),
            (.banChangeInfo, .changeInfo)
        ]
    }
}

func banSendMediaSubList() -> [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] {
    return [
        (.banSendPhotos, .banMembers),
        (.banSendVideos, .banMembers),
        (.banSendGifs, .banMembers),
        (.banSendMusic, .banMembers),
        (.banSendFiles, .banMembers),
        (.banSendVoice, .banMembers),
        (.banSendInstantVideos, .banMembers),
        (.banEmbedLinks, .banMembers),
    ]
}



let publicGroupRestrictedPermissions: TelegramChatBannedRightsFlags = [
    .banPinMessages,
    .banChangeInfo
]



func groupPermissionDependencies(_ right: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    if right.contains(.banSendMedia) || banSendMediaSubList().contains(where: { $0.0 == right }) {
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
    } else if right.contains(.banManageTopics) {
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

private func _id_permission(_ flags: TelegramChatBannedRightsFlags) -> InputDataIdentifier {
    return .init("_id_permission_\(flags.rawValue)")
}
private let _id_convert_to_giga = InputDataIdentifier("_id_convert_to_giga")
private let _id_slow_mode = InputDataIdentifier("_id_slow_mode")
private let _id_kicked = InputDataIdentifier("_id_kicked")
private let _id_add_peer = InputDataIdentifier("_id_add_peer")
private func _id_peer(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(peerId.toInt64())")
}


private func _stableIndex(for value: TelegramChatBannedRightsFlags) -> Int32 {
    var index: Int32 = 100
    for (right, _) in internal_allPossibleGroupPermissionList {
        if right == value {
            return index
        }
        index += 1
    }
    return index
}

private func entries(state: State, arguments: Arguments) -> [InputDataEntry] {
    
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    let limits: LimitsConfiguration = arguments.context.limitConfiguration

    struct TuplePermission : Equatable {
        struct Sub: Equatable {
            let title: String
            let flags: TelegramChatBannedRightsFlags
            let isSelected: Bool
        }
        let string: NSAttributedString
        let flags: TelegramChatBannedRightsFlags
        let selected: Bool
        let enabled: Bool?
        let viewType: GeneralViewType
        let reveable: Bool
        let subItems:[Sub]
    }
    
    let insertSlowMode: (Int32?) -> Void = { timeout in
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().channelPermissionsSlowModeHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_slow_mode, equatable: InputDataEquatable(timeout), comparable: nil, item: { initialSize, stableId in
            let list:[Int32] = [0, 10, 30, 60, 300, 900, 3600]
            let titles: [String] = [strings().channelPermissionsSlowModeTimeoutOff,
                                    strings().channelPermissionsSlowModeTimeout10s,
                                    strings().channelPermissionsSlowModeTimeout30s,
                                    strings().channelPermissionsSlowModeTimeout1m, strings().channelPermissionsSlowModeTimeout5m,
                                    strings().channelPermissionsSlowModeTimeout15m,
                                    strings().channelPermissionsSlowModeTimeout1h]
            return SelectSizeRowItem(initialSize, stableId: stableId, current: timeout ?? 0, sizes: list, hasMarkers: false, titles: titles, viewType: .singleItem, selectAction: { index in
               arguments.updateSlowMode(list[index])
            })
        }))
        
        let text: String
        if let timeout = timeout, timeout > 0 {
            text = strings().channelPermissionsSlowModeTextSelected(autoremoveLocalized(Int(timeout)))
        } else {
            text = strings().channelPermissionsSlowModeTextOff
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(text), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
    }
    
    let insertPermissions:([TuplePermission]) -> Int32 = { items in
        var index: Int32 = 0
        for item in items {
            index = _stableIndex(for: item.flags)
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_permission(item.flags), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: item.string.string, nameAttributed: item.string, type: .switchable(item.selected), viewType: item.viewType, action: {
                    if item.reveable {
                        arguments.toggleReveal(item.flags)
                    } else {
                        if let _ = item.enabled {
                            arguments.updatePermission(item.flags, !item.selected)
                        } else {
                            arguments.presentRestrictedPublicGroupPermissionsAlert()
                        }
                    }
                    
                }, enabled: item.enabled ?? true, switchAppearance: SwitchViewAppearance(backgroundColor: theme.colors.background, stateOnColor: item.enabled == true ? theme.colors.accent : theme.colors.accent.withAlphaComponent(0.6), stateOffColor: item.enabled == true ? theme.colors.redUI : theme.colors.redUI.withAlphaComponent(0.6), disabledColor: .grayBackground, borderColor: .clear), autoswitch: false, switchAction: {
                    if let _ = item.enabled {
                        arguments.updatePermission(item.flags, !item.selected)
                    } else {
                        arguments.presentRestrictedPublicGroupPermissionsAlert()
                    }
                })
            }))
            
            for item in item.subItems {
                index = _stableIndex(for: item.flags)
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_permission(item.flags), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                    return GeneralInteractedRowItem(initialSize, stableId: stableId, name: item.title, type: .selectableLeft(item.isSelected), viewType: .innerItem, action: {
                        arguments.updatePermission(item.flags, !item.isSelected)
                    }, enabled: true)
                }))
            }
        }
        return index
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if let channel = state.peer?.peer as? TelegramChannel, let participants = state.participants, let cachedData = state.cachedData?.data as? CachedChannelData, let defaultBannedRights = channel.defaultBannedRights {

        let effectiveRightsFlags: TelegramChatBannedRightsFlags
        if let modifiedRightsFlags = state.modifiedRightsFlags {
            effectiveRightsFlags = modifiedRightsFlags
        } else {
            effectiveRightsFlags = defaultBannedRights.flags
        }

        let permissionList = allGroupPermissionList(peer: channel)

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().groupInfoPermissionsSectionTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
    
        
        var items: [TuplePermission] = []
        for (i, rights) in permissionList.enumerated() {
            var enabled: Bool? = true
            if channel.addressName != nil && publicGroupRestrictedPermissions.contains(rights.0) {
                enabled = nil
            }
            var isSelected = !effectiveRightsFlags.contains(rights.0)
            var subItems: [TuplePermission.Sub] = []
            if rights.0 == .banSendMedia {
                isSelected = banSendMediaSubList().allSatisfy({ !effectiveRightsFlags.contains($0.0) })
                if state.revealed[.banSendMedia] == true {
                    for (subRight, _) in banSendMediaSubList() {
                        subItems.append(.init(title: stringForGroupPermission(right: subRight, channel: channel), flags: subRight, isSelected: !effectiveRightsFlags.contains(subRight)))
                    }

                }
            }
            let string: NSMutableAttributedString = NSMutableAttributedString()
            string.append(string: stringForGroupPermission(right: rights.0, channel: channel), color: theme.colors.text, font: .normal(.title))
            
            if rights.0 == .banSendMedia {
                let count = banSendMediaSubList().filter({ !effectiveRightsFlags.contains($0.0) }).count
                string.append(string: " \(count)/\(banSendMediaSubList().count)", color: theme.colors.text, font: .bold(.small))
            }
            items.append(.init(string: string, flags: rights.0, selected: isSelected, enabled: enabled, viewType: bestGeneralViewType(permissionList, for: i), reveable: rights.0 == .banSendMedia, subItems: subItems))
        }
            
        index = insertPermissions(items)
       

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        if let members = cachedData.participantsSummary.memberCount, limits.maxSupergroupMemberCount - members < 1000 {
            if channel.groupAccess.isCreator && !channel.flags.contains(.isGigagroup) {
                
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().groupInfoPermissionsBroadcastTitle.uppercased()), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
                index += 1
                
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_convert_to_giga, data: .init(name: strings().groupInfoPermissionsBroadcastConvert, color: theme.colors.text, type: .next, viewType: .singleItem, action: arguments.convert)))
                index += 1

                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().groupInfoPermissionsBroadcastConvertInfo(Formatter.withSeparator.string(from: .init(value: arguments.context.limitConfiguration.maxSupergroupMemberCount))!)), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
                index += 1

                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1

            }
        }

        if !channel.flags.contains(.isGigagroup) {
            insertSlowMode(cachedData.slowModeTimeout)
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_kicked, data: .init(name: strings().groupInfoPermissionsRemoved, color: theme.colors.text, type: .nextContext(cachedData.participantsSummary.kickedCount.flatMap({ "\($0 > 0 ? "\($0)" : "")" }) ?? ""), viewType: .singleItem, action: arguments.openKicked)))
        index += 1


        if !channel.flags.contains(.isGigagroup) {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().groupInfoPermissionsExceptions), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1

            let viewType: GeneralViewType = participants.isEmpty ? .singleItem : .firstItem
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_peer, equatable: .init(viewType), comparable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().groupInfoPermissionsAddException, nameStyle: blueActionButton, type: .none, viewType: viewType, action: arguments.addPeer, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 52, thumbInset: 5))
            }))
            index += 1



            struct TuplePeer: Equatable {
                let participant: RenderedChannelParticipant
                let peer: PeerEquatable
                let deleting: ShortPeerDeleting?
                let enabled: Bool
                let canOpen: Bool
                let flags: TelegramChatBannedRightsFlags
                let viewType: GeneralViewType
            }
            
            var items:[TuplePeer] = []
            for (i, participant) in participants.enumerated() {
                let viewType: GeneralViewType
                if i == 0 {
                    if participants.count == 1 {
                        viewType = .lastItem
                    } else {
                        viewType = .innerItem
                    }
                } else {
                    viewType = bestGeneralViewType(participants, for: i)
                }
                items.append(.init(participant: participant, peer: .init(channel), deleting: ShortPeerDeleting(editable: true), enabled: state.removingPeerId != participant.peer.id, canOpen: true, flags: effectiveRightsFlags, viewType: viewType))
                
            }
            for item in items {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                    var text: String?
                    switch item.participant.participant {
                    case let .member(_, _, _, banInfo, _):
                        var exceptionsString = ""
                        if let banInfo = banInfo {
                            for rights in allGroupPermissionList(peer: channel) {
                                if !item.flags.contains(rights.0) && banInfo.rights.flags.contains(rights.0) {
                                    if !exceptionsString.isEmpty {
                                        exceptionsString.append(", ")
                                    }
                                    exceptionsString.append(compactStringForGroupPermission(right: rights.0, channel: item.peer.peer as? TelegramChannel))
                                }
                            }
                            text = exceptionsString
                        }
                    default:
                        break
                    }
                    
                    return ShortPeerRowItem(initialSize, peer: item.participant.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, enabled: item.enabled, status: text, inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: item.viewType, action: {
                        if item.canOpen {
                            arguments.openPeer(item.participant.participant)
                        } else {
                            arguments.openPeerInfo(item.participant.peer)
                        }
                    })
                }))
                index += 1
            }
        }

    }  else if let group = state.peer?.peer as? TelegramGroup, let _ = state.cachedData?.data as? CachedGroupData, let defaultBannedRights = group.defaultBannedRights {
        let effectiveRightsFlags: TelegramChatBannedRightsFlags
        if let modifiedRightsFlags = state.modifiedRightsFlags {
            effectiveRightsFlags = modifiedRightsFlags
        } else {
            effectiveRightsFlags = defaultBannedRights.flags
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().groupInfoPermissionsSectionTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        
        var items: [TuplePermission] = []
        let list = allGroupPermissionList(peer: group)
        for (i, rights) in list.enumerated() {
            let string: NSMutableAttributedString = NSMutableAttributedString()
            _ = string.append(string: stringForGroupPermission(right: rights.0, channel: nil), color: theme.colors.text, font: .normal(.title))

            items.append(.init(string: string, flags: rights.0, selected: !effectiveRightsFlags.contains(rights.0), enabled: true, viewType: bestGeneralViewType(list, for: i), reveable: false, subItems: []))
        }
        index = insertPermissions(items)

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        insertSlowMode(nil)

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().groupInfoPermissionsExceptions), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        let viewType: GeneralViewType = .singleItem
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_peer, equatable: .init(viewType), comparable: nil, item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().groupInfoPermissionsAddException, nameStyle: blueActionButton, type: .none, viewType: viewType, action: arguments.addPeer, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 52, thumbInset: 5))
        }))
        index += 1

    }

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries

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
        
        let statePromise = ValuePromise(State(), ignoreRepeated: true)
        let stateValue = Atomic(value: State())
        let updateState: ((State) -> State) -> Void = { f in
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
                        signal = context.engine.peers.convertGroupToSupergroup(peerId: peerId)
                            |> map(Optional.init)
                            |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                guard let upgradedPeerId = upgradedPeerId else {
                                    return .single(nil)
                                }
                                return context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(peerId: upgradedPeerId, memberId: memberId, bannedRights: updatedRights)
                                    |> castError(ConvertGroupToSupergroupError.self)
                                    |> mapToSignal { _ -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                        return .complete()
                                    }
                                    |> then(.single(upgradedPeerId) |> castError(ConvertGroupToSupergroupError.self))
                            }
                            |> deliverOnMainQueue
                    } else {
                        signal = context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(peerId: peerId, memberId: memberId, bannedRights: updatedRights)
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
                            alert(for: context.window, info: strings().unknownError)
                        }
                    }))
                default:
                    break
                }
                
                
            }), for: context.window)
        }
        
        let peersPromise = Promise<[RenderedChannelParticipant]?>(nil)
        let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.restricted(peerId: peerId, updated: { state in
            peersPromise.set(.single(state.list))
        })
        actionsDisposable.add(disposable)
        
        let updateDefaultRightsDisposable = MetaDisposable()
        actionsDisposable.add(updateDefaultRightsDisposable)
        
        actionsDisposable.add(context.account.viewTracker.peerView(peerId).start(next: { peerView in
            updateState { current in
                var current = current
                current.peer = PeerEquatable(peerView.peers[peerId])
                current.cachedData = CachedDataEquatable(peerView.cachedData)
                return current
            }
        }))
        
        
        let arguments = Arguments(context: context, updatePermission: { rights, value in
            
            let peer = stateValue.with { $0.peer?.peer }
            let cachedData = stateValue.with { $0.cachedData?.data }

            if let channel = peer as? TelegramChannel, let _ = cachedData as? CachedChannelData {
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
                    
                    if rights == .banSendMedia {
                        if value {
                            effectiveRightsFlags.remove(rights)
                            for item in banSendMediaSubList() {
                                effectiveRightsFlags.remove(item.0)
                            }
                        } else {
                            effectiveRightsFlags.insert(rights)
                            for (right, _) in allGroupPermissionList(peer: channel) {
                                if groupPermissionDependencies(right).contains(rights) {
                                    effectiveRightsFlags.insert(right)
                                }
                            }
                            
                            for item in banSendMediaSubList() {
                                effectiveRightsFlags.insert(item.0)
                                for (right, _) in allGroupPermissionList(peer: channel) {
                                    if groupPermissionDependencies(right).contains(item.0) {
                                        effectiveRightsFlags.insert(right)
                                    }
                                }
                            }
                        }
                    } else {
                        if value {
                            effectiveRightsFlags.remove(rights)
                            effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                        } else {
                            effectiveRightsFlags.insert(rights)
                            for (right, _) in allGroupPermissionList(peer: channel) {
                                if groupPermissionDependencies(right).contains(rights) {
                                    effectiveRightsFlags.insert(right)
                                }
                            }
                        }
                    }
                    if banSendMediaSubList().allSatisfy({ !effectiveRightsFlags.contains($0.0) }) {
                        effectiveRightsFlags.remove(.banSendMedia)
                    } else {
                        effectiveRightsFlags.insert(.banSendMedia)
                    }
                    state.modifiedRightsFlags = effectiveRightsFlags
                    return state
                }
                let state = stateValue.with { $0 }
                if let modifiedRightsFlags = state.modifiedRightsFlags {
                    updateDefaultRightsDisposable.set((context.engine.peers.updateDefaultChannelMemberBannedRights(peerId: peerId, rights: TelegramChatBannedRights(flags: completeRights(modifiedRightsFlags), untilDate: Int32.max))
                    |> deliverOnMainQueue).start())
                }
            } else if let group = peer as? TelegramGroup, let _ = cachedData as? CachedGroupData {
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
                        for (right, _) in allGroupPermissionList(peer: group) {
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
                    updateDefaultRightsDisposable.set((context.engine.peers.updateDefaultChannelMemberBannedRights(peerId: peerId, rights: TelegramChatBannedRights(flags: completeRights(modifiedRightsFlags), untilDate: Int32.max))
                        |> deliverOnMainQueue).start())
                }

            }
        }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
            updateState { state in
                var state = state
                if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                    state.peerIdWithRevealedOptions = peerId
                }
                return state
            }
        }, addPeer: {
            let behavior = peerId.namespace == Namespaces.Peer.CloudGroup ? SelectGroupMembersBehavior(peerId: peerId, limit: 1) : SelectChannelMembersBehavior(peerId: peerId, peerChannelMemberContextsManager: context.peerChannelMemberCategoriesContextsManager, limit: 1)
            
            _ = (selectModalPeers(window: context.window, context: context, title: strings().channelBlacklistSelectNewUserTitle, limit: 1, behavior: behavior, confirmation: { peerIds in
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
                        alert(for: context.window, info: strings().channelBlacklistDemoteAdminError)
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
            
            removePeerDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(peerId: peerId, memberId: memberId, bannedRights: nil)
                |> deliverOnMainQueue).start(completed: {
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
                alert(for: context.window, info: strings().groupPermissionNotAvailableInPublicGroups)
        }, updateSlowMode: { value in
            let signal: Signal<PeerId?, ConvertGroupToSupergroupError>
            
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                stopMerging = true
                signal = context.engine.peers.convertGroupToSupergroup(peerId: peerId)
                    |> map(Optional.init)
                    |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                        guard let upgradedPeerId = upgradedPeerId else {
                            return .fail(.generic)
                        }
                        return context.engine.peers.updateChannelSlowModeInteractively(peerId: upgradedPeerId, timeout: value)
                            |> map { _ in return Optional(upgradedPeerId) }
                            |> mapError { _ in
                                return ConvertGroupToSupergroupError.generic
                            }
                    }
                
            } else {
                signal = context.engine.peers.updateChannelSlowModeInteractively(peerId: peerId, timeout: value)
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
                    alert(for: context.window, info: strings().unknownError)
                }
            })
            
        }, convert: {
            showModal(with: GigagroupLandingController(context: context, peerId: peerId), for: context.window)
        }, toggleReveal: { rights in
            updateState { current in
                var current = current
                if let value = current.revealed[rights] {
                    current.revealed[rights] = !value
                } else {
                    current.revealed[rights] = true
                }
                return current
            }
        })
        
        let previous = Atomic<[AppearanceWrapperEntry<InputDataEntry>]>(value: [])
        let initialSize = self.atomicSize
        
        let dataArguments = InputDataArguments.init(select: { _, _ in
            
        }, dataUpdated: {
            
        })
        
        let signal = combineLatest(queue: .mainQueue(), appearanceSignal, statePromise.get())
        |> deliverOnMainQueue
        |> mapToSignal { appearance, state -> Signal<TableUpdateTransition, NoError> in
            let entries = entries(state: state, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            let previous = previous.swap(entries)
            return prepareInputDataTransition(left: previous, right: entries, animated: true, searchState: nil, initialSize: initialSize.with { $0 }, arguments: dataArguments, onMainQueue: false, animateEverything: true, grouping: false)
        }
        |> deliverOnMainQueue
        |> afterDisposed {
            actionsDisposable.dispose()
        }
        
        interfaceFullReady.set(statePromise.get() |> map { state in
            return state.cachedData != nil && state.participants != nil
        })
        
        actionsDisposable.add(peersPromise.get().start(next: { participants in
            updateState { current in
                var current = current
                current.participants = participants
                return current
            }
        }))
        
        
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
                navigationController?.push(chatController!, false, style: ViewControllerStyle.none)
                navigationController?.push(controller!, false, style: ViewControllerStyle.none)
                
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

