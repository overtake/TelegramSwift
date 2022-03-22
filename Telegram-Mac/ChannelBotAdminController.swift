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

private final class Arguments {
    let context: AccountContext
    let toggleIsAdmin: ()->Void
    let toggleAdminRight: (TelegramChatAdminRightsFlags)->Void
    init(context: AccountContext, toggleIsAdmin: @escaping()->Void, toggleAdminRight: @escaping(TelegramChatAdminRightsFlags)->Void) {
        self.context = context
        self.toggleIsAdmin = toggleIsAdmin
        self.toggleAdminRight = toggleAdminRight
    }
}

private struct State : Equatable {
    var peer: PeerEquatable
    var admin: PeerEquatable
    var isAdmin: Bool = true
    var rights: TelegramChatAdminRightsFlags = [.canChangeInfo,
                                                .canDeleteMessages,
                                                .canBanUsers,
                                                .canInviteUsers,
                                                .canPinMessages]
    var title: String?
}


private let _id_header = InputDataIdentifier("_id_header")
private let _id_admin_rights = InputDataIdentifier("_id_admin_rights")
private let _id_title = InputDataIdentifier("_id_title")
private func _id_admin_right(_ right: TelegramChatAdminRightsFlags) -> InputDataIdentifier {
    return .init("_id_admin_right_\(right.rawValue)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state.admin), comparable: nil, item: { initialSize, stableId in
        let string:String = strings().presenceBot
        let color:NSColor = theme.colors.grayText
        return ShortPeerRowItem(initialSize, peer: state.admin.peer, account: arguments.context.account, stableId: stableId, enabled: true, height: 60, photoSize: NSMakeSize(40, 40), statusStyle: ControlStyle(font: .normal(.title), foregroundColor: color), status: string, inset: NSEdgeInsets(left: 30, right: 30), viewType: .singleItem, action: {})
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_admin_rights, data: .init(name: "Admin Rights", color: theme.colors.text, type: .switchable(state.isAdmin), viewType: .singleItem, action: arguments.toggleIsAdmin)))
    index += 1
    
    if state.isAdmin {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        let rightsOrder: [TelegramChatAdminRightsFlags]
        
        rightsOrder = [
            .canChangeInfo,
            .canDeleteMessages,
            .canBanUsers,
            .canInviteUsers,
            .canPinMessages,
            .canBeAnonymous
        ]
        
        for (i, right) in rightsOrder.enumerated() {
            let text = stringForRight(right: right, isGroup: state.peer.peer.isGroup || state.peer.peer.isChannel, defaultBannedRights: nil)
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_admin_right(right), data: .init(name: text, color: theme.colors.text, type: .switchable(state.isAdmin), viewType: bestGeneralViewType(rightsOrder, for: i), action: {
                arguments.toggleAdminRight(right)
            })))
            index += 1
        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(state.title), error: nil, identifier: _id_title, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: "Custom title", filter: { text in
            let filtered = text.filter { character -> Bool in
                return !String(character).containsOnlyEmoji
            }
            return filtered
        }, limit: 16))
        index += 1

    }
        
   
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ChannelBotAdminController(context: AccountContext, peer: Peer, admin: Peer, callback:@escaping(PeerId)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(peer: .init(peer), admin: .init(admin))
    
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
    }, toggleAdminRight: { right in
        updateState { current in
            var current = current
            if current.rights.contains(right) {
                current.rights.remove(right)
            } else {
                current.rights.insert(right)
            }
            return current
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
    }, drawBorder: true, height: 50, singleButton: true)
    
    
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
            
            confirm(for: context.window, header: title, information: info, okTitle: ok, cancelTitle: cancel, successHandler: { _ in
                
                var signal: Signal<PeerId, (AddGroupMemberError?, AddChannelMemberError?, ConvertGroupToSupergroupError?)>
                
                if isAdmin {
                    let add:(PeerId)->Signal<PeerId, (AddGroupMemberError?, AddChannelMemberError?, ConvertGroupToSupergroupError?)> = { peerId in
                        return context.peerChannelMemberCategoriesContextsManager.addMembers(peerId: peerId, memberIds: [admin.id])
                        |> mapError { (nil, $0, nil) }
                        |> mapToSignal { _ in
                            return context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(peerId: peerId, memberId: admin.id, adminRights: .init(rights: rights), rank: rank)
                            |> map { _ in
                                return peerId
                            }
                            |> castError(AddChannelMemberError.self)
                            |> mapError { (nil, $0, nil) }
                        }
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
                        signal = context.peerChannelMemberCategoriesContextsManager.addMembers(peerId: peer.id, memberIds: [admin.id])
                        |> map { _ in
                            return peer.id
                        }
                        
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

