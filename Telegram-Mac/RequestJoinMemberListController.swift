//
//  RequestJoinMemberListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let add:(PeerId)->Void
    let dismiss:(PeerId)->Void
    init(context: AccountContext, add:@escaping(PeerId)->Void, dismiss:@escaping(PeerId)->Void) {
        self.context = context
        self.add = add
        self.dismiss = dismiss
    }
}

struct PeerRequestChatJoinData : Equatable {
    let peer: PeerEquatable
    let about: String
    let timeInterval: TimeInterval
    let added: Bool
    let adding: Bool
    let dismissing: Bool
    let dismissed: Bool
}

private struct State : Equatable {
    var peer: PeerEquatable?
    var participants:[RenderedChannelParticipant]?
    var adding:Set<PeerId> = Set()
    var added:Set<PeerId> = Set()
    var dismissing:Set<PeerId> = Set()
    var dismissed:Set<PeerId> = Set()
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if let peer = state.peer?.peer {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            let text:String = "Some addition links are set up to accept requests to join the channel"
            return AnimtedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.invitations, text: .initialize(string: text, color: theme.colors.listGrayText, font: .normal(.text)))
        }))
        index += 1
        
       
        
        
        if let participants = state.participants {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("\(participants.count) REQUESTED TO JOIN"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            
            for (i, peer) in participants.enumerated() {
                let data: PeerRequestChatJoinData = .init(peer: PeerEquatable(peer.peer), about: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua", timeInterval: Date().timeIntervalSince1970, added: state.added.contains(peer.peer.id), adding: state.adding.contains(peer.peer.id), dismissing: state.dismissing.contains(peer.peer.id), dismissed: state.dismissed.contains(peer.peer.id))
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("peer_id_\(peer.peer.id)"), equatable: .init(data), comparable: nil, item: { initialSize, stableId in
                    return PeerRequestJoinRowItem(initialSize, stableId: stableId, context: arguments.context, data: data, add: arguments.add, dismiss: arguments.dismiss, viewType: bestGeneralViewType(participants, for: i))
                }))
                index += 1
            }
        }
        
    }
    
   
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func RequestJoinMemberListController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, add: { peerId in
        updateState { current in
            var current = current
            current.adding.insert(peerId)
            return current
        }
        delay(2.0, closure: {
            updateState { current in
                var current = current
                current.adding.remove(peerId)
                current.added.insert(peerId)
                return current
            }
        })
    }, dismiss: { peerId in
        updateState { current in
            var current = current
            current.dismissing.insert(peerId)
            return current
        }
        delay(2.0, closure: {
            updateState { current in
                var current = current
                current.dismissing.remove(peerId)
                current.dismissed.insert(peerId)
                return current
            }
        })
    })
    
    let peerSignal = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    
    
    _ = context.peerChannelMemberCategoriesContextsManager.recent(peerId: peerId, updated: { state in
        updateState { current in
            var current = current
            current.participants = state.list
            return current
        }
    })
    
    actionsDisposable.add(peerSignal.start(next: { peer in
        updateState { current in
            var current = current
            if let peer = peer?._asPeer() {
                current.peer = .init(peer)
            } else {
                current.peer = nil
            }
            return current
        }
    }))

    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Members Requests")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
