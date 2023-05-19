//
//  PaymentsPaymentMethodController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import Stripe



private final class Arguments {
    let context: AccountContext
    let toggleSaveInfo:()->Void
    let verify: ()->Void
    let passwordMissing:Bool
    init(context: AccountContext, toggleSaveInfo: @escaping()->Void, verify: @escaping()->Void, passwordMissing:Bool) {
        self.context = context
        self.toggleSaveInfo = toggleSaveInfo
        self.verify = verify
        self.passwordMissing = passwordMissing
    }
}


private let _id_card_number = InputDataIdentifier("_id_card_number")
private let _id_card_date = InputDataIdentifier("_id_card_date")
private let _id_card_cvc = InputDataIdentifier("_id_card_cvc")

private let _id_card_holder_name = InputDataIdentifier("_id_card_holder_name")

private let _id_card_country = InputDataIdentifier("_id_card_country")
private let _id_card_zip_code = InputDataIdentifier("_id_card_zip_code")

private let _id_card_save_info = InputDataIdentifier("_id_card_save_info")

private struct State : Equatable {
    struct Card : Equatable {
        var number: String
        var date: String
        var cvc: String
    }
    struct BillingAddress : Equatable {
        var country: String?
        var zipCode: String?
    }
    var card: Card
    var holderName: String?
    var billingAddress: BillingAddress
    
    var stripe: STPCardParams {
        let params = STPCardParams()
        params.number = STPCardValidator.sanitizedNumericString(for: self.card.number)
        if self.card.date.count == 5 {
            params.expYear = UInt(self.card.date.suffix(2))!
            params.expMonth = UInt(self.card.date.prefix(2))!
        }
        params.cvc = self.card.cvc
        params.name = self.holderName
        params.addressCountry = self.billingAddress.country
        params.addressZip = self.billingAddress.zipCode
        return params
    }
    
    var cardError: InputDataValueError?
    var nameError: InputDataValueError?
    var billingError: InputDataValueError?
    
    var saveInfo: Bool
    
    var unfilledItem: InputDataIdentifier? {
        
        let normalized = STPCardValidator.sanitizedNumericString(for: card.number)
        let brand = STPCardValidator.brand(forNumber: normalized)
        let maxCardNumberLength = STPCardValidator.maxLength(for: brand)
        let maxCVCLength = STPCardValidator.maxCVCLength(for: brand)

                
        if normalized.length == maxCardNumberLength {
            let state = STPCardValidator.validationState(forNumber: card.number, validatingCardBrand: true)
            switch state {
            case .invalid:
                return _id_card_number
            default:
                break
            }
        } else {
            return _id_card_number
        }
              
        if card.date.length == 5 {
            let yearState = STPCardValidator.validationState(forExpirationYear: String(card.date.suffix(2)), inMonth: card.date.prefix(2))
            switch yearState {
            case .invalid:
                return _id_card_date
            default:
                let monthState = STPCardValidator.validationState(forExpirationMonth: card.date.prefix(2))
                switch monthState {
                case .invalid:
                    return _id_card_date
                default:
                    break
                }
            }
        } else {
            return _id_card_date
        }
        
        if card.cvc.length == maxCVCLength {
            let state = STPCardValidator.validationState(forCVC: card.cvc, cardBrand: brand)
            switch state {
            case .invalid:
                return _id_card_cvc
            default:
                break
            }
        } else {
            return _id_card_cvc
        }
        
        if let holder = self.holderName, holder.isEmpty {
            return _id_card_holder_name
        }
        if let country = self.billingAddress.country, country.isEmpty {
            return _id_card_country
        }
        if let zipCode = self.billingAddress.zipCode, zipCode.isEmpty {
            return _id_card_zip_code
        }
        
        return nil
    }
}

