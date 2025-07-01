//
//  ChannelBotAdminController.swift
//  Telegram
//
//  Created by Mike Renoir on 18.03.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation


import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

func addBotAsMember(context: AccountContext, peer: Peer, to: Peer, completion:@escaping(PeerId)->Void, error: @escaping(String)->Void) -> Void {
    if to.isGroup {
        _ = showModalProgress(signal: context.engine.peers.addGroupMember(peerId: to.id, memberId: peer.id), for: context.window).start(error: { _ in
            error(strings().unknownError)
        }, completed: {
            completion(to.id)
        })
    } else {
        completion(to.id)
    }
}



public struct ResolvedBotAdminRights: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let changeInfo = ResolvedBotAdminRights(rawValue: 1)
    public static let postMessages = ResolvedBotAdminRights(rawValue: 2)
    public static let editMessages = ResolvedBotAdminRights(rawValue: 4)
    public static let deleteMessages = ResolvedBotAdminRights(rawValue: 16)
    public static let restrictMembers = ResolvedBotAdminRights(rawValue: 32)
    public static let inviteUsers = ResolvedBotAdminRights(rawValue: 64)
    public static let pinMessages = ResolvedBotAdminRights(rawValue: 128)
    public static let promoteMembers = ResolvedBotAdminRights(rawValue: 256)
    public static let manageVideoChats = ResolvedBotAdminRights(rawValue: 512)
    public static let canBeAnonymous = ResolvedBotAdminRights(rawValue: 1024)
    public static let manageChat = ResolvedBotAdminRights(rawValue: 2048)
    
    public static let postStories = ResolvedBotAdminRights(rawValue: 4096)
    public static let editStories = ResolvedBotAdminRights(rawValue: 8192)
    public static let deleteStories = ResolvedBotAdminRights(rawValue: 16384)
    public static let canManageDirect = ResolvedBotAdminRights(rawValue: 32768)
    
    
    public var chatAdminRights: TelegramChatAdminRightsFlags? {
        var flags = TelegramChatAdminRightsFlags()
        
        if self.contains(ResolvedBotAdminRights.changeInfo) {
            flags.insert(.canChangeInfo)
        }
        if self.contains(ResolvedBotAdminRights.postMessages) {
            flags.insert(.canPostMessages)
        }
        if self.contains(ResolvedBotAdminRights.canManageDirect) {
            flags.insert(.canManageDirect)
        }
        if self.contains(ResolvedBotAdminRights.editMessages) {
            flags.insert(.canEditMessages)
        }
        if self.contains(ResolvedBotAdminRights.deleteMessages) {
            flags.insert(.canDeleteMessages)
        }
        if self.contains(ResolvedBotAdminRights.restrictMembers) {
            flags.insert(.canBanUsers)
        }
        if self.contains(ResolvedBotAdminRights.inviteUsers) {
            flags.insert(.canInviteUsers)
        }
        if self.contains(ResolvedBotAdminRights.pinMessages) {
            flags.insert(.canPinMessages)
        }
        if self.contains(ResolvedBotAdminRights.promoteMembers) {
            flags.insert(.canAddAdmins)
        }
        if self.contains(ResolvedBotAdminRights.manageVideoChats) {
            flags.insert(.canManageCalls)
        }
        if self.contains(ResolvedBotAdminRights.canBeAnonymous) {
            flags.insert(.canBeAnonymous)
        }
        if self.contains(ResolvedBotAdminRights.postStories) {
            flags.insert(.canPostStories)
        }
        if self.contains(ResolvedBotAdminRights.editStories) {
            flags.insert(.canEditStories)
        }
        if self.contains(ResolvedBotAdminRights.deleteStories) {
            flags.insert(.canDeleteStories)
        }
        if flags.isEmpty && !self.contains(ResolvedBotAdminRights.manageChat) {
            return nil
        }
        
        return flags
    }
}
extension ResolvedBotAdminRights {
    init?(_ string: String) {
        var rawValue: UInt32 = 0
        
        let components = string.lowercased().components(separatedBy: "+")
        if components.contains("change_info") {
            rawValue |= ResolvedBotAdminRights.changeInfo.rawValue
        }
        if components.contains("post_messages") {
            rawValue |= ResolvedBotAdminRights.postMessages.rawValue
        }
        if components.contains("delete_messages") {
            rawValue |= ResolvedBotAdminRights.deleteMessages.rawValue
        }
        if components.contains("post_stories") {
            rawValue |= ResolvedBotAdminRights.postStories.rawValue
        }
        if components.contains("edit_stories") {
            rawValue |= ResolvedBotAdminRights.editStories.rawValue
        }
        if components.contains("delete_stories") {
            rawValue |= ResolvedBotAdminRights.deleteStories.rawValue
        }
        if components.contains("restrict_members") {
            rawValue |= ResolvedBotAdminRights.restrictMembers.rawValue
        }
        if components.contains("invite_users") {
            rawValue |= ResolvedBotAdminRights.inviteUsers.rawValue
        }
        if components.contains("pin_messages") {
            rawValue |= ResolvedBotAdminRights.pinMessages.rawValue
        }
        if components.contains("promote_members") {
            rawValue |= ResolvedBotAdminRights.promoteMembers.rawValue
        }
        if components.contains("manage_video_chats") {
            rawValue |= ResolvedBotAdminRights.manageVideoChats.rawValue
        }
        if components.contains("manage_chat") {
            rawValue |= ResolvedBotAdminRights.manageChat.rawValue
        }
        if components.contains("anonymous") {
            rawValue |= ResolvedBotAdminRights.canBeAnonymous.rawValue
        }
        if components.contains("manage_direct_messages") {
            rawValue |= ResolvedBotAdminRights.canManageDirect.rawValue
        }
                
        if rawValue != 0 {
            self.init(rawValue: rawValue)
        } else {
            return nil
        }
    }
}


