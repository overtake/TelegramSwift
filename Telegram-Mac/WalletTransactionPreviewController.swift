//
//  WalletTransactionPreviewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import TGUIKit
import WalletCore

private final class WalletTransactionPreviewArguments {
    let context: AccountContext
    let copy:(String)->Void
    let sendGrams:(String)->Void
    init(context: AccountContext, copy: @escaping(String)->Void, sendGrams: @escaping(String)->Void) {
        self.context = context
        self.copy = copy
        self.sendGrams = sendGrams
    }
}

private struct WalletTransactionPreviewState : Equatable {
    let transaction: WalletInfoTransaction
    init(transaction: WalletInfoTransaction) {
        self.transaction = transaction
    }
}
private let _id_value = InputDataIdentifier("_id_value")
private let _id_comment = InputDataIdentifier("_id_comment")
private let _id_address = InputDataIdentifier("_id_address")
private let _id_fee_other = InputDataIdentifier("_id_fee_other")
private let _id_fee_storage = InputDataIdentifier("_id_fee_storage")


private let _id_copy = InputDataIdentifier("_id_copy")
private let _id_send = InputDataIdentifier("_id_send")



private var dayFormatterRelative: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: appAppearance.language.languageCode)
    // dateFormatter.timeZone = TimeZone(abbreviation: "UTC")!
    
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    dateFormatter.doesRelativeDateFormatting = true
    return dateFormatter
}

private func formatDay(_ date: Date) -> String {
     return dayFormatterRelative.string(from: date)
}

enum WalletTransactionAddress {
    case list([String])
    case none
    case unknown
}


func stringForAddress(address: WalletTransactionAddress) -> String {
    switch address {
    case let .list(addresses):
        return addresses.map { formatAddress($0) }.joined(separator: "\n\n")
    case .none:
        return L10n.walletTransactionEmptyAddress
    case .unknown:
        return "<unknown>"
    }
}

func extractAddress(_ walletTransaction: WalletInfoTransaction) -> WalletTransactionAddress {
    switch walletTransaction {
    case let .completed(walletTransaction):
        let transferredValue = walletTransaction.transferredValueWithoutFees
        if transferredValue <= 0 {
            if walletTransaction.outMessages.isEmpty {
                return .none
            } else {
                var addresses: [String] = []
                for message in walletTransaction.outMessages {
                    addresses.append(message.destination)
                }
                return .list(addresses)
            }
        } else {
            if let inMessage = walletTransaction.inMessage {
                return .list([inMessage.source])
            } else {
                return .unknown
            }
        }
        return .none
    case let .pending(pending):
        return .list([pending.address])
    }
}

func extractDescription(_ walletTransaction: WalletInfoTransaction) -> String {
    switch walletTransaction {
    case let .completed(walletTransaction):
        let transferredValue = walletTransaction.transferredValueWithoutFees
        var text = ""
        if transferredValue <= 0 {
            for message in walletTransaction.outMessages {
                if !text.isEmpty {
                    text.append("\n\n")
                }
                text.append(message.textMessage)
            }
        } else {
            if let inMessage = walletTransaction.inMessage {
                text = inMessage.textMessage
            }
        }
        return text
    case let .pending(pending):
        return String(data: pending.comment, encoding: .utf8) ?? ""
    }
}




