//
//  CancelResetAccountController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa


import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac

private let _id_input_code = InputDataIdentifier("_id_input_code")

private struct CancelResetAccountState : Equatable {
    let code: String
    let error: InputDataValueError?
    let checking: Bool
    let limit: Int32
    init(code: String, error: InputDataValueError?, checking: Bool, limit: Int32) {
        self.code = code
        self.error = error
        self.checking = checking
        self.limit = limit
    }
    func withUpdatedCode(_ code: String) -> CancelResetAccountState {
        return CancelResetAccountState(code: code, error: self.error, checking: self.checking, limit: self.limit)
    }
    func withUpdatedError(_ error: InputDataValueError?) -> CancelResetAccountState {
        return CancelResetAccountState(code: self.code, error: error, checking: self.checking, limit: self.limit)
    }
    func withUpdatedChecking(_ checking: Bool) -> CancelResetAccountState {
        return CancelResetAccountState(code: self.code, error: self.error, checking: checking, limit: self.limit)
    }
    func withUpdatedCodeLimit(_ limit: Int32) -> CancelResetAccountState {
        return CancelResetAccountState(code: self.code, error: self.error, checking: self.checking, limit: limit)
    }
}



 
 
func authorizationNextOptionText(currentType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?) -> (current: String, next: String, codeLength: Int) {
    
    var codeLength: Int = 255
    var basic: String = ""
    var nextText: String = ""
    
    switch currentType {
    case let .otherSession(length: length):
        codeLength = Int(length)
        basic = L10n.loginEnterCodeFromApp
        nextText = L10n.loginSendSmsIfNotReceivedAppCode
    case let .sms(length: length):
        codeLength = Int(length)
        basic = L10n.loginJustSentSms
    case let .call(length: length):
        codeLength = Int(length)
        basic = L10n.loginPhoneCalledCode
    default:
        break
    }
    
    
    if let nextType = nextType {
        if let timeout = timeout {
            let timeout = Int(timeout)
            let minutes = timeout / 60;
            let sec = timeout % 60;
            let secValue = sec > 9 ? "\(sec)" : "0\(sec)"
            if timeout > 0 {
                switch nextType {
                case .call:
                    nextText = L10n.loginWillCall(minutes, secValue)
                    break
                case .sms:
                    nextText = L10n.loginWillSendSms(minutes, secValue)
                    break
                default:
                    break
                }
            } else {
                switch nextType {
                case .call:
                    basic = L10n.loginPhoneCalledCode
                    nextText = L10n.loginPhoneDialed
                    break
                default:
                    break
                }
            }
            
        } else {
            nextText = L10n.loginSendSmsIfNotReceivedAppCode
        }
    }
    
    return (current: basic, next: nextText, codeLength: codeLength)
}


private func timeoutSignal(codeData: CancelAccountResetData) -> Signal<Int32?, NoError> {
    if let _ = codeData.nextType, let timeout = codeData.timeout {
        return Signal { subscriber in
            let value = Atomic<Int32>(value: timeout)
            subscriber.putNext(timeout)
            
            let timer = SwiftSignalKitMac.Timer(timeout: 1.0, repeat: true, completion: {
                subscriber.putNext(value.modify { value in
                    return max(0, value - 1)
                })
            }, queue: Queue.mainQueue())
            timer.start()
            
            return ActionDisposable {
                timer.invalidate()
            }
        }
    } else {
        return .single(nil)
    }
}

private func cancelResetAccountEntries(state: CancelResetAccountState, data: CancelAccountResetData, timeout: Int32?, phone: String) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
//
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.code), error: state.error, identifier: _id_input_code, mode: .plain, data: InputDataRowData(), placeholder: nil, inputPlaceholder: L10n.twoStepAuthRecoveryCode, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: state.limit))
    index += 1
    
    var nextOptionText = ""
    if let nextType = data.nextType {
        nextOptionText += authorizationNextOptionText(currentType: data.type, nextType: nextType, timeout: timeout).next
    }
    
    let phoneNumber = phone.hasPrefix("+") ? phone : "+\(phone)"
    
    let formattedNumber = formatPhoneNumber(phoneNumber)
    var result = L10n.cancelResetAccountTextSMS(formattedNumber)
    
    if !nextOptionText.isEmpty {
        result += "\n\n" + nextOptionText
    }
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(result), data: InputDataGeneralTextData()))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}


