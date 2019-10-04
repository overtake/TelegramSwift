//
//  WalletProcessTransactionController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04/10/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

private final class WalletTransactionArguments {
    let context: AccountContext
    let buttonAction: ()->Void
    init(context: AccountContext, buttonAction: @escaping()->Void) {
        self.context = context
        self.buttonAction = buttonAction
    }
}

private enum WalletTransactionMode : Equatable {
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
            return ""
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
        
    let animation: WalletAnimatedSticker?
    
    switch state.mode {
    case .passcode:
        animation = WalletAnimatedSticker.keychain
    case .sending:
        animation = WalletAnimatedSticker.fly_dollar
    case .sent:
        animation = WalletAnimatedSticker.gift
    }
    
  
    switch state.mode {
    case .passcode:
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return WalletSplashRowItem(initialSize, stableId: stableId, context: arguments.context, title: state.mode.title, desc: state.mode.text, animation: animation, viewType: .modern(position: .inner, insets: NSEdgeInsets()), action: { _ in })
        }))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: state.passcode ?? .none, error: state.passcodeError, identifier: _id_passcode, mode: .secure, data: InputDataRowData(viewType: .singleItem, maxBlockWidth: 280), placeholder: nil, inputPlaceholder: L10n.walletProcessTransactionPasscodePlaceholder, filter: { $0 }, limit: 255))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        //
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_button, equatable: InputDataEquatable(state.mode), item: { initialSize, stableId in
            return WalletSplashButtonRowItem(initialSize, stableId: stableId, buttonText: L10n.walletSendProcessTranfer, subButtonText: nil, viewType: .lastItem, subTextAction: { _ in }, action: arguments.buttonAction)
        }))
        index += 1
    case .sending:
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return WalletSplashRowItem(initialSize, stableId: stableId, context: arguments.context, title: state.mode.title, desc: state.mode.text, animation: animation, viewType: .modern(position: .inner, insets: NSEdgeInsets()), action: { _ in })
        }))
        index += 1
        
    case .sent:
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return WalletSplashRowItem(initialSize, stableId: stableId, context: arguments.context, title: L10n.walletSendSentTitle, desc: L10n.walletSendSentText(formatBalanceText(state.amount)), animation: animation, viewType: .modern(position: .inner, insets: NSEdgeInsets()), action: { _ in })
        }))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        //
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_button, equatable: InputDataEquatable(state.mode), item: { initialSize, stableId in
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
func WalletProcessTransactionController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, amount: Int64, to address: String, comment: String, updateWallet:(()->Void)? = nil) -> InputDataModalController {
    let initialState = WalletTransactionState(amount: amount, randomId: arc4random64(), mode: .passcode, passcode: nil, passcodeError: nil)
    let state: ValuePromise<WalletTransactionState> = ValuePromise(initialState)
    let stateValue: Atomic<WalletTransactionState> = Atomic(value: initialState)
    
    let updateState:((WalletTransactionState)->WalletTransactionState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    let checkPasscode = MetaDisposable()
    let sendDisposable = MetaDisposable()
    var getController:(()->InputDataController?)? = nil
    
    let arguments = WalletTransactionArguments(context: context, buttonAction: {
        getController?()?.validateInputValues()
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return entries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    var getModalController:(()->InputDataModalController?)? = nil
    
    let controller = InputDataController(dataSignal: dataSignal, title: "", hasDone: false)
    
    func send(_ decryptedSecret: Data, _ state: WalletTransactionState, _ force: Bool) -> InputDataValidation {
        return .fail(.doSomething(next: { f in
            let signal = getServerWalletSalt(network: context.account.network) |> mapError { _ in
                return SendGramsFromWalletError.generic
                } |> mapToSignal { salt in
                    sendGramsFromWallet(postbox: context.account.postbox, network: context.account.network, tonInstance: tonContext.instance, walletInfo: walletInfo, decryptedSecret: decryptedSecret, localPassword: salt, toAddress: address, amount: state.amount, textMessage: comment.data(using: .utf8)!, forceIfDestinationNotInitialized: false, timeout: 0, randomId: state.randomId)
            } |> deliverOnMainQueue
            
            sendDisposable.set(signal.start(error: { error in
                var bp:Int = 0
                bp += 1
            }, completed: {
                updateState {
                    $0.withUpdatedMode(.sent)
                }
            }))
            
        }))
    }
    
    controller.validateData = { data in
        let state = stateValue.with { $0 }
        
        switch state.mode {
        case .passcode:
            return .fail(.doSomething(next: { f in
                if let passcode = state.passcode?.stringValue {
                    let signal = TONKeychain.decryptedSecretKey(walletInfo.encryptedSecret, tonInstance: tonContext.instance, by: passcode) |> deliverOnMainQueue
                    checkPasscode.set(signal.start(next: { data in
                        if let data = data {
                            updateState {
                                $0.withUpdatedMode(.sending)
                            }
                            f(send(data, state, false))
                        } else {
                            f(.fail(.fields([_id_passcode : .shake])))
                        }
                    }))
                } else {
                    f(.fail(.fields([_id_passcode : .shake])))
                }
            }))
        case .sent:
            updateWallet?()
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
    
//    controller.rightModalHeader = ModalHeaderData(image: theme.icons.wallet_close, handler: {
//        closeAllModals()
//    })
    
    controller.afterDisappear = {
        checkPasscode.dispose()
        sendDisposable.dispose()
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    let modalController = InputDataModalController(controller, closeHandler: { f in
        f()
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
