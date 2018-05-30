//
//  TwoStepVerificationPasswordEntryController.swift
//  Telegram
//
//  Created by keepcoder on 17/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import TGUIKit

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<TwoStepVerificationPasswordEntryEntry>], right: [AppearanceWrapperEntry<TwoStepVerificationPasswordEntryEntry>], initialSize:NSSize, arguments:TwoStepVerificationPasswordEntryControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class TwoStepVerificationPasswordEntryController: TableViewController {

    fileprivate let mode: TwoStepVerificationPasswordEntryMode
    fileprivate let result: Promise<TwoStepVerificationPasswordEntryResult?>
    fileprivate var nextAction:(()->Void)?
    fileprivate let disposable = MetaDisposable()
    init(account: Account, mode: TwoStepVerificationPasswordEntryMode, result: Promise<TwoStepVerificationPasswordEntryResult?>) {
        self.mode = mode
        self.result = result
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let mode = self.mode
        let result = self.result
        
        let initialStage: PasswordEntryStage
        switch mode {
        case .setup, .change:
            initialStage = .entry(text: "")
        case .setupEmail:
            initialStage = .email(password: "", hint: "", text: "")
        }
        let initialState = TwoStepVerificationPasswordEntryControllerState(stage: initialStage, updating: false)
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((TwoStepVerificationPasswordEntryControllerState) -> TwoStepVerificationPasswordEntryControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        
        let actionsDisposable = DisposableSet()
        
        let updatePasswordDisposable = MetaDisposable()
        actionsDisposable.add(updatePasswordDisposable)
        
        func checkPassword(_ skipEmail:Bool = false) {
            var passwordHintEmail: (String, String, String)?
            var invalidReentry = false
            updateState { state in
                if state.updating {
                    return state
                } else {
                    switch state.stage {
                    case let .entry(text):
                        if text.isEmpty {
                            return state
                        } else {
                            return state.withUpdatedStage(.reentry(first: text, text: ""))
                        }
                    case let .reentry(first, text):
                        if text.isEmpty {
                            return state
                        } else if text != first {
                            invalidReentry = true
                            return state.withUpdatedStage(.entry(text: ""))
                        } else {
                            return state.withUpdatedStage(.hint(password: text, text: ""))
                        }
                    case let .hint(password, text):
                        switch mode {
                        case .setup:
                            return state.withUpdatedStage(.email(password: password, hint: text, text: ""))
                        case .change:
                            passwordHintEmail = (password, text, "")
                            return state.withUpdatedUpdating(true)
                        case .setupEmail:
                            preconditionFailure()
                        }
                    case let .email(password, hint, text):
                        passwordHintEmail = (password, hint, text)
                        return state.withUpdatedUpdating(true)
                    }
                }
            }
            if let (password, hint, email) = passwordHintEmail {
                switch mode {
                case .setup, .change:
                    var currentPassword: String?
                    if case let .change(current) = mode {
                        currentPassword = current
                    }
                    updatePasswordDisposable.set((updateTwoStepVerificationPassword(network: account.network, currentPassword: currentPassword, updatedPassword: .password(password: password, hint: hint, email: skipEmail ? "" : email)) |> deliverOnMainQueue).start(next: { update in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        switch update {
                        case let .password(password, pendingEmailPattern):
                            result.set(.single(TwoStepVerificationPasswordEntryResult(password: password, pendingEmailPattern: pendingEmailPattern)))
                        case .none:
                            break
                        }
                    }, error: { error in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        let alertText: String
                        switch error {
                        case .generic:
                            alertText = tr(L10n.twoStepAuthErrorGeneric)
                        case .invalidEmail:
                            alertText = tr(L10n.twoStepAuthErrorInvalidEmail)
                        }
                        alert(for: mainWindow, info: alertText)
                    }))
                case let .setupEmail(password):
                    updatePasswordDisposable.set((updateTwoStepVerificationEmail(account: account, currentPassword: password, updatedEmail: email) |> deliverOnMainQueue).start(next: { update in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        switch update {
                        case let .password(password, pendingEmailPattern):
                            result.set(.single(TwoStepVerificationPasswordEntryResult(password: password, pendingEmailPattern: pendingEmailPattern)))
                        case .none:
                            break
                        }
                    }, error: { error in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        let alertText: String
                        switch error {
                        case .generic:
                            alertText = tr(L10n.twoStepAuthErrorGeneric)
                        case .invalidEmail:
                            alertText = tr(L10n.twoStepAuthErrorInvalidEmail)
                        }
                        alert(for: mainWindow, info: alertText)
                    }))
                }
            } else if invalidReentry {
                alert(for: mainWindow, info: tr(L10n.twoStepAuthErrorPasswordsDontMatch))
            }
        }
        
        let arguments = TwoStepVerificationPasswordEntryControllerArguments(updateEntryText: { updatedText in
            updateState {
                $0.withUpdatedStage($0.stage.updateCurrentText(updatedText))
            }
        }, next: { [weak self] in
            
            if self?.rightBarView.isEnabled == false {
                NSSound.beep()
                return
            }
            
            let value = stateValue.modify({$0})
            
            if !value.updating {
                switch value.stage {
                case let .email(password: _, hint: _, text):
                    switch mode {
                    case .setupEmail:
                        checkPassword()
                        return
                    default:
                        break
                    }
                    if text.isEmpty {
                        confirm(for: mainWindow, information: tr(L10n.twoStepAuthEmailSkipAlert), successHandler: { _ in
                            checkPassword()
                        })
                    } else {
                        checkPassword()
                    }
                    return
                default:
                    break
                }
            }
            
            checkPassword()
        }, skipEmail: {
            confirm(for: mainWindow, information: tr(L10n.twoStepAuthEmailSkipAlert), successHandler: { _ in
                checkPassword(true)
            })
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<TwoStepVerificationPasswordEntryEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        let signal = combineLatest(appearanceSignal, statePromise.get()) |> deliverOnMainQueue
            |> map { appearance, state -> (TableUpdateTransition, Bool, String) in
                
                var nextEnabled = true
                var title: String = "Password"
                
                switch state.stage {
                case .entry:
                    title = tr(L10n.twoStepAuthSetupPasswordTitle)
                case .reentry:
                     title = tr(L10n.twoStepAuthSetupPasswordTitle)
                case .hint:
                     title = tr(L10n.twoStepAuthSetupHintTitle)
                case .email:
                     title = tr(L10n.twoStepAuthSetupEmailTitle)
                }
                
                if state.updating {
                    nextEnabled = false
                } else {
                    switch state.stage {
                    case let .entry(text):
                        if text.isEmpty {
                            nextEnabled = false
                        }
                    case let.reentry(_, text):
                        if text.isEmpty {
                            nextEnabled = false
                        }
                    case .hint:
                        break
                    case .email(let text):
                        switch mode {
                        case .setupEmail:
                            nextEnabled = !text.text.isEmpty
                        default:
                            nextEnabled = true
                        }
                    }
                   
                }
                
                let entries = twoStepVerificationPasswordEntryControllerEntries(state: state, mode: mode).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                
                return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), nextEnabled, title)
            } |> afterDisposed {
                actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        nextAction = arguments.next
        
        disposable.set(signal.start(next: { [weak self] transition, nextEnabled, title in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
            self?.setCenterTitle(title)
            self?.rightBarView.isEnabled = nextEnabled
        }))
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: tr(L10n.composeNext))
        
        button.set(handler: { [weak self] _ in
            self?.nextAction?()
        }, for: .Click)
        
        return button
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        nextAction?()
        return .invoked
    }
    
    override func firstResponder() -> NSResponder? {
        if genericView.count > 1 {
            if !(window?.firstResponder is NSTextView) {
                return (genericView.viewNecessary(at: 1) as? GeneralInputRowView)?.firstResponder
            }
        }
        return window?.firstResponder
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
}
