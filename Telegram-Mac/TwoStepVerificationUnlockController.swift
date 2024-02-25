//
//  TwoStepVerificationUnlockController.swift
//  Telegram
//
//  Created by keepcoder on 16/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

import Postbox




private struct TwoStepVerificationUnlockSettingsControllerState: Equatable {
    let passwordText: String
    let checking: Bool
    let emailCode: String
    let errors:[InputDataIdentifier : InputDataValueError]
    let data: TwoStepVerificationUnlockSettingsControllerData
    
    init(passwordText: String, checking: Bool, emailCode: String, errors: [InputDataIdentifier : InputDataValueError], data: TwoStepVerificationUnlockSettingsControllerData) {
        self.passwordText = passwordText
        self.checking = checking
        self.emailCode = emailCode
        self.errors = errors
        self.data = data
    }
    
    func withUpdatedError(_ error: InputDataValueError?, for key: InputDataIdentifier) -> TwoStepVerificationUnlockSettingsControllerState {
        var errors = self.errors
        if let error = error {
            errors[key] = error
        } else {
            errors.removeValue(forKey: key)
        }
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: self.passwordText, checking: self.checking, emailCode: self.emailCode, errors: errors, data: self.data)
    }
    
    func withUpdatedPasswordText(_ passwordText: String) -> TwoStepVerificationUnlockSettingsControllerState {
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: passwordText, checking: self.checking, emailCode: self.emailCode, errors: self.errors, data: self.data)
    }
    func withUpdatedEmailCode(_ emailCode: String) -> TwoStepVerificationUnlockSettingsControllerState {
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: self.passwordText, checking: self.checking, emailCode: emailCode, errors: self.errors, data: self.data)
    }
    
    func withUpdatedChecking(_ checking: Bool) -> TwoStepVerificationUnlockSettingsControllerState {
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: self.passwordText, checking: checking, emailCode: self.emailCode, errors: self.errors, data: self.data)
    }
    
    func withUpdatedControllerData(_ data: TwoStepVerificationUnlockSettingsControllerData) -> TwoStepVerificationUnlockSettingsControllerState {
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: self.passwordText, checking: self.checking, emailCode: self.emailCode, errors: self.errors, data: data)
    }
}


enum TwoStepVerificationUnlockSettingsControllerMode {
    case access(TwoStepVeriticationAccessConfiguration?)
    case manage(password: String, email: String, pendingEmail: TwoStepVerificationPendingEmail?, hasSecureValues: Bool)
}

private enum TwoStepVerificationUnlockSettingsControllerData : Equatable {
    case access(configuration: TwoStepVeriticationAccessConfiguration?)
    case manage(password: String, emailSet: Bool, pendingEmail: TwoStepVerificationPendingEmail?, hasSecureValues: Bool)
}



struct PendingEmailState : Equatable {
    let password: String?
    let email: TwoStepVerificationPendingEmail
}


private final class TwoStepVerificationPasswordEntryControllerArguments {
    let updateEntryText: (String) -> Void
    let next: () -> Void
    let skipEmail:() ->Void
    init(updateEntryText: @escaping (String) -> Void, next: @escaping () -> Void, skipEmail:@escaping()->Void) {
        self.updateEntryText = updateEntryText
        self.next = next
        self.skipEmail = skipEmail
    }
}



enum PasswordEntryStage: Equatable {
    case entry(text: String)
    case reentry(first: String, text: String)
    case hint(password: String, text: String)
    case email(password: String, hint: String, text: String, change: Bool)
    case code(text: String, codeLength: Int32?, pattern: String)
    
    func updateCurrentText(_ text: String) -> PasswordEntryStage {
        switch self {
        case .entry:
            return .entry(text: text)
        case let .reentry(first, _):
            return .reentry(first: first, text: text)
        case let .hint(password, _):
            return .hint(password: password, text: text)
        case let .email(password, hint, _, change):
            return .email(password: password, hint: hint, text: text, change: change)
        case let .code(_, codeLength, pattern):
            return .code(text: text, codeLength: codeLength, pattern: pattern)
        }
    }
    
}

private struct TwoStepVerificationPasswordEntryControllerState: Equatable {
    let stage: PasswordEntryStage
    let updating: Bool
    let errors: [InputDataIdentifier : InputDataValueError]
    init(stage: PasswordEntryStage, updating: Bool, errors: [InputDataIdentifier : InputDataValueError]) {
        self.stage = stage
        self.updating = updating
        self.errors = errors
    }
    
    func withUpdatedError(_ error: InputDataValueError?, for key: InputDataIdentifier) -> TwoStepVerificationPasswordEntryControllerState {
        var errors = self.errors
        if let error = error {
            errors[key] = error
        } else {
            errors.removeValue(forKey: key)
        }
        return TwoStepVerificationPasswordEntryControllerState(stage: self.stage, updating: self.updating, errors: errors)
    }
    
    func withUpdatedStage(_ stage: PasswordEntryStage) -> TwoStepVerificationPasswordEntryControllerState {
        return TwoStepVerificationPasswordEntryControllerState(stage: stage, updating: self.updating, errors: self.errors)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> TwoStepVerificationPasswordEntryControllerState {
        return TwoStepVerificationPasswordEntryControllerState(stage: self.stage, updating: updating, errors: self.errors)
    }
}


enum TwoStepVerificationPasswordEntryMode {
    case setup
    case change(current: String)
    case setupEmail(password: String, change: Bool)
    case enterCode(codeLength: Int32?, pattern: String)
}


enum TwoStepVeriticationAccessConfiguration : Equatable {
    case notSet(pendingEmail: PendingEmailState?)
    case set(hint: String, hasRecoveryEmail: Bool, hasSecureValues: Bool, pendingResetTimestamp: Int32?)
    
    init(configuration: TwoStepVerificationConfiguration, password: String?) {
        switch configuration {
        case let .notSet(pendingEmail):
            self = .notSet(pendingEmail: pendingEmail.flatMap({ PendingEmailState(password: password, email: $0) }))
        case let .set(hint, hasRecoveryEmail, _, hasSecureValues, pendingResetTimestamp):
            self = .set(hint: hint, hasRecoveryEmail: hasRecoveryEmail, hasSecureValues: hasSecureValues, pendingResetTimestamp: pendingResetTimestamp)
        }
    }
}

enum SetupTwoStepVerificationStateUpdate {
    case noPassword
    case awaitingEmailConfirmation(password: String, pattern: String, codeLength: Int32?)
    case passwordSet(password: String?, hasRecoveryEmail: Bool, hasSecureValues: Bool)
    case emailSet
}




final class TwoStepVerificationResetControllerArguments {
    let updateEntryText: (String) -> Void
    let next: () -> Void
    let openEmailInaccessible: () -> Void
    
