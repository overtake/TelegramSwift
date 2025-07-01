//
//  AddTonBalanceController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27.06.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import CurrencyFormat
private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var tonAmount: Int64
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        let attr = NSMutableAttributedString()
        let formattedAmount = formatCurrencyAmount(state.tonAmount, currency: TON).prettyCurrencyNumberUsd
        attr.append(string: strings().fragmentTonAddFundsHeaderAmount(formattedAmount), color: theme.colors.text, font: .medium(18))
        attr.append(string: "\n\n")
        attr.append(string: strings().fragmentTonAddFundsHeaderInfo, color: theme.colors.text, font: .normal(.text))
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.diamond, text: attr, bgColor: theme.colors.listBackground)
    }))
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func AddTonBalanceController(context: AccountContext, tonAmount: Int64) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(tonAmount: tonAmount)
    
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
    
    let controller = InputDataController(dataSignal: signal, title: strings().fragmentTonAddFundsTitle)

    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        close?()
        execute(inapp: .external(link: strings().fragmentTonAddFundsLink, false))
        return .none
    }

    let modalInteractions = ModalInteractions(
        acceptTitle: strings().fragmentTonAddFundsAction,
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
        modalController?.close()
    }
    
    return modalController
    
}

