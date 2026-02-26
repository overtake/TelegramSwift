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
import CurrencyFormat
import Postbox

enum PaymentProvider : Equatable {
    case stripe
    case smartglocal(String?)
}


enum BotCheckoutPaymentMethod: Equatable {
    case savedCredentials(BotPaymentSavedCredentials)
    case webToken(BotCheckoutPaymentWebToken)
    case other(BotPaymentMethod)
    
    var title: String {
        switch self {
            case let .savedCredentials(credentials):
                switch credentials {
                    case let .card(_, title):
                        return title
                }
            case let .webToken(token):
                return token.title
            case let .other(method):
                return method.title
        }
    }
}





private func availablePaymentMethods(form: BotPaymentForm, current: BotCheckoutPaymentMethod?) -> [BotCheckoutPaymentMethod] {
    var methods: [BotCheckoutPaymentMethod] = []
    for savedCredentials in form.savedCredentials {
        if !methods.contains(.savedCredentials(savedCredentials)) {
            methods.append(.savedCredentials(savedCredentials))
        }
    }
    
    if !form.additionalPaymentMethods.isEmpty {
        methods.append(contentsOf: form.additionalPaymentMethods.map { .other($0) })
    }
    if let current = current {
        if !methods.contains(current) {
            methods.insert(current, at: 0)
        }
    }
    return methods
}



func parseRequestedPaymentMethod(paymentForm: BotPaymentForm?) -> (String, PaymentsPaymentMethodAdditionalFields, PaymentProvider)? {
        
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
        
        return (publishableKey, additionalFields, .stripe)
    } else if let paymentForm = paymentForm, let nativeProvider = paymentForm.nativeProvider, nativeProvider.name == "smartglocal" {
        guard let paramsData = nativeProvider.params.data(using: .utf8) else {
            return nil
        }
        guard let nativeParams = (try? JSONSerialization.jsonObject(with: paramsData)) as? [String: Any] else {
            return nil
        }
        guard let publishableKey = nativeParams["public_token"] as? String else {
            return nil
        }
        
        var customTokenizeUrl: String?
        if let value = nativeParams["public_token"] as? String, let url = URL(string: value), let host = url.host {
            if url.scheme == "https" && (host == "smart-glocal.com" || host.hasSuffix(".smart-glocal.com")) {
                customTokenizeUrl = value
            }
        }
        return (publishableKey, [], .smartglocal(customTokenizeUrl))
    }
    return nil
}



private func currentTotalPrice(paymentForm: BotPaymentForm?, validatedFormInfo: BotPaymentValidatedFormInfo?, shippingOption: BotPaymentShippingOption?, tip:Int64? = nil) -> Int64 {
    guard let paymentForm = paymentForm else {
        return 0
    }
    
    var totalPrice: Int64 = 0
    
    for price in paymentForm.invoice.prices {
        totalPrice += price.amount
    }
    
    if let option = shippingOption {
        for price in option.prices {
            totalPrice += price.amount
        }
    }
    if let tip = tip {
        totalPrice += tip
    }
    
    return totalPrice
}


struct BotCheckoutPaymentWebToken: Equatable {
    let title: String
    let data: String
    var saveOnServer: Bool
}


private final class Arguments {
    let context: AccountContext
    let openForm:(PaymentsShippingInfoFocus?)->Void
    let openShippingMethod:()->Void
    let openPaymentMethod:()->Void
    let selectTip:(Int64?)->Void
    let pay:(TemporaryTwoStepPasswordToken?)->Void
    let toggleRecurrentAccept:()->Void
    init(context: AccountContext, openForm:@escaping(PaymentsShippingInfoFocus?)->Void, openShippingMethod:@escaping()->Void, openPaymentMethod:@escaping()->Void, pay:@escaping(TemporaryTwoStepPasswordToken?)->Void, selectTip:@escaping(Int64?)->Void, toggleRecurrentAccept:@escaping()->Void) {
        self.context = context
        self.openForm = openForm
        self.openShippingMethod = openShippingMethod
        self.openPaymentMethod = openPaymentMethod
        self.pay = pay
        self.selectTip = selectTip
        self.toggleRecurrentAccept = toggleRecurrentAccept
    }
}

