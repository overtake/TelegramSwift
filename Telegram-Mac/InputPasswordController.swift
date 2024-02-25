//
//  InputPasswordController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TelegramCore

import TGUIKit

enum InputPasswordValueError {
    case generic
    case wrong
    case custom(String)
}


private struct InputPasswordState : Equatable {
    let error: InputDataValueError?
    let value: InputDataValue
    let isLoading: Bool
    init(value: InputDataValue, error: InputDataValueError?, isLoading: Bool) {
        self.value = value
        self.error = error
        self.isLoading = isLoading
    }
    
    func withUpdatedError(_ error: InputDataValueError?) -> InputPasswordState {
        return InputPasswordState(value: self.value, error: error, isLoading: self.isLoading)
    }
    func withUpdatedValue(_ value: InputDataValue) -> InputPasswordState {
        return InputPasswordState(value: value, error: self.error, isLoading: self.isLoading)
    }
    func withUpdatedLoading(_ isLoading: Bool) -> InputPasswordState {
        return InputPasswordState(value: self.value, error: self.error, isLoading: isLoading)
    }
}

private let _id_input_pwd:InputDataIdentifier = InputDataIdentifier("_id_input_pwd")

private func inputPasswordEntries(state: InputPasswordState, desc:String) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: state.value, error: state.error, identifier: _id_input_pwd, mode: .secure, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().inputPasswordControllerPlaceholder, filter: { $0 }, limit: 255))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(desc), data: InputDataGeneralTextData(detectBold: false, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

func InputPasswordController(context: AccountContext, title: String, desc: String, checker:@escaping(String)->Signal<Never, InputPasswordValueError>) -> InputDataModalController {

    let initialState: InputPasswordState = InputPasswordState(value: .string(nil), error: nil, isLoading: false)
    let stateValue: Atomic<InputPasswordState> = Atomic(value: initialState)
    let statePromise:ValuePromise<InputPasswordState> = ValuePromise(initialState, ignoreRepeated: true)
    
    let updateState:(_ f:(InputPasswordState)->InputPasswordState) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    let dataSignal = statePromise.get() |> map { state in
        return inputPasswordEntries(state: state, desc: desc)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    let checkPassword = MetaDisposable()
    
    var dismiss:(()->Void)?
    
    let controller = InputDataController(dataSignal: dataSignal, title: title, validateData: { data in
        return .fail(.doSomething { f in
            if let pwd = data[_id_input_pwd]?.stringValue, !stateValue.with({$0.isLoading}) {
                updateState {
                    return $0.withUpdatedLoading(true)
                }
                checkPassword.set(showModalProgress(signal: checker(pwd), for: context.window).start(error: { error in
                    let text: String
                    switch error {
                    case .wrong:
                        text = strings().inputPasswordControllerErrorWrongPassword
                    case let .custom(value):
                        text = value
                    case .generic:
                        text = strings().unknownError
                    }
                    updateState {
                        return $0.withUpdatedLoading(false).withUpdatedError(InputDataValueError(description: text, target: .data))
                    }
                    f(.fail(.fields([_id_input_pwd : .shake])))
                }, completed: {
                    updateState {
                        return $0.withUpdatedLoading(false)
                    }
                    dismiss?()
                }))
            }
        })
    }, updateDatas: { data in
        updateState {
            return $0.withUpdatedValue(data[_id_input_pwd]!).withUpdatedError(nil)
        }
        return .fail(.none)
    }, afterDisappear: {
        checkPassword.dispose()
    }, hasDone: true)
    
    controller.autoInputAction = true
    
    let interactions = ModalInteractions(acceptTitle: strings().navigationDone, accept: { [weak controller] in
        
        controller?.validateInputValues()
        
    }, singleButton: true)
    
    
    let modalController = InputDataModalController(controller, modalInteractions: interactions, size: NSMakeSize(300, 300))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    dismiss = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
