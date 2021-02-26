//
//  PaymentsCheckoutController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox

func parseRequestedPaymentMethod(paymentForm: BotPaymentForm?) -> (String, PaymentsPaymentMethodAdditionalFields)? {
    if let paymentForm = paymentForm, let nativeProvider = paymentForm.nativeProvider, nativeProvider.name == "stripe" {
                        
        guard let paramsData = nativeProvider.params.data(using: .utf8) else {
            return nil
        }
        guard let nativeParams = (try? JSONSerialization.jsonObject(with: paramsData)) as? [String: Any] else {
            return nil
        }
        guard let publishableKey = nativeParams["publishable_key"] as? String else {
            return nil
        }
        
        var additionalFields: PaymentsPaymentMethodAdditionalFields = []
        if let needCardholderName = nativeParams["need_cardholder_name"] as? NSNumber, needCardholderName.boolValue {
            additionalFields.insert(.cardholderName)
        }
        if let needCountry = nativeParams["need_country"] as? NSNumber, needCountry.boolValue {
            additionalFields.insert(.country)
        }
        if let needZip = nativeParams["need_zip"] as? NSNumber, needZip.boolValue {
            additionalFields.insert(.zipCode)
        }
        
        return (publishableKey, additionalFields)
    }
    return nil
}



private func currentTotalPrice(paymentForm: BotPaymentForm?, validatedFormInfo: BotPaymentValidatedFormInfo?, shippingOption: BotPaymentShippingOption?) -> Int64 {
    guard let paymentForm = paymentForm else {
        return 0
    }
    
    var totalPrice: Int64 = 0
    
    var index = 0
    for price in paymentForm.invoice.prices {
        totalPrice += price.amount
        index += 1
    }
    
    if let option = shippingOption {
        for price in option.prices {
            totalPrice += price.amount
        }
    }
    
    return totalPrice
}


struct BotCheckoutPaymentWebToken: Equatable {
    let title: String
    let data: String
    var saveOnServer: Bool
}

enum BotCheckoutPaymentMethod: Equatable {
    case savedCredentials(BotPaymentSavedCredentials)
    case webToken(BotCheckoutPaymentWebToken)
    case applePay
    
    var title: String {
        switch self {
            case let .savedCredentials(credentials):
                switch credentials {
                    case let .card(_, title):
                        return title
                }
            case let .webToken(token):
                return token.title
            case .applePay:
                return "Apple Pay"
        }
    }
}


private final class Arguments {
    let context: AccountContext
    let openForm:(PaymentsShippingInfoFocus?)->Void
    let openShippingMethod:()->Void
    let openPaymentMethod:()->Void
    let pay:()->Void
    init(context: AccountContext, openForm:@escaping(PaymentsShippingInfoFocus?)->Void, openShippingMethod:@escaping()->Void, openPaymentMethod:@escaping()->Void, pay:@escaping()->Void) {
        self.context = context
        self.openForm = openForm
        self.openShippingMethod = openShippingMethod
        self.openPaymentMethod = openPaymentMethod
        self.pay = pay
    }
}

enum PaymentViewMode {
    case receipt
    case invoice
}

private struct State : Equatable {
    let mode: PaymentViewMode
    var message: Message
    var form: BotPaymentForm?
    var validatedInfo: BotPaymentValidatedFormInfo?
    var savedInfo: BotPaymentRequestedInfo
    var shippingOptionId: BotPaymentShippingOption?
    var paymentMethod: BotCheckoutPaymentMethod?
    
    var unfilledInfo: PaymentsShippingInfoFocus? {
        if let form = form {
            if form.invoice.requestedFields.contains(.shippingAddress) {
                if savedInfo.shippingAddress == nil {
                    return .address
                }
            }
            if form.invoice.requestedFields.contains(.phone) {
                if savedInfo.phone == nil {
                    return .phone
                }
            }
            if form.invoice.requestedFields.contains(.email) {
                if savedInfo.email == nil {
                    return .email
                }
            }
            if form.invoice.requestedFields.contains(.name) {
                if savedInfo.name == nil {
                    return .name
                }
            }
        }
        return nil
    }
}

