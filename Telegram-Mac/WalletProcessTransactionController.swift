//
//  WalletProcessTransactionController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04/10/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import WalletCore

private final class WalletTransactionArguments {
    let context: AccountContext
    let buttonAction: ()->Void
    init(context: AccountContext, buttonAction: @escaping()->Void) {
        self.context = context
        self.buttonAction = buttonAction
    }
}

enum WalletTransactionMode : Equatable {
    case none
    case passcode
    case sending
    case sent
    
    var title: String {
        switch self {
        case .passcode:
            return L10n.walletProcessTransactionPasscodeTitle
        case .sending:
            return L10n.walletSendSendingTitle
        default:
            return L10n.walletSendSentTitle
        }
    }
    
    var headerId:InputDataIdentifier {
        switch self {
        case .none:
            return InputDataIdentifier("_header_none")
        case .passcode:
            return InputDataIdentifier("_header_passcode")
        case .sending:
            return InputDataIdentifier("_header_sending")
        case .sent:
            return InputDataIdentifier("_header_sent")
        }
    }
    
    var text: String {
        switch self {
        case .passcode:
            return L10n.walletProcessTransactionPasscodeText
        case .sending:
            return L10n.walletSendSendingText
        default:
            return ""
        }
    }
}

private struct WalletTransactionState : Equatable {
    let amount: Int64
    let randomId: Int64
    let mode: WalletTransactionMode
    let passcode: InputDataValue?
    let passcodeError: InputDataValueError?
    init(amount: Int64, randomId: Int64, mode: WalletTransactionMode, passcode: InputDataValue?, passcodeError: InputDataValueError?) {
        self.amount = amount
        self.randomId = randomId
        self.mode = mode
        self.passcode = passcode
        self.passcodeError = passcodeError
    }
    
    func withUpdatedPasscode(_ passcode: InputDataValue?) -> WalletTransactionState {
        return WalletTransactionState(amount: self.amount, randomId: randomId, mode: self.mode, passcode: passcode, passcodeError: self.passcodeError)
    }
    func withUpdatedPasscodeError(_ passcodeError: InputDataValueError?) -> WalletTransactionState {
        return WalletTransactionState(amount: self.amount, randomId: randomId, mode: self.mode, passcode: self.passcode, passcodeError: passcodeError)
    }
    func withUpdatedMode(_ mode: WalletTransactionMode) -> WalletTransactionState {
        return WalletTransactionState(amount: self.amount, randomId: randomId, mode: mode, passcode: self.passcode, passcodeError: self.passcodeError)
    }
}
private let _id_header = InputDataIdentifier("_id_header")
private let _id_passcode = InputDataIdentifier("_id_passcode")
private let _id_button = InputDataIdentifier("_id_button")

