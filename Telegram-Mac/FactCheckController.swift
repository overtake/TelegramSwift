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
import TelegramCore
import Postbox
import InputView

private final class Arguments {
    let context: AccountContext
    let updateState:(Updated_ChatTextInputState)->Void
    init(context: AccountContext, updateState: @escaping (Updated_ChatTextInputState) -> Void) {
        self.context = context
        self.updateState = updateState
    }
}

private struct State : Equatable {
    var textState:Updated_ChatTextInputState = .init(inputText: .init())
}

private let _id_input = InputDataIdentifier("_id_input")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    let length = arguments.context.appConfiguration.getGeneralValue("factcheck_length_limit", orElse: 1024)
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input, equatable: .init(state.textState), comparable: nil, item: { initialSize, stableId in
        return InputTextDataRowItem(initialSize, stableId: stableId, context: arguments.context, state: state.textState, viewType: .singleItem, placeholder: nil, inputPlaceholder: strings().factCheckPlaceholder, canMakeTransformations: true, filter: { text in
            return text
        }, updateState: arguments.updateState, limit: length, hasEmoji: false, allowedLinkHosts: ["t.me"])
    }))
    index += 1
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func FactCheckController(context: AccountContext, message: Message) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let inputState: Updated_ChatTextInputState
    if let factCheck = message.factCheckAttribute {
        switch factCheck.content {
        case let .Loaded(text, entities, country):
            inputState = ChatTextInputState(inputText: text, selectionRange: text.length ..< text.length, attributes: chatTextAttributes(from: TextEntitiesMessageAttribute(entities: entities), associatedMedia: message.associatedMedia)).textInputState()
        default:
            inputState = .init()
        }
    } else {
        inputState = .init()
    }
    
    let initialState = State(textState: inputState)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, updateState: { state in
        updateState { current in
            var current = current
            current.textState = state
            return current
        }
    })
    
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
    
    controller.validateData = { _ in
        let isEnabled = stateValue.with { $0.textState != inputState }
        
        if isEnabled {
            let state = stateValue.with { $0.textState.textInputState() }
            if state.inputText.isEmpty {
                _ = context.engine.messages.deleteMessageFactCheck(messageId: message.id).startStandalone()
                showModalText(for: context.window, text: strings().factCheckSaveDelete)
            } else {
                _ = context.engine.messages.editMessageFactCheck(messageId: message.id, text: state.inputText, entities: state.messageTextEntities()).startStandalone()
                showModalText(for: context.window, text: strings().factCheckSaveUpdated)
            }
            close?()
        } else {
            return .fail(.fields([_id_input: .shake]))
        }
        
        
        return .none
    }

    controller.afterTransaction = { [weak modalInteractions] controller in
        modalInteractions?.updateDone { button in
            button.isEnabled = stateValue.with { $0.textState != inputState }
            let isRemoved = stateValue.with { $0.textState.inputText.string.isEmpty } && !inputState.inputText.string.isEmpty
            
            if isRemoved {
                button.set(background: theme.colors.redUI, for: .Normal)
                button.set(text: strings().modalRemove, for: .Normal)
            } else {
                button.set(background: theme.colors.accent, for: .Normal)
                button.set(text: strings().modalDone, for: .Normal)
            }
        }
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}



