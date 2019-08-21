//
//  ChannelAdminController.swift
//  Telegram
//
//  Created by keepcoder on 06/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private final class ChannelAdminControllerArguments {
    let context: AccountContext
    let toggleRight: (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void
    let dismissAdmin: () -> Void
    let cantEditError: () -> Void
    let transferOwnership:()->Void
    let updateRank:(String)->Void
    init(context: AccountContext, toggleRight: @escaping (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void, dismissAdmin: @escaping () -> Void, cantEditError: @escaping() -> Void, transferOwnership: @escaping()->Void, updateRank: @escaping(String)->Void) {
        self.context = context
        self.toggleRight = toggleRight
        self.dismissAdmin = dismissAdmin
        self.cantEditError = cantEditError
        self.transferOwnership = transferOwnership
        self.updateRank = updateRank
    }
}

private enum ChannelAdminEntryStableId: Hashable {
    case info
    case right(TelegramChatAdminRightsFlags)
    case description(Int32)
    case changeOwnership
    case section(Int32)
    case roleHeader
    case role
    case roleDesc
    var hashValue: Int {
        return 0
    }

}

private enum ChannelAdminEntry: TableItemListNodeEntry {
    case info(Int32, Peer, TelegramUserPresence?)
    case rightItem(Int32, Int, String, TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags, Bool, Bool)
    case roleHeader(Int32)
    case roleDesc(Int32)
    case role(Int32, String, String)
    case description(Int32, Int32, String)
    case changeOwnership(Int32, Int32, String)
    case section(Int32)
    
    
    var stableId: ChannelAdminEntryStableId {
        switch self {
        case .info:
            return .info
        case let .rightItem(_, _, _, right, _, _, _):
            return .right(right)
        case .description(_, let index, _):
            return .description(index)
        case .changeOwnership:
            return .changeOwnership
        case .roleHeader:
            return .roleHeader
        case .roleDesc:
            return .roleDesc
        case .role:
            return .role
        case .section(let sectionId):
            return .section(sectionId)
        }
    }
    
    static func ==(lhs: ChannelAdminEntry, rhs: ChannelAdminEntry) -> Bool {
        switch lhs {
        case let .info(lhsSectionId, lhsPeer, lhsPresence):
            if case let .info(rhsSectionId, rhsPeer, rhsPresence) = rhs {
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if !arePeersEqual(lhsPeer, rhsPeer) {
                    return false
                }
                if lhsPresence != rhsPresence {
                    return false
                }
                
                return true
            } else {
                return false
            }
        case let .rightItem(sectionId, index, text, right, flags, value, enabled):
            if case .rightItem(sectionId, index, text, right, flags, value, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .description(sectionId, index, text):
            if case .description(sectionId, index, text) = rhs{
                return true
            } else {
                return false
            }
        case let .changeOwnership(sectionId, index, text):
            if case .changeOwnership(sectionId, index, text) = rhs{
                return true
            } else {
                return false
            }
        case let .roleHeader(section):
            if case .roleHeader(section) = rhs {
                return true
            } else {
                return false
            }
        case let .roleDesc(section):
            if case .roleDesc(section) = rhs {
                return true
            } else {
                return false
            }
        case let .role(section, text, placeholder):
            if case .role(section, text, placeholder) = rhs {
                return true
            } else {
                return false
            }
        case let .section(sectionId):
            if case .section(sectionId) = rhs{
                return true
            } else {
                return false
            }
        }
    }

    var index:Int32 {
        switch self {
        case .info(let sectionId, _, _):
            return (sectionId * 1000) + 0
        case .description(let sectionId, let index, _):
            return (sectionId * 1000) + index
        case let .changeOwnership(sectionId, index, _):
            return (sectionId * 1000) + index
        case .rightItem(let sectionId, let index, _, _, _, _, _):
            return (sectionId * 1000) + Int32(index) + 10
        case let .roleHeader(sectionId):
             return (sectionId * 1000)
        case let .role(sectionId, _, _):
            return (sectionId * 1000) + 1
        case let .roleDesc(sectionId):
            return (sectionId * 1000) + 2
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: ChannelAdminEntry, rhs: ChannelAdminEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: ChannelAdminControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .info(_, let peer, let presence):
            var string:String = peer.isBot ? L10n.presenceBot : L10n.peerStatusRecently
            var color:NSColor = theme.colors.grayText
            if let presence = presence, !peer.isBot {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.context.timeDifference, relativeTo: Int32(timestamp))
            }
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, enabled: true, height: 60, photoSize: NSMakeSize(50, 50), statusStyle: ControlStyle(font: .normal(.title), foregroundColor: color), status: string, borderType: [], drawCustomSeparator: false, drawLastSeparator: false, inset: NSEdgeInsets(left: 25, right: 25), drawSeparatorIgnoringInset: false, action: {})
        case let .rightItem(_, _, name, right, flags, value, enabled):
            //ControlStyle(font: NSFont.)
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: enabled ? theme.colors.text : theme.colors.grayText), type: .switchable(value), action: { 
                arguments.toggleRight(right, flags)
            }, enabled: enabled, switchAppearance: SwitchViewAppearance(backgroundColor: theme.colors.background, stateOnColor: enabled ? theme.colors.accent : theme.colors.accent.withAlphaComponent(0.6), stateOffColor: enabled ? theme.colors.redUI : theme.colors.redUI.withAlphaComponent(0.6), disabledColor: .grayBackground, borderColor: .clear), disabledAction: {
                arguments.cantEditError()
            })
        case let .changeOwnership(_, _, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, nameStyle: blueActionButton, action: {
                arguments.transferOwnership()
            })
        case .roleHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.channelAdminRoleHeader)
        case let .role(_, text, placeholder):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: placeholder, text: text, limit: 16, textChangeHandler: { text in
                arguments.updateRank(text)
            }, textFilter: { text in
                let filtered = text.filter { character -> Bool in
                    return !String(character).containsOnlyEmoji
                }
                return filtered
            }, pasteFilter: { text in
                return (false, text)
            })
        case .roleDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: "")
        case .description(_, _, let name):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: name)//GeneralInteractedRowItem(initialSize, stableId: stableId, name: name)
        }
        //return TableRowItem(initialSize)
    }
}

