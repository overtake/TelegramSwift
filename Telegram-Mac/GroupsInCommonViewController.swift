//
//  GroupsInCommonViewController.swift
//  Telegram
//
//  Created by keepcoder on 03/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

final class GroupsInCommonArguments {
    let context: AccountContext
    let open:(PeerId)->Void
    init(context: AccountContext, open: @escaping(PeerId) -> Void) {
        self.open = open
        self.context = context
    }
}


private func _id_peer_id(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_id_\(id)")
}

private func commonGroupsEntries(state: GroupsInCommonState, arguments: GroupsInCommonArguments) -> [InputDataEntry] {
    
    
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    let peers = state.peers.compactMap { $0.chatMainPeer }
    
    struct Tuple : Equatable {
        let peer: PeerEquatable
        let viewType: GeneralViewType
    }
    for (i, peer) in peers.enumerated() {
        var viewType: GeneralViewType = bestGeneralViewType(peers, for: i)
        if i == 0 {
            if peers.count == 1 {
                viewType = .lastItem
            } else {
                viewType = .innerItem
            }
        }
        let tuple = Tuple(peer: .init(peer), viewType: viewType)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer_id(peer.id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 46, photoSize: NSMakeSize(32, 32), inset: NSEdgeInsetsZero, viewType: tuple.viewType, action: {
                arguments.open(tuple.peer.peer.id)
            })
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
    
}

func GroupsInCommonViewController(context: AccountContext, peerId: PeerId) -> ViewController {
    

    let actionsDisposable = DisposableSet()
    
    let arguments = GroupsInCommonArguments(context: context, open: { peerId in
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId)))
    })
    
    let contextValue: Promise<GroupsInCommonContext> = Promise()
    let peerId = getPeerView(peerId: peerId, postbox: context.account.postbox) |> take(1) |> map { peer in
        return peer?.id ?? peerId
    }
    contextValue.set(peerId |> map {
        GroupsInCommonContext(account: context.account, peerId: $0)
    })
    let state = contextValue.get() |> mapToSignal {
        $0.state
    }
    let dataSignal = state |> map {
        return InputDataSignalValue(entries: commonGroupsEntries(state: $0, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: dataSignal, title: "")
    controller.bar = .init(height: 0)
    
    controller.contextObject = contextValue
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.getBackgroundColor = {
        theme.colors.listBackground
    }
    
    controller.didLoad = { controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                _ = contextValue.get().start(next: { ctx in
                    ctx.loadMore()
                })
                //commonContext.loadMore()
            default:
                break
            }
        }
    }
    
    return controller
}