enum PaymentViewMode {
    case receipt
    case invoice
}

extension TelegramMediaInvoice : Equatable {
    public static func == (lhs: TelegramMediaInvoice, rhs: TelegramMediaInvoice) -> Bool {
        return lhs.id == rhs.id
    }
}

private struct State : Equatable {
    let mode: PaymentViewMode
    var invoice: TelegramMediaInvoice
    var form: BotPaymentForm?
    var botPeer: PeerEquatable?
    var validatedInfo: BotPaymentValidatedFormInfo?
    var savedInfo: BotPaymentRequestedInfo
    var shippingOptionId: BotPaymentShippingOption?
    var paymentMethod: BotCheckoutPaymentMethod?
    var currentTip: Int64?
    var recurrentAccepted: Bool?
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

private let _id_recurrent_info = InputDataIdentifier("_id_checkout_email")

private let _id_tips = InputDataIdentifier("_id_tips")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
  
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_preview, equatable: InputDataEquatable(state.botPeer), comparable: nil, item: { initialSize, stableId in
        return PaymentsCheckoutPreviewRowItem(initialSize, stableId: stableId, context: arguments.context, invoice: state.invoice, botPeer: state.botPeer?.peer, viewType: .singleItem)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
  
    
    if let form = state.form {
        
//        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().checkoutPriceHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
//        index += 1
        let insets = NSEdgeInsets(top: 7, left: 16, bottom: 7, right: 16)
        let first = NSEdgeInsets(top: 14, left: 16, bottom: 7, right: 16)
        let last = NSEdgeInsets(top: 7, left: 16, bottom: 14, right: 16)

        struct Tuple: Equatable {
            let label: String
            let price: String
            let viewType: GeneralViewType
            let editableTip: PaymentsCheckoutPriceItem.EditableTip?
        }
        
        
        
        var prices = form.invoice.prices
        if let shippingOption = state.shippingOptionId {
            prices += shippingOption.prices
        }
        
        if let _ = form.invoice.tip {
            prices.append(BotPaymentPrice(label: strings().paymentsTipLabel, amount: state.currentTip ?? 0))
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
            
            let editableTip: PaymentsCheckoutPriceItem.EditableTip?
            
            if price.label == strings().paymentsTipLabel, let tip = form.invoice.tip {
                editableTip = PaymentsCheckoutPriceItem.EditableTip(currency: form.invoice.currency, current: state.currentTip ?? 0, maxValue: tip.max)
            } else {
                editableTip = nil
            }
            
            let tuple = Tuple(label:price.label, price: formatCurrencyAmount(price.amount, currency: form.invoice.currency), viewType: viewType, editableTip: editableTip)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_price(price.label, index: i), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return PaymentsCheckoutPriceItem(initialSize, stableId: stableId, title: tuple.label, price: tuple.price, font: .normal(.text), color: theme.colors.grayText, viewType: tuple.viewType, editableTip: editableTip, updateValue: arguments.selectTip)
            }))
            index += 1
        }
        
        
        if let tip = form.invoice.tip, !prices.isEmpty {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_tips, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
                return PaymentsTipsRowItem(initialSize, stableId: stableId, viewType: .innerItem, currency: form.invoice.currency, tips: tip, current: state.currentTip, select: arguments.selectTip)
            }))
            index += 1
        }
        
        if !prices.isEmpty {
            let viewType = GeneralViewType.lastItem.withUpdatedInsets(last)

            let tuple = Tuple(label: strings().checkoutTotalAmount, price: formatCurrencyAmount(prices.reduce(0, { $0 + $1.amount}), currency: form.invoice.currency), viewType: viewType, editableTip: nil)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_price(strings().checkoutTotalAmount, index: .max), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return PaymentsCheckoutPriceItem(initialSize, stableId: stableId, title: tuple.label, price: tuple.price, font: .medium(.text), color: theme.colors.text, viewType: tuple.viewType)
            }))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1

        }
        var paymentMethodTitle = ""
        if let paymentMethod = state.paymentMethod {
            paymentMethodTitle = paymentMethod.title
        }

        var fields = form.invoice.requestedFields.intersection([.shippingAddress, .email, .name, .phone])
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_payment_method, data: .init(name: strings().checkoutPaymentMethod, color: theme.colors.text, type: .nextContext(paymentMethodTitle), viewType: fields.isEmpty ? .singleItem : .firstItem, action: arguments.openPaymentMethod)))
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
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_shipping_info, data: .init(name: strings().checkoutShippingAddress, color: theme.colors.text, type: .nextContext(addressString), viewType: fields.isEmpty && state.validatedInfo?.shippingOptions == nil ? .lastItem : .innerItem, action: {
                arguments.openForm(.address)
            })))
            index += 1
        }
        
        if let _ = state.validatedInfo?.shippingOptions {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_flex_shipping, data: .init(name: strings().checkoutShippingMethod, color: theme.colors.text, type: .nextContext(state.shippingOptionId?.title ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, action: arguments.openShippingMethod)))
            index += 1
        }
        
        updated = fields.subtracting(.name)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_name, data: .init(name: strings().checkoutName, color: theme.colors.text, type: .nextContext(savedInfo.name ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, action: {
                arguments.openForm(.name)
            })))
            index += 1
        }
        
        updated = fields.subtracting(.email)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_email, data: .init(name: strings().checkoutEmail, color: theme.colors.text, type: .nextContext(savedInfo.email ?? ""), viewType: fields.isEmpty ? .lastItem : .innerItem, action: {
                arguments.openForm(.email)
            })))
            index += 1
        }
        
        updated = fields.subtracting(.phone)
        if updated != fields {
            fields = updated
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_phone_number, data: .init(name: strings().checkoutPhone, color: theme.colors.text, type: .nextContext(formatPhoneNumber(context: arguments.context, number: savedInfo.phone ?? "")), viewType: fields.isEmpty ? .lastItem : .innerItem, action: {
                arguments.openForm(.phone)
            })))
            index += 1
        }
        
        if let info = state.form?.invoice.termsInfo, let accept = state.recurrentAccepted {
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_recurrent_info, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return PaymentsCheckoutRecurrentRowItem(initialSize, stableId: stableId, termsUrl: info.termsUrl, botName: state.botPeer?.peer.displayTitle ?? "", accept: accept, isReccurent: info.isRecurrent, toggle: arguments.toggleRecurrentAccept)
            }))
            index += 1
        }
    
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_checkout_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .singleItem)
        }))
        index += 1
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

