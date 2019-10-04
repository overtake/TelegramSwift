//
//  WalletInfoController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit


private final class WalletInfoArguments {
    let context: AccountContext
    let openReceive:()->Void
    let openSend:()->Void
    let openTransaction:(WalletTransaction)->Void
    let update:()->Void
    init(context: AccountContext, openReceive: @escaping()->Void, openSend: @escaping()->Void, openTransaction: @escaping(WalletTransaction)->Void, update:@escaping()->Void) {
        self.context = context
        self.openReceive = openReceive
        self.openSend = openSend
        self.openTransaction = openTransaction
        self.update = update
    }
}

private struct WalletInfoState : Equatable {
    let walletState: WalletState?
    let updatedTimestamp: Int64?
    let previousTimestamp: Int64?
    let address: String
    let transactions:[WalletTransaction]
    init(walletState: WalletState?, updatedTimestamp: Int64?, previousTimestamp: Int64?, address: String, transactions:[WalletTransaction]) {
        self.walletState = walletState
        self.address = address
        self.updatedTimestamp = updatedTimestamp
        self.previousTimestamp = previousTimestamp
        self.transactions = transactions.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    func withUpdatedWalletState(_ walletState: WalletState?) -> WalletInfoState {
        return WalletInfoState(walletState: walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, transactions: self.transactions)
    }
    func withUpdatedAddress(_ address: String) -> WalletInfoState {
        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: address, transactions: self.transactions)
    }
    
    func withUpdatedTimestamp(_ updatedTimestamp: Int64?) -> WalletInfoState {
        return WalletInfoState(walletState: self.walletState, updatedTimestamp: updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, transactions: self.transactions)
    }
    func withUpdatedPreviousTimestamp(_ previousTimestamp: Int64?) -> WalletInfoState {
        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: previousTimestamp, address: self.address, transactions: self.transactions)
    }
    func withUpdatedTransactions(_ transactions: [WalletTransaction]) -> WalletInfoState {
        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, transactions: transactions)
    }
    
    func withAddedTransactions(_ list: [WalletTransaction]) -> WalletInfoState {
        var transactions = self.transactions
        transactions.append(contentsOf: list.filter { transaction in
            return !transactions.contains(where: { $0.transactionId == transaction.transactionId })
        })
        
        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, transactions: transactions)
    }
}