private final class Arguments {
    let context: AccountContext
    let toggleIsAdmin: ()->Void
    let toggleRight: (RightsItem, Bool) -> Void
    let toggleIsOptionExpanded: (RightsItem.Sub) -> Void
    init(context: AccountContext, toggleIsAdmin: @escaping()->Void, toggleRight: @escaping(RightsItem, Bool) -> Void, toggleIsOptionExpanded: @escaping(RightsItem.Sub) -> Void) {
        self.context = context
        self.toggleIsAdmin = toggleIsAdmin
        self.toggleRight = toggleRight
        self.toggleIsOptionExpanded = toggleIsOptionExpanded
    }
}

private struct State : Equatable {
    var peer: PeerEquatable
    var admin: PeerEquatable
    var isAdmin: Bool = true
    var rights: TelegramChatAdminRightsFlags
    var title: String?
    var expandedPermissions: Set<RightsItem.Sub> = Set()
}


private let _id_header = InputDataIdentifier("_id_header")
private let _id_admin_rights = InputDataIdentifier("_id_admin_rights")
private let _id_title = InputDataIdentifier("_id_title")
private func _id_admin_right(_ right: RightsItem) -> InputDataIdentifier {
    switch right {
    case let .direct(right):
        return .init("_id_admin_right_\(right.rawValue)")
    case let .sub(_, rights):
        return rights.reduce(InputDataIdentifier(""), { current, value in
            return .init(current.identifier + _id_admin_right(.direct(value)).identifier)
        })
    }
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state.admin), comparable: nil, item: { initialSize, stableId in
        let string:String = strings().presenceBot
        let color:NSColor = theme.colors.grayText
        return ShortPeerRowItem(initialSize, peer: state.admin.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, enabled: true, height: 60, photoSize: NSMakeSize(40, 40), statusStyle: ControlStyle(font: .normal(.title), foregroundColor: color), status: string, inset: NSEdgeInsets(left: 20, right: 20), viewType: .singleItem, action: {})
    }))
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_admin_rights, data: .init(name: strings().channelAddBotAdminRights, color: theme.colors.text, type: .switchable(state.isAdmin), viewType: .singleItem, action: arguments.toggleIsAdmin)))
    
    if state.isAdmin {
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
        
                
        let isGroup: Bool
        let maskRightsFlags: TelegramChatAdminRightsFlags
        let rightsOrder: [RightsItem]
        
        if let channel = state.peer.peer as? TelegramChannel {
            maskRightsFlags = .peerSpecific(peer: .init(channel))
            switch channel.info {
            case .broadcast:
                isGroup = false
                rightsOrder = [
                    .direct(.canChangeInfo),
                    .sub(.messages, messageRelatedFlags),
                    .sub(.stories, storiesRelatedFlags),
                    .direct(.canInviteUsers),
                    .direct(.canManageCalls),
                    .direct(.canAddAdmins)
                ]
            case .group:
                isGroup = true
                if channel.flags.contains(.isForum) {
                    rightsOrder = [
                        .direct(.canChangeInfo),
                        .direct(.canDeleteMessages),
                        .direct(.canBanUsers),
                        .direct(.canInviteUsers),
                        .direct(.canPinMessages),
                        .direct(.canManageTopics),
                        .direct(.canManageCalls),
                        .direct(.canBeAnonymous),
                        .direct(.canAddAdmins)
                    ]
                } else {
                    rightsOrder = [
                        .direct(.canChangeInfo),
                        .direct(.canDeleteMessages),
                        .direct(.canBanUsers),
                        .direct(.canInviteUsers),
                        .direct(.canPinMessages),
                        .direct(.canManageCalls),
                        .direct(.canBeAnonymous),
                        .direct(.canAddAdmins)
                    ]
                }
            }
        } else {
            isGroup = true
            maskRightsFlags = .internal_groupSpecific
            rightsOrder = [
                .direct(.canChangeInfo),
                .direct(.canDeleteMessages),
                .direct(.canBanUsers),
                .direct(.canInviteUsers),
                .direct(.canManageCalls),
                .direct(.canPinMessages),
                .direct(.canBeAnonymous),
                .direct(.canAddAdmins)
            ]
        }
        
        
        for (i, rights) in rightsOrder.enumerated() {
            switch rights {
            case let .direct(right):
                let text = stringForRight(right: right, isGroup: state.peer.peer.isGroup || state.peer.peer.isSupergroup, defaultBannedRights: nil)
                
                
                var enabled: Bool = state.peer.peer.groupAccess.isCreator
                
                let peer = state.peer.peer as? TelegramChannel
                
                if let adminRights = peer?.adminRights, !enabled {
                    enabled = adminRights.rights.contains(right)
                }
                
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_admin_right(rights), data: .init(name: text, color: theme.colors.text, type: .switchable(state.rights.contains(right)), viewType: bestGeneralViewType(rightsOrder, for: i), enabled: enabled, action: {
                    // arguments.toggleAdminRight(right)
                })))
            case let .sub(type, subRights):
                
                let isExpanded = state.expandedPermissions.contains(type)
                
                let text: String
                switch type {
                case .messages:
                    text = strings().channelEditAdminPermissionManageMessages
                case .stories:
                    text = strings().channelEditAdminPermissionManageStories
                }
                
                var enabled: Bool = state.peer.peer.groupAccess.isCreator
                                
                if let adminRights = (state.peer.peer as? TelegramChannel)?.adminRights, !enabled {
                    let subRights = subRights.filter { adminRights.rights.contains($0) }
                    enabled = !subRights.isEmpty
                }
                let isSelected = subRights.filter({ state.rights.contains($0) }).count == subRights.count
                
                let string: NSMutableAttributedString = NSMutableAttributedString()
                string.append(string: text, color: theme.colors.text, font: .normal(.title))
                
                let selectedCount = subRights.filter { state.rights.contains($0) }.count
                string.append(string: " \(selectedCount)/\(subRights.count)", color: theme.colors.text, font: .bold(.short))
                
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_admin_right(rights), data: .init(name: text, color: theme.colors.text, type: .switchable(isSelected), viewType: bestGeneralViewType(rightsOrder, for: i), enabled: enabled, action: {
                    switch rights {
                    case .direct:
                        arguments.toggleRight(rights, !isSelected)
                    case let .sub(type, _):
                        arguments.toggleIsOptionExpanded(type)
                    }
                }, switchAction: {
                    arguments.toggleRight(rights, !isSelected)
                }, nameAttributed: string)))
                
                if isExpanded {
                    for right in subRights {
                        let text = stringForRight(right: right, isGroup: state.peer.peer.isGroup || state.peer.peer.isSupergroup, defaultBannedRights: nil)
                        let isSelected = state.rights.contains(right)
                        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_admin_right(.direct(right)), data: .init(name: text, color: theme.colors.text, type: .selectableLeft(isSelected), viewType: .innerItem, enabled: enabled, action: {
                            arguments.toggleRight(.direct(right), !isSelected)
                        })))
                    }
                }
            }
        }
        
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(state.title), error: nil, identifier: _id_title, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().channelAddBotCustomTitle, filter: { text in
            let filtered = text.filter { character -> Bool in
                return !String(character).containsOnlyEmoji
            }
            return filtered
        }, limit: 16))

    }
        
   
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

