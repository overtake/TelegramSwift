//
//  PaymentsShippingInfoController.swift
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

private let cManager: CountryManager = CountryManager()


private final class Arguments {
    let context: AccountContext
    let toggleSaveInfo:()->Void
    init(context: AccountContext, toggleSaveInfo: @escaping()->Void) {
        self.context = context
        self.toggleSaveInfo = toggleSaveInfo
    }
}

private let _id_checkout_info_address1 = InputDataIdentifier("_id_checkout_info_address1")
private let _id_checkout_info_address2 = InputDataIdentifier("_id_checkout_info_address2")
private let _id_checkout_info_city = InputDataIdentifier("_id_checkout_info_city")
private let _id_checkout_info_state = InputDataIdentifier("_id_checkout_info_state")
private let _id_checkout_info_country = InputDataIdentifier("_id_checkout_info_country")
private let _id_checkout_info_postcode = InputDataIdentifier("_id_checkout_info_postcode")
private let _id_checkout_info_name = InputDataIdentifier("_id_checkout_info_name")
private let _id_checkout_info_email = InputDataIdentifier("_id_checkout_info_email")
private let _id_checkout_info_phone = InputDataIdentifier("_id_checkout_info_phone")
private let _id_checkout_info_save_info = InputDataIdentifier("_id_checkout_info_save_info")


private struct State : Equatable {
    
    struct Address : Equatable {
        var address1: String
        var address2: String
        var city: String
        var state: String
        var country: String
        var postcode: String
    }
    
    var address: Address?
    var name: String?
    var email: String?
    var phone: String?
    
    var saveInfo: Bool
    
    var errors:[InputDataIdentifier: InputDataValueError]
    
    var firstEmptyId: InputDataIdentifier? {
        if let address = address {
            if address.address1.isEmpty {
                return _id_checkout_info_address1
            }
            if address.address2.isEmpty {
                return _id_checkout_info_address2
            }
            if address.city.count < 2 {
                return _id_checkout_info_city
            }
            if address.state.count < 2 {
                return _id_checkout_info_state
            }
            if address.country.isEmpty {
                return _id_checkout_info_country
            }
            if address.postcode.count < 2 {
                return _id_checkout_info_postcode
            }
        }
        if let value = name, value.isEmpty {
            return _id_checkout_info_name
        }
        if let value = email, value.isEmpty {
            return _id_checkout_info_email
        }
        if let value = phone, value.isEmpty {
            return _id_checkout_info_phone
        }
        return nil
    }
    
