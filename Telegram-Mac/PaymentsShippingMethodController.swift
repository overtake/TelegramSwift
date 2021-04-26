//
//  PaymentsShippingMethodController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import SyncCore

private final class Arguments {
    let context: AccountContext
    let select:(BotPaymentShippingOption)->Void
    init(context: AccountContext, select: @escaping(BotPaymentShippingOption)->Void) {
        self.context = context
        self.select = select
    }
}

private struct State : Equatable {
    var shippingOptions: [BotPaymentShippingOption]
    var form: BotPaymentForm
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    for option in state.shippingOptions {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier(option.title), data: .init(name: option.title, color: theme.colors.text, type: .context(formatCurrencyAmount(option.prices.reduce(0, { $0 + $1.amount }), currency: state.form.invoice.currency)), viewType: bestGeneralViewType(state.shippingOptions, for: option), action: {
            arguments.select(option)
        })))
        index += 1
    }
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PaymentsShippingMethodController(context: AccountContext, shippingOptions: [BotPaymentShippingOption], form: BotPaymentForm, select:@escaping(BotPaymentShippingOption)->Void) -> InputDataModalController {

    var close:(()->Void)? = nil
    
    let actionsDisposable = DisposableSet()

    let initialState = State(shippingOptions: shippingOptions, form: form)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, select: { option in
        close?()
        select(option)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.checkoutShippingMethod)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: L10n.modalCancel, accept: {
        close?()
    }, drawBorder: true, height: 50, singleButton: true)


    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    

    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}





