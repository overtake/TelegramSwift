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
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var stats: AllStorageUsageStats
}

private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer\(id.toInt64())")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
   
    let sorted = state.stats.peers.map { $0.value }.sorted(by: { $0.stats.totalCount > $1.stats.totalCount })
    
    struct TuplePeer : Equatable {
        let peer: PeerEquatable
        let count: String
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
        items.append(.init(peer: .init(sort.peer._asPeer()), count: String.prettySized(with: sort.stats.totalCount), viewType: viewType))
    }
    
    
    for item in items {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 42, photoSize: NSMakeSize(30, 30), isLookSavedMessage: true, inset: NSEdgeInsets(), generalType: .context(item.count), viewType: item.viewType, action: {
                
            })
        }))
    }
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    return entries
}

func StorageUsage_Block_Chats(context: AccountContext, stats: AllStorageUsageStats) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(stats: stats)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
