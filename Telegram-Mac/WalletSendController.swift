//
//  WalletSendController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit



private final class WalletSendArguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct WalletSendingDest : Equatable {
    let randomId: Int64
    let recipient: String
    let comment: String
    let amount: Int64
    init(randomId: Int64, amount: Int64, recipient: String, comment: String) {
        self.randomId = randomId
        self.recipient = recipient
        self.amount = amount
        self.comment = comment
    }
}


private struct WalletSendState : Equatable {
    let walletState: WalletState?
    let recipient: String
    let comment: String
    let amount: String
    let sendingState: WalletTransactionMode
    let address: String
    init(walletState: WalletState?, sendingState: WalletTransactionMode, address: String, recipient: String, comment: String, amount: String) {
        self.sendingState = sendingState
        self.walletState = walletState
        self.recipient = recipient
        self.comment = comment
        self.amount = amount
        self.address = address
    }
    func withUpdatedWalletState(_ walletState: WalletState?) -> WalletSendState {
        return WalletSendState(walletState: walletState, sendingState: self.sendingState, address: self.address, recipient: recipient, comment: self.comment, amount: self.amount)
    }
    func withUpdatedRecipient(_ recipient: String) -> WalletSendState {
        return WalletSendState(walletState: self.walletState, sendingState: self.sendingState, address: self.address, recipient: recipient, comment: self.comment, amount: self.amount)
    }
    func withUpdatedComment(_ comment: String) -> WalletSendState {
        return WalletSendState(walletState: self.walletState, sendingState: self.sendingState, address: self.address, recipient: self.recipient, comment: comment, amount: self.amount)
    }
    func withUpdatedAmount(_ amount: String) -> WalletSendState {
        return WalletSendState(walletState: self.walletState, sendingState: self.sendingState, address: self.address, recipient: self.recipient, comment: self.comment, amount: amount)
    }
    func withUpdatedAddress(_ address: String) -> WalletSendState {
        return WalletSendState(walletState: self.walletState, sendingState: self.sendingState, address: address, recipient: self.recipient, comment: self.comment, amount: self.amount)
    }
    func withUpdatedSendingState(_ sendingState: WalletTransactionMode) -> WalletSendState {
        return WalletSendState(walletState: self.walletState, sendingState: sendingState, address: self.address, recipient: self.recipient, comment: self.comment, amount: self.amount)
    }
}
private let _id_recipient = InputDataIdentifier("_id_recipient")
private let _id_amount = InputDataIdentifier("_id_amount")
private let _id_comment = InputDataIdentifier("_id_comment")