    init(updateEntryText: @escaping (String) -> Void, next: @escaping () -> Void, openEmailInaccessible: @escaping () -> Void) {
        self.updateEntryText = updateEntryText
        self.next = next
        self.openEmailInaccessible = openEmailInaccessible
    }
}


struct TwoStepVerificationResetControllerState: Equatable {
    let codeText: String
    let checking: Bool
    
    init(codeText: String, checking: Bool) {
        self.codeText = codeText
        self.checking = checking
    }
    
    
    func withUpdatedCodeText(_ codeText: String) -> TwoStepVerificationResetControllerState {
        return TwoStepVerificationResetControllerState(codeText: codeText, checking: self.checking)
    }
    
    func withUpdatedChecking(_ checking: Bool) -> TwoStepVerificationResetControllerState {
        return TwoStepVerificationResetControllerState(codeText: self.codeText, checking: checking)
    }
}



private let _id_input_enter_pwd = InputDataIdentifier("input_password")
private let _id_change_pwd = InputDataIdentifier("change_pwd")
private let _id_remove_pwd = InputDataIdentifier("remove_pwd")
private let _id_setup_email = InputDataIdentifier("setup_email")
private let _id_enter_email_code = InputDataIdentifier("enter_email_code")
private let _id_set_password = InputDataIdentifier("set_password")
private let _id_input_enter_email_code = InputDataIdentifier("_id_input_enter_email_code")

private func twoStepVerificationUnlockSettingsControllerEntries(state: TwoStepVerificationUnlockSettingsControllerState, context: AccountContext, forgotPassword:@escaping()->Void, cancelReset:@escaping() -> Void, abort:@escaping()-> Void) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId:Int32 = 0
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    var index: Int32 = 0
    
    
    switch state.data {
    case let .access(configuration):
        if let configuration = configuration {
            switch configuration {
            case let .notSet(pendingEmail):
                if let pendingEmail = pendingEmail {
                    
                    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.emailCode), error: state.errors[_id_input_enter_email_code], identifier: _id_input_enter_email_code, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().twoStepAuthRecoveryCode, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: pendingEmail.email.codeLength ?? 255))
                    index += 1
                    
                    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().twoStepAuthConfirmationTextNew + "\n\n\(pendingEmail.email.pattern)\n\n[" + strings().twoStepAuthConfirmationAbort + "]()", linkHandler: { url in
                        abort()
                    }), data: InputDataGeneralTextData(detectBold: false, viewType: .textBottomItem)))
                    index += 1

        
                } else {
                    entries.append(.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_set_password, data: InputDataGeneralData(name: strings().twoStepAuthSetPassword, color: theme.colors.text, icon: nil, type: .none, viewType: .singleItem, action: nil)))
                    index += 1
                    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().twoStepAuthSetPasswordHelp), data: InputDataGeneralTextData(viewType: .textBottomItem)))
                    index += 1
                }
            case let .set(hint, hasRecoveryEmail, _, pendingResetTimestamp):
                entries.append(.input(sectionId: sectionId, index: index, value: .string(state.passwordText), error: state.errors[_id_input_enter_pwd], identifier: _id_input_enter_pwd, mode: .secure, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().twoStepAuthEnterPasswordPassword, filter: { $0 }, limit: 255))
                index += 1
                if let timestamp = pendingResetTimestamp {
                    
                    if timestamp.isFuture {
                        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().twoStepAuthEnterPasswordHelp + "\n\n" + strings().twoStepAuthResetPending(autoremoveLocalized(Int(timestamp - Int32(Date().timeIntervalSince1970)))) + "\n[" + strings().twoStepAuthCancelReset + "](reset)", linkHandler: { link in
                            verifyAlert_button(for: context.window, header: strings().twoStepAuthCancelResetConfirm, information: strings().twoStepAuthCancelResetText, ok: strings().alertYes, cancel: strings().alertNO, successHandler: { _ in
                                cancelReset()
                            })
                        }), data: InputDataGeneralTextData(viewType: .textBottomItem)))
                    } else {
                        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().twoStepAuthEnterPasswordHelp + "\n\n" + "[" + strings().twoStepAuthReset + "](reset)", linkHandler: { link in
                            forgotPassword()
                        }), data: InputDataGeneralTextData(viewType: .textBottomItem)))
                    }
                    index += 1
                    
                } else {
                    
                    let forgot:()->Void = {
                        if !hasRecoveryEmail {
                            verifyAlert_button(for: context.window, header: strings().twoStepAuthErrorHaventEmailResetHeader, information: strings().twoStepAuthErrorHaventEmailNew, ok: strings().twoStepAuthErrorHaventEmailReset, successHandler: { _ in
                                forgotPassword()
                            })
                        } else {
                            forgotPassword()
                        }
                    }
                    
                    if hint.isEmpty {
                        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().twoStepAuthEnterPasswordHelp + "\n\n[" + strings().twoStepAuthEnterPasswordForgot + "](forgot)", linkHandler: { link in
                            forgot()
                        }), data: InputDataGeneralTextData(viewType: .textBottomItem)))
                    } else {
                        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().twoStepAuthEnterPasswordHint(hint) + "\n\n" + strings().twoStepAuthEnterPasswordHelp + "\n\n[" + strings().twoStepAuthEnterPasswordForgot + "](forgot)", linkHandler: { link in
                            forgot()
                        }), data: InputDataGeneralTextData(viewType: .textBottomItem)))
                    }
                    index += 1
                }
               
            }
        } else {
            return [.loading]
        }
    case let .manage(_, emailSet, pendingEmail, _):
        
        entries.append(.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_change_pwd, data: InputDataGeneralData(name: strings().twoStepAuthChangePassword, color: theme.colors.text, icon: nil, type: .none, viewType: .firstItem, action: nil)))
        index += 1
        entries.append(.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_remove_pwd, data: InputDataGeneralData(name: strings().twoStepAuthRemovePassword, color: theme.colors.text, icon: nil, type: .none, viewType: .innerItem, action: nil)))
        index += 1
        entries.append(.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_setup_email, data: InputDataGeneralData(name: emailSet ? strings().twoStepAuthChangeEmail : strings().twoStepAuthSetupEmail, color: theme.colors.text, icon: nil, type: .none, viewType: .lastItem, action: nil)))
        index += 1
        
        
        if let _ = pendingEmail {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_enter_email_code, data: InputDataGeneralData(name: strings().twoStepAuthEnterEmailCode, color: theme.colors.text, icon: nil, type: .none, viewType: .singleItem, action: nil)))
            index += 1
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().twoStepAuthEmailSent), data: InputDataGeneralTextData(viewType: .textBottomItem)))
            index += 1

        } else {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().twoStepAuthGenericHelp), data: InputDataGeneralTextData(viewType: .textBottomItem)))
            index += 1
        }

    }
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    return entries
}




