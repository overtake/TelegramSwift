//
//  JoinVoiceChatAlertController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11.03.2021.
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
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var title: String
    var peer: PeerEquatable
    var participantsCount: Int
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: InputDataEquatable(state), item: { initialSize, stableId in
        return JoinVoiceChatAlertRowItem(initialSize, stableId: stableId, account: arguments.context.account, peer: state.peer.peer, title: state.title, participantsCount: state.participantsCount)
    }))
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func JoinVoiceChatAlertController(context: AccountContext, groupCall: GroupCallPanelData, peer: Peer, join: @escaping()->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    var close:(()->Void)? = nil
    
    let initialState = State(title: groupCall.info?.title ?? peer.displayTitle, peer: PeerEquatable(peer), participantsCount: groupCall.participantCount)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.chatVoiceChatJoinLinkTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        join()
        close?()
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: L10n.chatVoiceChatJoinLinkOK, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(250, 250))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