    var formInfo: BotPaymentRequestedInfo {
        var shippingAddress: BotPaymentShippingAddress?
        if let address = self.address {
            shippingAddress = BotPaymentShippingAddress(streetLine1: address.address1, streetLine2: address.address2, city: address.city, state: address.state, countryIso2: address.country, postCode: address.postcode)
        }
        return BotPaymentRequestedInfo(name: self.name, phone: self.phone, email: self.email, shippingAddress: shippingAddress, tipAmount: nil)
    }

}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    if let address = state.address {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.checkoutInfoShippingInfoTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(address.address1), error: nil, identifier: _id_checkout_info_address1, mode: .plain, data: .init(viewType: .firstItem), placeholder: InputDataInputPlaceholder(L10n.checkoutInfoShippingInfoAddress1), inputPlaceholder: L10n.checkoutInfoShippingInfoAddress1Placeholder, filter: { $0 }, limit: 64))
        index += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(address.address2), error: nil, identifier: _id_checkout_info_address2, mode: .plain, data: .init(viewType: .innerItem), placeholder: InputDataInputPlaceholder(L10n.checkoutInfoShippingInfoAddress2), inputPlaceholder: L10n.checkoutInfoShippingInfoAddress2Placeholder, filter: { $0 }, limit: 64))
        index += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(address.city), error: nil, identifier: _id_checkout_info_city, mode: .plain, data: .init(viewType: .innerItem), placeholder: InputDataInputPlaceholder(L10n.checkoutInfoShippingInfoCity), inputPlaceholder: L10n.checkoutInfoShippingInfoCityPlaceholder, filter: { $0 }, limit: 64))
        index += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(address.state), error: nil, identifier: _id_checkout_info_state, mode: .plain, data: .init(viewType: .innerItem), placeholder: InputDataInputPlaceholder(L10n.checkoutInfoShippingInfoState), inputPlaceholder: L10n.checkoutInfoShippingInfoStatePlaceholder, filter: { $0 }, limit: 64))
        index += 1
        
        
        let filedata = try! String(contentsOfFile: Bundle.main.path(forResource: "countries", ofType: nil)!)
        
        let countries: [ValuesSelectorValue<InputDataValue>] = filedata.components(separatedBy: "\n").compactMap { country in
            let entry = country.components(separatedBy: ";")
            if entry.count >= 3 {
                return ValuesSelectorValue(localized: entry[2], value: .string(entry[1]))
            } else {
                return nil
            }
        }.sorted(by: { $0.localized < $1.localized})
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: .string(state.address?.country), error: nil, identifier: _id_checkout_info_country, placeholder: L10n.checkoutInfoShippingInfoCountry, viewType: .innerItem, values: countries))
        index += 1


        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(address.postcode), error: nil, identifier: _id_checkout_info_postcode, mode: .plain, data: .init(viewType: .lastItem), placeholder: InputDataInputPlaceholder(L10n.checkoutInfoShippingInfoPostcode), inputPlaceholder: L10n.checkoutInfoShippingInfoPostcodePlaceholder, filter: { $0 }, limit: 12))
        index += 1

    }
    
    if state.email != nil  || state.name != nil  || state.phone != nil {
        if state.address != nil {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.checkoutInfoReceiverInfoTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        
        struct Tuple : Equatable {
            let id: InputDataIdentifier
            let name: String
            let placeholder: String
            let value: InputDataValue
            let error: InputDataValueError?
        }
        
        var items:[Tuple] = []
        
        if let name = state.name {
            items.append(Tuple(id: _id_checkout_info_name, name: L10n.checkoutInfoReceiverInfoName, placeholder: L10n.checkoutInfoReceiverInfoNamePlaceholder, value: .string(name), error: state.errors[_id_checkout_info_name]))
        }
        if let email = state.email {
            items.append(Tuple(id: _id_checkout_info_email, name: L10n.checkoutInfoReceiverInfoEmail, placeholder: L10n.checkoutInfoReceiverInfoEmailPlaceholder, value: .string(email), error: state.errors[_id_checkout_info_email]))
        }
        if let phone = state.phone {
            items.append(Tuple(id: _id_checkout_info_phone, name: L10n.checkoutInfoReceiverInfoPhone, placeholder: L10n.checkoutInfoReceiverInfoPhone, value: .string(phone), error: state.errors[_id_checkout_info_phone]))
        }
        
        for item in items {
            entries.append(.input(sectionId: sectionId, index: index, value: item.value, error: item.error, identifier: item.id, mode: .plain, data: .init(viewType: bestGeneralViewType(items, for: item)), placeholder: InputDataInputPlaceholder(item.name), inputPlaceholder: item.placeholder, filter: { $0 }, limit: 255))
            index += 1
        }
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_checkout_info_save_info, data: .init(name: L10n.checkoutInfoSaveInfo, color: theme.colors.text, type: .switchable(state.saveInfo), viewType: .singleItem, action: arguments.toggleSaveInfo)))
    index += 1
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.checkoutInfoSaveInfoHelp), data: InputDataGeneralTextData.init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum PaymentsShippingInfoFocus {
    case address
    case name
    case email
    case phone
}

