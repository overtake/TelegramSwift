//
//  PaymentsCheckoutBotCheckoutPaymentMethodController.swift
//  Telegram
//
//  Created by Mike Renoir on 26.07.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    let openNewMethod:(String)->Void
    init(context: AccountContext, openNewMethod:@escaping(String)->Void) {
        self.context = context
        self.openNewMethod = openNewMethod
    }
}

private struct State : Equatable {
    let methods: [BotCheckoutPaymentMethod]
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    for (i, method) in state.methods.enumerated() {
        let viewType = bestGeneralViewType(state.methods, for: i)
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("\(arc4random())"), data: .init(name: method.title, color: theme.colors.text, type: .none, viewType: viewType, action: {
            switch method {
            case let .other(method):
                arguments.openNewMethod(method.url)
            default:
                break
            }
        })))
        index += 1
    }
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PaymentMethodController(context: AccountContext, methods: [BotCheckoutPaymentMethod], newCard: @escaping()->Void, newByUrl:@escaping(String)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
        
    var close:(()->Void)? = nil

    let initialState = State(methods: methods)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, openNewMethod: { url in
        newByUrl(url)
        close?()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().checkoutPaymentMethodTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().checkoutPaymentMethodNew, accept: {
        newCard()
        close?()
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


/*

 */