func cancelResetAccountController(account: Account, phone: String, data: CancelAccountResetData) -> InputDataModalController {
    
    
    let initialState = CancelResetAccountState(code: "", error: nil, checking: false, limit: 255)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CancelResetAccountState) -> CancelResetAccountState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    let actionsDisposable = DisposableSet()
    
    let updateCodeLimitDisposable = MetaDisposable()
    actionsDisposable.add(updateCodeLimitDisposable)
    
    let confirmPhoneDisposable = MetaDisposable()
    actionsDisposable.add(confirmPhoneDisposable)
    
    let nextTypeDisposable = MetaDisposable()
    actionsDisposable.add(nextTypeDisposable)
    
    let currentDataPromise = Promise<CancelAccountResetData>()
    currentDataPromise.set(.single(data))
    
    let timeout = Promise<Int32?>()
    timeout.set(currentDataPromise.get() |> mapToSignal(timeoutSignal))
    
    
    updateCodeLimitDisposable.set((currentDataPromise.get() |> deliverOnMainQueue).start(next: { data in
        updateState { current in
            var limit:Int32 = 255
            switch data.type {
            case let .call(length):
                limit = length
            case let .otherSession(length):
                limit = length
            case let .sms(length):
                limit = length
            default:
                break
            }
            return current.withUpdatedCodeLimit(limit)
        }
    }))
    
    var close: (() -> Void)? = nil
    
    let checkCode: (String) -> InputDataValidation = { code in
        return .fail(.doSomething { f in
           
            let checking = stateValue.with {$0.checking}
            let code = stateValue.with { $0.code }
            
            updateState { current in
                return current.withUpdatedChecking(true)
            }
            
            if !checking {
                confirmPhoneDisposable.set(showModalProgress(signal: requestCancelAccountReset(network: account.network, phoneCodeHash: data.hash, phoneCode: code) |> deliverOnMainQueue, for: mainWindow).start(error: { error in
                        
                        let errorText: String
                        switch error {
                        case .generic:
                            errorText = L10n.twoStepAuthGenericError
                        case .invalidCode:
                            errorText = L10n.twoStepAuthRecoveryCodeInvalid
                        case .codeExpired:
                            errorText = L10n.twoStepAuthRecoveryCodeExpired
                        case .limitExceeded:
                            errorText = L10n.twoStepAuthFloodError
                        }
                        
                        updateState {
                            return $0.withUpdatedError(InputDataValueError(description: errorText, target: .data)).withUpdatedChecking(false)
                        }
                        
                        f(.fail(.fields([_id_input_code : .shake])))
                        
                    }, completed: {
                        updateState {
                            return $0.withUpdatedChecking(false)
                        }
                        close?()
                        alert(for: mainWindow, info: L10n.cancelResetAccountSuccess(formatPhoneNumber(phone.hasPrefix("+") ? phone : "+\(phone)")))
                    }))
            }
        })
    }
    
   
    
    
    
    let signal = combineLatest(statePromise.get(), currentDataPromise.get(), timeout.get()) |> map { state, data, timeout in
        return InputDataSignalValue(entries: cancelResetAccountEntries(state: state, data: data, timeout: timeout, phone: phone))
    }
    
    let resendCode = currentDataPromise.get()
        |> mapToSignal { [weak currentDataPromise] data -> Signal<Void, NoError> in
            if let _ = data.nextType {
                return timeout.get()
                    |> filter { $0 == 0 }
                    |> take(1)
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return Signal { subscriber in
                            return requestNextCancelAccountResetOption(network: account.network, phoneNumber: phone, phoneCodeHash: data.hash).start(next: { next in
                                currentDataPromise?.set(.single(next))
                            }, error: { error in
                                
                            })
                        }
                }
            } else {
                return .complete()
            }
    }
    nextTypeDisposable.set(resendCode.start())
    
    let controller = InputDataController(dataSignal: signal, title: L10n.cancelResetAccountTitle, validateData: { data in
        
        return checkCode(stateValue.with { $0.code })
    }, updateDatas: { data in
        updateState { current in
            return current.withUpdatedCode(data[_id_input_code]?.stringValue ?? current.code).withUpdatedError(nil)
        }
        
        let codeLimit = stateValue.with { $0.limit }
        let code = stateValue.with { $0.code }
        
        if code.length == codeLimit {
            return checkCode(code)
        }
        return .none
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, updateDoneValue: { data in
        return { f in
            let checking = stateValue.with { $0.checking }
            f(checking ? .loading : .invisible)
        }
    }, hasDone: true)
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.modalSend, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 50)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}
