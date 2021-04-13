//
//  AnimatedWebp.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
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
    var data: Data
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("webp"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return  AnimatedWebpRowItem(initialSize, stableId: stableId, data: state.data)
    }))
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func AnimatedWebpController(context: AccountContext, path: String) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(data: try! Data(contentsOf: URL(fileURLWithPath: path)))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "DONE", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })

    
    return modalController
}


/*

 */



