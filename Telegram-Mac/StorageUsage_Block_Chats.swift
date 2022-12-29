//
//  StorageUsage_Block_ChatsController.swift
//  Telegram
//
//  Created by Mike Renoir on 23.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let toggle:(PeerId, Peer)->Void
    let open:(PeerId)->Void
    let clear:(PeerId)->Void
    init(context: AccountContext, toggle:@escaping(PeerId, Peer)->Void, open:@escaping(PeerId)->Void, clear:@escaping(PeerId)->Void) {
        self.context = context
        self.toggle = toggle
        self.open = open
        self.clear = clear
    }
}


private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer\(id.toInt64())")
}
private func entries(_ state: StorageUsageUIState, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
   
    let sorted = state.peers.map { $0.value }.sorted(by: { lhs, rhs in
        if lhs.stats.totalCount == rhs.stats.totalCount {
            if lhs.peer._asPeer().displayTitle == rhs.peer._asPeer().displayTitle {
                return lhs.peer.id > rhs.peer.id
            }
            return lhs.peer._asPeer().displayTitle > rhs.peer._asPeer().displayTitle
        } else {
            return lhs.stats.totalCount > rhs.stats.totalCount
        }
    })
    
    struct TuplePeer : Equatable {
        let peer: PeerEquatable
        let count: String
        let selected: Bool?
        let viewType: GeneralViewType
    }
    var items:[TuplePeer] = []
    
    for (i, sort) in sorted.enumerated() {
        let viewType: GeneralViewType
        if i == 0 {
            if sorted.count == 1 {
                viewType = .lastItem
            } else {
                viewType = .innerItem
            }
        } else {
            viewType = bestGeneralViewType(sorted, for: i)
        }
        items.append(.init(peer: .init(sort.peer._asPeer()), count: String.prettySized(with: sort.stats.totalCount), selected: state.editing ? state.selectedPeers.selected.contains(sort.peer.id) : nil, viewType: viewType))
    }
    
    
    let interaction: SelectPeerInteraction = .init()
    
    interaction.update { _ in
        state.selectedPeers
    }
    interaction.action = { peerId, _ in
        if let item = items.first(where: { $0.peer.peer.id == peerId }) {
            arguments.toggle(peerId, item.peer.peer)
        }
    }
    for item in items {
        entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
            
            let type: ShortPeerItemInteractionType
            if let _ = item.selected {
                type = .selectable(interaction, side: .left)
            } else {
                type = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 42, photoSize: NSMakeSize(30, 30), isLookSavedMessage: true, inset: NSEdgeInsets(), interactionType: type, generalType: .context(item.count), viewType: item.viewType, action: {
                arguments.open(item.peer.peer.id)
            }, contextMenuItems: {
                
                var items: [ContextMenuItem] = []
                
                items.append(ContextMenuItem(strings().storageUsageMessageContextSelect, handler: {
                    arguments.toggle(item.peer.peer.id, item.peer.peer)
                }, itemImage: MenuAnimation.menu_select_messages.value))
                items.append(ContextSeparatorItem())
                
                items.append(ContextMenuItem(strings().storageUsageClearConfirmOKAll, handler: {
                    arguments.clear(item.peer.peer.id)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                
                return .single(items)
            })
        }))
        index += 1
    }
    
    
    if state.editing {
        entries.append(.sectionId(sectionId, type: .customModern(70)))
        sectionId += 1
    } else {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
  
    
    return entries
}

func StorageUsage_Block_Chats(context: AccountContext, storageArguments: StorageUsageArguments, state: Signal<StorageUsageUIState, NoError>, updateState:@escaping((StorageUsageUIState)->StorageUsageUIState)->StorageUsageUIState) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let arguments = Arguments(context: context, toggle: { peerId, peer in
        _ = updateState { current in
            var current = current
            current.selectedPeers = current.selectedPeers.withToggledSelected(peerId, peer: peer)
            if let stats = current.allStats?.peers[peerId] {
                if current.selectedPeers.selected.contains(peerId) {
                    for id in stats.stats.msgIds {
                        current.selectedMessages.insert(id)
                    }
                } else {
                    for id in stats.stats.msgIds {
                        current.selectedMessages.remove(id)
                    }
                }
            }
            current.editing = true
            return current
        }
    }, open: { peerId in
        context.bindings.rootNavigation().push(StorageUsageController(context, peerId: peerId, updateMainState: updateState))
    }, clear: { peerId in
        storageArguments.clearPeer(peerId)
    })
    
    let signal = state |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), grouping: false, animateEverything: true)
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
