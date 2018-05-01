//
//  TwoStepVerificationResetController.swift
//  Telegram
//
//  Created by keepcoder on 18/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit




private func twoStepVerificationResetControllerEntries(state: TwoStepVerificationResetControllerState, emailPattern: String) -> [TwoStepVerificationResetEntry] {
    var entries: [TwoStepVerificationResetEntry] = []
    
    var sectionId:Int32 = 0
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.codeEntry(sectionId : sectionId, state.codeText))
    entries.append(.codeInfo(sectionId : sectionId, tr(L10n.twoStepAuthRecoveryCodeHelp) + "\n\n[\(tr(L10n.twoStepAuthRecoveryEmailUnavailable(emailPattern)))]()"))
    return entries
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<TwoStepVerificationResetEntry>], right: [AppearanceWrapperEntry<TwoStepVerificationResetEntry>], initialSize:NSSize, arguments:TwoStepVerificationResetControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class TwoStepVerificationResetController : TableViewController {
    fileprivate let emailPattern: String
    fileprivate let result: Promise<Bool>
    fileprivate let disposable = MetaDisposable()
    fileprivate var nextAction:(()->Void)?
    init(account: Account, emailPattern: String, result: Promise<Bool>) {
        self.emailPattern = emailPattern
        self.result = result
        super.init(account)
    }
    
    override var defaultBarTitle: String {
        return tr(L10n.twoStepAuthRecoveryTitle)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        let account = self.account
        let result = self.result
        let emailPattern = self.emailPattern
        let initialSize = self.atomicSize
        let initialState = TwoStepVerificationResetControllerState(codeText: "", checking: false)
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((TwoStepVerificationResetControllerState) -> TwoStepVerificationResetControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let actionsDisposable = DisposableSet()
        
        let resetPasswordDisposable = MetaDisposable()
        actionsDisposable.add(resetPasswordDisposable)
        
        let checkCode: () -> Void = { [weak self] in
            
            if self?.rightBarView.isEnabled == false {
                NSSound.beep()
                return
            }
            
            var code: String?
            updateState { state in
                if state.checking || state.codeText.isEmpty {
                    return state
                } else {
                    code = state.codeText
                    return state.withUpdatedChecking(true)
                }
            }
            if let code = code {
                resetPasswordDisposable.set((recoverTwoStepVerificationPassword(network: account.network, code: code) |> deliverOnMainQueue).start(error: { error in
                    updateState {
                        return $0.withUpdatedChecking(false)
                    }
                    let alertText: String
                    switch error {
                    case .generic:
                        alertText = tr(L10n.twoStepAuthGenericError)
                    case .invalidCode:
                        alertText = tr(L10n.twoStepAuthRecoveryCodeInvalid)
                    case .codeExpired:
                        alertText = tr(L10n.twoStepAuthRecoveryCodeExpired)
                    case .limitExceeded:
                        alertText = tr(L10n.twoStepAuthFloodError)
                    }
                    alert(for: mainWindow, info: alertText)

                }, completed: {
                    updateState {
                        return $0.withUpdatedChecking(false)
                    }
                    result.set(.single(true))
                }))
            }
        }
        
        let arguments = TwoStepVerificationResetControllerArguments(updateEntryText: { updatedText in
            updateState {
                $0.withUpdatedCodeText(updatedText)
            }
        }, next: {
            checkCode()
        }, openEmailInaccessible: {
            alert(for: mainWindow, info: tr(L10n.twoStepAuthErrorHaventEmail))
        })
        
        
        self.nextAction = checkCode
        
        let previous: Atomic<[AppearanceWrapperEntry<TwoStepVerificationResetEntry>]> = Atomic(value: [])
        
        let signal = combineLatest(appearanceSignal, statePromise.get()) |> deliverOnMainQueue
            |> map { appearance, state -> (TableUpdateTransition, Bool) in
                
                var nextEnabled = true

                
                if state.checking {
                    nextEnabled = false
                } else {
                    if state.codeText.isEmpty {
                        nextEnabled = false
                    }
                }
                let entries = twoStepVerificationResetControllerEntries(state: state, emailPattern: emailPattern).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                
                return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), nextEnabled)
            } |> afterDisposed {
                actionsDisposable.dispose()
        }
        
        disposable.set(signal.start(next: { [weak self] transition, enabled in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
            self?.rightBarView.isEnabled = enabled
        }))
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
            return (genericView.viewNecessary(at: 1) as? GeneralInputRowView)?.firstResponder
        }
        return nil
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



