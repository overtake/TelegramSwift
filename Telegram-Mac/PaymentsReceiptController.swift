//
//  PaymentsReceiptController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import CurrencyFormat

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var invoice: TelegramMediaInvoice
    var botPeer: PeerEquatable?
    var receipt: BotPaymentReceipt?
}

private let _id_loading = InputDataIdentifier("_id_loading")
private let _id_preview = InputDataIdentifier("_id_preview")

private let _id_checkout_payment_method = InputDataIdentifier("_id_checkout_payment_method")
private let _id_checkout_shipping_info = InputDataIdentifier("_id_checkout_shipping_info")
private let _id_checkout_name = InputDataIdentifier("_id_checkout_name")
private let _id_checkout_flex_shipping = InputDataIdentifier("_id_checkout_flex_shipping")
private let _id_checkout_phone_number = InputDataIdentifier("_id_checkout_phone_number")
private let _id_checkout_email = InputDataIdentifier("_id_checkout_email")


private func _id_checkout_price(_ label: String, index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_checkout_price_\(label)_\(index)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: InputDataEquatable(state.botPeer), comparable: nil, item: { initialSize, stableId in
        return PaymentsCheckoutPreviewRowItem(initialSize, stableId: stableId, context: arguments.context, invoice: state.invoice, botPeer: state.botPeer?.peer, viewType: .singleItem)
    }))

    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    if let receipt = state.receipt {
        
        let insets = NSEdgeInsets(top: 7, left: 16, bottom: 7, right: 16)
        let first = NSEdgeInsets(top: 14, left: 16, bottom: 7, right: 16)
        let last = NSEdgeInsets(top: 7, left: 16, bottom: 14, right: 16)

        struct Tuple: Equatable {
            let label: String
            let price: String
            let viewType: GeneralViewType
        }
        
        var prices = receipt.invoice.prices
        if let shippingOption = receipt.shippingOption {
            prices += shippingOption.prices
        }
        
        if let tipAmount = receipt.tipAmount {
            prices.append(.init(label: strings().paymentsReceiptTip, amount: tipAmount))
        }
        
        for (i, price) in prices.enumerated() {
            var viewType = bestGeneralViewType(prices, for: i)
            
            if i == 0 {
                viewType = viewType.withUpdatedInsets(first)
            } else {
                viewType = viewType.withUpdatedInsets(insets)
            }
            if price == prices.last {
                if prices.count > 1 {
                    viewType = GeneralViewType.innerItem.withUpdatedInsets(insets)
                } else {
                    viewType = GeneralViewType.firstItem.withUpdatedInsets(insets)
                }
            }
            let tuple = Tuple(label:price.label, price: formatCurrencyAmount(price.amount, currency: receipt.invoice.currency), viewType: viewType)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_price(price.label, index: i), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return PaymentsCheckoutPriceItem(initialSize, stableId: stableId, title: tuple.label, price: tuple.price, font: .normal(.text), color: theme.colors.grayText, viewType: tuple.viewType)
            }))
            index += 1
        }
        
        if !prices.isEmpty {
            let viewType = GeneralViewType.lastItem.withUpdatedInsets(last)

            let tuple = Tuple(label: strings().checkoutTotalAmount, price: formatCurrencyAmount(prices.reduce(0, { $0 + $1.amount}), currency: receipt.invoice.currency), viewType: viewType)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_price(strings().checkoutTotalAmount, index: .max), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return PaymentsCheckoutPriceItem(initialSize, stableId: stableId, title: tuple.label, price: tuple.price, font: .medium(.text), color: theme.colors.text, viewType: tuple.viewType)
            }))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1

        }
        
        var fields = receipt.invoice.requestedFields.intersection([.shippingAddress, .email, .name, .phone])
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_payment_method, data: .init(name: strings().checkoutPaymentMethod, color: theme.colors.text, type: .context(receipt.credentialsTitle), viewType: fields.isEmpty ? .singleItem : .firstItem, enabled: false)))
        index += 1
        
        
        
        var updated = fields.subtracting(.shippingAddress)
        if updated != fields {
            fields = updated
            var addressString = ""
            if let address = receipt.info?.shippingAddress {
                let components: [String] = [
                    address.city,
                    address.streetLine1,
                    address.streetLine2,
                    address.state
                ]
                for component in components {
                    if !component.isEmpty {
                        if !addressString.isEmpty {
                            addressString.append(", ")
                        }
                        addressString.append(component)
                    }
                }
            }
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_shipping_info, data: .init(name: strings().checkoutShippingAddress, color: theme.colors.text, type: .context(addressString), viewType: fields.isEmpty && receipt.shippingOption == nil ? .lastItem : .innerItem, enabled: false)))
            index += 1
        }
        
        if let _ = receipt.shippingOption {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_flex_shipping, data: .init(name: strings().checkoutShippingMethod, color: theme.colors.text, type: .context(receipt.shippingOption?.title ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, enabled: false)))
            index += 1
        }
        
        updated = fields.subtracting(.name)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_name, data: .init(name: strings().checkoutName, color: theme.colors.text, type: .context(receipt.info?.name ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, enabled: false)))
            index += 1
        }
        
        updated = fields.subtracting(.email)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_email, data: .init(name: strings().checkoutEmail, color: theme.colors.text, type: .context(receipt.info?.email ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, enabled: false)))
            index += 1
        }
        
        updated = fields.subtracting(.phone)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_phone_number, data: .init(name: strings().checkoutPhone, color: theme.colors.text, type: .nextContext(formatPhoneNumber(receipt.info?.phone ?? "")), viewType: fields.isEmpty ? .lastItem : .innerItem, enabled: false)))
            index += 1
        }
        
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .singleItem)
        }))
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

func PaymentsReceiptController(context: AccountContext, messageId: MessageId, invoice: TelegramMediaInvoice) -> InputDataModalController {

    var close:(()->Void)? = nil
    let actionsDisposable = DisposableSet()

    let initialState = State(invoice: invoice)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title:strings().checkoutReceiptTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        close?()
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    
    //BotPaymentReceipt, RequestBotPaymentReceiptError
    let receiptPromise: Promise<BotPaymentReceipt> = Promise()
    receiptPromise.set(context.engine.payments.requestBotPaymentReceipt(messageId: messageId) |> `catch` { _ in return .complete() })
    
    
    let botPeer = receiptPromise.get() |> mapToSignal { value in
        return context.account.postbox.transaction { $0.getPeer(value.botPaymentId) }
    }
    
    actionsDisposable.add(combineLatest(receiptPromise.get(), botPeer).start(next: { receipt, botPeer in
        updateState { current in
            var current = current
            current.receipt = receipt
            current.botPeer = botPeer != nil ? PeerEquatable(botPeer!) : nil
            return current
        }
    }))
    

    
    return modalController
}