private struct ChannelAdminControllerState: Equatable {
    let updatedFlags: TelegramChatAdminRightsFlags?
    let updating: Bool
    let editable:Bool
    let rank:String?
    let initialRank:String?
    init(updatedFlags: TelegramChatAdminRightsFlags? = nil, updating: Bool = false, editable: Bool = false, rank: String?, initialRank: String?) {
        self.updatedFlags = updatedFlags
        self.updating = updating
        self.editable = editable
        self.rank = rank
        self.initialRank = initialRank
    }
    
    func withUpdatedUpdatedFlags(_ updatedFlags: TelegramChatAdminRightsFlags?) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: updatedFlags, updating: self.updating, editable: self.editable, rank: self.rank, initialRank: self.initialRank)
    }
    
    func withUpdatedEditable(_ editable:Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: updatedFlags, updating: self.updating, editable: editable, rank: self.rank, initialRank: self.initialRank)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updating: updating, editable: self.editable, rank: self.rank, initialRank: self.initialRank)
    }
    
    func withUpdatedRank(_ rank: String?) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updating: updating, editable: self.editable, rank: rank, initialRank: self.initialRank)
    }
}

private func stringForRight(right: TelegramChatAdminRightsFlags, isGroup: Bool, defaultBannedRights: TelegramChatBannedRights?) -> String {
    if right.contains(.canChangeInfo) {
        return isGroup ? L10n.groupEditAdminPermissionChangeInfo : L10n.channelEditAdminPermissionChangeInfo
    } else if right.contains(.canPostMessages) {
        return L10n.channelEditAdminPermissionPostMessages
    } else if right.contains(.canEditMessages) {
        return L10n.channelEditAdminPermissionEditMessages
    } else if right.contains(.canDeleteMessages) {
        return L10n.channelEditAdminPermissionDeleteMessages
    } else if right.contains(.canBanUsers) {
        return L10n.channelEditAdminPermissionBanUsers
    } else if right.contains(.canInviteUsers) {
        if isGroup {
            if let defaultBannedRights = defaultBannedRights, defaultBannedRights.flags.contains(.banAddMembers) {
                return L10n.channelEditAdminPermissionInviteMembers
            } else {
                return L10n.channelEditAdminPermissionInviteViaLink
            }
        } else {
            return L10n.channelEditAdminPermissionInviteSubscribers
        }

    } else if right.contains(.canPinMessages) {
        return L10n.channelEditAdminPermissionPinMessages
    } else if right.contains(.canAddAdmins) {
        return L10n.channelEditAdminPermissionAddNewAdmins
    } else {
        return ""
    }
}