@available (OSX 10.12, *)
private func entries(state: WalletTransactionState, arguments: WalletTransactionArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("topDynamic"), equatable: InputDataEquatable(arc4random()), item: { initialSize, stableId in
        return DynamicHeightRowItem(initialSize, stableId: stableId, side: .top)
    }))
    
    let animation: LocalAnimatedSticker?
    
    switch state.mode {
    case .passcode:
        animation = LocalAnimatedSticker.keychain
    case .sending:
        animation = LocalAnimatedSticker.fly_dollar
    case .sent:
        animation = LocalAnimatedSticker.gift
    case .none:
        animation = nil
    }
    
    let desc: String
    switch state.mode {
    case .passcode:
        if let error = state.passcodeError {
            desc = L10n.walletProcessTransactionPasscodeTextError(error.description)
        } else {
            desc = state.mode.text
        }
    case .sending:
        desc = state.mode.text
    case .sent:
        desc = L10n.walletSendSentText(formatBalanceText(state.amount))
    case .none:
        desc = ""
    }
    
    let title: String
    switch state.mode {
    case .passcode:
        if let _ = state.passcodeError {
            title = L10n.walletProcessTransactionPasscodeTitleError
        } else {
            title = state.mode.title
        }
    default:
        title = state.mode.title
    }
    
    switch state.mode {
    case .none:
        break
    default:
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: state.mode.headerId, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return WalletSplashRowItem(initialSize, stableId: stableId, context: arguments.context, title: title, desc: desc, animation: animation, viewType: .modern(position: .inner, insets: NSEdgeInsets()), action: { _ in })
        }))
        index += 1
    }
    
  
    switch state.mode {
    case .passcode:
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: state.passcode ?? .none, error: nil, identifier: _id_passcode, mode: .secure, data: InputDataRowData(viewType: .singleItem, maxBlockWidth: 280), placeholder: nil, inputPlaceholder: L10n.walletProcessTransactionPasscodePlaceholder, filter: { $0 }, limit: 255))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        //
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_button, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return WalletSplashButtonRowItem(initialSize, stableId: stableId, buttonText: L10n.walletSendProcessTranfer, subButtonText: nil, enabled: state.passcodeError == nil, viewType: .lastItem, subTextAction: { _ in }, action: arguments.buttonAction)
        }))
        index += 1
    case .sending, .none:
        break
        
    case .sent:
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_button, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return WalletSplashButtonRowItem(initialSize, stableId: stableId, buttonText: L10n.walletSendSentViewMyWallet, subButtonText: nil, viewType: .lastItem, subTextAction: { _ in }, action: arguments.buttonAction)
        }))
        index += 1
    }

    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("bottomDynamic"), equatable: InputDataEquatable(arc4random()), item: { initialSize, stableId in
        return DynamicHeightRowItem(initialSize, stableId: stableId, side: .bottom)
    }))
    
    
    return entries
}

