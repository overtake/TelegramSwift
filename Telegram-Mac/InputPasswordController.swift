//
//  InputPasswordController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import TGUIKit

enum InputPasswordValueError {
    case generic
    case wrong
}
enum InputPasswordValueResult {
    case close
    case nothing
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
    
    entries.append(.sectionId(sectionId, type: .custom(20)))
    sectionId += 1
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: state.value, error: state.error, identifier: _id_input_pwd, mode: .secure, placeholder: nil, inputPlaceholder: L10n.inputPasswordControllerPlaceholder, filter: { $0 }, limit: 255))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(desc), color: theme.colors.grayText, detectBold: false))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func InputPasswordController(context: AccountContext, title: String, desc: String, checker:@escaping(String)->Signal<InputPasswordValueResult, InputPasswordValueError>) -> InputDataModalController {

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
                checkPassword.set(showModalProgress(signal: checker(pwd), for: context.window).start(next: { value in
                    updateState {
                        return $0.withUpdatedLoading(false)
                    }
                    switch value {
                    case .close:
                        dismiss?()
                    case .nothing:
                        break
                    }
                }, error: { error in
                    let text: String
                    switch error {
                    case .wrong:
                        text = L10n.inputPasswordControllerErrorWrongPassword
                    case .generic:
                        text = L10n.unknownError
                    }
                    updateState {
                        return $0.withUpdatedLoading(false).withUpdatedError(InputDataValueError(description: text, target: .data))
                    }
                    f(.fail(.fields([_id_input_pwd : .shake])))
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
    
    let interactions = ModalInteractions(acceptTitle: L10n.navigationDone, accept: { [weak controller] in
        
        controller?.validateInputValues()
        
    }, cancelTitle: L10n.modalCancel, height: 50)
    
    let modalController = InputDataModalController(controller, modalInteractions: interactions, size: NSMakeSize(300, 300))
    
    dismiss = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