private func WalletTransactionPreviewEntries(state: WalletTransactionPreviewState, arguments: WalletTransactionPreviewArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    
    let title: String
    let transferredValue: Int64
    switch state.transaction {
    case let .completed(transaction):
        transferredValue = transaction.transferredValueWithoutFees
    case let .pending(transaction):
        transferredValue = -transaction.value
    }
    let address = stringForAddress(address: extractAddress(state.transaction))
    let comment = extractDescription(state.transaction)
    
    
    var color: NSColor
    let headerText: String
    if transferredValue <= 0 {
        title = "\(formatBalanceText(abs(transferredValue)))"
        headerText = L10n.walletTransactionPreviewRecipient
        color = theme.colors.redUI
    } else {
        headerText = L10n.walletTransactionPreviewSender
        color = theme.colors.greenUI
        title = "\(formatBalanceText(transferredValue))"
    }
    
    
    let timestamp: Int64
    switch state.transaction {
    case let .completed(transaction):
        timestamp = transaction.timestamp
    case let .pending(transaction):
        timestamp = transaction.timestamp
    }

    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_value, equatable: InputDataEquatable(state.transaction), item: { initialSize, stableId in
        var subText: String = ""
        if case let .completed(transaction) = state.transaction {
            if transaction.otherFee != 0 {
                subText += L10n.walletTransactionPreviewTransactionFee("-\(formatBalanceText(transaction.otherFee))")
            }
            if transaction.storageFee != 0 {
                if !subText.isEmpty {
                    subText += "\n"
                }
                subText += L10n.walletTransactionPreviewStorageFee("-\(formatBalanceText(transaction.storageFee))")
            }
        }
        return WalletTransactionTextItem(initialSize, stableId: stableId, context: arguments.context, value: title, subText: subText, color: color, viewType: .modern(position: .single, insets: NSEdgeInsets(left: 12, right: 12, top: 30, bottom: 20)))
    }))
    index += 1
    
   
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(headerText), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_address, equatable: InputDataEquatable(state.transaction), item: { initialSize, stableId in
        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .firstItem, text: address, font: .blockchain(.text))
    }))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .string(address), error: nil, identifier: _id_copy, data: InputDataGeneralData(name: L10n.walletTransactionPreviewCopyAddress, color: theme.colors.accent, viewType: .innerItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .string(address), error: nil, identifier: _id_send, data: InputDataGeneralData(name: L10n.walletTransactionPreviewSendGrams, color: theme.colors.accent, viewType: .lastItem)))
    index += 1
    

    
    if !comment.isEmpty {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletTransactionPreviewCommentHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_comment, equatable: InputDataEquatable(state.transaction), item: { initialSize, stableId in
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: comment, font: .normal(.text))
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}
@available(OSX 10.12, *)
func WalletTransactionPreviewController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, transaction: WalletInfoTransaction, walletState: WalletState? = nil, updateWallet:(()->Void)? = nil) -> InputDataModalController {
    let initialState = WalletTransactionPreviewState(transaction: transaction)
    let state: ValuePromise<WalletTransactionPreviewState> = ValuePromise(initialState)
    let stateValue: Atomic<WalletTransactionPreviewState> = Atomic(value: initialState)
    
    let updateState:((WalletTransactionPreviewState)->WalletTransactionPreviewState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    var getController:(()->InputDataController?)? = nil
    
    let arguments = WalletTransactionPreviewArguments(context: context, copy: { address in
        copyToClipboard(address)
        getController?()?.show(toaster: ControllerToaster(text: L10n.shareLinkCopied))

    }, sendGrams: { address in
        showModal(with: WalletSendController(context: context, tonContext: tonContext, walletInfo: walletInfo, walletState: walletState, recipient: address, updateWallet: updateWallet), for: context.window)
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return WalletTransactionPreviewEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    var getModalController:(()->InputDataModalController?)? = nil
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.walletTransactionPreviewTitle, hasDone: false)
    
    controller.validateData = { data in
        if let address = data[_id_copy]?.stringValue {
            arguments.copy(address.replacingOccurrences(of: "\n", with: ""))
        } else if let address = data[_id_send]?.stringValue {
            arguments.sendGrams(address.replacingOccurrences(of: "\n", with: ""))
        }
        return .none
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.wallet_close, handler: {
        getModalController?()?.close()
    })
    
    let date = formatDay(Date(timeIntervalSince1970: TimeInterval(transaction.timestamp) - arguments.context.timeDifference))
    controller.centerModalHeader = ModalHeaderData(title: L10n.walletTransactionPreviewTitle, subtitle: date)
    
    getController = { [weak controller] in
        return controller
    }
    
    let modalController = InputDataModalController(controller, closeHandler: { f in
        f()
    }, size: NSMakeSize(350, 350))
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    
    return modalController
}
