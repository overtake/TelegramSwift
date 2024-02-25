//
//  ForgotPasswordController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

import Postbox


private let _id_input_code = InputDataIdentifier("_id_input_code")

private struct ForgotPasswordState : Equatable {
    let code: String
    let error: InputDataValueError?
    let checking: Bool
    init(code: String, error: InputDataValueError?, checking: Bool) {
        self.code = code
        self.error = error
        self.checking = checking
    }
    func withUpdatedCode(_ code: String) -> ForgotPasswordState {
        return ForgotPasswordState(code: code, error: self.error, checking: self.checking)
    }
    func withUpdatedError(_ error: InputDataValueError?) -> ForgotPasswordState {
        return ForgotPasswordState(code: self.code, error: error, checking: self.checking)
    }
    func withUpdatedChecking(_ checking: Bool) -> ForgotPasswordState {
        return ForgotPasswordState(code: self.code, error: self.error, checking: checking)
    }
}

private func forgotPasswordEntries(state: ForgotPasswordState, pattern: String, unavailable: @escaping()->Void) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.code), error: state.error, identifier: _id_input_code, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().twoStepAuthRecoveryCode, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: 6))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: GeneralRowTextType.markdown(strings().twoStepAuthRecoveryCodeHelp + "\n\n" + strings().twoStepAuthRecoveryEmailUnavailableNew(pattern), linkHandler: { _ in
        unavailable()
    }), data: InputDataGeneralTextData(color: theme.colors.listGrayText, detectBold: false, viewType: .textBottomItem)))
    
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

func ForgotUnauthorizedPasswordController(accountManager: AccountManager<TelegramAccountManagerTypes>, engine: TelegramEngineUnauthorized?, emailPattern: String) -> InputDataModalController {
    
    
    let initialState = ForgotPasswordState(code: "", error: nil, checking: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ForgotPasswordState) -> ForgotPasswordState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    
    let disposable = MetaDisposable()
    
    var close: (() -> Void)? = nil
    
    let checkCode: (String) -> InputDataValidation = { code in
        return .fail(.doSomething { f in
            let checking: Bool = stateValue.with { $0.checking }
            if !checking {
                updateState { state in
                    return state.withUpdatedChecking(true)
                }
                
                if code.length == 6, let engine = engine {
                    disposable.set(showModalProgress(signal: engine.auth.performPasswordRecovery(code: code, updatedPassword: .none) |> deliverOnMainQueue, for: mainWindow).start(next: { data in
                        
                        let auth = loginWithRecoveredAccountData(accountManager: accountManager, account: engine.account, recoveredAccountData: data, syncContacts: true) |> deliverOnMainQueue
                        
                        disposable.set(auth.start(completed: {
                            updateState { state in
                                return state.withUpdatedChecking(false)
                            }
                            close?()
                        }))
                        
                    }, error: { error in
                        
                        updateState { state in
                            return state.withUpdatedChecking(false)
                        }
                        
                        let text: String
                        switch error {
                        case .invalidCode:
                            text = strings().twoStepAuthEmailCodeInvalid
                        case .expired:
                            text = strings().twoStepAuthEmailCodeExpired
                        case .generic:
                            text = strings().unknownError
                        case .limitExceeded:
                            text = strings().loginFloodWait
                        }
                        
                        updateState { current in
                            return current.withUpdatedError(InputDataValueError(description: text, target: .data))
                        }
                        
                        f(.fail(.fields([_id_input_code : .shake])))
                    }))
                } else {
                    updateState { current in
                        return current.withUpdatedError(InputDataValueError(description: strings().twoStepAuthEmailCodeInvalid, target: .data))
                    }
                    
                    f(.fail(.fields([_id_input_code : .shake])))
                }
                
                
            }

        })
    }
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: forgotPasswordEntries(state: state, pattern: emailPattern, unavailable: {
             alert(for: mainWindow, info: strings().twoStepAuthRecoveryFailed)
        }))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().twoStepAuthRecoveryTitle, validateData: { data in
        
        return checkCode(stateValue.with { $0.code })
    }, updateDatas: { data in
        updateState { current in
            return current.withUpdatedCode(data[_id_input_code]?.stringValue ?? current.code).withUpdatedError(nil)
        }
        let code = stateValue.with { $0.code }
        if code.length == 6 {
            return checkCode(code)
        }
        return .none
    }, afterDisappear: {
        disposable.dispose()
    }, updateDoneValue: { data in
        return { f in
            let checking = stateValue.with { $0.checking }
            f(checking ? .loading : .invisible)
        }
    }, hasDone: true)
    
//    controller.getBackgroundColor = {
//        theme.colors.background
//    }
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().modalSend, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}
