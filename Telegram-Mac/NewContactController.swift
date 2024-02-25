//
//  AddContactController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox
import SwiftSignalKit
import TGUIKit

private final class NewContactArguments {
    let context: AccountContext
    let updateText:(String, String)->Void
    let toggleAddToException:(Bool)->Void
    init(context: AccountContext, updateText:@escaping(String, String)->Void, toggleAddToException:@escaping(Bool)->Void) {
        self.context = context
        self.updateText = updateText
        self.toggleAddToException = toggleAddToException
    }
}

private struct NewContactState : Equatable {
    
}
private let _id_contact_info = InputDataIdentifier("_id_contact_info")
private let _id_phone_number = InputDataIdentifier("_id_phone_number")
private let _id_add_exception = InputDataIdentifier("_id_add_exception")

private func newContactEntries(state: EditInfoState, arguments: NewContactArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_contact_info, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        return EditAccountInfoItem(initialSize, stableId: stableId, account: arguments.context.account, state: state, viewType: .singleItem, updateText: arguments.updateText)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_phone_number, equatable: InputDataEquatable(state.phone), comparable: nil, item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().newContactPhone, description: state.phone == nil ? strings().newContactPhoneHidden : formatPhoneNumber(state.phone!), descTextColor: theme.colors.accent, type: .none, viewType: .singleItem, action: {
            
        })
    }))
    index += 1

    if state.phone == nil {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().newContactPhoneHiddenText(state.firstName)), data: InputDataGeneralTextData(viewType: .textBottomItem)))
        index += 1
    }
    
    
    if let peerStatusSettings = state.peerStatusSettings, peerStatusSettings.contains(.addExceptionWhenAddingContact) {
        
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_exception, data: InputDataGeneralData(name: strings().newContactExceptionShareMyPhoneNumber, color: theme.colors.text, type: .switchable(state.addToException), viewType: .singleItem, action: {
            arguments.toggleAddToException(!state.addToException)
        })))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().newContactExceptionShareMyPhoneNumberDesc(state.firstName)), data: InputDataGeneralTextData(viewType: .textBottomItem)))
        index += 1

    }
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1

    
    return entries
}

func NewContactController(context: AccountContext, peerId: PeerId) -> InputDataModalController {

    let initialState: EditInfoState = EditInfoState()
    let stateValue: Atomic<EditInfoState> = Atomic(value: initialState)
    let statePromise: ValuePromise<EditInfoState> = ValuePromise(initialState, ignoreRepeated: true)
    
    let updateState: (_ f:(EditInfoState)->EditInfoState)->Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    let arguments = NewContactArguments(context: context, updateText: { firstName, lastName in
        updateState {
            return $0.withUpdatedFirstName(firstName).withUpdatedLastName(lastName)
        }
    }, toggleAddToException: { value in
        updateState {
            return $0.withUpdatedAddToException(value)
        }
    })
    
    let actionsDisposable = DisposableSet()
    
    let dataSignal = statePromise.get() |> mapToSignal { state in
        if state.peer == nil {
            return .never()
        } else {
            return .single(newContactEntries(state: state, arguments: arguments))
        }
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    actionsDisposable.add((context.account.postbox.peerView(id: peerId) |> deliverOnMainQueue).start(next: { pv in
        updateState { current in
            return current.withUpdatedPeerView(pv)
        }
    }))
    
    var dismiss:(()->Void)?
    
    let addContact:()->Void = {
        let state = stateValue.with { $0 }
        _ = showModalProgress(signal: context.engine.contacts.addContactInteractively(peerId: peerId, firstName: state.firstName, lastName: state.lastName, phoneNumber: state.phone ?? "", addToPrivacyExceptions: state.addToException), for: context.window).start(completed: {
            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 2.0).start()
        })
        dismiss?()
    }
    
    let controller = InputDataController(dataSignal: dataSignal, title: strings().newContactTitle, validateData: { data in
        
        let firstName = stateValue.with { $0.firstName }
        if firstName.isEmpty {
            return .fail(.fields([_id_contact_info : .shake]))
        }
        addContact()
        
        return .fail(.none)
    }, afterDisappear: {
        actionsDisposable.dispose()
    })
    
    let modalInteractions: ModalInteractions = ModalInteractions(acceptTitle: strings().navigationDone, accept: { [weak controller] in
        controller?.validateInputValues()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(300, 300))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    dismiss = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