private let _id_balance = InputDataIdentifier("_id_balance")
private let _id_created_address = InputDataIdentifier("_id_created_address")
private func _id_transaction(_ id: WalletTransactionId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_transaction_\(id.lt)")
}
private func _id_date(_ id:Int32) -> InputDataIdentifier {
    return InputDataIdentifier("_id_data_\(id)")
}
private func walletInfoEntries(_ state: WalletInfoState, arguments: WalletInfoArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if let _ = state.walletState {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_balance, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return WalletBalanceItem(initialSize, stableId: stableId, context: arguments.context, state: state.walletState, updatedTimestamp: state.updatedTimestamp, viewType: .singleItem, receiveMoney: arguments.openReceive, sendMoney: arguments.openSend, update: arguments.update)
        }))
        index += 1
 
        
        if state.transactions.isEmpty  {
            
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_created_address, equatable: InputDataEquatable(state), item: { initialSize, stableId in
                return WalletInfoCreatedItem(initialSize, stableId: stableId, context: arguments.context, address: state.address, viewType: .singleItem)
            }))
            index += 1
        } else {
            
            enum TransactionItem : Equatable {
                case transaction(WalletTransaction)
                case date(Int32)
            }
            
            var items: [TransactionItem] = []
            
            
            for (i, transaction) in state.transactions.enumerated() {
                let prev: WalletTransaction? = i == 0 ? nil : state.transactions[i - 1]
                let next: WalletTransaction? = i == state.transactions.count - 1 ? nil : state.transactions[i + 1]
                if prev == nil {
                    let dateId = chatDateId(for: Int32(transaction.timestamp))
                    items.append(.date(Int32(dateId)))
                }
                
                items.append(.transaction(transaction))
                
                if let next = next {
                    let dateId = chatDateId(for: Int32(transaction.timestamp))
                    let nextDateId = chatDateId(for: Int32(next.timestamp))
                    
                    if dateId != nextDateId {
                        items.append(.date(Int32(nextDateId)))
                    }
                }
            }
            
            
            var groupItems:[(TransactionItem, [TransactionItem])] = []
            var current:[TransactionItem] = []
            for item in items.reversed() {
                switch item {
                case .date:
                    if !current.isEmpty {
                        groupItems.append((item, current))
                        current.removeAll()
                    }
                case .transaction:
                    current.insert(item, at: 0)
                }
            }

            for group in groupItems.reversed() {
                switch group.0 {
                case let .date(timestamp):
                    entries.append(.sectionId(sectionId, type: .normal))
                    sectionId += 1
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_date(timestamp), equatable: InputDataEquatable(timestamp), item: { initialSize, stableId in
                        return WalletTransactionDateStickItem(initialSize, timestamp: timestamp, viewType: .firstItem)
                    }))
                    
                    for item in group.1 {
                        switch item {
                        case let .transaction(transaction):
                            struct E : Equatable {
                                let transaction: WalletTransaction
                                let viewType: GeneralViewType
                            }
                            
                            let value = E(transaction: transaction, viewType: bestGeneralViewType(group.1, for: item))
                            
                            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction(transaction.transactionId), equatable: InputDataEquatable(value), item: { initialSize, stableId in
                                return WalletInfoTransactionItem(initialSize, stableId: stableId, context: arguments.context, transaction: value.transaction, viewType: value.viewType, action: {
                                    arguments.openTransaction(transaction)
                                })
                            }))
                            index += 1
                        default:
                            break
                        }
                        
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}
@available(OSX 10.12, *)
func WalletInfoController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo) -> InputDataController {
    
    let initialState = WalletInfoState(walletState: nil, updatedTimestamp: nil, previousTimestamp: nil, address: "", transactions: [])
    let state: ValuePromise<WalletInfoState> = ValuePromise()
    let stateValue: Atomic<WalletInfoState> = Atomic(value: initialState)
    
    let updateState:((WalletInfoState)->WalletInfoState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    var getController:(()->InputDataController?)? = nil


    let updateBalanceDisposable = MetaDisposable()
    let updateBalance:()->Void = {
        let signal = combineLatest(queue: .mainQueue(), getCombinedWalletState(postbox: context.account.postbox, subject: .wallet(walletInfo), tonInstance: tonContext.instance), walletAddress(publicKey: walletInfo.publicKey, tonInstance: tonContext.instance) |> mapError { _ in return .generic })
        
        updateBalanceDisposable.set(signal.start(next: { state, address in
            switch state {
            case let .cached(combinedState):
                if let combinedState = combinedState {
                    updateState {
                        $0.withUpdatedTimestamp($0.walletState == nil ? combinedState.timestamp : $0.updatedTimestamp)
                            .withUpdatedPreviousTimestamp(combinedState.timestamp)
                            .withUpdatedWalletState(combinedState.walletState)
                            .withAddedTransactions(combinedState.topTransactions)
                            .withUpdatedAddress(address)
                    }
                } else {
                    updateState {
                        $0.withUpdatedAddress(address)
                    }
                }
            case let .updated(combinedState):
                updateState {
                    $0.withUpdatedTimestamp(combinedState.timestamp)
                        .withUpdatedPreviousTimestamp(combinedState.timestamp)
                        .withUpdatedWalletState(combinedState.walletState)
                        .withAddedTransactions(combinedState.topTransactions)
                        .withUpdatedAddress(address)
                }
            }
        }, error: { error in
            if stateValue.with({$0.updatedTimestamp == nil}) {
                getController?()?.show(toaster: ControllerToaster(text: L10n.walletBalanceInfoRetrieveError))
            }
            updateState {
                $0.withUpdatedTimestamp($0.previousTimestamp)
            }
        }))
    }
    
    let transactionListDisposable = MetaDisposable()
    
    let loadTransactions:(WalletTransactionId?)->Void = { transactionId in
        let signal = getWalletTransactions(address: stateValue.with { $0.address }, previousId: transactionId, tonInstance: tonContext.instance) |> deliverOnMainQueue
        transactionListDisposable.set(signal.start(next: { list in
            updateState {
                $0.withAddedTransactions(list)
            }
        }, error: { error in
          
        }))
    }
    
    let invokeUpdate:()->Void = {
        if stateValue.with({ $0.updatedTimestamp != nil }) {
            updateState {
                $0.withUpdatedTimestamp(nil)
            }
            getController?()?.tableView.scroll(to: .up(true))
            updateBalance()
        }
    }
    
    let arguments = WalletInfoArguments(context: context, openReceive: {
        showModal(with: WalletReceiveController(context: context, tonContext: tonContext, address: stateValue.with { $0.address }), for: context.window)
    }, openSend: {
        showModal(with: WalletSendController(context: context, tonContext: tonContext, walletInfo: walletInfo, walletState: stateValue.with { $0 }.walletState, updateWallet: invokeUpdate), for: context.window)
    }, openTransaction: { transaction in
        showModal(with: WalletTransactionPreviewController(context: context, tonContext: tonContext, walletInfo: walletInfo, transaction: transaction, walletState: stateValue.with { $0 }.walletState, updateWallet: invokeUpdate), for: context.window)
    }, update: invokeUpdate)
    
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map {
        return walletInfoEntries($0, arguments: arguments)
    } |> map {
        return InputDataSignalValue(entries: $0, animated: true)
    }
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.walletBalanceInfoTitle, hasDone: false, identifier: "wallet-info")
    
    controller.afterDisappear = {
        transactionListDisposable.dispose()
        updateBalanceDisposable.dispose()
    }
    
    
    
    controller.didLoaded = { [weak controller] _ in
        controller?.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                loadTransactions(stateValue.with { $0.transactions.last?.transactionId })
            default:
                break
            }
        }
        loadTransactions(nil)
        controller?.tableView.set(stickClass: WalletTransactionDateStickItem.self, handler: { item in

        })
    }
    
    controller.customRightButton = { controller in
        let rightView = ImageBarView(controller: controller, theme.icons.wallet_settings)
        
        rightView.button.set(handler: { _ in
            showModal(with: WalletSettingsController(context: context, tonContext: tonContext, walletInfo: walletInfo), for: context.window)
        }, for: .Click)
        
        return rightView
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    updateBalance()
    
    return controller
}
