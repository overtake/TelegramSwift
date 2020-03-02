////
////  WalletCreateInvoiceController.swift
////  Telegram
////
////  Created by Mikhail Filimonov on 08/10/2019.
////  Copyright © 2019 Telegram. All rights reserved.
////
//
//import Cocoa
//import TGUIKit
//import SwiftSignalKit
//import TelegramCore
//import SyncCore
//import WalletCore
//private final class WalletInvoiceArguments {
//    let context: AccountContext
//    let copy:()->Void
//    let share:()->Void
//    init(context: AccountContext, copy: @escaping()->Void, share: @escaping()->Void) {
//        self.context = context
//        self.copy = copy
//        self.share = share
//    }
//}
//
//private func url(for state: WalletInvoiceState, address: String) -> String {
//    var url = "ton://transfer/\(escape(with: address, addPercent: true))"
//    let amount = amountValue(state.amount)
//    let comment = state.comment
//    if !comment.isEmpty || amount > 0 {
//        url += "?"
//    }
//    if amount > 0 {
//        url += "amount=\(amount)"
//    }
//    if !comment.isEmpty {
//        if amount > 0 {
//            url += "&"
//        }
//        url += "text=\(comment)"
//    }
//    return url
//}
//
//private struct WalletInvoiceState : Equatable {
//    let amount: String
//    let comment: String
//    init(amount: String, comment: String) {
//        self.amount = amount
//        self.comment = comment
//    }
//    func withUpdatedAmount(_ amount: String) -> WalletInvoiceState {
//        return WalletInvoiceState(amount: amount, comment: self.comment)
//    }
//    func withUpdatedComment(_ comment: String) -> WalletInvoiceState {
//        return WalletInvoiceState(amount: self.amount, comment: comment)
//    }
//}
//private let _id_amount = InputDataIdentifier("_id_amount")
//private let _id_comment = InputDataIdentifier("_id_comment")
//private let _id_copy = InputDataIdentifier("_id_copy")
//private let _id_share = InputDataIdentifier("_id_share")
//private let _id_invoice_url = InputDataIdentifier("_id_invoice_url")
//private func walletInvoiceEntries(state: WalletInvoiceState, address: String, arguments: WalletInvoiceArguments) -> [InputDataEntry] {
//    var entries:[InputDataEntry] = []
//    
//    var sectionId:Int32 = 0
//    var index:Int32 = 0
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
//    
//    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletCreateInvoiceAmoutTitle), data: InputDataGeneralTextData(viewType: .textTopItem)))
//    index += 1
//    
//    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.amount), error: nil, identifier: _id_amount, mode: .plain, data: .init(viewType: .firstItem, rightItem: nil, defaultText: nil, pasteFilter: { value in
//        if isValidAmount(value) {
//            return (true, value)
//        }
//        return (false, value)
//    }), placeholder: nil, inputPlaceholder: L10n.walletCreateInvoiceAmoutPlaceholder, filter: { value in
//        
//        let set = CharacterSet(charactersIn: "0987654321.,\(Formatter.withSeparator.decimalSeparator!)")
//        let value = value.trimmingCharacters(in: set.inverted)
//        
//        if !isValidAmount(value) {
//            return state.amount
//        }
//        return value
//        
//    }, limit: 40))
//    index += 1
//    
//    
//    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.comment), error: nil, identifier: _id_comment, mode: .plain, data: InputDataRowData(viewType: .lastItem), placeholder: nil, inputPlaceholder: L10n.walletCreateInvoiceCommentPlaceholder, filter: { current in
//        if let data = current.data(using: .utf8) {
//            let ncut = data.suffix(500)
//            return String(data: ncut, encoding: .utf8)!
//        } else {
//            return current
//        }
//    }, limit: 500))
//    index += 1
//
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
//    
//    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletCreateInvoiceInvoiceTitle), data: InputDataGeneralTextData(viewType: .textTopItem)))
//    index += 1
//    
//    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_invoice_url, equatable: InputDataEquatable(state), item: { initialSize, stableId in
//        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .firstItem, text: url(for: state, address: address), font: .normal(.text))
//    }))
//    index += 1
//    
//    
//    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_copy, data: InputDataGeneralData(name: L10n.walletCreateInvoiceCopyURL, color: theme.colors.accent, viewType: .innerItem, action: arguments.copy)))
//    index += 1
//    
//    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_share, data: InputDataGeneralData(name: L10n.walletCreateInvoiceShareURL, color: theme.colors.accent, viewType: .lastItem, action: arguments.share)))
//    index += 1
//    
//    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletCreateInvoiceShareDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
//    index += 1
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
//    
//    return entries
//}
//
//func WalletInvoiceController(context: AccountContext, tonContext: TonContext, address: String) -> InputDataModalController {
//    let initialState = WalletInvoiceState(amount: "", comment: "")
//    let state: ValuePromise<WalletInvoiceState> = ValuePromise(initialState)
//    let stateValue: Atomic<WalletInvoiceState> = Atomic(value: initialState)
//    
//    let updateState:((WalletInvoiceState)->WalletInvoiceState) -> Void = { f in
//        state.set(stateValue.modify(f))
//    }
//    
//    var getController:(()->InputDataController?)? = nil
//    
//    let arguments = WalletInvoiceArguments(context: context, copy: {
//        copyToClipboard(url(for: stateValue.with { $0 }, address: address))
//        getController?()?.show(toaster: ControllerToaster(text: L10n.shareLinkCopied))
//    }, share: {
//        let urlValue = url(for: stateValue.with { $0 }, address: address)
//        showModal(with: ShareModalController(ShareLinkObject(context, link: urlValue)), for: context.window)
//    })
//    
//    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
//        return walletInvoiceEntries(state: state, address: address, arguments: arguments)
//    } |> map { entries in
//        return InputDataSignalValue(entries: entries)
//    }
//    
//    var getModalController:(()->InputDataModalController?)? = nil
//    
//    
//    let controller = InputDataController(dataSignal: dataSignal, title: L10n.walletCreateInvoiceTitle)
//    
//    
//    controller.updateDatas = { data in
//        updateState {
//            $0.withUpdatedAmount(formatAmountText(data[_id_amount]?.stringValue ?? ""))
//            .withUpdatedComment(data[_id_comment]?.stringValue ?? "")
//        }
//        return .none
//    }
//    
//    controller.leftModalHeader = ModalHeaderData(image: theme.icons.wallet_close, handler: {
//        getModalController?()?.close()
//    })
//    
//    getController = { [weak controller] in
//        return controller
//    }
//    
//    let modalController = InputDataModalController(controller, closeHandler: { f in
//        f()
//    }, size: NSMakeSize(350, 350))
//    
//    getModalController = { [weak modalController] in
//        return modalController
//    }
//    
//    return modalController
//}