func PaymentsShippingInfoController(context: AccountContext, invoice: BotPaymentInvoice, messageId: MessageId, formInfo: BotPaymentRequestedInfo, focus: PaymentsShippingInfoFocus?, formInfoUpdated: @escaping (BotPaymentRequestedInfo, BotPaymentValidatedFormInfo) -> Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    
    let initialState = State(address: invoice.requestedFields.contains(.shippingAddress) ? State.Address(address1: formInfo.shippingAddress?.streetLine1 ?? "", address2: formInfo.shippingAddress?.streetLine2 ?? "", city: formInfo.shippingAddress?.city ?? "", state: formInfo.shippingAddress?.state ?? "", country: formInfo.shippingAddress?.countryIso2 ?? "", postcode: formInfo.shippingAddress?.postCode ?? "") : nil, name: invoice.requestedFields.contains(.name) ? formInfo.name ?? "" : nil, email: invoice.requestedFields.contains(.email) ? formInfo.email ?? "" : nil, phone: invoice.requestedFields.contains(.phone) ? formInfo.phone ?? "" : nil, saveInfo: true, errors: [:])
    
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
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.checkoutInfoTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.didAppear = { controller in
        DispatchQueue.main.async {
            if let focus = focus {
                let id: InputDataIdentifier
                switch focus {
                case .address:
                    id = _id_checkout_info_address1
                case .name:
                    id = _id_checkout_info_name
                case .email:
                    id = _id_checkout_info_email
                case .phone:
                    id = _id_checkout_info_phone
                }
                controller.makeFirstResponderIfPossible(for: id, focusIdentifier: id)
            }
        }
    }
    
    controller.validateData = { _ in
        
        let emptyId = stateValue.with { $0.firstEmptyId }
        if let emptyId = emptyId {
            return .fail(.fields([emptyId: .shake]))
        }
        
        let state = stateValue.with { $0 }
        let formInfo = state.formInfo
        
        return .fail(.doSomething(next: { f in
            _ = showModalProgress(signal: validateBotPaymentForm(account: context.account, saveInfo: state.saveInfo, messageId: messageId, formInfo: formInfo), for: context.window).start(next: { result in
                
                formInfoUpdated(formInfo, result)
                close?()
            }, error: { error in
                let text: String
                var id: InputDataIdentifier? = nil
                switch error {
                    case .shippingNotAvailable:
                        text = L10n.checkoutInfoErrorShippingNotAvailable
                    case .addressStateInvalid:
                        text = L10n.checkoutInfoErrorStateInvalid
                        id = _id_checkout_info_state
                    case .addressPostcodeInvalid:
                        text = L10n.checkoutInfoErrorPostcodeInvalid
                        id = _id_checkout_info_postcode
                    case .addressCityInvalid:
                        text = L10n.checkoutInfoErrorCityInvalid
                        id = _id_checkout_info_city
                    case .nameInvalid:
                        text = L10n.checkoutInfoErrorNameInvalid
                        id = _id_checkout_info_name
                    case .emailInvalid:
                        text = L10n.checkoutInfoErrorEmailInvalid
                        id = _id_checkout_info_email
                    case .phoneInvalid:
                        text = L10n.checkoutInfoErrorPhoneInvalid
                        id = _id_checkout_info_phone
                    case .generic:
                        text = L10n.unknownError
                }
                alert(for: context.window, info: text)
                if let id = id {
                    f(.fail(.fields([id: .shake])))
                }
            })
        }))
        
    }
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            
            current.address?.address1 = data[_id_checkout_info_address1]?.stringValue ?? ""
            current.address?.address2 = data[_id_checkout_info_address2]?.stringValue ?? ""
            current.address?.city = data[_id_checkout_info_city]?.stringValue ?? ""
            current.address?.state = data[_id_checkout_info_state]?.stringValue ?? ""
            current.address?.country = data[_id_checkout_info_country]?.stringValue ?? ""
            current.address?.postcode = data[_id_checkout_info_postcode]?.stringValue ?? ""

            
            if let value = data[_id_checkout_info_name]?.stringValue {
                current.name = value
            }
            if let value = data[_id_checkout_info_email]?.stringValue {
                current.email = value
            }
            if let value = data[_id_checkout_info_phone]?.stringValue {
                current.phone = value
            }
            current.errors = [:]
            return current
        }
        return .none
    }
    
   

    let modalInteractions = ModalInteractions(acceptTitle: L10n.modalDone, accept: { [weak controller] in
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