func twoStepVerificationUnlockController(context: AccountContext, mode: TwoStepVerificationUnlockSettingsControllerMode, presentController:@escaping((controller: ViewController, root:Bool, animated: Bool))->Void) -> InputDataController {
    
    let actionsDisposable = DisposableSet()
    
    
    let checkDisposable = MetaDisposable()
    actionsDisposable.add(checkDisposable)
    
    let setupDisposable = MetaDisposable()
    actionsDisposable.add(setupDisposable)
    
    let setupResultDisposable = MetaDisposable()
    actionsDisposable.add(setupResultDisposable)
    
    
    let data: TwoStepVerificationUnlockSettingsControllerData
    
    switch mode {
    case let .access(configuration):
        data = .access(configuration: configuration)
    case let .manage(password, email, pendingEmail, hasSecureValues):
        data = .manage(password: password, emailSet: !email.isEmpty, pendingEmail: pendingEmail, hasSecureValues: hasSecureValues)
    }
    //
    let initialState = TwoStepVerificationUnlockSettingsControllerState(passwordText: "", checking: false, emailCode: "", errors: [:], data: data)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((TwoStepVerificationUnlockSettingsControllerState) -> TwoStepVerificationUnlockSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    switch mode {
    case .access:
        actionsDisposable.add((context.engine.auth.twoStepVerificationConfiguration() |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVeriticationAccessConfiguration(configuration: $0, password: nil)) } |> deliverOnMainQueue).start(next: { data in
            updateState {
                $0.withUpdatedControllerData(data)
            }
        }))
    default:
        break
    }
    
    

    let disablePassword: () -> InputDataValidation = {
        return .fail(.doSomething { f in
            
            switch data {
            case .access:
                break
            case let .manage(password, _, _, hasSecureValues):
                
                var text: String = strings().twoStepAuthConfirmDisablePassword
                if hasSecureValues {
                    text += "\n\n"
                    text += strings().secureIdWarningDataLost
                }
                
                verifyAlert_button(for: context.window, information: text, successHandler: { result in
                    var disablePassword = false
                    updateState { state in
                        if state.checking {
                            return state
                        } else {
                            disablePassword = true
                            return state.withUpdatedChecking(true)
                        }
                    }
                    context.hasPassportSettings.set(.single(false))
                    
                    if disablePassword {
                        let resetPassword = context.engine.auth.updateTwoStepVerificationPassword(currentPassword: password, updatedPassword: .none) |> deliverOnMainQueue
                        
                        setupDisposable.set(resetPassword.start(next: { value in
                            updateState {
                                $0.withUpdatedChecking(false)
                            }
                            context.resetTemporaryPwd()
                            presentController((controller: twoStepVerificationUnlockController(context: context, mode: .access(.notSet(pendingEmail: nil)), presentController: presentController), root: true, animated: true))
                            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
                        }, error: { error in
                            alert(for: context.window, info: strings().unknownError)
                        }))
                    }
                })
            }
        })
    }
    
    let checkEmailConfirmation: () -> InputDataValidation = {
        
        return .fail(.doSomething { f in
            let data: TwoStepVerificationUnlockSettingsControllerData = stateValue.with { $0.data }
            
            var pendingEmailData: PendingEmailState?
            switch data {
            case let .access(configuration):
                guard let configuration = configuration else {
                    return
                }
                switch configuration {
                case let .notSet(pendingEmail):
                    pendingEmailData = pendingEmail
                case .set:
                    break
                }
            case let .manage(password, _, pendingEmail, _):
                if let pendingEmail = pendingEmail {
                    pendingEmailData = PendingEmailState(password: password, email: pendingEmail)
                }
            }
            if let pendingEmail = pendingEmailData {
                var code: String?
                updateState { state in
                    if !state.checking {
                        code = state.emailCode
                        return state.withUpdatedChecking(true)
                    }
                    return state
                }
                if let code = code {
                    setupDisposable.set((context.engine.auth.confirmTwoStepRecoveryEmail(code: code)
                        |> deliverOnMainQueue).start(error: { error in
                            updateState { state in
                                return state.withUpdatedChecking(false)
                            }
                            let text: String
                            switch error {
                            case .invalidEmail:
                                text = strings().twoStepAuthEmailInvalid
                            case .invalidCode:
                                text = strings().twoStepAuthEmailCodeInvalid
                            case .expired:
                                text = strings().twoStepAuthEmailCodeExpired
                            case .flood:
                                text = strings().twoStepAuthFloodError
                            case .generic:
                                text = strings().unknownError
                            }
                            updateState {
                                $0.withUpdatedError(InputDataValueError(description: text, target: .data), for: _id_input_enter_email_code)
                            }
                            f(.fail(.fields([_id_input_enter_email_code:.shake])))
                        }, completed: {
                            switch data {
                            case .access:
                                if let password = pendingEmail.password {
                                    presentController((controller: twoStepVerificationUnlockController(context: context, mode: .manage(password: password, email: "", pendingEmail: nil, hasSecureValues: false), presentController: presentController), root: true, animated: true))
                                } else {
                                    presentController((controller: twoStepVerificationUnlockController(context: context, mode: .access(.set(hint: "", hasRecoveryEmail: true, hasSecureValues: false, pendingResetTimestamp: nil)), presentController: presentController), root: true, animated: true))
                                }
                            case let .manage(manage):
                                presentController((controller: twoStepVerificationUnlockController(context: context, mode: .manage(password: manage.password, email: "", pendingEmail: nil, hasSecureValues: manage.hasSecureValues), presentController: presentController), root: true, animated: true))
                            }
                            
                            updateState { state in
                                return state.withUpdatedChecking(false).withUpdatedEmailCode("")
                            }
                        }))
                }
            }
            
        })
    }
    
    
    
    let validateAccessPassword:([InputDataIdentifier : InputDataValue]) -> InputDataValidation = { data in
        var wasChecking: Bool = false
        updateState { state in
            wasChecking = state.checking
            return state
        }
        
        updateState { state in
            return state.withUpdatedChecking(!wasChecking)
        }
        
        if !wasChecking, let password = data[_id_input_enter_pwd]?.stringValue {
            
            return .fail(.doSomething(next: { f in
                
                checkDisposable.set((context.engine.auth.requestTwoStepVerifiationSettings(password: password)
                    |> mapToSignal { settings -> Signal<(TwoStepVerificationSettings, TwoStepVerificationPendingEmail?), AuthorizationPasswordVerificationError> in
                        return context.engine.auth.twoStepVerificationConfiguration()
                    |> castError(AuthorizationPasswordVerificationError.self)
                            |> map { configuration in
                                var pendingEmail: TwoStepVerificationPendingEmail?
                                if case let .set(configuration) = configuration {
                                    pendingEmail = configuration.pendingEmail
                                }
                                return (settings, pendingEmail)
                        }
                    }
                    |> deliverOnMainQueue).start(next: { settings, pendingEmail in
                        updateState {
                            $0.withUpdatedChecking(false)
                        }
                        presentController((controller: twoStepVerificationUnlockController(context: context, mode: .manage(password: password, email: settings.email, pendingEmail: pendingEmail, hasSecureValues: settings.secureSecret != nil), presentController: presentController), root: true, animated: true))
                        f(.none)
                    }, error: { error in
                        let text: String
                        switch error {
                        case .limitExceeded:
                            text = strings().twoStepAuthErrorLimitExceeded
                        case .invalidPassword:
                            text = strings().twoStepAuthInvalidPasswordError
                        case .generic:
                            text = strings().twoStepAuthErrorGeneric
                        }
                        updateState {
                            $0.withUpdatedChecking(false).withUpdatedError(InputDataValueError(description: text, target: .data), for: _id_input_enter_pwd)
                        }
                        
                        f(.fail(.fields([_id_input_enter_pwd : .shake])))
                        
                    }))
                
            }))
            
            
        } else {
            checkDisposable.set(nil)
        }

        return .none
    }
    
    let proccessEntryResult:(SetupTwoStepVerificationStateUpdate) -> Void = { update in
        switch update {
        case .noPassword:
            presentController((controller: twoStepVerificationUnlockController(context: context, mode: .access(.notSet(pendingEmail: nil)), presentController: presentController), root: true, animated: true))
        case let .awaitingEmailConfirmation(password, pattern, codeLength):
            
            let data = stateValue.with {$0.data}
            
            let hasSecureValues: Bool
            
            switch data {
            case let .manage(_, _, _, _hasSecureValues):
                hasSecureValues = _hasSecureValues
            case .access:
                hasSecureValues = false
            }
            
            
            
            let pendingEmail = TwoStepVerificationPendingEmail(pattern: pattern, codeLength: codeLength)

            let root = twoStepVerificationUnlockController(context: context, mode: .manage(password: password, email: "", pendingEmail: pendingEmail, hasSecureValues: hasSecureValues), presentController: presentController)
            
            presentController((controller: root, root: true, animated: false))
            
            presentController((controller: twoStepVerificationPasswordEntryController(context: context, mode: .enterCode(codeLength: pendingEmail.codeLength, pattern: pendingEmail.pattern), initialStage: nil, result: { _ in
                presentController((controller: twoStepVerificationUnlockController(context: context, mode: .manage(password: password, email: "email", pendingEmail: nil, hasSecureValues: hasSecureValues), presentController: presentController), root: true, animated: true))
                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
            }, presentController: presentController), root: false, animated: true))
            
            
        case .emailSet:
            let data = stateValue.with {$0.data}
            
            switch data {
            case let .manage(password, _, _, hasSecureValues):
                presentController((controller: twoStepVerificationUnlockController(context: context, mode: .manage(password: password, email: "email", pendingEmail: nil, hasSecureValues: hasSecureValues), presentController: presentController), root: true, animated: true))
                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
            default:
                break
            }
        case let .passwordSet(password, hasRecoveryEmail, hasSecureValues):
            if let password = password {
                presentController((controller: twoStepVerificationUnlockController(context: context, mode: .manage(password: password, email: hasRecoveryEmail ? "email" : "", pendingEmail: nil, hasSecureValues: hasSecureValues), presentController: presentController), root: true, animated: true))
                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
            } else {
                presentController((controller: twoStepVerificationUnlockController(context: context, mode: .access(.set(hint: "", hasRecoveryEmail: hasRecoveryEmail, hasSecureValues: hasSecureValues, pendingResetTimestamp: nil)), presentController: presentController), root: true, animated: true))
            }
        }
    }
    
    let setupPassword:() -> InputDataValidation = {
        let controller = twoStepVerificationPasswordEntryController(context: context, mode: .setup, initialStage: nil, result: proccessEntryResult, presentController: presentController)
        presentController((controller: controller, root: false, animated: true))
        return .none
    }
    
    let changePassword: (_ current: String) -> InputDataValidation = { current in
        let controller = twoStepVerificationPasswordEntryController(context: context, mode: .change(current: current), initialStage: nil, result: proccessEntryResult, presentController: presentController)
        presentController((controller: controller, root: false, animated: true))
        return .none
    }
    
    let setupRecoveryEmail:() -> InputDataValidation = {
        
        let data = stateValue.with {$0.data}
        
        switch data {
        case .access:
            break
        case let .manage(password, emailSet, _, _):
            let controller = twoStepVerificationPasswordEntryController(context: context, mode: .setupEmail(password: password, change: emailSet), initialStage: nil, result: proccessEntryResult, presentController: presentController)
            presentController((controller: controller, root: false, animated: true))
        }
        
        return .none
    }
    
    let enterCode:() -> InputDataValidation = {
        let data = stateValue.with {$0.data}
        
        switch data {
        case .access:
            break
        case let .manage(_, _, pendingEmail, _):
            if let pendingEmail = pendingEmail {
                let controller = twoStepVerificationPasswordEntryController(context: context, mode: .enterCode(codeLength: pendingEmail.codeLength, pattern: pendingEmail.pattern), initialStage: nil, result: proccessEntryResult, presentController: presentController)
                presentController((controller: controller, root: false, animated: true))
            }
        }
        
        return .none
    }
    
    let cancelReset: () -> Void = {
        let _ = (context.engine.auth.declineTwoStepPasswordReset()
            |> deliverOnMainQueue).start(completed: {
                
                _ = showModalProgress(signal: context.engine.auth.twoStepVerificationConfiguration(), for: context.window).start(next: { configuration in
                    updateState {
                        $0.withUpdatedControllerData(.access(configuration: .init(configuration: configuration, password: nil)))
                    }
                })

        })
    }
    

    let forgotPassword:() -> Void = {
        
        let data = stateValue.with {$0.data}
        switch data {
        case let .access(configuration):
            if let configuration = configuration {
                switch configuration {
                case let .set(hint, hasRecoveryEmail, hasSecureValues, _):
                    if hasRecoveryEmail {
                        updateState { state in
                            return state.withUpdatedChecking(true)
                        }
                        
                        setupResultDisposable.set((context.engine.auth.requestTwoStepVerificationPasswordRecoveryCode()
                            |> deliverOnMainQueue).start(next: { emailPattern in
                                
                                updateState { state in
                                    return state.withUpdatedChecking(false)
                                }
                                
                                presentController((controller: twoStepVerificationResetPasswordController(context: context, emailPattern: emailPattern, success: {
                                    presentController((controller: twoStepVerificationUnlockController(context: context, mode: .access(.notSet(pendingEmail: nil)), presentController: presentController), root: true, animated: true))
                                }), root: false, animated: true))
                              
                            }, error: { _ in
                                updateState { state in
                                    return state.withUpdatedChecking(false)
                                }
                                alert(for: context.window, info: strings().twoStepAuthAnError)
                            }))
                    } else {
                        
                        let reset:()->Void = {
                            _ = showModalProgress(signal: context.engine.auth.requestTwoStepPasswordReset(), for: context.window).start(next: { result in
                                switch result {
                                case .done:
                                    updateState {
                                        $0.withUpdatedControllerData(.access(configuration: .notSet(pendingEmail: nil)))
                                    }
                                    verifyAlert_button(for: context.window, header: strings().twoStepAuthResetSuccessHeader, information: strings().twoStepAuthResetSuccess, ok: strings().alertYes, cancel: strings().alertNO, successHandler: { _ in
                                        let controller = twoStepVerificationPasswordEntryController(context: context, mode: .setup, initialStage: nil, result: proccessEntryResult, presentController: presentController)
                                        presentController((controller: controller, root: true, animated: true))
                                    })
                                case let .error(reason):
                                    switch reason {
                                    case let .limitExceeded(retryin):
                                        if let retryin = retryin {
                                            let formatter = DateFormatter()
                                            formatter.dateStyle = .medium
                                            formatter.timeStyle = .medium
                                            formatter.timeZone = NSTimeZone.local
                                            alert(for: context.window, info: strings().twoStepAuthUnableToReset(formatter.string(from: Date.init(timeIntervalSince1970: TimeInterval(retryin)))))
                                        } else {
                                            alert(for: context.window, info: strings().errorAnError)
                                        }
                                    default:
                                        alert(for: context.window, info: strings().errorAnError)
                                    }
                                case .declined:
                                    break
                                case let .waitingForReset(resetAtTimestamp):
                                    updateState {
                                        $0.withUpdatedControllerData(.access(configuration: .set(hint: hint, hasRecoveryEmail: hasRecoveryEmail, hasSecureValues: hasSecureValues, pendingResetTimestamp: resetAtTimestamp)))
                                    }
                                }
                            })
                        }
                        
                        reset()
                        
                    }
                    
                default:
                    break
                }
                
            }
        case .manage:
            break
        }
        
    }
    
    let abort: () -> Void = {
        updateState { $0.withUpdatedChecking(true) }
        let resetPassword = context.engine.auth.updateTwoStepVerificationPassword(currentPassword: nil, updatedPassword: .none) |> deliverOnMainQueue
        
        setupDisposable.set(resetPassword.start(next: { value in
            updateState { $0.withUpdatedChecking(false) }
            presentController((controller: twoStepVerificationUnlockController(context: context, mode: .access(.notSet(pendingEmail: nil)), presentController: presentController), root: true, animated: true))
        }, error: { error in
            alert(for: context.window, info: strings().unknownError)
        }))
    }
    
    let _repeat:Signal<Void, NoError> = (.single(Void()) |> then(.single(Void()) |> suspendAwareDelay(1, queue: Queue.concurrentDefaultQueue()))) |> restart

    
    let signal: Signal<[InputDataEntry], NoError> = combineLatest(statePromise.get(), _repeat) |> map { state, _ -> [InputDataEntry] in
        return twoStepVerificationUnlockSettingsControllerEntries(state: state, context: context, forgotPassword: forgotPassword, cancelReset: cancelReset, abort: abort)
    }
    
    
    return InputDataController(dataSignal: signal |> map { InputDataSignalValue(entries: $0) }, title: strings().privacySettingsTwoStepVerification, validateData: { validateData -> InputDataValidation in
        
        let data = stateValue.with {$0.data}
        let loading = stateValue.with {$0.checking}
        
        if !loading {
            switch mode {
            case .access:
                switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        switch configuration {
                        case let .notSet(pendingEmail):
                            if let _ = pendingEmail {
                                return checkEmailConfirmation()
                            } else {
                                return setupPassword()
                            }
                        case .set:
                            return validateAccessPassword(validateData)
                        }
                    }
                case .manage:
                    break
                }
            case let .manage(password, _, _, _):
                if let _ = validateData[_id_remove_pwd] {
                    return disablePassword()
                } else if let _ = validateData[_id_change_pwd] {
                    return changePassword(password)
                } else if let _ = validateData[_id_setup_email] {
                    return setupRecoveryEmail()
                } else if let _ = validateData[_id_enter_email_code] {
                    return enterCode()
                }
                
            }
        } else {
            NSSound.beep()
        }
        
        return .none
        
    }, updateDatas: { data in
        if let password = data[_id_input_enter_pwd]?.stringValue {
            updateState { state in
                return state.withUpdatedPasswordText(password).withUpdatedError(nil, for: _id_input_enter_pwd)
            }
        } else if let code = data[_id_input_enter_email_code]?.stringValue {
            updateState { state in
                return state.withUpdatedEmailCode(code).withUpdatedError(nil, for: _id_input_enter_email_code)
            }
        }
        return .none
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, updateDoneValue: { data in
        return { f in
            
            let data = stateValue.with {$0.data}
            
            switch mode {
            case .access:
                switch data {
                case let .access(configuration: configuration):
                    if let configuration = configuration {
                        switch configuration {
                        case let .notSet(pendingEmail):
                            if let _ = pendingEmail {
                                var checking: Bool = false
                                var codeEmpty: Bool = true
                                updateState { state in
                                    checking = state.checking
                                    codeEmpty = state.emailCode.isEmpty
                                    return state
                                }
                            return f(checking ? .loading : codeEmpty ? .disabled(strings().navigationDone) : .enabled(strings().navigationDone))
                            } else {
                                
                            }
                        case .set:
                            var checking: Bool = false
                            var pwdEmpty: Bool = true
                            updateState { state in
                                checking = state.checking
                                pwdEmpty = state.passwordText.isEmpty
                                return state
                            }
                            return f(checking ? .loading : pwdEmpty ? .disabled(strings().navigationDone) : .enabled(strings().navigationDone))
                        }
                    } else {
                        return f(.invisible)
                    }
                case .manage:
                    break
                }
            
            default:
                break
            }
            
            var checking: Bool = false
            updateState { state in
                checking = state.checking
                return state
            }
            return f(checking ? .loading : .invisible)
            
        }
    }, removeAfterDisappear: false, hasDone: true, identifier: "tsv-unlock")
}