@available (OSX 10.12, *)
func WalletProcessTransactionController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, amount: Int64, to address: String, comment: String, updateMode:@escaping(WalletTransactionMode)->Void, updateWallet:((Bool)->Void)? = nil) -> InputDataModalController {
    let initialState = WalletTransactionState(amount: amount, randomId: arc4random64(), mode: .passcode, passcode: nil, passcodeError: nil)
    let state: ValuePromise<WalletTransactionState> = ValuePromise(initialState)
    let stateValue: Atomic<WalletTransactionState> = Atomic(value: initialState)
    
    let updateState:((WalletTransactionState)->WalletTransactionState) -> Void = { f in
        let result = stateValue.modify(f)
        state.set(result)
        updateMode(result.mode)
    }
    
    let checkPasscode = MetaDisposable()
    let sendDisposable = MetaDisposable()
    let updateTimeout = MetaDisposable()

    var getController:(()->InputDataController?)? = nil
    
    let arguments = WalletTransactionArguments(context: context, buttonAction: {
        getController?()?.validateInputValues()
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return entries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    updateTimeout.set(context.walletPasscodeTimeoutContext.value.start(next: { timeout in
        updateState { current in
            if timeout > 0 {
                let minutes = timeout / 60
                let seconds = timeout % 60
                let string = String(format: "%@:%@", minutes < 10 ? "0\(minutes)" : "\(minutes)", seconds < 10 ? "0\(seconds)" : "\(seconds)")
                return current.withUpdatedPasscodeError(InputDataValueError.init(description: string, target: .data))
            } else {
                return current.withUpdatedPasscodeError(nil)
            }
        }
    }))
    
    var getModalController:(()->InputDataModalController?)? = nil
    
    let controller = InputDataController(dataSignal: dataSignal, title: "", hasDone: false)
    
    func send(_ decryptedSecret: Data, _ state: WalletTransactionState, _ force: Bool) -> InputDataValidation {
        return .fail(.doSomething(next: { f in
            let signal = getServerWalletSalt(network: context.account.network) |> mapError { _ in
                return SendGramsFromWalletError.generic
                } |> mapToSignal { salt in
                    sendGramsFromWallet(storage: tonContext.storage, tonInstance: tonContext.instance, walletInfo: walletInfo, decryptedSecret: decryptedSecret, localPassword: salt, toAddress: address, amount: state.amount, textMessage: comment.data(using: .utf8)!, forceIfDestinationNotInitialized: force, timeout: 0, randomId: state.randomId)
            } |> timeout(15.0, queue: .mainQueue(), alternate: .fail(.network)) |> deliverOnMainQueue
            
            sendDisposable.set(signal.start(error: { error in
                var errorText: String?
                switch error {
                case .destinationIsNotInitialized:
                    confirm(for: context.window, header: L10n.walletSendErrorTitle, information: L10n.walletSendErrorDestinationIsNotInitialized, okTitle: L10n.walletSendSendAnyway, cancelTitle: "", thridTitle: L10n.modalCancel, successHandler: { result in
                        switch result {
                        case .basic:
                            getController?()?.proccessValidation(send(decryptedSecret, state, true))
                        default:
                            updateState {
                                $0.withUpdatedMode(.none)
                            }
                            getModalController?()?.close()
                        }
                    })
                case .invalidAddress:
                    errorText = L10n.walletSendErrorInvalidAddress
                case .messageTooLong:
                    errorText = L10n.unknownError
                case .network:
                    errorText = L10n.walletSendErrorNetwork
                case .notEnoughFunds:
                    errorText = L10n.walletSendErrorNotEnoughFundsText
                case .secretDecryptionFailed:
                    errorText = L10n.walletSendErrorDecryptionFailed
                case .generic:
                    errorText = L10n.unknownError
                }
                
                if let errorText = errorText {
                    alert(for: context.window, header: L10n.walletSendErrorTitle, info: errorText)
                    updateState {
                        $0.withUpdatedMode(.none)
                    }
                    getModalController?()?.close()
                }
            }, completed: {
                updateState {
                    $0.withUpdatedMode(.sent)
                }
                updateWallet?(false)
            }))
            
        }))
    }
    
    controller.validateData = { data in
        let state = stateValue.with { $0 }
        switch state.mode {
        case .passcode:
            return .fail(.doSomething(next: { f in
                if state.passcodeError == nil {
                    if let passcode = state.passcode?.stringValue  {
                        let signal = TONKeychain.decryptedSecretKey(walletInfo.encryptedSecret, account: context.account, tonInstance: tonContext.instance, by: passcode) |> deliverOnMainQueue
                        checkPasscode.set(signal.start(next: { data in
                            if let data = data {
                                updateState {
                                    $0.withUpdatedMode(.sending)
                                }
                                f(send(data, state, true))
                                context.walletPasscodeTimeoutContext.disposeLevel()
                            } else {
                                f(.fail(.fields([_id_passcode : .shake])))
                                context.walletPasscodeTimeoutContext.incrementLevel()
                            }
                        }))
                    } else {
                        f(.fail(.fields([_id_passcode : .shake])))
                    }
                } else {
                    f(.none)
                }
            }))
        case .sent:
            updateWallet?(true)
        default:
            break
        }
        
        return .none
    }
    
    controller.updateDatas = { data in
        updateState { current in
            switch current.mode {
            case .passcode:
                return current.withUpdatedPasscode(data[_id_passcode])
            default:
                return current
            }
        }
        return .none
    }
    
//    controller.leftModalHeader = ModalHeaderData(image: theme.icons.wallet_close, handler: {
//        closeAllModals()
//    })
    
    controller.onDeinit = {
        checkPasscode.dispose()
        sendDisposable.dispose()
        updateTimeout.dispose()
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    let modalController = InputDataModalController(controller, closeHandler: { f in
        switch stateValue.with ({ $0.mode }) {
        case .passcode, .none:
            f()
        case .sent:
            f()
            closeAllModals()
        default:
            break
        }
    }, size: NSMakeSize(350, 350))
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    modalController.isFullScreenImpl = {
        return true
    }
    modalController.dynamicSizeImpl = {
        return false
    }
    
    return modalController
}
