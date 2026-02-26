//
//  DeclineSuggestPostModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16.06.2025.
//  Copyright © 2025 Telegram. All rights reserved.
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
    var comment: String = ""
}

private let _id_input = InputDataIdentifier("_id_input")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    entries.append(.input(
        sectionId: sectionId,
        index: index,
        value: .string(state.comment),
        error: nil,
        identifier: _id_input,
        mode: .plain,
        data: .init(viewType: .singleItem),
        placeholder: nil,
        inputPlaceholder: strings().declineSuggestPostPlaceholderComment,
        filter: { $0 },
        limit: 255
    ))
    
    entries.append(.desc(
        sectionId: sectionId,
        index: index,
        text: .plain(strings().declineSuggestPostDescription),
        data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)
    ))
    index += 1
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func DeclineSuggestPostModalController(context: AccountContext, callback:@escaping(String)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    var close:(()->Void)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    let controller = InputDataController(dataSignal: signal, title: strings().declineSuggestPostTitle)

    getController = { [weak controller] in
        return controller
    }
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.comment = data[_id_input]?.stringValue ?? ""
            return current
        }
        return .none
    }
    
    controller.validateData = { _ in
        callback(stateValue.with { $0.comment })
        close?()
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(
        acceptTitle: strings().declineSuggestPostActionReject,
        accept: { [weak controller] in
            _ = controller?.returnKeyAction()
        },
        singleButton: true
    )

    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}