private let _id_checkout_preview = InputDataIdentifier("_id_checkout_preview")
private let _id_checkout_loading = InputDataIdentifier("_id_checkout_loading")
private func _id_checkout_price(_ label: String, index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_checkout_price_\(label)_\(index)")
}
private let _id_checkout_payment_method = InputDataIdentifier("_id_checkout_payment_method")
private let _id_checkout_shipping_info = InputDataIdentifier("_id_checkout_shipping_info")
private let _id_checkout_name = InputDataIdentifier("_id_checkout_name")
private let _id_checkout_flex_shipping = InputDataIdentifier("_id_checkout_flex_shipping")
private let _id_checkout_phone_number = InputDataIdentifier("_id_checkout_phone_number")
private let _id_checkout_email = InputDataIdentifier("_id_checkout_email")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_preview, equatable: nil, item: { initialSize, stableId in
        return PaymentsCheckoutPreviewRowItem(initialSize, stableId: stableId, context: arguments.context, message: state.message, viewType: .singleItem)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    if let form = state.form {
        
//        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.checkoutPriceHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
//        index += 1
        let insets = NSEdgeInsets(top: 7, left: 16, bottom: 7, right: 16)
        let first = NSEdgeInsets(top: 14, left: 16, bottom: 7, right: 16)
        let last = NSEdgeInsets(top: 7, left: 16, bottom: 14, right: 16)

        struct Tuple: Equatable {
            let label: String
            let price: String
            let viewType: GeneralViewType
        }
        
        var prices = form.invoice.prices
        if let shippingOption = state.shippingOptionId {
            prices += shippingOption.prices
        }
        
        for (i, price) in prices.enumerated() {
            var viewType = bestGeneralViewType(prices, for: i)
            
            if i == 0 {
                viewType = viewType.withUpdatedInsets(first)
            } else {
                viewType = viewType.withUpdatedInsets(insets)
            }
            if price == prices.last {
                viewType = GeneralViewType.innerItem.withUpdatedInsets(insets)
            }
            let tuple = Tuple(label:price.label, price: formatCurrencyAmount(price.amount, currency: form.invoice.currency), viewType: viewType)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_price(price.label, index: i), equatable: InputDataEquatable(tuple), item: { initialSize, stableId in
                return PaymentsCheckoutPriceItem(initialSize, stableId: stableId, title: tuple.label, price: tuple.price, font: .normal(.text), color: theme.colors.grayText, viewType: tuple.viewType)
            }))
            index += 1
        }
        
        if !prices.isEmpty {
            let viewType = GeneralViewType.lastItem.withUpdatedInsets(last)

            let tuple = Tuple(label: L10n.checkoutTotalAmount, price: formatCurrencyAmount(prices.reduce(0, { $0 + $1.amount}), currency: form.invoice.currency), viewType: viewType)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_price(L10n.checkoutTotalAmount, index: .max), equatable: InputDataEquatable(tuple), item: { initialSize, stableId in
                return PaymentsCheckoutPriceItem(initialSize, stableId: stableId, title: tuple.label, price: tuple.price, font: .medium(.text), color: theme.colors.text, viewType: tuple.viewType)
            }))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

        }
        var paymentMethodTitle = ""
        if let paymentMethod = state.paymentMethod {
            paymentMethodTitle = paymentMethod.title
        }

        var fields = form.invoice.requestedFields.intersection([.shippingAddress, .email, .name, .phone])
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_payment_method, data: .init(name: L10n.checkoutPaymentMethod, color: theme.colors.text, type: .nextContext(paymentMethodTitle), viewType: fields.isEmpty ? .singleItem : .firstItem, action: arguments.openPaymentMethod)))
        index += 1
        
        let savedInfo = state.savedInfo
        
        
        var updated = fields.subtracting(.shippingAddress)
        if updated != fields {
            fields = updated
            var addressString = ""
            if let address = savedInfo.shippingAddress {
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
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_shipping_info, data: .init(name: L10n.checkoutShippingAddress, color: theme.colors.text, type: .nextContext(addressString), viewType: fields.isEmpty && state.validatedInfo?.shippingOptions == nil ? .lastItem : .innerItem, action: {
                arguments.openForm(.address)
            })))
            index += 1
        }
        
        if let _ = state.validatedInfo?.shippingOptions {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_flex_shipping, data: .init(name: L10n.checkoutShippingMethod, color: theme.colors.text, type: .nextContext(state.shippingOptionId?.title ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, action: arguments.openShippingMethod)))
            index += 1
        }
        
        updated = fields.subtracting(.name)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_name, data: .init(name: L10n.checkoutName, color: theme.colors.text, type: .nextContext(savedInfo.name ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, action: {
                arguments.openForm(.name)
            })))
            index += 1
        }
        
        updated = fields.subtracting(.email)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_email, data: .init(name: L10n.checkoutEmail, color: theme.colors.text, type: .nextContext(savedInfo.email ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, action: {
                arguments.openForm(.email)
            })))
            index += 1
        }
        
        updated = fields.subtracting(.phone)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_phone_number, data: .init(name: L10n.checkoutPhone, color: theme.colors.text, type: .nextContext(formatPhoneNumber(savedInfo.phone ?? "")), viewType: fields.isEmpty ? .lastItem : .innerItem, action: {
                arguments.openForm(.phone)
            })))
            index += 1
        }
    
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_loading, equatable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .singleItem)
        }))
        index += 1
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PaymentsCheckoutController(context: AccountContext, message: Message) -> InputDataModalController {

    var close:(()->Void)? = nil
    let messageId = message.id
    let actionsDisposable = DisposableSet()

    let initialState = State(mode: .invoice, message: message, savedInfo: BotPaymentRequestedInfo(name: nil, phone: nil, email: nil, shippingAddress: nil))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, openForm: { focus in
        let state = stateValue.with({ $0 })
        if let form = state.form {
            showModal(with: PaymentsShippingInfoController(context: context, invoice: form.invoice, messageId: messageId, formInfo: state.savedInfo, focus: focus, formInfoUpdated: { savedInfo, validatedInfo in
                updateState { current in
                    var current = current
                    current.savedInfo = savedInfo
                    current.validatedInfo = validatedInfo
                    return current
                }
            }), for: context.window)
        }
    }, openShippingMethod: {
        let state = stateValue.with({ $0 })
        if let form = state.form, let options = state.validatedInfo?.shippingOptions {
            showModal(with: PaymentsShippingMethodController(context: context, shippingOptions: options, form: form, select: { id in
                updateState { current in
                    var current = current
                    current.shippingOptionId = id
                    return current
                }
            }), for: context.window)
        }
    }, openPaymentMethod: {
        if let value = parseRequestedPaymentMethod(paymentForm: stateValue.with { $0.form }) {
            showModal(with: PaymentsPaymentMethodController(context: context, fields: value.1, publishableKey: value.0, completion: { method in
                updateState { current in
                    var current = current
                    current.paymentMethod = method
                    return current
                }
            }), for: context.window)
        }
    }, pay: {
        guard let paymentMethod = stateValue.with ({ $0.paymentMethod }) else {
            return
        }
        
        let state = stateValue.with { $0 }
        
        let credentials: BotPaymentCredentials
        switch paymentMethod {
        case let .webToken(token):
            credentials = .generic(data: token.data, saveOnServer: token.saveOnServer)
        default:
            alert(for: context.window, info: "Unsupported")
            return
        }
        
        let paySignal = sendBotPaymentForm(account: context.account, messageId: messageId, validatedInfoId: state.validatedInfo?.id, shippingOptionId: state.shippingOptionId?.id, credentials: credentials)
        
        _ = showModalProgress(signal: paySignal, for: context.window).start(next: { result in
            
            let success:(Bool)->Void = { value in
                if value {
                    close?()
                }
            }
            switch result {
            case .done:
                success(true)
            case let .externalVerificationRequired(url: url):
                showModal(with: PaymentWebInteractionController(context: context, url: url, intent: .externalVerification(success)), for: context.window)
            }
        }, error: { error in
            let text: String
            switch error {
            case .alreadyPaid:
                text = L10n.checkoutErrorInvoiceAlreadyPaid
            case .generic:
                text = L10n.unknownError
            case .paymentFailed:
                text = L10n.checkoutErrorPaymentFailed
            case .precheckoutFailed:
                text = L10n.checkoutErrorPrecheckoutFailed
            }
            alert(for: context.window, info: text)
        })
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.checkoutTitle)
    
    
    let formAndMaybeValidatedInfo = fetchBotPaymentForm(postbox: context.account.postbox, network: context.account.network, messageId: messageId)
               |> mapToSignal { paymentForm -> Signal<(BotPaymentForm, BotPaymentValidatedFormInfo?), BotPaymentFormRequestError> in
                   if let current = paymentForm.savedInfo {
                       return validateBotPaymentForm(network: context.account.network, saveInfo: true, messageId: messageId, formInfo: current)
                           |> mapError { _ -> BotPaymentFormRequestError in
                               return .generic
                           }
                           |> map { result -> (BotPaymentForm, BotPaymentValidatedFormInfo?) in
                               return (paymentForm, result)
                           }
                           |> `catch` { _ -> Signal<(BotPaymentForm, BotPaymentValidatedFormInfo?), BotPaymentFormRequestError> in
                               return .single((paymentForm, nil))
                           }
                   } else {
                       return .single((paymentForm, nil))
                   }
               } |> deliverOnMainQueue

    actionsDisposable.add(formAndMaybeValidatedInfo.start(next: { form in
        updateState { current in
            var current = current
            current.form = form.0
            current.validatedInfo = form.1
            if let savedInfo = form.0.savedInfo {
                current.savedInfo = savedInfo
            }
            if let savedCredentials = form.0.savedCredentials {
                current.paymentMethod = .savedCredentials(savedCredentials)
            }

            return current
        }
    }, error: { error in
        close?()
        switch error {
        case .generic:
            alert(for: context.window, info: L10n.unknownError)
        }
    }))
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
                
        let state = stateValue.with ({ $0 })
                
        if let focus = state.unfilledInfo {
            return .fail(.doSomething(next: { _ in
                arguments.openForm(focus)
            }))
        }
        
        if state.validatedInfo?.shippingOptions != nil && state.shippingOptionId == nil {
            return .fail(.doSomething(next: { _ in
                arguments.openShippingMethod()
            }))
        }

        if state.paymentMethod == nil {
            return .fail(.doSomething(next: { _ in
                arguments.openPaymentMethod()
            }))
        }
        
        return .fail(.doSomething(next: { _ in
            arguments.pay()
        }))
    }

    let modalInteractions = ModalInteractions(acceptTitle: L10n.checkoutPayNone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    controller.afterTransaction = { [weak modalInteractions] controller in
        modalInteractions?.updateDone { button in
            button.isEnabled = stateValue.with { $0.form != nil }
            let state = stateValue.with ({ $0 })
            let text: String
            if let form = state.form {
                let totalAmount = formatCurrencyAmount(currentTotalPrice(paymentForm: form, validatedFormInfo: state.validatedInfo, shippingOption: state.shippingOptionId), currency: form.invoice.currency)
                text = L10n.checkoutPayPrice("\(totalAmount)")
            } else {
                text = L10n.checkoutPayNone
            }
            button.set(text: text, for: .Normal)
        }
    }
    
    return modalController
    
}

