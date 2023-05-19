//
//  PasscodeControllers.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import BuildConfig
import SwiftSignalKit


enum PasscodeMode : Equatable {
    case install
    case change
    case disable
}

private struct PasscodeState : Equatable {
    let mode: PasscodeMode
    let data: [InputDataIdentifier : InputDataValue]
    let errors: [InputDataIdentifier : InputDataValueError]
    init(mode: PasscodeMode, data: [InputDataIdentifier : InputDataValue], errors: [InputDataIdentifier : InputDataValueError]) {
        self.mode = mode
        self.data = data
        self.errors = errors
    }
    
    func withUpdatedError(_ error: InputDataValueError?, for key: InputDataIdentifier) -> PasscodeState {
        var errors = self.errors
        if let error = error {
            errors[key] = error
        } else {
            errors.removeValue(forKey: key)
        }
        return PasscodeState(mode: self.mode, data: self.data, errors: errors)
    }
    
    func withUpdatedValue(_ value: InputDataValue, for key: InputDataIdentifier) -> PasscodeState {
        var data = self.data
        data[key] = value
        return PasscodeState(mode: self.mode, data: data, errors: self.errors)
    }
}

private let _id_input_new_passcode = InputDataIdentifier("_id_input_new_passcode")
private let _id_input_re_new_passcode = InputDataIdentifier("_id_input_re_new_passcode")

private let _id_input_current = InputDataIdentifier("_id_input_current")

