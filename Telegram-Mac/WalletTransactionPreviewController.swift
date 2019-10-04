//
//  WalletTransactionPreviewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit


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
    let transaction: WalletTransaction
    init(transaction: WalletTransaction) {
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

private func WalletTransactionPreviewEntries(state: WalletTransactionPreviewState, arguments: WalletTransactionPreviewArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    
    let title: String
    var address: String = ""
    var comment: String = ""
    let transferredValue = state.transaction.transferredValueWithoutFees
    
    var color: NSColor = theme.colors.redUI
    let headerText: String
    if transferredValue <= 0 {
        title = "-    \(formatBalanceText(abs(transferredValue)))"
        headerText = L10n.walletTransactionPreviewRecipient
        if state.transaction.outMessages.isEmpty {
            comment = ""
            address = ""
        } else {
            for message in state.transaction.outMessages {
                if !comment.isEmpty {
                    comment.append("\n")
                }
                comment.append(message.textMessage)
                
                if !address.isEmpty {
                    address.append("\n")
                }
                address.append(message.destination)
            }
        }
        
    } else {
        headerText = L10n.walletTransactionPreviewSender
        color = theme.colors.greenUI
        title = "+    \(formatBalanceText(transferredValue))"
        if let inMessage = state.transaction.inMessage {
            comment = inMessage.textMessage
            address = inMessage.source
        }
    }
    
    if address.count % 2 == 0 {
        address = String(address.prefix(address.count / 2) + "\n" + address.suffix(address.count / 2))
    }
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_value, equatable: InputDataEquatable(state.transaction), item: { initialSize, stableId in
        let date = formatDay(Date(timeIntervalSince1970: TimeInterval(state.transaction.timestamp)))
        return WalletTransactionTextItem(initialSize, stableId: stableId, context: arguments.context, value: title, subText: date, color: color, viewType: .modern(position: .single, insets: NSEdgeInsets(left: 12, right: 12, top: 30, bottom: 20)))
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
    
    

    
    if state.transaction.otherFee != 0 || state.transaction.storageFee != 0 {
        if state.transaction.otherFee != 0 {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            let text = L10n.walletTransactionPreviewTransactionFee
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(text), data: InputDataGeneralTextData(viewType: .textTopItem)))
            index += 1
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_fee_other, equatable: InputDataEquatable(state.transaction), item: { initialSize, stableId in
                return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: "-\(formatBalanceText(state.transaction.otherFee))", font: .normal(.text))
            }))
            index += 1
        }
        if state.transaction.storageFee != 0 {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            let text = L10n.walletTransactionPreviewStorageFee
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(text), data: InputDataGeneralTextData(viewType: .textTopItem)))
            index += 1
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_fee_storage, equatable: InputDataEquatable(state.transaction), item: { initialSize, stableId in
                return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: "-\(formatBalanceText(state.transaction.storageFee))", font: .normal(.text))
            }))
            index += 1
        }
        
//        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(descText, linkHandler: { link in
//            openFaq(context: arguments.context, dest: .ton)
//        }), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    }
    
    
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
func WalletTransactionPreviewController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, transaction: WalletTransaction, walletState: WalletState? = nil, updateWallet:(()->Void)? = nil) -> InputDataModalController {
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
    
    controller.rightModalHeader = ModalHeaderData(image: theme.icons.wallet_close, handler: {
        getModalController?()?.close()
    })
    
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
