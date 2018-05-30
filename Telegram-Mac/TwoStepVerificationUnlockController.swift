//
//  TwoStepVerificationUnlockController.swift
//  Telegram
//
//  Created by keepcoder on 16/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

private func twoStepVerificationUnlockSettingsControllerEntries(state: TwoStepVerificationUnlockSettingsControllerState,data: TwoStepVerificationUnlockSettingsControllerData) -> [TwoStepVerificationUnlockSettingsEntry] {
    var entries: [TwoStepVerificationUnlockSettingsEntry] = []
    var sectionId:Int32 = 0
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    switch data {
    case let .access(configuration):
        if let configuration = configuration {
            switch configuration {
            case let .notSet(pendingEmailPattern):
                if pendingEmailPattern.isEmpty {
                    entries.append(.passwordSetup(sectionId: sectionId, tr(L10n.twoStepAuthSetPassword)))
                    entries.append(.passwordSetupInfo(sectionId: sectionId, tr(L10n.twoStepAuthSetPasswordHelp)))
                } else {
                    entries.append(.pendingEmailInfo(sectionId: sectionId, tr(L10n.twoStepAuthConfirmationText) + "\n\n\(pendingEmailPattern)\n\n[" + tr(L10n.twoStepAuthConfirmationAbort) + "]()"))
                }
            case let .set(hint, _, _):
                entries.append(.passwordEntry(sectionId: sectionId, tr(L10n.twoStepAuthEnterPasswordPassword), state.passwordText))
                if hint.isEmpty {
                    entries.append(.passwordEntryInfo(sectionId: sectionId, tr(L10n.twoStepAuthEnterPasswordHelp) + "\n\n[" + tr(L10n.twoStepAuthEnterPasswordForgot) + "](forgot)"))
                } else {
                    entries.append(.passwordEntryInfo(sectionId: sectionId, tr(L10n.twoStepAuthEnterPasswordHint(hint)) + "\n\n" + tr(L10n.twoStepAuthEnterPasswordHelp) + "\n\n[" + tr(L10n.twoStepAuthEnterPasswordForgot) + "](forgot)"))
                }
            }
        }
    case let .manage(_, emailSet, pendingEmailPattern):
        entries.append(.changePassword(sectionId: sectionId, tr(L10n.twoStepAuthChangePassword)))
        entries.append(.turnPasswordOff(sectionId: sectionId, tr(L10n.twoStepAuthRemovePassword)))
        entries.append(.setupRecoveryEmail(sectionId: sectionId, emailSet ? tr(L10n.twoStepAuthChangeEmail) : tr(L10n.twoStepAuthSetupEmail)))
        if pendingEmailPattern.isEmpty {
            entries.append(.passwordInfo(sectionId: sectionId, tr(L10n.twoStepAuthGenericHelp)))
        } else {
            entries.append(.passwordInfo(sectionId: sectionId, tr(L10n.twoStepAuthPendingEmailHelp(pendingEmailPattern))))
        }
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<TwoStepVerificationUnlockSettingsEntry>], right: [AppearanceWrapperEntry<TwoStepVerificationUnlockSettingsEntry>], initialSize:NSSize, arguments:TwoStepVerificationUnlockSettingsControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class TwoStepVerificationUnlockController: TableViewController {

    private let mode:TwoStepVerificationUnlockSettingsControllerMode
    private var invokeNextAction:(()->Void)?
    private let disposable = MetaDisposable()
    private var removeOnDisappear: Bool = false
    init(account: Account, mode: TwoStepVerificationUnlockSettingsControllerMode) {
        self.mode = mode
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let mode = self.mode
        
        let initialState = TwoStepVerificationUnlockSettingsControllerState(passwordText: "", checking: false)
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((TwoStepVerificationUnlockSettingsControllerState) -> TwoStepVerificationUnlockSettingsControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        var presentControllerImpl: ((ViewController) -> Void)?
        
        let actionsDisposable = DisposableSet()
        
        let checkDisposable = MetaDisposable()
        actionsDisposable.add(checkDisposable)
        
        let setupDisposable = MetaDisposable()
        actionsDisposable.add(setupDisposable)
        
        let setupResultDisposable = MetaDisposable()
        actionsDisposable.add(setupResultDisposable)
        
        let dataPromise = Promise<TwoStepVerificationUnlockSettingsControllerData>()
        
        switch mode {
        case .access:
            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: nil)) |> then(twoStepVerificationConfiguration(account: account) |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: $0) }))
        case let .manage(password, email, pendingEmailPattern):
            dataPromise.set(.single(.manage(password: password, emailSet: !email.isEmpty, pendingEmailPattern: pendingEmailPattern)))
        }
        
        let arguments = TwoStepVerificationUnlockSettingsControllerArguments(updatePasswordText: { updatedText in
            updateState {
                $0.withUpdatedPasswordText(updatedText)
            }
        }, openForgotPassword: {
            setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
                switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        switch configuration {
                        case let .set(_, hasRecoveryEmail, _):
                            if hasRecoveryEmail {
                                updateState {
                                    $0.withUpdatedChecking(true)
                                }
                                setupResultDisposable.set((requestTwoStepVerificationPasswordRecoveryCode(network: account.network) |> deliverOnMainQueue).start(next: { emailPattern in
                                    updateState {
                                        $0.withUpdatedChecking(false)
                                    }
                                    let result = Promise<Bool>()
                                    let controller = TwoStepVerificationResetController(account: account, emailPattern: emailPattern, result: result)
                                    presentControllerImpl?(controller)
                                    
                                    setupDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] _ in
                                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationConfiguration.notSet(pendingEmailPattern: ""))))
                                        controller?.dismiss()
                                    }))
                                }, error: { _ in
                                    updateState {
                                        $0.withUpdatedChecking(false)
                                    }
                                    alert(for: mainWindow, info: tr(L10n.twoStepAuthAnError))
                                }))
                            } else {
                                alert(for: mainWindow, info: tr(L10n.twoStepAuthErrorHaventEmail))
                            }
                        case .notSet:
                            break
                        }
                    }
                case .manage:
                    break
                }
            }))
        }, openSetupPassword: {
            setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
                switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        switch configuration {
                        case .notSet:
                            let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                            let controller = TwoStepVerificationPasswordEntryController(account: account, mode: .setup, result: result)
                            presentControllerImpl?(controller)
                            setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                                if let updatedPassword = updatedPassword {
                                    if let pendingEmailPattern = updatedPassword.pendingEmailPattern {
                                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationConfiguration.notSet(pendingEmailPattern: pendingEmailPattern))))
                                    } else {
                                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: false, pendingEmailPattern: "")))
                                    }
                                    controller?.dismiss()
                                }
                            }))
                        case .set:
                            break
                        }
                    }
                case let .manage(password, emailSet, pendingEmailPattern):
                    let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                    let controller = TwoStepVerificationPasswordEntryController(account: account, mode: .change(current: password), result: result)
                    presentControllerImpl?(controller)
                    setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                        if let updatedPassword = updatedPassword {
                           dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: emailSet, pendingEmailPattern: pendingEmailPattern)))
                            controller?.dismiss()
                        }
                    }))
                }
            }))
        }, openDisablePassword: {
            
            confirm(for: mainWindow, information: tr(L10n.twoStepAuthConfirmDisablePassword), successHandler: { _ in
                var disablePassword = false
                updateState { state in
                    if state.checking {
                        return state
                    } else {
                        disablePassword = true
                        return state.withUpdatedChecking(true)
                    }
                }
                if disablePassword {
                    setupDisposable.set((dataPromise.get()
                        |> take(1)
                        |> mapError { _ -> UpdateTwoStepVerificationPasswordError in return .generic }
                        |> mapToSignal { data -> Signal<Void, UpdateTwoStepVerificationPasswordError> in
                            switch data {
                            case .access:
                                return .complete()
                            case let .manage(password, _, _):
                                return updateTwoStepVerificationPassword(network: account.network, currentPassword: password, updatedPassword: .none)
                                    |> mapToSignal { _ -> Signal<Void, UpdateTwoStepVerificationPasswordError> in
                                        return .complete()
                                }
                            }
                        }
                        |> deliverOnMainQueue).start(error: { _ in
                            updateState {
                                $0.withUpdatedChecking(false)
                            }
                        }, completed: {
                            updateState {
                                $0.withUpdatedChecking(false)
                            }
                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmailPattern: ""))))
                        }))
                }
            })
 
        }, openSetupEmail: {
            setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
                switch data {
                case .access:
                    break
                case let .manage(password, _, _):
                    let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                    let controller = TwoStepVerificationPasswordEntryController(account: account, mode: .setupEmail(password: password), result: result)
                    presentControllerImpl?(controller)
                    setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                        if let updatedPassword = updatedPassword {
                           dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: true, pendingEmailPattern: updatedPassword.pendingEmailPattern ?? "")))
                            controller?.dismiss()
                        }
                    }))
                }
            }))
        }, openResetPendingEmail: {
            updateState { state in
                return state.withUpdatedChecking(true)
            }
            setupDisposable.set((updateTwoStepVerificationPassword(network: account.network, currentPassword: nil, updatedPassword: .none) |> deliverOnMainQueue).start(next: { _ in
                updateState { state in
                    return state.withUpdatedChecking(false)
                }
                dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmailPattern: ""))))
            }, error: { _ in
                updateState { state in
                    return state.withUpdatedChecking(false)
                }
            }))
        })
        
        let previous: Atomic<[AppearanceWrapperEntry<TwoStepVerificationUnlockSettingsEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        var nextAction:(()->Void)? = nil
        
        let shake:()->Void = { [weak self] in
            (self?.firstResponder() as? NSTextView)?.shake()
            (self?.firstResponder() as? NSTextView)?.selectAll(nil)
            NSSound.beep()
        }
        
        let signal = combineLatest(appearanceSignal, statePromise.get(), dataPromise.get() |> deliverOnMainQueue)
            |> map { appearance, state, data -> (TableUpdateTransition, String, TwoStepVerificationUnlockSettingsControllerData) in
                
                
                let entries = twoStepVerificationUnlockSettingsControllerEntries(state: state, data: data).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                
                var title: String = tr(L10n.twoStepAuthPasswordTitle)
                switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        if state.checking {
                            nextAction = nil
                        } else {
                            switch configuration {
                            case .notSet:
                                title = tr(L10n.telegramTwoStepVerificationUnlockController)
                            case let .set(_, _, pendingEmailPattern):
                                title = tr(L10n.twoStepAuthPasswordTitle)
                                nextAction = {
                                    
                                    var wasChecking = false
                                    var password: String?
                                    updateState { state in
                                        wasChecking = state.checking
                                        password = state.passwordText
                                        return state.withUpdatedChecking(true)
                                    }
                                
                                    if let password = password, !wasChecking {
                                        checkDisposable.set((requestTwoStepVerifiationSettings(network: account.network, password: password) |> deliverOnMainQueue).start(next: { settings in
                                            updateState {
                                                $0.withUpdatedChecking(false)
                                            }
                                            presentControllerImpl?(TwoStepVerificationUnlockController(account: account, mode: .manage(password: password, email: settings.email, pendingEmailPattern: pendingEmailPattern)))
                                        }, error: { error in
                                            updateState {
                                                $0.withUpdatedChecking(false)
                                            }
                                            
                                            switch error {
                                            case .limitExceeded:
                                                alert(for: mainWindow, info: tr(L10n.twoStepAuthErrorLimitExceeded))
                                            case .invalidPassword:
                                                shake()
                                                //text = tr(L10n.twoStepAuthErrorInvalidPassword)
                                            case .generic:
                                                 alert(for: mainWindow, info: tr(L10n.twoStepAuthErrorGeneric))
                                            }
                                           
                                        }))
                                    }
                                }
                            }
                        }
                    }
                case .manage:
                    title = tr(L10n.telegramTwoStepVerificationUnlockController)
                    if state.checking {
                       nextAction = nil
                    }
                }
                
                return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), title, data)
            } |> afterDisposed {
                actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        self.invokeNextAction = {
            nextAction?()
        }
        
        disposable.set(signal.start(next: { [weak self] transition, title, data in
            self?.genericView.merge(with: transition)
            
            switch mode {
            case .access:
                switch data {
                case let .access(configuration):
                    self?.removeOnDisappear = false
                    if let configuration = configuration {
                        switch configuration {
                        case .notSet:
                            self?.rightBarView.isHidden = true
                            self?.removeOnDisappear = false
                        case .set:
                            self?.rightBarView.isHidden = false
                            self?.removeOnDisappear = true
                        }
                    } else {
                        self?.rightBarView.isHidden = true
                    }
                case .manage:
                    self?.removeOnDisappear = false
                    self?.rightBarView.isHidden = true
                }
            case .manage:
                self?.removeOnDisappear = false
                self?.rightBarView.isHidden = true
            }
            
            
            self?.setCenterTitle(title)
        }))
        
        readyOnce()
        
        presentControllerImpl = { [weak self] controller in
            self?.navigationController?.push(controller)
        }
    }
    
    override var removeAfterDisapper: Bool {
        return removeOnDisappear
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        if genericView.count > 1 {
            if !(window?.firstResponder is NSTextView) {
                return (genericView.viewNecessary(at: 1) as? GeneralInputRowView)?.firstResponder
            }
        }
        return window?.firstResponder
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: tr(L10n.composeNext))
        
        button.set(handler: { [weak self] _ in
            self?.invokeNextAction?()
        }, for: .Click)
        
        return button
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        invokeNextAction?()
        return .invoked
    }
    
}

