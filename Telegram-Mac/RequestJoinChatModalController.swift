//
//  RequestJoinGroupModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
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
    let flags: ExternalJoiningChatState.Invite.Flags
    let title: String
    let about: String?
    let photoRepresentation: TelegramMediaImageRepresentation?
    let participantsCount: Int32
    let isChannelOrMegagroup: Bool
    
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    // entries
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("value"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        return RequestJoinChatRowItem(initialSize, stableId: stableId, context: arguments.context, photo: state.photoRepresentation, title: state.title, about: state.about, participantsCount: Int(state.participantsCount), isChannelOrMegagroup: state.isChannelOrMegagroup, viewType: .singleItem)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("about"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: state.flags.isChannel ? strings().requestJoinDescChannel : strings().requestJoinDescGroup, font: .normal(.text), color: theme.colors.grayText)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func RequestJoinChatModalController(context: AccountContext, joinhash: String, invite: ExternalJoiningChatState, interaction:@escaping(PeerId?)->Void) -> InputDataModalController {


    switch invite {
    case let .invite(state):
        let actionsDisposable = DisposableSet()

        let initialState = State(flags: state.flags, title: state.title, about: state.about, photoRepresentation: state.photoRepresentation, participantsCount: state.participantsCount, isChannelOrMegagroup: state.flags.isChannel && state.flags.isBroadcast)
        
        var close:(()->Void)? = nil
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }

        let arguments = Arguments(context: context)
        
        
        
        let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
            return InputDataSignalValue(entries: entries(state, arguments: arguments))
        }
        
        let controller = InputDataController(dataSignal: signal, title: state.title)
        
        controller.onDeinit = {
            actionsDisposable.dispose()
        }

        let modalInteractions = ModalInteractions(acceptTitle: strings().requestJoinButton, accept: { [weak controller] in
            _ = controller?.returnKeyAction()
        }, drawBorder: true, height: 50, singleButton: true)
        
        let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
        
        controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
            modalController?.close()
        })
        
        close = { [weak modalController] in
            modalController?.modal?.close()
        }
        
        controller.afterTransaction = { controller in
            
        }
        
        controller.returnKeyInvocation = { _, _ in
            close?()
            _ = showModalProgress(signal: context.engine.peers.joinChatInteractively(with: joinhash), for: context.window).start(next: { peerId in
                interaction(peerId)
            }, error: { error in
                let text: String
                switch error {
                case .generic:
                    text = strings().unknownError
                case .tooMuchJoined:
                    showInactiveChannels(context: context, source: .join)
                    return
                case .tooMuchUsers:
                    text = strings().groupUsersTooMuchError
                case .requestSent:
                    let navigation = context.bindings.rootNavigation()
                    navigation.controller.show(toaster: .init(text: strings().requestJoinSent))
                    return
                case .flood:
                    text = strings().joinLinkFloodError
                }
                alert(for: context.window, info: text)
            })
            return .default
        }
        
        return modalController
    default:
        fatalError("I thought it's impossible.")
    }
    
}
