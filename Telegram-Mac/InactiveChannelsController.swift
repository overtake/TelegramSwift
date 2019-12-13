//
//  InactiveChannelsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/12/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore

private final class InactiveChannelsArguments  {
    let context: AccountContext
    let delete: (PeerId)->Void
    init(context: AccountContext, delete: @escaping(PeerId)->Void) {
        self.context = context
        self.delete = delete
    }
}

private struct InactiveChannelsState : Equatable {
    let channels:[PeerEquatable]
    let processing:Set<PeerId>
    init(channels: [PeerEquatable], processing: Set<PeerId>) {
        self.channels = channels
        self.processing = processing
    }
    func withUpdatedChannels(_ channels: [PeerEquatable]) -> InactiveChannelsState {
        return InactiveChannelsState(channels: channels, processing: self.processing)
    }
}


private func inactiveEntries(state: InactiveChannelsState, arguments: InactiveChannelsArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("INACTIVE GROUPS AND CHANNELS"), data: .init(color: theme.colors.grayText, viewType: .textTopItem)))
    index += 1
    
    for channel in state.channels {
        
        struct _Equatable : Equatable {
            let channel: PeerEquatable
            let processing: Bool
        }
        let equatable = _Equatable(channel: channel, processing: state.processing.contains(channel.peer.id))
        
        let interaction = ShortPeerItemInteractionType.deletable(onRemove: { peerId in
            
        }, deletable: true)
        
        let viewType = bestGeneralViewType(state.channels, for: channel)
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_peer_\(channel.peer.id.toInt64())"), equatable: InputDataEquatable(equatable), item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: channel.peer, account: arguments.context.account, stableId: stableId, enabled: !equatable.processing, height: 50, photoSize: NSMakeSize(36, 36), status: "inactive 2 month", inset: NSEdgeInsets(left: 30, right: 30), interactionType: interaction, viewType: viewType)
        }))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func InactiveChannelsController(context: AccountContext, inactive: [PeerEquatable]) -> InputDataModalController {
    let initialState = InactiveChannelsState(channels: inactive, processing: Set())
    let statePromise = ValuePromise<InactiveChannelsState>(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InactiveChannelsState) -> InactiveChannelsState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let disposable = MetaDisposable()
    
    let arguments = InactiveChannelsArguments(context: context, delete: { peerId in
        
    })
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: inactiveEntries(state: state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Inactive Chats")
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.modalOK, accept: {
        close?()
    }, height: 50, singleButton: true)
    
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        return .none
    }
    controller.onDeinit = {
        disposable.dispose()
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(300, 300))
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
    
}



func showInactiveChannels(context: AccountContext) {
    
    let peersSignal = context.account.postbox.transaction{ transaction -> [PeerEquatable] in
        var peers:[PeerEquatable] = []
        if let peer = transaction.getPeer(context.peerId) {
            peers.append(PeerEquatable(peer))
        }
        return peers
    }
    
    _ = showModalProgress(signal: peersSignal, for: context.window).start(next: { inactive in
        showModal(with: InactiveChannelsController(context: context, inactive: inactive), for: context.window)
    })
}
