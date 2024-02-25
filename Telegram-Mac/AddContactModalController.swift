//
//  AddContactModalController.swift
//  Telegram
//
//  Created by keepcoder on 10/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox

private struct AddContactState : Equatable {
    let firstName: String
    let lastName: String
    let phoneNumber: String
    
    let errors: [InputDataIdentifier : InputDataValueError]
    
    init(firstName: String, lastName: String, phoneNumber: String, errors: [InputDataIdentifier : InputDataValueError]) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.errors = errors
    }
    
    func withUpdatedError(_ error: InputDataValueError?, for key: InputDataIdentifier) -> AddContactState {
        var errors = self.errors
        if let error = error {
            errors[key] = error
        } else {
            errors.removeValue(forKey: key)
        }
        return AddContactState(firstName: self.firstName, lastName: self.lastName, phoneNumber: self.phoneNumber, errors: errors)
    }
    
    func withUpdatedFirstName(_ firstName: String) -> AddContactState {
        return AddContactState(firstName: firstName, lastName: self.lastName, phoneNumber: self.phoneNumber, errors: self.errors)
    }
    func withUpdatedLastName(_ lastName: String) -> AddContactState {
        return AddContactState(firstName: self.firstName, lastName: lastName, phoneNumber: self.phoneNumber, errors: self.errors)
    }
    func withUpdatedPhoneNumber(_ phoneNumber: String) -> AddContactState {
        return AddContactState(firstName: self.firstName, lastName: self.lastName, phoneNumber: phoneNumber, errors: self.errors)
    }
}

private let _id_input_first_name = InputDataIdentifier("_id_input_first_name")
private let _id_input_last_name = InputDataIdentifier("_id_input_last_name")
private let _id_input_phone_number = InputDataIdentifier("_id_input_phone_number")

private func addContactEntries(state: AddContactState) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1

    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.firstName), error: state.errors[_id_input_first_name], identifier: _id_input_first_name, mode: .plain, data: InputDataRowData(viewType: .firstItem), placeholder: nil, inputPlaceholder: strings().contactsFirstNamePlaceholder, filter: { $0 }, limit: 255))
    index += 1

    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.lastName), error: state.errors[_id_input_last_name], identifier: _id_input_last_name, mode: .plain, data: InputDataRowData(viewType: .innerItem), placeholder: nil, inputPlaceholder: strings().contactsLastNamePlaceholder, filter: { $0 }, limit: 255))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.phoneNumber), error: state.errors[_id_input_phone_number], identifier: _id_input_phone_number, mode: .plain, data: InputDataRowData(viewType: .lastItem), placeholder: nil, inputPlaceholder: strings().contactsPhoneNumberPlaceholder, filter: { text in
        return text.trimmingCharacters(in: CharacterSet(charactersIn: "0987654321+ ").inverted)
    }, limit: 30))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

func AddContactModalController(_ context: AccountContext) -> InputDataModalController {
    
    
    let initialState = AddContactState(firstName: "", lastName: "", phoneNumber: "", errors: [:])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: false)
    let stateValue = Atomic(value: initialState)
    let updateState: ((AddContactState) -> AddContactState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let dataSignal = statePromise.get() |> map { state in
        return addContactEntries(state: state)
    }
    
    var close: (() -> Void)?
    
    var shouldMakeNextResponderAfterTransition: InputDataIdentifier? = nil
    
    let controller = InputDataController(dataSignal: dataSignal |> map { InputDataSignalValue(entries: $0) }, title: strings().contactsAddContact, validateData: { data in
        
        return .fail(.doSomething { f in
            let state = stateValue.with {$0}
            
            var fields: [InputDataIdentifier : InputDataValidationFailAction] = [:]
            
            if state.firstName.isEmpty {
                fields[_id_input_first_name] = .shake
                shouldMakeNextResponderAfterTransition = _id_input_first_name
            }
            
            if state.phoneNumber.isEmpty {
                fields[_id_input_phone_number] = .shake
                if shouldMakeNextResponderAfterTransition == nil {
                    shouldMakeNextResponderAfterTransition = _id_input_phone_number
                }
                updateState {
                    $0.withUpdatedError(InputDataValueError(description: strings().contactsPhoneNumberInvalid, target: .data), for: _id_input_phone_number)
                }
            }
            
            if !fields.isEmpty {
                f(.fail(.fields(fields)))
            } else {
                _ = (showModalProgress(signal: context.engine.contacts.importContact(firstName: state.firstName, lastName: state.lastName, phoneNumber: state.phoneNumber), for: context.window) |> deliverOnMainQueue).start(next: { peerId in
                    if let peerId = peerId {
                        context.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId)))
                        close?()
                    } else {
                        updateState {
                            $0.withUpdatedError(InputDataValueError(description: strings().contactsPhoneNumberNotRegistred, target: .data), for: _id_input_phone_number)
                        }
                    }
                })
            }
            
            updateState {
                $0
            }
        })
        
       
    }, updateDatas: { data in
        updateState { state in
            return state
                .withUpdatedFirstName(data[_id_input_first_name]?.stringValue ?? "")
                .withUpdatedLastName(data[_id_input_last_name]?.stringValue ?? "")
                .withUpdatedPhoneNumber(formatPhoneNumber(data[_id_input_phone_number]?.stringValue ?? ""))
                .withUpdatedError(nil, for: _id_input_first_name)
                .withUpdatedError(nil, for: _id_input_last_name)
                .withUpdatedError(nil, for: _id_input_phone_number)
        }

        return .none
    }, afterDisappear: {
        
    }, afterTransaction: { controller in
        if let identifier = shouldMakeNextResponderAfterTransition {
            controller.makeFirstResponderIfPossible(for: identifier)
        }
        shouldMakeNextResponderAfterTransition = nil
    })
    
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().modalCreate, accept: { [weak controller] in
        controller?.validateInputValues()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(300, 300))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