enum PaymentCheckoutCompletionStatus : String {
    case paid
    case cancelled
    case failed
}

func PaymentsCheckoutController(context: AccountContext, source: BotPaymentInvoiceSource, invoice: TelegramMediaInvoice, completion:((PaymentCheckoutCompletionStatus)->Void)? = nil) -> InputDataModalController {

    var completion = completion
    
    let invokeCompletion:(PaymentCheckoutCompletionStatus)->Void = { value in
        completion?(value)
        completion = nil
    }
    
    var getController:(()->ViewController?)? = nil
    
    
    let window:()->Window = {
        return bestWindow(context, getController?())
    }
    
    var close:(()->Void)? = nil
    let actionsDisposable = DisposableSet()

    let initialState = State(mode: .invoice, invoice: invoice, savedInfo: BotPaymentRequestedInfo(name: nil, phone: nil, email: nil, shippingAddress: nil))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let addPaymentMethod:(String, BotPaymentForm)->Void = { url, paymentForm in
        showModal(with: PaymentWebInteractionController(context: context, url: url, intent: .addPaymentMethod({ token in
           
            let canSave = paymentForm.canSaveCredentials && !paymentForm.passwordMissing
            if canSave {
                verifyAlert_button(for: window(), information: strings().checkoutInfoSaveInfoHelp, ok: strings().modalYes, cancel: strings().modalNotNow, successHandler: { _ in
                    updateState { current in
                        var current = current
                        current.paymentMethod = .webToken(.init(title: token.title, data: token.data, saveOnServer: true))
                        return current
                    }
                }, cancelHandler: {
                    updateState { current in
                        var current = current
                        current.paymentMethod = .webToken(token)
                        return current
                    }
                })
            } else {
                updateState { current in
                    var current = current
                    current.paymentMethod = .webToken(token)
                    return current
                }
            }

        })), for: window())
    }

    let arguments = Arguments(context: context, openForm: { focus in
        let state = stateValue.with({ $0 })
        if let form = state.form {
            showModal(with: PaymentsShippingInfoController(context: context, invoice: form.invoice, source: source, formInfo: state.savedInfo, focus: focus, formInfoUpdated: { savedInfo, validatedInfo in
                updateState { current in
                    var current = current
                    current.savedInfo = savedInfo
                    current.validatedInfo = validatedInfo
                    return current
                }
            }), for: window())
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
            }), for: window())
        }
    }, openPaymentMethod: {
        if let form = stateValue.with({ $0.form }), let value = parseRequestedPaymentMethod(paymentForm: form) {
            
            let openNewCard:()->Void = {
                showModal(with: PaymentsPaymentMethodController(context: context, fields: value.1, publishableKey: value.0, passwordMissing: form.passwordMissing, isTesting: form.invoice.isTest, provider: value.2, completion: { method in
                    updateState { current in
                        var current = current
                        current.paymentMethod = method
                        return current
                    }
                }), for: window())
            }
            
            let methods = availablePaymentMethods(form: form, current: nil)
            showModal(with: PamentsSelectMethodController(context: context, cards: form.savedCredentials, form: form, methods: methods, select: { selected in
                updateState { current in
                    var current = current
                    current.paymentMethod = .savedCredentials(selected)
                    return current
                }
            }, addNew: openNewCard, addPaymentMethod: addPaymentMethod), for: window())
            
        } else if let paymentForm = stateValue.with({ $0.form }) {
            if let url = paymentForm.url {
                addPaymentMethod(url, paymentForm)
            }
        }
    }, pay: { savedCredentialsToken in
        guard let paymentMethod = stateValue.with ({ $0.paymentMethod }) else {
            return
        }
        let state = stateValue.with { $0 }
        
        let pay:(BotPaymentCredentials)->Void = { credentials in
            
            guard let form = state.form else {
                return
            }
                        
            let pay:()->Void = {
                
                let paySignal = context.engine.payments.sendBotPaymentForm(source: source, formId: form.id, validatedInfoId: state.validatedInfo?.id, shippingOptionId: state.shippingOptionId?.id, tipAmount: state.form?.invoice.tip != nil ? (state.currentTip ?? 0) : nil, credentials: credentials)
                
                _ = showModalProgress(signal: paySignal, for: window()).start(next: { result in
                    
                    let success:(Bool)->Void = { value in
                        if value {
                            invokeCompletion(.paid)
                            close?()
                            let invoice = state.invoice
                            let totalValue = currentTotalPrice(paymentForm: form, validatedFormInfo: state.validatedInfo, shippingOption: state.shippingOptionId)
                            
                            let total = formatCurrencyAmount(totalValue, currency: form.invoice.currency)
                            
                            showModalText(for: window(), text: strings().paymentsPaid(total, invoice.title))
                        }
                    }
                    switch result {
                    case .done:
                        success(true)
                    case let .externalVerificationRequired(url: url):
                        showModal(with: PaymentWebInteractionController(context: context, url: url, intent: .externalVerification(success)), for: window())
                    }
                }, error: { error in
                    let text: String
                    switch error {
                    case .alreadyPaid:
                        text = strings().checkoutErrorInvoiceAlreadyPaid
                    case .generic:
                        text = strings().unknownError
                    case .paymentFailed:
                        text = strings().checkoutErrorPaymentFailed
                    case .precheckoutFailed:
                        text = strings().checkoutErrorPrecheckoutFailed
                    case .starGiftOutOfStock:
                        text = strings().giftSoldOutError
                    case .disallowedStarGift:
                        text = strings().giftSendDisallowError
                    case .starGiftUserLimit:
                        text = strings().giftOptionsGiftBuyLimitReached
                    }
                    alert(for: window(), info: text)
                    invokeCompletion(.failed)
                    close?()
                })
            }
            
            let botPeer: Signal<Peer?, NoError> = context.account.postbox.transaction { transaction -> Peer? in
                if let paymentBotId = form.paymentBotId {
                    return transaction.getPeer(paymentBotId)
                } else {
                    return nil
                }
            }

            if let providerId = form.providerId, let paymentBotId = form.paymentBotId {
                let checkSignal = combineLatest(queue: .mainQueue(), ApplicationSpecificNotice.getBotPaymentLiability(accountManager: context.sharedContext.accountManager, peerId: paymentBotId), botPeer, context.account.postbox.loadedPeerWithId(providerId))
                
                let _ = checkSignal.startStandalone(next: { value, botPeer, providerPeer in
                    if let botPeer = botPeer {
                        if value {
                            pay()
                        } else {
                            verifyAlert_button(for: window(), header: strings().paymentsWarninTitle, information: strings().paymentsWarningText(botPeer.compactDisplayTitle, providerPeer.compactDisplayTitle, botPeer.compactDisplayTitle, botPeer.compactDisplayTitle), successHandler: { _ in
                                pay()
                                _ = ApplicationSpecificNotice.setBotPaymentLiability(accountManager: context.sharedContext.accountManager, peerId: botPeer.id).start()
                            })
                        }
                    }
                })
            }
        }
        
        switch paymentMethod {
        case let .savedCredentials(savedCredentials):
            switch savedCredentials {
            case let .card(id, title):
                if let savedCredentialsToken = savedCredentialsToken {
                    pay(.saved(id: id, tempPassword: savedCredentialsToken.token))
                } else {
                    let _ = (context.engine.auth.cachedTwoStepPasswordToken()
                                                   |> deliverOnMainQueue).start(next: { token in
                        let timestamp = context.account.network.getApproximateRemoteTimestamp()
                        if let token = token, token.validUntilDate > timestamp - 1 * 60  {
                            pay(.saved(id: id, tempPassword: token.token))
                        } else {
                            showModal(with: InputPasswordController(context: context, title: strings().checkoutPasswordEntryTitle, desc: strings().checkoutPasswordEntryText(title), checker: { password in
                                Signal { subscriber in
                                    let checker = context.engine.auth.requestTemporaryTwoStepPasswordToken(password: password, period: 1 * 60, requiresBiometrics: false) |> deliverOnMainQueue
                                    return checker.start(next: { token in
                                        pay(.saved(id: id, tempPassword: token.token))
                                        subscriber.putCompletion()
                                    }, error: { error in
                                        switch error {
                                        case .invalidPassword:
                                            subscriber.putError(.wrong)
                                        default:
                                            subscriber.putError(.generic)
                                        }
                                    })
                                }
                            }), for: window())
                        }
                    })
                }
            }
        case let .webToken(token):
            pay(.generic(data: token.data, saveOnServer: token.saveOnServer))
        default:
            alert(for: window(), info: "Unsupported")
            return
        }
    }, selectTip: { value in
        updateState { current in
            var current = current
            if let value = value {
                current.currentTip = min(value, current.form?.invoice.tip?.max ?? .max)
            } else {
                current.currentTip = nil
            }
            return current
        }
    }, toggleRecurrentAccept: {
        updateState { current in
            var current = current
            if let value = current.recurrentAccepted {
                current.recurrentAccepted = !value
            }
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().checkoutTitle)
    
    
    let themeParams: [String: Any] = [
        "bg_color": Int32(bitPattern: theme.colors.background.argb),
        "text_color": Int32(bitPattern: theme.colors.text.argb),
        "link_color": Int32(bitPattern: theme.colors.link.argb),
        "button_color": Int32(bitPattern: theme.colors.accent.argb),
        "button_text_color": Int32(bitPattern: theme.colors.underSelectedColor.argb)
            ]

    
    let formAndMaybeValidatedInfo = context.engine.payments.fetchBotPaymentForm(source: source, themeParams: themeParams)
           |> mapToSignal { paymentForm -> Signal<(BotPaymentForm, BotPaymentValidatedFormInfo?), BotPaymentFormRequestError> in
               if let current = paymentForm.savedInfo {
                   return context.engine.payments.validateBotPaymentForm(saveInfo: true, source: source, formInfo: current)
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

    let formPromise: Promise<(BotPaymentForm, BotPaymentValidatedFormInfo?)> = Promise()
    
    formPromise.set(formAndMaybeValidatedInfo |> `catch` { _ in .complete() })
    
    
    let botPeer: Signal<Peer?, BotPaymentFormRequestError> = formPromise.get() |> mapToSignal { value in
        return context.account.postbox.transaction { transaction in
            if let paymentBotId = value.0.paymentBotId {
                return transaction.getPeer(paymentBotId)
            } else {
                return nil
            }
        }
    } |> castError(BotPaymentFormRequestError.self)
    
    actionsDisposable.add(combineLatest(formPromise.get() |> castError(BotPaymentFormRequestError.self), botPeer).start(next: { form, botPeer in
        updateState { current in
            var current = current
            current.form = form.0
            if current.recurrentAccepted == nil, current.form?.invoice.termsInfo != nil {
                current.recurrentAccepted = false
            }
            current.botPeer = botPeer != nil ? PeerEquatable(botPeer!) : nil
            current.validatedInfo = form.1
            if let savedInfo = form.0.savedInfo {
                current.savedInfo = savedInfo
            }
            if let savedCredentials = form.0.savedCredentials.first {
                current.paymentMethod = .savedCredentials(savedCredentials)
            }

            return current
        }
    }, error: { error in
        invokeCompletion(.failed)
        close?()
        alert(for: window(), info: strings().unknownError)
    }))
    
    getController = { [weak controller] in
        return controller
    }
    
    
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
        if let recurrent = state.recurrentAccepted {
            if !recurrent {
                return .fail(.fields([_id_recurrent_info : .shake]))
            }
        }
        
        return .fail(.doSomething(next: { _ in
            arguments.pay(nil)
        }))
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().checkoutPayNone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in
        f()
        invokeCompletion(.cancelled)
    })
    
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
                let totalAmount = formatCurrencyAmount(currentTotalPrice(paymentForm: form, validatedFormInfo: state.validatedInfo, shippingOption: state.shippingOptionId, tip: state.currentTip), currency: form.invoice.currency)
                text = strings().checkoutPayPrice("\(totalAmount)")
            } else {
                text = strings().checkoutPayNone
            }
            button.set(text: text, for: .Normal)
        }
        if stateValue.with ({ $0.form != nil }) {
            DispatchQueue.main.async { [weak controller] in
                controller?.window?.applyResponderIfNeeded()
            }
        }
    }
    
    return modalController
    
}

