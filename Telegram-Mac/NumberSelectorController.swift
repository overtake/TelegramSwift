//
//  NumberSelectorController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

private struct NumberValueState : Equatable {
    var value: Int?
}

private let _id_input = InputDataIdentifier("_id_input")

private func entries(_ state: NumberValueState, placeholder: String) -> [InputDataEntry] {
    
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    //4 294 967 295
    let formatter = Formatter.withSeparator
    
    let formatted: String
    if let value = state.value {
        formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    } else {
        formatted = ""
    }
    entries.append(.input(sectionId: sectionId, index: index, value: .string(formatted), error: nil, identifier: _id_input, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: placeholder, filter: { value in
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890, .").inverted)
    }, limit: 5))
    index += 1
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func NumberSelectorController(base: Int?, title: String, placeholder: String, okTitle: String, updated: @escaping(Int?)->Void) -> InputDataModalController {
    
    let initialState = NumberValueState(value: base)
    let statePromise = ValuePromise(initialState, ignoreRepeated: false)
    let stateValue = Atomic(value: initialState)
    let updateState: ((NumberValueState) -> NumberValueState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let disposable = MetaDisposable()
    
    var close: (() -> Void)? = nil
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, placeholder: placeholder))
    }
    
    let controller = InputDataController(dataSignal: signal, title: title, validateData: { data in
        return .none
    }, updateDatas: { data in
        updateState { current in
            var current = current
            if let value = data[_id_input]?.stringValue {
                let value = value
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: ".", with: "")
                if let intValue = Int(value) {
                    current.value = intValue
                } else {
                    current.value = nil
                }
            } else {
                current.value = nil
            }
            return current
        }
        return .none
    }, afterDisappear: {
        disposable.dispose()
    }, hasDone: true)
    
    controller.validateData = { data in
        updated(stateValue.with { $0.value })
        close?()
        return .none
    }
    
    controller.getBackgroundColor = {
        theme.colors.listBackground
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