private struct TwoStepVerificationResetState : Equatable {
    let code: String
    let checking: Bool
    let emailPattern: String
    let errors: [InputDataIdentifier : InputDataValueError]
    init(emailPattern: String, code: String, checking: Bool, errors: [InputDataIdentifier : InputDataValueError] = [:]) {
        self.code = code
        self.checking = checking
        self.emailPattern = emailPattern
        self.errors = errors
    }
    
    func withUpdatedCode(_ code: String) -> TwoStepVerificationResetState {
        return TwoStepVerificationResetState(emailPattern: self.emailPattern, code: code, checking: self.checking, errors: self.errors)
    }
    func withUpdatedChecking(_ checking: Bool) -> TwoStepVerificationResetState {
        return TwoStepVerificationResetState(emailPattern: self.emailPattern, code: self.code, checking: checking, errors: self.errors)
    }
    func withUpdatedError(_ error: InputDataValueError?, for key: InputDataIdentifier) -> TwoStepVerificationResetState {
        var errors = self.errors
        if let error = error {
            errors[key] = error
        } else {
            errors.removeValue(forKey: key)
        }
        return TwoStepVerificationResetState(emailPattern: self.emailPattern, code: self.code, checking: checking, errors: errors)
    }
}

private let _id_input_recovery_code = InputDataIdentifier("_id_input_recovery_code")