/*
 
 var rightNavigationButton: ItemListNavigationButton?
 var emptyStateItem: ItemListControllerEmptyStateItem?
 let title: String
 switch data {
 case let .access(configuration):
 title = presentationData.strings.TwoStepAuth_Title
 if let configuration = configuration {
 if state.checking {
 rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
 } else {
 switch configuration {
 case .notSet:
 break
 case .set:
 rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Next, style: .bold, enabled: true, action: {
 var wasChecking = false
 var password: String?
 updateState { state in
 wasChecking = state.checking
 password = state.passwordText
 return state.withUpdatedChecking(true)
 }
 
 if let password = password, !wasChecking {
 checkDisposable.set((requestTwoStepVerifiationSettings(account: account, password: password) |> deliverOnMainQueue).start(next: { settings in
 updateState {
 $0.withUpdatedChecking(false)
 }
 
 replaceControllerImpl?(twoStepVerificationUnlockSettingsController(account: account, mode: .manage(password: password, email: settings.email, pendingEmailPattern: "")))
 }, error: { error in
 updateState {
 $0.withUpdatedChecking(false)
 }
 
 let text: String
 switch error {
 case .limitExceeded:
 text = "You have entered invalid password too many times. Please try again later."
 case .invalidPassword:
 text = "Invalid password. Please try again."
 case .generic:
 text = "An error occured. Please try again later."
 }
 
 presentControllerImpl?(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
 }))
 }
 })
 }
 }
 } else {
 emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
 }
 case .manage:
 title = presentationData.strings.PrivacySettings_TwoStepAuth
 if state.checking {
 rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
 }
 }
 
 let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
 let listState = ItemListNodeState(entries: twoStepVerificationUnlockSettingsControllerEntries(presentationData: presentationData, state: state, data: data), style: .blocks, focusItemTag: TwoStepVerificationUnlockSettingsEntryTag.password, emptyStateItem: emptyStateItem, animateChanges: false)
 
 return (controllerState, (listState, arguments))
 */
