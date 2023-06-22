//
//  TextInputController.swift
//  Telegram
//
//  Created by Mike Renoir on 28.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

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
    var text: String
    var placeholder: String
    var limit: Int32
}

private let _id_text = InputDataIdentifier("_id_text")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.text), error: nil, identifier: _id_text, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: state.placeholder, filter: { $0 }, limit: state.limit))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func TextInputController(context: AccountContext, title: String, placeholder: String, initialText: String = "", okTitle: String = strings().modalOK,  limit: Int32 = 255, callback:@escaping(String)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    let initialState = State(text: initialText, placeholder: placeholder, limit: limit)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: title)
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.text = data[_id_text]?.stringValue ?? ""
            return current
        }
        return .none
    }
    
    controller.validateData = { _ in
        callback(stateValue.with { $0.text })
        close?()
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: okTitle, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}




