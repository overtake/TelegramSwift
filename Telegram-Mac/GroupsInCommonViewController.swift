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
import SyncCore
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
    
    for (i, peer) in peers.enumerated() {
        var viewType: GeneralViewType = bestGeneralViewType(peers, for: i)
        if i == 0 {
            if peers.count == 1 {
                viewType = .lastItem
            } else {
                viewType = .innerItem
            }
        }
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer_id(peer.id), equatable: InputDataEquatable(PeerEquatable(peer)), item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, height: 46, photoSize: NSMakeSize(32, 32), inset: NSEdgeInsetsZero, viewType: viewType, action: {
                arguments.open(peer.id)
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
        context.sharedContext.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId)))
    })
    
    let commonContext = GroupsInCommonContext(account: context.account, peerId: peerId)

    let dataSignal = commonContext.state |> map {
        return InputDataSignalValue(entries: commonGroupsEntries(state: $0, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: dataSignal, title: "")
    controller.bar = .init(height: 0)
    
    controller.contextOject = commonContext
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.getBackgroundColor = {
        theme.colors.listBackground
    }
    
    controller.didLoaded = { controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                commonContext.loadMore()
            default:
                break
            }
        }
    }
    
    return controller
}
