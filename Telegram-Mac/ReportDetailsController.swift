//
//  ReportDetailsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
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
    var value: ReportReasonValue
}

private let _id_input = InputDataIdentifier("_id_input")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("sticker"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimtedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: .police, text: .initialize(string: strings().reportAdditionText, color: theme.colors.text, font: .normal(.text)))
    }))
    index += 1
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.value.comment), error: nil, identifier: _id_input, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().reportAdditionTextPlaceholder, filter: { $0 }, limit: 128))
    index += 1


    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ReportDetailsController(context: AccountContext, reason: ReportReasonValue, updated: @escaping(ReportReasonValue)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    var close:(()->Void)? = nil
    
    let initialState = State(value: reason)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().reportAdditionTextButton)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.value = .init(reason: current.value.reason, comment: data[_id_input]?.stringValue ?? "")
            return current
        }
        return .none
    }
    
    controller.validateData = { _ in
        close?()
        return .none
    }
    
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().reportAdditionTextButton, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
        updated(stateValue.with { $0.value })
    }
    
    return modalController
    
}

