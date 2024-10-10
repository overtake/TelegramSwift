//
//  VCardModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import Contacts
import SwiftSignalKit



private struct State : Equatable {

}

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private func entries(vCard: CNContact, contact: TelegramMediaContact, arguments: Arguments) -> [InputDataEntry] {
    
    var entries: [InputDataEntry] = []
    var sectionId:Int32 = 0
    
    func getLabel(_ key: String) -> String {
        
        switch key {
        case "_$!<HomePage>!$_":
            return strings().contactInfoURLLabelHomepage
        case "_$!<Home>!$_":
            return strings().contactInfoPhoneLabelHome
        case "_$!<Work>!$_":
            return strings().contactInfoPhoneLabelWork
        case "_$!<Mobile>!$_":
            return strings().contactInfoPhoneLabelMobile
        case "_$!<Main>!$_":
            return strings().contactInfoPhoneLabelMain
        case "_$!<HomeFax>!$_":
            return strings().contactInfoPhoneLabelHomeFax
        case "_$!<WorkFax>!$_":
            return strings().contactInfoPhoneLabelWorkFax
        case "_$!<Pager>!$_":
            return strings().contactInfoPhoneLabelPager
        case "_$!<Other>!$_":
            return strings().contactInfoPhoneLabelOther
        default:
            return strings().contactInfoPhoneLabelOther
        }
    }
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    
    struct Item : Equatable {
        let label: String
        let text: String
        let identifier: String
    }
    
    var labels:[Item] = []
    
    for phoneNumber in vCard.phoneNumbers {
        if let label = phoneNumber.label {
            labels.append(.init(label: getLabel(label), text: formatPhoneNumber(phoneNumber.value.stringValue), identifier: phoneNumber.identifier))
        }
    }
    
    
    for email in vCard.emailAddresses {
        if let label = email.label {
            labels.append(.init(label: getLabel(label), text: email.value as String, identifier: email.identifier))
        }
    }
    
    for address in vCard.urlAddresses {
        if let label = address.label {
            labels.append(.init(label: getLabel(label), text: address.value as String, identifier: address.identifier))
        }
    }
    
    for address in vCard.postalAddresses {
        if let label = address.label {
            let text: String = address.value.street + "\n" + address.value.city + "\n" + address.value.country
            labels.append(.init(label: getLabel(label), text: text, identifier: address.identifier))
        }
    }
    
    if !vCard.organizationName.isEmpty {
        labels.append(.init(label: strings().contactInfoJob, text: vCard.organizationName, identifier: "job_company"))
    }
    
    if !vCard.jobTitle.isEmpty {
        labels.append(.init(label: strings().contactInfoTitle, text: vCard.jobTitle, identifier: "job_title"))
    }
        
    
    if let birthday = vCard.birthday {
        let date = Calendar.current.date(from: birthday)!
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        labels.append(.init(label: strings().contactInfoBirthdayLabel, text: dateFormatter.string(from: date), identifier: "birthday"))
    }
    
    for social in vCard.socialProfiles {
        labels.append(.init(label: social.value.service, text: social.value.urlString, identifier: social.identifier))

    }
    
    for social in vCard.instantMessageAddresses {
        labels.append(.init(label: social.value.service, text: social.value.username, identifier: social.identifier))
    }
    
    
    for (i, label) in labels.enumerated() {
        let viewType = bestGeneralViewType(labels, for: i)
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: 0, value: .none, identifier: InputDataIdentifier("_id\(label.identifier)"), equatable: .init(label), comparable: nil, item: { initialSize, stableId -> TableRowItem in
            return TextAndLabelItem(initialSize, stableId: stableId, label: label.label, copyMenuText: strings().contextCopy, text: label.text, context: arguments.context, viewType: viewType, canCopy: true, _copyToClipboard: { 
                copyToClipboard(label.text)
                showModalText(for: arguments.context.window, text: strings().shareLinkCopied)
            })
        }))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    

    return entries
}


func VCardModalController(context: AccountContext, vCard: CNContact, contact: TelegramMediaContact) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(vCard: vCard, contact: contact, arguments: arguments))
    }
    let name = isNotEmptyStrings([contact.firstName + (!contact.firstName.isEmpty ? " " : "") + contact.lastName])

    
    let controller = InputDataController(dataSignal: signal, title: name)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalOK, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.validateData = { [weak modalController] _ in
    
        modalController?.close()
        return .none
    }
    
//    close = { [weak modalController] in
//        modalController?.modal?.close()
//    }
    
    return modalController
}