private func twoStepVerificationResetPasswordEntries( state: TwoStepVerificationResetState, unavailable: @escaping()-> Void) -> [InputDataEntry] {
    
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.code), error: state.errors[_id_input_recovery_code], identifier: _id_input_recovery_code, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().twoStepAuthRecoveryCode, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: 255))
    index += 1
    
    let info = strings().twoStepAuthRecoveryCodeHelp + "\n\n\(strings().twoStepAuthRecoveryEmailUnavailableNew(state.emailPattern))"

    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(info, linkHandler: { _ in
        unavailable()
    }), data: InputDataGeneralTextData(detectBold: false, viewType: .textBottomItem)))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}



private func twoStepVerificationResetPasswordController(context: AccountContext, emailPattern: String, success: @escaping()->Void) -> InputDataController {
    

    
    let initialState = TwoStepVerificationResetState(emailPattern: emailPattern, code: "", checking: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((TwoStepVerificationResetState) -> TwoStepVerificationResetState) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    let resetDisposable = MetaDisposable()
    
    let signal: Signal<[InputDataEntry], NoError> = statePromise.get() |> map { state in
        return twoStepVerificationResetPasswordEntries(state: state, unavailable: {
             alert(for: context.window, info: strings().twoStepAuthRecoveryFailed)
        })
    }
    
    let checkRecoveryCode: (String) -> InputDataValidation = { code in
        return .fail(.doSomething { f in
            
            updateState {
                return $0.withUpdatedChecking(true)
            }
            
            resetDisposable.set((context.engine.auth.performPasswordRecovery(code: code, updatedPassword: .none) |> deliverOnMainQueue).start(error: { error in
                
                let errorText: String
                switch error {
                case .generic:
                    errorText = strings().twoStepAuthGenericError
                case .invalidCode:
                    errorText = strings().twoStepAuthRecoveryCodeInvalid
                case .expired:
                    errorText = strings().twoStepAuthRecoveryCodeExpired
                case .limitExceeded:
                    errorText = strings().twoStepAuthFloodError
                }
                
                updateState {
                    return $0.withUpdatedError(InputDataValueError(description: errorText, target: .data), for: _id_input_recovery_code).withUpdatedChecking(false)
                }
                
                f(.fail(.fields([_id_input_recovery_code: .shake])))
                
            }, completed: {
                updateState {
                    return $0.withUpdatedChecking(false)
                }
                success()
            }))
        })
    }
    
    return InputDataController(dataSignal: signal |> map { InputDataSignalValue(entries: $0) }, title: strings().twoStepAuthRecoveryTitle, validateData: { data in
        
        let code = stateValue.with {$0.code}
        let loading = stateValue.with {$0.checking}

        if !loading {
            return checkRecoveryCode(code)
        } else {
            NSSound.beep()
        }
        return .none
    }, updateDatas: { data in
        updateState { current in
            return current.withUpdatedCode(data[_id_input_recovery_code]?.stringValue ?? current.code).withUpdatedError(nil, for: _id_input_recovery_code)
        }
        return .none
    }, afterDisappear: {
        resetDisposable.dispose()
    }, updateDoneValue: { data in
        return { f in
            let code = stateValue.with {$0.code}
            let loading = stateValue.with {$0.checking}
            f(loading ? .loading : code.isEmpty ? .disabled(strings().navigationDone) : .enabled(strings().navigationDone))
        }
    }, removeAfterDisappear: true, hasDone: true, identifier: "tsv-reset")
}




private let _id_input_entry_pwd = InputDataIdentifier("_id_input_entry_pwd")
private let _id_input_reentry_pwd = InputDataIdentifier("_id_input_reentry_pwd")
private let _id_input_entry_hint = InputDataIdentifier("_id_input_entry_hint")
private let _id_input_entry_email = InputDataIdentifier("_id_input_entry_email")
private let _id_input_entry_code = InputDataIdentifier("_id_input_entry_code")

private func twoStepVerificationPasswordEntryControllerEntries(state: TwoStepVerificationPasswordEntryControllerState, mode: TwoStepVerificationPasswordEntryMode) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    var index: Int32 = 0
    
    
    switch state.stage {
    case let .entry(text):
        
        let placeholder:String
        switch mode {
        case .change:
            placeholder = strings().twoStepAuthEnterPasswordPassword
        default:
            placeholder = strings().twoStepAuthEnterPasswordPassword
        }
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(text), error: state.errors[_id_input_entry_pwd], identifier: _id_input_entry_pwd, mode: .secure, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: placeholder, filter: { $0 }, limit: 255))
        index += 1
        
        switch mode {
        case .setup:
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().twoStepAuthSetupPasswordDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
            index += 1
        case .change:
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().twoStepAuthChangePasswordDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
            index += 1
        default:
            break
        }
        
    case let .reentry(_, text):
        entries.append(.input(sectionId: sectionId, index: index, value: .string(text), error: state.errors[_id_input_reentry_pwd], identifier: _id_input_reentry_pwd, mode: .secure, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().twoStepAuthEnterPasswordPassword, filter: { $0 }, limit: 255))
        index += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().twoStepAuthSetupPasswordConfirmPassword), data: InputDataGeneralTextData(viewType: .textBottomItem)))
        index += 1
    case let .hint(_, text):
        entries.append(.input(sectionId: sectionId, index: index, value: .string(text), error: state.errors[_id_input_entry_hint], identifier: _id_input_entry_hint, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().twoStepAuthSetupHintPlaceholder, filter: { $0 }, limit: 255))
        index += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().twoStepAuthSetupHintDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
        index += 1
    case let .email(_, _, text, change):
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(text), error: state.errors[_id_input_entry_email], identifier: _id_input_entry_email, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().twoStepAuthEmail, filter: { $0 }, limit: 255))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(change ? strings().twoStepAuthEmailHelpChange : strings().twoStepAuthEmailHelp), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    case let .code(text, codeLength, pattern):
        entries.append(.input(sectionId: sectionId, index: index, value: .string(text), error: state.errors[_id_input_entry_code], identifier: _id_input_entry_code, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().twoStepAuthRecoveryCode, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: codeLength ?? 255))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().twoStepAuthConfirmEmailCodeDesc(pattern)), data: InputDataGeneralTextData(detectBold: false, viewType: .textBottomItem)))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}