private func rightDependencies(_ right: TelegramChatAdminRightsFlags) -> [TelegramChatAdminRightsFlags] {
    if right.contains(.canChangeInfo) {
        return []
    } else if right.contains(.canPostMessages) {
        return []
    } else if right.contains(.canEditMessages) {
        return []
    } else if right.contains(.canDeleteMessages) {
        return []
    } else if right.contains(.canBanUsers) {
        return []
    } else if right.contains(.canInviteUsers) {
        return []
    } else if right.contains(.canPinMessages) {
        return []
    } else if right.contains(.canAddAdmins) {
        return []
    } else {
        return []
    }
}

private func canEditAdminRights(accountPeerId: PeerId, channelView: PeerView, initialParticipant: ChannelParticipant?) -> Bool {
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel {
        if channel.flags.contains(.isCreator) {
            return true
        } else if let initialParticipant = initialParticipant {
            switch initialParticipant {
            case .creator:
                return false
            case let .member(_, _, adminInfo, _, _):
                if let adminInfo = adminInfo {
                    return adminInfo.canBeEditedByAccountPeer || adminInfo.promotedBy == accountPeerId
                } else {
                    return channel.hasPermission(.addAdmins)
                }
            }
        } else {
            return channel.hasPermission(.addAdmins)
        }
    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup {
        if case .creator = group.role {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}


private func channelAdminControllerEntries(state: ChannelAdminControllerState, accountPeerId: PeerId, channelView: PeerView, adminView: PeerView, initialParticipant: ChannelParticipant?) -> [ChannelAdminEntry] {
    var entries: [ChannelAdminEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    var descId: Int32 = 0
    
    var addAdminsEnabled: Bool = false
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(sectionId, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence))
        
        let isGroup: Bool
        let maskRightsFlags: TelegramChatAdminRightsFlags
        let rightsOrder: [TelegramChatAdminRightsFlags]
        
        switch channel.info {
        case .broadcast:
            isGroup = false
            maskRightsFlags = .broadcastSpecific
            rightsOrder = [
                .canChangeInfo,
                .canPostMessages,
                .canEditMessages,
                .canDeleteMessages,
                .canInviteUsers,
                .canAddAdmins
            ]
        case .group:
            isGroup = true
            maskRightsFlags = .groupSpecific
            rightsOrder = [
                .canChangeInfo,
                .canDeleteMessages,
                .canBanUsers,
                .canInviteUsers,
                .canPinMessages,
                .canAddAdmins
            ]
        }
        
        if canEditAdminRights(accountPeerId: accountPeerId, channelView: channelView, initialParticipant: initialParticipant) {
            
            var isCreator = false
            if let initialParticipant = initialParticipant, case .creator = initialParticipant {
                isCreator = true
            }
            
            if channel.isSupergroup {
                entries.append(.section(sectionId))
                sectionId += 1
                let placeholder = isCreator ? L10n.channelAdminRolePlaceholderOwner : L10n.channelAdminRolePlaceholderAdmin
                entries.append(.roleHeader(sectionId))
                entries.append(.role(sectionId, state.rank ?? "", placeholder))
                entries.append(.description(sectionId, descId, isCreator ? L10n.channelAdminRoleOwnerDesc : L10n.channelAdminRoleAdminDesc))
                descId += 1
            }
            entries.append(.section(sectionId))
            sectionId += 1
            
           
            if !isCreator || channel.isChannel {
                entries.append(.description(sectionId, descId, L10n.channelAdminWhatCanAdminDo))
                descId += 1
                
                let accountUserRightsFlags: TelegramChatAdminRightsFlags
                if channel.flags.contains(.isCreator) {
                    accountUserRightsFlags = maskRightsFlags
                } else if let adminRights = channel.adminRights {
                    accountUserRightsFlags = maskRightsFlags.intersection(adminRights.flags)
                } else {
                    accountUserRightsFlags = []
                }
                
                let currentRightsFlags: TelegramChatAdminRightsFlags
                if let updatedFlags = state.updatedFlags {
                    currentRightsFlags = updatedFlags
                } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _, _) = initialParticipant, let adminRights = maybeAdminRights {
                    currentRightsFlags = adminRights.rights.flags
                } else {
                    currentRightsFlags = accountUserRightsFlags.subtracting(.canAddAdmins)
                }
                
                if accountUserRightsFlags.contains(.canAddAdmins) {
                    addAdminsEnabled = currentRightsFlags.contains(.canAddAdmins)
                }
                
                var index = 0
                for right in rightsOrder {
                    if accountUserRightsFlags.contains(right) {
                        
                        entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating))
                        index += 1
                    }
                }
                entries.append(.description(sectionId, descId, addAdminsEnabled ? L10n.channelAdminAdminAccess : L10n.channelAdminAdminRestricted))
                descId += 1
                
                if channel.flags.contains(.isCreator), !admin.isBot {
                    if currentRightsFlags.contains(maskRightsFlags) {
                        entries.append(.section(sectionId))
                        sectionId += 1
                        entries.append(.changeOwnership(sectionId, descId, channel.isChannel ? L10n.channelAdminTransferOwnershipChannel : L10n.channelAdminTransferOwnershipGroup))
                        entries.append(.section(sectionId))
                        sectionId += 1
                    }
                }
            }

            
        } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminInfo, _, _) = initialParticipant, let adminInfo = maybeAdminInfo {
            
            if let rank = state.rank {
                entries.append(.section(sectionId))
                sectionId += 1
                entries.append(.roleHeader(sectionId))
                entries.append(.description(sectionId, descId, rank))
                descId += 1
                entries.append(.section(sectionId))
                sectionId += 1
            }
            
            var index = 0
            for right in rightsOrder {
                entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, adminInfo.rights.flags, adminInfo.rights.flags.contains(right), false))
                index += 1
            }
            entries.append(.description(sectionId, descId, L10n.channelAdminCantEditRights))
            descId += 1
        } else if let initialParticipant = initialParticipant, case .creator = initialParticipant {
            
            if let rank = state.rank {
                entries.append(.section(sectionId))
                sectionId += 1
                entries.append(.roleHeader(sectionId))
                entries.append(.description(sectionId, descId, rank))
                descId += 1
                entries.append(.section(sectionId))
                sectionId += 1
            }
            
            var index = 0
            for right in rightsOrder {
                entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, TelegramChatAdminRightsFlags(rightsOrder), true, false))
                index += 1
            }
            entries.append(.description(sectionId, descId, L10n.channelAdminCantEditRights))
            descId += 1
        }
        
    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(sectionId, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence))

        var isCreator = false
        if let initialParticipant = initialParticipant, case .creator = initialParticipant {
            isCreator = true
        }
        
        let placeholder = isCreator ? L10n.channelAdminRolePlaceholderOwner : L10n.channelAdminRolePlaceholderAdmin
        
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.roleHeader(sectionId))
        entries.append(.role(sectionId, state.rank ?? "", placeholder))
        entries.append(.description(sectionId, descId, isCreator ? L10n.channelAdminRoleOwnerDesc : L10n.channelAdminRoleAdminDesc))
        descId += 1
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        if !isCreator {
            entries.append(.description(sectionId, descId, L10n.channelAdminWhatCanAdminDo))
            descId += 1
            
            let isGroup = true
            let maskRightsFlags: TelegramChatAdminRightsFlags = .groupSpecific
            let rightsOrder: [TelegramChatAdminRightsFlags] = [
                .canChangeInfo,
                .canDeleteMessages,
                .canBanUsers,
                .canInviteUsers,
                .canPinMessages,
                .canAddAdmins
            ]
            
            let accountUserRightsFlags: TelegramChatAdminRightsFlags = maskRightsFlags
            
            let currentRightsFlags: TelegramChatAdminRightsFlags
            if let updatedFlags = state.updatedFlags {
                currentRightsFlags = updatedFlags
            } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _, _) = initialParticipant, let adminRights = maybeAdminRights {
                currentRightsFlags = adminRights.rights.flags.subtracting(.canAddAdmins)
            } else {
                currentRightsFlags = accountUserRightsFlags.subtracting(.canAddAdmins)
            }
            
            var index = 0
            for right in rightsOrder {
                if accountUserRightsFlags.contains(right) {
                    entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup, defaultBannedRights: group.defaultBannedRights), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating))
                    index += 1
                }
            }
            
            if accountUserRightsFlags.contains(.canAddAdmins) {
                entries.append(.description(sectionId, descId, currentRightsFlags.contains(.canAddAdmins) ? L10n.channelAdminAdminAccess : L10n.channelAdminAdminRestricted))
                descId += 1
            }
            
            if case .creator = group.role, !admin.isBot {
                if currentRightsFlags.contains(maskRightsFlags) {
                    entries.append(.section(sectionId))
                    sectionId += 1
                    entries.append(.changeOwnership(sectionId, descId, L10n.channelAdminTransferOwnershipGroup))
                    entries.append(.section(sectionId))
                    sectionId += 1
                }
            }
        }
    }
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelAdminEntry>], right: [AppearanceWrapperEntry<ChannelAdminEntry>], initialSize:NSSize, arguments:ChannelAdminControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ChannelAdminController: ModalViewController {
    private var arguments: ChannelAdminControllerArguments?
    private let context:AccountContext
    private let peerId:PeerId
    private let adminId:PeerId
    private let initialParticipant:ChannelParticipant?
    private let updated:(TelegramChatAdminRights) -> Void
    private let disposable = MetaDisposable()
    private let upgradedToSupergroup: (PeerId, @escaping () -> Void) -> Void
    private var okClick: (()-> Void)?
    
    init(_ context: AccountContext, peerId: PeerId, adminId: PeerId, initialParticipant: ChannelParticipant?, updated: @escaping (TelegramChatAdminRights) -> Void, upgradedToSupergroup: @escaping (PeerId, @escaping () -> Void) -> Void) {
        self.context = context
        self.peerId = peerId
        self.upgradedToSupergroup = upgradedToSupergroup
        self.adminId = adminId
        self.initialParticipant = initialParticipant
        self.updated = updated
        super.init(frame: NSMakeRect(0, 0, 300, 360))
        bar = .init(height : 0)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.listHeight)), animated: false)
    }
    
    override func viewClass() -> AnyClass {
        return TableView.self
    }
    
    private var genericView:TableView {
        return self.view as! TableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let combinedPromise: Promise<CombinedView> = Promise()
        
        let context = self.context
        var peerId = self.peerId
        let adminId = self.adminId
        let initialParticipant = self.initialParticipant
        let updated = self.updated
        let upgradedToSupergroup = self.upgradedToSupergroup

        
        

        let initialValue = ChannelAdminControllerState(rank: initialParticipant?.rank, initialRank: initialParticipant?.rank)
        let stateValue = Atomic(value: initialValue)
        let statePromise = ValuePromise(initialValue, ignoreRepeated: true)
        let updateState: ((ChannelAdminControllerState) -> ChannelAdminControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let dismissImpl:()-> Void = { [weak self] in
            self?.close()
        }
        
        let actionsDisposable = DisposableSet()
        
        let updateRightsDisposable = MetaDisposable()
        actionsDisposable.add(updateRightsDisposable)
        
        let arguments = ChannelAdminControllerArguments(context: context, toggleRight: { right, flags in
            updateState { current in
                var updated = flags
                if flags.contains(right) {
                    updated.remove(right)
                } else {
                    updated.insert(right)
                }
                
                return current.withUpdatedUpdatedFlags(updated)
            }
        }, dismissAdmin: {
            updateState { current in
                return current.withUpdatedUpdating(true)
            }
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                updateRightsDisposable.set((removeGroupAdmin(account: context.account, peerId: peerId, adminId: adminId)
                    |> deliverOnMainQueue).start(error: { _ in
                    }, completed: {
                        updated(TelegramChatAdminRights(flags: []))
                        dismissImpl()
                    }))
            } else {
                updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: []), rank: stateValue.with { $0.rank }) |> deliverOnMainQueue).start(error: { _ in
                    
                }, completed: {
                    updated(TelegramChatAdminRights(flags: []))
                    dismissImpl()
                }))
            }
        }, cantEditError: { [weak self] in
            self?.show(toaster: ControllerToaster(text: L10n.channelAdminCantEdit))
        }, transferOwnership: {
            _ = (combineLatest(queue: .mainQueue(), context.account.postbox.loadedPeerWithId(peerId), context.account.postbox.loadedPeerWithId(adminId))).start(next: { peer, admin in
                
                let header: String
                let text: String
                if peer.isChannel {
                    header = L10n.channelAdminTransferOwnershipConfirmChannelTitle
                    text = L10n.channelAdminTransferOwnershipConfirmChannelText(peer.displayTitle, admin.displayTitle)
                } else {
                    header = L10n.channelAdminTransferOwnershipConfirmGroupTitle
                    text = L10n.channelAdminTransferOwnershipConfirmGroupText(peer.displayTitle, admin.displayTitle)
                }
                
                let checkPassword:(PeerId)->Void = { peerId in
                    showModal(with: InputPasswordController(context: context, title: L10n.channelAdminTransferOwnershipPasswordTitle, desc: L10n.channelAdminTransferOwnershipPasswordDesc, checker: { pwd in
                        return context.peerChannelMemberCategoriesContextsManager.transferOwnership(account: context.account, peerId: peerId, memberId: admin.id, password: pwd)
                            |> deliverOnMainQueue
                            |> ignoreValues
                            |> `catch` { error -> Signal<Never, InputPasswordValueError> in
                            switch error {
                            case .generic:
                                return .fail(.generic)
                            case .invalidPassword:
                                return .fail(.wrong)
                            default:
                                return .fail(.generic)
                            }
                        }  |> afterCompleted {
                            dismissImpl()
                            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 2.0)
                        }
                    }), for: context.window)
                    
                }
                
                let transfer:(PeerId, Bool, Bool)->Void = { _peerId, isGroup, convert in
                    actionsDisposable.add(showModalProgress(signal: checkOwnershipTranfserAvailability(postbox: context.account.postbox, network: context.account.network, accountStateManager: context.account.stateManager, memberId: adminId), for: context.window).start(error: { error in
                        let errorText: String?
                        var install2Fa = false
                        switch error {
                        case .generic:
                            errorText = L10n.unknownError
                        case .tooMuchJoined:
                            errorText = L10n.channelErrorAddTooMuch
                        case .authSessionTooFresh:
                            errorText = L10n.channelTransferOwnerErrorText
                        case .invalidPassword:
                            preconditionFailure()
                        case .requestPassword:
                            errorText = nil
                        case .twoStepAuthMissing:
                            errorText = L10n.channelTransferOwnerErrorText
                            install2Fa = true
                        case .twoStepAuthTooFresh:
                            errorText = L10n.channelTransferOwnerErrorText
                        case .restricted, .userBlocked:
                            errorText = isGroup ? L10n.groupTransferOwnerErrorPrivacyRestricted : L10n.channelTransferOwnerErrorPrivacyRestricted
                        case .adminsTooMuch:
                             errorText = isGroup ? L10n.groupTransferOwnerErrorAdminsTooMuch : L10n.channelTransferOwnerErrorAdminsTooMuch
                        case .userPublicChannelsTooMuch:
                            errorText = L10n.channelTransferOwnerErrorPublicChannelsTooMuch
                        case .limitExceeded:
                            errorText = L10n.loginFloodWait
                        case .userLocatedGroupsTooMuch:
                            errorText = L10n.groupOwnershipTransferErrorLocatedGroupsTooMuch
                        }
                        
                        if let errorText = errorText {
                            confirm(for: context.window, header: L10n.channelTransferOwnerErrorTitle, information: errorText, okTitle: L10n.modalOK, cancelTitle: L10n.modalCancel, thridTitle: install2Fa ? L10n.channelTransferOwnerErrorEnable2FA : nil, successHandler: { result in
                                switch result {
                                case .basic:
                                    break
                                case .thrid:
                                    dismissImpl()
                                    context.sharedContext.bindings.rootNavigation().removeUntil(EmptyChatViewController.self)
                                    context.sharedContext.bindings.rootNavigation().push(twoStepVerificationUnlockController(context: context, mode: .access(nil), presentController: { (controller, isRoot, animated) in
                                        let navigation = context.sharedContext.bindings.rootNavigation()
                                        if isRoot {
                                            navigation.removeUntil(EmptyChatViewController.self)
                                        }
                                        if !animated {
                                            navigation.stackInsert(controller, at: navigation.stackCount)
                                        } else {
                                            navigation.push(controller)
                                        }
                                    }))
                                }
                            })
                        } else {
                            if convert {
                                actionsDisposable.add(showModalProgress(signal: convertGroupToSupergroup(account: context.account, peerId: peer.id), for: context.window).start(next: { upgradedPeerId in
                                    upgradedToSupergroup(upgradedPeerId, {
                                        peerId = upgradedPeerId
                                        combinedPromise.set(context.account.postbox.combinedView(keys: [.peer(peerId: upgradedPeerId, components: .all), .peer(peerId: adminId, components: .all)]))
                                        checkPassword(upgradedPeerId)
                                    })
                                }, error: { error in
                                    dismissImpl()
                                }))
                            } else {
                               checkPassword(peer.id)
                            }
                        }
                    }))
                }
                
                confirm(for: context.window, header: header, information: text, okTitle: L10n.channelAdminTransferOwnershipConfirmOK, successHandler: { _ in
                    transfer(peerId, peer.isSupergroup || peer.isGroup, peer.isGroup)
                })
            })
        }, updateRank: { rank in
            updateState {
                $0.withUpdatedRank(rank)
            }
        })
        
        self.arguments = arguments
        
        
        combinedPromise.set(context.account.postbox.combinedView(keys: [.peer(peerId: peerId, components: .all), .peer(peerId: adminId, components: .all)]))
        
        let previous:Atomic<[AppearanceWrapperEntry<ChannelAdminEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        
        let signal = combineLatest(statePromise.get(), combinedPromise.get(), appearanceSignal)
            |> deliverOn(prepareQueue)
            |> map { state, combinedView, appearance -> (transition: TableUpdateTransition, canEdit: Bool, canDismiss: Bool, channelView: PeerView) in
                let channelView = combinedView.views[.peer(peerId: peerId, components: .all)] as! PeerView
                let adminView = combinedView.views[.peer(peerId: adminId, components: .all)] as! PeerView
                let canEdit = canEditAdminRights(accountPeerId: context.account.peerId, channelView: channelView, initialParticipant: initialParticipant)
                var canDismiss = false

                if let channel = peerViewMainPeer(channelView) as? TelegramChannel {
                    
                    if let initialParticipant = initialParticipant {
                        if channel.flags.contains(.isCreator) {
                            canDismiss = initialParticipant.adminInfo != nil
                        } else {
                            switch initialParticipant {
                            case .creator:
                                break
                            case let .member(_, _, adminInfo, _, _):
                                if let adminInfo = adminInfo {
                                    if adminInfo.promotedBy == context.account.peerId || adminInfo.canBeEditedByAccountPeer {
                                        canDismiss = true
                                    }
                                }
                            }
                        }
                    }
                }
                let result = channelAdminControllerEntries(state: state, accountPeerId: context.account.peerId, channelView: channelView, adminView: adminView, initialParticipant: initialParticipant)
                let entries = result.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
                _ = stateValue.modify({$0.withUpdatedEditable(canEdit)})
                return (transition: prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), canEdit: canEdit, canDismiss: canDismiss, channelView: channelView)
                
        } |> afterDisposed {
            actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        let updatedSize:Atomic<Bool> = Atomic(value: false)
        
        disposable.set(signal.start(next: { [weak self] values in
            self?.genericView.merge(with: values.transition)
            self?.readyOnce()
            self?.updateSize(updatedSize.swap(true))
            
            self?.modal?.interactions?.updateDone { button in
                
                button.isEnabled = values.canEdit
                button.set(text: L10n.navigationDone, for: .Normal)
            }
            self?.modal?.interactions?.updateCancel { button in
                button.set(text: values.canDismiss ? L10n.channelAdminDismiss : "", for: .Normal)
                button.set(color: values.canDismiss ? theme.colors.redUI : theme.colors.blueText, for: .Normal)
            }
            
            self?.okClick = {
                if let channel = values.channelView.peers[values.channelView.peerId] as? TelegramChannel {
                    if let initialParticipant = initialParticipant {
                        var updateFlags: TelegramChatAdminRightsFlags?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            if let _ = updateFlags {
                                return current.withUpdatedUpdating(true)
                            } else {
                                return current
                            }
                        }
                        
                        if updateFlags == nil {
                            switch initialParticipant {
                            case .creator:
                                if stateValue.with ({ $0.rank != $0.initialRank }) {
                                    updateFlags = .groupSpecific
                                }
                            case let .member(member):
                                if member.adminInfo?.rights == nil {
                                    let maskRightsFlags: TelegramChatAdminRightsFlags
                                    switch channel.info {
                                    case .broadcast:
                                        maskRightsFlags = .broadcastSpecific
                                    case .group:
                                        maskRightsFlags = .groupSpecific
                                    }
                                    
                                    if channel.flags.contains(.isCreator) {
                                        updateFlags = maskRightsFlags.subtracting(.canAddAdmins)
                                    } else if let adminRights = channel.adminRights {
                                        updateFlags = maskRightsFlags.intersection(adminRights.flags).subtracting(.canAddAdmins)
                                    } else {
                                        updateFlags = []
                                    }
                                }
                            }
                        }
                        if updateFlags == nil && stateValue.with ({ $0.rank != $0.initialRank }) {
                            updateFlags = initialParticipant.adminInfo?.rights.flags
                        }
                        
                        if let updateFlags = updateFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags), rank: stateValue.with { $0.rank }) |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                updated(TelegramChatAdminRights(flags: updateFlags))
                                dismissImpl()
                            }))
                        } else {
                            dismissImpl()
                        }
                    } else if values.canEdit {
                        var updateFlags: TelegramChatAdminRightsFlags?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            return current.withUpdatedUpdating(true)
                        }
                        
                        if updateFlags == nil {
                            let maskRightsFlags: TelegramChatAdminRightsFlags
                            switch channel.info {
                            case .broadcast:
                                maskRightsFlags = .broadcastSpecific
                            case .group:
                                maskRightsFlags = .groupSpecific
                            }
                            
                            if channel.flags.contains(.isCreator) {
                                updateFlags = maskRightsFlags.subtracting(.canAddAdmins)
                            } else if let adminRights = channel.adminRights {
                                updateFlags = maskRightsFlags.intersection(adminRights.flags).subtracting(.canAddAdmins)
                            } else {
                                updateFlags = []
                            }
                        }
                        
                        
                        
                        if let updateFlags = updateFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags), rank: stateValue.with { $0.rank }) |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                updated(TelegramChatAdminRights(flags: updateFlags))
                                dismissImpl()
                            }))
                        }
                    }
                } else if let _ = values.channelView.peers[values.channelView.peerId] as? TelegramGroup {
                    var updateFlags: TelegramChatAdminRightsFlags?
                    updateState { current in
                        updateFlags = current.updatedFlags
                        return current
                    }
                    
                    let maskRightsFlags: TelegramChatAdminRightsFlags = .groupSpecific
                    let defaultFlags = maskRightsFlags.subtracting(.canAddAdmins)
                    
                    if updateFlags == nil {
                        updateFlags = defaultFlags
                    }
                    
                    if let updateFlags = updateFlags {
                        if initialParticipant?.adminInfo == nil && updateFlags == defaultFlags && stateValue.with ({ $0.rank == $0.initialRank }) {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((addGroupAdmin(account: context.account, peerId: peerId, adminId: adminId)
                                |> deliverOnMainQueue).start(completed: {
                                    dismissImpl()
                                }))
                        } else if updateFlags != defaultFlags || stateValue.with ({ $0.rank != $0.initialRank }) {
                            let signal = convertGroupToSupergroup(account: context.account, peerId: peerId)
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<PeerId?, NoError> in
                                    return .single(nil)
                                }
                                |> mapToSignal { upgradedPeerId -> Signal<PeerId?, NoError> in
                                    guard let upgradedPeerId = upgradedPeerId else {
                                        return .single(nil)
                                    }
                                    
                                    return  context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: upgradedPeerId, memberId: adminId, adminRights: TelegramChatAdminRights(flags: updateFlags), rank: stateValue.with { $0.rank })
                                        |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                            return .complete()
                                        }
                                        |> then(.single(upgradedPeerId))
                                }
                                |> deliverOnMainQueue
                            
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            
                            
                            updateRightsDisposable.set(showModalProgress(signal: signal, for: mainWindow).start(next: { upgradedPeerId in
                                if let upgradedPeerId = upgradedPeerId {
                                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: upgradedPeerId, updated: { state in
                                       
                                        if case .ready = state.loadingState {
                                            upgradedToSupergroup(upgradedPeerId, {
                                                
                                            })
                                            dismissImpl()
                                        }  
                                    })
                                    actionsDisposable.add(disposable)
                                    
                                }
                            }, error: { _ in
                                updateState { current in
                                    return current.withUpdatedUpdating(false)
                                }
                            }))
                        } else {
                            dismissImpl()
                        }
                    } else {
                        dismissImpl()
                    }
                }
            }
        }))
        
        
    }
    
    private func updateSize(_ animated: Bool) {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 70, genericView.listHeight)), animated: animated)
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    
    override func close() {
        disposable.set(nil)
        super.close()
    }
    
    override func firstResponder() -> NSResponder? {
        let view = self.genericView.item(stableId: ChannelAdminEntryStableId.role)?.view as? GeneralInputRowView
        return view?.textView
    }
    
    
    override func returnKeyAction() -> KeyHandlerResult {
        self.okClick?()
        return .invoked
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
             self?.okClick?()
        }, cancelTitle: L10n.modalCancel, cancel: { [weak self] in
            self?.arguments?.dismissAdmin()
        }, height: 40)
    }
}

