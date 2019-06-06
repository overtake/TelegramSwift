//
//  ForgotPasswordController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac


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
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.code), error: state.error, identifier: _id_input_code, mode: .plain, placeholder: nil, inputPlaceholder: L10n.twoStepAuthRecoveryCode, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: 6))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: GeneralRowTextType.markdown(L10n.twoStepAuthRecoveryCodeHelp + "\n\n" + L10n.twoStepAuthRecoveryEmailUnavailableNew(pattern), linkHandler: { _ in
        unavailable()
    }), color: theme.colors.grayText, detectBold: false))
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    return entries
}

func ForgotUnauthorizedPasswordController(accountManager: AccountManager, account: UnauthorizedAccount, emailPattern: String) -> InputDataModalController {
    
    
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
                
                if code.length == 6 {
                    disposable.set(showModalProgress(signal: performPasswordRecovery(accountManager: accountManager, account: account, code: code, syncContacts: false) |> deliverOnMainQueue, for: mainWindow).start(next: {
                        
                        updateState { state in
                            return state.withUpdatedChecking(false)
                        }
                        
                        close?()
                        
                    }, error: { error in
                        
                        updateState { state in
                            return state.withUpdatedChecking(false)
                        }
                        
                        let text: String
                        switch error {
                        case .invalidCode:
                            text = L10n.twoStepAuthEmailCodeInvalid
                        case .expired:
                            text = L10n.twoStepAuthEmailCodeExpired
                        case .limitExceeded:
                            text = L10n.loginFloodWait
                        }
                        
                        updateState { current in
                            return current.withUpdatedError(InputDataValueError(description: text, target: .data))
                        }
                        
                        f(.fail(.fields([_id_input_code : .shake])))
                    }))
                } else {
                    updateState { current in
                        return current.withUpdatedError(InputDataValueError(description: L10n.twoStepAuthEmailCodeInvalid, target: .data))
                    }
                    
                    f(.fail(.fields([_id_input_code : .shake])))
                }
                
                
            }

        })
    }
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: forgotPasswordEntries(state: state, pattern: emailPattern, unavailable: {
             alert(for: mainWindow, info: L10n.twoStepAuthRecoveryFailed)
        }))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.twoStepAuthRecoveryTitle, validateData: { data in
        
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
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.modalSend, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
        }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 50)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}