func twoStepVerificationPasswordEntryController(context: AccountContext, mode: TwoStepVerificationPasswordEntryMode, initialStage: PasswordEntryStage?, result: @escaping(SetupTwoStepVerificationStateUpdate) -> Void, presentController: @escaping((controller: ViewController, root: Bool, animated: Bool)) -> Void) -> InputDataController {

    
    let network = context.account.network
    
    var initialStage: PasswordEntryStage! = initialStage
    if initialStage == nil {
        switch mode {
        case .setup, .change:
            initialStage =  .entry(text: "")
        case let .setupEmail(password, change):
            initialStage = .email(password: password, hint: "", text: "", change: change)
        case let .enterCode(codeLength, pattern):
            initialStage = .code(text: "", codeLength: codeLength, pattern: pattern)
        }
    }

    let initialState = TwoStepVerificationPasswordEntryControllerState(stage: initialStage, updating: false, errors: [:])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((TwoStepVerificationPasswordEntryControllerState) -> TwoStepVerificationPasswordEntryControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let signal: Signal<[InputDataEntry], NoError> = statePromise.get() |> map { state in
        return twoStepVerificationPasswordEntryControllerEntries(state: state, mode: mode)
    }
    
    
    let actionsDisposable = DisposableSet()
    
    let updatePasswordDisposable = MetaDisposable()
    actionsDisposable.add(updatePasswordDisposable)
 
    
    func checkAndSaveState(context:AccountContext) -> InputDataValidation {
        var passwordHintEmail: (String, String, String)?
        var enterCode: String?
        updateState { state in
            if state.updating {
                return state
            } else {
                switch state.stage {
                case .entry:
                    break
                case .reentry:
                    break
                case let .hint(password, text):
                    switch mode {
                    case .change:
                        passwordHintEmail = (password, text, "")
                    default:
                        preconditionFailure()
                    }
                case let .email(password, hint, text, _):
                    passwordHintEmail = (password, hint, text)
                case let .code(text, _, _):
                    enterCode = text
                }
            }
            return state
        }
        
        
        return .fail(.doSomething { f in
            if let (password, hint, email) = passwordHintEmail {
                
                updateState {
                    $0.withUpdatedUpdating(true)
                }
                
                switch mode {
                case .setup, .change:
                    var currentPassword: String?
                    if case let .change(current) = mode {
                        currentPassword = current
                    }

                    updatePasswordDisposable.set((context.engine.auth.updateTwoStepVerificationPassword(currentPassword: currentPassword, updatedPassword: .password(password: password, hint: hint, email: email)) |> deliverOnMainQueue).start(next: { update in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        switch update {
                        case let .password(password, pendingEmail):
                            if let pendingEmail = pendingEmail {
                                result(.awaitingEmailConfirmation(password: password, pattern: email, codeLength: pendingEmail.codeLength))
                            } else {
                                result(.passwordSet(password: password, hasRecoveryEmail: false, hasSecureValues: false))
                            }
                        case .none:
                            break
                        }
                    }, error: { error in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        switch error {
                        case .generic:
                            alert(for: context.window, info: strings().twoStepAuthErrorGeneric)
                        case .invalidEmail:
                            updateState {
                                $0.withUpdatedError(InputDataValueError(description: strings().twoStepAuthErrorInvalidEmail, target: .data), for: _id_input_entry_email)
                            }
                            f(.fail(.fields([_id_input_entry_email: .shake])))
                        }
                        
                    }))
                case let .setupEmail(password, _):
                    updatePasswordDisposable.set((context.engine.auth.updateTwoStepVerificationEmail(currentPassword: password, updatedEmail: email) |> deliverOnMainQueue).start(next: { update in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        switch update {
                        case let .password(password, pendingEmail):
                            if let pendingEmail = pendingEmail {
                                result(.awaitingEmailConfirmation(password: password, pattern: email, codeLength: pendingEmail.codeLength))
                            } else {
                                result(.passwordSet(password: password, hasRecoveryEmail: true, hasSecureValues: false))
                            }
                        case .none:
                            break
                        }
                    }, error: { error in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        let errorText: String
                        switch error {
                        case .generic:
                            errorText = strings().twoStepAuthErrorGeneric
                        case .invalidEmail:
                            errorText = strings().twoStepAuthErrorInvalidEmail
                        }
                        updateState {
                            $0.withUpdatedError(InputDataValueError(description: errorText, target: .data), for: _id_input_entry_email)
                        }
                        f(.fail(.fields([_id_input_entry_email: .shake])))
                    }))
                case .enterCode:
                    fatalError()
                }
            } else if let code = enterCode {
                updateState {
                    $0.withUpdatedUpdating(true)
                }
                updatePasswordDisposable.set((context.engine.auth.confirmTwoStepRecoveryEmail(code: code) |> deliverOnMainQueue).start(error: { error in
                    updateState {
                        $0.withUpdatedUpdating(false)
                    }
                    let errorText: String
                    switch error {
                    case .generic:
                        errorText = strings().twoStepAuthGenericError
                    case .invalidCode:
                        errorText = strings().twoStepAuthRecoveryCodeInvalid
                    case .expired:
                        errorText = strings().twoStepAuthRecoveryCodeExpired
                    case .flood:
                        errorText = strings().twoStepAuthFloodError
                    case .invalidEmail:
                        errorText = strings().twoStepAuthErrorInvalidEmail
                    }
                    updateState {
                        $0.withUpdatedError(InputDataValueError(description: errorText, target: .data), for: _id_input_entry_code)
                    }
                    f(.fail(.fields([_id_input_entry_code: .shake])))
                    
                }, completed: {
                    updateState {
                        $0.withUpdatedUpdating(false)
                    }
                    result(.emailSet)
                }))
            }
        })
        
        
    }


    return InputDataController(dataSignal: signal |> map { InputDataSignalValue(entries: $0) }, title: "", validateData: { data -> InputDataValidation in
        
        var stage: PasswordEntryStage?
        var allowPerform: Bool = true
        
        let loading = stateValue.with {$0.updating}
        
        if !loading {
            return .fail(.doSomething { f in
                var skipEmail: Bool = false
                updateState { state in
                    var state = state
                    if state.updating {
                        return state
                    } else {
                        switch state.stage {
                        case let .entry(text):
                            if text.isEmpty {
                                return state
                            } else {
                                stage = .reentry(first: text, text: "")
                            }
                        case let .reentry(first, text):
                            if text.isEmpty {
                                
                            } else if text != first {
                                state = state.withUpdatedError(InputDataValueError(description: strings().twoStepAuthSetupPasswordConfirmFailed, target: .data), for: _id_input_reentry_pwd)
                                f(.fail(.fields([_id_input_reentry_pwd : .shake])))
                            } else {
                                stage = .hint(password: text, text: "")
                            }
                        case let .hint(password, text):
                            switch mode {
                            case .setup:
                                stage = .email(password: password, hint: text, text: "", change: false)
                            default:
                                break
                            }
                        case let .email(_, _, text, _):
                            if text.isEmpty {
                                skipEmail = true
                            }
                        case let .code(text, codeLength, _):
                            if text.isEmpty {
                                allowPerform = false
                            } else if let codeLength = codeLength, text.length != codeLength {
                                allowPerform = false
                            } else {
                                allowPerform = true
                            }
                        }
                        return state
                    }
                }
                if allowPerform {
                    if let stage = stage {
                        presentController((controller: twoStepVerificationPasswordEntryController(context: context, mode: mode, initialStage: stage, result: result, presentController: presentController), root: false, animated: true))
                    } else {
                        if skipEmail {
                            verifyAlert_button(for: context.window, information: strings().twoStepAuthEmailSkipAlert, ok: strings().twoStepAuthEmailSkip, successHandler: { _ in
                                f(checkAndSaveState(context: context))
                            })
                        } else {
                            f(checkAndSaveState(context: context))
                        }
                    }
                }
            })
        } else {
            NSSound.beep()
            return .none
        }
    }, updateDatas: { data -> InputDataValidation in
        
        let previousCode: String?
        switch stateValue.with ({ $0.stage }) {
        case let .code(text, _, _):
            previousCode = text
        default:
            previousCode = nil
        }
        
        updateState { state in
            switch state.stage {
            case let .entry(text):
                return state.withUpdatedStage(.entry(text: data[_id_input_entry_pwd]?.stringValue ?? text))
            case let .reentry(first, text):
                return state.withUpdatedStage(.reentry(first: first, text: data[_id_input_reentry_pwd]?.stringValue ?? text)).withUpdatedError(nil, for: _id_input_reentry_pwd)
            case let .hint(password, text):
                return state.withUpdatedStage(.hint(password: password, text: data[_id_input_entry_hint]?.stringValue ?? text)).withUpdatedError(nil, for: _id_input_entry_hint)
            case let .email(password, hint, text, change):
                return state.withUpdatedStage(.email(password: password, hint: hint, text: data[_id_input_entry_email]?.stringValue ?? text, change: change)).withUpdatedError(nil, for: _id_input_entry_email)
            case let .code(text, codeLength, pattern):
                return state.withUpdatedStage(.code(text: data[_id_input_entry_code]?.stringValue ?? text, codeLength: codeLength, pattern: pattern)).withUpdatedError(nil, for: _id_input_entry_code)
            }
        }
        
        switch stateValue.with ({ $0.stage }) {
        case let .code(text, codeLength, _):
            if Int32(text.length) == codeLength, previousCode != text {
                return checkAndSaveState(context: context)
            }
        default:
            break
        }
        
        return .none
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, updateDoneValue: { data in
        return { f in
            updateState { state in
                
                if state.updating {
                    f(.loading)
                } else {
                    switch state.stage {
                    case let .entry(text):
                        if text.isEmpty {
                            f(.disabled(strings().navigationNext))
                        } else {
                            f(.enabled(strings().navigationNext))
                        }
                    case let .reentry(_, text):
                        if text.isEmpty {
                            f(.disabled(strings().navigationNext))
                        } else {
                            f(.enabled(strings().navigationNext))
                        }
                    case let .hint(_, text):
                        if text.isEmpty {
                            f(.enabled(strings().twoStepAuthEmailSkip))
                        } else {
                            f(.enabled(strings().navigationNext))
                        }
                    case let .email(_, _, text, _):
                        switch mode {
                        case .setupEmail:
                            f(text.isEmpty ? .disabled(strings().navigationNext) : .enabled(strings().navigationNext))
                        default:
                            f(text.isEmpty ? .enabled(strings().twoStepAuthEmailSkip) : .enabled(strings().navigationNext))
                        }
                    case let .code(text, codeLength, _):
                        if let codeLength = codeLength {
                            f(text.length < codeLength ? .disabled(strings().navigationNext) : .enabled(strings().navigationNext))
                        } else {
                            f(text.isEmpty ? .disabled(strings().navigationNext) : .enabled(strings().navigationNext))
                        }
                    }
                }
                return state
            }
        }
    }, removeAfterDisappear: false, hasDone: true, identifier: "tsv-entry", afterTransaction: { controller in
        var stage: PasswordEntryStage?
        updateState { state in
            stage = state.stage
            return state
        }
        if let stage = stage {
            var title: String = ""
            
            switch stage {
            case .entry:
                switch mode {
                case .change:
                    title = strings().twoStepAuthChangePassword
                case .setup:
                    title = strings().twoStepAuthSetupPasswordTitle
                case .setupEmail:
                    title = strings().twoStepAuthSetupPasswordTitle
                case .enterCode:
                    preconditionFailure()
                }
                
            case .reentry:
                switch mode {
                case .change:
                    title = strings().twoStepAuthChangePassword
                case .setup:
                    title = strings().twoStepAuthSetupPasswordTitle
                case .setupEmail:
                    title = strings().twoStepAuthSetupPasswordTitle
                case .enterCode:
                    preconditionFailure()
                }
            case .hint:
                title = strings().twoStepAuthSetupHintTitle
            case .email:
                title = strings().twoStepAuthSetupEmailTitle
            case .code:
                title = strings().twoStepAuthSetupEmailTitle
            }
            controller.setCenterTitle(title)
        }
    })
    
}