private func validateSmartGlobal(_ publicToken: String, isTesting: Bool, state: State) -> Signal<BotCheckoutPaymentMethod, Error> {
    return Signal { subscriber in
        
        let url: String
        if isTesting {
            url = "https://tgb-playground.smart-glocal.com/cds/v1/tokenize/card"
        } else {
            url = "https://tgb.smart-glocal.com/cds/v1/tokenize/card"
        }

        let stripe = state.stripe
        
        let jsonPayload: [String: Any] = [
            "card": [
                "number": stripe.number ?? "",
                "expiration_month": "\(state.card.date.prefix(2))",
                "expiration_year": "\(state.card.date.suffix(2))",
                "security_code": "\(stripe.cvc ?? "")"
            ] as [String: Any]
        ]

        guard let parsedUrl = URL(string: url) else {
            return EmptyDisposable
        }

        var request = URLRequest(url: parsedUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publicToken, forHTTPHeaderField: "X-PUBLIC-TOKEN")
        guard let requestBody = try? JSONSerialization.data(withJSONObject: jsonPayload, options: []) else {
            return EmptyDisposable
        }
        request.httpBody = requestBody

        let session = URLSession.shared
        
        var cancelled: Bool = false
        
        let dataTask = session.dataTask(with: request, completionHandler: { data, response, error in
            enum ReponseError: Error {
                case generic
            }
            
            if cancelled {
                return
            } else if let error = error {
                subscriber.putError(error)
                return
            }

            do {
                guard let data = data else {
                    throw ReponseError.generic
                }

                let jsonRaw = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonRaw as? [String: Any] else {
                    throw ReponseError.generic
                }
                guard let resultData = json["data"] as? [String: Any] else {
                    throw ReponseError.generic
                }
                guard let resultInfo = resultData["info"] as? [String: Any] else {
                    throw ReponseError.generic
                }
                guard let token = resultData["token"] as? String else {
                    throw ReponseError.generic
                }
                guard let maskedCardNumber = resultInfo["masked_card_number"] as? String else {
                    throw ReponseError.generic
                }
                guard let cardType = resultInfo["card_type"] as? String else {
                    throw ReponseError.generic
                }

                var last4 = maskedCardNumber
                if last4.count > 4 {
                    let lastDigits = String(maskedCardNumber[maskedCardNumber.index(maskedCardNumber.endIndex, offsetBy: -4)...])
                    if lastDigits.allSatisfy(\.isNumber) {
                        last4 = "\(cardType) *\(lastDigits)"
                    }
                }

                let responseJson: [String: Any] = [
                    "type": "card",
                    "token": "\(token)"
                ]

                let serializedResponseJson = try JSONSerialization.data(withJSONObject: responseJson, options: [])

                guard let serializedResponseString = String(data: serializedResponseJson, encoding: .utf8) else {
                    throw ReponseError.generic
                }

                subscriber.putNext(.webToken(BotCheckoutPaymentWebToken(
                    title: last4,
                    data: serializedResponseString,
                    saveOnServer: state.saveInfo
                )))
                subscriber.putCompletion()
            } catch {
                subscriber.putError(error)
            }
        })
        
        dataTask.resume()


        return ActionDisposable {
            cancelled = true
            dataTask.cancel()
        }
    }
}