private func WalletSendEntries(state: WalletSendState, arguments: WalletSendArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletSendRecipientHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.recipient), error: nil, identifier: _id_recipient, mode: .plain, data: InputDataRowData(viewType: .singleItem, pasteFilter: { value in
        
        let value = value.trimmingCharacters(in: invalidAddressCharacters).replacingOccurrences(of: "\n", with: "")
        
        if isValidAddress(value) {
            return (true, value)
        }
        if let url = URL(string: value), let data = parseWalletUrl(url) {
            return (true, data.address)
        }
        return (false, value)
    }), placeholder: nil, inputPlaceholder: L10n.walletSendRecipientPlaceholder, filter: { value in
        return value.trimmingCharacters(in: invalidAddressCharacters)
    }, limit: Int32(walletAddressLength)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletSendRecipientDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    let text: NSMutableAttributedString?
    if let balance = state.walletState?.balance {
        let color = balance > amountValue(state.amount) ? theme.colors.listGrayText : theme.colors.redUI
        var attr: String = ""
        let value = formatBalanceText(balance)
        if let range = value.range(of: Formatter.withSeparator.decimalSeparator) {
            let integralPart = String(value[..<range.lowerBound])
            let fractionalPart = String(value[range.lowerBound...])
            attr = "**" + integralPart + "**"
            attr += fractionalPart
        } else {
            attr = "**" + value + "**"
        }
        text = NSMutableAttributedString()
        let balance = L10n.walletSendAmountBalance(attr)
        _ = text?.append(string: balance, color: color, font: .normal(11.5))
        _ = text?.detectBoldColorInString(with: .medium(11.5))
        
        let range = balance.nsstring.range(of: ":")
        if range.location != NSNotFound {
            text?.addAttributes([InputDataTextInsertAnimatedViewData.attributeKey : InputDataTextInsertAnimatedViewData(context: arguments.context, file: WalletAnimatedSticker.brilliant_static.file)], range: NSMakeRange(range.location + 1, 3))
        }
    } else {
        text = nil
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletSendAmountHeader), data: InputDataGeneralTextData(viewType: .textTopItem, rightItem: InputDataGeneralTextRightData(isLoading: state.walletState == nil, text: text))))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.amount), error: nil, identifier: _id_amount, mode: .plain, data: InputDataRowData(viewType: .firstItem, pasteFilter: { value in
        if isValidAmount(value) {
            return (true, value)
        }
        return (false, value)
    }), placeholder: nil, inputPlaceholder: L10n.walletSendAmountPlaceholder, filter: { value in
        
        let set = CharacterSet(charactersIn: "0987654321.,\(Formatter.withSeparator.decimalSeparator!)")
        let value = value.trimmingCharacters(in: set.inverted)
        
        if !isValidAmount(value) {
            return state.amount
        }
        return value
    }, limit: 40))
    index += 1
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.comment), error: nil, identifier: _id_comment, mode: .plain, data: InputDataRowData(viewType: .lastItem), placeholder: nil, inputPlaceholder: L10n.walletSendCommentPlaceholder, filter: { current in
        if let data = current.data(using: .utf8) {
            let ncut = data.suffix(500)
            return String(data: ncut, encoding: .utf8)!
        } else {
            return current
        }
    }, limit: 500))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    
    return entries
}
@available(OSX 10.12, *)
func WalletSendController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, walletState: WalletState? = nil, recipient: String = "", comment: String = "", amount: String = "", updateWallet:(()->Void)? = nil) -> InputDataModalController {
    let initialState = WalletSendState(walletState: walletState, sendingState: .passcode, address: "", recipient: recipient, comment: comment, amount: formatAmountText(amount))
    let state: ValuePromise<WalletSendState> = ValuePromise()
    let stateValue: Atomic<WalletSendState> = Atomic(value: initialState)
    
    let updateState:((WalletSendState)->WalletSendState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    let updateBalanceDisposable = MetaDisposable()
    let transferDisposable = MetaDisposable()
    
    let updateBalance:()->Void = {
        let signal = getCombinedWalletState(postbox: context.account.postbox, subject: .wallet(walletInfo), tonInstance: tonContext.instance)
        
        let address = walletAddress(publicKey: walletInfo.publicKey, tonInstance: tonContext.instance)
            |> mapError { _ in
                return GetCombinedWalletStateError.generic
            }
        
        updateBalanceDisposable.set(combineLatest(queue: .mainQueue(), address, signal).start(next: { address, state in
            switch state {
            case let .cached(combinedState):
                if let combinedState = combinedState {
                    updateState {
                        $0.withUpdatedWalletState(combinedState.walletState)
                            .withUpdatedAddress(address)
                    }
                } else {
                    updateState {
                        $0.withUpdatedAddress(address)
                    }
                }
            case let .updated(combinedState):
                updateState {
                    $0.withUpdatedWalletState(combinedState.walletState)
                        .withUpdatedAddress(address)
                }
            }
        }, error: { error in
            
        }))
    }
    
    var getController:(()->InputDataController?)? = nil
    
    let arguments = WalletSendArguments(context: context)
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return WalletSendEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    var getModalController:(()->InputDataModalController?)? = nil
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.walletSendTitle)
    
    controller.updateDatas = { data in
        updateState {
            $0.withUpdatedComment(data[_id_comment]?.stringValue ?? "")
                .withUpdatedRecipient(data[_id_recipient]?.stringValue ?? "")
                .withUpdatedAmount(formatAmountText(data[_id_amount]?.stringValue ?? ""))
        }
        return .none
    }
    
    
    
    
    let serverSaltValue = Promise<Data?>()
    serverSaltValue.set(getServerWalletSalt(network: context.account.network)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Data?, NoError> in
            return .single(nil)
        })

    
    controller.validateData = { data in
        let state = stateValue.with { $0 }
        
        let addressIsValid = isValidAddress(state.recipient, exactLength: true)
        let amountIsValid = isValidAmount(state.amount) && amountValue(state.amount) <= state.walletState?.balance ?? 0 && amountValue(state.amount) > 0
        
        if !addressIsValid {
            return .fail(.fields([_id_recipient : .shake]))
        }
        if !amountIsValid {
            return .fail(.fields([_id_amount : .shake]))
        }
        
        return .fail(.doSomething(next: { f in
            confirm(for: context.window, header: L10n.walletSendConfirmationHeader, information: L10n.walletSendConfirmationText(state.amount, state.recipient), okTitle: L10n.walletSendConfirmationOK, successHandler: { _ in
                
                let state = stateValue.with { $0 }
                
                let invoke:()->Void = {
                    
                    let controller = WalletProcessTransactionController(context: context, tonContext: tonContext, walletInfo: walletInfo, amount: amountValue(state.amount), to: state.recipient, comment: state.comment, updateMode: { mode in
                        updateState { $0.withUpdatedSendingState(mode) }
                    }, updateWallet: { close in
                        if close {
                            getModalController?()?.close()
                        }
                        if let updateWallet = updateWallet {
                            updateWallet()
                        } else if close {
                            context.sharedContext.bindings.rootNavigation().push(WalletInfoController(context: context, tonContext: tonContext, walletInfo: walletInfo))
                        }
                        
                    })
                    
                    
                    if let parentModal = getModalController?()?.modal {
                        let modal = Modal(controller: controller, for: context.window, isOverlay: false, animationType: .scaleCenter, parentView: parentModal.containerView)
                         modal.show()
                    }
                }
                
                if state.recipient == state.address {
                    confirm(for: context.window, header: L10n.walletSendConfirmTitle, information: L10n.walletSendSelfConfirmText, okTitle: L10n.walletSendSelfConfirmOK, successHandler: { _ in
                        invoke()
                    })
                } else {
                    invoke()
                }
            })
        }))
    }
    
    let interactions = ModalInteractions(acceptTitle: L10n.modalSend, accept: { [weak controller] in
        controller?.validateInputValues()
    }, drawBorder: true, height: 50, singleButton: true)
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.afterTransaction = { controller in
        interactions.updateDone { title in
            let addressIsValid = isValidAddress(stateValue.with { $0.recipient }, exactLength: true)
            let amountIsValid = isValidAmount(stateValue.with { $0.amount }) && amountValue(stateValue.with { $0.amount }) <= stateValue.with { $0.walletState?.balance ?? 0 } && amountValue(stateValue.with { $0.amount }) > 0
            title.isEnabled = amountIsValid && addressIsValid
        }
    }
    
    controller.onDeinit = {
        transferDisposable.dispose()
        updateBalanceDisposable.dispose()
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.wallet_close, handler: {
        getModalController?()?.close()
    })
    
    let modalController = InputDataModalController(controller, modalInteractions: interactions, closeHandler: { f in
        f()
        closeAllModals()
    }, size: NSMakeSize(350, 350))
    
    
    modalController.closableImpl = {
        let value = stateValue.with { $0.sendingState }
        switch value {
        case .passcode, .sent:
            return true
        default:
            return false
        }
    }
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    updateBalance()
    
    return modalController
    
}

