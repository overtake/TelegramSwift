////
////  WalletInfoController.swift
////  Telegram
////
////  Created by Mikhail Filimonov on 19/09/2019.
////  Copyright © 2019 Telegram. All rights reserved.
////
//
//import Cocoa
//import TelegramCore
//import SyncCore
//import SwiftSignalKit
//import TGUIKit
//import WalletCore
//
//enum WalletInfoTransaction: Equatable {
//    case completed(WalletTransaction)
//    case pending(PendingWalletTransaction)
//    
//    var timestamp: Int64 {
//        switch self {
//        case let .completed(transaction):
//            return transaction.timestamp
//        case let .pending(transaction):
//            return transaction.timestamp
//        }
//    }
//    
//    var transactionId: Int64 {
//        switch self {
//        case let .completed(transaction):
//            return transaction.transactionId.lt
//        case let .pending(transaction):
//            return transaction.timestamp
//        }
//    }
//}
//
//
//private final class WalletInfoArguments {
//    let context: AccountContext
//    let openReceive:()->Void
//    let openSend:()->Void
//    let openTransaction:(WalletInfoTransaction)->Void
//    let update:()->Void
//    init(context: AccountContext, openReceive: @escaping()->Void, openSend: @escaping()->Void, openTransaction: @escaping(WalletInfoTransaction)->Void, update:@escaping()->Void) {
//        self.context = context
//        self.openReceive = openReceive
//        self.openSend = openSend
//        self.openTransaction = openTransaction
//        self.update = update
//    }
//}
//
//private struct WalletInfoState : Equatable {
//    let walletState: WalletState?
//    let updatedTimestamp: Int64?
//    let previousTimestamp: Int64?
//    let address: String
//    let syncProgress: Float
//    let isSynced: Bool
//    let transactions:[WalletInfoTransaction]
//    init(walletState: WalletState?, updatedTimestamp: Int64?, previousTimestamp: Int64?, address: String, syncProgress: Float, isSynced: Bool, transactions:[WalletInfoTransaction]) {
//        self.walletState = walletState
//        self.address = address
//        self.isSynced = isSynced
//        self.syncProgress = syncProgress
//        self.updatedTimestamp = updatedTimestamp
//        self.previousTimestamp = previousTimestamp
//        self.transactions = transactions.sorted(by: { $0.timestamp > $1.timestamp })
//    }
//    
//    func withUpdatedWalletState(_ walletState: WalletState?) -> WalletInfoState {
//        return WalletInfoState(walletState: walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, syncProgress: self.syncProgress, isSynced: self.isSynced, transactions: self.transactions)
//    }
//    func withUpdatedAddress(_ address: String) -> WalletInfoState {
//        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: address, syncProgress: self.syncProgress, isSynced: self.isSynced, transactions: self.transactions)
//    }
//    
//    func withUpdatedTimestamp(_ updatedTimestamp: Int64?) -> WalletInfoState {
//        return WalletInfoState(walletState: self.walletState, updatedTimestamp: updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, syncProgress: self.syncProgress, isSynced: self.isSynced, transactions: self.transactions)
//    }
//    func withUpdatedSyncProgress(_ syncProgress: Float) -> WalletInfoState {
//        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, syncProgress: syncProgress, isSynced: self.isSynced, transactions: self.transactions)
//    }
//    func withUpdatedSynced(_ isSynced: Bool) -> WalletInfoState {
//        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, syncProgress: self.syncProgress, isSynced: isSynced, transactions: self.transactions)
//    }
//    func withUpdatedPreviousTimestamp(_ previousTimestamp: Int64?) -> WalletInfoState {
//        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: previousTimestamp, address: self.address, syncProgress: self.syncProgress, isSynced: self.isSynced, transactions: self.transactions)
//    }
//    func withUpdatedTransactions(_ transactions: [WalletInfoTransaction]) -> WalletInfoState {
//        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, syncProgress: self.syncProgress, isSynced: self.isSynced, transactions: transactions)
//    }
//    
//    func withAddedTransactions(_ transactions: [WalletInfoTransaction]) -> WalletInfoState {
//        var updated = self.transactions
//        var exists:Set<WalletTransactionId> = Set()
//        for transaction in updated {
//            switch transaction {
//            case let .completed(transaction):
//                exists.insert(transaction.transactionId)
//            case .pending:
//                break
//            }
//        }
//        for transaction in transactions {
//            switch transaction {
//            case let .completed(transaction):
//                if !exists.contains(transaction.transactionId) {
//                    updated.append(.completed(transaction))
//                }
//            case .pending:
//                break
//            }
//        }
//        return WalletInfoState(walletState: self.walletState, updatedTimestamp: self.updatedTimestamp, previousTimestamp: self.previousTimestamp, address: self.address, syncProgress: self.syncProgress, isSynced: self.isSynced, transactions: updated)
//    }
//}
//
//private let _id_balance = InputDataIdentifier("_id_balance")
//private let _id_created_address = InputDataIdentifier("_id_created_address")
//private func _id_transaction(_ id: Int64) -> InputDataIdentifier {
//    return InputDataIdentifier("_id_transaction_\(id)")
//}
//private func _id_date(_ id:Int32) -> InputDataIdentifier {
//    return InputDataIdentifier("_id_data_\(id)")
//}
//private func walletInfoEntries(_ state: WalletInfoState, arguments: WalletInfoArguments) -> [InputDataEntry] {
//    var entries:[InputDataEntry] = []
//    
//    var sectionId: Int32 = 0
//    var index:Int32 = 0
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
//    
//    if let _ = state.walletState {
//        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_balance, equatable: InputDataEquatable(state), item: { initialSize, stableId in
//            return WalletBalanceItem(initialSize, stableId: stableId, context: arguments.context, state: state.walletState, updatedTimestamp: state.updatedTimestamp, syncProgress: state.syncProgress, viewType: .singleItem, receiveMoney: arguments.openReceive, sendMoney: arguments.openSend, update: arguments.update)
//        }))
//        index += 1
// 
//        
//        if state.transactions.isEmpty  {
//            
//            if state.walletState?.balance == -1 {
//                entries.append(.sectionId(sectionId, type: .normal))
//                sectionId += 1
//                
//                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_created_address, equatable: InputDataEquatable(state), item: { initialSize, stableId in
//                    return WalletInfoCreatedItem(initialSize, stableId: stableId, context: arguments.context, address: state.address, viewType: .singleItem)
//                }))
//                index += 1
//            }
//           
//        } else {
//            
//            enum TransactionItem : Equatable {
//                case transaction(WalletInfoTransaction)
//                case date(Int32)
//            }
//            
//            var items: [TransactionItem] = []
//            
//            
//            for (i, transaction) in state.transactions.enumerated() {
//                let prev: WalletInfoTransaction? = i == 0 ? nil : state.transactions[i - 1]
//                let next: WalletInfoTransaction? = i == state.transactions.count - 1 ? nil : state.transactions[i + 1]
//                if prev == nil {
//                    let dateId = chatDateId(for: Int32(transaction.timestamp))
//                    items.append(.date(Int32(dateId)))
//                }
//                
//                items.append(.transaction(transaction))
//                
//                if let next = next {
//                    let dateId = chatDateId(for: Int32(transaction.timestamp))
//                    let nextDateId = chatDateId(for: Int32(next.timestamp))
//                    
//                    if dateId != nextDateId {
//                        items.append(.date(Int32(nextDateId)))
//                    }
//                }
//            }
//            
//            
//            var groupItems:[(TransactionItem, [TransactionItem])] = []
//            var current:[TransactionItem] = []
//            for item in items.reversed() {
//                switch item {
//                case .date:
//                    if !current.isEmpty {
//                        groupItems.append((item, current))
//                        current.removeAll()
//                    }
//                case .transaction:
//                    current.insert(item, at: 0)
//                }
//            }
//
//            for group in groupItems.reversed() {
//                switch group.0 {
//                case let .date(timestamp):
//                    entries.append(.sectionId(sectionId, type: .normal))
//                    sectionId += 1
//                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_date(timestamp), equatable: InputDataEquatable(timestamp), item: { initialSize, stableId in
//                        return WalletTransactionDateStickItem(initialSize, timestamp: timestamp, viewType: .firstItem)
//                    }))
//                    
//                    for item in group.1 {
//                        switch item {
//                        case let .transaction(transaction):
//                            struct E : Equatable {
//                                let transaction: WalletInfoTransaction
//                                let viewType: GeneralViewType
//                            }
//                            
//                            let value = E(transaction: transaction, viewType: bestGeneralViewType(group.1, for: item))
//                            
//                            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction(transaction.transactionId), equatable: InputDataEquatable(value), item: { initialSize, stableId in
//                                return WalletInfoTransactionItem(initialSize, stableId: stableId, context: arguments.context, transaction: value.transaction, viewType: value.viewType, action: {
//                                    arguments.openTransaction(transaction)
//                                })
//                            }))
//                            index += 1
//                        default:
//                            break
//                        }
//                        
//                    }
//                    
//                default:
//                    break
//                }
//            }
//        }
//    }
//    
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
//    
//    return entries
//}
//@available(OSX 10.12, *)
//func WalletInfoController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo) -> InputDataController {
//    
//    let initialState = WalletInfoState(walletState: nil, updatedTimestamp: nil, previousTimestamp: nil, address: "", syncProgress: 0, isSynced: true, transactions: [])
//    let state: ValuePromise<WalletInfoState> = ValuePromise()
//    let stateValue: Atomic<WalletInfoState> = Atomic(value: initialState)
//    
//    let updateState:((WalletInfoState)->WalletInfoState) -> Void = { f in
//        state.set(stateValue.modify(f))
//    }
//    
//    let syncDisposable = MetaDisposable()
//    
//    var getController:(()->InputDataController?)? = nil
//
//
//    let updateBalanceDisposable = MetaDisposable()
//    let updateBalance:()->Void = {
//        
//        
//        
//        let signal = combineLatest(queue: .mainQueue(), getCombinedWalletState(storage: tonContext.storage, subject: .wallet(walletInfo), tonInstance: tonContext.instance), walletAddress(publicKey: walletInfo.publicKey, tonInstance: tonContext.instance) |> mapError { _ in return .generic }, TONKeychain.hasKeys(for: context.account) |> castError(GetCombinedWalletStateError.self))
//        
//        let short = signal |> then(signal |> delay(3.3, queue: .mainQueue()) |> restart)
//        
//        updateBalanceDisposable.set(short.start(next: { state, address, hasKeys in
//            var combinedState: CombinedWalletState?
//            switch state {
//            case let .cached(state):
//                combinedState = state
//            case let .updated(state):
//                combinedState = state
//            }
//            
//            if let combinedState = combinedState {
//                var transactions:[WalletInfoTransaction] = []
//                transactions.append(contentsOf: combinedState.topTransactions.map { .completed($0) })
//                transactions.append(contentsOf: combinedState.pendingTransactions.map { .pending($0) })
//                
//                var updatedTransactions: [WalletTransaction] = combinedState.topTransactions
//                
//                var existingIds = Set<WalletTransactionId>()
//                for transaction in updatedTransactions {
//                    existingIds.insert(transaction.transactionId)
//                }
//                let current = stateValue.with { $0.transactions }
//                
//                for transaction in current {
//                    switch transaction {
//                    case let .completed(transaction):
//                        if !existingIds.contains(transaction.transactionId) {
//                            existingIds.insert(transaction.transactionId)
//                            updatedTransactions.append(transaction)
//                        }
//                    case .pending:
//                        break
//                    }
//                }
//                let list:[WalletInfoTransaction] = combinedState.pendingTransactions.map { .pending($0) } + updatedTransactions.map { .completed($0) }
//                
//                
//                updateState {
//                    $0.withUpdatedTimestamp(combinedState.timestamp)
//                        .withUpdatedPreviousTimestamp(combinedState.timestamp)
//                        .withUpdatedWalletState(combinedState.walletState)
//                        .withUpdatedTransactions(list)
//                        .withUpdatedAddress(address)
//                }
//            } else {
//                updateState {
//                    $0.withUpdatedAddress(address)
//                }
//            }
//            if !hasKeys {
//                 context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .unavailable))
//            }
//            
//        }, error: { error in
//            if stateValue.with({$0.updatedTimestamp == nil}) {
//                getController?()?.show(toaster: ControllerToaster(text: L10n.walletBalanceInfoRetrieveError))
//            }
//            updateState {
//                $0.withUpdatedTimestamp($0.previousTimestamp)
//            }
//        }))
//    }
//    
//    syncDisposable.set(tonContext.instance.syncProgress.start(next: { value in
//        updateState {
//            $0.withUpdatedSyncProgress(value)
//        }
//    }))
//    
//    let transactionListDisposable = MetaDisposable()
//    
//    var loadMoreTransactions: Bool = true
//    
//    let loadTransactions:(WalletTransactionId?)->Void = { transactionId in
//        if !loadMoreTransactions {
//            return
//        }
//        loadMoreTransactions = false
//        let signal = getWalletTransactions(address: stateValue.with { $0.address }, previousId: transactionId, tonInstance: tonContext.instance) |> deliverOnMainQueue
//        transactionListDisposable.set(signal.start(next: { list in
//            loadMoreTransactions = true
//            updateState {
//                $0.withAddedTransactions(list.map { .completed($0) })
//            }
//        }, error: { error in
//          
//        }))
//    }
//    
//    let invokeUpdate:()->Void = {
//        if stateValue.with({ $0.updatedTimestamp != nil }) {
//            updateState {
//                $0.withUpdatedTimestamp(nil)
//            }
//            getController?()?.tableView.scroll(to: .up(true))
//            updateBalance()
//        }
//    }
//    
//    let arguments = WalletInfoArguments(context: context, openReceive: {
//        showModal(with: WalletReceiveController(context: context, tonContext: tonContext, address: stateValue.with { $0.address }), for: context.window)
//    }, openSend: {
//        showModal(with: WalletSendController(context: context, tonContext: tonContext, walletInfo: walletInfo, walletState: stateValue.with { $0 }.walletState, updateWallet: invokeUpdate), for: context.window)
//    }, openTransaction: { transaction in
//        showModal(with: WalletTransactionPreviewController(context: context, tonContext: tonContext, walletInfo: walletInfo, transaction: transaction, walletState: stateValue.with { $0 }.walletState, updateWallet: invokeUpdate), for: context.window)
//    }, update: invokeUpdate)
//    
//    
//    let dataSignal = state.get() |> deliverOnPrepareQueue |> map {
//        return walletInfoEntries($0, arguments: arguments)
//    } |> map {
//        return InputDataSignalValue(entries: $0, animated: true)
//    }
//    let controller = InputDataController(dataSignal: dataSignal, title: L10n.walletBalanceInfoTitle, hasDone: false, identifier: "wallet-info")
//    
//    controller.onDeinit = {
//        transactionListDisposable.dispose()
//        updateBalanceDisposable.dispose()
//        syncDisposable.dispose()
//    }
//    
//    
//    
//    controller.didLoaded = { controller, _ in
//        controller.tableView.setScrollHandler { position in
//            switch position.direction {
//            case .bottom:
//                let lastTransactionId: WalletTransactionId? = stateValue.with { state in
//                    if let last = state.transactions.last {
//                        switch last {
//                        case let .completed(transaction):
//                            return transaction.transactionId
//
//                        case .pending:
//                            break
//                        }
//                    }
//                    return nil
//                }
//                
//                loadTransactions(lastTransactionId)
//            default:
//                break
//            }
//        }
//        controller.tableView.set(stickClass: WalletTransactionDateStickItem.self, handler: { item in
//
//        })
//    }
//    
//    controller.customRightButton = { controller in
//        let rightView = ImageBarView(controller: controller, theme.icons.wallet_settings)
//        
//        rightView.button.set(handler: { _ in
//            showModal(with: WalletSettingsController(context: context, tonContext: tonContext, walletInfo: walletInfo), for: context.window)
//        }, for: .Click)
//        
//        return rightView
//    }
//    
//    getController = { [weak controller] in
//        return controller
//    }
//    
//    updateBalance()
//    
//    return controller
//}