private func passcodeEntries(_ state: PasscodeState) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    switch state.mode {
    case .install:

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().passcodeControllerHeaderNew), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.data[_id_input_new_passcode]?.stringValue), error: state.errors[_id_input_new_passcode], identifier: _id_input_new_passcode, mode: .secure, data: InputDataRowData(viewType: .firstItem), placeholder: nil, inputPlaceholder: strings().passcodeControllerEnterPasscodePlaceholder, filter: { $0 }, limit: 255))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.data[_id_input_re_new_passcode]?.stringValue), error: state.errors[_id_input_re_new_passcode], identifier: _id_input_re_new_passcode, mode: .secure, data: InputDataRowData(viewType: .lastItem), placeholder: nil, inputPlaceholder: strings().passcodeControllerReEnterPasscodePlaceholder, filter: { $0 }, limit: 255))
        index += 1
        
        
    case .change:
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().passcodeControllerHeaderCurrent), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.data[_id_input_current]?.stringValue), error: state.errors[_id_input_current], identifier: _id_input_current, mode: .secure, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().passcodeControllerCurrentPlaceholder, filter: { $0 }, limit: 255))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().passcodeControllerHeaderNew), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.data[_id_input_new_passcode]?.stringValue), error: state.errors[_id_input_new_passcode], identifier: _id_input_new_passcode, mode: .secure, data: InputDataRowData(viewType: .firstItem), placeholder: nil, inputPlaceholder: strings().passcodeControllerEnterPasscodePlaceholder, filter: { $0 }, limit: 255))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.data[_id_input_re_new_passcode]?.stringValue), error: state.errors[_id_input_re_new_passcode], identifier: _id_input_re_new_passcode, mode: .secure, data: InputDataRowData(viewType: .lastItem), placeholder: nil, inputPlaceholder: strings().passcodeControllerReEnterPasscodePlaceholder, filter: { $0 }, limit: 255))
        index += 1
        
        
        
    case .disable:
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().passcodeControllerHeaderCurrent), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.data[_id_input_current]?.stringValue), error: state.errors[_id_input_current], identifier: _id_input_current, mode: .secure, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().passcodeControllerCurrentPlaceholder, filter: { $0 }, limit: 255))
        index += 1
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().passcodeControllerText), data: InputDataGeneralTextData(detectBold: false, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PasscodeController(sharedContext: SharedAccountContext, mode: PasscodeMode) -> ViewController {
    
    
    let initialState = PasscodeState(mode: mode, data: [:], errors: [:])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: false)
    let stateValue = Atomic(value: initialState)
    let updateState: ((PasscodeState) -> PasscodeState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let dataSignal = statePromise.get() |> map {
        return passcodeEntries($0)
    }
    
    let title: String
    switch mode {
    case .install:
        title = strings().passcodeControllerInstallTitle
    case .change:
        title = strings().passcodeControllerChangeTitle
    case .disable:
        title = strings().passcodeControllerDisableTitle
    }
    
    var shouldMakeNextResponderAfterTransition: InputDataIdentifier? = nil

    let actionsDisposable = DisposableSet()
    
    return InputDataController(dataSignal: dataSignal |> map { InputDataSignalValue(entries: $0) }, title: title, validateData: { data in
        
        
        return .fail(.doSomething { f in
            let state = stateValue.with { $0 }
            
            switch state.mode {
            case .install:
                let passcode = state.data[_id_input_new_passcode]?.stringValue ?? ""
                let confirm = state.data[_id_input_re_new_passcode]?.stringValue ?? ""
                
                var fields:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                
                if !passcode.isEmpty, !confirm.isEmpty, passcode != confirm {
                    fields[_id_input_new_passcode] = .shake
                    fields[_id_input_re_new_passcode] = .shake
                    
                    updateState {
                        $0.withUpdatedError(InputDataValueError(description: strings().passcodeControllerErrorDifferent, target: .data), for: _id_input_re_new_passcode)
                    }
                }
                if passcode.isEmpty {
                    fields[_id_input_new_passcode] = .shake
                    shouldMakeNextResponderAfterTransition = _id_input_new_passcode
                }
                if confirm.isEmpty {
                    fields[_id_input_re_new_passcode] = .shake
                    if shouldMakeNextResponderAfterTransition == nil {
                        shouldMakeNextResponderAfterTransition = _id_input_re_new_passcode
                    }
                }
                if !fields.isEmpty {
                    f(.fail(.fields(fields)))
                } else {
                    actionsDisposable.add((sharedContext.accountManager.transaction { transaction in
                        transaction.setAccessChallengeData(.plaintextPassword(value: ""))
                    } |> deliverOnMainQueue).start(completed: {
                        sharedContext.appEncryptionValue.change(passcode)
                        f(.success(.navigationBackWithPushAnimation))
                    }))
                }
                
            case .change:
                let current = state.data[_id_input_current]?.stringValue ?? ""
            
                let appEncryption = AppEncryptionParameters(path: sharedContext.accountManager.basePath.nsstring.deletingLastPathComponent)
                appEncryption.applyPasscode(current)
                
                let passcode = state.data[_id_input_new_passcode]?.stringValue ?? ""
                let confirm = state.data[_id_input_re_new_passcode]?.stringValue ?? ""
                
                var fields:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                
                 if appEncryption.decrypt() == nil {
                    fields[_id_input_current] = .shake
                    if shouldMakeNextResponderAfterTransition == nil {
                        shouldMakeNextResponderAfterTransition = _id_input_current
                    }
                    updateState {
                        $0.withUpdatedError(InputDataValueError(description: strings().passcodeControllerErrorCurrent, target: .data), for: _id_input_current)
                    }
                    f(.fail(.fields(fields)))
                    return
                }
                
                if !passcode.isEmpty, !confirm.isEmpty, passcode != confirm {
                    fields[_id_input_new_passcode] = .shake
                    fields[_id_input_re_new_passcode] = .shake
                    
                    updateState {
                        $0.withUpdatedError(InputDataValueError(description: strings().passcodeControllerErrorDifferent, target: .data), for: _id_input_re_new_passcode)
                    }
                }
                if passcode.isEmpty {
                    fields[_id_input_new_passcode] = .shake
                    if shouldMakeNextResponderAfterTransition == nil {
                        shouldMakeNextResponderAfterTransition = _id_input_new_passcode
                    }
                }
                if confirm.isEmpty {
                    fields[_id_input_re_new_passcode] = .shake
                    if shouldMakeNextResponderAfterTransition == nil {
                        shouldMakeNextResponderAfterTransition = _id_input_re_new_passcode
                    }
                }
                if !fields.isEmpty {
                    f(.fail(.fields(fields)))
                } else {
                    
                    
                    actionsDisposable.add((sharedContext.accountManager.transaction { transaction in
                        transaction.setAccessChallengeData(.plaintextPassword(value: ""))
                    } |> deliverOnMainQueue).start(completed: {
                        sharedContext.appEncryptionValue.change(passcode)
                        f(.success(.navigationBackWithPushAnimation))
                    }))
                }
            case .disable:
                let current = state.data[_id_input_current]?.stringValue ?? ""
                
                let appEncryption = AppEncryptionParameters(path: sharedContext.accountManager.basePath.nsstring.deletingLastPathComponent)
                appEncryption.applyPasscode(current)
                
                if appEncryption.decrypt() == nil {
                    updateState {
                        $0.withUpdatedError(InputDataValueError(description: strings().passcodeControllerErrorCurrent, target: .data), for: _id_input_current)
                    }
                    f(.fail(.fields([_id_input_current : .shake])))
                    
                } else {
                    actionsDisposable.add((sharedContext.accountManager.transaction { transaction in
                        transaction.setAccessChallengeData(.none)
                    } |> deliverOnMainQueue).start(completed: {
                        sharedContext.appEncryptionValue.remove()
                        f(.success(.navigationBackWithPushAnimation))
                    }))
                }
                
            }
            
            updateState {
                $0
            }
        })
    }, updateDatas: { data in
        updateState { state in
            var state = state
            if let value = data[_id_input_new_passcode] {
                state = state.withUpdatedValue(value, for: _id_input_new_passcode).withUpdatedError(nil, for: _id_input_new_passcode)
            }
            if let value = data[_id_input_re_new_passcode] {
                state = state.withUpdatedValue(value, for: _id_input_re_new_passcode).withUpdatedError(nil, for: _id_input_re_new_passcode)
            }
            if let value = data[_id_input_current] {
                state = state.withUpdatedValue(value, for: _id_input_current).withUpdatedError(nil, for: _id_input_current)
            }
            return state
        }
       
        
        return .none
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, afterTransaction: { controller in
        if let identifier = shouldMakeNextResponderAfterTransition {
            controller.makeFirstResponderIfPossible(for: identifier)
        }
        shouldMakeNextResponderAfterTransition = nil
    })
    
}
