//
//  Star_AppExamples.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit


private final class Arguments {
    let context: AccountContext
    let launchApp:(EnginePeer)->Void
    init(context: AccountContext, launchApp:@escaping(EnginePeer)->Void) {
        self.context = context
        self.launchApp = launchApp
    }
}

private struct State : Equatable {
    var recent: [EnginePeer] = []
    var recommended: [EnginePeer] = []
}

private func _id_peer(_ peer: EnginePeer) -> InputDataIdentifier {
    return .init("_id_peer_\(peer.id.toInt64())")
}

private let _id_separator = InputDataIdentifier("_id_separator")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_separator, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return SeparatorRowItem(initialSize, stableId, string: "APPS THAT ACCEPT STARS")
    }))
    
    for recommend in state.recommended {
        
        let string: String
        if let subscriberCount = (recommend._asPeer() as? TelegramUser)?.subscriberCount {
            string = strings().peerStatusUsersCountable(Int(subscriberCount)).replacingOccurrences(of: "\(subscriberCount)", with: subscriberCount.formattedWithSeparator)
        } else {
            string = strings().presenceBot
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(recommend), equatable: .init(recommend), comparable: nil, item: { initialSize, stableId in
            return RecentPeerRowItem(initialSize, peer: recommend._asPeer(), account: arguments.context.account, context: arguments.context, stableId: stableId, statusStyle:ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status: string, action: {
                arguments.launchApp(recommend)
            })
        }))
    }
  
    
    return entries
}

func Star_AppExamples(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    let recommendedList:(Signal<[EnginePeer.Id]?, NoError>) -> Signal<[EnginePeer], NoError> = { signal in
        return signal |> mapToSignal { appIds in
            if let appIds {
                return context.engine.data.subscribe(
                    EngineDataMap(
                        appIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                            return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                        }
                    )) |> map  { peers in
                        var result: [EnginePeer] = []
                        for id in appIds {
                            if let peer = peers[id] as? EnginePeer  {
                                result.append(peer)
                            }
                        }
                        return Array(result)
                    }
            } else {
                return .single([])
            }
        }
    }
    
    let recommendedApps: Signal<[EnginePeer], NoError> = recommendedList(context.engine.peers.recommendedAppPeerIds())
    let recentUsedApps: Signal<[EnginePeer], NoError> = recommendedList(context.engine.peers.recentApps() |> map(Optional.init))
    
    
    actionsDisposable.add(combineLatest(recommendedApps, recentUsedApps).start(next: { (recommendedApps, recentUsedApps) in
        updateState { current in
            var current = current
            current.recent = recentUsedApps
            current.recommended = recommendedApps
            return current
        }
    }))
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, launchApp: { peer in
        BrowserStateContext.get(context).open(tab: .mainapp(bot: peer, source: .generic))
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().exampleAppsTitle)
    
    
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller)
    
    modalController.alwaysActiveHeader = true
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    return modalController
    
}