func ChannelBotAdminController(context: AccountContext, peer: Peer, admin: Peer, rights:String? = nil, callback:@escaping(PeerId)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let rights = ResolvedBotAdminRights(rights ?? "")?.chatAdminRights ?? [.canChangeInfo,
                                                                           .canDeleteMessages,
                                                                           .canBanUsers,
                                                                           .canInviteUsers,
                                                                           .canPinMessages]
    
    let initialState = State(peer: .init(peer), admin: .init(admin), rights: rights)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil

    let arguments = Arguments(context: context, toggleIsAdmin: {
        updateState { current in
            var current = current
            current.isAdmin = !current.isAdmin
            return current
        }
    }, toggleRight: { rights, value in
        updateState { current in
            var current = current
            var updated = current.rights
            var combinedRight: TelegramChatAdminRightsFlags
            switch rights {
            case let .direct(right):
                combinedRight = right
            case let .sub(_, right):
                combinedRight = []
                for flag in right {
                    combinedRight.insert(flag)
                }
            }
            if !value {
                updated.remove(combinedRight)
            } else {
                updated.insert(combinedRight)
            }
            current.rights = updated
            return current
        }
    }, toggleIsOptionExpanded: { flag in
        updateState { state in
            var state = state
            
            if state.expandedPermissions.contains(flag) {
                state.expandedPermissions.remove(flag)
            } else {
                state.expandedPermissions.insert(flag)
            }
            
            return state
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().channelAddBotTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().channelAddBotButtonAdmin, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.afterTransaction = { [weak modalInteractions] controller in
        if let modalInteractions = modalInteractions {
            modalInteractions.updateDone({ button in
                button.set(text: stateValue.with { $0.isAdmin} ? strings().channelAddBotButtonAdmin : strings().channelAddBotButtonMember, for: .Normal)
            })
        }
    }
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.title = data[_id_title]?.stringValue
            return current
        }
        return .none
    }
    
    controller.validateData = { _ in
        
        return .fail(.doSomething(next: { f in
            let peer = stateValue.with { $0.peer.peer }
            let admin = stateValue.with { $0.admin.peer }
            let isAdmin = stateValue.with { $0.isAdmin }
            let rights = stateValue.with { $0.rights }
            
            let rank = stateValue.with { $0.title }

            let title: String = isAdmin ? strings().channelAddBotConfirmTitleAdmin : strings().channelAddBotConfirmTitleMember
            let info: String = strings().channelAddBotConfirmInfo(peer.displayTitle)
            let ok: String = isAdmin ? strings().channelAddBotConfirmOkAdmin : strings().channelAddBotConfirmOkMember
            let cancel: String = strings().modalCancel
            
            verifyAlert_button(for: context.window, header: title, information: info, ok: ok, cancel: cancel, successHandler: { _ in
                
                var signal: Signal<PeerId, (AddGroupMemberError?, AddChannelMemberError?, ConvertGroupToSupergroupError?)>
                
                if isAdmin {
                    let add:(PeerId)->Signal<PeerId, (AddGroupMemberError?, AddChannelMemberError?, ConvertGroupToSupergroupError?)> = { peerId in
                        return context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(peerId: peerId, memberId: admin.id, adminRights: .init(rights: rights), rank: rank)
                        |> map { _ in
                            return peerId
                        }
                        |> castError(AddChannelMemberError.self)
                        |> mapError { (nil, $0, nil) }
                    }
                    
                    if peer.id.namespace == Namespaces.Peer.CloudGroup {
                        let convert: Signal<PeerId, (AddGroupMemberError?, AddChannelMemberError?, ConvertGroupToSupergroupError?)> = context.engine.peers.convertGroupToSupergroup(peerId: peer.id)
                        |> mapError { (nil, nil, $0) }
                        signal = convert |> mapToSignal {
                            add($0)
                        }
                    } else {
                        signal = add(peer.id)
                    }
                } else {
                    if peer.id.namespace == Namespaces.Peer.CloudGroup {
                        signal = context.engine.peers.addGroupMember(peerId: peer.id, memberId: admin.id)
                        |> mapError { ($0, nil, nil) }
                        |> map { peer.id }
                    } else {
                        signal = .single(peer.id)
                        |> mapError { (nil, $0, nil) }
                    }
                }
                _ = showModalProgress(signal: signal, for: context.window).start(next: { peerId in
                    f(.none)
                    callback(peerId)
                    close?()
                    showModalText(for: context.window, text: isAdmin ? strings().channelAddBotSuccessAdmin(admin.displayTitle, peer.displayTitle) : strings().channelAddBotSuccessMember(admin.displayTitle, peer.displayTitle))
                }, error: { error in
                    if let _ = error.0 {
                        alert(for: context.window, info: strings().unknownError)
                    } else if let error = error.1 {
                        let text: String
                        switch error {
                        case .notMutualContact:
                            text = strings().channelInfoAddUserLeftError
                        case .limitExceeded:
                            text = strings().channelErrorAddTooMuch
                        case .botDoesntSupportGroups:
                            text = strings().channelBotDoesntSupportGroups
                        case .tooMuchBots:
                            text = strings().channelTooMuchBots
                        case .tooMuchJoined:
                            text = strings().inviteChannelsTooMuch
                        case .generic:
                            text = strings().unknownError
                        case .bot:
                            text = strings().channelAddBotErrorHaveRights
                        case .restricted:
                            text = strings().channelErrorAddBlocked
                        case .kicked:
                            text = strings().channelAddUserKickedError
                        }
                        alert(for: context.window, info: text)
                    } else if let error = error.2 {
                        switch error {
                        case .generic:
                            alert(for: context.window, info: strings().unknownError)
                        case .tooManyChannels:
                            showInactiveChannels(context: context, source: .upgrade)
                        }
                    }
                })
            })
            
        }))
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}

