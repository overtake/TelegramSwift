//
//  FactCheckController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var string: NSAttributedString?
}

private let _id_input = InputDataIdentifier("_id_input")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .attributedString(state.string), error: nil, identifier: _id_input, mode: .plain, data: .init(viewType: .singleItem, canMakeTransformations: true), placeholder: nil, inputPlaceholder: strings().factCheckPlaceholder, filter: { $0 }, limit: 1024))
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func FactCheckController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    var close:(()->Void)? = nil
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().factCheckTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.string = data[_id_input]?.attributedString
            return current
        }
        return .none
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


/*

 */