struct PaymentsPaymentMethodAdditionalFields: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let cardholderName = PaymentsPaymentMethodAdditionalFields(rawValue: 1 << 0)
    static let country = PaymentsPaymentMethodAdditionalFields(rawValue: 1 << 1)
    static let zipCode = PaymentsPaymentMethodAdditionalFields(rawValue: 1 << 2)
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().checkoutNewCardPaymentCard), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    let cardBrand = STPCardValidator.brand(forNumber: state.card.number)
    let maxCardNumberLength = STPCardValidator.maxLength(for: cardBrand)
    let maxCVCLength = STPCardValidator.maxCVCLength(for: cardBrand)

    
    let image: NSImage? = STPImageLibrary.brandImage(for: cardBrand)

    let spacesCardLength: Int
    switch cardBrand {
    case .amex:
        spacesCardLength = 2
    default:
        spacesCardLength = 3
    }
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.card.number), error: nil, identifier: _id_card_number, mode: .plain, data: .init(viewType: .firstItem), placeholder: InputDataInputPlaceholder(icon: image?._cgImage), inputPlaceholder: "1234 5678 1234 5678", filter: { value in
        
        let filtered = value.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890").inverted)
        let sanitized = STPCardValidator.sanitizedNumericString(for: filtered)
        
        let cardSpacing: [Int]
        switch cardBrand {
        case .amex:
            cardSpacing = [4 ,10]
        default:
            cardSpacing = [4, 8, 12]
        }
        var chars = Array(sanitized)
        
        for (i, space) in cardSpacing.enumerated() {
            let index = space + i
            if chars.count > index {
                chars.insert(" ", at: index)
            }
        }
        
        return String(chars)
    }, limit: Int32(maxCardNumberLength + spacesCardLength)))
    index += 1

    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.card.date), error: nil, identifier: _id_card_date, mode: .plain, data: .init(viewType: .innerItem), placeholder: nil, inputPlaceholder: "MM/YY", filter: { value in
        
        let filtered = value.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890").inverted)
            .replacingOccurrences(of: "/", with: "")

        var chars = Array(filtered).map { String($0) }
        
        if chars.count > 0 {
            let month = Int(String(chars[0]))!
            if month > 1 {
                chars[0] = "0"
                if chars.count == 1 {
                    chars.append("\(month)")
                } else {
                    chars[1] = "\(month)"
                }
            }
            if chars.count > 2 {
                chars.insert("/", at: 2)
            }
        }
        return chars.joined()
    }, limit: 5))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.card.cvc), error: state.cardError, identifier: _id_card_cvc, mode: .plain, data: .init(viewType: .lastItem), placeholder: nil, inputPlaceholder: "CVC", filter: { value in
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890").inverted)
    }, limit: Int32(maxCVCLength)))
    index += 1


    if state.holderName != nil {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().checkoutNewCardCardholderNameTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(state.holderName), error: nil, identifier: _id_card_holder_name, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().checkoutNewCardCardholderNamePlaceholder, filter: { $0.uppercased() }, limit: 255))
        index += 1
    }
    
    
    if state.billingAddress.country != nil || state.billingAddress.zipCode != nil {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().checkoutNewCardPostcodeTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        if state.billingAddress.country != nil {
            
            let filedata = try! String(contentsOfFile: Bundle.main.path(forResource: "countries", ofType: nil)!)
            
            let countries: [ValuesSelectorValue<InputDataValue>] = filedata.components(separatedBy: "\n").compactMap { country in
                let entry = country.components(separatedBy: ";")
                if entry.count >= 3 {
                    return ValuesSelectorValue(localized: entry[2], value: .string(entry[1]))
                } else {
                    return nil
                }
            }.sorted(by: { $0.localized < $1.localized})

            
            entries.append(.selector(sectionId: sectionId, index: index, value: .string(state.billingAddress.country), error: nil, identifier: _id_card_country, placeholder: strings().checkoutInfoShippingInfoCountryPlaceholder, viewType: state.billingAddress.zipCode != nil ? .firstItem : .singleItem, values: countries))
            index += 1
        }
        if state.billingAddress.zipCode != nil {
            let type = STPPostalCodeValidator.postalCodeType(forCountryCode: state.billingAddress.country)
            
            entries.append(.input(sectionId: sectionId, index: index, value: .string(state.billingAddress.zipCode), error: state.billingError, identifier: _id_card_zip_code, mode: .plain, data: .init(viewType: state.billingAddress.country != nil ? .lastItem : .singleItem), placeholder: InputDataInputPlaceholder(strings().checkoutNewCardPostcodePlaceholder), inputPlaceholder: strings().checkoutNewCardPostcodePlaceholder, filter: { value in
                switch type {
                case .countryPostalCodeTypeAlphanumeric:
                    return value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                case .countryPostalCodeTypeNumericOnly:
                    return value.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890"))
                case .countryPostalCodeTypeNotRequired:
                    return value
                @unknown default:
                    return value
                }
            }, limit: 12))
            index += 1
        }
        
        
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_card_save_info, data: .init(name: strings().checkoutInfoSaveInfo, color: theme.colors.text, type: .switchable(state.saveInfo), viewType: .singleItem, enabled: !arguments.passwordMissing, action: arguments.toggleSaveInfo)))
    index += 1
    let desc = arguments.passwordMissing ? strings().checkout2FAText : strings().checkoutNewCardSaveInfoHelp
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(desc), data: InputDataGeneralTextData(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PaymentsPaymentMethodController(context: AccountContext, fields: PaymentsPaymentMethodAdditionalFields, publishableKey: String, passwordMissing: Bool, isTesting: Bool, provider: PaymentProvider, completion: @escaping (BotCheckoutPaymentMethod) -> Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    var close:(()->Void)? = nil
    
    let initialState = State(card: .init(number: "", date: "", cvc: ""), holderName: fields.contains(.cardholderName) ? "" : nil, billingAddress: .init(country: fields.contains(.country) ? "" : nil, zipCode: fields.contains(.zipCode) ? "" : nil), saveInfo: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, toggleSaveInfo: {
        updateState { current in
            var current = current
            current.saveInfo = !current.saveInfo
            return current
        }
    }, verify: {
        
        let tokenSignal:Signal<BotCheckoutPaymentMethod?, Error>
        
        switch provider {
        case .stripe:
            let configuration = STPPaymentConfiguration.shared().copy() as! STPPaymentConfiguration
            configuration.smsAutofillDisabled = true
            configuration.publishableKey = publishableKey
            configuration.appleMerchantIdentifier = "merchant.ph.telegra.Telegraph"
            let apiClient = STPAPIClient(configuration: configuration)
            let card = stateValue.with { $0.stripe }
            let saveOnServer = stateValue.with { $0.saveInfo }
            let createToken: Signal<STPToken, Error> = Signal { subscriber in
                apiClient.createToken(withCard: card, completion: { token, error in
                    if let error = error {
                        subscriber.putError(error)
                    } else if let token = token {
                        subscriber.putNext(token)
                        subscriber.putCompletion()
                    }
                })
                return ActionDisposable {
                    let _ = apiClient.publishableKey
                }
            }
            tokenSignal = createToken |> map { token in
                if let card = token.card {
                    let last4 = card.last4()
                    let brand = STPAPIClient.string(with: card.brand)
                    return .webToken(BotCheckoutPaymentWebToken(title: "\(brand)*\(last4)", data: "{\"type\": \"card\", \"id\": \"\(token.tokenId)\"}", saveOnServer: saveOnServer))
                }
                return nil
            }
        case .smartglocal:
            tokenSignal = validateSmartGlobal(publishableKey, isTesting: isTesting, state: stateValue.with { $0 }) |> map(Optional.init)
        }
        _ = showModalProgress(signal: tokenSignal, for: context.window).start(next: { token in
            if let token = token {
                completion(token)
                close?()
            }
        }, error: { error in
            alert(for: context.window, info: error.localizedDescription)
        })

    }, passwordMissing: passwordMissing)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().checkoutNewCardTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        updateState { _ in
            State(card: .init(number: "", date: "", cvc: ""), holderName: "", billingAddress: .init(country: "", zipCode: ""), saveInfo: false)
        }
    }
    
    controller.updateDatas = { [weak controller] data in
                
        updateState { current in
            var current = current
            
            current.billingError = nil
            current.nameError = nil
            
            current.card.number = data[_id_card_number]?.stringValue ?? ""
            current.card.date = data[_id_card_date]?.stringValue ?? ""
            current.card.cvc = data[_id_card_cvc]?.stringValue ?? ""

            current.holderName = data[_id_card_holder_name]?.stringValue
            current.billingAddress.country = data[_id_card_country]?.stringValue
            current.billingAddress.zipCode = data[_id_card_zip_code]?.stringValue
            

            let normalized = STPCardValidator.sanitizedNumericString(for: current.card.number)
            let brand = STPCardValidator.brand(forNumber: normalized)
            let maxCardNumberLength = STPCardValidator.maxLength(for: brand)
            let maxCVCLength = STPCardValidator.maxCVCLength(for: brand)

            
            
            var cardError: InputDataValueError? = nil
            
            if normalized.length == maxCardNumberLength {
                let state = STPCardValidator.validationState(forNumber: current.card.number, validatingCardBrand: true)
                switch state {
                case .invalid:
                    cardError = .init(description: strings().yourCardsNumberIsInvalid, target: .data)
                default:
                    cardError = nil
                }
            }
                  
            if current.card.date.length == 5 && cardError == nil {
                let yearState = STPCardValidator.validationState(forExpirationYear: String(current.card.date.suffix(2)), inMonth: current.card.date.prefix(2))
                switch yearState {
                case .invalid:
                    cardError = .init(description: strings().yourCardsExpirationYearIsInvalid, target: .data)
                default:
                    let monthState = STPCardValidator.validationState(forExpirationMonth: current.card.date.prefix(2))
                    switch monthState {
                    case .invalid:
                        cardError = .init(description: strings().yourCardsExpirationMonthIsInvalid, target: .data)
                    default:
                        cardError = nil
                    }
                }
            }
            
            if current.card.cvc.length == maxCVCLength && cardError == nil {
                let state = STPCardValidator.validationState(forCVC: current.card.cvc, cardBrand: brand)
                switch state {
                case .invalid:
                    cardError = .init(description: strings().yourCardsSecurityCodeIsInvalid, target: .data)
                default:
                    cardError = nil
                }
            }
            
            if let responder = controller?.currentFirstResponderIdentifier, cardError == nil {
                if _id_card_number == responder, normalized.length == maxCardNumberLength {
                    controller?.jumpNext()
                } else if _id_card_date == responder, current.card.date.length == 5 {
                    controller?.jumpNext()
                }  else if _id_card_cvc == responder, current.card.cvc.length == maxCVCLength {
                    controller?.jumpNext()
                }
            }
            
            current.cardError = cardError
            
            return current
        }
        return .none
    }
    
    controller.validateData = { _ in
        let state = stateValue.with { $0 }
        if let unfilled = state.unfilledItem {
            return .fail(.fields([unfilled: .shake]))
        } else {
            return .fail(.doSomething(next: { _ in
                arguments.verify()
            }))
        }
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}





