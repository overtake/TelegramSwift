//
//  PamentsSelectMethodController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.03.2021.
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
    let select:(BotPaymentSavedCredentials)->Void
    let addNew:()->Void
    let addPaymentMethod:(String)->Void
    init(context: AccountContext, select: @escaping(BotPaymentSavedCredentials)->Void, addNew:@escaping()->Void, addPaymentMethod:@escaping(String)->Void) {
        self.context = context
        self.select = select
        self.addNew = addNew
        self.addPaymentMethod = addPaymentMethod
    }
}

private struct State : Equatable {
    var cards:[BotPaymentSavedCredentials]
    var form: BotPaymentForm
    var methods: [BotCheckoutPaymentMethod]
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
                arguments.addPaymentMethod(method.url)
            case let .savedCredentials(credeitials):
                arguments.select(credeitials)
            default:
                break
            }
        })))
        index += 1
    }
    
    if !state.methods.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("add_new"), data: .init(name: strings().checkoutPaymentMethodNew, color: theme.colors.accent, type: .context(""), viewType: .singleItem, action: {
        arguments.addNew()
    })))
    index += 1
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PamentsSelectMethodController(context: AccountContext, cards:[BotPaymentSavedCredentials], form: BotPaymentForm, methods: [BotCheckoutPaymentMethod], select:@escaping(BotPaymentSavedCredentials)->Void, addNew: @escaping()->Void, addPaymentMethod:@escaping(String, BotPaymentForm)->Void) -> InputDataModalController {

    var close:(()->Void)? = nil
    
    let actionsDisposable = DisposableSet()

    let initialState = State(cards: cards, form: form, methods: methods)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, select: { option in
        close?()
        select(option)
    }, addNew: {
        close?()
        addNew()
    }, addPaymentMethod: { url in
        addPaymentMethod(url, form)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().checkoutPaymentMethodTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalCancel, accept: {
        close?()
    }, drawBorder: true, height: 50, singleButton: true)


    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    

    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}





