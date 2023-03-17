//
//  ShareCloudFolderController.swift
//  Telegram
//
//  Created by Mike Renoir on 17.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox



private final class Arguments {
    let context: AccountContext
    let select: SelectPeerInteraction
    init(context: AccountContext, select: SelectPeerInteraction) {
        self.context = context
        self.select = select
    }
}

private struct State : Equatable {
    var peers: [PeerEquatable] = []
    var selected: Set<PeerId> = Set()
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_link = InputDataIdentifier("_id_link")
private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        let attr: NSMutableAttributedString = .init()
        attr.append(string: "Anyone with this link can add **Gaming Club** folder and the 2 chats selected below", color: theme.colors.listGrayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.new_folder, text: attr, stickerSize: NSMakeSize(80, 80))
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("INVITE LINK"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_link, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.context, exportedLink: _ExportedInvitation.initialize(.link(link: "https://t.me/+FAByF3", title: "Link", isPermanent: true, requestApproval: false, isRevoked: false, adminId: arguments.context.peerId, date: 0, startDate: 0, expireDate: nil, usageLimit: nil, count: nil, requestedCount: nil)), lastPeers: [], viewType: .singleItem, mode: .normal(hasUsage: false), menuItems: {

            var items:[ContextMenuItem] = []
            return .single(items)
        }, share: { _ in }, copyLink: { _ in })
    }))
    index += 1
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("3 CHATS SELECTED"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    struct Tuple : Equatable {
        let peer: PeerEquatable
        let selected: Bool
        let viewType: GeneralViewType
        let selectable: Bool
    }
    
    var items: [Tuple] = []
    
    for (i, peer) in state.peers.enumerated() {
        items.append(.init(peer: peer, selected: state.selected.contains(peer.peer.id), viewType: bestGeneralViewType(state.peers, for: i), selectable: true))
    }
    
    for item in items {
        
        let interactionType: ShortPeerItemInteractionType
        if item.selectable {
            interactionType = .selectable(arguments.select, side: .left)
        } else {
            interactionType = .plain
        }
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, status: "you can invite others here", inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, viewType: item.viewType)
        }))
        index += 1
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Select groups and channels that you want everyone who adds the folder via invite link to join."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
   
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func ShareCloudFolderController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    
    let peers: [PeerEquatable] = [context.myPeer].compactMap { .init($0) }

    let initialState = State(peers: peers, selected: Set(peers.map { $0.peer.id }))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    

    let selected = SelectPeerInteraction()
    
    selected.action = { peerId, _ in
        let peer = stateValue.with { $0.peers.first(where: { $0.peer.id == peerId }) }?.peer
        if let peer = peer {
            selected.update({
                $0.withToggledSelected(peerId, peer: peer)
            })
        }
        updateState { current in
            var current = current
            current.selected = selected.presentation.selected
            return current
        }
    }
    
    for peer in peers {
        selected.toggleSelection(peer.peer)
    }

    let arguments = Arguments(context: context, select: selected)

    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Share Folder")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: {
       close?()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


/*
 
 */



